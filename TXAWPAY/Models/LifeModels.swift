import Foundation
import SwiftData

// MARK: - Memory Vault

@Model
final class Memory {
    var id: UUID = UUID()
    var title: String = ""
    var text: String = ""
    var date: Date = Date()
    var kindRaw: String = MemoryKind.text.rawValue
    var tags: [String] = []
    var isFavorite: Bool = false
    /// Collection name (free text so the user can create collections on the fly).
    var collection: String = ""
    var locationName: String = ""
    var latitude: Double? = nil
    var longitude: Double? = nil
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var isDemo: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \JournalAttachment.memory)
    var attachments: [JournalAttachment]? = []

    var journalEntries: [JournalEntry]? = []
    var trip: TravelTrip? = nil
    var project: CreativeProject? = nil
    var people: [Person]? = []

    init(title: String = "", text: String = "", kind: MemoryKind = .text, date: Date = Date()) {
        self.title = title
        self.text = text
        self.kindRaw = kind.rawValue
        self.date = date
    }

    var kind: MemoryKind {
        get { MemoryKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? kind.label : String(s.prefix(60))
    }

    var sortedAttachments: [JournalAttachment] {
        (attachments ?? []).sorted { $0.createdAt < $1.createdAt }
    }
}

// MARK: - Explore

@Model
final class TravelTrip {
    var id: UUID = UUID()
    var title: String = ""
    var destination: String = ""
    var countryCode: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var hasDates: Bool = true
    var statusRaw: String = TripStatus.planned.rawValue
    var itinerary: String = ""
    var notes: String = ""
    var memoriesText: String = ""
    var coverFileName: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var isDemo: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \TravelDestination.trip)
    var places: [TravelDestination]? = []

    @Relationship(deleteRule: .cascade, inverse: \JournalAttachment.trip)
    var attachments: [JournalAttachment]? = []

    @Relationship(inverse: \JournalEntry.trip)
    var journalEntries: [JournalEntry]? = []

    @Relationship(inverse: \Memory.trip)
    var memories: [Memory]? = []

    init(title: String, destination: String = "", startDate: Date = Date(), endDate: Date = Date(), status: TripStatus = .planned) {
        self.title = title
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.statusRaw = status.rawValue
    }

    var status: TripStatus {
        get { TripStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    var sortedPlaces: [TravelDestination] {
        (places ?? []).sorted { ($0.visitedDate ?? .distantFuture) < ($1.visitedDate ?? .distantFuture) }
    }

    var isUpcoming: Bool { hasDates && startDate > Date() && status != .completed }
}

/// A country, city or specific place — visited, wished for, or simply saved.
@Model
final class TravelDestination {
    var id: UUID = UUID()
    var name: String = ""
    var city: String = ""
    var country: String = ""
    /// ISO 3166-1 alpha-2 country code, used for flags and statistics.
    var countryCode: String = ""
    var kindRaw: String = PlaceKind.place.rawValue
    var statusRaw: String = PlaceStatus.saved.rawValue
    var latitude: Double? = nil
    var longitude: Double? = nil
    var notes: String = ""
    var visitedDate: Date? = nil
    var createdAt: Date = Date()
    var isDemo: Bool = false

    var trip: TravelTrip? = nil

    @Relationship(deleteRule: .cascade, inverse: \JournalAttachment.place)
    var attachments: [JournalAttachment]? = []

    init(name: String, kind: PlaceKind = .place, status: PlaceStatus = .saved) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.statusRaw = status.rawValue
    }

    var kind: PlaceKind {
        get { PlaceKind(rawValue: kindRaw) ?? .place }
        set { kindRaw = newValue.rawValue }
    }

    var status: PlaceStatus {
        get { PlaceStatus(rawValue: statusRaw) ?? .saved }
        set { statusRaw = newValue.rawValue }
    }

    var hasCoordinate: Bool { latitude != nil && longitude != nil }
}

// MARK: - Create

