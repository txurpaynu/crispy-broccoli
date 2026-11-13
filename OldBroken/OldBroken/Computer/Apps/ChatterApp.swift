import SwiftUI

/// Desktop versions of the phone apps (synced in Chapter 4).
struct ChatterApp: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Synced with your phone").font(.system(size: 9)).foregroundStyle(.white.opacity(0.4)).padding(4)
            ChatterView()
        }
        .background(Color(red: 0.07, green: 0.09, blue: 0.1))
    }
}

struct LumenApp: View {
    var body: some View { LumenView() }
}
