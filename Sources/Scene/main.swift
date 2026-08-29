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

if arguments.first == "link-smoke" {
    let result: Int32 = MainActor.assumeIsolated {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "scene-link-smoke-\(UUID().uuidString)", directoryHint: .isDirectory)
        let preferencesURL = root.appending(path: "library.json")
        defer { try? FileManager.default.removeItem(at: root) }
        let preferences = ScenePreferences(
            libraryPath: "/tmp/books",
            featuredTitles: [],
            readerByFilename: [:],
            links: []
        )
        let model = SceneModel(preferences: preferences, preferencesURL: preferencesURL)
        guard !model.saveLink(id: nil, title: "Bad", subtitle: "", urlText: "file:///tmp/no"),
              model.saveLink(id: nil, title: "Practice", subtitle: "Daily", urlText: "https://example.com/practice"),
              let saved = SceneLibrary.loadPreferences(from: preferencesURL).links.first,
              model.saveLink(id: saved.id, title: "Practice now", subtitle: "Daily", urlText: "https://example.com/now"),
              SceneLibrary.loadPreferences(from: preferencesURL).links.first?.title == "Practice now",
              model.remove(saved),
              SceneLibrary.loadPreferences(from: preferencesURL).links.isEmpty
        else {
            fputs("SCENE LINK VERDICT: FAIL\n", stderr)
            return 1
        }
        print("SCENE LINK VERDICT: PASS")
        return 0
    }
    exit(result)
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
            SceneView(model: model, startsAddingLink: arguments.contains("--add-entry"))
                .frame(width: 266, height: 740),
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
