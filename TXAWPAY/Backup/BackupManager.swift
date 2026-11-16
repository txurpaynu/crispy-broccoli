import Foundation
import SwiftData
import SwiftUI
import Network
import UIKit

/// Orchestrates automatic journal backups.
///
/// Flow
/// 1. Any change to a journal entry calls `entryChanged(_:previousDayKey:)`.
///    The affected day(s) get a `BackupRecord` in `.pending` state, which is
///    persisted immediately, so a crash or force-quit can't lose the fact that
///    a backup is owed.
/// 2. Writes are debounced (`debounceInterval`) while the person types, and
///    flushed immediately when the editor closes, the app goes to the
///    background, or the app launches with pending records.
/// 3. `BackupWriter` (an actor) renders and writes the day files atomically,
///    keeps version history, verifies the result and updates manifest.json.
/// 4. iCloud files move to `.waitingForICloud` and only become `.completed`
///    once iCloud reports `ubiquitousItemIsUploaded`. A local write is never
///    reported as an iCloud success.
/// 5. Failures are retried with exponential back-off, on foreground, and when
///    the network comes back.
@MainActor
final class BackupManager: ObservableObject {
    static private(set) weak var shared: BackupManager?

    @Published private(set) var isRunning = false
    @Published private(set) var lastSuccess: Date?
    @Published private(set) var lastMessage: String?
    @Published private(set) var stats = Stats()
    @Published var resolvedPath: String = ""

    struct Stats: Equatable {
        var pending = 0
        var failed = 0
        var waitingForICloud = 0
        var savedLocally = 0
        var completed = 0
        var backedUpEntries = 0
        var lastError: String?
    }

    @AppStorage(AppSettings.Keys.backupEnabled) var isEnabled = true
    @AppStorage(AppSettings.Keys.backupDestination) private var destinationRaw = BackupDestinationKind.onDevice.rawValue
    @AppStorage(AppSettings.Keys.backupAlsoTXT) var alsoTXT = false
    @AppStorage(AppSettings.Keys.backupIncludeMedia) var includeMedia = true
    @AppStorage(AppSettings.Keys.backupFolderName) var folderName = ""

