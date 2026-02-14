import Darwin.Mach
import Foundation

public struct MemoryUsageSample: Sendable, Equatable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64

    public init(usedBytes: UInt64, totalBytes: UInt64) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
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

        let freePages = UInt64(vmStats.free_count) + UInt64(vmStats.speculative_count)
        let freeBytes = freePages * UInt64(pageSize)
        let usedBytes = totalMemory > freeBytes ? totalMemory - freeBytes : 0

        return MemoryUsageSample(usedBytes: usedBytes, totalBytes: totalMemory)
    }
}
