import AppKit

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
    private var revealWorkItem: DispatchWorkItem?
    private var armed = false
    private let reveal: () -> Void

    init(reveal: @escaping () -> Void) {
        self.reveal = reveal
        rebuild()
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            let point = event.locationInWindow
            DispatchQueue.main.async { self?.handlePointerPosition(point) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
            guard let self else { return }
            self.armed = true
            self.handlePointerPosition(NSEvent.mouseLocation)
        }
    }

    deinit {
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
    }

    func rebuild() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let frame = screen.visibleFrame
            let window = NSPanel(
                contentRect: NSRect(x: frame.minX, y: frame.minY, width: 2, height: frame.height),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            let view = EdgeRevealView(frame: NSRect(x: 0, y: 0, width: 2, height: frame.height))
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.01).cgColor
            view.onEnter = { [weak self] in self?.scheduleReveal() }
            view.onExit = { [weak self] in self?.cancelReveal() }
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

    private func handlePointerPosition(_ point: CGPoint) {
        let atEdge = NSScreen.screens.contains {
            NSMouseInRect(point, $0.frame, false) && point.x <= $0.frame.minX + 2
        }
        atEdge ? scheduleReveal() : cancelReveal()
    }

    private func scheduleReveal() {
        guard armed else { return }
        guard revealWorkItem == nil else { return }
        let item = DispatchWorkItem { [weak self] in
            self?.revealWorkItem = nil
            self?.reveal()
        }
        revealWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: item)
    }

    private func cancelReveal() {
        revealWorkItem?.cancel()
        revealWorkItem = nil
    }
}
