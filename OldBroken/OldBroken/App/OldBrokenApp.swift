import SwiftUI

@main
struct OldBrokenApp: App {
    init() {
        AudioManager.shared.start()
        AudioManager.shared.setScene(.title)
        MainActor.assumeIsolated { ComputerSimulationManager.bootstrap(); RetroGameController.bootstrap() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(GameSession.shared)
                .environmentObject(GameSettings.shared)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}
