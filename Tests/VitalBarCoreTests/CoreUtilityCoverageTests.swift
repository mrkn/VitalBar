import Foundation
import XCTest
@testable import VitalBarCore

final class CoreUtilityCoverageTests: XCTestCase {
    func testMetricSampleStoresValues() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let sample = MetricSample(metricID: "cpu", timestamp: timestamp, value: 0.42)

        XCTAssertEqual(sample.metricID, "cpu")
        XCTAssertEqual(sample.timestamp, timestamp)
        XCTAssertEqual(sample.value, 0.42, accuracy: 0.0001)
    }

    func testSystemTimeSourceReturnsCurrentDate() {
        let source = SystemTimeSource()
        let now = source.now()

        XCTAssertLessThan(abs(now.timeIntervalSinceNow), 2.0)
    }

    func testCPULoadSampleClampsAndComputesPercentage() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

        let low = CPULoadSample(timestamp: timestamp, usage: -1)
        XCTAssertEqual(low.usage, 0.0, accuracy: 0.0001)

        let high = CPULoadSample(timestamp: timestamp, usage: 2)
        XCTAssertEqual(high.usage, 1.0, accuracy: 0.0001)
        XCTAssertEqual(high.percentage, 100.0, accuracy: 0.0001)
    }

    func testSystemCPUTicksSamplerReturnsTicks() throws {
        let sampler = SystemCPUTicksSampler()
        let ticks = try sampler.sample()

        XCTAssertGreaterThanOrEqual(ticks.user, 0)
        XCTAssertGreaterThanOrEqual(ticks.system, 0)
        XCTAssertGreaterThanOrEqual(ticks.idle, 0)
        XCTAssertGreaterThanOrEqual(ticks.nice, 0)
    }


    func testDiskUsageSampleStoresValues() {
        let sample = DiskUsageSample(usedBytes: 412, totalBytes: 1_000)

        XCTAssertEqual(sample.usedBytes, 412)
        XCTAssertEqual(sample.totalBytes, 1_000)
        XCTAssertEqual(sample.usage, 0.412, accuracy: 0.0001)
    }

    func testSystemDiskUsageSamplerReturnsNormalizedUsage() throws {
        let sampler = SystemDiskUsageSampler()
        let sample = try sampler.sampleUsage()

        XCTAssertGreaterThan(sample.totalBytes, 0)
        XCTAssertLessThanOrEqual(sample.usedBytes, sample.totalBytes)
        XCTAssertGreaterThanOrEqual(sample.usage, 0.0)
        XCTAssertLessThanOrEqual(sample.usage, 1.0)
    }

    func testSystemMemoryUsageSamplerReturnsNormalizedUsage() throws {
        let sampler = SystemMemoryUsageSampler()
        let sample = try sampler.sampleUsage()
        let usage = sample.usage

        XCTAssertGreaterThan(sample.totalBytes, 0)
        XCTAssertLessThanOrEqual(sample.usedBytes, sample.totalBytes)
        XCTAssertLessThanOrEqual(sample.cachedBytes, sample.totalBytes)
        XCTAssertLessThanOrEqual(sample.compressedBytes, sample.totalBytes)
        XCTAssertGreaterThanOrEqual(sample.swapUsedBytes, 0)
        XCTAssertGreaterThanOrEqual(usage, 0.0)
        XCTAssertLessThanOrEqual(usage, 1.0)
    }

    func testMemoryUsageSampleStoresExtendedValues() {
        let sample = MemoryUsageSample(
            usedBytes: 10,
            totalBytes: 16,
            appBytes: 4,
            wiredBytes: 3,
            cachedBytes: 3,
            compressedBytes: 2,
            swapUsedBytes: 1,
            pressureLevel: .warning
        )

        XCTAssertEqual(sample.usedBytes, 10)
        XCTAssertEqual(sample.totalBytes, 16)
        XCTAssertEqual(sample.appBytes, 4)
        XCTAssertEqual(sample.wiredBytes, 3)
        XCTAssertEqual(sample.cachedBytes, 3)
        XCTAssertEqual(sample.compressedBytes, 2)
        XCTAssertEqual(sample.swapUsedBytes, 1)
        XCTAssertEqual(sample.pressureLevel, .warning)
        XCTAssertEqual(sample.usage, 0.625, accuracy: 0.0001)
    }

    func testUsedPagesIncludesCompressedPages() {
        let usedPages = SystemMemoryUsageSampler.usedPagesIncludingCompressed(
            appPages: 700,
            wiredPages: 300,
            compressedPages: 150
        )

        // app + wired + compressed
        XCTAssertEqual(usedPages, 1_150)
    }

    func testAppMemoryPagesUsesInternalPages() {
        let appPages = SystemMemoryUsageSampler.appMemoryPages(
            internalPages: 764_497
        )

        XCTAssertEqual(appPages, 764_497)
    }

    func testCachedPagesUsesFileBackedAndPurgeable() {
        let cachedPages = SystemMemoryUsageSampler.cachedPages(
            fileBackedPages: 226_829,
            purgeablePages: 20_415
        )

        XCTAssertEqual(cachedPages, 247_244)
    }
}
