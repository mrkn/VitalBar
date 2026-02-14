public enum CPULoadCalculator {
    public static func usage(from previous: CPUTicks, to current: CPUTicks) -> Double? {
        guard
            let userDelta = delta(previous.user, current.user),
            let systemDelta = delta(previous.system, current.system),
            let idleDelta = delta(previous.idle, current.idle),
            let niceDelta = delta(previous.nice, current.nice)
        else {
            return nil
        }

        let busy = userDelta + systemDelta + niceDelta
        let total = busy + idleDelta
        guard total > 0 else {
            return nil
        }

        return min(max(Double(busy) / Double(total), 0.0), 1.0)
    }

    private static func delta(_ previous: UInt64, _ current: UInt64) -> UInt64? {
        guard current >= previous else {
            return nil
        }
        return current - previous
    }
}
