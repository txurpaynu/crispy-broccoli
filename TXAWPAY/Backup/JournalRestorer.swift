import Foundation
import SwiftData

/// Reads TXAWPAY backup folders, Markdown/TXT files, ZIP exports and encrypted
/// exports, previews what would be imported, and imports without duplicates.
enum JournalRestorer {
    enum ItemStatus: String {
        case new = "New"
        case newer = "Newer than yours"
        case duplicate = "Already in your journal"

        var symbol: String {
            switch self {
            case .new: "plus.circle.fill"
            case .newer: "arrow.triangle.2.circlepath"
            case .duplicate: "checkmark.circle"
            }
        }
    }

    struct PlanItem: Identifiable, Hashable {
        var entry: JournalMarkdownCodec.ParsedEntry
        var status: ItemStatus
        /// Folder holding this entry's media in the backup ("…/Media/<id>").
        var mediaFolder: URL?
        var id: UUID { entry.id }
    }

    struct Plan {
        var items: [PlanItem]
        var filesScanned: Int
        var unreadableFiles: [String]
        /// Security-scoped source that must be accessed again while importing media.
        var scopedSource: URL?
        /// Temporary extraction folder to delete when finished.
        var tempFolder: URL?

        var newCount: Int { items.filter { $0.status == .new }.count }
        var newerCount: Int { items.filter { $0.status == .newer }.count }
        var duplicateCount: Int { items.filter { $0.status == .duplicate }.count }
    }

    struct Summary {
        var imported = 0
        var updated = 0
        var skipped = 0
        var mediaRestored = 0
        var mediaMissing = 0
    }

    enum RestoreError: LocalizedError {
        case accessDenied
        case nothingFound
        case needsPassword

        var errorDescription: String? {
            switch self {
            case .accessDenied: "TXAWPAY couldn't open the selected location."
            case .nothingFound: "No journal files were found. Choose your TXAWPAY folder, a Journal Backups folder, Markdown files or a TXAWPAY export."
            case .needsPassword: "This backup is encrypted. Enter its password to continue."
            }
        }
    }

    // MARK: Scanning

    /// Scans the picked URLs. Runs file I/O off the main actor.
    static func scan(urls: [URL], password: String?, existing: [UUID: Date], existingFingerprints: Set<UUID>) async throws -> Plan {
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            var mdFiles: [URL] = []
            var scoped: URL?
            var temp: URL?
            var unreadable: [String] = []

            for url in urls {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }

                var isDir: ObjCBool = false
                _ = fm.fileExists(atPath: url.path, isDirectory: &isDir)
                if isDir.boolValue {
                    scoped = url
                    mdFiles += collectJournalFiles(in: url)
                    continue
                }

                let ext = url.pathExtension.lowercased()
                if ext == "zip" || ext == EncryptedArchive.fileExtension || EncryptedArchive.isEncrypted(url) {
                    let work = fm.temporaryDirectory.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
                    try fm.createDirectory(at: work, withIntermediateDirectories: true)
                    temp = work
                    var archiveURL = work.appendingPathComponent("archive.zip")
                    if EncryptedArchive.isEncrypted(url) {
                        guard let password, !password.isEmpty else { throw RestoreError.needsPassword }
                        let data = try Data(contentsOf: url)
                        try EncryptedArchive.decrypt(data, password: password).write(to: archiveURL)
                    } else {
                        archiveURL = work.appendingPathComponent(url.lastPathComponent)
                        try fm.copyItem(at: url, to: archiveURL)
                    }
                    let extracted = work.appendingPathComponent("extracted", isDirectory: true)
                    try ZipReader.extract(archive: archiveURL, to: extracted)
                    mdFiles += collectJournalFiles(in: extracted)
                } else if ext == "md" || ext == "markdown" || ext == "txt" {
                    // Individual files: copy into temp so they stay readable after scope ends.
                    let work = temp ?? fm.temporaryDirectory.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
                    try fm.createDirectory(at: work, withIntermediateDirectories: true)
                    temp = work
                    let copy = work.appendingPathComponent(url.lastPathComponent)
                    try? fm.removeItem(at: copy)
                    try fm.copyItem(at: url, to: copy)
                    mdFiles.append(copy)
                }
            }

