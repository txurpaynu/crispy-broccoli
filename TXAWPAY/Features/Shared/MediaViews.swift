import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers

/// Transferable that copies a picked movie into a temporary file.
struct PickedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedMovie(url: dest)
        }
    }
}

enum MediaImporter {
    struct Imported {
        var kind: AttachmentKind
        var fileName: String
        var originalName: String
    }

    /// Imports PhotosPicker items into the MediaStore. Returns stored files and
    /// the number of items that failed.
    static func importItems(_ items: [PhotosPickerItem]) async -> ([Imported], Int) {
        var results: [Imported] = []
        var failures = 0
        for item in items {
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            do {
                if isVideo, let movie = try await item.loadTransferable(type: PickedMovie.self) {
                    let name = try MediaStore.shared.importFile(at: movie.url)
                    try? FileManager.default.removeItem(at: movie.url)
                    results.append(Imported(kind: .video, fileName: name, originalName: movie.url.lastPathComponent))
                } else if let data = try await item.loadTransferable(type: Data.self) {
                    // Normalise to JPEG (handles HEIC and keeps sizes predictable).
                    let name: String
                    if let image = UIImage(data: data) {
                        name = try MediaStore.shared.save(image: image)
                    } else {
                        name = try MediaStore.shared.save(data: data, fileExtension: "jpg")
                    }
                    results.append(Imported(kind: .photo, fileName: name, originalName: "Photo"))
                } else {
                    failures += 1
                }
            } catch {
                failures += 1
            }
        }
        return (results, failures)
    }
}

/// Async thumbnail for a stored media file.
struct MediaThumbnail: View {
    let fileName: String
    var isVideo = false
    var maxPixel: CGFloat = 500
    var cornerRadius: CGFloat = Theme.Radius.medium

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Theme.surfaceSunken)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: isVideo ? "video" : "photo")
                    .foregroundStyle(Theme.textTertiary)
            }
            if isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .black.opacity(0.35))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: fileName) {
            let name = fileName, px = maxPixel
            image = await Task.detached(priority: .utility) { MediaStore.shared.thumbnail(for: name, maxPixel: px) }.value
        }
        .accessibilityLabel(isVideo ? "Video" : "Photo")
    }
}

/// Full-screen media viewer with swipe between items.
struct MediaViewer: View {
    let attachments: [JournalAttachment]
    @State var index: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView(selection: $index) {
                ForEach(Array(attachments.enumerated()), id: \.element.id) { i, a in
                    Group {
                        if a.kind == .video {
                            VideoPlayer(player: AVPlayer(url: a.fileURL))
                        } else if let img = MediaStore.shared.image(named: a.fileName) {
                            ZoomableImage(image: img)
                        } else {
                            ContentUnavailableView("File missing", systemImage: "photo.badge.exclamationmark")
                        }
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: attachments.count > 1 ? .automatic : .never))
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                if attachments.indices.contains(index), attachments[index].kind == .photo {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: attachments[index].fileURL)
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

struct ZoomableImage: View {
    let image: UIImage
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .gesture(
                MagnificationGesture()
                    .onChanged { scale = max(1, lastScale * $0) }
                    .onEnded { _ in lastScale = scale }
            )
            .onTapGesture(count: 2) {
                withAnimation { scale = scale > 1 ? 1 : 2.5; lastScale = scale }
            }
            .accessibilityLabel("Photo")
    }
}

/// Grid of attachments with tap-to-view.
struct AttachmentGrid: View {
    let attachments: [JournalAttachment]
    var onDelete: ((JournalAttachment) -> Void)? = nil
    @State private var viewerIndex: Int?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(attachments.enumerated()), id: \.element.id) { i, a in
                Button { viewerIndex = i } label: {
                    MediaThumbnail(fileName: a.fileName, isVideo: a.kind == .video)
                        .aspectRatio(1, contentMode: .fill)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if let onDelete {
                        Button(role: .destructive) { onDelete(a) } label: { Label("Remove", systemImage: "trash") }
                    }
                }
            }
        }
        .fullScreenCover(item: Binding(get: { viewerIndex.map { IndexBox(value: $0) } }, set: { viewerIndex = $0?.value })) { box in
            MediaViewer(attachments: attachments, index: box.value)
        }
    }
}

struct IndexBox: Identifiable {
    let value: Int
    var id: Int { value }
}

/// A circular avatar for people and the profile, from a stored image or initials.
struct AvatarView: View {
    let fileName: String
    let initials: String
    var size: CGFloat = 56

    var body: some View {
        Group {
            if !fileName.isEmpty, MediaStore.shared.exists(fileName) {
                MediaThumbnail(fileName: fileName, maxPixel: size * 3, cornerRadius: size / 2)
            } else {
                Circle()
                    .fill(Theme.hydroGradient)
                    .overlay(
                        Text(initials)
                            .font(.system(size: size * 0.38, weight: .semibold, design: .serif))
                            .foregroundStyle(Brand.warmIvory)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Theme.gold.opacity(0.5), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// Picks one photo and stores it, returning the file name.
struct SinglePhotoPicker<Label: View>: View {
    @Binding var fileName: String
    @ViewBuilder var label: () -> Label
    @State private var item: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $item, matching: .images) { label() }
            .onChange(of: item) { _, newItem in
                guard let newItem else { return }
                Task {
                    let (imported, _) = await MediaImporter.importItems([newItem])
                    if let first = imported.first {
                        if !fileName.isEmpty { MediaStore.shared.delete(fileName) }
                        fileName = first.fileName
                    }
                    item = nil
                }
            }
    }
}
