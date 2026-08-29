import Foundation

public enum SceneLibrary {
    public static let defaultFeaturedTitles = [
        "老子",
        "理想国",
        "费恩曼物理学讲义",
        "卡拉马佐夫兄弟",
    ]

    public static let defaultRoutes: [String: ReaderChoice] = [
        "老子.epub": .appleBooks,
        "理想国.epub": .readest,
        "费恩曼物理学讲义.epub": .readest,
        "卡拉马佐夫兄弟.epub": .appleBooks,
    ]

    public static func defaultPreferences(libraryURL: URL = SovereignPaths.defaultBooks) -> ScenePreferences {
        ScenePreferences(
            libraryPath: libraryURL.path,
            featuredTitles: defaultFeaturedTitles,
            readerByFilename: defaultRoutes
        )
    }

    public static func loadPreferences(from url: URL = SovereignPaths.scenePreferences) -> ScenePreferences {
        guard let data = try? Data(contentsOf: url),
              let preferences = try? JSONDecoder().decode(ScenePreferences.self, from: data)
        else { return defaultPreferences() }
        return preferences
    }

    public static func savePreferences(_ preferences: ScenePreferences, to url: URL = SovereignPaths.scenePreferences) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try SovereignIO.atomicWrite(try encoder.encode(preferences), to: url)
    }

    public static func scan(_ preferences: ScenePreferences) -> [SceneBook] {
        let library = URL(fileURLWithPath: preferences.libraryPath, isDirectory: true)
        let keys: [URLResourceKey] = [.isRegularFileKey, .nameKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: library,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []
        let allowed = Set(["epub", "pdf"])
        let featuredIndex = Dictionary(uniqueKeysWithValues: preferences.featuredTitles.enumerated().map { ($1, $0) })

        return urls
            .filter { allowed.contains($0.pathExtension.lowercased()) }
            .map { url in
                let title = url.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .whitespaces)
                return SceneBook(
                    title: title,
                    fileURL: url,
                    reader: preferences.readerByFilename[url.lastPathComponent] ?? .systemDefault,
                    isFeatured: featuredIndex[title] != nil
                )
            }
            .sorted { lhs, rhs in
                switch (featuredIndex[lhs.title], featuredIndex[rhs.title]) {
                case let (l?, r?): l < r
                case (_?, nil): true
                case (nil, _?): false
                case (nil, nil): lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
            }
    }
}
