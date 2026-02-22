import Foundation

public struct DiskUsageSample: Sendable, Equatable {
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

public protocol DiskUsageSampling: Sendable {
    func sampleUsage() throws -> DiskUsageSample
}

public enum DiskSamplingError: Error, Sendable {
    case unavailableCapacity
}

public struct SystemDiskUsageSampler: DiskUsageSampling {
    private let volumeURL: URL

    public init(volumeURL: URL = URL(fileURLWithPath: "/")) {
        self.volumeURL = volumeURL
    }

    public func sampleUsage() throws -> DiskUsageSample {
        let values = try volumeURL.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ])

        guard
            let totalCapacity = values.volumeTotalCapacity,
            let availableCapacity = values.volumeAvailableCapacity
        else {
            throw DiskSamplingError.unavailableCapacity
        }

        let totalBytes = UInt64(max(totalCapacity, 0))
        let availableBytes = UInt64(max(availableCapacity, 0))
        let usedBytes = totalBytes >= availableBytes ? totalBytes - availableBytes : 0

        return DiskUsageSample(usedBytes: usedBytes, totalBytes: totalBytes)
    }
}
