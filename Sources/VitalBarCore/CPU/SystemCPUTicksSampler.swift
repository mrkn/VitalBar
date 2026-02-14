import Darwin.Mach

public enum CPUSamplingError: Error, Sendable {
    case hostStatisticsFailed(code: kern_return_t)
}

public struct SystemCPUTicksSampler: CPUTicksSampling {
    public init() {}

    public func sample() throws -> CPUTicks {
        var cpuLoadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result: kern_return_t = withUnsafeMutablePointer(to: &cpuLoadInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { integerPointer in
                host_statistics(
                    mach_host_self(),
                    HOST_CPU_LOAD_INFO,
                    integerPointer,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            throw CPUSamplingError.hostStatisticsFailed(code: result)
        }

        let ticks = cpuLoadInfo.cpu_ticks
        return CPUTicks(
            user: UInt64(ticks.0),
            system: UInt64(ticks.1),
            idle: UInt64(ticks.2),
            nice: UInt64(ticks.3)
        )
    }
}
