import Foundation

public protocol CPULoadSampling: Sendable {
    func sample() async throws -> CPULoadSample?
}

public actor CPULoadSampler: CPULoadSampling {
    private let ticksSampler: any CPUTicksSampling
    private let timeSource: any TimeSource
    private var previousTicks: CPUTicks?

    public init(
        ticksSampler: any CPUTicksSampling = SystemCPUTicksSampler(),
        timeSource: any TimeSource = SystemTimeSource()
    ) {
        self.ticksSampler = ticksSampler
        self.timeSource = timeSource
    }

    public func sample() async throws -> CPULoadSample? {
        let currentTicks = try ticksSampler.sample()

        guard let previousTicks else {
            self.previousTicks = currentTicks
            return nil
        }

        self.previousTicks = currentTicks

        guard let usage = CPULoadCalculator.usage(from: previousTicks, to: currentTicks) else {
            return nil
        }

        return CPULoadSample(timestamp: timeSource.now(), usage: usage)
    }
}
