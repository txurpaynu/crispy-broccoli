import Foundation
import SwiftData

/// Complete export of everything in TXAWPAY (all modules) as JSON + media in a ZIP,
/// and the matching import ("Restore data"). The journal is also included as
/// Markdown day files so the export is readable without the app.
///
/// Import merges by stable id: existing items are left untouched, missing ones
/// are created, and links between items are restored by id.
enum DataExportService {
    static let formatVersion = 1

    // MARK: DTOs

    struct MediaRef: Codable { var id: UUID; var kind: String; var role: String; var fileName: String; var originalFileName: String; var caption: String; var createdAt: Date }
    struct CategoryDTO: Codable { var id: UUID; var name: String; var symbol: String; var colorHex: String; var isBuiltIn: Bool; var sortOrder: Int }
    struct EntryDTO: Codable {
        var snapshot: JournalEntrySnapshot
        var categoryID: UUID?; var tripID: UUID?; var projectID: UUID?; var personIDs: [UUID]
        var media: [MediaRef]
    }
    struct MemoryDTO: Codable {
        var id: UUID; var title: String; var text: String; var date: Date; var kind: String; var tags: [String]; var isFavorite: Bool
        var collection: String; var locationName: String; var latitude: Double?; var longitude: Double?; var createdAt: Date; var modifiedAt: Date
        var entryIDs: [UUID]; var tripID: UUID?; var projectID: UUID?; var personIDs: [UUID]; var media: [MediaRef]
    }
    struct PlaceDTO: Codable {
        var id: UUID; var name: String; var city: String; var country: String; var countryCode: String; var kind: String; var status: String
        var latitude: Double?; var longitude: Double?; var notes: String; var visitedDate: Date?; var createdAt: Date; var tripID: UUID?; var media: [MediaRef]
    }
    struct TripDTO: Codable {
        var id: UUID; var title: String; var destination: String; var countryCode: String; var startDate: Date; var endDate: Date; var hasDates: Bool
        var status: String; var itinerary: String; var notes: String; var memoriesText: String; var coverFileName: String; var createdAt: Date; var modifiedAt: Date
        var media: [MediaRef]
    }
    struct MilestoneDTO: Codable { var id: UUID; var title: String; var dueDate: Date?; var isDone: Bool; var completedAt: Date?; var sortOrder: Int; var createdAt: Date }
    struct UpdateDTO: Codable { var id: UUID; var date: Date; var text: String; var symbol: String }
    struct ProjectDTO: Codable {
        var id: UUID; var name: String; var summary: String; var category: String; var status: String; var coverFileName: String; var notes: String
        var createdAt: Date; var modifiedAt: Date; var completedAt: Date?; var milestones: [MilestoneDTO]; var updates: [UpdateDTO]; var media: [MediaRef]
    }
    struct SessionDTO: Codable { var id: UUID; var subject: String; var date: Date; var durationMinutes: Int; var notes: String; var learned: String; var nextSteps: String }
    struct GoalDTO: Codable {
        var id: UUID; var skillName: String; var summary: String; var category: String; var startDate: Date; var targetDate: Date?; var progress: Double
        var notes: String; var resources: String; var isCompleted: Bool; var completedAt: Date?; var reminderEnabled: Bool; var createdAt: Date; var sessions: [SessionDTO]
    }
    struct DateDTO: Codable { var id: UUID; var title: String; var date: Date; var kind: String; var repeatsYearly: Bool; var remind: Bool; var notes: String }
    struct PersonDTO: Codable {
        var id: UUID; var name: String; var photoFileName: String; var birthday: Date?; var birthdayReminder: Bool; var relationship: String; var notes: String
        var createdAt: Date; var dates: [DateDTO]; var media: [MediaRef]
    }
    struct ExerciseDTO: Codable { var id: UUID; var name: String; var sets: Int; var reps: Int; var durationSeconds: Int; var notes: String; var sortOrder: Int; var isLibraryItem: Bool; var focusArea: String; var date: Date }
    struct WorkoutDTO: Codable {
        var id: UUID; var name: String; var date: Date; var durationMinutes: Int; var notes: String; var isCompleted: Bool; var isTemplate: Bool
        var scheduledWeekdays: [Int]; var reminderEnabled: Bool; var createdAt: Date; var exercises: [ExerciseDTO]
    }
    struct LogDTO: Codable { var id: UUID; var date: Date; var kind: String; var value: Double; var quality: Int; var notes: String }
    struct RoutineDTO: Codable { var id: UUID; var name: String; var steps: [String]; var timeOfDay: String; var isActive: Bool; var lastCompleted: Date?; var createdAt: Date }
    struct TaskDTO: Codable { var id: UUID; var title: String; var notes: String; var dueDate: Date?; var hasDueTime: Bool; var isDone: Bool; var completedAt: Date?; var priority: Int; var reminderEnabled: Bool; var createdAt: Date }
    struct ReminderDTO: Codable { var id: UUID; var title: String; var message: String; var fireDate: Date; var repeats: String; var kind: String; var isEnabled: Bool; var createdAt: Date }
    struct EventDTO: Codable { var id: UUID; var title: String; var date: Date; var notes: String; var kind: String; var reminderEnabled: Bool; var createdAt: Date }
    struct ProfileDTO: Codable { var displayName: String; var avatarFileName: String; var bio: String; var memberSince: Date }

