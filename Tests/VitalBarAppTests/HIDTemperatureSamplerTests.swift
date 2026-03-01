import XCTest
@testable import VitalBarApp

final class HIDTemperatureSamplerTests: XCTestCase {
    func testAggregateMapsPMUTdieToCPUAndFiltersBatterySensors() {
        let readings = HIDTemperatureSampler.aggregate(
            samples: [
                HIDTemperatureSample(product: "PMU tdie2", celsius: 56.0),
                HIDTemperatureSample(product: "gas gauge battery", celsius: 29.0),
            ]
        )

        XCTAssertEqual(readings.count, 1)
        XCTAssertEqual(readings[0].id, "cpu")
        XCTAssertEqual(readings[0].name, "CPU Temperature")
        XCTAssertEqual(readings[0].celsius, 56.0, accuracy: 0.0001)
    }

    func testAggregateOrdersCPUGPUAndSocAndAveragesEachGroup() {
        let readings = HIDTemperatureSampler.aggregate(
            samples: [
                HIDTemperatureSample(product: "PMU tdie1", celsius: 52.0),
                HIDTemperatureSample(product: "PMU tdie2", celsius: 56.0),
                HIDTemperatureSample(product: "AGX GPU sensor", celsius: 48.0),
                HIDTemperatureSample(product: "PMU tdev4", celsius: 44.0),
            ]
        )

        XCTAssertEqual(readings.map(\.id), ["cpu", "gpu", "soc"])
        XCTAssertEqual(readings[0].celsius, 54.0, accuracy: 0.0001)
        XCTAssertEqual(readings[1].celsius, 48.0, accuracy: 0.0001)
        XCTAssertEqual(readings[2].celsius, 44.0, accuracy: 0.0001)
    }
}
