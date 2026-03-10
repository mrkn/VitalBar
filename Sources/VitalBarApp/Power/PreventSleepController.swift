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

struct PreventSleepAssertionClient {
    var create: @Sendable (_ assertionType: CFString, _ name: CFString) -> (IOReturn, IOPMAssertionID)
    var release: @Sendable (_ assertionID: IOPMAssertionID) -> IOReturn

    static let live = PreventSleepAssertionClient(
        create: { assertionType, name in
            var assertionID = IOPMAssertionID(kIOPMNullAssertionID)
            let result = IOPMAssertionCreateWithName(
                assertionType,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                name,
                &assertionID
            )

            return (result, assertionID)
        },
        release: { assertionID in
            IOPMAssertionRelease(assertionID)
        }
    )
}

final class PreventSleepController: PreventSleepControlling {
    private let client: PreventSleepAssertionClient
    private var systemAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
    private var displayAssertionID = IOPMAssertionID(kIOPMNullAssertionID)

    init(client: PreventSleepAssertionClient = .live) {
        self.client = client
    }

    deinit {
        _ = try? releaseAssertionsIfNeeded()
    }

    func isEnabled() -> Bool {
        systemAssertionID != kIOPMNullAssertionID || displayAssertionID != kIOPMNullAssertionID
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try acquireAssertionsIfNeeded()
        } else {
            try releaseAssertionsIfNeeded()
        }
    }

    private func acquireAssertionsIfNeeded() throws {
        let assertionName = "VitalBar Keep Mac Awake" as CFString
        var createdSystemAssertionID: IOPMAssertionID?
        var createdDisplayAssertionID: IOPMAssertionID?

        do {
            if systemAssertionID == IOPMAssertionID(kIOPMNullAssertionID) {
                let assertionID = try createAssertion(
                    ofType: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                    name: assertionName
                )
                systemAssertionID = assertionID
                createdSystemAssertionID = assertionID
            }

            if displayAssertionID == IOPMAssertionID(kIOPMNullAssertionID) {
                let assertionID = try createAssertion(
                    ofType: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                    name: assertionName
                )
                displayAssertionID = assertionID
                createdDisplayAssertionID = assertionID
            }
        } catch {
            if let createdDisplayAssertionID {
                try? releaseAssertion(createdDisplayAssertionID)
                displayAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
            }

            if let createdSystemAssertionID {
                try? releaseAssertion(createdSystemAssertionID)
                systemAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
            }

            throw error
        }
    }

    @discardableResult
    private func releaseAssertionsIfNeeded() throws -> Bool {
        var releasedAny = false

        if displayAssertionID != IOPMAssertionID(kIOPMNullAssertionID) {
            try releaseAssertion(displayAssertionID)
            displayAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
            releasedAny = true
        }

        if systemAssertionID != IOPMAssertionID(kIOPMNullAssertionID) {
            try releaseAssertion(systemAssertionID)
            systemAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
            releasedAny = true
        }

        return releasedAny
    }

    private func createAssertion(ofType assertionType: CFString, name: CFString) throws -> IOPMAssertionID {
        let (result, assertionID) = client.create(assertionType, name)
        guard result == kIOReturnSuccess else {
            throw PreventSleepError.createAssertionFailed(code: result)
        }

        return assertionID
    }

    private func releaseAssertion(_ assertionID: IOPMAssertionID) throws -> Void {
        let result = client.release(assertionID)
        guard result == kIOReturnSuccess else {
            throw PreventSleepError.releaseAssertionFailed(code: result)
        }
    }
}
