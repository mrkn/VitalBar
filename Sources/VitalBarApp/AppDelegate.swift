import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appSubmenuController = SubmenuWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppTerminationCoordinator.shared.requestTermination()
    }
}
