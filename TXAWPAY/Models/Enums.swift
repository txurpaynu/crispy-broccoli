import SwiftUI

// Enums are persisted as raw strings on the models (`moodRaw`, `statusRaw`…)
// so the stored schema stays stable and CloudKit-compatible even if cases are
// renamed in code later.

enum Mood: String, CaseIterable, Identifiable, Codable {
    case radiant, happy, calm, neutral, tired, low, anxious, grateful, inspired

    var id: String { rawValue }

    var label: String {
        switch self {
        case .radiant: "Radiant"
        case .happy: "Happy"
        case .calm: "Calm"
        case .neutral: "Neutral"
        case .tired: "Tired"
        case .low: "Low"
        case .anxious: "Anxious"
        case .grateful: "Grateful"
        case .inspired: "Inspired"
        }
    }

    var symbol: String {
        switch self {
        case .radiant: "sun.max.fill"
        case .happy: "face.smiling"
        case .calm: "water.waves"
        case .neutral: "circle.dashed"
        case .tired: "moon.zzz"
        case .low: "cloud.drizzle"
        case .anxious: "wind"
        case .grateful: "heart"
        case .inspired: "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .radiant, .inspired: Theme.gold
        case .happy, .grateful: Theme.jungle
        case .calm: Theme.accent
        case .neutral: Theme.textSecondary
        case .tired, .low: Color(hex: 0x6F6A9A)
        case .anxious: Theme.earth
        }
    }

    /// Accepts labels or raw values when parsing restored Markdown.
    static func parse(_ text: String) -> Mood? {
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
        return Mood.allCases.first { $0.rawValue == t || $0.label.lowercased() == t }
    }
}

enum AttachmentKind: String, CaseIterable, Codable {
    case photo, video, file
    var symbol: String {
        switch self {
        case .photo: "photo"
        case .video: "video"
        case .file: "doc"
        }
    }
}

/// Role of an attachment inside a creative project.
enum AttachmentRole: String, Codable {
    case general, inspiration, file, cover
}

enum MemoryKind: String, CaseIterable, Identifiable, Codable {
    case photo, video, text, place, date, reflection, thought
    var id: String { rawValue }
    var label: String {
        switch self {
        case .photo: "Photo"
        case .video: "Video"
        case .text: "Note"
        case .place: "Place"
        case .date: "Important date"
        case .reflection: "Reflection"
        case .thought: "Thought"
        }
    }
    var symbol: String {
        switch self {
        case .photo: "photo.on.rectangle"
        case .video: "play.rectangle"
        case .text: "text.quote"
        case .place: "mappin.and.ellipse"
        case .date: "calendar"
        case .reflection: "leaf"
        case .thought: "bubble.left"
        }
    }
}

enum TripStatus: String, CaseIterable, Identifiable, Codable {
    case dreaming, planned, ongoing, completed
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dreaming: "Dreaming"
        case .planned: "Planned"
        case .ongoing: "On the road"
        case .completed: "Completed"
        }
    }
    var symbol: String {
        switch self {
        case .dreaming: "sparkles"
        case .planned: "calendar.badge.clock"
        case .ongoing: "airplane"
        case .completed: "checkmark.seal"
        }
    }
}

enum PlaceKind: String, CaseIterable, Identifiable, Codable {
    case country, city, place
    var id: String { rawValue }
    var label: String {
        switch self {
        case .country: "Country"
        case .city: "City"
        case .place: "Place"
        }
    }
    var symbol: String {
        switch self {
        case .country: "globe.americas"
        case .city: "building.2"
        case .place: "mappin"
        }
    }
}

enum PlaceStatus: String, CaseIterable, Identifiable, Codable {
    case visited, wishlist, saved
    var id: String { rawValue }
    var label: String {
        switch self {
        case .visited: "Visited"
        case .wishlist: "Want to visit"
        case .saved: "Saved"
        }
    }
    var tint: Color {
        switch self {
        case .visited: Theme.accent
        case .wishlist: Theme.gold
        case .saved: Theme.jungle
        }
    }
}

