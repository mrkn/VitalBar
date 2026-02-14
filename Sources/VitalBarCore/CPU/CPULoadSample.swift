import Foundation

public struct CPULoadSample: Sendable, Equatable {
    public let timestamp: Date
    public let usage: Double

    public init(timestamp: Date, usage: Double) {
        self.timestamp = timestamp
        self.usage = min(max(usage, 0.0), 1.0)
    }

    public var percentage: Double {
        usage * 100.0
    }
}
