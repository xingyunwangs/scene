import AppKit
import SceneCore

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.first == "catalog" {
    let preferences = SceneLibrary.loadPreferences()
    for book in SceneLibrary.scan(preferences) {
        print("\(book.isFeatured ? "*" : " ")\t\(book.reader.rawValue)\t\(book.fileURL.path)")
    }
    exit(0)
}

if arguments.first == "shot" {
    let destination = arguments.count > 1 ? arguments[1] : "scene.png"
    let code: Int32 = MainActor.assumeIsolated {
        _ = NSApplication.shared
        NSApplication.shared.setActivationPolicy(.accessory)
        var preferences = SceneLibrary.loadPreferences()
        if arguments.contains("--dock-edge=right") { preferences.dockEdge = .right }
        if arguments.contains("--dock-edge=left") { preferences.dockEdge = .left }
        let model = SceneModel(preferences: preferences)
        model.refresh()
        return ViewSnapshot.write(
            SceneView(model: model).frame(width: 266, height: 740),
            size: CGSize(width: 266, height: 740),
            to: destination
        ) ? 0 : 1
    }
    exit(code)
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = SceneAppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) {
        application.run()
    }
}
