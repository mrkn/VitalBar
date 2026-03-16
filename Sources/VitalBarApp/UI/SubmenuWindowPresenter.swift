import AppKit
import SwiftUI

@MainActor
final class SubmenuWindowController {
    private var panel: SubmenuPanel?
    private var hostingView: HoverTrackingHostingView<AnyView>?
    private weak var observedParentWindow: NSWindow?
    private var observerTokens: [NSObjectProtocol] = []
    private var horizontalOffset: CGFloat = 8
    private var verticalOffset: CGFloat = 0

    func present(
        relativeTo anchorView: NSView,
        horizontalOffset: CGFloat,
        verticalOffset: CGFloat,
        onHoverChanged: ((Bool) -> Void)?,
        content: AnyView
    ) {
        self.horizontalOffset = horizontalOffset
        self.verticalOffset = verticalOffset

        guard let parentWindow = anchorView.window else {
            DispatchQueue.main.async { [weak self, weak anchorView] in
                guard let self, let anchorView else {
                    return
                }

                self.present(
                    relativeTo: anchorView,
                    horizontalOffset: horizontalOffset,
                    verticalOffset: verticalOffset,
                    onHoverChanged: onHoverChanged,
                    content: content
                )
            }
            return
        }

        let panel = panel ?? makePanel()
        let hostingView = hostingView ?? makeHostingView()
        hostingView.rootView = content
        hostingView.onHoverChanged = onHoverChanged
        panel.contentView = hostingView
        self.hostingView = hostingView

        hostingView.layoutSubtreeIfNeeded()
        let fittingSize = hostingView.fittingSize
        panel.setContentSize(
            NSSize(
                width: max(180, fittingSize.width),
                height: max(1, fittingSize.height)
            )
        )

        if panel.parent !== parentWindow {
            panel.parent?.removeChildWindow(panel)
            parentWindow.addChildWindow(panel, ordered: .above)
        }

        updatePanelFrame(relativeTo: anchorView, in: parentWindow, panel: panel)
        panel.orderFront(nil)
        observeFrameChanges(of: parentWindow, anchorView: anchorView)
    }

    func close() {
        removeObservers()

        if let panel, let parentWindow = panel.parent {
            parentWindow.removeChildWindow(panel)
        }

        panel?.orderOut(nil)
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
        HoverTrackingHostingView(rootView: AnyView(EmptyView()))
    }

    private func observeFrameChanges(of parentWindow: NSWindow, anchorView: NSView) {
        guard observedParentWindow !== parentWindow else {
            return
        }

        removeObservers()
        observedParentWindow = parentWindow

        observerTokens.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: parentWindow,
            queue: .main
        ) { [weak self, weak anchorView] _ in
            Task { @MainActor [weak self, weak anchorView] in
                self?.repositionPanel(relativeTo: anchorView)
            }
        })

        observerTokens.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: parentWindow,
            queue: .main
        ) { [weak self, weak anchorView] _ in
            Task { @MainActor [weak self, weak anchorView] in
                self?.repositionPanel(relativeTo: anchorView)
            }
        })
    }

    private func repositionPanel(relativeTo anchorView: NSView?) {
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
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func removeObservers() {
        observerTokens.forEach { NotificationCenter.default.removeObserver($0) }
        observerTokens.removeAll()
        observedParentWindow = nil
    }
}

struct SubmenuWindowPresenter<Content: View>: NSViewRepresentable {
    let controller: SubmenuWindowController
    @Binding var isPresented: Bool
    var horizontalOffset: CGFloat = 8
    var verticalOffset: CGFloat = 0
    var onHoverChanged: ((Bool) -> Void)?
    let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(
            controller: controller,
            isPresented: $isPresented,
            onHoverChanged: onHoverChanged,
            content: content
        )
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
        private let controller: SubmenuWindowController
        private var isPresented: Binding<Bool>
        fileprivate var onHoverChanged: ((Bool) -> Void)?
        fileprivate var content: () -> Content
        fileprivate var horizontalOffset: CGFloat = 8
        fileprivate var verticalOffset: CGFloat = 0
        private weak var anchorView: NSView?

        init(
            controller: SubmenuWindowController,
            isPresented: Binding<Bool>,
            onHoverChanged: ((Bool) -> Void)?,
            content: @escaping () -> Content
        ) {
            self.controller = controller
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
            controller.close()
        }

        private func presentIfNeeded() {
            guard let anchorView else {
                return
            }

            controller.present(
                relativeTo: anchorView,
                horizontalOffset: horizontalOffset,
                verticalOffset: verticalOffset,
                onHoverChanged: onHoverChanged,
                content: AnyView(content())
            )
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
