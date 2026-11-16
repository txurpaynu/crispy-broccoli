import Foundation
import UIKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

/// Stores photos, videos and files that belong to TXAWPAY content.
///
/// Files live in `Application Support/Media` (excluded from the Files app,
/// included in device backups). Models store only the *file name*, never an
/// absolute URL, because the container path changes between installs.
final class MediaStore {
    static let shared = MediaStore()

    let directory: URL
    private let thumbnailCache = NSCache<NSString, UIImage>()

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("Media", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    func exists(_ fileName: String) -> Bool {
        !fileName.isEmpty && FileManager.default.fileExists(atPath: url(for: fileName).path)
    }

    /// Saves raw data with a fresh unique name. Returns the stored file name.
    @discardableResult
    func save(data: Data, fileExtension: String) throws -> String {
        let name = "\(UUID().uuidString).\(fileExtension.isEmpty ? "bin" : fileExtension.lowercased())"
        try data.write(to: url(for: name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return name
    }

    /// Saves a JPEG version of the image (keeps storage reasonable for photos).
    func save(image: UIImage, quality: CGFloat = 0.85) throws -> String {
        guard let data = image.jpegData(compressionQuality: quality) else {
            throw MediaError.encodingFailed
        }
        return try save(data: data, fileExtension: "jpg")
    }

    /// Copies an external file (e.g. a picked video or document) into the store.
    func importFile(at source: URL) throws -> String {
        let ext = source.pathExtension.isEmpty ? "bin" : source.pathExtension.lowercased()
        let name = "\(UUID().uuidString).\(ext)"
        let dest = url(for: name)
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        try FileManager.default.copyItem(at: source, to: dest)
        return name
    }

    /// Copies a file into the store keeping a given name (used by restore so
    /// attachment names stay stable). Skips if an identical name already exists.
    func importFile(at source: URL, preservingName name: String) throws -> String {
        let dest = url(for: name)
        if FileManager.default.fileExists(atPath: dest.path) { return name }
        try FileManager.default.copyItem(at: source, to: dest)
        return name
    }

    func delete(_ fileName: String) {
        guard !fileName.isEmpty else { return }
        try? FileManager.default.removeItem(at: url(for: fileName))
        thumbnailCache.removeObject(forKey: fileName as NSString)
    }

    func image(named fileName: String) -> UIImage? {
        guard exists(fileName) else { return nil }
        return UIImage(contentsOfFile: url(for: fileName).path)
    }

    /// Memory-efficient downsampled thumbnail (ImageIO) or a video poster frame.
    func thumbnail(for fileName: String, maxPixel: CGFloat = 600) -> UIImage? {
        let key = "\(fileName)#\(Int(maxPixel))" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        guard exists(fileName) else { return nil }
        let fileURL = url(for: fileName)
        let image: UIImage?
        if Self.isVideo(fileURL) {
            let asset = AVURLAsset(url: fileURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maxPixel, height: maxPixel)
            image = (try? generator.copyCGImage(at: .zero, actualTime: nil)).map { UIImage(cgImage: $0) }
        } else {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel
            ]
            if let src = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
               let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) {
                image = UIImage(cgImage: cg)
            } else {
                image = nil
            }
        }
        if let image { thumbnailCache.setObject(image, forKey: key) }
        return image
    }

    static func isVideo(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .movie) || type.conforms(to: .video)
    }

    /// Total bytes used by stored media.
    func totalSize() -> Int64 {
        FileSizeCalculator.size(of: directory)
    }

    /// Removes every media file not referenced by the given set of names.
    func removeOrphans(keeping referenced: Set<String>) -> Int {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        var removed = 0
        for f in files where !referenced.contains(f) {
            try? FileManager.default.removeItem(at: url(for: f))
            removed += 1
        }
        return removed
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        thumbnailCache.removeAllObjects()
    }

    enum MediaError: LocalizedError {
        case encodingFailed
        var errorDescription: String? { "The image couldn't be saved." }
    }
}

enum FileSizeCalculator {
    static func size(of url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true { total += Int64(values?.fileSize ?? 0) }
        }
        return total
    }

    static func text(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
