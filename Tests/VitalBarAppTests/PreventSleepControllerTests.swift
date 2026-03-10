import IOKit.pwr_mgt
import XCTest
@testable import VitalBarApp

final class PreventSleepControllerTests: XCTestCase {
    func testEnableCreatesSystemAndDisplayAssertions() throws {
        let recorder = AssertionRecorder()
        let controller = PreventSleepController(client: recorder.client)

        try controller.setEnabled(true)

        XCTAssertTrue(controller.isEnabled())
        XCTAssertEqual(
            recorder.createdTypes,
            [
                kIOPMAssertionTypePreventUserIdleSystemSleep as String,
                kIOPMAssertionTypePreventUserIdleDisplaySleep as String,
            ]
        )
        XCTAssertEqual(recorder.createdNames, ["VitalBar Keep Mac Awake", "VitalBar Keep Mac Awake"])
    }

    func testDisableReleasesDisplayThenSystemAssertions() throws {
        let recorder = AssertionRecorder()
        let controller = PreventSleepController(client: recorder.client)

        try controller.setEnabled(true)
        try controller.setEnabled(false)

        XCTAssertFalse(controller.isEnabled())
        XCTAssertEqual(recorder.releasedIDs, [2, 1])
    }

    func testEnableRollsBackSystemAssertionWhenDisplayAssertionCreationFails() {
        let recorder = AssertionRecorder()
        recorder.createResults = [
            (kIOReturnSuccess, 1),
            (kIOReturnError, IOPMAssertionID(kIOPMNullAssertionID)),
        ]
        let controller = PreventSleepController(client: recorder.client)

        XCTAssertThrowsError(try controller.setEnabled(true))
        XCTAssertFalse(controller.isEnabled())
        XCTAssertEqual(recorder.releasedIDs, [1])
    }

    func testDisableLeavesSystemAssertionEnabledWhenSystemReleaseFails() throws {
        let recorder = AssertionRecorder()
        recorder.releaseResults = [
            2: kIOReturnSuccess,
            1: kIOReturnError,
        ]
        let controller = PreventSleepController(client: recorder.client)

        try controller.setEnabled(true)

        XCTAssertThrowsError(try controller.setEnabled(false))
        XCTAssertTrue(controller.isEnabled())
        XCTAssertEqual(recorder.releasedIDs, [2, 1])
    }
}

private final class AssertionRecorder: @unchecked Sendable {
    var createResults: [(IOReturn, IOPMAssertionID)] = [
        (kIOReturnSuccess, 1),
        (kIOReturnSuccess, 2),
    ]
    var releaseResults: [IOPMAssertionID: IOReturn] = [:]
    private(set) var createdTypes: [String] = []
    private(set) var createdNames: [String] = []
    private(set) var releasedIDs: [IOPMAssertionID] = []

    var client: PreventSleepAssertionClient {
        PreventSleepAssertionClient(
            create: { [weak self] assertionType, name in
                guard let self else {
                    return (kIOReturnError, IOPMAssertionID(kIOPMNullAssertionID))
                }

                createdTypes.append(assertionType as String)
                createdNames.append(name as String)
                if createResults.isEmpty {
                    return (kIOReturnError, IOPMAssertionID(kIOPMNullAssertionID))
                }
                return createResults.removeFirst()
            },
            release: { [weak self] assertionID in
                guard let self else {
                    return kIOReturnError
                }

                releasedIDs.append(assertionID)
                return releaseResults[assertionID] ?? kIOReturnSuccess
            }
        )
    }
}
