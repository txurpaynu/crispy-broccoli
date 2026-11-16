import SwiftUI
import SwiftData

struct RootView: View {
    let containerWarning: String?
    let cloudKitActive: Bool

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var lock: AppLock
    @EnvironmentObject private var backup: BackupManager
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppSettings.Keys.hasOnboarded) private var hasOnboarded = false
    @State private var shownWarning = false

    var body: some View {
        TabView(selection: tabSelection) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: router.binding(for: tab)) {
                    rootView(for: tab)
                        .appDestinations()
                }
                .tabItem { Label(tab.title, systemImage: tab.symbol) }
                .tag(tab)
            }
        }
        .sheet(item: $router.quickCapture) { kind in
            QuickCaptureView(initialKind: kind)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $router.newJournalEntry) {
            NavigationStack { JournalEditorView(entry: nil) }
        }
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { if !$0 { hasOnboarded = true } })) {
            OnboardingView()
        }
        .toast($router.toast)
        .overlay {
            // Privacy cover hides content in the app switcher; lock screen when locked.
            if lock.isLocked {
                LockView()
                    .transition(.opacity)
            } else if scenePhase != .active && lock.isEnabled {
                PrivacyCover()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: lock.isLocked)
        .onAppear {
            if let containerWarning, !shownWarning {
                shownWarning = true
                router.showToast(containerWarning, symbol: "exclamationmark.icloud", isError: true)
            }
        }
        .environment(\.cloudKitActive, cloudKitActive)
    }

    /// Tapping the selected tab again pops it to its root, like native apps.
    private var tabSelection: Binding<AppTab> {
        Binding(get: { router.selectedTab }, set: { newTab in
            if newTab == router.selectedTab { router.popToRoot(newTab) }
            router.selectedTab = newTab
        })
    }

    @ViewBuilder
    private func rootView(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView()
        case .explore: ExploreView()
        case .create: CreateView()
        case .journal: JournalView()
        case .profile: ProfileView()
        }
    }
}

private struct CloudKitActiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var cloudKitActive: Bool {
        get { self[CloudKitActiveKey.self] }
        set { self[CloudKitActiveKey.self] = newValue }
    }
}

/// Registers every navigable destination once per stack, so `NavigationLink(value:)`
/// works from anywhere (Home, search, timeline…).
struct AppDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: AppModule.self) { module in
                ModuleView(module: module)
            }
            .navigationDestination(for: JournalEntry.self) { JournalEntryDetailView(entry: $0) }
            .navigationDestination(for: NewEntryRoute.self) { JournalEditorView(entry: nil, initialDate: $0.date) }
            .navigationDestination(for: EditEntryRoute.self) { JournalEditorView(entry: $0.entry) }
            .navigationDestination(for: PromptEntryRoute.self) { JournalEditorView(entry: nil, initialTitle: $0.prompt) }
            .navigationDestination(for: TripEntryRoute.self) { JournalEditorView(entry: nil, trip: $0.trip) }
            .navigationDestination(for: ProjectEntryRoute.self) { JournalEditorView(entry: nil, project: $0.project) }
            .navigationDestination(for: NewPersonRoute.self) { _ in PersonEditor(person: nil) }
            .navigationDestination(for: StudySessionRoute.self) { StudySessionEditor(goalID: $0.goalID, session: nil) }
            .navigationDestination(for: TravelTrip.self) { TripDetailView(trip: $0) }
            .navigationDestination(for: TravelDestination.self) { PlaceDetailView(place: $0) }
            .navigationDestination(for: CreativeProject.self) { ProjectDetailView(project: $0) }
            .navigationDestination(for: LearningGoal.self) { LearningGoalDetailView(goal: $0) }
            .navigationDestination(for: Person.self) { PersonDetailView(person: $0) }
            .navigationDestination(for: Memory.self) { MemoryDetailView(memory: $0) }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .navigationDestination(for: JournalCategory.self) { JournalCategoryEntriesView(category: $0) }
            .navigationDestination(for: YearbookRoute.self) { YearbookView(year: $0.year) }
    }
}

extension View {
    func appDestinations() -> some View { modifier(AppDestinations()) }
}

struct YearbookRoute: Hashable { let year: Int }

/// Maps secondary modules to their screens.
struct ModuleView: View {
    let module: AppModule

    var body: some View {
        switch module {
        case .learn: LearnView()
        case .people: PeopleView()
        case .vitality: VitalityView()
        case .timeline: LifeTimelineView()
        case .memoryVault: MemoryVaultView()
        case .yearbook: YearbookPickerView()
        case .search: GlobalSearchView()
        case .tasks: TasksView()
        case .events: EventsView()
        case .backup: BackupSettingsView()
        case .restore: RestoreJournalView()
        case .journalCategories: JournalCategoriesView()
        case .onThisDay: OnThisDayView()
        case .settingsAppearance: AppearanceSettingsView()
        case .settingsNotifications: NotificationSettingsView()
        case .settingsPrivacy: PrivacySettingsView()
        case .storage: StorageView()
        case .exportData: ExportDataView()
        case .about: AboutView()
        }
    }
}
