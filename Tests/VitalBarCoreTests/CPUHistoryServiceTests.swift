import Foundation
import XCTest
@testable import VitalBarCore

final class CPUHistoryServiceTests: XCTestCase {
    func testSnapshotsArePublishedInOrder() async {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let timeSource = MutableTimeSource(now: start)

        let sampler = FakeCPULoadSampler(results: [
            .success(CPULoadSample(timestamp: start, usage: 0.2)),
            .success(CPULoadSample(timestamp: start.addingTimeInterval(1), usage: 0.4)),
        ])
        let memorySampler = FakeMemoryUsageSampler(results: [
            .success(MemoryUsageSample(usedBytes: 8, totalBytes: 16)),
            .success(MemoryUsageSample(usedBytes: 10, totalBytes: 16)),
        ])
        let temperatureSampler = FakeTemperatureSampler(results: [
            .success([
                TemperatureSensorReading(id: "cpu", name: "CPU Temperature", celsius: 58.5),
            ]),
            .success([
                TemperatureSensorReading(id: "cpu", name: "CPU Temperature", celsius: 60.0),
                TemperatureSensorReading(id: "gpu", name: "GPU Temperature", celsius: 57.0),
            ]),
        ])

        let service = CPUHistoryService(
            sampler: sampler,
            memorySampler: memorySampler,
            temperatureSampler: temperatureSampler,
            historyCapacity: 120,
            sampleInterval: .seconds(10),
            staleAfter: .seconds(5),
            timeSource: timeSource
        )

        let stream = await service.snapshots()

        let collector = Task { () -> [CPUHistorySnapshot] in
            var snapshots: [CPUHistorySnapshot] = []
            for await snapshot in stream.prefix(3) {
                snapshots.append(snapshot)
            }
            return snapshots
        }

        await service.performTick()
        timeSource.advance(by: 1)
        await service.performTick()

        let snapshots = await collector.value

        XCTAssertEqual(snapshots.count, 3)
        XCTAssertEqual(snapshots[1].history.count, 1)
        XCTAssertEqual(snapshots[1].latest?.usage ?? -1, 0.2, accuracy: 0.0001)
        XCTAssertEqual(snapshots[1].memoryUsage, MemoryUsageSample(usedBytes: 8, totalBytes: 16))
        XCTAssertEqual(
            snapshots[1].temperatures,
            [TemperatureSensorReading(id: "cpu", name: "CPU Temperature", celsius: 58.5)]
        )
        XCTAssertEqual(snapshots[2].history.count, 2)
        XCTAssertEqual(snapshots[2].latest?.usage ?? -1, 0.4, accuracy: 0.0001)
        XCTAssertEqual(snapshots[2].memoryUsage, MemoryUsageSample(usedBytes: 10, totalBytes: 16))
        XCTAssertEqual(
            snapshots[2].temperatures,
            [
                TemperatureSensorReading(id: "cpu", name: "CPU Temperature", celsius: 60.0),
                TemperatureSensorReading(id: "gpu", name: "GPU Temperature", celsius: 57.0),
            ]
        )
    }

    func testServiceBecomesStaleAfterNoSuccessfulUpdates() async {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let timeSource = MutableTimeSource(now: start)

        let sampler = FakeCPULoadSampler(results: [
            .success(CPULoadSample(timestamp: start, usage: 0.2)),
            .failure(TestSamplingError.failure),
        ])
        let memorySampler = FakeMemoryUsageSampler(results: [
            .success(MemoryUsageSample(usedBytes: 4, totalBytes: 10)),
            .failure(TestSamplingError.failure),
        ])
        let temperatureSampler = FakeTemperatureSampler(results: [
            .success([
                TemperatureSensorReading(id: "cpu", name: "CPU Temperature", celsius: 52.0),
            ]),
            .failure(TestSamplingError.failure),
        ])

        let service = CPUHistoryService(
            sampler: sampler,
            memorySampler: memorySampler,
            temperatureSampler: temperatureSampler,
            historyCapacity: 120,
            sampleInterval: .seconds(10),
            staleAfter: .seconds(5),
            timeSource: timeSource
        )

        let stream = await service.snapshots()

        let collector = Task { () -> [CPUHistorySnapshot] in
            var snapshots: [CPUHistorySnapshot] = []
            for await snapshot in stream.prefix(3) {
                snapshots.append(snapshot)
            }
            return snapshots
        }

        await service.performTick()
        timeSource.advance(by: 6)
        await service.performTick()

        let snapshots = await collector.value
        let staleSnapshot = snapshots[2]

        XCTAssertTrue(staleSnapshot.isStale)
        XCTAssertEqual(staleSnapshot.consecutiveFailures, 1)
        XCTAssertNotNil(staleSnapshot.lastErrorDescription)
        XCTAssertEqual(staleSnapshot.memoryUsage, MemoryUsageSample(usedBytes: 4, totalBytes: 10))
        XCTAssertEqual(
            staleSnapshot.temperatures,
            [TemperatureSensorReading(id: "cpu", name: "CPU Temperature", celsius: 52.0)]
        )
    }

    func testStartSchedulesTimerDrivenTicks() async {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let timeSource = MutableTimeSource(now: start)

        let sample = CPULoadSample(timestamp: start, usage: 0.3)
        let sampler = FakeCPULoadSampler(
            results: [.success(sample)],
            fallback: .success(sample)
        )
        let memorySampler = FakeMemoryUsageSampler(
            results: [.success(MemoryUsageSample(usedBytes: 3, totalBytes: 10))],
            fallback: .success(MemoryUsageSample(usedBytes: 3, totalBytes: 10))
        )
        let temperatureSampler = FakeTemperatureSampler(
            results: [.success([TemperatureSensorReading(id: "cpu", name: "CPU Temperature", celsius: 61.0)])],
            fallback: .success([TemperatureSensorReading(id: "cpu", name: "CPU Temperature", celsius: 61.0)])
        )

        let service = CPUHistoryService(
            sampler: sampler,
            memorySampler: memorySampler,
            temperatureSampler: temperatureSampler,
            historyCapacity: 120,
            sampleInterval: .milliseconds(20),
            staleAfter: .seconds(5),
            timeSource: timeSource
        )

        let stream = await service.snapshots()
        let expectation = XCTestExpectation(description: "Receives timer-driven snapshots")

        let collector = Task {
            var received = 0
            for await _ in stream {
                received += 1
                if received >= 4 {
                    expectation.fulfill()
                    break
                }
            }
        }

        await service.start()
        await fulfillment(of: [expectation], timeout: 1.0)
        await service.stop()
        collector.cancel()
    }

    func testStopFinishesActiveSnapshotStreams() async {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let timeSource = MutableTimeSource(now: start)
        let sample = CPULoadSample(timestamp: start, usage: 0.3)
        let service = CPUHistoryService(
            sampler: FakeCPULoadSampler(results: [.success(sample)], fallback: .success(sample)),
            memorySampler: FakeMemoryUsageSampler(results: [.success(MemoryUsageSample(usedBytes: 3, totalBytes: 10))]),
            temperatureSampler: FakeTemperatureSampler(
                results: [.success([TemperatureSensorReading(id: "cpu", name: "CPU Temperature", celsius: 61.0)])]
            ),
            historyCapacity: 120,
            sampleInterval: .seconds(10),
            staleAfter: .seconds(5),
            timeSource: timeSource
        )

        let stream = await service.snapshots()
        var iterator = stream.makeAsyncIterator()

        _ = await iterator.next()
        await service.stop()

        let next = await iterator.next()
        XCTAssertNil(next)
    }
}
