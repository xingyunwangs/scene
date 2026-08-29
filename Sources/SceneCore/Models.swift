import Foundation

public enum MirrorKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case thought
    case note
    case memory

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .thought: "Thought"
        case .note: "Note"
        case .memory: "Memory"
        }
    }

    public var folderName: String { rawValue + "s" }
}

public struct SourceContext: Codable, Equatable, Sendable {
    public var appName: String?
    public var bundleIdentifier: String?
    public var title: String?
    public var url: URL?
    public var fileURL: URL?
    public var selectedText: String?
    public var capturedAt: Date

    public init(
        appName: String? = nil,
        bundleIdentifier: String? = nil,
        title: String? = nil,
        url: URL? = nil,
        fileURL: URL? = nil,
        selectedText: String? = nil,
        capturedAt: Date = Date()
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.title = title
        self.url = url
        self.fileURL = fileURL
        self.selectedText = selectedText
        self.capturedAt = capturedAt
    }

    public var isEmpty: Bool {
        [appName, title, selectedText].allSatisfy { ($0 ?? "").isEmpty }
            && url == nil && fileURL == nil
    }
}

public struct CaptureDraft: Codable, Equatable, Identifiable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var id: UUID
    public var kind: MirrorKind
    public var body: String
    public var source: SourceContext?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: MirrorKind = .thought,
        body: String = "",
        source: SourceContext? = nil,
        createdAt: Date = Date()
    ) {
        version = Self.currentVersion
        self.id = id
        self.kind = kind
        self.body = body
        self.source = source
        self.createdAt = createdAt
    }
}

public enum ReaderChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case appleBooks
    case readest
    case systemDefault

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .appleBooks: "Apple Books"
        case .readest: "Readest"
        case .systemDefault: "Default Reader"
        }
    }
}

public struct SceneBook: Identifiable, Equatable, Sendable {
    public var id: String { fileURL.standardizedFileURL.path }
    public let title: String
    public let fileURL: URL
    public let reader: ReaderChoice
    public let isFeatured: Bool

    public init(title: String, fileURL: URL, reader: ReaderChoice, isFeatured: Bool) {
        self.title = title
        self.fileURL = fileURL
        self.reader = reader
        self.isFeatured = isFeatured
    }
}

public struct ScenePreferences: Codable, Equatable, Sendable {
    public var libraryPath: String
    public var featuredTitles: [String]
    public var readerByFilename: [String: ReaderChoice]

    public init(libraryPath: String, featuredTitles: [String], readerByFilename: [String: ReaderChoice]) {
        self.libraryPath = libraryPath
        self.featuredTitles = featuredTitles
        self.readerByFilename = readerByFilename
    }
}
