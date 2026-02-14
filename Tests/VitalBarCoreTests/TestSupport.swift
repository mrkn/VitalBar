import Foundation
@testable import VitalBarCore

final class MutableTimeSource: TimeSource, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(now: Date) {
        current = now
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        current = current.addingTimeInterval(interval)
        lock.unlock()
    }
}

final class SequenceCPUTicksSampler: CPUTicksSampling, @unchecked Sendable {
    private let lock = NSLock()
    private var ticks: [CPUTicks]
    private let fallback: CPUTicks

    init(ticks: [CPUTicks], fallback: CPUTicks? = nil) {
        precondition(!ticks.isEmpty || fallback != nil, "Provide ticks or fallback")
        self.ticks = ticks
        self.fallback = fallback ?? ticks.last!
    }

    func sample() throws -> CPUTicks {
        lock.lock()
        defer { lock.unlock() }

        if !ticks.isEmpty {
            return ticks.removeFirst()
        }

        return fallback
    }
}

actor FakeCPULoadSampler: CPULoadSampling {
    private var results: [Result<CPULoadSample?, Error>]
    private let fallback: Result<CPULoadSample?, Error>?

    init(
        results: [Result<CPULoadSample?, Error>],
        fallback: Result<CPULoadSample?, Error>? = nil
    ) {
        self.results = results
        self.fallback = fallback
    }

    func sample() async throws -> CPULoadSample? {
        let next: Result<CPULoadSample?, Error>

        if !results.isEmpty {
            next = results.removeFirst()
        } else if let fallback {
            next = fallback
        } else {
            next = .success(nil)
        }

        return try next.get()
    }
}

final class FakeMemoryUsageSampler: MemoryUsageSampling, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<MemoryUsageSample, Error>]
    private let fallback: Result<MemoryUsageSample, Error>?

    init(
        results: [Result<MemoryUsageSample, Error>],
        fallback: Result<MemoryUsageSample, Error>? = nil
    ) {
        self.results = results
        self.fallback = fallback
    }

    func sampleUsage() throws -> MemoryUsageSample {
        lock.lock()
        defer { lock.unlock() }

        let next: Result<MemoryUsageSample, Error>
        if !results.isEmpty {
            next = results.removeFirst()
        } else if let fallback {
            next = fallback
        } else {
            next = .success(MemoryUsageSample(usedBytes: 0, totalBytes: 1))
        }

        return try next.get()
    }
}

enum TestSamplingError: Error {
    case failure
}
