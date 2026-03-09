import Foundation
import IOKit.pwr_mgt

protocol PreventSleepControlling {
    func isEnabled() -> Bool
    func setEnabled(_ enabled: Bool) throws
}

enum PreventSleepError: LocalizedError {
    case createAssertionFailed(code: IOReturn)
    case releaseAssertionFailed(code: IOReturn)

    var errorDescription: String? {
        switch self {
        case let .createAssertionFailed(code):
            return "Failed to prevent sleep (\(code))."
        case let .releaseAssertionFailed(code):
            return "Failed to restore sleep (\(code))."
        }
    }
}

final class PreventSleepController: PreventSleepControlling {
    private var assertionID = IOPMAssertionID(kIOPMNullAssertionID)

    deinit {
        _ = try? releaseAssertionIfNeeded()
    }

    func isEnabled() -> Bool {
        assertionID != kIOPMNullAssertionID
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try acquireAssertionIfNeeded()
        } else {
            try releaseAssertionIfNeeded()
        }
    }

    private func acquireAssertionIfNeeded() throws {
        guard assertionID == IOPMAssertionID(kIOPMNullAssertionID) else {
            return
        }

        var assertionID = IOPMAssertionID(kIOPMNullAssertionID)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "VitalBar Keep Mac Awake" as CFString,
            &assertionID
        )

        guard result == kIOReturnSuccess else {
            throw PreventSleepError.createAssertionFailed(code: result)
        }

        self.assertionID = assertionID
    }

    @discardableResult
    private func releaseAssertionIfNeeded() throws -> Bool {
        guard assertionID != IOPMAssertionID(kIOPMNullAssertionID) else {
            return false
        }

        let currentAssertionID = assertionID
        assertionID = IOPMAssertionID(kIOPMNullAssertionID)

        let result = IOPMAssertionRelease(currentAssertionID)
        guard result == kIOReturnSuccess else {
            assertionID = currentAssertionID
            throw PreventSleepError.releaseAssertionFailed(code: result)
        }

        return true
    }
}
