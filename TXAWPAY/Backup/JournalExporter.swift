import Foundation
import SwiftData

/// Builds a complete, self-contained journal export (ZIP, optionally encrypted).
///
/// The ZIP uses the same layout as the automatic backup folder, so it can be
/// unzipped and restored with Restore Journal, or read with any text editor:
///
///     TXAWPAY/README.txt
///     TXAWPAY/Journal Backups/2026/November/2026-11-16.md
///     TXAWPAY/Journal Backups/Media/<entry id>/<file>
///     TXAWPAY/Journal Backups/manifest.json
///     TXAWPAY/journal.json        (structured copy of every entry)
enum JournalExporter {
    struct ExportPayload: Codable {
        var exportedAt: Date
        var formatVersion: Int
        var categories: [String]
        var entries: [JournalEntrySnapshot]
    }

    @MainActor
    static func snapshot(context: ModelContext) -> ExportPayload {
        let entries = (try? context.fetch(FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.isDemo == false },
                                                                         sortBy: [SortDescriptor(\.date)]))) ?? []
        let categories = ((try? context.fetch(FetchDescriptor<JournalCategory>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []).map(\.name)
        return ExportPayload(exportedAt: Date(), formatVersion: JournalMarkdownCodec.formatVersion,
                             categories: categories, entries: entries.map { JournalEntrySnapshot($0) })
    }

    /// Writes the ZIP to a temporary file and returns its URL.
    static func makeArchive(payload: ExportPayload, includeMedia: Bool, password: String?) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let stamp = DayKey.key(for: Date())
            let workDir = fm.temporaryDirectory.appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
            try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
            let zipURL = workDir.appendingPathComponent("TXAWPAY Journal \(stamp).zip")

            let zip = try ZipWriter(url: zipURL)
            let root = "TXAWPAY/"
            let journal = root + "Journal Backups/"

            zip.add(readme: root + "README.txt")

            let byDay = Dictionary(grouping: payload.entries, by: \.dayKey)
            var manifest = BackupManifest()
            for (key, entries) in byDay.sorted(by: { $0.key < $1.key }) {
                let md = JournalMarkdownCodec.renderDay(key: key, entries: entries)
                let data = Data(md.utf8)
                let relative = DayKey.relativePath(for: key)
                try zip.add(path: journal + relative, data: data)
                manifest.days[key] = .init(path: relative, sha256: JournalMarkdownCodec.sha256(data),
                                           entryIDs: entries.map(\.id), writtenAt: Date(), lastSnapshotAt: nil)
            }

            if includeMedia {
                for entry in payload.entries {
                    for a in entry.attachments {
                        let src = MediaStore.shared.url(for: a.fileName)
                        guard fm.fileExists(atPath: src.path) else { continue }
                        try zip.addFile(path: journal + "Media/\(entry.id.uuidString)/\(a.fileName)", from: src)
                    }
                }
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try zip.add(path: journal + "manifest.json", data: encoder.encode(manifest))
            try zip.add(path: root + "journal.json", data: encoder.encode(payload))
            try zip.finish()

            guard let password, !password.isEmpty else { return zipURL }
            let zipData = try Data(contentsOf: zipURL)
            let sealed = try EncryptedArchive.encrypt(zipData, password: password)
            let encURL = workDir.appendingPathComponent("TXAWPAY Journal \(stamp).\(EncryptedArchive.fileExtension)")
            try sealed.write(to: encURL, options: .atomic)
            try? fm.removeItem(at: zipURL)
            return encURL
        }.value
    }
}

private extension ZipWriter {
    func add(readme path: String) {
        let text = """
        TXAWPAY journal export

        Journal Backups/ holds one Markdown file per day (year/month folders) with the full text
        of every entry, plus titles, moods, tags and timestamps. Media/ holds attached photos and
        videos. journal.json is a structured copy of the same data.

        Restore: TXAWPAY › Profile › Restore Journal › choose this ZIP (or the unzipped TXAWPAY folder).
        These files are not encrypted unless you exported with a password.
        """
        try? add(path: path, data: Data(text.utf8))
    }
}
