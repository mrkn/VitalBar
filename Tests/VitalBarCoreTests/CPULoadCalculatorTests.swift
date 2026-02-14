import XCTest
@testable import VitalBarCore

final class CPULoadCalculatorTests: XCTestCase {
    func testUsageIsCalculatedFromTickDelta() {
        let previous = CPUTicks(user: 100, system: 50, idle: 50, nice: 0)
        let current = CPUTicks(user: 140, system: 70, idle: 90, nice: 0)

        let usage = CPULoadCalculator.usage(from: previous, to: current)

        XCTAssertEqual(usage ?? -1, 0.6, accuracy: 0.0001)
    }

    func testUsageReturnsNilWhenNoDeltaExists() {
        let ticks = CPUTicks(user: 100, system: 50, idle: 50, nice: 0)

        XCTAssertNil(CPULoadCalculator.usage(from: ticks, to: ticks))
    }

    func testUsageReturnsNilWhenCountersRollback() {
        let previous = CPUTicks(user: 100, system: 50, idle: 50, nice: 0)
        let current = CPUTicks(user: 90, system: 60, idle: 70, nice: 0)

        XCTAssertNil(CPULoadCalculator.usage(from: previous, to: current))
    }
}
