import SwiftUI

@main
struct SecondsClockApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            VStack(spacing: 12) {
                Text(ctx.date, format: .dateTime.hour().minute().second())
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(ctx.date, format: .dateTime.weekday(.wide).month().day())
                    .font(.title3).foregroundStyle(.secondary)
                Text(TimeZone.current.identifier)
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Long-press your Home Screen or Lock Screen → Edit → add the “Seconds Clock” widget.")
                    .font(.footnote).multilineTextAlignment(.center)
                    .foregroundStyle(.secondary).padding(.top, 40).padding(.horizontal)
            }
        }
    }
}
