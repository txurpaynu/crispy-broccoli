import SwiftUI

struct ContentView: View {
    @StateObject private var store = CompanionStore()
    @StateObject private var engine = ShimejiEngine()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showChat = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.01, blue: 0.10), Color(red: 0.20, green: 0.04, blue: 0.22)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                StageView(engine: engine, store: store)
                    .background(alignment: .bottom) {
                        Rectangle()
                            .fill(Color(red: 1.0, green: 0.12, blue: 0.5).opacity(0.5))
                            .frame(height: 2)
                    }
                controls
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            let companion = store
            engine.onEvent = { [weak companion] event in companion?.handle(event) }
            engine.sleepiness = store.sleepiness
        }
        .onChange(of: store.happiness) { _, _ in engine.sleepiness = store.sleepiness }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                IdleNotifications.cancel()
                engine.start()
                store.appBecameActive()
                IdleNotifications.scheduleRandomThoughts(name: store.name)
            case .background:
                engine.stop()
                store.appWentToBackground()
                IdleNotifications.schedule(name: store.name)
            default:
                break
            }
        }
        .onOpenURL { url in
            if url.host == "chat" { showChat = true }
        }
        .sheet(isPresented: $showChat) {
            ChatView(store: store)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.name)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text("\(store.mood.emoji) \(store.mood.label)")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HeartMeter(value: store.happiness)
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    showChat = true
                } label: {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 1.0, green: 0.12, blue: 0.5))

                Button {
                    store.toggleLiveActivity()
                } label: {
                    Label(store.live.isRunning ? "Hide from Lock Screen" : "Show on Lock Screen",
                          systemImage: store.live.isRunning ? "pin.slash.fill" : "pin.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color(red: 0.25, green: 0.75, blue: 0.95))
            }
            .controlSize(.large)

            if let error = store.live.lastError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

struct HeartMeter: View {
    var value: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill").foregroundStyle(.pink)
            Text("\(value)%")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.12)))
    }
}
