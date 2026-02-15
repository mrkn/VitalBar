import Darwin
import Foundation

public enum MemoryPressureLevel: String, Sendable, Equatable {
    case normal
    case warning
    case critical
    case unknown
}

public struct MemoryUsageSample: Sendable, Equatable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64
    public let cachedBytes: UInt64
    public let compressedBytes: UInt64
    public let swapUsedBytes: UInt64
    public let pressureLevel: MemoryPressureLevel

    public init(
        usedBytes: UInt64,
        totalBytes: UInt64,
        cachedBytes: UInt64 = 0,
        compressedBytes: UInt64 = 0,
        swapUsedBytes: UInt64 = 0,
        pressureLevel: MemoryPressureLevel = .unknown
    ) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.cachedBytes = cachedBytes
        self.compressedBytes = compressedBytes
        self.swapUsedBytes = swapUsedBytes
        self.pressureLevel = pressureLevel
    }

    public var usage: Double {
        guard totalBytes > 0 else {
            return 0.0
        }

        let ratio = Double(usedBytes) / Double(totalBytes)
        return min(max(ratio, 0.0), 1.0)
    }
}

public enum MemorySamplingError: Error, Sendable {
    case invalidPhysicalMemory
    case hostPageSizeFailed(code: kern_return_t)
    case hostStatisticsFailed(code: kern_return_t)
}

public protocol MemoryUsageSampling: Sendable {
    func sampleUsage() throws -> MemoryUsageSample
}

public struct SystemMemoryUsageSampler: MemoryUsageSampling {
    public init() {}

    public func sampleUsage() throws -> MemoryUsageSample {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        guard totalMemory > 0 else {
            throw MemorySamplingError.invalidPhysicalMemory
        }

        var pageSize: vm_size_t = 0
        let host = mach_host_self()
        let pageSizeResult = host_page_size(host, &pageSize)

        guard pageSizeResult == KERN_SUCCESS else {
            throw MemorySamplingError.hostPageSizeFailed(code: pageSizeResult)
        }

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result: kern_return_t = withUnsafeMutablePointer(to: &vmStats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { integerPointer in
                host_statistics64(host, HOST_VM_INFO64, integerPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            throw MemorySamplingError.hostStatisticsFailed(code: result)
        }

        let pageSizeBytes = UInt64(pageSize)

        let activePages = UInt64(vmStats.active_count)
        let purgeablePages = UInt64(vmStats.purgeable_count)
        let externalPages = UInt64(vmStats.external_page_count)
        let wiredPages = UInt64(vmStats.wire_count)
        let compressedPages = UInt64(vmStats.compressor_page_count)
        let inactivePages = UInt64(vmStats.inactive_count)
        let speculativePages = UInt64(vmStats.speculative_count)

        let usedPages = Self.usedPagesIncludingCompressed(
            activePages: activePages,
            purgeablePages: purgeablePages,
            externalPages: externalPages,
            wiredPages: wiredPages,
            compressedPages: compressedPages
        )
        let cachedPages = inactivePages + speculativePages + purgeablePages

        let usedBytes = min(totalMemory, Self.bytes(fromPages: usedPages, pageSize: pageSizeBytes))
        let cachedBytes = min(totalMemory, Self.bytes(fromPages: cachedPages, pageSize: pageSizeBytes))
        let compressedBytes = min(totalMemory, Self.bytes(fromPages: compressedPages, pageSize: pageSizeBytes))
        let swapUsedBytes = Self.readSwapUsedBytes()
        let pressureLevel = Self.estimatedPressureLevel(
            usedBytes: usedBytes,
            compressedBytes: compressedBytes,
            swapUsedBytes: swapUsedBytes,
            totalBytes: totalMemory
        )

        return MemoryUsageSample(
            usedBytes: usedBytes,
            totalBytes: totalMemory,
            cachedBytes: cachedBytes,
            compressedBytes: compressedBytes,
            swapUsedBytes: swapUsedBytes,
            pressureLevel: pressureLevel
        )
    }

    private static func bytes(fromPages pages: UInt64, pageSize: UInt64) -> UInt64 {
        let (result, overflow) = pages.multipliedReportingOverflow(by: pageSize)
        return overflow ? UInt64.max : result
    }

    static func usedPagesIncludingCompressed(
        activePages: UInt64,
        purgeablePages: UInt64,
        externalPages: UInt64,
        wiredPages: UInt64,
        compressedPages: UInt64
    ) -> UInt64 {
        // Activity Monitor style approximation:
        // Memory Used = (App Memory + Wired Memory) + Compressed.
        let appMemory = activePages > (purgeablePages + externalPages)
            ? activePages - purgeablePages - externalPages
            : 0
        let wiredMemory = wiredPages
        let compressedMemory = compressedPages
        return appMemory + wiredMemory + compressedMemory
    }

    private static func readSwapUsedBytes() -> UInt64 {
        var mib = [CTL_VM, VM_SWAPUSAGE]
        var swapUsage = xsw_usage()
        var swapUsageSize = MemoryLayout<xsw_usage>.size
        let mibCount = u_int(mib.count)

        let result: Int32 = mib.withUnsafeMutableBufferPointer { mibBuffer in
            withUnsafeMutablePointer(to: &swapUsage) { swapUsagePointer in
                sysctl(
                    mibBuffer.baseAddress,
                    mibCount,
                    swapUsagePointer,
                    &swapUsageSize,
                    nil,
                    0
                )
            }
        }

        guard result == 0 else {
            return 0
        }

        return UInt64(swapUsage.xsu_used)
    }

    private static func estimatedPressureLevel(
        usedBytes: UInt64,
        compressedBytes: UInt64,
        swapUsedBytes: UInt64,
        totalBytes: UInt64
    ) -> MemoryPressureLevel {
        guard totalBytes > 0 else {
            return .unknown
        }

        let usedRatio = Double(usedBytes) / Double(totalBytes)
        let compressedRatio = Double(compressedBytes) / Double(totalBytes)

        let gib = 1_073_741_824 as UInt64
        let criticalSwap = 2 * gib
        let warningSwap = gib / 2

        if usedRatio >= 0.95 || compressedRatio >= 0.20 || swapUsedBytes >= criticalSwap {
            return .critical
        }

        if usedRatio >= 0.88 || compressedRatio >= 0.10 || swapUsedBytes >= warningSwap {
            return .warning
        }

        return .normal
    }
}
