import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home, explore, create, journal, profile
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .explore: "Explore"
        case .create: "Create"
        case .journal: "Journal"
        case .profile: "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .explore: "globe.americas"
        case .create: "paintbrush.pointed"
        case .journal: "book.closed"
        case .profile: "person.crop.circle"
        }
    }
}

/// Secondary modules reachable from Home and section menus.
enum AppModule: String, Hashable, CaseIterable, Identifiable {
    case learn, people, vitality, timeline, memoryVault, yearbook, search, tasks, events
    case backup, restore, journalCategories, onThisDay, settingsAppearance, settingsNotifications
    case settingsPrivacy, storage, exportData, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .learn: "Learn"
        case .people: "People"
        case .vitality: "Vitality"
        case .timeline: "Life Timeline"
        case .memoryVault: "Memory Vault"
        case .yearbook: "Yearbook"
        case .search: "Search"
        case .tasks: "Tasks"
        case .events: "Events & Reminders"
        case .backup: "Journal Backup"
        case .restore: "Restore Journal"
        case .journalCategories: "Categories"
        case .onThisDay: "On This Day"
        case .settingsAppearance: "Appearance"
        case .settingsNotifications: "Notifications"
        case .settingsPrivacy: "Privacy & Security"
        case .storage: "Storage"
        case .exportData: "Export & Delete Data"
        case .about: "About TXAWPAY"
        }
    }

    var symbol: String {
        switch self {
        case .learn: "graduationcap"
        case .people: "person.2"
        case .vitality: "figure.mind.and.body"
        case .timeline: "point.3.connected.trianglepath.dotted"
        case .memoryVault: "sparkles.rectangle.stack"
        case .yearbook: "book.pages"
        case .search: "magnifyingglass"
        case .tasks: "checklist"
        case .events: "calendar.badge.clock"
        case .backup: "externaldrive.badge.icloud"
        case .restore: "arrow.counterclockwise.icloud"
        case .journalCategories: "folder"
        case .onThisDay: "clock.arrow.circlepath"
        case .settingsAppearance: "paintpalette"
        case .settingsNotifications: "bell.badge"
        case .settingsPrivacy: "faceid"
        case .storage: "internaldrive"
        case .exportData: "square.and.arrow.up.on.square"
        case .about: "info.circle"
        }
    }

    var tint: Color {
        switch self {
        case .learn: Color(hex: 0x6F6A9A)
        case .people: Theme.earth
        case .vitality: Theme.jungle
        case .timeline, .yearbook: Theme.gold
        case .memoryVault: Theme.accent
        default: Theme.accent
        }
    }
}

/// What Quick Capture should open with.
enum CaptureKind: String, CaseIterable, Identifiable {
    case thought, journal, photo, place, memory, task, projectIdea
    var id: String { rawValue }
    var label: String {
        switch self {
        case .thought: "Thought"
        case .journal: "Journal"
        case .photo: "Photo"
        case .place: "Place"
        case .memory: "Memory"
        case .task: "Task"
        case .projectIdea: "Idea"
        }
    }
    var symbol: String {
        switch self {
        case .thought: "bubble.left"
        case .journal: "book.closed"
        case .photo: "camera"
        case .place: "mappin.and.ellipse"
        case .memory: "sparkles"
        case .task: "checkmark.circle"
        case .projectIdea: "lightbulb"
        }
    }
}

/// Owns tab selection, per-tab navigation paths and app-wide sheets.
@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var paths: [AppTab: NavigationPath] = Dictionary(uniqueKeysWithValues: AppTab.allCases.map { ($0, NavigationPath()) })
    @Published var quickCapture: CaptureKind? = nil
    @Published var newJournalEntry = false
    @Published var toast: ToastMessage? = nil

    func binding(for tab: AppTab) -> Binding<NavigationPath> {
        Binding(get: { self.paths[tab] ?? NavigationPath() },
                set: { self.paths[tab] = $0 })
    }

    /// Pushes a destination onto a tab's stack, switching to that tab.
    func open<V: Hashable>(_ value: V, in tab: AppTab? = nil) {
        let target = tab ?? selectedTab
        selectedTab = target
        var path = paths[target] ?? NavigationPath()
        path.append(value)
        paths[target] = path
    }

    func popToRoot(_ tab: AppTab) {
        paths[tab] = NavigationPath()
    }

    func capture(_ kind: CaptureKind) {
        quickCapture = kind
    }

    func showToast(_ text: String, symbol: String = "checkmark.circle.fill", isError: Bool = false) {
        toast = ToastMessage(text: text, symbol: symbol, isError: isError)
    }
}
