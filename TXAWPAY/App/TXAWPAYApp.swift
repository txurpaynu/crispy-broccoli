import SwiftUI
import SwiftData

@main
struct TXAWPAYApp: App {
    private let container: ModelContainer
    private let containerWarning: String?
    private let cloudKitActive: Bool

    @StateObject private var router = AppRouter()
    @StateObject private var lock = AppLock()
    @StateObject private var backup: BackupManager
    @AppStorage(AppSettings.Keys.appearance) private var appearance = AppearanceMode.system.rawValue
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppSettings.registerDefaults()
        let result = PersistenceController.makeContainer()
        container = result.container
        containerWarning = result.warning
        cloudKitActive = result.cloudKitActive
        _backup = StateObject(wrappedValue: BackupManager(container: result.container))
        Appearance.configureUIKitAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView(containerWarning: containerWarning, cloudKitActive: cloudKitActive)
                .environmentObject(router)
                .environmentObject(lock)
                .environmentObject(backup)
                .environmentObject(RecentsStore.shared)
                .preferredColorScheme(AppearanceMode(rawValue: appearance)?.colorScheme)
                .tint(Theme.accent)
                .task {
                    PersistenceController.seedEssentials(in: container.mainContext)
                    // Launch-time backup pass: picks up anything that was still
                    // pending when the app last closed and re-checks iCloud uploads.
                    await backup.launchCheck()
                    await NotificationService.shared.refreshAll(context: container.mainContext)
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                lock.didEnterBackground()
                // Flush any debounced journal writes before the app is suspended.
                backup.flushForBackground()
            case .active:
                lock.didBecomeActive()
                Task { await backup.resumeAfterForeground() }
            default:
                break
            }
        }
    }
}

enum Appearance {
    /// Gives navigation bars the serif title treatment and transparent backgrounds.
    static func configureUIKitAppearance() {
        let titleColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xF1E5D2) : UIColor(hex: 0x123F48) }
        let serifLarge = UIFont.preferredFont(forTextStyle: .largeTitle).withSerifDesign(weight: .semibold)
        let serifInline = UIFont.preferredFont(forTextStyle: .headline).withSerifDesign(weight: .semibold)

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.largeTitleTextAttributes = [.foregroundColor: titleColor, .font: serifLarge]
        nav.titleTextAttributes = [.foregroundColor: titleColor, .font: serifInline]
        UINavigationBar.appearance().standardAppearance = {
            let a = UINavigationBarAppearance()
            a.configureWithDefaultBackground()
            a.largeTitleTextAttributes = nav.largeTitleTextAttributes
            a.titleTextAttributes = nav.titleTextAttributes
            return a
        }()
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }
}

extension UIFont {
    func withSerifDesign(weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: pointSize, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
