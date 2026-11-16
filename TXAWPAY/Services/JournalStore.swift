import Foundation
import SwiftData

/// Single entry point for journal mutations, so every change is saved to
/// SwiftData *and* reported to the backup engine. Views never delete or
/// save journal entries directly.
@MainActor
enum JournalStore {
    /// Saves an entry after editing. `previousDayKey` is the entry's day before the edit.
    static func save(_ entry: JournalEntry, previousDayKey: String?, in context: ModelContext, touch: Bool = true) throws {
        if touch { entry.modifiedAt = Date() }
        if entry.modelContext == nil { context.insert(entry) }
        try context.save()
        BackupManager.shared?.entryChanged(entry, previousDayKey: previousDayKey)
    }

    static func delete(_ entry: JournalEntry, in context: ModelContext) throws {
        BackupManager.shared?.entryWillBeDeleted(entry)
        for a in entry.attachments ?? [] { MediaStore.shared.delete(a.fileName) }
        RecentsStore.shared.remove(id: entry.id)
        context.delete(entry)
        try context.save()
        BackupManager.shared?.entriesDeleted()
    }

    /// Quick creation used by Quick Capture and Home.
    @discardableResult
    static func create(title: String, body: String, date: Date = Date(), mood: Mood? = nil,
                       category: JournalCategory? = nil, in context: ModelContext) throws -> JournalEntry {
        let entry = JournalEntry(title: title, body: body, date: date)
        entry.mood = mood
        entry.category = category
        context.insert(entry)
        try context.save()
        BackupManager.shared?.entryChanged(entry)
        BackupManager.shared?.flushNow()
        return entry
    }

    /// Entries written on this calendar day in previous years.
    static func onThisDay(_ entries: [JournalEntry], reference: Date = Date()) -> [JournalEntry] {
        let cal = Calendar.current
        let m = cal.component(.month, from: reference), d = cal.component(.day, from: reference)
        let y = cal.component(.year, from: reference)
        return entries.filter {
            cal.component(.month, from: $0.date) == m && cal.component(.day, from: $0.date) == d && cal.component(.year, from: $0.date) < y
        }.sorted { $0.date > $1.date }
    }
}
