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
    private var activeScreen: NSScreen?
    private var hideWorkItem: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []
    private var menuIsTracking = false

    init(model: SceneModel) {
        self.model = model
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
        root.onEnter = { [weak self] in self?.cancelScheduledHide() }
        root.onExit = { [weak self] in self?.scheduleHide(after: 0.58) }
        panel.contentView = root

        observers.append(NotificationCenter.default.addObserver(
            forName: .sceneHideShelf,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.hide() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.menuIsTracking = true
                self?.cancelScheduledHide()
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.menuIsTracking = false
                self?.scheduleHideIfPointerIsAway()
            }
        })
        reposition()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func show(source: Source = .shortcut) {
        cancelScheduledHide()
        guard !panel.isVisible else { return }
        let screen = screenContainingPointer() ?? NSScreen.main
        guard let screen else { return }
        activeScreen = screen
        let shown = shownFrame(on: screen)
        panel.setFrame(hiddenFrame(on: screen), display: false)
        panel.alphaValue = 0.92
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(shown, display: true)
            panel.animator().alphaValue = 1
        }
        scheduleHide(after: source == .edge ? 1.35 : 2.8)
    }

    func hide(animated: Bool = true) {
        cancelScheduledHide()
        guard panel.isVisible else { return }
        let screen = activeScreen ?? screenContainingPointer() ?? NSScreen.main
        guard let screen else {
            panel.orderOut(nil)
            return
        }
        let finish = { [weak panel] in
            panel?.orderOut(nil)
            panel?.alphaValue = 1
        }
        guard animated else {
            panel.setFrame(hiddenFrame(on: screen), display: false)
            finish()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.19
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

    func reposition() {
        let screen = screenContainingPointer() ?? activeScreen ?? NSScreen.main
        guard let screen else { return }
        activeScreen = screen
        panel.setFrame(panel.isVisible ? shownFrame(on: screen) : hiddenFrame(on: screen), display: true)
    }

    private func scheduleHide(after delay: TimeInterval) {
        guard panel.isVisible, !menuIsTracking else { return }
        cancelScheduledHide()
        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.menuIsTracking else { return }
            self.hide()
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func scheduleHideIfPointerIsAway() {
        guard panel.isVisible else { return }
        let generousFrame = panel.frame.insetBy(dx: -14, dy: -14)
        if !NSMouseInRect(NSEvent.mouseLocation, generousFrame, false) {
            scheduleHide(after: 0.58)
        }
    }

    private func cancelScheduledHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    private func shownFrame(on screen: NSScreen) -> NSRect {
        let frame = screen.visibleFrame
        let height = min(740, max(580, frame.height - 32))
        return NSRect(x: frame.minX + 12, y: frame.midY - height / 2, width: Self.width, height: height)
    }

    private func hiddenFrame(on screen: NSScreen) -> NSRect {
        var frame = shownFrame(on: screen)
        frame.origin.x = screen.frame.minX - Self.width - 18
        return frame
    }

    private func screenContainingPointer() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }
}
