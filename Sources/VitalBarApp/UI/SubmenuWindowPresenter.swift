import AppKit
import SwiftUI

struct SubmenuWindowPresenter<Content: View>: NSViewRepresentable {
    @Binding var isPresented: Bool
    var horizontalOffset: CGFloat = 8
    var verticalOffset: CGFloat = 0
    var onHoverChanged: ((Bool) -> Void)?
    let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onHoverChanged: onHoverChanged, content: content)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.postsFrameChangedNotifications = true
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.horizontalOffset = horizontalOffset
        context.coordinator.verticalOffset = verticalOffset
        context.coordinator.onHoverChanged = onHoverChanged
        context.coordinator.content = content
        context.coordinator.update(from: nsView, isPresented: isPresented)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.close()
    }

    @MainActor
    final class Coordinator: NSObject {
        private var isPresented: Binding<Bool>
        fileprivate var onHoverChanged: ((Bool) -> Void)?
        fileprivate var content: () -> Content
        fileprivate var horizontalOffset: CGFloat = 8
        fileprivate var verticalOffset: CGFloat = 0
        private weak var anchorView: NSView?
        private var panel: SubmenuPanel?
        private var hostingView: HoverTrackingHostingView<AnyView>?
        private weak var observedParentWindow: NSWindow?

        init(
            isPresented: Binding<Bool>,
            onHoverChanged: ((Bool) -> Void)?,
            content: @escaping () -> Content
        ) {
            self.isPresented = isPresented
            self.onHoverChanged = onHoverChanged
            self.content = content
        }

        func attach(to view: NSView) {
            anchorView = view
        }

        func update(from view: NSView, isPresented: Bool) {
            anchorView = view

            if isPresented {
                presentIfNeeded()
            } else {
                close()
            }
        }

        func close() {
            removeObservers()

            if let panel {
                if let parentWindow = panel.parent {
                    parentWindow.removeChildWindow(panel)
                }

                panel.orderOut(nil)
                self.panel = nil
            }

            hostingView = nil
        }

        private func presentIfNeeded() {
            guard let anchorView else {
                return
            }

            guard let parentWindow = anchorView.window else {
                DispatchQueue.main.async { [weak self] in
                    self?.presentIfNeeded()
                }
                return
            }

            let panel = panel ?? makePanel()
            let hostingView = hostingView ?? makeHostingView()
            hostingView.rootView = AnyView(content())
            panel.contentView = hostingView
            self.hostingView = hostingView

            hostingView.layoutSubtreeIfNeeded()
            let fittingSize = hostingView.fittingSize
            let contentSize = NSSize(
                width: max(180, fittingSize.width),
                height: max(1, fittingSize.height)
            )
            panel.setContentSize(contentSize)

            if panel.parent !== parentWindow {
                panel.parent?.removeChildWindow(panel)
                parentWindow.addChildWindow(panel, ordered: .above)
            }

            updatePanelFrame(relativeTo: anchorView, in: parentWindow, panel: panel)
            panel.orderFront(nil)
            observeFrameChanges(of: parentWindow)
        }

        private func makePanel() -> SubmenuPanel {
            let panel = SubmenuPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.hidesOnDeactivate = false
            panel.level = .popUpMenu
            panel.collectionBehavior = [.transient, .moveToActiveSpace, .ignoresCycle]
            self.panel = panel
            return panel
        }

        private func makeHostingView() -> HoverTrackingHostingView<AnyView> {
            let hostingView = HoverTrackingHostingView(rootView: AnyView(content()))
            hostingView.onHoverChanged = { [weak self] isHovered in
                self?.onHoverChanged?(isHovered)
            }
            return hostingView
        }

        private func observeFrameChanges(of parentWindow: NSWindow) {
            guard observedParentWindow !== parentWindow else {
                return
            }

            removeObservers()
            observedParentWindow = parentWindow

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleParentWindowFrameChange),
                name: NSWindow.didMoveNotification,
                object: parentWindow
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleParentWindowFrameChange),
                name: NSWindow.didResizeNotification,
                object: parentWindow
            )
        }

        @objc
        private func handleParentWindowFrameChange() {
            repositionPanel()
        }

        private func repositionPanel() {
            guard
                let anchorView,
                let parentWindow = anchorView.window,
                let panel
            else {
                return
            }

            updatePanelFrame(relativeTo: anchorView, in: parentWindow, panel: panel)
        }

        private func updatePanelFrame(relativeTo anchorView: NSView, in parentWindow: NSWindow, panel: NSPanel) {
            let anchorFrame = anchorView.convert(anchorView.bounds, to: nil)
            let anchorScreenFrame = parentWindow.convertToScreen(anchorFrame)
            let visibleFrame = parentWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .infinite
            let opensRight = anchorScreenFrame.maxX + horizontalOffset + panel.frame.width <= visibleFrame.maxX
            let x = opensRight
                ? anchorScreenFrame.maxX + horizontalOffset
                : anchorScreenFrame.minX - horizontalOffset - panel.frame.width
            let preferredY = anchorScreenFrame.maxY - panel.frame.height + verticalOffset
            let y = min(
                max(preferredY, visibleFrame.minY),
                visibleFrame.maxY - panel.frame.height
            )
            let origin = NSPoint(x: x, y: y)
            panel.setFrameOrigin(origin)
        }

        private func removeObservers() {
            if let observedParentWindow {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSWindow.didMoveNotification,
                    object: observedParentWindow
                )
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSWindow.didResizeNotification,
                    object: observedParentWindow
                )
                self.observedParentWindow = nil
            }
        }
    }
}

private final class SubmenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class HoverTrackingHostingView<Content: View>: NSHostingView<Content> {
    var onHoverChanged: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverChanged?(false)
    }
}
