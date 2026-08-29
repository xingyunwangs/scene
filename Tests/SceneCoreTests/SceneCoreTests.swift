import Foundation
import Testing
@testable import SceneCore

@Test func scanIsReadOnlyAndKeepsFeaturedOrder() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let first = root.appending(path: "老子.epub")
    let second = root.appending(path: "理想国.epub")
    try Data("a".utf8).write(to: first)
    try Data("b".utf8).write(to: second)
    let before = try FileManager.default.attributesOfItem(atPath: first.path)[.modificationDate] as? Date

    let preferences = ScenePreferences(
        libraryPath: root.path,
        featuredTitles: ["理想国", "老子"],
        readerByFilename: ["老子.epub": .appleBooks]
    )
    let books = SceneLibrary.scan(preferences)

    #expect(books.map(\.title) == ["理想国", "老子"])
    #expect(books[1].reader == .appleBooks)
    let after = try FileManager.default.attributesOfItem(atPath: first.path)[.modificationDate] as? Date
    #expect(before == after)
}

@Test func handoffFixtureMatchesVersionOne() throws {
    let fixture = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Docs/capture-draft-v1.json")
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let draft = try decoder.decode(CaptureDraft.self, from: Data(contentsOf: fixture))
    #expect(draft.version == CaptureDraft.currentVersion)
    #expect(draft.source?.bundleIdentifier == "com.sovereign.Scene")
}
