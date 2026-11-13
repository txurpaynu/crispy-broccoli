import SwiftUI

struct PauseMenuView: View {
    @EnvironmentObject var session: GameSession
    @EnvironmentObject var settings: GameSettings
    @State private var tab: Tab = .objectives
    @State private var selectedItem: String?

    enum Tab: String, CaseIterable { case objectives = "Objectives", inventory = "Inventory", journal = "Journal", system = "System" }

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PAUSED").font(.system(size: 12, weight: .semibold, design: .monospaced)).kerning(3)
                        .foregroundStyle(.white.opacity(0.5)).padding(.bottom, 8)
                    ForEach(Tab.allCases, id: \.self) { t in
                        Button {
                            AudioManager.shared.play(.uiClick)
                            tab = t
                        } label: {
                            Text(t.rawValue)
                                .font(.system(size: 17, weight: tab == t ? .semibold : .regular))
                                .foregroundStyle(.white.opacity(tab == t ? 1 : 0.55))
                        }
                    }
                    Spacer()
                    Button {
                        session.paused = false
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.white.opacity(0.15), in: Capsule())
                    }
                    .foregroundStyle(.white)
                }
                .frame(width: 150, alignment: .leading)

                Divider().background(.white.opacity(0.2))

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        switch tab {
                        case .objectives: objectives
                        case .inventory: inventory
                        case .journal: journal
                        case .system: system
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(28)
        }
    }

    private var objectives: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let ch = session.currentChapter {
                Text("\(ch.number) — \(ch.title)").font(.system(size: 13, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
            }
            if let o = session.currentObjective {
                Label(o.text, systemImage: "circle").foregroundStyle(.white)
            }
            ForEach(session.objectives.completed(flags: session.data.flags).reversed()) { o in
                Label(o.text, systemImage: "checkmark.circle.fill").foregroundStyle(.white.opacity(0.4))
                    .strikethrough()
            }
        }
        .font(.system(size: 15))
    }

    private var inventory: some View {
        VStack(alignment: .leading, spacing: 10) {
            if session.data.inventory.isEmpty {
                Text("Nothing. Pockets full of lint.").foregroundStyle(.white.opacity(0.5))
            }
            ForEach(session.data.inventory, id: \.self) { id in
                if let item = session.db.items[id] {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name).font(.system(size: 16, weight: .semibold))
                        Text(item.description).font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
                        if let doc = item.revealsDocument {
                            Button(session.hasDocument(doc) ? "Read it again" : "Look inside") {
                                AudioManager.shared.play(.paper)
                                session.paused = false
                                session.inspect(doc)
                            }
                            .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .foregroundStyle(.white)
    }

    private var journal: some View {
        VStack(alignment: .leading, spacing: 8) {
            if session.data.documents.isEmpty {
                Text("No documents yet. Look around.").foregroundStyle(.white.opacity(0.5))
            }
            ForEach(session.data.documents, id: \.self) { id in
                if let d = session.db.documents[id] {
                    Button {
                        session.paused = false
                        session.inspecting = d
                    } label: {
                        HStack {
                            Image(systemName: d.kind == "phone" ? "iphone" : d.kind == "file" ? "doc.text" : "note.text")
                            Text(d.title)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(10)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private var system: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                systemButton("Save game", "square.and.arrow.down") { session.saveManual() }
                systemButton("Load save", "clock.arrow.circlepath") { session.load(.manual) }
                    .disabled(!session.saves.exists(.manual))
                systemButton("Load autosave", "arrow.counterclockwise") { session.load(.auto) }
            }
            Group {
                VStack(alignment: .leading) {
                    Text("Look sensitivity: \(settings.lookSensitivity, specifier: "%.1f")")
                    Slider(value: $settings.lookSensitivity, in: 0.3...2.5)
                }
                VStack(alignment: .leading) {
                    Text("Volume: \(Int(settings.masterVolume * 100))%")
                    Slider(value: $settings.masterVolume, in: 0...1)
                }
                Toggle("Invert look Y", isOn: $settings.invertY)
                Toggle("Subtitles (inner voice)", isOn: $settings.subtitles)
            }
            .frame(maxWidth: 380)
            systemButton("Quit to title", "rectangle.portrait.and.arrow.right") { session.quitToTitle() }
        }
        .foregroundStyle(.white)
        .font(.system(size: 14))
    }

    private func systemButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            AudioManager.shared.play(.uiClick)
            action()
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
        .foregroundStyle(.white)
    }
}