@Model
final class CreativeProject {
    var id: UUID = UUID()
    var name: String = ""
    var summary: String = ""
    var category: String = "Personal Projects"
    var statusRaw: String = ProjectStatus.idea.rawValue
    var coverFileName: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var completedAt: Date? = nil
    var isDemo: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \ProjectMilestone.project)
    var milestones: [ProjectMilestone]? = []

    @Relationship(deleteRule: .cascade, inverse: \JournalAttachment.project)
    var attachments: [JournalAttachment]? = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectUpdate.project)
    var updates: [ProjectUpdate]? = []

    @Relationship(inverse: \JournalEntry.project)
    var journalEntries: [JournalEntry]? = []

    @Relationship(inverse: \Memory.project)
    var memories: [Memory]? = []

    init(name: String, summary: String = "", category: String = "Personal Projects", status: ProjectStatus = .idea) {
        self.name = name
        self.summary = summary
        self.category = category
        self.statusRaw = status.rawValue
    }

    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .idea }
        set { statusRaw = newValue.rawValue }
    }

    var sortedMilestones: [ProjectMilestone] {
        (milestones ?? []).sorted { $0.sortOrder == $1.sortOrder ? $0.createdAt < $1.createdAt : $0.sortOrder < $1.sortOrder }
    }

    var progress: Double {
        let all = milestones ?? []
        guard !all.isEmpty else { return status == .completed ? 1 : 0 }
        return Double(all.filter(\.isDone).count) / Double(all.count)
    }

    static let builtInCategories = ["Game Development", "Character Design", "Worldbuilding", "Writing", "Art", "Personal Projects", "Other"]
}

@Model
final class ProjectMilestone {
    var id: UUID = UUID()
    var title: String = ""
    var dueDate: Date? = nil
    var isDone: Bool = false
    var completedAt: Date? = nil
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    var project: CreativeProject? = nil

    init(title: String, dueDate: Date? = nil, sortOrder: Int = 0) {
        self.title = title
        self.dueDate = dueDate
        self.sortOrder = sortOrder
    }
}

/// One entry in a project's progress history (status changes, notes, milestone completions).
@Model
final class ProjectUpdate {
    var id: UUID = UUID()
    var date: Date = Date()
    var text: String = ""
    var symbol: String = "circle"
    var project: CreativeProject? = nil

    init(text: String, symbol: String = "circle", date: Date = Date()) {
        self.text = text
        self.symbol = symbol
        self.date = date
    }
}

// MARK: - Learn

@Model
final class LearningGoal {
    var id: UUID = UUID()
    var skillName: String = ""
    var summary: String = ""
    var categoryRaw: String = LearningCategory.other.rawValue
    var startDate: Date = Date()
    var targetDate: Date? = nil
    /// 0…1, set manually by the user.
    var progress: Double = 0
    var notes: String = ""
    var resources: String = ""
    var isCompleted: Bool = false
    var completedAt: Date? = nil
    var reminderEnabled: Bool = false
    var createdAt: Date = Date()
    var isDemo: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \StudySession.goal)
    var sessions: [StudySession]? = []

    init(skillName: String, category: LearningCategory = .other) {
        self.skillName = skillName
        self.categoryRaw = category.rawValue
    }

    var category: LearningCategory {
        get { LearningCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var sortedSessions: [StudySession] {
        (sessions ?? []).sorted { $0.date > $1.date }
    }

    var totalMinutes: Int { (sessions ?? []).reduce(0) { $0 + $1.durationMinutes } }
}

@Model
final class StudySession {
    var id: UUID = UUID()
    var subject: String = ""
    var date: Date = Date()
    var durationMinutes: Int = 30
    var notes: String = ""
    var learned: String = ""
    var nextSteps: String = ""
    var isDemo: Bool = false

    var goal: LearningGoal? = nil

    init(subject: String, date: Date = Date(), durationMinutes: Int = 30) {
        self.subject = subject
        self.date = date
        self.durationMinutes = durationMinutes
    }
}

// MARK: - People

@Model
final class Person {
    var id: UUID = UUID()
    var name: String = ""
    var photoFileName: String = ""
    var birthday: Date? = nil
    var birthdayReminder: Bool = false
    var relationship: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var isDemo: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \ImportantDate.person)
    var importantDates: [ImportantDate]? = []

    @Relationship(deleteRule: .cascade, inverse: \JournalAttachment.person)
    var attachments: [JournalAttachment]? = []

    var journalEntries: [JournalEntry]? = []

    @Relationship(inverse: \Memory.people)
    var memories: [Memory]? = []

    init(name: String, relationship: String = "") {
        self.name = name
        self.relationship = relationship
    }

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let s = parts.compactMap { $0.first }.map(String.init).joined()
        return s.isEmpty ? "?" : s.uppercased()
    }

    static let relationshipSuggestions = ["Family", "Friend", "Partner", "Colleague", "Mentor", "Neighbour", "Other"]
}

