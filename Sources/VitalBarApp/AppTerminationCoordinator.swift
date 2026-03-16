import AppKit

@MainActor
final class AppTerminationCoordinator {
    static let shared = AppTerminationCoordinator()

    private var shutdownHandler: (@MainActor () async -> Void)?
    private var isTerminationInFlight = false

    func register(shutdownHandler: @escaping @MainActor () async -> Void) {
        self.shutdownHandler = shutdownHandler
    }

    func requestTermination() -> NSApplication.TerminateReply {
        guard let shutdownHandler else {
            return .terminateNow
        }

        guard !isTerminationInFlight else {
            return .terminateLater
        }

        isTerminationInFlight = true

        Task { @MainActor in
            await shutdownHandler()
            isTerminationInFlight = false
            NSApp.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }
}
