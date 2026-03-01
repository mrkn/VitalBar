import Foundation
import IOKit
import VitalBarCore

enum SMCTemperatureSamplingError: Error {
    case smcOpenFailed(code: kern_return_t)
    case smcCallFailed(code: kern_return_t)
    case invalidSMCKey
    case invalidSensorData
}

struct SMCTemperatureSampler: TemperatureSampling {
    private static let hidFallbackSampler = HIDTemperatureSampler()

    private static let sensorGroups: [(id: String, name: String, keys: [String])] = [
        ("cpu", "CPU Temperature", ["TC0P", "TC0E", "TCXC", "Tp0C", "Tp1C"]),
        ("gpu", "GPU Temperature", ["TG0P", "TG0D", "Tp0G", "Tp1G"]),
        ("soc", "SoC Temperature", ["Ts0P", "Tp0P", "Tm0P"]),
    ]

    func sampleTemperatures() throws -> [TemperatureSensorReading] {
        let smcReadings = (try? sampleWithSMC()) ?? []
        if !smcReadings.isEmpty {
            return smcReadings
        }

        return (try? Self.hidFallbackSampler.sampleTemperatures()) ?? []
    }

    private func sampleWithSMC() throws -> [TemperatureSensorReading] {
        guard let connection = try SMCConnection.openIfAvailable() else {
            return []
        }

        defer { connection.close() }

        return Self.sensorGroups.compactMap { sensor in
            sensor.keys.lazy
                .compactMap { key in try? connection.readTemperature(for: key) }
                .first(where: Self.isPlausibleTemperature)
                .map { TemperatureSensorReading(id: sensor.id, name: sensor.name, celsius: $0) }
        }
    }

    private static func isPlausibleTemperature(_ celsius: Double) -> Bool {
        celsius.isFinite && celsius > -20.0 && celsius < 130.0
    }
}

private final class SMCConnection {
    private static let kernelIndex: UInt32 = 2
    private static let readBytesCommand: UInt8 = 5
    private static let readKeyInfoCommand: UInt8 = 9

    private let connection: io_connect_t

    private init(connection: io_connect_t) {
        self.connection = connection
    }

    static func openIfAvailable() throws -> SMCConnection? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            return nil
        }

        defer {
            IOObjectRelease(service)
        }

        var connection: io_connect_t = 0
        let openResult = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard openResult == KERN_SUCCESS else {
            throw SMCTemperatureSamplingError.smcOpenFailed(code: openResult)
        }

        return SMCConnection(connection: connection)
    }

    func close() {
        IOServiceClose(connection)
    }

    func readTemperature(for key: String) throws -> Double {
        let smcKey = try Self.encode(key: key)

        var input = SMCKeyData()
        var output = SMCKeyData()

        input.key = smcKey
        input.data8 = Self.readKeyInfoCommand
        try call(input: &input, output: &output)

        let dataType = output.keyInfo.dataType
        let dataTypeText = Self.decodeFourCC(dataType)
        let swappedDataTypeText = Self.decodeFourCC(dataType.byteSwapped)
        let dataSize = min(Int(output.keyInfo.dataSize), 32)
        guard dataSize >= 2 else {
            throw SMCTemperatureSamplingError.invalidSensorData
        }

        input = SMCKeyData()
        input.key = smcKey
        input.data8 = Self.readBytesCommand
        input.keyInfo.dataSize = output.keyInfo.dataSize
        try call(input: &input, output: &output)

        let bytes = output.bytes.asArray(prefixCount: dataSize)
        if dataTypeText == "sp78" || swappedDataTypeText == "sp78" {
            return try Self.decodeSP78(bytes)
        }
        if dataTypeText == "flt " || swappedDataTypeText == "flt " {
            return try Self.decodeFloat(bytes)
        }

        throw SMCTemperatureSamplingError.invalidSensorData
    }

    private func call(input: inout SMCKeyData, output: inout SMCKeyData) throws {
        var outputSize = MemoryLayout<SMCKeyData>.stride
        let inputSize = MemoryLayout<SMCKeyData>.stride

        let result = withUnsafePointer(to: &input) { inputPointer in
            withUnsafeMutablePointer(to: &output) { outputPointer in
                IOConnectCallStructMethod(
                    connection,
                    Self.kernelIndex,
                    inputPointer,
                    inputSize,
                    outputPointer,
                    &outputSize
                )
            }
        }

        guard result == KERN_SUCCESS else {
            throw SMCTemperatureSamplingError.smcCallFailed(code: result)
        }
    }

    private static func encode(key: String) throws -> UInt32 {
        let bytes = Array(key.utf8)
        guard bytes.count == 4 else {
            throw SMCTemperatureSamplingError.invalidSMCKey
        }

        return bytes.reduce(UInt32(0)) { (result, byte) in
            (result << 8) | UInt32(byte)
        }
    }

    private static func decodeFourCC(_ code: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF),
        ]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    private static func decodeSP78(_ bytes: [UInt8]) throws -> Double {
        guard bytes.count >= 2 else {
            throw SMCTemperatureSamplingError.invalidSensorData
        }

        let raw = Int16(bitPattern: (UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
        return Double(raw) / 256.0
    }

    private static func decodeFloat(_ bytes: [UInt8]) throws -> Double {
        guard bytes.count >= 4 else {
            throw SMCTemperatureSamplingError.invalidSensorData
        }

        let bits = (UInt32(bytes[0]) << 24)
            | (UInt32(bytes[1]) << 16)
            | (UInt32(bytes[2]) << 8)
            | UInt32(bytes[3])
        return Double(Float32(bitPattern: bits))
    }
}

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCKeyData {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes = SMCByteBuffer32()
}

private struct SMCByteBuffer32 {
    var b00: UInt8 = 0
    var b01: UInt8 = 0
    var b02: UInt8 = 0
    var b03: UInt8 = 0
    var b04: UInt8 = 0
    var b05: UInt8 = 0
    var b06: UInt8 = 0
    var b07: UInt8 = 0
    var b08: UInt8 = 0
    var b09: UInt8 = 0
    var b10: UInt8 = 0
    var b11: UInt8 = 0
    var b12: UInt8 = 0
    var b13: UInt8 = 0
    var b14: UInt8 = 0
    var b15: UInt8 = 0
    var b16: UInt8 = 0
    var b17: UInt8 = 0
    var b18: UInt8 = 0
    var b19: UInt8 = 0
    var b20: UInt8 = 0
    var b21: UInt8 = 0
    var b22: UInt8 = 0
    var b23: UInt8 = 0
    var b24: UInt8 = 0
    var b25: UInt8 = 0
    var b26: UInt8 = 0
    var b27: UInt8 = 0
    var b28: UInt8 = 0
    var b29: UInt8 = 0
    var b30: UInt8 = 0
    var b31: UInt8 = 0

    func asArray(prefixCount: Int) -> [UInt8] {
        let safeCount = max(0, min(prefixCount, 32))
        return withUnsafeBytes(of: self) { rawBuffer in
            Array(rawBuffer.prefix(safeCount))
        }
    }
}