    struct ExportBundle: Codable {
        var formatVersion: Int
        var exportedAt: Date
        var profile: ProfileDTO?
        var categories: [CategoryDTO]
        var entries: [EntryDTO]
        var memories: [MemoryDTO]
        var trips: [TripDTO]
        var places: [PlaceDTO]
        var projects: [ProjectDTO]
        var goals: [GoalDTO]
        var people: [PersonDTO]
        var workouts: [WorkoutDTO]
        var exerciseLibrary: [ExerciseDTO]
        var wellbeing: [LogDTO]
        var routines: [RoutineDTO]
        var tasks: [TaskDTO]
        var reminders: [ReminderDTO]
        var events: [EventDTO]
    }

    // MARK: Export

    private static func refs(_ list: [JournalAttachment]?) -> [MediaRef] {
        (list ?? []).map { MediaRef(id: $0.id, kind: $0.kindRaw, role: $0.roleRaw, fileName: $0.fileName, originalFileName: $0.originalFileName, caption: $0.caption, createdAt: $0.createdAt) }
    }

    @MainActor
    static func makeBundle(context: ModelContext) -> ExportBundle {
        func all<T: PersistentModel>(_ t: T.Type) -> [T] { (try? context.fetch(FetchDescriptor<T>())) ?? [] }
        let profile = all(UserSettings.self).first.map { ProfileDTO(displayName: $0.displayName, avatarFileName: $0.avatarFileName, bio: $0.bio, memberSince: $0.memberSince) }
        return ExportBundle(
            formatVersion: formatVersion, exportedAt: Date(), profile: profile,
            categories: all(JournalCategory.self).map { CategoryDTO(id: $0.id, name: $0.name, symbol: $0.symbol, colorHex: $0.colorHex, isBuiltIn: $0.isBuiltIn, sortOrder: $0.sortOrder) },
            entries: all(JournalEntry.self).filter { !$0.isDemo }.map {
                EntryDTO(snapshot: JournalEntrySnapshot($0), categoryID: $0.category?.id, tripID: $0.trip?.id, projectID: $0.project?.id,
                         personIDs: ($0.people ?? []).map(\.id), media: refs($0.attachments))
            },
            memories: all(Memory.self).filter { !$0.isDemo }.map {
                MemoryDTO(id: $0.id, title: $0.title, text: $0.text, date: $0.date, kind: $0.kindRaw, tags: $0.tags, isFavorite: $0.isFavorite,
                          collection: $0.collection, locationName: $0.locationName, latitude: $0.latitude, longitude: $0.longitude,
                          createdAt: $0.createdAt, modifiedAt: $0.modifiedAt, entryIDs: ($0.journalEntries ?? []).map(\.id),
                          tripID: $0.trip?.id, projectID: $0.project?.id, personIDs: ($0.people ?? []).map(\.id), media: refs($0.attachments))
            },
            trips: all(TravelTrip.self).filter { !$0.isDemo }.map {
                TripDTO(id: $0.id, title: $0.title, destination: $0.destination, countryCode: $0.countryCode, startDate: $0.startDate, endDate: $0.endDate,
                        hasDates: $0.hasDates, status: $0.statusRaw, itinerary: $0.itinerary, notes: $0.notes, memoriesText: $0.memoriesText,
                        coverFileName: $0.coverFileName, createdAt: $0.createdAt, modifiedAt: $0.modifiedAt, media: refs($0.attachments))
            },
            places: all(TravelDestination.self).filter { !$0.isDemo }.map {
                PlaceDTO(id: $0.id, name: $0.name, city: $0.city, country: $0.country, countryCode: $0.countryCode, kind: $0.kindRaw, status: $0.statusRaw,
                         latitude: $0.latitude, longitude: $0.longitude, notes: $0.notes, visitedDate: $0.visitedDate, createdAt: $0.createdAt,
                         tripID: $0.trip?.id, media: refs($0.attachments))
            },
            projects: all(CreativeProject.self).filter { !$0.isDemo }.map { p in
                ProjectDTO(id: p.id, name: p.name, summary: p.summary, category: p.category, status: p.statusRaw, coverFileName: p.coverFileName,
                           notes: p.notes, createdAt: p.createdAt, modifiedAt: p.modifiedAt, completedAt: p.completedAt,
                           milestones: (p.milestones ?? []).map { MilestoneDTO(id: $0.id, title: $0.title, dueDate: $0.dueDate, isDone: $0.isDone, completedAt: $0.completedAt, sortOrder: $0.sortOrder, createdAt: $0.createdAt) },
                           updates: (p.updates ?? []).map { UpdateDTO(id: $0.id, date: $0.date, text: $0.text, symbol: $0.symbol) },
                           media: refs(p.attachments))
            },
            goals: all(LearningGoal.self).filter { !$0.isDemo }.map { g in
                GoalDTO(id: g.id, skillName: g.skillName, summary: g.summary, category: g.categoryRaw, startDate: g.startDate, targetDate: g.targetDate,
                        progress: g.progress, notes: g.notes, resources: g.resources, isCompleted: g.isCompleted, completedAt: g.completedAt,
                        reminderEnabled: g.reminderEnabled, createdAt: g.createdAt,
                        sessions: (g.sessions ?? []).map { SessionDTO(id: $0.id, subject: $0.subject, date: $0.date, durationMinutes: $0.durationMinutes, notes: $0.notes, learned: $0.learned, nextSteps: $0.nextSteps) })
            },
            people: all(Person.self).filter { !$0.isDemo }.map { p in
                PersonDTO(id: p.id, name: p.name, photoFileName: p.photoFileName, birthday: p.birthday, birthdayReminder: p.birthdayReminder,
                          relationship: p.relationship, notes: p.notes, createdAt: p.createdAt,
                          dates: (p.importantDates ?? []).map { DateDTO(id: $0.id, title: $0.title, date: $0.date, kind: $0.kindRaw, repeatsYearly: $0.repeatsYearly, remind: $0.remind, notes: $0.notes) },
                          media: refs(p.attachments))
            },
            workouts: all(Workout.self).filter { !$0.isDemo }.map { w in
                WorkoutDTO(id: w.id, name: w.name, date: w.date, durationMinutes: w.durationMinutes, notes: w.notes, isCompleted: w.isCompleted,
                           isTemplate: w.isTemplate, scheduledWeekdays: w.scheduledWeekdays, reminderEnabled: w.reminderEnabled, createdAt: w.createdAt,
                           exercises: (w.exercises ?? []).map(exerciseDTO))
            },
            exerciseLibrary: all(Exercise.self).filter { $0.isLibraryItem && $0.workout == nil }.map(exerciseDTO),
            wellbeing: all(WellbeingLog.self).filter { !$0.isDemo }.map { LogDTO(id: $0.id, date: $0.date, kind: $0.kindRaw, value: $0.value, quality: $0.quality, notes: $0.notes) },
            routines: all(Routine.self).filter { !$0.isDemo }.map { RoutineDTO(id: $0.id, name: $0.name, steps: $0.steps, timeOfDay: $0.timeOfDay, isActive: $0.isActive, lastCompleted: $0.lastCompleted, createdAt: $0.createdAt) },
            tasks: all(TaskItem.self).filter { !$0.isDemo }.map { TaskDTO(id: $0.id, title: $0.title, notes: $0.notes, dueDate: $0.dueDate, hasDueTime: $0.hasDueTime, isDone: $0.isDone, completedAt: $0.completedAt, priority: $0.priorityRaw, reminderEnabled: $0.reminderEnabled, createdAt: $0.createdAt) },
            reminders: all(Reminder.self).map { ReminderDTO(id: $0.id, title: $0.title, message: $0.message, fireDate: $0.fireDate, repeats: $0.repeatRaw, kind: $0.kindRaw, isEnabled: $0.isEnabled, createdAt: $0.createdAt) },
            events: all(LifeEvent.self).filter { !$0.isDemo }.map { EventDTO(id: $0.id, title: $0.title, date: $0.date, notes: $0.notes, kind: $0.kindRaw, reminderEnabled: $0.reminderEnabled, createdAt: $0.createdAt) }
        )
    }