            // Parse everything while we still have access to the folder.
            var items: [PlanItem] = []
            var seen = Set<UUID>()
            if let scoped { _ = scoped.startAccessingSecurityScopedResource() }
            defer { scoped?.stopAccessingSecurityScopedResource() }
            for file in mdFiles {
                guard let data = try? Data(contentsOf: file) else { unreadable.append(file.lastPathComponent); continue }
                let text = String(decoding: data, as: UTF8.self)
                let parsed = JournalMarkdownCodec.parse(text, fileName: file.lastPathComponent)
                for entry in parsed where !seen.contains(entry.id) {
                    seen.insert(entry.id)
                    let status: ItemStatus
                    if let existingModified = existing[entry.id] {
                        status = entry.modifiedAt > existingModified.addingTimeInterval(1) ? .newer : .duplicate
                    } else if existingFingerprints.contains(entry.id) {
                        status = .duplicate
                    } else {
                        status = .new
                    }
                    // Media lives at <Journal Backups>/Media/<id>; day files are at <Journal Backups>/<year>/<month>/.
                    let journalRoot = file.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                    let media = journalRoot.appendingPathComponent("Media").appendingPathComponent(entry.id.uuidString)
                    items.append(PlanItem(entry: entry, status: status,
                                          mediaFolder: fm.fileExists(atPath: media.path) ? media : nil))
                }
            }
            guard !items.isEmpty else {
                if let temp { try? fm.removeItem(at: temp) }
                throw RestoreError.nothingFound
            }
            items.sort { $0.entry.date > $1.entry.date }
            return Plan(items: items, filesScanned: mdFiles.count, unreadableFiles: unreadable, scopedSource: scoped, tempFolder: temp)
        }.value
    }

    /// Recursively finds .md/.txt day files, skipping version history and exports' JSON.
    static func collectJournalFiles(in folder: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey],
                                                              options: [.skipsHiddenFiles]) else { return [] }
        var found: [URL] = []
        var txtFallback: [URL] = []
        for case let url as URL in enumerator {
            if url.lastPathComponent == "Version History" || url.lastPathComponent == "Media" {
                enumerator.skipDescendants()
                continue
            }
            let ext = url.pathExtension.lowercased()
            if ext == "md" || ext == "markdown" { found.append(url) }
            else if ext == "txt" && url.lastPathComponent != "README.txt" { txtFallback.append(url) }
        }
        // TXT files are only used if they don't have a Markdown twin (TXAWPAY writes both optionally).
        let mdStems = Set(found.map { $0.deletingPathExtension().path })
        found += txtFallback.filter { !mdStems.contains($0.deletingPathExtension().path) }
        return found.sorted { $0.path < $1.path }
    }

    // MARK: Fingerprints

    /// Existing entries keyed by id → modifiedAt, plus content fingerprints for
    /// plain-Markdown duplicates (same day + title + text).
    @MainActor
    static func existingIndex(context: ModelContext) -> ([UUID: Date], Set<UUID>) {
        let entries = (try? context.fetch(FetchDescriptor<JournalEntry>())) ?? []
        var byID: [UUID: Date] = [:]
        var prints = Set<UUID>()
        for e in entries {
            byID[e.id] = e.modifiedAt
            prints.insert(JournalMarkdownCodec.syntheticID(date: e.date, title: e.title, body: e.body))
        }
        return (byID, prints)
    }

    // MARK: Import

    @MainActor
    static func apply(plan: Plan, selected: Set<UUID>, context: ModelContext, backup: BackupManager?) -> Summary {
        var summary = Summary()
        var categories = Dictionary(((try? context.fetch(FetchDescriptor<JournalCategory>())) ?? []).map { ($0.name.lowercased(), $0) },
                                    uniquingKeysWith: { a, _ in a })
        let allEntries = (try? context.fetch(FetchDescriptor<JournalEntry>())) ?? []
        var byID = Dictionary(allEntries.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        let accessing = plan.scopedSource?.startAccessingSecurityScopedResource() ?? false
        defer { if accessing { plan.scopedSource?.stopAccessingSecurityScopedResource() } }

        for item in plan.items {
            guard selected.contains(item.id), item.status != .duplicate else { summary.skipped += 1; continue }
            let p = item.entry
            let entry: JournalEntry
            var previousDayKey: String? = nil
            if let existing = byID[p.id] {
                entry = existing
                previousDayKey = DayKey.key(for: existing.date)
                summary.updated += 1
            } else {
                entry = JournalEntry(title: p.title, body: p.body, date: p.date)
                entry.id = p.id
                context.insert(entry)
                byID[p.id] = entry
                summary.imported += 1
            }
            entry.title = p.title
            entry.body = p.body
            entry.reflection = p.reflection
            entry.date = p.date
            entry.createdAt = p.createdAt
            entry.modifiedAt = p.modifiedAt
            entry.moodRaw = Mood.parse(p.mood)?.rawValue ?? ""
            entry.tags = p.tags
            entry.locationName = p.locationName
            entry.latitude = p.latitude
            entry.longitude = p.longitude
            entry.isFavorite = p.isFavorite
            entry.isImportant = p.isImportant
            if !p.category.isEmpty {
                if let cat = categories[p.category.lowercased()] {
                    entry.category = cat
                } else {
                    let cat = JournalCategory(name: p.category, sortOrder: categories.count)
                    context.insert(cat)
                    categories[p.category.lowercased()] = cat
                    entry.category = cat
                }
            }

            // Media: attach files that exist in the backup and aren't attached yet.
            let existingNames = Set((entry.attachments ?? []).map(\.fileName))
            for a in p.attachments where !existingNames.contains(a.fileName) {
                guard let folder = item.mediaFolder else { summary.mediaMissing += 1; continue }
                let src = folder.appendingPathComponent(a.fileName)
                guard FileManager.default.fileExists(atPath: src.path),
                      let stored = try? MediaStore.shared.importFile(at: src, preservingName: a.fileName) else {
                    summary.mediaMissing += 1
                    continue
                }
                let att = JournalAttachment(kind: AttachmentKind(rawValue: a.kind) ?? .file, fileName: stored,
                                            originalFileName: a.originalFileName)
                att.caption = a.caption
                context.insert(att)
                att.entry = entry
                summary.mediaRestored += 1
            }
            backup?.entryChanged(entry, previousDayKey: previousDayKey)
        }
        try? context.save()
        if let temp = plan.tempFolder { try? FileManager.default.removeItem(at: temp) }
        return summary
    }
}
