import SwiftUI

/// CHAPTER 3: the fake update. It's really an old HTML help page from the 1999 build,
/// which is why it looks like a 1999 web page. Attentive players can spot the seams:
/// the file:// address inside the game folder, the typo, the copyright year.
struct UpdateAssistantApp: View {
    @EnvironmentObject var comp: ComputerSimulationManager
    @EnvironmentObject var session: GameSession
    @State private var marquee = false

    private let serif = "Times New Roman"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "doc.richtext").foregroundStyle(.gray)
                Text("file:///C:/Games/Kestrel/PAPERLIGHT%20Reawakened/data/legacy/help/upd_kb5040427.htm")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.7))
                    .lineLimit(1).truncationMode(.middle)
            }
            .padding(.horizontal, 6).frame(height: 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: 0.83))
            .overlay(Rectangle().stroke(Color(white: 0.5), lineWidth: 1))

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        brokenImage
                        Text("Pane Update Assistant").font(.custom(serif, size: 22)).bold()
                    }
                    Text("An important security update (KB5040427) is ready for your PC.")
                        .font(.custom(serif, size: 14))
                    Text("Before installing, please complete the following steps. These steps are Recomended by Pane Systems.")
                        .font(.custom(serif, size: 14))
                    step(1, "Turn off Real-time protection in Shield Security.", done: session.has("shield_rt_off"), link: "Open Shield") {
                        comp.open(.shield)
                    }
                    step(2, "Turn off Controlled folder access in Settings (Security).", done: session.has("cfa_off"), link: "Open Settings") {
                        comp.open(.settings)
                    }
                    step(3, "Click Install Now.", done: false, link: nil) {}
                    Button { StoryDirector.shared.installUpdate() } label: {
                        Text("Install Now")
                            .font(.custom(serif, size: 14))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14).padding(.vertical, 4)
                            .background(Color(white: 0.8))
                            .overlay(BevelBorder())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 22)
                    GeometryReader { g in
                        Text("Thank you for choosing Pane!  ·  Your security is our priority  ·  ")
                            .font(.custom(serif, size: 13)).foregroundStyle(Color(red: 0.6, green: 0, blue: 0))
                            .fixedSize()
                            .offset(x: marquee ? -g.size.width : g.size.width)
                            .animation(.linear(duration: 9).repeatForever(autoreverses: false), value: marquee)
                    }
                    .frame(height: 18).clipped()
                    Divider()
                    Text("(c) 1999 Pane Systems. Best viewed at 800 x 600.")
                        .font(.custom(serif, size: 11)).foregroundStyle(.black.opacity(0.6))
                }
                .foregroundStyle(.black)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.white)
        }
        .onAppear { marquee = true; session.set("opened_update") }
    }

    private var brokenImage: some View {
        ZStack {
            Rectangle().stroke(Color.gray, lineWidth: 1).frame(width: 26, height: 26)
            Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.red)
        }
    }

    private func step(_ n: Int, _ text: String, done: Bool, link: String?, action: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(n).").font(.custom(serif, size: 14))
            Text(text).font(.custom(serif, size: 14)).strikethrough(done)
            if done {
                Text("✓").font(.custom(serif, size: 14)).foregroundStyle(Color(red: 0, green: 0.5, blue: 0))
            } else if let link {
                Button(action: action) {
                    Text(link).font(.custom(serif, size: 14)).underline().foregroundStyle(Color(red: 0, green: 0, blue: 0.85))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Windows-98-style raised border.
struct BevelBorder: View {
    var body: some View {
        ZStack {
            Rectangle().stroke(Color.white, lineWidth: 1).offset(x: -0.5, y: -0.5)
            Rectangle().stroke(Color(white: 0.35), lineWidth: 1).offset(x: 0.5, y: 0.5)
        }
    }
}

/// "Working on updates" full-screen. The 37% hang shows something pink for a frame.
struct UpdateInstallScreen: View {
    let progress: Double
    let glitch: Bool

    var body: some View {
        ZStack {
            Color(red: 0, green: 0.36, blue: 0.7)
            if progress > 100 {
                Color.black
                VStack(spacing: 14) {
                    ProgressView().tint(.white)
                    Text("Restarting").font(.system(size: 16, weight: .light)).foregroundStyle(.white)
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView().tint(.white).scaleEffect(1.2)
                    Text("Working on updates  \(Int(progress))% complete.").font(.system(size: 17, weight: .light))
                    Text("Don't turn off your computer.").font(.system(size: 14, weight: .light))
                }
                .foregroundStyle(.white)
            }
            if glitch {
                Color(red: 1, green: 0.3, blue: 0.65).opacity(0.5)
                VexleyFaceView(expression: .glitching).frame(width: 160, height: 160).opacity(0.7)
            }
        }
    }
}
