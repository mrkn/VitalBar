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
}
