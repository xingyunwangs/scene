import AppKit
import Combine
import SceneCore

@MainActor
final class SceneModel: ObservableObject {
    @Published private(set) var books: [SceneBook] = []
    @Published var showAll = false
    @Published var status = ""
    @Published var search = ""
    @Published private(set) var preferences: ScenePreferences
    private var hasLoadedLibrary = false

    init(preferences: ScenePreferences? = nil) {
        self.preferences = preferences ?? SceneLibrary.loadPreferences()
    }

    func activate() {
        guard !hasLoadedLibrary else { return }
        hasLoadedLibrary = true
        guard !CommandLine.arguments.contains("interaction-smoke") else { return }
        refresh()
    }

    var visibleBooks: [SceneBook] {
        let base = showAll ? books : books.filter(\.isFeatured)
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    func refresh() {
        hasLoadedLibrary = true
        books = SceneLibrary.scan(preferences)
        if books.isEmpty {
            status = "No EPUB or PDF found in \(preferences.libraryPath)."
        }
    }

    func open(_ book: SceneBook, reader override: ReaderChoice? = nil, remember: Bool = false) {
        let reader = override ?? book.reader
        do {
            try ReaderRouter.open(book.fileURL, with: reader)
            status = "Opened \(book.title) in \(reader.displayName)."
            if remember { setReader(reader, for: book) }
            NotificationCenter.default.post(name: .sceneHideShelf, object: nil)
        } catch {
            status = error.localizedDescription
            NSSound.beep()
        }
    }

    func setReader(_ reader: ReaderChoice, for book: SceneBook) {
        preferences.readerByFilename[book.fileURL.lastPathComponent] = reader
        do {
            try SceneLibrary.savePreferences(preferences)
            refresh()
            status = "\(book.title) will use \(reader.displayName)."
        } catch {
            status = "Could not remember reader: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func setDockEdge(_ edge: DockEdge) -> Bool {
        guard preferences.dockEdge != edge else { return true }
        let previous = preferences.dockEdge
        preferences.dockEdge = edge
        do {
            try SceneLibrary.savePreferences(preferences)
            status = "Scene now lives on the \(edge.displayName.lowercased()) edge."
            return true
        } catch {
            preferences.dockEdge = previous
            status = "Could not remember the Dock side: \(error.localizedDescription)"
            return false
        }
    }

    func remember(_ book: SceneBook) {
        let source = SourceContext(
            appName: "Scene",
            bundleIdentifier: "com.sovereign.Scene",
            title: book.title,
            fileURL: book.fileURL
        )
        let draft = CaptureDraft(kind: .thought, body: "", source: source)
        do {
            let handoff = try HandoffCenter.write(draft)
            try MirrorBridge.openMirror(with: handoff)
            status = "Sent \(book.title) to Mirror."
            NotificationCenter.default.post(name: .sceneHideShelf, object: nil)
        } catch {
            status = "Mirror handoff failed: \(error.localizedDescription)"
        }
    }

    func openLibby() {
        guard let url = URL(string: "https://libbyapp.com") else { return }
        NSWorkspace.shared.open(url)
        status = "Opened Libby. Loans remain in Libby."
        NotificationCenter.default.post(name: .sceneHideShelf, object: nil)
    }
}

enum ReaderRouterError: LocalizedError {
    case missingReader(String)
    case unreadableBook

    var errorDescription: String? {
        switch self {
        case let .missingReader(name): "\(name) is not installed. Choose another reader from the book menu."
        case .unreadableBook: "The book is missing or cannot be read. The source was not changed."
        }
    }
}

enum ReaderRouter {
    static func open(_ book: URL, with reader: ReaderChoice) throws {
        guard FileManager.default.isReadableFile(atPath: book.path) else { throw ReaderRouterError.unreadableBook }
        if reader == .systemDefault {
            NSWorkspace.shared.open(book)
            return
        }
        let bundleID = reader == .appleBooks ? "com.apple.iBooksX" : "com.bilingify.readest"
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw ReaderRouterError.missingReader(reader.displayName)
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([book], withApplicationAt: app, configuration: configuration) { _, error in
            if let error { NSLog("Scene reader open failed: %@", error.localizedDescription) }
        }
    }
}

enum MirrorBridge {
    static func openMirror(with handoff: URL) throws {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.sovereign.Mirror") else {
            throw ReaderRouterError.missingReader("Mirror")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: app, configuration: configuration) { _, error in
            if let error {
                NSLog("Mirror launch failed: %@", error.localizedDescription)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                DistributedNotificationCenter.default().post(
                    name: HandoffCenter.notificationName,
                    object: handoff.path,
                    userInfo: nil
                )
            }
        }
    }
}
