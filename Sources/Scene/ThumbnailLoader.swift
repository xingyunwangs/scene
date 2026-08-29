import AppKit
import QuickLookThumbnailing

@MainActor
final class ThumbnailLoader: ObservableObject {
    @Published var image: NSImage?
    private static let cache = NSCache<NSURL, NSImage>()

    func load(_ url: URL) {
        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 126, height: 180),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            guard let nsImage = representation?.nsImage else { return }
            DispatchQueue.main.async {
                Self.cache.setObject(nsImage, forKey: url as NSURL)
                self?.image = nsImage
            }
        }
    }
}
