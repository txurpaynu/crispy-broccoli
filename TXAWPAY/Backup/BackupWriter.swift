import Foundation

/// Machine-readable index of what has been written to a backup folder.
struct BackupManifest: Codable {
    struct DayInfo: Codable {
        var path: String
        var sha256: String
        var entryIDs: [UUID]
        var writtenAt: Date
        var lastSnapshotAt: Date?
    }

    var formatVersion: Int = JournalMarkdownCodec.formatVersion
    var app: String = "TXAWPAY"
    var appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    var updatedAt: Date = Date()
    var days: [String: DayInfo] = [:]
}

/// Result for one day file.
struct DayWriteResult: Sendable {
    enum Outcome: Sendable {
        case written(path: String, hash: String, entryCount: Int, ubiquitous: Bool)
        case unchanged(path: String, hash: String, entryCount: Int, ubiquitous: Bool)
        case removed
        case failed(String)
    }
    let dayKey: String
    let outcome: Outcome
}

struct IntegrityReport: Sendable {
    var checked = 0
    var ok = 0
    var missing: [String] = []
    var mismatched: [String] = []
    var manifestMissing = false
    var isHealthy: Bool { !manifestMissing && missing.isEmpty && mismatched.isEmpty }
}

/// Performs all backup file I/O. An actor, so writes and manifest updates
/// are strictly serialised even when several backups are requested at once.
actor BackupWriter {
    /// Keep at most this many previous versions of each day file.
    static let maxVersionsPerDay = 30
    /// While a person is typing, take at most one safety snapshot per day per interval.
    static let snapshotInterval: TimeInterval = 15 * 60

    private let fm = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Writes the given days. `days` maps day key → entries (empty = day no longer has entries).
    func write(days: [String: [JournalEntrySnapshot]], to root: ResolvedBackupRoot,
               alsoTXT: Bool, includeMedia: Bool) -> [DayWriteResult] {
        let accessing = root.scopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if accessing { root.scopedURL?.stopAccessingSecurityScopedResource() } }

        do {
            try ensureDirectory(root.journalURL)
            try writeReadmeIfNeeded(root)
        } catch {
            let message = Self.describe(error)
            return days.keys.map { DayWriteResult(dayKey: $0, outcome: .failed(message)) }
        }

        var manifest = loadManifest(root) ?? BackupManifest()
        var results: [DayWriteResult] = []

        for (key, entries) in days.sorted(by: { $0.key < $1.key }) {
            do {
                let outcome = try writeDay(key: key, entries: entries, root: root, manifest: &manifest,
                                           alsoTXT: alsoTXT, includeMedia: includeMedia)
                results.append(DayWriteResult(dayKey: key, outcome: outcome))
            } catch {
                results.append(DayWriteResult(dayKey: key, outcome: .failed(Self.describe(error))))
            }
        }

        manifest.updatedAt = Date()
        do {
            try coordinatedWrite(try encoder.encode(manifest), to: root.manifestURL)
        } catch {
            // Day files are already safely written; a manifest failure is reported but
            // doesn't invalidate them (restore works without the manifest).
            results = results.map { r in
                if case .failed = r.outcome { return r }
                return DayWriteResult(dayKey: r.dayKey, outcome: .failed("Saved the entry file, but couldn't update manifest.json: \(Self.describe(error))"))
            }
        }
        return results
    }

    private func writeDay(key: String, entries: [JournalEntrySnapshot], root: ResolvedBackupRoot,
                          manifest: inout BackupManifest, alsoTXT: Bool, includeMedia: Bool) throws -> DayWriteResult.Outcome {
        let relative = DayKey.relativePath(for: key)
        let fileURL = root.journalURL.appendingPathComponent(relative)
        let previousInfo = manifest.days[key]

        // Day has no entries any more → archive the old file into Version History.
        if entries.isEmpty {
            if fm.fileExists(atPath: fileURL.path) {
                try snapshot(fileURL: fileURL, key: key, root: root, reason: "removed")
                try coordinatedDelete(fileURL)
                let txtURL = fileURL.deletingPathExtension().appendingPathExtension("txt")
                if fm.fileExists(atPath: txtURL.path) { try? coordinatedDelete(txtURL) }
            }
            manifest.days[key] = nil
            return .removed
        }

        let markdown = JournalMarkdownCodec.renderDay(key: key, entries: entries)
        let data = Data(markdown.utf8)
        let newHash = JournalMarkdownCodec.sha256(data)
        let newIDs = entries.map(\.id)
        var snapshotAt = previousInfo?.lastSnapshotAt

        if includeMedia { try copyMedia(for: entries, root: root) }

        // Existing file: decide whether to keep a recoverable copy first.
        if let existing = try? coordinatedRead(fileURL) {
            let existingHash = JournalMarkdownCodec.sha256(existing)
            if existingHash == newHash {
                // Duplicate prevention: identical content, nothing to write.
                manifest.days[key] = BackupManifest.DayInfo(path: relative, sha256: newHash, entryIDs: newIDs,
                                                            writtenAt: previousInfo?.writtenAt ?? Date(),
                                                            lastSnapshotAt: previousInfo?.lastSnapshotAt)
                return .unchanged(path: relative, hash: newHash, entryCount: entries.count, ubiquitous: root.isUbiquitous)
            }
            let existingIDs = JournalMarkdownCodec.entryIDs(in: String(decoding: existing, as: UTF8.self))
            let changedOutsideApp = previousInfo == nil || previousInfo?.sha256 != existingHash
            let entriesRemoved = !existingIDs.isSubset(of: Set(newIDs))
            let snapshotDue = (previousInfo?.lastSnapshotAt).map { Date().timeIntervalSince($0) > Self.snapshotInterval } ?? true
            // Never silently overwrite something we didn't write ourselves, never drop
            // entries without a copy, and keep periodic copies during long edits.
            if changedOutsideApp || entriesRemoved || snapshotDue {
                try snapshot(fileURL: fileURL, key: key, root: root,
                             reason: changedOutsideApp ? "external" : (entriesRemoved ? "removed" : "auto"))
                snapshotAt = Date()
            }
        }

        try ensureDirectory(fileURL.deletingLastPathComponent())
        try coordinatedWrite(data, to: fileURL)

        // Integrity check: read back and compare hashes.
        let readBack = try coordinatedRead(fileURL)
        guard JournalMarkdownCodec.sha256(readBack) == newHash else {
            throw BackupWriteError.verificationFailed(relative)
        }

        if alsoTXT {
            let txt = JournalMarkdownCodec.renderPlainDay(key: key, entries: entries)
            try? coordinatedWrite(Data(txt.utf8), to: fileURL.deletingPathExtension().appendingPathExtension("txt"))
        }

        manifest.days[key] = BackupManifest.DayInfo(path: relative, sha256: newHash, entryIDs: newIDs, writtenAt: Date(),
                                                    lastSnapshotAt: snapshotAt)
        return .written(path: relative, hash: newHash, entryCount: entries.count, ubiquitous: root.isUbiquitous)
    }

    // MARK: Version history

    private func snapshot(fileURL: URL, key: String, root: ResolvedBackupRoot, reason: String) throws {
        guard fm.fileExists(atPath: fileURL.path) else { return }
        let folder = root.historyURL.appendingPathComponent((DayKey.relativePath(for: key) as NSString).deletingPathExtension, isDirectory: true)
        try ensureDirectory(folder)
        let stamp = Self.stampFormatter.string(from: Date())
        let dest = folder.appendingPathComponent("\(key) \(stamp) \(reason).md")
        let data = try coordinatedRead(fileURL)
        try coordinatedWrite(data, to: dest)
        pruneVersions(in: folder)
    }

    private func pruneVersions(in folder: URL) {
        guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        let sorted = files.filter { $0.pathExtension == "md" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        for old in sorted.dropFirst(Self.maxVersionsPerDay) { try? coordinatedDelete(old) }
    }

    /// Lists the saved versions of a day, newest first.
    func versions(for key: String, root: ResolvedBackupRoot) -> [URL] {
        let accessing = root.scopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if accessing { root.scopedURL?.stopAccessingSecurityScopedResource() } }
        let folder = root.historyURL.appendingPathComponent((DayKey.relativePath(for: key) as NSString).deletingPathExtension, isDirectory: true)
        let files = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "md" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    func readText(_ url: URL, root: ResolvedBackupRoot) -> String? {
        let accessing = root.scopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if accessing { root.scopedURL?.stopAccessingSecurityScopedResource() } }
        return (try? coordinatedRead(url)).map { String(decoding: $0, as: UTF8.self) }
    }

    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        return f
    }()

    // MARK: Media

    private func copyMedia(for entries: [JournalEntrySnapshot], root: ResolvedBackupRoot) throws {
        for entry in entries where !entry.attachments.isEmpty {
            let folder = root.mediaURL.appendingPathComponent(entry.id.uuidString, isDirectory: true)
            for a in entry.attachments {
                let source = MediaStore.shared.url(for: a.fileName)
                let dest = folder.appendingPathComponent(a.fileName)
                // Media file names are UUIDs and never change content, so an existing copy is current.
                guard fm.fileExists(atPath: source.path), !fm.fileExists(atPath: dest.path) else { continue }
                try ensureDirectory(folder)
                try coordinatedCopy(from: source, to: dest)
            }
        }
    }

    // MARK: Upload status (iCloud)

    /// Returns `true` if iCloud reports the file as uploaded, `false` if still pending,
    /// or an error message if iCloud reported an upload error.
    func uploadStatus(relativePath: String, root: ResolvedBackupRoot) -> Result<Bool, BackupWriteError> {
        let accessing = root.scopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if accessing { root.scopedURL?.stopAccessingSecurityScopedResource() } }
        var url = root.journalURL.appendingPathComponent(relativePath)
        url.removeAllCachedResourceValues()
        do {
            let values = try url.resourceValues(forKeys: [.ubiquitousItemIsUploadedKey, .ubiquitousItemIsUploadingKey, .ubiquitousItemUploadingErrorKey])
            if let error = values.ubiquitousItemUploadingError {
                return .failure(.uploadError(error.localizedDescription))
            }
            return .success(values.ubiquitousItemIsUploaded ?? false)
        } catch {
            return .failure(.uploadError(Self.describe(error)))
        }
    }

    // MARK: Integrity

    func verify(root: ResolvedBackupRoot) -> IntegrityReport {
        let accessing = root.scopedURL?.startAccessingSecurityScopedResource() ?? false
        defer { if accessing { root.scopedURL?.stopAccessingSecurityScopedResource() } }
        var report = IntegrityReport()
        guard let manifest = loadManifest(root) else {
            report.manifestMissing = true
            return report
        }
        for (key, info) in manifest.days {
            report.checked += 1
            let url = root.journalURL.appendingPathComponent(info.path)
            guard let data = try? coordinatedRead(url) else { report.missing.append(key); continue }
            if JournalMarkdownCodec.sha256(data) == info.sha256 { report.ok += 1 } else { report.mismatched.append(key) }
        }
        report.missing.sort(); report.mismatched.sort()
        return report
    }

    func loadManifest(_ root: ResolvedBackupRoot) -> BackupManifest? {
        guard let data = try? coordinatedRead(root.manifestURL) else { return nil }
        return try? decoder.decode(BackupManifest.self, from: data)
    }

    // MARK: Helpers

    private func writeReadmeIfNeeded(_ root: ResolvedBackupRoot) throws {
        let url = root.rootURL.appendingPathComponent("README.txt")
        guard !fm.fileExists(atPath: url.path) else { return }
        let text = """
        TXAWPAY — Your world, in one place.

        "Journal Backups" contains one Markdown (.md) file per day, organised by year and month.
        Each file holds the complete text of that day's journal entries with their title, mood,
        tags and timestamps. You can open these files with any text editor.

        To restore: install TXAWPAY, open Profile › Restore Journal and choose this TXAWPAY folder.

        "Version History" keeps earlier copies of day files before they were changed or removed.
        "Media" holds photos and videos attached to entries.

        Privacy: these files are NOT encrypted by the TXAWPAY Face ID lock. Anyone with access to
        this folder can read them. Use TXAWPAY's encrypted export if you need stronger protection.
        """
        try coordinatedWrite(Data(text.utf8), to: url)
    }

    private func ensureDirectory(_ url: URL) throws {
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue { return }
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// Atomic replacement through NSFileCoordinator, so iCloud Drive and file
    /// providers see a consistent file and never a half-written one.
    private func coordinatedWrite(_ data: Data, to url: URL) throws {
        var coordError: NSError?
        var writeError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { target in
            do { try data.write(to: target, options: .atomic) } catch { writeError = error }
        }
        if let e = coordError ?? writeError { throw e }
    }

    private func coordinatedRead(_ url: URL) throws -> Data {
        var coordError: NSError?
        var result: Result<Data, Error> = .failure(BackupWriteError.unreadable(url.lastPathComponent))
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordError) { target in
            result = Result { try Data(contentsOf: target) }
        }
        if let coordError { throw coordError }
        return try result.get()
    }

    private func coordinatedDelete(_ url: URL) throws {
        var coordError: NSError?
        var deleteError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forDeleting, error: &coordError) { target in
            do { try FileManager.default.removeItem(at: target) } catch { deleteError = error }
        }
        if let e = coordError ?? deleteError { throw e }
    }

    private func coordinatedCopy(from source: URL, to dest: URL) throws {
        var coordError: NSError?
        var copyError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: source, options: [], writingItemAt: dest, options: .forReplacing, error: &coordError) { src, dst in
            do { try FileManager.default.copyItem(at: src, to: dst) } catch { copyError = error }
        }
        if let e = coordError ?? copyError { throw e }
    }

    static func describe(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain {
            switch ns.code {
            case NSFileWriteOutOfSpaceError: return "There isn't enough storage space."
            case NSFileWriteNoPermissionError, NSFileReadNoPermissionError: return "Permission was denied for the backup folder."
            case NSFileNoSuchFileError, NSFileReadNoSuchFileError: return "The backup folder couldn't be found."
            default: break
            }
        }
        return error.localizedDescription
    }
}

enum BackupWriteError: LocalizedError, Sendable {
    case verificationFailed(String)
    case unreadable(String)
    case uploadError(String)

    var errorDescription: String? {
        switch self {
        case .verificationFailed(let path): "The file \(path) didn't match after writing. It will be retried."
        case .unreadable(let name): "\(name) couldn't be read."
        case .uploadError(let message): "iCloud upload problem: \(message)"
        }
    }
}
