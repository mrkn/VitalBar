import Darwin
import Dispatch
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
    public let appBytes: UInt64
    public let wiredBytes: UInt64
    public let cachedBytes: UInt64
    public let compressedBytes: UInt64
    public let swapUsedBytes: UInt64
    public let pressureLevel: MemoryPressureLevel

    public init(
        usedBytes: UInt64,
        totalBytes: UInt64,
        appBytes: UInt64 = 0,
        wiredBytes: UInt64 = 0,
        cachedBytes: UInt64 = 0,
        compressedBytes: UInt64 = 0,
        swapUsedBytes: UInt64 = 0,
        pressureLevel: MemoryPressureLevel = .unknown
    ) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.appBytes = appBytes
        self.wiredBytes = wiredBytes
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

public protocol MemoryPressureLevelProviding: Sendable {
    func currentPressureLevel() -> MemoryPressureLevel
}

public final class SystemMemoryPressureSampler: MemoryPressureLevelProviding, @unchecked Sendable {
    public static let shared = SystemMemoryPressureSampler()

    private let lock = NSLock()
    private var level: MemoryPressureLevel = .normal
    private let source: DispatchSourceMemoryPressure

    private init() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical],
            queue: DispatchQueue.global(qos: .utility)
        )
        self.source = source

        source.setEventHandler { [weak self] in
            guard let self else {
                return
            }

            self.updateLevel(from: self.source.data)
        }
        source.resume()
    }

    public func currentPressureLevel() -> MemoryPressureLevel {
        lock.lock()
        defer { lock.unlock() }
        return level
    }

    private func updateLevel(from event: DispatchSource.MemoryPressureEvent) {
        let nextLevel: MemoryPressureLevel
        if event.contains(.critical) {
            nextLevel = .critical
        } else if event.contains(.warning) {
            nextLevel = .warning
        } else if event.contains(.normal) {
            nextLevel = .normal
        } else {
            nextLevel = .unknown
        }

        lock.lock()
        level = nextLevel
        lock.unlock()
    }
}

public struct SystemMemoryUsageSampler: MemoryUsageSampling {
    private let pressureSampler: any MemoryPressureLevelProviding

    public init(pressureSampler: any MemoryPressureLevelProviding = SystemMemoryPressureSampler.shared) {
        self.pressureSampler = pressureSampler
    }

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

        let internalPages = UInt64(vmStats.internal_page_count)
        let purgeablePages = UInt64(vmStats.purgeable_count)
        let fileBackedPages = UInt64(vmStats.external_page_count)
        let wiredPages = UInt64(vmStats.wire_count)
        let compressedPages = UInt64(vmStats.compressor_page_count)

        let appPages = Self.appMemoryPages(
            internalPages: internalPages
        )
        let usedPages = Self.usedPagesIncludingCompressed(
            appPages: appPages,
            wiredPages: wiredPages,
            compressedPages: compressedPages
        )
        let cachedPages = Self.cachedPages(
            fileBackedPages: fileBackedPages,
            purgeablePages: purgeablePages
        )

        let appBytes = min(totalMemory, Self.bytes(fromPages: appPages, pageSize: pageSizeBytes))
        let wiredBytes = min(totalMemory, Self.bytes(fromPages: wiredPages, pageSize: pageSizeBytes))
        let usedBytes = min(totalMemory, Self.bytes(fromPages: usedPages, pageSize: pageSizeBytes))
        let cachedBytes = min(totalMemory, Self.bytes(fromPages: cachedPages, pageSize: pageSizeBytes))
        let compressedBytes = min(totalMemory, Self.bytes(fromPages: compressedPages, pageSize: pageSizeBytes))
        let swapUsedBytes = Self.readSwapUsedBytes()
        let pressureLevel = pressureSampler.currentPressureLevel()

        return MemoryUsageSample(
            usedBytes: usedBytes,
            totalBytes: totalMemory,
            appBytes: appBytes,
            wiredBytes: wiredBytes,
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
        appPages: UInt64,
        wiredPages: UInt64,
        compressedPages: UInt64
    ) -> UInt64 {
        // Activity Monitor style approximation:
        // Memory Used = (App Memory + Wired Memory) + Compressed.
        let appMemory = appPages
        let wiredMemory = wiredPages
        let compressedMemory = compressedPages
        return appMemory + wiredMemory + compressedMemory
    }

    static func appMemoryPages(
        internalPages: UInt64
    ) -> UInt64 {
        internalPages
    }

    static func cachedPages(
        fileBackedPages: UInt64,
        purgeablePages: UInt64
    ) -> UInt64 {
        // Approximation based on vm_stat fields:
        // Cached Files ~= File-backed pages + Purgeable pages.
        fileBackedPages + purgeablePages
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

}
