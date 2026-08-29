import AppKit
import SceneCore

final class EdgeRevealView: NSView {
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

    override func mouseEntered(with event: NSEvent) {
        onEnter?()
    }

    override func mouseExited(with event: NSEvent) {
        onExit?()
    }
}

@MainActor
final class EdgeRevealController {
    private var windows: [NSPanel] = []
    private var globalMouseMonitor: Any?
    private var armed = true
    private var latched = false
    private var edge: DockEdge
    private let reveal: () -> Void

    init(edge: DockEdge, reveal: @escaping () -> Void) {
        self.edge = edge
        self.reveal = reveal
        rebuild()
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            let point = event.locationInWindow
            DispatchQueue.main.async { self?.handlePointerPosition(point) }
        }
        handlePointerPosition(NSEvent.mouseLocation)
    }

    deinit {
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
    }

    func rebuild() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let frame = screen.visibleFrame
            let x = edge == .left ? screen.frame.minX : screen.frame.maxX - 2
            let window = NSPanel(
                contentRect: NSRect(x: x, y: frame.minY, width: 2, height: frame.height),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            let view = EdgeRevealView(frame: NSRect(x: 0, y: 0, width: 2, height: frame.height))
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.01).cgColor
            view.onEnter = { [weak self] in self?.scheduleReveal() }
            view.onExit = { [weak self] in self?.handlePointerPosition(NSEvent.mouseLocation) }
            window.contentView = view
            window.level = .statusBar
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isOpaque = false
            window.backgroundColor = NSColor.black.withAlphaComponent(0.01)
            window.hasShadow = false
            // Two pixels behave like a native screen-edge hot zone. The local
            // tracking area is the reliable path; the global monitor above is
            // a permission-free backup for fast pointer motion.
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            window.orderFrontRegardless()
            return window
        }
    }

    func setEdge(_ edge: DockEdge) {
        guard self.edge != edge else { return }
        self.edge = edge
        latched = false
        rebuild()
        handlePointerPosition(NSEvent.mouseLocation)
    }

    private func handlePointerPosition(_ point: CGPoint) {
        let atEdge = NSScreen.screens.contains { screen in
            guard NSMouseInRect(point, screen.frame, false) else { return false }
            return edge == .left
                ? point.x <= screen.frame.minX + 2
                : point.x >= screen.frame.maxX - 2
        }
        if atEdge {
            scheduleReveal()
        } else {
            let stillNearEdge = NSScreen.screens.contains { screen in
                guard NSMouseInRect(point, screen.frame, false) else { return false }
                return edge == .left
                    ? point.x <= screen.frame.minX + 48
                    : point.x >= screen.frame.maxX - 48
            }
            if !stillNearEdge { latched = false }
        }
    }

    private func scheduleReveal() {
        guard armed, !latched else { return }
        latched = true
        reveal()
    }
}