    private static func exerciseDTO(_ e: Exercise) -> ExerciseDTO {
        ExerciseDTO(id: e.id, name: e.name, sets: e.sets, reps: e.reps, durationSeconds: e.durationSeconds, notes: e.notes,
                    sortOrder: e.sortOrder, isLibraryItem: e.isLibraryItem, focusArea: e.focusArea, date: e.date)
    }

    /// Every media file name referenced by the bundle.
    static func mediaFiles(in b: ExportBundle) -> Set<String> {
        var s = Set<String>()
        let groups: [[MediaRef]] = b.entries.map(\.media) + b.memories.map(\.media) + b.trips.map(\.media) + b.places.map(\.media)
            + b.projects.map(\.media) + b.people.map(\.media)
        for g in groups { for m in g { s.insert(m.fileName) } }
        for t in b.trips where !t.coverFileName.isEmpty { s.insert(t.coverFileName) }
        for p in b.projects where !p.coverFileName.isEmpty { s.insert(p.coverFileName) }
        for p in b.people where !p.photoFileName.isEmpty { s.insert(p.photoFileName) }
        if let a = b.profile?.avatarFileName, !a.isEmpty { s.insert(a) }
        return s
    }

    static func makeArchive(bundle: ExportBundle, password: String?) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let work = fm.temporaryDirectory.appendingPathComponent("full-export-\(UUID().uuidString)", isDirectory: true)
            try fm.createDirectory(at: work, withIntermediateDirectories: true)
            let stamp = DayKey.key(for: Date())
            let zipURL = work.appendingPathComponent("TXAWPAY Export \(stamp).zip")
            let zip = try ZipWriter(url: zipURL)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try zip.add(path: "TXAWPAY/txawpay-data.json", data: encoder.encode(bundle))