@Model
final class ImportantDate {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date()
    var kindRaw: String = ImportantDateKind.event.rawValue
    var repeatsYearly: Bool = true
    var remind: Bool = false
    var notes: String = ""
    var isDemo: Bool = false

    var person: Person? = nil

    init(title: String, date: Date, kind: ImportantDateKind = .event, repeatsYearly: Bool = true) {
        self.title = title
        self.date = date
        self.kindRaw = kind.rawValue
        self.repeatsYearly = repeatsYearly
    }

    var kind: ImportantDateKind {
        get { ImportantDateKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    /// The next occurrence on or after today (or the date itself if not repeating).
    var nextOccurrence: Date? {
        DateMath.nextOccurrence(of: date, repeatsYearly: repeatsYearly)
    }
}

// MARK: - Vitality

@Model
final class Workout {
    var id: UUID = UUID()
    var name: String = ""
    var date: Date = Date()
    var durationMinutes: Int = 0
    var notes: String = ""
    var isCompleted: Bool = false
    /// Templates appear in the schedule/library and can be logged repeatedly.
    var isTemplate: Bool = false
    /// Weekday numbers (1 = Sunday … 7 = Saturday) for a scheduled template.
    var scheduledWeekdays: [Int] = []
    var reminderEnabled: Bool = false
    var createdAt: Date = Date()
    var isDemo: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    var exercises: [Exercise]? = []

    init(name: String, date: Date = Date(), isTemplate: Bool = false) {
        self.name = name
        self.date = date
        self.isTemplate = isTemplate
    }

    var sortedExercises: [Exercise] {
        (exercises ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }
}

/// An exercise performed inside a workout, or — when `workout` is nil and
/// `isLibraryItem` is true — an entry in the user's exercise library.
@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var sets: Int = 0
    var reps: Int = 0
    var durationSeconds: Int = 0
    var notes: String = ""
    var sortOrder: Int = 0
    var isLibraryItem: Bool = false
    var focusArea: String = ""
    var date: Date = Date()

    var workout: Workout? = nil

    init(name: String, sets: Int = 0, reps: Int = 0, durationSeconds: Int = 0) {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.durationSeconds = durationSeconds
    }

    var summaryLine: String {
        var parts: [String] = []
        if sets > 0 && reps > 0 { parts.append("\(sets) × \(reps)") }
        else if sets > 0 { parts.append("\(sets) sets") }
        else if reps > 0 { parts.append("\(reps) reps") }
        if durationSeconds > 0 { parts.append(DateMath.durationText(seconds: durationSeconds)) }
        return parts.joined(separator: " · ")
    }
}

/// Sleep, hydration, recovery and activity notes.
@Model
final class WellbeingLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var kindRaw: String = WellbeingKind.sleep.rawValue
    var value: Double = 0
    var quality: Int = 0 // 0 = not set, 1…5
    var notes: String = ""
    var isDemo: Bool = false

    init(kind: WellbeingKind, value: Double = 0, date: Date = Date()) {
        self.kindRaw = kind.rawValue
        self.value = value
        self.date = date
    }

    var kind: WellbeingKind {
        get { WellbeingKind(rawValue: kindRaw) ?? .sleep }
        set { kindRaw = newValue.rawValue }
    }
}

@Model
final class Routine {
    var id: UUID = UUID()
    var name: String = ""
    var steps: [String] = []
    var timeOfDay: String = "Morning"
    var isActive: Bool = true
    var lastCompleted: Date? = nil
    var createdAt: Date = Date()
    var isDemo: Bool = false

