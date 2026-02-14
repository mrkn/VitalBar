import Foundation

public struct MetricSample: Sendable, Equatable {
    public let metricID: String
    public let timestamp: Date
    public let value: Double

    public init(metricID: String, timestamp: Date, value: Double) {
        self.metricID = metricID
        self.timestamp = timestamp
        self.value = value
    }
}
