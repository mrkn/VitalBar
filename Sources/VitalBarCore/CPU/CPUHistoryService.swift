import Foundation

public struct CPUHistorySnapshot: Sendable, Equatable {
    public let history: [CPULoadSample]
    public let latest: CPULoadSample?
    public let memoryUsage: MemoryUsageSample?
    public let diskUsage: DiskUsageSample?
    public let temperatures: [TemperatureSensorReading]
    public let lastSuccessfulSampleAt: Date?
    public let isStale: Bool
    public let consecutiveFailures: Int
    public let lastErrorDescription: String?

    public init(
        history: [CPULoadSample],
        latest: CPULoadSample?,
        memoryUsage: MemoryUsageSample?,
        diskUsage: DiskUsageSample?,
        temperatures: [TemperatureSensorReading] = [],
        lastSuccessfulSampleAt: Date?,
        isStale: Bool,
        consecutiveFailures: Int,
        lastErrorDescription: String?
    ) {
        self.history = history
        self.latest = latest
        self.memoryUsage = memoryUsage
        self.diskUsage = diskUsage
        self.temperatures = temperatures
        self.lastSuccessfulSampleAt = lastSuccessfulSampleAt
        self.isStale = isStale
        self.consecutiveFailures = consecutiveFailures
        self.lastErrorDescription = lastErrorDescription
    }
}

public protocol CPUHistoryStreaming: Sendable {
    func start() async
    func stop() async
    func snapshots() async -> AsyncStream<CPUHistorySnapshot>
}

public actor CPUHistoryService: CPUHistoryStreaming {
    public static let defaultHistoryCapacity = 120
    public static let defaultSampleInterval: Duration = .seconds(1)
    public static let defaultStaleAfter: Duration = .seconds(5)

    private let sampler: any CPULoadSampling
    private let memorySampler: any MemoryUsageSampling
    private let diskSampler: any DiskUsageSampling
    private let temperatureSampler: any TemperatureSampling
    private let timeSource: any TimeSource
    private let sampleInterval: Duration
    private let staleAfter: TimeInterval

    private var history: HistoryBuffer<CPULoadSample>
    private var latestMemoryUsage: MemoryUsageSample?
    private var latestDiskUsage: DiskUsageSample?
    private var latestTemperatures: [TemperatureSensorReading] = []
    private var lastSuccessfulSampleAt: Date?
    private var consecutiveFailures = 0
    private var lastErrorDescription: String?

    private var workerTask: Task<Void, Never>?
    private var subscribers: [UUID: AsyncStream<CPUHistorySnapshot>.Continuation] = [:]

    public init(
        sampler: any CPULoadSampling,
        memorySampler: any MemoryUsageSampling = SystemMemoryUsageSampler(),
        diskSampler: any DiskUsageSampling = SystemDiskUsageSampler(),
        temperatureSampler: any TemperatureSampling = SystemTemperatureSampler(),
        historyCapacity: Int = CPUHistoryService.defaultHistoryCapacity,
        sampleInterval: Duration = CPUHistoryService.defaultSampleInterval,
        staleAfter: Duration = CPUHistoryService.defaultStaleAfter,
        timeSource: any TimeSource = SystemTimeSource()
    ) {
        self.sampler = sampler
        self.memorySampler = memorySampler
        self.history = HistoryBuffer(capacity: historyCapacity)
        self.diskSampler = diskSampler
        self.temperatureSampler = temperatureSampler
        self.sampleInterval = sampleInterval
        self.staleAfter = Self.timeInterval(from: staleAfter)
        self.timeSource = timeSource
    }

    deinit {
        workerTask?.cancel()
    }

    public func start() async {
        guard workerTask == nil else {
            return
        }

        workerTask = Task { [sampleInterval] in
            while !Task.isCancelled {
                await self.performTick()

                do {
                    try await Task.sleep(for: sampleInterval)
                } catch {
                    break
                }
            }
        }
    }

    public func stop() async {
        let task = workerTask
        workerTask = nil
        task?.cancel()

        let activeSubscribers = Array(subscribers.values)
        subscribers.removeAll()
        for continuation in activeSubscribers {
            continuation.finish()
        }

        await task?.value
    }

    public func snapshots() async -> AsyncStream<CPUHistorySnapshot> {
        AsyncStream { continuation in
            let identifier = UUID()
            addSubscriber(id: identifier, continuation: continuation)
        }
    }

    public func performTick() async {
        let referenceTime = timeSource.now()

        do {
            if let sample = try await sampler.sample() {
                history.append(sample)
                lastSuccessfulSampleAt = sample.timestamp
                consecutiveFailures = 0
                lastErrorDescription = nil
            }
        } catch {
            consecutiveFailures += 1
            lastErrorDescription = String(describing: error)
        }

        if let memoryUsage = try? memorySampler.sampleUsage() {
            latestMemoryUsage = memoryUsage
        }

        if let diskUsage = try? diskSampler.sampleUsage() {
            latestDiskUsage = diskUsage
        }

        if let temperatures = try? temperatureSampler.sampleTemperatures() {
            latestTemperatures = temperatures
        }

        broadcastSnapshot(at: referenceTime)
    }

    private func addSubscriber(
        id: UUID,
        continuation: AsyncStream<CPUHistorySnapshot>.Continuation
    ) {
        continuation.onTermination = { [weak self] _ in
            Task {
                await self?.removeSubscriber(id: id)
            }
        }

        subscribers[id] = continuation
        continuation.yield(buildSnapshot(at: timeSource.now()))
    }

    private func removeSubscriber(id: UUID) {
        subscribers[id] = nil
    }

    private func broadcastSnapshot(at referenceTime: Date) {
        let snapshot = buildSnapshot(at: referenceTime)
        for continuation in subscribers.values {
            continuation.yield(snapshot)
        }
    }

    private func buildSnapshot(at referenceTime: Date) -> CPUHistorySnapshot {
        CPUHistorySnapshot(
            history: history.elements,
            latest: history.latest,
            memoryUsage: latestMemoryUsage,
            diskUsage: latestDiskUsage,
            temperatures: latestTemperatures,
            lastSuccessfulSampleAt: lastSuccessfulSampleAt,
            isStale: staleState(at: referenceTime),
            consecutiveFailures: consecutiveFailures,
            lastErrorDescription: lastErrorDescription
        )
    }

    private func staleState(at referenceTime: Date) -> Bool {
        guard let lastSuccessfulSampleAt else {
            return false
        }

        return referenceTime.timeIntervalSince(lastSuccessfulSampleAt) >= staleAfter
    }

    private static func timeInterval(from duration: Duration) -> TimeInterval {
        let components = duration.components
        let seconds = TimeInterval(components.seconds)
        let attoseconds = TimeInterval(components.attoseconds)
        return seconds + (attoseconds / 1_000_000_000_000_000_000)
    }
}
