import SwiftUI

/// Phase 2 placeholder: replaced by the simulated desktop in Phase 3.
struct DesktopRootView: View {
    @EnvironmentObject var session: GameSession
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.1, green: 0.16, blue: 0.32), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            Button("Stand up") { session.leaveDesktop() }
                .padding()
                .background(.black.opacity(0.5), in: Capsule())
                .foregroundStyle(.white)
        }
    }
}
