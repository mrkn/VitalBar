import Foundation
import XCTest
@testable import VitalBarCore

final class CPULoadSamplerTests: XCTestCase {
    func testFirstSampleIsWarmupAndSecondReturnsUsage() async throws {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let timeSource = MutableTimeSource(now: base)

        let ticksSampler = SequenceCPUTicksSampler(
            ticks: [
                CPUTicks(user: 100, system: 50, idle: 50, nice: 0),
                CPUTicks(user: 140, system: 70, idle: 90, nice: 0),
            ]
        )

        let sampler = CPULoadSampler(ticksSampler: ticksSampler, timeSource: timeSource)

        let warmup = try await sampler.sample()
        let sample = try await sampler.sample()

        XCTAssertNil(warmup)
        XCTAssertEqual(sample?.timestamp, base)
        XCTAssertEqual(sample?.usage ?? -1, 0.6, accuracy: 0.0001)
    }
}
