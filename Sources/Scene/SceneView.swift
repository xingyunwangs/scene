import AppKit
import SceneCore
import SwiftUI

struct SceneView: View {
    @ObservedObject var model: SceneModel
    var onHide: () -> Void
    @State private var linkEditor: LinkEditorDraft?
    @State private var pendingDeletion: SceneLink?

    init(model: SceneModel, onHide: @escaping () -> Void = {}, startsAddingLink: Bool = false) {
        self.model = model
        self.onHide = onHide
        _linkEditor = State(initialValue: startsAddingLink ? LinkEditorDraft() : nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if pendingDeletion != nil {
                removalConfirmation
            } else if linkEditor != nil {
                linkEditorBody
            } else {
                if model.showAll { search }
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        ForEach(model.visibleLinks) { link in
                            LinkCard(
                                link: link,
                                open: { model.open(link) },
                                edit: { linkEditor = LinkEditorDraft(link) },
                                remove: { pendingDeletion = link }
                            )
                        }
                        ForEach(model.visibleBooks) { book in
                            BookCard(book: book, model: model)
                        }
                    }
                    .padding(.horizontal, 17)
                    .padding(.vertical, 18)
                }
                footer
            }
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
                Text(headerTitle)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(SovereignDesign.ink)
            }
            Spacer()
            if linkEditor == nil, pendingDeletion == nil {
                HeaderButton(symbol: "plus") {
                    linkEditor = LinkEditorDraft()
                }
                .help("Add a website or video")
                HeaderButton(symbol: model.showAll ? "books.vertical.fill" : "square.grid.2x2") {
                    withAnimation(.easeOut(duration: 0.18)) { model.showAll.toggle() }
                }
                .help(model.showAll ? "Featured books" : "All books")
            } else {
                HeaderButton(symbol: "xmark") {
                    linkEditor = nil
                    pendingDeletion = nil
                }
                .help("Cancel")
            }
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

    private var headerTitle: String {
        if pendingDeletion != nil { return "Remove entry" }
        if let editor = linkEditor { return editor.existingID == nil ? "Add entry" : "Edit entry" }
        return model.showAll ? "Library" : "Read next"
    }

    @ViewBuilder private var linkEditorBody: some View {
        if let draft = linkEditor {
            LinkEditorView(
                draft: Binding(
                    get: { linkEditor ?? draft },
                    set: { linkEditor = $0 }
                ),
                save: {
                    guard let current = linkEditor else { return }
                    if model.saveLink(
                        id: current.existingID,
                        title: current.title,
                        subtitle: current.subtitle,
                        urlText: current.urlText
                    ) {
                        linkEditor = nil
                    }
                },
                cancel: { linkEditor = nil }
            )
        }
    }

    @ViewBuilder private var removalConfirmation: some View {
        if let link = pendingDeletion {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(SovereignDesign.rust)
                Text("Remove \(link.title) from this Scene?")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(SovereignDesign.ink)
                Text("The website or video is not changed. Only this local entrance is removed.")
                    .font(.system(size: 11))
                    .foregroundStyle(SovereignDesign.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                HStack {
                    Button("Cancel") { pendingDeletion = nil }
                        .buttonStyle(.plain)
                        .foregroundStyle(SovereignDesign.secondaryInk)
                    Spacer()
                    Button("Remove", role: .destructive) {
                        if model.remove(link) { pendingDeletion = nil }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 14)
        }
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

private struct LinkEditorDraft: Identifiable {
    let id = UUID()
    let existingID: UUID?
    var title: String
    var subtitle: String
    var urlText: String

    init() {
        existingID = nil
        title = ""
        subtitle = ""
        urlText = ""
    }

    init(_ link: SceneLink) {
        existingID = link.id
        title = link.title
        subtitle = link.subtitle
        urlText = link.url.absoluteString
    }
}

private struct LinkEditorView: View {
    @Binding var draft: LinkEditorDraft
    let save: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            EditorField(label: "NAME") {
                TextField("Tai chi, lecture, journal…", text: $draft.title)
            }
            EditorField(label: "DETAIL") {
                TextField("Optional short description", text: $draft.subtitle)
            }
            EditorField(label: "ADDRESS") {
                TextField("https://", text: $draft.urlText)
            }
            Text("Paste any http or https page. Scene keeps the address locally and opens it in your default app.")
                .font(.system(size: 10.5))
                .foregroundStyle(SovereignDesign.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            HStack {
                Button("Cancel", action: cancel)
                    .buttonStyle(.plain)
                    .foregroundStyle(SovereignDesign.secondaryInk)
                Spacer()
                Button("Keep in Scene", action: save)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(SovereignDesign.sage)
            }
        }
        .textFieldStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }
}

private struct EditorField<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(SovereignDesign.rust)
            content
                .font(.system(size: 13))
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
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

private struct LinkCard: View {
    let link: SceneLink
    let open: () -> Void
    let edit: () -> Void
    let remove: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(tileColor)
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 70)
                VStack(alignment: .leading, spacing: 5) {
                    Text(link.title)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(SovereignDesign.ink)
                        .lineLimit(2)
                    Text(link.subtitle.isEmpty ? (link.url.host ?? link.url.absoluteString) : link.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(SovereignDesign.secondaryInk)
                        .lineLimit(2)
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
        .contextMenu {
            Button("Open") { open() }
            Button("Edit…") { edit() }
            Divider()
            Button("Remove from Scene…", role: .destructive) { remove() }
        }
    }

    private var isVideo: Bool {
        let host = link.url.host?.lowercased() ?? ""
        return host.contains("bilibili") || host.contains("youtube") || host.contains("vimeo")
    }

    private var symbol: String {
        if isVideo { return "play.rectangle.fill" }
        if link.url.host?.localizedCaseInsensitiveContains("libby") == true { return "building.columns.fill" }
        return "link"
    }

    private var tileColor: Color {
        if isVideo { return Color(red: 0.78, green: 0.28, blue: 0.29) }
        if link.url.host?.localizedCaseInsensitiveContains("libby") == true {
            return Color(red: 0.12, green: 0.52, blue: 0.32)
        }
        return SovereignDesign.sage
    }
}