    init(name: String, steps: [String] = [], timeOfDay: String = "Morning") {
        self.name = name
        self.steps = steps
        self.timeOfDay = timeOfDay
    }

    var completedToday: Bool {
        guard let lastCompleted else { return false }
        return Calendar.current.isDateInToday(lastCompleted)
    }
}

// MARK: - Tasks, reminders, events

@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var dueDate: Date? = nil
    var hasDueTime: Bool = false
    var isDone: Bool = false
    var completedAt: Date? = nil
    var priorityRaw: Int = TaskPriority.normal.rawValue
    var reminderEnabled: Bool = false
    var createdAt: Date = Date()
    var isDemo: Bool = false

    init(title: String, dueDate: Date? = nil) {
        self.title = title
        self.dueDate = dueDate
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    var isDueToday: Bool {
        guard let dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    var isOverdue: Bool {
        guard let dueDate, !isDone else { return false }
        return dueDate < Calendar.current.startOfDay(for: Date())
    }
}

/// A user-defined local notification (journal nudges, hydration, custom reminders).
/// Reminders tied to a task/date/person are derived from those models instead.
@Model
final class Reminder {
    var id: UUID = UUID()
    var title: String = ""
    var message: String = ""
    var fireDate: Date = Date()
    var repeatRaw: String = ReminderRepeat.none.rawValue
    var kindRaw: String = ReminderKind.general.rawValue
    var isEnabled: Bool = true
    var createdAt: Date = Date()

    init(title: String, fireDate: Date, repeats: ReminderRepeat = .none, kind: ReminderKind = .general) {
        self.title = title
        self.fireDate = fireDate
        self.repeatRaw = repeats.rawValue
        self.kindRaw = kind.rawValue
    }

    var repeats: ReminderRepeat {
        get { ReminderRepeat(rawValue: repeatRaw) ?? .none }
        set { repeatRaw = newValue.rawValue }
    }

    var kind: ReminderKind {
        get { ReminderKind(rawValue: kindRaw) ?? .general }
        set { kindRaw = newValue.rawValue }
    }

    var nextFire: Date? {
        switch repeats {
        case .none: return fireDate >= Date() ? fireDate : nil
        case .yearly: return DateMath.nextOccurrence(of: fireDate, repeatsYearly: true)
        case .daily, .weekly:
            let cal = Calendar.current
            var next = fireDate
            let step: Calendar.Component = repeats == .daily ? .day : .weekOfYear
            while next < Date() { next = cal.date(byAdding: step, value: 1, to: next) ?? Date.distantFuture }
            return next
        }
    }
}

/// An important personal event added directly to the Life Timeline,
/// or an upcoming event shown on Home.
@Model
final class LifeEvent {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date()
    var notes: String = ""
    var kindRaw: String = LifeEventKind.event.rawValue
    var reminderEnabled: Bool = false
    var createdAt: Date = Date()
    var isDemo: Bool = false

    init(title: String, date: Date, kind: LifeEventKind = .event) {
        self.title = title
        self.date = date
        self.kindRaw = kind.rawValue
    }

    var kind: LifeEventKind {
        get { LifeEventKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }
}

// MARK: - Backup & settings

/// Tracks the backup state of one day's Markdown file ("yyyy-MM-dd").
@Model
final class BackupRecord {
    var dayKey: String = ""
    var stateRaw: String = BackupState.pending.rawValue
    var relativePath: String = ""
    var contentHash: String = ""
    var entryCount: Int = 0
    var lastAttempt: Date? = nil
    var lastSuccess: Date? = nil
    var lastError: String = ""
    var retryCount: Int = 0
    var destinationRaw: String = ""

    init(dayKey: String) {
        self.dayKey = dayKey
    }

    var state: BackupState {
        get { BackupState(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }
}

/// Profile information (synchronised with the rest of the data when CloudKit is on).
/// Device-specific preferences (appearance, app lock…) live in `AppSettings` / UserDefaults.
@Model
final class UserSettings {
    var id: UUID = UUID()
    var displayName: String = ""
    var avatarFileName: String = ""
    var bio: String = ""
    var memberSince: Date = Date()

    init() {}
}
