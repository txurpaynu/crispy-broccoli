import SwiftUI

/// Chapter 6–8 level. Filled in by the facility phase.
struct FacilityView: View {
    @EnvironmentObject var session: GameSession
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("The facility").foregroundStyle(.white.opacity(0.4))
        }
        .onTapGesture { session.screen = .apartment }
    }
}
