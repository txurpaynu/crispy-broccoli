import SwiftUI

/// Device-local preferences (UserDefaults). Profile data lives in `UserSettings`.
enum AppSettings {
    enum Keys {
        static let appearance = "appearance"
        static let appLockEnabled = "appLockEnabled"
        static let lockOnBackgroundDelay = "lockOnBackgroundDelay"
        static let inspirationEnabled = "inspirationEnabled"
        static let cloudSyncEnabled = "cloudSyncEnabled"
        static let demoModeActive = "demoModeActive"
        static let hasOnboarded = "hasOnboarded"
        static let journalReminderEnabled = "journalReminderEnabled"
        static let journalReminderTime = "journalReminderTime"
        static let hydrationRemindersEnabled = "hydrationRemindersEnabled"
        static let hydrationStartHour = "hydrationStartHour"
        static let hydrationEndHour = "hydrationEndHour"
        static let hydrationIntervalHours = "hydrationIntervalHours"
        static let notifyTasks = "notifyTasks"
        static let notifyBirthdays = "notifyBirthdays"
        static let notifyEvents = "notifyEvents"
        static let notifyLearning = "notifyLearning"
        static let notifyWorkouts = "notifyWorkouts"
        static let learningReminderTime = "learningReminderTime"
        static let backupEnabled = "backupEnabled"
        static let backupDestination = "backupDestination"
        static let backupFolderBookmark = "backupFolderBookmark"
        static let backupFolderName = "backupFolderName"
        static let backupAlsoTXT = "backupAlsoTXT"
        static let backupIncludeMedia = "backupIncludeMedia"
        static let hideInspirationUntil = "hideInspirationUntil"
        static let recentItems = "recentItems"
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Keys.appearance: AppearanceMode.system.rawValue,
            Keys.appLockEnabled: false,
            Keys.lockOnBackgroundDelay: 0,
            Keys.inspirationEnabled: true,
            Keys.cloudSyncEnabled: false,
            Keys.demoModeActive: false,
            Keys.journalReminderEnabled: false,
            Keys.journalReminderTime: 21 * 3600.0,     // seconds after midnight
            Keys.learningReminderTime: 18 * 3600.0,
            Keys.hydrationRemindersEnabled: false,
            Keys.hydrationStartHour: 9,
            Keys.hydrationEndHour: 20,
            Keys.hydrationIntervalHours: 2,
            Keys.notifyTasks: true,
            Keys.notifyBirthdays: true,
            Keys.notifyEvents: true,
            Keys.notifyLearning: true,
            Keys.notifyWorkouts: true,
            Keys.backupEnabled: true,
            Keys.backupDestination: BackupDestinationKind.onDevice.rawValue,
            Keys.backupAlsoTXT: false,
            Keys.backupIncludeMedia: true
        ])
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon.stars"
        }
    }
}

/// "Continue where you left off": a small persisted list of recently opened items.
struct RecentItem: Codable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case journal, project, trip, goal, person, memory
    }
    var kind: Kind
    var itemID: UUID
    var title: String
    var openedAt: Date
    var id: String { "\(kind.rawValue)-\(itemID)" }
}

@MainActor
final class RecentsStore: ObservableObject {
    static let shared = RecentsStore()
    @Published private(set) var items: [RecentItem] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: AppSettings.Keys.recentItems),
           let decoded = try? JSONDecoder().decode([RecentItem].self, from: data) {
            items = decoded
        }
    }

    func record(_ kind: RecentItem.Kind, id: UUID, title: String) {
        items.removeAll { $0.kind == kind && $0.itemID == id }
        items.insert(RecentItem(kind: kind, itemID: id, title: title, openedAt: Date()), at: 0)
        items = Array(items.prefix(12))
        persist()
    }

    func remove(id: UUID) {
        items.removeAll { $0.itemID == id }
        persist()
    }

    func clear() {
        items = []
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: AppSettings.Keys.recentItems)
        }
    }
}
