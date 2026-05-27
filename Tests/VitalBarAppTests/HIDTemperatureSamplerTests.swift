import XCTest
@testable import VitalBarApp

final class HIDTemperatureSamplerTests: XCTestCase {
    func testSampleTemperaturesReusesPreferredClientAcrossCalls() throws {
        HIDTemperatureAPITestHook.reset(preferredClientReturnsNoServices: false)
        let api = HIDTemperatureAPI(
            create: { _ in
                Unmanaged.passRetained(HIDTemperatureAPITestHook.create())
            },
            setMatching: { _, _ in },
            copyServices: { _ in
                Unmanaged.passRetained(HIDTemperatureAPITestHook.copyServices(for: "client-1"))
            },
            copyProperty: { _, _ in
                Unmanaged.passRetained("PMU tdie2" as CFTypeRef)
            },
            copyEvent: { _, _, _, _ in
                Unmanaged.passRetained("event" as CFTypeRef)
            },
            eventFloatValue: { _, _ in
                56.0
            }
        )
        let sampler = HIDTemperatureSampler(api: api)

        let first = try sampler.sampleTemperatures()
        let second = try sampler.sampleTemperatures()

        XCTAssertEqual(first, second)
        XCTAssertEqual(HIDTemperatureAPITestHook.createCount, 1)
    }

    func testSampleTemperaturesReusesFallbackClientAcrossCalls() throws {
        HIDTemperatureAPITestHook.reset(preferredClientReturnsNoServices: true)
        let api = HIDTemperatureAPI(
            create: { _ in
                Unmanaged.passRetained(HIDTemperatureAPITestHook.create())
            },
            setMatching: { _, _ in },
            copyServices: { client in
                Unmanaged.passRetained(HIDTemperatureAPITestHook.copyServices(for: client as? String))
            },
            copyProperty: { _, _ in
                Unmanaged.passRetained("PMU tdev4" as CFTypeRef)
            },
            copyEvent: { _, _, _, _ in
                Unmanaged.passRetained("event" as CFTypeRef)
            },
            eventFloatValue: { _, _ in
                44.0
            }
        )
        let sampler = HIDTemperatureSampler(api: api)

        let first = try sampler.sampleTemperatures()
        let second = try sampler.sampleTemperatures()

        XCTAssertEqual(first, second)
        XCTAssertEqual(HIDTemperatureAPITestHook.createCount, 2)
    }

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

private enum HIDTemperatureAPITestHook {
    private static let storage = LockedState()

    static var createCount: Int {
        storage.createCount
    }

    static func reset(preferredClientReturnsNoServices: Bool) {
        storage.reset(preferredClientReturnsNoServices: preferredClientReturnsNoServices)
    }

    static func create() -> CFTypeRef {
        storage.create()
    }

    static func copyServices(for client: String?) -> CFArray {
        storage.copyServices(for: client)
    }

    struct State {
        var createCount = 0
        var preferredClientReturnsNoServices = false
    }
}

private final class LockedState: @unchecked Sendable {
    private let lock = NSLock()
    private var state = HIDTemperatureAPITestHook.State()

    var createCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return state.createCount
    }

    func reset(preferredClientReturnsNoServices: Bool) {
        lock.lock()
        state = HIDTemperatureAPITestHook.State(
            createCount: 0,
            preferredClientReturnsNoServices: preferredClientReturnsNoServices
        )
        lock.unlock()
    }

    func create() -> CFTypeRef {
        lock.lock()
        state.createCount += 1
        let client = "client-\(state.createCount)" as CFTypeRef
        lock.unlock()
        return client
    }

    func copyServices(for client: String?) -> CFArray {
        lock.lock()
        defer { lock.unlock() }

        if state.preferredClientReturnsNoServices, client == "client-1" {
            return [] as CFArray
        }

        return ["service"] as CFArray
    }
}
