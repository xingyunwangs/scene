import AppKit
import QuartzCore
import SceneCore
import SwiftUI

extension Notification.Name {
    static let sceneHideShelf = Notification.Name("com.sovereign.scene.hide-shelf")
}

final class ScenePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private final class SceneTrackingView: NSView {
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?
    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        tracking = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) { onEnter?() }
    override func mouseExited(with event: NSEvent) { onExit?() }
}

@MainActor
final class ScenePanelController {
    enum Source { case edge, shortcut }

    private static let width: CGFloat = 266
    private let panel: ScenePanel
    private let model: SceneModel
    private var edge: DockEdge
    private var activeScreen: NSScreen?
    private var observers: [NSObjectProtocol] = []
    private var mouseMonitors: [Any] = []
    private var menuIsTracking = false
    private var isEdgePreview = false
    private var isAnimatingReveal = false
    private var isHiding = false
    private var transitionID = 0

    init(model: SceneModel, edge: DockEdge) {
        self.model = model
        self.edge = edge
        panel = ScenePanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 760),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.title = "Scene Shelf"
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isRestorable = false
        panel.isMovableByWindowBackground = false
        panel.animationBehavior = .none

        let root = SceneTrackingView(frame: panel.contentView?.bounds ?? .zero)
        let hosting = NSHostingView(rootView: SceneView(model: model) { [weak panel] in
            guard let panel else { return }
            NotificationCenter.default.post(name: .sceneHideShelf, object: panel)
        })
        hosting.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: root.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        root.onExit = { [weak self] in self?.hideIfPointerIsAway() }
        panel.contentView = root

        observers.append(NotificationCenter.default.addObserver(
            forName: .sceneHideShelf,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.menuIsTracking = true
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.menuIsTracking = false
                self?.hideIfPointerIsAway()
            }
        })
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { [weak self] _ in
            DispatchQueue.main.async {
                guard self?.isEdgePreview == true else { return }
                self?.hideIfPointerIsAway()
            }
        }) {
            mouseMonitors.append(monitor)
        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { [weak self] event in
            MainActor.assumeIsolated {
                guard self?.isEdgePreview == true else { return }
                self?.hideIfPointerIsAway()
            }
            return event
        }) {
            mouseMonitors.append(monitor)
        }
        reposition()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        mouseMonitors.forEach(NSEvent.removeMonitor)
    }

    func show(source: Source = .shortcut) {
        let wasHiding = isHiding
        guard !panel.isVisible || wasHiding else { return }
        isHiding = false
        transitionID &+= 1
        let revealID = transitionID
        isEdgePreview = source == .edge
        let screen = screenContainingPointer() ?? NSScreen.main
        guard let screen else { return }
        activeScreen = screen
        let shown = shownFrame(on: screen)
        isAnimatingReveal = true
        if !panel.isVisible {
            panel.setFrame(hiddenFrame(on: screen), display: false)
        }
        panel.alphaValue = 0.92
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0 : 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(shown, display: true)
            panel.animator().alphaValue = 1
        } completionHandler: { [weak self] in
            DispatchQueue.main.async {
                guard self?.transitionID == revealID else { return }
                self?.isAnimatingReveal = false
                if self?.isEdgePreview == true { self?.hideIfPointerIsAway() }
            }
        }
    }

    func hide(animated: Bool = true) {
        guard panel.isVisible, !isHiding, !menuIsTracking else { return }
        isHiding = true
        transitionID &+= 1
        let hideID = transitionID
        let screen = activeScreen ?? screenContainingPointer() ?? NSScreen.main
        guard let screen else {
            panel.orderOut(nil)
            return
        }
        let finish = { [weak self, weak panel] in
            guard self?.transitionID == hideID else { return }
            panel?.orderOut(nil)
            panel?.alphaValue = 1
            self?.isEdgePreview = false
            self?.isAnimatingReveal = false
            self?.isHiding = false
        }
        guard animated, !reduceMotion else {
            panel.setFrame(hiddenFrame(on: screen), display: false)
            finish()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(hiddenFrame(on: screen), display: true)
            panel.animator().alphaValue = 0.9
        } completionHandler: {
            DispatchQueue.main.async(execute: finish)
        }
    }

    func toggle() {
        panel.isVisible ? hide() : show(source: .shortcut)
    }

    var isVisible: Bool { panel.isVisible }

    func setEdge(_ edge: DockEdge) {
        guard self.edge != edge else { return }
        if panel.isVisible { hide(animated: false) }
        self.edge = edge
        reposition()
    }

    func reposition() {
        let screen = screenContainingPointer() ?? activeScreen ?? NSScreen.main
        guard let screen else { return }
        activeScreen = screen
        panel.setFrame(panel.isVisible ? shownFrame(on: screen) : hiddenFrame(on: screen), display: true)
    }

    private func hideIfPointerIsAway() {
        guard panel.isVisible, !menuIsTracking else { return }
        let generousFrame = panel.frame.insetBy(dx: -14, dy: -14)
        if !NSMouseInRect(NSEvent.mouseLocation, generousFrame, false) {
            hide()
        }
    }

    private func shownFrame(on screen: NSScreen) -> NSRect {
        let frame = screen.visibleFrame
        let height = min(740, max(580, frame.height - 32))
        let x = edge == .left ? frame.minX + 12 : frame.maxX - Self.width - 12
        return NSRect(x: x, y: frame.midY - height / 2, width: Self.width, height: height)
    }

    private func hiddenFrame(on screen: NSScreen) -> NSRect {
        var frame = shownFrame(on: screen)
        frame.origin.x = edge == .left
            ? screen.frame.minX - Self.width - 18
            : screen.frame.maxX + 18
        return frame
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func screenContainingPointer() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }
}
