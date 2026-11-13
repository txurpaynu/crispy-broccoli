import SwiftUI

/// The simulated computer, seen full-screen as if sitting at the desk.
/// The black bezel uses the iPhone's safe-area space; the left bezel holds "Stand up".
struct DesktopRootView: View {
    @EnvironmentObject var session: GameSession
    @StateObject private var comp = ComputerSimulationManager.shared

    var body: some View {
        GeometryReader { outer in
            HStack(spacing: 0) {
                bezelLeft
                    .frame(width: max(44, outer.safeAreaInsets.leading))
                DesktopView()
                    .environmentObject(comp)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.vertical, 6)
                Color.black.frame(width: max(14, outer.safeAreaInsets.trailing))
            }
            .ignoresSafeArea()
            .background(Color.black)
        }
    }

    private var bezelLeft: some View {
        VStack {
            Button {
                AudioManager.shared.play(.uiClick)
                session.leaveDesktop()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "figure.stand").font(.system(size: 16))
                    Text("STAND\nUP").font(.system(size: 7, weight: .bold, design: .monospaced)).multilineTextAlignment(.center)
                }
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 40, height: 50)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.top, 18)
            Spacer()
            Circle().fill(Color(red: 0.3, green: 0.6, blue: 1)).frame(width: 4, height: 4).padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }
}

struct DesktopView: View {
    @EnvironmentObject var session: GameSession
    @EnvironmentObject var comp: ComputerSimulationManager

    var body: some View {
        GeometryReader { geo in
            let areaSize = CGSize(width: geo.size.width, height: geo.size.height - 34)
            ZStack(alignment: .topLeading) {
                Wallpaper(index: session.data.desktop.wallpaper)
                    .onTapGesture { comp.startOpen = false; comp.notificationCenterOpen = false }

                DesktopIcons()
                    .padding(8)

                ForEach(comp.windows) { w in
                    if !w.minimized {
                        WindowChrome(window: w, area: areaSize)
                            .zIndex(Double(comp.windows.firstIndex(of: w) ?? 0) + 10)
                    }
                }

                VStack(spacing: 0) {
                    Spacer()
                    if comp.startOpen { StartMenu().padding(.leading, 6).frame(maxWidth: .infinity, alignment: .leading) }
                    Taskbar()
                }
                .zIndex(500)

                if comp.notificationCenterOpen {
                    NotificationCenterPanel()
                        .frame(width: 250, height: areaSize.height - 8)
                        .position(x: geo.size.width - 129, y: areaSize.height / 2)
                        .zIndex(550)
                }

                if let t = comp.toast {
                    ToastView(n: t)
                        .frame(width: 250)
                        .position(x: geo.size.width - 133, y: areaSize.height - 44)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .zIndex(600)
                }

                if let d = comp.dialog {
                    Color.black.opacity(0.25).zIndex(700)
                    SystemDialogView(dialog: d)
                        .frame(width: min(380, geo.size.width - 40))
                        .position(x: geo.size.width / 2, y: areaSize.height / 2)
                        .zIndex(701)
                }
            }
            .onAppear { comp.area = areaSize }
            .onChange(of: geo.size) { _, _ in comp.area = CGSize(width: geo.size.width, height: geo.size.height - 34) }
            .animation(.easeOut(duration: 0.2), value: comp.toast)
        }
    }
}

