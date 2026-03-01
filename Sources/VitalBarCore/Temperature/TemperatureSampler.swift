import Foundation

public struct TemperatureSensorReading: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let celsius: Double

    public init(id: String, name: String, celsius: Double) {
        self.id = id
        self.name = name
        self.celsius = celsius
    }
}

public protocol TemperatureSampling: Sendable {
    func sampleTemperatures() throws -> [TemperatureSensorReading]
}

// VitalBarCore keeps this sampler intentionally conservative so it remains
// platform-neutral and test-friendly. App targets can inject richer samplers.
public struct SystemTemperatureSampler: TemperatureSampling {
    public init() {}

    public func sampleTemperatures() throws -> [TemperatureSensorReading] {
        []
    }
}
