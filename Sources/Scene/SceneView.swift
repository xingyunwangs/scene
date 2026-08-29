import AppKit
import SceneCore
import SwiftUI

struct SceneView: View {
    @ObservedObject var model: SceneModel
    var onHide: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header
            if model.showAll { search }
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(model.visibleBooks) { book in
                        BookCard(book: book, model: model)
                    }
                    LibbyCard(action: model.openLibby)
                }
                .padding(.horizontal, 17)
                .padding(.vertical, 18)
            }
            footer
        }
        .frame(minWidth: 266, minHeight: 580)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(.white.opacity(0.55), lineWidth: 0.8)
        }
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 11) {
            VStack(alignment: .leading, spacing: 3) {
                Text("SCENE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.9)
                    .foregroundStyle(SovereignDesign.rust)
                Text(model.showAll ? "Library" : "Read next")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(SovereignDesign.ink)
            }
            Spacer()
            HeaderButton(symbol: model.showAll ? "books.vertical.fill" : "square.grid.2x2") {
                withAnimation(.easeOut(duration: 0.18)) { model.showAll.toggle() }
            }
            .help(model.showAll ? "Featured books" : "All books")
            HeaderButton(
                symbol: model.preferences.dockEdge == .left ? "chevron.left" : "chevron.right",
                action: onHide
            )
                .help("Hide Scene")
        }
        .padding(.horizontal, 19)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var search: some View {
        TextField("Find a book", text: $model.search)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .padding(.horizontal, 18)
            .padding(.top, 4)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.status.isEmpty {
                Text(model.status)
                    .font(.system(size: 10.5))
                    .foregroundStyle(SovereignDesign.secondaryInk)
                    .lineLimit(2)
                    .transition(.opacity)
            }
            HStack(spacing: 8) {
                SovereignKeyHint("⌥B")
                Text("or touch the \(model.preferences.dockEdge.rawValue) edge")
                    .font(.system(size: 10))
                    .foregroundStyle(SovereignDesign.secondaryInk.opacity(0.8))
                Spacer()
                Text(model.preferences.dockEdge == .left ? "左 · 观" : "观 · 右")
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundStyle(SovereignDesign.sage)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 15)
    }
}

private struct HeaderButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.45), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct BookCard: View {
    let book: SceneBook
    @ObservedObject var model: SceneModel
    @StateObject private var thumbnail = ThumbnailLoader()
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Button { model.open(book) } label: {
                HStack(spacing: 14) {
                    cover
                    VStack(alignment: .leading, spacing: 7) {
                        Text(book.title)
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(SovereignDesign.ink)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                        Text(book.reader.displayName)
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(SovereignDesign.secondaryInk.opacity(0.84))
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { model.remember(book) } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 27, height: 27)
                    .background(.white.opacity(hovering ? 0.72 : 0.38), in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(SovereignDesign.rust)
            .help("Remember in Mirror")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(hovering ? Color.white.opacity(0.48) : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .scaleEffect(hovering ? 1.018 : 1)
        .animation(.easeOut(duration: 0.13), value: hovering)
        .onHover { hovering = $0 }
        .onAppear { thumbnail.load(book.fileURL) }
        .contextMenu {
            ForEach(ReaderChoice.allCases) { reader in
                Button("Open in \(reader.displayName)") { model.open(book, reader: reader) }
                Button("Always use \(reader.displayName)") { model.setReader(reader, for: book) }
            }
            Divider()
            Button("Remember in Mirror") { model.remember(book) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([book.fileURL]) }
        }
    }

    @ViewBuilder private var cover: some View {
        if let image = thumbnail.image {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(book.reader == .readest ? SovereignDesign.sage : SovereignDesign.rust)
                Text(String(book.title.prefix(2)))
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: 58, height: 82)
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
    }
}

private struct LibbyCard: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(red: 0.12, green: 0.52, blue: 0.32))
                    Image(systemName: "building.columns.fill").foregroundStyle(.white)
                }
                .frame(width: 58, height: 70)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Libby")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                    Text("Temporary loans")
                        .font(.system(size: 10))
                        .foregroundStyle(SovereignDesign.secondaryInk)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .bold))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(hovering ? Color.white.opacity(0.48) : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .scaleEffect(hovering ? 1.018 : 1)
        .animation(.easeOut(duration: 0.13), value: hovering)
        .onHover { hovering = $0 }
    }
}