struct Wallpaper: View {
    let index: Int
    var body: some View {
        switch index {
        case 1:
            LinearGradient(colors: [Color(red: 0.12, green: 0.05, blue: 0.18), Color(red: 0.02, green: 0.02, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom)
        case 2:
            ZStack {
                Color(red: 0.05, green: 0.12, blue: 0.1)
                Circle().fill(Color(red: 0.1, green: 0.35, blue: 0.3).opacity(0.5)).blur(radius: 60).offset(x: 120, y: -60)
            }
        default:
            ZStack {
                LinearGradient(colors: [Color(red: 0.10, green: 0.18, blue: 0.38), Color(red: 0.03, green: 0.05, blue: 0.14)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(Color(red: 0.3, green: 0.5, blue: 1).opacity(0.25)).blur(radius: 80).offset(x: 160, y: -40)
            }
        }
    }
}

struct DesktopIcons: View {
    @EnvironmentObject var session: GameSession
    @EnvironmentObject var comp: ComputerSimulationManager

    struct Icon: Identifiable { let id: String; let name: String; let app: AppKind; let action: () -> Void }

    var icons: [Icon] {
        var list: [Icon] = [
            Icon(id: "files", name: "Files", app: .files) { comp.open(.files, payload: "C:/Users/sam") },
            Icon(id: "browser", name: "Drift", app: .browser) { comp.open(.browser) },
            Icon(id: "kestrel", name: "Kestrel", app: .kestrel) { comp.open(.kestrel) },
            Icon(id: "shield", name: "Shield", app: .shield) { comp.open(.shield) },
            Icon(id: "recycle", name: "Recycle Bin", app: .recycle) { comp.open(.recycle) },
        ]
        if session.has("remaster_installed") {
            list.append(Icon(id: "remaster", name: "Reawakened", app: .remaster) { comp.launch(.remaster) })
        }
        if session.has("keysmith_installed") {
            list.append(Icon(id: "keysmith", name: "KeySmith", app: .keysmith) { comp.launch(.keysmith) })
        }
        return list
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.fixed(70)), GridItem(.fixed(70))], alignment: .leading, spacing: 8) {
            ForEach(icons) { icon in
                Button(action: icon.action) {
                    VStack(spacing: 4) {
                        Image(systemName: icon.app.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(icon.app.tint)
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                        Text(icon.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                            .lineLimit(1)
                    }
                    .frame(width: 66)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct Taskbar: View {
    @EnvironmentObject var session: GameSession
    @EnvironmentObject var comp: ComputerSimulationManager

    var body: some View {
        HStack(spacing: 6) {
            Button {
                AudioManager.shared.play(.uiClick)
                comp.startOpen.toggle()
                comp.notificationCenterOpen = false
            } label: {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 0.45, green: 0.7, blue: 1))
                    .frame(width: 34, height: 30)
                    .background(comp.startOpen ? Color.white.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 5))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(comp.windows) { w in
                        Button { comp.taskbarTap(w.id) } label: {
                            HStack(spacing: 4) {
                                Image(systemName: w.app.icon).foregroundStyle(w.app.tint)
                                Text(w.title).lineLimit(1).frame(maxWidth: 90)
                            }
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(w.minimized ? 0.55 : 0.95))
                            .padding(.horizontal, 7).frame(height: 28)
                            .background(.white.opacity(comp.windows.last == w && !w.minimized ? 0.16 : 0.06), in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }
            }
            Spacer(minLength: 4)
            HStack(spacing: 8) {
                Image(systemName: "wifi")
                Image(systemName: "speaker.wave.2.fill")
                Image(systemName: "checkmark.shield.fill").foregroundStyle(.green.opacity(0.8))
                Button {
                    comp.notificationCenterOpen.toggle()
                    comp.startOpen = false
                } label: {
                    Image(systemName: session.data.desktop.notifications.isEmpty ? "bell" : "bell.badge.fill")
                }
                Text(session.clockText).font(.system(size: 10, design: .monospaced))
            }
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.8))
            .padding(.trailing, 8)
        }
        .frame(height: 34)
        .background(.black.opacity(0.72))
        .overlay(Rectangle().fill(.white.opacity(0.08)).frame(height: 1), alignment: .top)
    }
}

struct StartMenu: View {
    @EnvironmentObject var session: GameSession
    @EnvironmentObject var comp: ComputerSimulationManager

    var apps: [AppKind] {
        var a: [AppKind] = [.files, .browser, .kestrel, .shield, .taskmgr, .settings, .recycle]
        if session.has("remaster_installed") { a.append(.remaster) }
        if session.has("keysmith_installed") { a.append(.keysmith) }
        return a
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("sam").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.8)).padding(8)
            ForEach(apps, id: \.self) { app in
                Button {
                    if app == .files { comp.open(.files, payload: "C:/Users/sam") } else { comp.launch(app) }
                } label: {
                    HStack {
                        Image(systemName: app.icon).foregroundStyle(app.tint).frame(width: 20)
                        Text(app.title).foregroundStyle(.white)
                        Spacer()
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Divider().background(.white.opacity(0.2))
            Button {
                session.leaveDesktop()
            } label: {
                Label("Stand up from the desk", systemImage: "power").font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 220)
        .background(Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.97), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12)))
        .padding(.bottom, 4)
    }
}

struct ToastView: View {
    let n: DesktopNotification
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(n.app.uppercased()).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
            Text(n.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            Text(n.body).font(.system(size: 11)).foregroundStyle(.white.opacity(0.8)).lineLimit(3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.1, green: 0.11, blue: 0.15).opacity(0.97), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12)))
        .shadow(radius: 8)
    }
}

struct NotificationCenterPanel: View {
    @EnvironmentObject var session: GameSession
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Notifications").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Button("Clear") { session.data.desktop.notifications.removeAll() }.font(.system(size: 11))
            }
            ScrollView {
                VStack(spacing: 6) {
                    if session.data.desktop.notifications.isEmpty {
                        Text("You're all caught up.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).padding(.top, 20)
                    }
                    ForEach(session.data.desktop.notifications) { n in
                        ToastView(n: n).shadow(radius: 0)
                    }
                }
            }
        }
        .padding(10)
        .background(Color(red: 0.06, green: 0.07, blue: 0.1).opacity(0.97), in: RoundedRectangle(cornerRadius: 10))
    }
}