            // Journal as readable Markdown, in the standard backup layout.
            let byDay = Dictionary(grouping: bundle.entries.map(\.snapshot), by: \.dayKey)
            for (key, entries) in byDay {
                try zip.add(path: "TXAWPAY/Journal Backups/" + DayKey.relativePath(for: key),
                            data: Data(JournalMarkdownCodec.renderDay(key: key, entries: entries).utf8))
            }
            for e in bundle.entries {
                for m in e.media {
                    let src = MediaStore.shared.url(for: m.fileName)
                    if fm.fileExists(atPath: src.path) {
                        try zip.addFile(path: "TXAWPAY/Journal Backups/Media/\(e.snapshot.id.uuidString)/\(m.fileName)", from: src)
                    }
                }
            }
            // All media (including non-journal) for full restore.
            for name in mediaFiles(in: bundle).sorted() {
                let src = MediaStore.shared.url(for: name)
                if fm.fileExists(atPath: src.path) { try zip.addFile(path: "TXAWPAY/Media/\(name)", from: src) }
            }
            try zip.finish()

            guard let password, !password.isEmpty else { return zipURL }
            let sealed = try EncryptedArchive.encrypt(try Data(contentsOf: zipURL), password: password)
            let enc = work.appendingPathComponent("TXAWPAY Export \(stamp).\(EncryptedArchive.fileExtension)")
            try sealed.write(to: enc, options: .atomic)
            try? fm.removeItem(at: zipURL)
            return enc
        }.value
    }

    // MARK: Import

    struct ImportSummary { var created = 0; var skipped = 0; var media = 0 }

    enum ImportError: LocalizedError {
        case noDataFile, needsPassword
        var errorDescription: String? {
            switch self {
            case .noDataFile: "This isn't a full TXAWPAY export (txawpay-data.json is missing). To restore journal files, use Restore Journal."
            case .needsPassword: "This export is encrypted. Enter its password."
            }
        }
    }

    /// Unpacks an export and decodes its bundle. Returns the bundle and the extracted media folder.
    static func readArchive(_ url: URL, password: String?) async throws -> (ExportBundle, URL?) {
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let work = fm.temporaryDirectory.appendingPathComponent("full-import-\(UUID().uuidString)", isDirectory: true)
            try fm.createDirectory(at: work, withIntermediateDirectories: true)
            let zipURL = work.appendingPathComponent("archive.zip")
            if EncryptedArchive.isEncrypted(url) {
                guard let password, !password.isEmpty else { throw ImportError.needsPassword }
                try EncryptedArchive.decrypt(try Data(contentsOf: url), password: password).write(to: zipURL)
            } else {
                try fm.copyItem(at: url, to: zipURL)
            }
            let out = work.appendingPathComponent("x", isDirectory: true)
            try ZipReader.extract(archive: zipURL, to: out)
            let dataURL = out.appendingPathComponent("TXAWPAY/txawpay-data.json")
            guard let data = try? Data(contentsOf: dataURL) else { throw ImportError.noDataFile }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let bundle = try decoder.decode(ExportBundle.self, from: data)
            let media = out.appendingPathComponent("TXAWPAY/Media", isDirectory: true)
            return (bundle, fm.fileExists(atPath: media.path) ? media : nil)
        }.value
    }

    @MainActor
    static func importBundle(_ b: ExportBundle, mediaFolder: URL?, context: ModelContext) -> ImportSummary {
        var summary = ImportSummary()
        func existingIDs<T: PersistentModel>(_ t: T.Type, _ id: (T) -> UUID) -> [UUID: T] {
            Dictionary(((try? context.fetch(FetchDescriptor<T>())) ?? []).map { (id($0), $0) }, uniquingKeysWith: { a, _ in a })
        }
        func restoreMedia(_ name: String) {
            guard !name.isEmpty, let mediaFolder, !MediaStore.shared.exists(name) else { return }
            let src = mediaFolder.appendingPathComponent(name)
            if (try? MediaStore.shared.importFile(at: src, preservingName: name)) != nil { summary.media += 1 }
        }
        func attach(_ refs: [MediaRef], _ assign: (JournalAttachment) -> Void) {
            for r in refs {
                restoreMedia(r.fileName)
                let a = JournalAttachment(kind: AttachmentKind(rawValue: r.kind) ?? .file, fileName: r.fileName, originalFileName: r.originalFileName,
                                          role: AttachmentRole(rawValue: r.role) ?? .general)
                a.id = r.id; a.caption = r.caption; a.createdAt = r.createdAt
                context.insert(a)
                assign(a)
            }
        }

        var categories = existingIDs(JournalCategory.self) { $0.id }
        var categoriesByName = Dictionary(categories.values.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })
        for c in b.categories where categories[c.id] == nil {
            if let sameName = categoriesByName[c.name.lowercased()] { categories[c.id] = sameName; continue }
            let cat = JournalCategory(name: c.name, symbol: c.symbol, colorHex: c.colorHex, isBuiltIn: c.isBuiltIn, sortOrder: c.sortOrder)
            cat.id = c.id
            context.insert(cat); categories[c.id] = cat; categoriesByName[c.name.lowercased()] = cat
            summary.created += 1
        }

        var trips = existingIDs(TravelTrip.self) { $0.id }
        for t in b.trips {
            guard trips[t.id] == nil else { summary.skipped += 1; continue }
            let trip = TravelTrip(title: t.title, destination: t.destination, startDate: t.startDate, endDate: t.endDate, status: TripStatus(rawValue: t.status) ?? .planned)
            trip.id = t.id; trip.countryCode = t.countryCode; trip.hasDates = t.hasDates; trip.itinerary = t.itinerary; trip.notes = t.notes
            trip.memoriesText = t.memoriesText; trip.coverFileName = t.coverFileName; trip.createdAt = t.createdAt; trip.modifiedAt = t.modifiedAt
            restoreMedia(t.coverFileName)
            context.insert(trip); trips[t.id] = trip
            attach(t.media) { $0.trip = trip }
            summary.created += 1
        }
        let places = existingIDs(TravelDestination.self) { $0.id }
        for p in b.places {
            guard places[p.id] == nil else { summary.skipped += 1; continue }
            let place = TravelDestination(name: p.name, kind: PlaceKind(rawValue: p.kind) ?? .place, status: PlaceStatus(rawValue: p.status) ?? .saved)
            place.id = p.id; place.city = p.city; place.country = p.country; place.countryCode = p.countryCode
            place.latitude = p.latitude; place.longitude = p.longitude; place.notes = p.notes; place.visitedDate = p.visitedDate; place.createdAt = p.createdAt
            context.insert(place)
            place.trip = p.tripID.flatMap { trips[$0] }
            attach(p.media) { $0.place = place }
            summary.created += 1
        }

        var projects = existingIDs(CreativeProject.self) { $0.id }
        for p in b.projects {
            guard projects[p.id] == nil else { summary.skipped += 1; continue }
            let project = CreativeProject(name: p.name, summary: p.summary, category: p.category, status: ProjectStatus(rawValue: p.status) ?? .idea)
            project.id = p.id; project.coverFileName = p.coverFileName; project.notes = p.notes
            project.createdAt = p.createdAt; project.modifiedAt = p.modifiedAt; project.completedAt = p.completedAt
            restoreMedia(p.coverFileName)
            context.insert(project); projects[p.id] = project
            for m in p.milestones {
                let ms = ProjectMilestone(title: m.title, dueDate: m.dueDate, sortOrder: m.sortOrder)
                ms.id = m.id; ms.isDone = m.isDone; ms.completedAt = m.completedAt; ms.createdAt = m.createdAt
                context.insert(ms); ms.project = project
            }
            for u in p.updates {
                let up = ProjectUpdate(text: u.text, symbol: u.symbol, date: u.date)
                up.id = u.id
                context.insert(up); up.project = project
            }
            attach(p.media) { $0.project = project }
            summary.created += 1
        }

        var people = existingIDs(Person.self) { $0.id }
        for p in b.people {
            guard people[p.id] == nil else { summary.skipped += 1; continue }
            let person = Person(name: p.name, relationship: p.relationship)
            person.id = p.id; person.photoFileName = p.photoFileName; person.birthday = p.birthday
            person.birthdayReminder = p.birthdayReminder; person.notes = p.notes; person.createdAt = p.createdAt
            restoreMedia(p.photoFileName)
            context.insert(person); people[p.id] = person
            for d in p.dates {
                let date = ImportantDate(title: d.title, date: d.date, kind: ImportantDateKind(rawValue: d.kind) ?? .other, repeatsYearly: d.repeatsYearly)
                date.id = d.id; date.remind = d.remind; date.notes = d.notes
                context.insert(date); date.person = person
            }
            attach(p.media) { $0.person = person }
            summary.created += 1
        }

        var entries = existingIDs(JournalEntry.self) { $0.id }
        for e in b.entries {
            let s = e.snapshot
            guard entries[s.id] == nil else { summary.skipped += 1; continue }
            let entry = JournalEntry(title: s.title, body: s.body, date: s.date)
            entry.id = s.id; entry.reflection = s.reflection; entry.createdAt = s.createdAt; entry.modifiedAt = s.modifiedAt
            entry.moodRaw = s.mood; entry.tags = s.tags; entry.locationName = s.locationName; entry.latitude = s.latitude; entry.longitude = s.longitude
            entry.isFavorite = s.isFavorite; entry.isImportant = s.isImportant
            context.insert(entry); entries[s.id] = entry
            entry.category = e.categoryID.flatMap { categories[$0] }
            entry.trip = e.tripID.flatMap { trips[$0] }
            entry.project = e.projectID.flatMap { projects[$0] }
            entry.people = e.personIDs.compactMap { people[$0] }
            attach(e.media) { $0.entry = entry }
            BackupManager.shared?.entryChanged(entry)
            summary.created += 1
        }

        let memories = existingIDs(Memory.self) { $0.id }
        for m in b.memories {
            guard memories[m.id] == nil else { summary.skipped += 1; continue }
            let memory = Memory(title: m.title, text: m.text, kind: MemoryKind(rawValue: m.kind) ?? .text, date: m.date)
            memory.id = m.id; memory.tags = m.tags; memory.isFavorite = m.isFavorite; memory.collection = m.collection
            memory.locationName = m.locationName; memory.latitude = m.latitude; memory.longitude = m.longitude
            memory.createdAt = m.createdAt; memory.modifiedAt = m.modifiedAt
            context.insert(memory)
            memory.journalEntries = m.entryIDs.compactMap { entries[$0] }
            memory.trip = m.tripID.flatMap { trips[$0] }
            memory.project = m.projectID.flatMap { projects[$0] }
            memory.people = m.personIDs.compactMap { people[$0] }
            attach(m.media) { $0.memory = memory }
            summary.created += 1
        }

        let goals = existingIDs(LearningGoal.self) { $0.id }
        for g in b.goals {
            guard goals[g.id] == nil else { summary.skipped += 1; continue }
            let goal = LearningGoal(skillName: g.skillName, category: LearningCategory(rawValue: g.category) ?? .other)
            goal.id = g.id; goal.summary = g.summary; goal.startDate = g.startDate; goal.targetDate = g.targetDate; goal.progress = g.progress
            goal.notes = g.notes; goal.resources = g.resources; goal.isCompleted = g.isCompleted; goal.completedAt = g.completedAt
            goal.reminderEnabled = g.reminderEnabled; goal.createdAt = g.createdAt
            context.insert(goal)
            for s in g.sessions {
                let session = StudySession(subject: s.subject, date: s.date, durationMinutes: s.durationMinutes)
                session.id = s.id; session.notes = s.notes; session.learned = s.learned; session.nextSteps = s.nextSteps
                context.insert(session); session.goal = goal
            }
            summary.created += 1
        }

        let workouts = existingIDs(Workout.self) { $0.id }
        let exercises = existingIDs(Exercise.self) { $0.id }
        func makeExercise(_ d: ExerciseDTO) -> Exercise {
            let e = Exercise(name: d.name, sets: d.sets, reps: d.reps, durationSeconds: d.durationSeconds)
            e.id = d.id; e.notes = d.notes; e.sortOrder = d.sortOrder; e.isLibraryItem = d.isLibraryItem; e.focusArea = d.focusArea; e.date = d.date
            context.insert(e)
            return e
        }
        for w in b.workouts {
            guard workouts[w.id] == nil else { summary.skipped += 1; continue }
            let workout = Workout(name: w.name, date: w.date, isTemplate: w.isTemplate)
            workout.id = w.id; workout.durationMinutes = w.durationMinutes; workout.notes = w.notes; workout.isCompleted = w.isCompleted
            workout.scheduledWeekdays = w.scheduledWeekdays; workout.reminderEnabled = w.reminderEnabled; workout.createdAt = w.createdAt
            context.insert(workout)
            for x in w.exercises where exercises[x.id] == nil { makeExercise(x).workout = workout }
            summary.created += 1
        }
        for x in b.exerciseLibrary where exercises[x.id] == nil { _ = makeExercise(x); summary.created += 1 }

        let logs = existingIDs(WellbeingLog.self) { $0.id }
        for l in b.wellbeing where logs[l.id] == nil {
            let log = WellbeingLog(kind: WellbeingKind(rawValue: l.kind) ?? .sleep, value: l.value, date: l.date)
            log.id = l.id; log.quality = l.quality; log.notes = l.notes
            context.insert(log); summary.created += 1
        }
        let routines = existingIDs(Routine.self) { $0.id }
        for r in b.routines where routines[r.id] == nil {
            let routine = Routine(name: r.name, steps: r.steps, timeOfDay: r.timeOfDay)
            routine.id = r.id; routine.isActive = r.isActive; routine.lastCompleted = r.lastCompleted; routine.createdAt = r.createdAt
            context.insert(routine); summary.created += 1
        }
        let tasks = existingIDs(TaskItem.self) { $0.id }
        for t in b.tasks where tasks[t.id] == nil {
            let task = TaskItem(title: t.title, dueDate: t.dueDate)
            task.id = t.id; task.notes = t.notes; task.hasDueTime = t.hasDueTime; task.isDone = t.isDone; task.completedAt = t.completedAt
            task.priorityRaw = t.priority; task.reminderEnabled = t.reminderEnabled; task.createdAt = t.createdAt
            context.insert(task); summary.created += 1
        }
        let reminders = existingIDs(Reminder.self) { $0.id }
        for r in b.reminders where reminders[r.id] == nil {
            let reminder = Reminder(title: r.title, fireDate: r.fireDate, repeats: ReminderRepeat(rawValue: r.repeats) ?? .none, kind: ReminderKind(rawValue: r.kind) ?? .general)
            reminder.id = r.id; reminder.message = r.message; reminder.isEnabled = r.isEnabled; reminder.createdAt = r.createdAt
            context.insert(reminder); summary.created += 1
        }
        let events = existingIDs(LifeEvent.self) { $0.id }
        for e in b.events where events[e.id] == nil {
            let event = LifeEvent(title: e.title, date: e.date, kind: LifeEventKind(rawValue: e.kind) ?? .other)
            event.id = e.id; event.notes = e.notes; event.reminderEnabled = e.reminderEnabled; event.createdAt = e.createdAt
            context.insert(event); summary.created += 1
        }

        if let p = b.profile, let current = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first, current.displayName.isEmpty {
            current.displayName = p.displayName; current.bio = p.bio; current.memberSince = p.memberSince
            if !p.avatarFileName.isEmpty { restoreMedia(p.avatarFileName); current.avatarFileName = p.avatarFileName }
        }

        try? context.save()
        return summary
    }

    // MARK: Deletion

    /// Deletes all app data on this device. External backup folders are not touched.
    @MainActor
    static func deleteEverything(context: ModelContext, includeLocalBackups: Bool) throws {
        try context.delete(model: JournalAttachment.self)
        try context.delete(model: JournalEntry.self)
        try context.delete(model: JournalCategory.self)
        try context.delete(model: Memory.self)
        try context.delete(model: TravelDestination.self)
        try context.delete(model: TravelTrip.self)
        try context.delete(model: ProjectMilestone.self)
        try context.delete(model: ProjectUpdate.self)
        try context.delete(model: CreativeProject.self)
        try context.delete(model: StudySession.self)
        try context.delete(model: LearningGoal.self)
        try context.delete(model: ImportantDate.self)
        try context.delete(model: Person.self)
        try context.delete(model: Exercise.self)
        try context.delete(model: Workout.self)
        try context.delete(model: WellbeingLog.self)
        try context.delete(model: Routine.self)
        try context.delete(model: TaskItem.self)
        try context.delete(model: Reminder.self)
        try context.delete(model: LifeEvent.self)
        try context.delete(model: BackupRecord.self)
        try context.delete(model: UserSettings.self)
        try context.save()
        MediaStore.shared.deleteAll()
        RecentsStore.shared.clear()
        if includeLocalBackups {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("TXAWPAY")
            try? FileManager.default.removeItem(at: docs)
        }
        UserDefaults.standard.set(false, forKey: AppSettings.Keys.demoModeActive)
        PersistenceController.seedEssentials(in: context)
    }
}
