import XCTest
@testable import VitalBarCore

final class HistoryBufferTests: XCTestCase {
    func testBufferKeepsInsertionOrderWithinCapacity() {
        var buffer = HistoryBuffer<Int>(capacity: 3)

        buffer.append(1)
        buffer.append(2)
        buffer.append(3)

        XCTAssertEqual(buffer.elements, [1, 2, 3])
        XCTAssertEqual(buffer.latest, 3)
    }

    func testBufferDropsOldestElementWhenCapacityExceeded() {
        var buffer = HistoryBuffer<Int>(capacity: 3)

        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        buffer.append(4)

        XCTAssertEqual(buffer.elements, [2, 3, 4])
        XCTAssertEqual(buffer.latest, 4)
        XCTAssertEqual(buffer.count, 3)
    }
}
