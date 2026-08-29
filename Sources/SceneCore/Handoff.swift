import Foundation

public enum HandoffCenter {
    public static let notificationName = Notification.Name("com.sovereign.mirror.capture")

    public static func write(_ draft: CaptureDraft, directory: URL = SovereignPaths.handoffDirectory) throws -> URL {
        try SovereignIO.ensureDirectory(directory)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let destination = directory.appending(path: "\(draft.id.uuidString).json")
        try SovereignIO.atomicWrite(try encoder.encode(draft), to: destination)
        return destination
    }

    public static func read(_ url: URL) throws -> CaptureDraft {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let draft = try decoder.decode(CaptureDraft.self, from: Data(contentsOf: url))
        guard draft.version == CaptureDraft.currentVersion else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return draft
    }

    public static func pending(directory: URL = SovereignPaths.handoffDirectory) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? [])
        .filter { $0.pathExtension.lowercased() == "json" }
        .sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return l < r
        }
    }
}