enum ProjectStatus: String, CaseIterable, Identifiable, Codable {
    case idea, planning, inProgress, onHold, completed, archived
    var id: String { rawValue }
    var label: String {
        switch self {
        case .idea: "Idea"
        case .planning: "Planning"
        case .inProgress: "In Progress"
        case .onHold: "On Hold"
        case .completed: "Completed"
        case .archived: "Archived"
        }
    }
    var symbol: String {
        switch self {
        case .idea: "lightbulb"
        case .planning: "map"
        case .inProgress: "hammer"
        case .onHold: "pause.circle"
        case .completed: "checkmark.seal"
        case .archived: "archivebox"
        }
    }
    var tint: Color {
        switch self {
        case .idea: Theme.gold
        case .planning: Color(hex: 0x6F6A9A)
        case .inProgress: Theme.accent
        case .onHold: Theme.earth
        case .completed: Theme.jungle
        case .archived: Theme.textTertiary
        }
    }
}

enum LearningCategory: String, CaseIterable, Identifiable, Codable {
    case languages, programming, artDesign, history, technology, music, science, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .languages: "Languages"
        case .programming: "Programming"
        case .artDesign: "Art and Design"
        case .history: "History"
        case .technology: "Technology"
        case .music: "Music"
        case .science: "Science"
        case .other: "Other"
        }
    }
    var symbol: String {
        switch self {
        case .languages: "character.bubble"
        case .programming: "chevron.left.forwardslash.chevron.right"
        case .artDesign: "paintpalette"
        case .history: "building.columns"
        case .technology: "cpu"
        case .music: "music.note"
        case .science: "atom"
        case .other: "book"
        }
    }
}

enum ImportantDateKind: String, CaseIterable, Identifiable, Codable {
    case birthday, anniversary, event, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .birthday: "Birthday"
        case .anniversary: "Anniversary"
        case .event: "Event"
        case .other: "Other"
        }
    }
    var symbol: String {
        switch self {
        case .birthday: "gift"
        case .anniversary: "heart.circle"
        case .event: "star"
        case .other: "calendar"
        }
    }
}

enum WellbeingKind: String, CaseIterable, Identifiable, Codable {
    case sleep, hydration, recovery, activity
    var id: String { rawValue }
    var label: String {
        switch self {
        case .sleep: "Sleep"
        case .hydration: "Hydration"
        case .recovery: "Recovery"
        case .activity: "Activity"
        }
    }
    var symbol: String {
        switch self {
        case .sleep: "bed.double"
        case .hydration: "drop"
        case .recovery: "leaf"
        case .activity: "figure.walk"
        }
    }
    /// Unit shown next to the numeric value, if any.
    var unit: String {
        switch self {
        case .sleep: "h"
        case .hydration: "glasses"
        case .recovery: ""
        case .activity: "min"
        }
    }
}

enum LifeEventKind: String, CaseIterable, Identifiable, Codable {
    case milestone, event, celebration, change, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .milestone: "Milestone"
        case .event: "Event"
        case .celebration: "Celebration"
        case .change: "Life change"
        case .other: "Other"
        }
    }
    var symbol: String {
        switch self {
        case .milestone: "flag"
        case .event: "calendar"
        case .celebration: "party.popper"
        case .change: "arrow.triangle.branch"
        case .other: "circle"
        }
    }
}

enum ReminderKind: String, CaseIterable, Identifiable, Codable {
    case general, task, event, birthday, journal, learning, workout, hydration, importantDate
    var id: String { rawValue }
}

enum ReminderRepeat: String, CaseIterable, Identifiable, Codable {
    case none, daily, weekly, yearly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: "Once"
        case .daily: "Every day"
        case .weekly: "Every week"
        case .yearly: "Every year"
        }
    }
}

enum TaskPriority: Int, CaseIterable, Identifiable, Codable {
    case low = 0, normal = 1, high = 2
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        }
    }
}

/// State of a single day's backup file.
enum BackupState: String, Codable {
    case pending          // changed in the app, not yet written
    case savedLocally     // written to the on-device folder only
    case waitingForICloud // written into iCloud Drive, upload not yet confirmed
    case completed        // written and (for iCloud) confirmed uploaded
    case failed

    var label: String {
        switch self {
        case .pending: "Pending"
        case .savedLocally: "Saved locally"
        case .waitingForICloud: "Waiting for iCloud synchronization"
        case .completed: "Backup completed"
        case .failed: "Backup failed"
        }
    }

    var symbol: String {
        switch self {
        case .pending: "clock"
        case .savedLocally: "iphone"
        case .waitingForICloud: "icloud.and.arrow.up"
        case .completed: "checkmark.icloud"
        case .failed: "exclamationmark.triangle"
        }
    }
}
