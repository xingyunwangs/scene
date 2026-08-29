import Foundation

public enum SovereignPaths {
    public static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    public static var defaultBooks: URL {
        home.appending(path: "Documents/Knowledge/Books/real", directoryHint: .isDirectory)
    }

    public static var sceneSupport: URL {
        home.appending(path: "Library/Application Support/Scene", directoryHint: .isDirectory)
    }

    public static var scenePreferences: URL {
        sceneSupport.appending(path: "library.json")
    }

    public static var handoffDirectory: URL {
        home.appending(path: "Library/Application Support/SovereignContext/Handoffs", directoryHint: .isDirectory)
    }
}

public enum SovereignIO {
    public static func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public static func atomicWrite(_ data: Data, to destination: URL) throws {
        try ensureDirectory(destination.deletingLastPathComponent())
        let temporary = destination.deletingLastPathComponent()
            .appending(path: ".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
        try data.write(to: temporary, options: .withoutOverwriting)
        do {
            try FileManager.default.moveItem(at: temporary, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }
}
