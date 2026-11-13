import SwiftUI

/// The final cinematic. Filled in by the ending phase.
struct EndingView: View {
    @EnvironmentObject var session: GameSession
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Button("Return to title") { session.quitToTitle() }
        }
    }
}