    let debounceInterval: TimeInterval = 2.0
    private let container: ModelContainer
    private let writer = BackupWriter()
    private var debounceTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var uploadPollTask: Task<Void, Never>?
    private var retryAttempt = 0
    private let pathMonitor = NWPathMonitor()
    private var networkWasAvailable = true

    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
        self.lastSuccess = UserDefaults.standard.object(forKey: "backupLastSuccess") as? Date
        BackupManager.shared = self
        startNetworkMonitoring()
    }

    var destination: BackupDestinationKind {
        get { BackupDestinationKind(rawValue: destinationRaw) ?? .onDevice }
        set { destinationRaw = newValue.rawValue; objectWillChange.send() }
    }

    // MARK: - Change tracking

    /// Call after any create/edit of a journal entry (already saved to SwiftData).
    func entryChanged(_ entry: JournalEntry, previousDayKey: String? = nil) {
        guard !entry.isDemo else { return }
        var keys: Set<String> = [DayKey.key(for: entry.date)]
        if let previousDayKey { keys.insert(previousDayKey) }
        if let last = entry.lastBackupDayKey { keys.insert(last) }
        markDirty(keys)
        scheduleDebounced()
    }

    /// Call *before* deleting an entry (so we still know its day).
    func entryWillBeDeleted(_ entry: JournalEntry) {
        guard !entry.isDemo else { return }
        var keys: Set<String> = [DayKey.key(for: entry.date)]
        if let last = entry.lastBackupDayKey { keys.insert(last) }
        markDirty(keys)
    }

    /// Call after a deletion has been saved.
    func entriesDeleted() {
        scheduleDebounced()
    }

    func markDirty(_ keys: Set<String>) {
        for key in keys {
            let record = fetchRecord(key) ?? {
                let r = BackupRecord(dayKey: key)
                context.insert(r)
                return r
            }()
            record.state = .pending
            record.retryCount = 0
        }
        try? context.save()
        refreshStats()
    }

    private func scheduleDebounced() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.debounceInterval ?? 2) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.processPending()
        }
    }

    /// Flushes immediately (editor closed, explicit save).
    func flushNow() {
        debounceTask?.cancel()
        Task { await processPending() }
    }

    /// Runs the pending backup inside a UIKit background task so it completes
    /// even though the app is being suspended.
    func flushForBackground() {
        debounceTask?.cancel()
        var taskID = UIBackgroundTaskIdentifier.invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: "TXAWPAY journal backup") {
            UIApplication.shared.endBackgroundTask(taskID)
            taskID = .invalid
        }
        Task {
            await processPending()
            if taskID != .invalid { UIApplication.shared.endBackgroundTask(taskID) }
        }
    }

    func launchCheck() async {
        refreshStats()
        if isEnabled, stats.pending + stats.failed > 0 {
            await processPending(includeFailed: true)
        }
        await checkUploads()
    }

    func resumeAfterForeground() async {
        guard isEnabled else { return }
        if stats.pending + stats.failed > 0 { await processPending(includeFailed: true) }
        await checkUploads()
    }

    // MARK: - Processing

    /// Writes all pending (and optionally failed) day files.
    func processPending(includeFailed: Bool = true) async {
        guard isEnabled, !isRunning else { return }
        let records = allRecords().filter { $0.state == .pending || (includeFailed && $0.state == .failed) }
        guard !records.isEmpty else { refreshStats(); return }
        await run(dayKeys: Set(records.map(\.dayKey)))
    }

    /// Manual "Back up now": rewrites every day that has entries.
    func backUpEverything() async {
        guard !isRunning else { return }
        let entries = (try? context.fetch(FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.isDemo == false }))) ?? []
        var keys = Set(entries.map { DayKey.key(for: $0.date) })
        // Also revisit days that used to have entries (to archive removed ones).
        keys.formUnion(allRecords().map(\.dayKey))
        markDirty(keys)
        await run(dayKeys: keys)
    }

    private func run(dayKeys: Set<String>) async {
        isRunning = true
        defer { isRunning = false; refreshStats() }

        // Build value snapshots on the main actor.
        var payload: [String: [JournalEntrySnapshot]] = [:]
        var entryByID: [UUID: JournalEntry] = [:]
        for key in dayKeys {
            guard let day = DayKey.date(fromKey: key) else { continue }
            let (start, end) = DateMath.dayRange(day)
            let descriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.date >= start && $0.date < end && $0.isDemo == false })
            let entries = (try? context.fetch(descriptor)) ?? []
            payload[key] = entries.map { JournalEntrySnapshot($0) }
            for e in entries { entryByID[e.id] = e }
        }

        let kind = destination
        let bookmark = UserDefaults.standard.data(forKey: AppSettings.Keys.backupFolderBookmark)
        let root: ResolvedBackupRoot
        do {
            root = try await Task.detached(priority: .utility) {
                try BackupDestinationResolver.resolve(kind: kind, bookmark: bookmark)
            }.value
        } catch {
            markFailed(dayKeys, message: error.localizedDescription)
            scheduleRetry()
            return
        }
        resolvedPath = root.displayPath

        let results = await writer.write(days: payload, to: root, alsoTXT: alsoTXT, includeMedia: includeMedia)

        var anyFailure = false
        var anyWaiting = false
        for result in results {
            guard let record = fetchRecord(result.dayKey) else { continue }
            record.lastAttempt = Date()
            record.destinationRaw = kind.rawValue
            switch result.outcome {
            case let .written(path, hash, count, ubiquitous), let .unchanged(path, hash, count, ubiquitous):
                record.relativePath = path
                record.contentHash = hash
                record.entryCount = count
                record.lastError = ""
                record.retryCount = 0
                record.lastSuccess = Date()
                if ubiquitous {
                    record.state = .waitingForICloud
                    anyWaiting = true
                } else {
                    record.state = kind == .onDevice ? .savedLocally : .completed
                }
                for entry in entryByID.values where DayKey.key(for: entry.date) == result.dayKey {
                    entry.lastBackupDayKey = result.dayKey
                }
            case .removed:
                // Nothing left to back up for this day; forget the record.
                context.delete(record)
            case .failed(let message):
                record.state = .failed
                record.lastError = message
                record.retryCount += 1
                anyFailure = true
            }
        }
        try? context.save()

        if anyFailure {
            lastMessage = "Some days couldn't be backed up. TXAWPAY will retry."
            scheduleRetry()
        } else {
            retryAttempt = 0
            lastSuccess = Date()
            UserDefaults.standard.set(lastSuccess, forKey: "backupLastSuccess")
            lastMessage = nil
        }
        if anyWaiting { startUploadPolling() }
    }

    private func markFailed(_ keys: Set<String>, message: String) {
        for key in keys {
            let record = fetchRecord(key) ?? {
                let r = BackupRecord(dayKey: key); context.insert(r); return r
            }()
            record.state = .failed
            record.lastError = message
            record.lastAttempt = Date()
            record.retryCount += 1
        }
        try? context.save()
        lastMessage = message
        refreshStats()
    }

    /// Exponential back-off: 30 s, 1 min, 2 min … capped at 30 min.
    private func scheduleRetry() {
        retryTask?.cancel()
        retryAttempt += 1
        let delay = min(30.0 * pow(2.0, Double(retryAttempt - 1)), 1800)
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.processPending(includeFailed: true)
        }
    }

    // MARK: - iCloud upload confirmation

    func checkUploads() async {
        let waiting = allRecords().filter { $0.state == .waitingForICloud }
        guard !waiting.isEmpty else { return }
        let kind = destination
        let bookmark = UserDefaults.standard.data(forKey: AppSettings.Keys.backupFolderBookmark)
        guard let root = try? await Task.detached(priority: .utility, operation: {
            try BackupDestinationResolver.resolve(kind: kind, bookmark: bookmark)
        }).value else { return }

        for record in waiting {
            let status = await writer.uploadStatus(relativePath: record.relativePath, root: root)
            switch status {
            case .success(true):
                record.state = .completed
                record.lastError = ""
            case .success(false):
                break // still uploading or waiting for network
            case .failure(let error):
                // Keep the state honest: the file is saved, but iCloud has a problem.
                record.lastError = error.localizedDescription
            }
        }
        try? context.save()
        refreshStats()
    }

    private func startUploadPolling() {
        guard uploadPollTask == nil else { return }
        uploadPollTask = Task { [weak self] in
            // Poll for up to ~10 minutes while the app is open; on later launches
            // `launchCheck` picks up anything still waiting.
            for _ in 0..<40 {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard let self, !Task.isCancelled else { break }
                await self.checkUploads()
                if self.stats.waitingForICloud == 0 { break }
            }
            self?.uploadPollTask = nil
        }
    }

    // MARK: - Network

    private func startNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                defer { self.networkWasAvailable = available }
                // Device came back online → retry failures and confirm pending uploads.
                if available && !self.networkWasAvailable {
                    await self.processPending(includeFailed: true)
                    await self.checkUploads()
                    self.startUploadPolling()
                }
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "txawpay.backup.network"))
    }

    // MARK: - Destination management

    /// Saves a security-scoped bookmark for a folder picked in Files.
    func setFolder(_ url: URL) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw BackupDestinationError.permissionDenied("Please choose the folder again.")
        }
        defer { url.stopAccessingSecurityScopedResource() }
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: AppSettings.Keys.backupFolderBookmark)
        folderName = url.lastPathComponent
        destination = .folder
    }

    /// Switching destination rewrites the whole journal to the new location.
    func changeDestination(to kind: BackupDestinationKind) async {
        destination = kind
        for record in allRecords() { record.state = .pending }
        try? context.save()
        await backUpEverything()
    }

    func resolveRoot() async throws -> ResolvedBackupRoot {
        let kind = destination
        let bookmark = UserDefaults.standard.data(forKey: AppSettings.Keys.backupFolderBookmark)
        return try await Task.detached(priority: .userInitiated) {
            try BackupDestinationResolver.resolve(kind: kind, bookmark: bookmark)
        }.value
    }

    func verifyIntegrity() async -> Result<IntegrityReport, Error> {
        do {
            let root = try await resolveRoot()
            return .success(await writer.verify(root: root))
        } catch {
            return .failure(error)
        }
    }

    func versions(for dayKey: String) async -> [URL] {
        guard let root = try? await resolveRoot() else { return [] }
        return await writer.versions(for: dayKey, root: root)
    }

    func readVersion(_ url: URL) async -> String? {
        guard let root = try? await resolveRoot() else { return nil }
        return await writer.readText(url, root: root)
    }

    // MARK: - Records

    func allRecords() -> [BackupRecord] {
        (try? context.fetch(FetchDescriptor<BackupRecord>(sortBy: [SortDescriptor(\.dayKey, order: .reverse)]))) ?? []
    }

    private func fetchRecord(_ key: String) -> BackupRecord? {
        var d = FetchDescriptor<BackupRecord>(predicate: #Predicate { $0.dayKey == key })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    func refreshStats() {
        var s = Stats()
        for r in allRecords() {
            switch r.state {
            case .pending: s.pending += 1
            case .failed: s.failed += 1; s.lastError = s.lastError ?? r.lastError
            case .waitingForICloud: s.waitingForICloud += 1; s.backedUpEntries += r.entryCount
            case .savedLocally: s.savedLocally += 1; s.backedUpEntries += r.entryCount
            case .completed: s.completed += 1; s.backedUpEntries += r.entryCount
            }
        }
        stats = s
    }

    /// Overall headline status for the backup screen and Profile.
    var overallState: BackupState {
        if !isEnabled { return .pending }
        if stats.failed > 0 { return .failed }
        if stats.pending > 0 { return .pending }
        if stats.waitingForICloud > 0 { return .waitingForICloud }
        if destination == .onDevice && stats.savedLocally > 0 { return .savedLocally }
        return .completed
    }
}
