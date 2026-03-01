import Darwin
import Foundation
import VitalBarCore

struct HIDTemperatureSample {
    let product: String
    let celsius: Double
}

// Apple Silicon can expose temperature sensors through IOHID when SMC access
// is denied. This keeps temperatures available in environments where AppleSMC
// is restricted.
struct HIDTemperatureSampler: TemperatureSampling {
    private static let usagePage = 0xFF00
    private static let usage = 0x05
    private static let eventTypeTemperature = 0x0F
    private static let temperatureField = Int64(eventTypeTemperature << 16)
    private static let preferredOrderedIDs = ["cpu", "gpu", "soc"]

    private let api: HIDTemperatureAPI?

    init(api: HIDTemperatureAPI? = HIDTemperatureAPI.load()) {
        self.api = api
    }

    func sampleTemperatures() throws -> [TemperatureSensorReading] {
        guard let api else {
            return []
        }

        let preferredMatching: [String: Any] = [
            "PrimaryUsagePage": Self.usagePage,
            "PrimaryUsage": Self.usage,
        ]

        let preferredServices = collectServices(using: api, matching: preferredMatching)
        let services: [Any]
        if preferredServices.isEmpty {
            // Some systems do not expose temperature services with vendor usage
            // matching; scan all HID services and extract temperature events.
            services = collectServices(using: api, matching: nil)
        } else {
            services = preferredServices
        }

        guard !services.isEmpty else {
            return []
        }

        var samples: [HIDTemperatureSample] = []

        for service in services {
            let serviceRef = service as CFTypeRef
            guard
                let event = api.copyEvent(serviceRef, Int64(Self.eventTypeTemperature), 0, 0)
            else {
                continue
            }

            let value = api.eventFloatValue(event, Self.temperatureField)
            guard Self.isPlausibleTemperature(value) else {
                continue
            }

            let product = (api.copyProperty(serviceRef, "Product" as CFString) as? String) ?? "Temperature Sensor"
            samples.append(HIDTemperatureSample(product: product, celsius: value))
        }

        return Self.aggregate(samples: samples)
    }

    private func collectServices(using api: HIDTemperatureAPI, matching: [String: Any]?) -> [Any] {
        guard let client = api.create(kCFAllocatorDefault) else {
            return []
        }

        if let matching {
            api.setMatching(client, matching as CFDictionary)
        }

        guard let services = api.copyServices(client) else {
            return []
        }

        return (services as NSArray).map { $0 }
    }

    static func aggregate(samples: [HIDTemperatureSample]) -> [TemperatureSensorReading] {
        var grouped: [String: (sum: Double, count: Int, name: String)] = [:]

        for sample in samples where isRelevantSensor(sample.product) {
            let category = category(for: sample.product)
            let displayName = displayName(for: category, fallback: sample.product)
            let current = grouped[category] ?? (sum: 0.0, count: 0, name: displayName)
            grouped[category] = (
                sum: current.sum + sample.celsius,
                count: current.count + 1,
                name: current.name
            )
        }

        return preferredOrderedIDs.compactMap { id in
            guard let group = grouped[id], group.count > 0 else {
                return nil
            }
            return TemperatureSensorReading(
                id: id,
                name: group.name,
                celsius: group.sum / Double(group.count)
            )
        }
    }

    private static func isPlausibleTemperature(_ celsius: Double) -> Bool {
        celsius.isFinite && celsius > -20.0 && celsius < 130.0
    }

    private static func isRelevantSensor(_ productName: String) -> Bool {
        let lower = productName.lowercased()
        if lower.contains("battery") || lower.contains("gas gauge") {
            return false
        }

        return true
    }

    private static func category(for productName: String) -> String {
        let lower = productName.lowercased()
        if lower.contains("gpu") || lower.contains("g3d") || lower.contains("agx") || lower.contains("gfx") {
            return "gpu"
        }
        if lower.contains("cpu")
            || lower.contains("ecpu")
            || lower.contains("pcpu")
            || lower.contains("tdie")
            || lower.contains("efficiency")
            || lower.contains("performance")
        {
            return "cpu"
        }
        return "soc"
    }

    private static func displayName(for category: String, fallback: String) -> String {
        switch category {
        case "cpu":
            return "CPU Temperature"
        case "gpu":
            return "GPU Temperature"
        case "soc":
            return "SoC Temperature"
        default:
            return fallback
        }
    }
}

struct HIDTemperatureAPI {
    typealias CreateFn = @convention(c) (_ allocator: CFAllocator?) -> CFTypeRef?
    typealias SetMatchingFn = @convention(c) (_ client: CFTypeRef, _ matching: CFDictionary) -> Void
    typealias CopyServicesFn = @convention(c) (_ client: CFTypeRef) -> CFArray?
    typealias CopyPropertyFn = @convention(c) (_ service: CFTypeRef, _ property: CFString) -> CFTypeRef?
    typealias CopyEventFn = @convention(c) (
        _ service: CFTypeRef,
        _ type: Int64,
        _ matching: Int64,
        _ options: Int64
    ) -> CFTypeRef?
    typealias EventFloatValueFn = @convention(c) (_ event: CFTypeRef, _ field: Int64) -> Double

    let create: CreateFn
    let setMatching: SetMatchingFn
    let copyServices: CopyServicesFn
    let copyProperty: CopyPropertyFn
    let copyEvent: CopyEventFn
    let eventFloatValue: EventFloatValueFn

    static func load() -> HIDTemperatureAPI? {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else {
            return nil
        }

        guard
            let createSymbol = dlsym(handle, "IOHIDEventSystemClientCreate"),
            let setMatchingSymbol = dlsym(handle, "IOHIDEventSystemClientSetMatching"),
            let copyServicesSymbol = dlsym(handle, "IOHIDEventSystemClientCopyServices"),
            let copyPropertySymbol = dlsym(handle, "IOHIDServiceClientCopyProperty"),
            let copyEventSymbol = dlsym(handle, "IOHIDServiceClientCopyEvent"),
            let floatValueSymbol = dlsym(handle, "IOHIDEventGetFloatValue")
        else {
            return nil
        }

        return HIDTemperatureAPI(
            create: unsafeBitCast(createSymbol, to: CreateFn.self),
            setMatching: unsafeBitCast(setMatchingSymbol, to: SetMatchingFn.self),
            copyServices: unsafeBitCast(copyServicesSymbol, to: CopyServicesFn.self),
            copyProperty: unsafeBitCast(copyPropertySymbol, to: CopyPropertyFn.self),
            copyEvent: unsafeBitCast(copyEventSymbol, to: CopyEventFn.self),
            eventFloatValue: unsafeBitCast(floatValueSymbol, to: EventFloatValueFn.self)
        )
    }
}
