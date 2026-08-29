import AppKit
import Carbon
import ServiceManagement
import SceneCore

@MainActor
final class SceneAppDelegate: NSObject, NSApplicationDelegate {
    private let model = SceneModel()
    private var panelController: ScenePanelController?
    private var statusItem: NSStatusItem?
    private var hotKey: GlobalHotKey?
    private var edgeRevealController: EdgeRevealController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        var launchEdge = model.preferences.dockEdge
        if let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--dock-edge=") }),
           let requested = DockEdge(rawValue: String(argument.dropFirst("--dock-edge=".count))) {
            launchEdge = requested
        }
        panelController = ScenePanelController(model: model, edge: launchEdge)
        edgeRevealController = EdgeRevealController(edge: launchEdge) { [weak self] in
            self?.model.activate()
            self?.panelController?.show(source: .edge)
        }
        makeStatusItem()
        hotKey = GlobalHotKey(
            keyCode: UInt32(kVK_ANSI_B),
            modifiers: UInt32(optionKey),
            identifier: 1
        ) { [weak self] in
            DispatchQueue.main.async { self?.togglePanel() }
        }
        if hotKey == nil {
            model.status = "⌥B is unavailable; move the pointer to the far-\(launchEdge.rawValue) edge."
        }
        if CommandLine.arguments.contains("lifecycle-check") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { NSApp.terminate(nil) }
        } else if !CommandLine.arguments.contains("hidden") {
            model.activate()
            panelController?.show()
        }
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        panelController?.reposition()
        edgeRevealController?.rebuild()
    }

    @objc private func togglePanel() {
        if panelController?.isVisible == false { model.activate() }
        panelController?.toggle()
    }

    @objc private func openLibrary() {
        NSWorkspace.shared.open(URL(fileURLWithPath: model.preferences.libraryPath, isDirectory: true))
    }

    @objc private func selectDockEdge(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let edge = DockEdge(rawValue: raw) else { return }
        guard model.setDockEdge(edge) else { return }
        panelController?.setEdge(edge)
        edgeRevealController?.setEdge(edge)
        makeStatusMenu()
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
        } catch {
            model.status = error.localizedDescription
        }
    }

    private func makeStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "books.vertical.fill", accessibilityDescription: "Scene")
        statusItem = item
        makeStatusMenu()
    }

    private func makeStatusMenu() {
        guard let item = statusItem else { return }
        let menu = NSMenu()
        let show = NSMenuItem(title: "Show Scene\t⌥B", action: #selector(togglePanel), keyEquivalent: "")
        show.target = self
        menu.addItem(show)
        let library = NSMenuItem(title: "Open Book Folder", action: #selector(openLibrary), keyEquivalent: "")
        library.target = self
        menu.addItem(library)
        let sideMenu = NSMenu()
        for edge in DockEdge.allCases {
            let side = NSMenuItem(title: edge.displayName, action: #selector(selectDockEdge(_:)), keyEquivalent: "")
            side.target = self
            side.representedObject = edge.rawValue
            side.state = model.preferences.dockEdge == edge ? .on : .off
            sideMenu.addItem(side)
        }
        let sideItem = NSMenuItem(title: "Dock Side", action: nil, keyEquivalent: "")
        sideItem.submenu = sideMenu
        menu.addItem(sideItem)
        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLoginItem(_:)), keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        login.target = self
        menu.addItem(login)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Scene", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        item.menu = menu
    }
}
