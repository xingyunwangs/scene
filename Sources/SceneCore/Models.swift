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

public enum DockEdge: String, Codable, CaseIterable, Identifiable, Sendable {
    case left
    case right

    public var id: String { rawValue }
    public var displayName: String { self == .left ? "Left" : "Right" }
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

public struct SceneLink: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var subtitle: String
    public var url: URL

    public init(id: UUID = UUID(), title: String, subtitle: String = "", url: URL) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.url = url
    }

    public static let defaultLinks = [
        SceneLink(
            id: UUID(uuidString: "F2C7F76D-5790-43EA-928D-7A23E30A9B77")!,
            title: "太极拳",
            subtitle: "练习视频 · bilibili",
            url: URL(string: "https://www.bilibili.com/video/BV15t411L7Bj")!
        ),
        SceneLink(
            id: UUID(uuidString: "B6835B34-C1D8-4B54-920F-98DA43D84385")!,
            title: "Libby",
            subtitle: "Temporary loans",
            url: URL(string: "https://libbyapp.com")!
        ),
    ]
}

public struct ScenePreferences: Codable, Equatable, Sendable {
    public var libraryPath: String
    public var featuredTitles: [String]
    public var readerByFilename: [String: ReaderChoice]
    public var dockEdge: DockEdge
    public var links: [SceneLink]

    public init(
        libraryPath: String,
        featuredTitles: [String],
        readerByFilename: [String: ReaderChoice],
        dockEdge: DockEdge = .left,
        links: [SceneLink] = SceneLink.defaultLinks
    ) {
        self.libraryPath = libraryPath
        self.featuredTitles = featuredTitles
        self.readerByFilename = readerByFilename
        self.dockEdge = dockEdge
        self.links = links
    }

    private enum CodingKeys: String, CodingKey {
        case libraryPath, featuredTitles, readerByFilename, dockEdge, links
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        libraryPath = try container.decode(String.self, forKey: .libraryPath)
        featuredTitles = try container.decode([String].self, forKey: .featuredTitles)
        readerByFilename = try container.decode([String: ReaderChoice].self, forKey: .readerByFilename)
        dockEdge = try container.decodeIfPresent(DockEdge.self, forKey: .dockEdge) ?? .left
        links = try container.decodeIfPresent([SceneLink].self, forKey: .links) ?? SceneLink.defaultLinks
    }
}
