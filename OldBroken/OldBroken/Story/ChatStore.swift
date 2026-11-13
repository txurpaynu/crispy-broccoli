import SwiftUI

/// Chatter, the messaging app (phone + desktop sync). Conversations are rebuilt from
/// story flags, so they survive saves without extra data. The real Theo types in
/// lowercase and calls you "sammy". The impersonated Theo doesn't.
struct ChatMessage: Identifiable {
    let id: Int
    let fromMe: Bool
    let text: String
    let time: String
}

struct ChatThread: Identifiable {
    let id: String
    let name: String
    let messages: [ChatMessage]
}

struct ChatOption: Identifiable {
    var id: String { flag }
    let label: String
    /// Set when the player sends it.
    let flag: String
    /// Reply flags set (in order) after the other side "types".
    let replies: [String]
}

@MainActor
final class ChatController: ObservableObject {
    static let shared = ChatController()
    @Published var typing: String?
    private var session: GameSession { GameSession.shared }

    func send(_ o: ChatOption, in thread: String) {
        guard typing == nil else { return }
        AudioManager.shared.play(.uiClick)
        session.set(o.flag)
        guard !o.replies.isEmpty else { return }
        typing = thread
        var delay = 1.8
        for (i, r) in o.replies.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.session.set(r)
                AudioManager.shared.play(.notification)
                if i == o.replies.count - 1 { self?.typing = nil }
            }
            delay += 1.6
        }
    }

    func call(_ thread: String) {
        AudioManager.shared.play(.uiClick)
        if thread == "theo" {
            session.set("ch4_called_theo")
            ComputerSimulationManager.shared.toast = nil
            session.showBanner("Call failed", "Theo is unavailable.")
            session.say("Straight to voicemail. Theo never lets it go to voicemail.")
        } else {
            session.showBanner("Calling…", "No answer.")
        }
    }
}

@MainActor
enum ChatStore {
    static func threads(_ s: GameSession) -> [ChatThread] {
        [theo(s), maya(s), mom(s)]
    }

    private static func build(_ id: String, _ name: String, _ rows: [(Bool, String, String)]) -> ChatThread {
        ChatThread(id: id, name: name, messages: rows.enumerated().map { ChatMessage(id: $0.offset, fromMe: $0.element.0, text: $0.element.1, time: $0.element.2) })
    }

    static func theo(_ s: GameSession) -> ChatThread {
        var r: [(Bool, String, String)] = [
            (false, "sammy you alive", "2 weeks ago"),
            (true, "barely", "2 weeks ago"),
            (false, "lol same", "2 weeks ago"),
            (false, "dude", "Mon 9:12 PM"),
            (false, "PAPERLIGHT IS GETTING A REMASTER\nlike actually. reawakened. its on kestrel", "Mon 9:12 PM"),
            (false, "remember when you made me sit through the lighthouse level like 40 times", "Mon 9:13 PM"),
            (true, "no way. buying it tonight", "Mon 9:40 PM"),
            (false, "reviews are... not great lol. tell me if its bad", "Mon 11:58 PM"),
        ]
        if s.day >= 2 { r.append((false, "so was it bad", "Tue 1:14 PM")) }
        if s.day >= 3 { r.append((false, "hello??\nsammy", "Wed 6:02 PM")) }
        if s.day >= 3 { r.append((false, "ok ignore me then lol", "Wed 11:40 PM")) }
        if s.has("ch4_asked_theo") { r.append((true, "Have you heard of this Lumen thing? It's all over the news.", "Thu 9:03 AM")) }
        if s.has("ch4_theo_r1") {
            r.append((false, "Hi Sam! Yes, I've been using Lumen for a week now. It's honestly impressive.", "Thu 9:03 AM"))
            r.append((false, "It remembers everything you tell it. You should really try it :)", "Thu 9:04 AM"))
        }
        if s.has("ch4_probe_caps") { r.append((true, "since when do you use capital letters lol", "Thu 9:05 AM")) }
        if s.has("ch4_theo_r_caps") { r.append((false, "Ha! New phone. The autocorrect is very aggressive.", "Thu 9:05 AM")) }
        if s.has("ch4_probe_sat") { r.append((true, "what did we do last saturday?", "Thu 9:06 AM")) }
        if s.has("ch4_theo_r_sat") { r.append((false, "The usual! Anyway, have you tried Lumen yet?", "Thu 9:06 AM")) }
        if s.has("ch4_ok_theo") { r.append((true, "ok I'll check it out", "Thu 9:07 AM")) }
        if s.has("ch4_theo_r_ok") { r.append((false, "Great! It's at lumen-ai.com. Let me know what you think!", "Thu 9:07 AM")) }
        if s.has("ch4_told_fox") { r.append((true, "tried it. picked the fox lol", "Thu")) }
        if s.has("ch4_theo_knew") { r.append((false, "I knew you would.", "Thu")) }
        if s.has("ch5_theo_real") {
            r.append((false, "sammy sorry my phone died for like 4 days", "Sat 8:15 PM"))
            r.append((false, "wait what lumen thing. i never sent you that", "Sat 8:16 PM"))
            r.append((false, "?? sammy whats going on", "Sat 8:20 PM"))
        }
        return build("theo", "Theo", r)
    }

    static func maya(_ s: GameSession) -> ChatThread {
        var r: [(Bool, String, String)] = [
            (false, "Are you coming to Priya's thing on Saturday?", "last week"),
            (true, "maybe", "last week"),
            (false, "That means no.", "last week"),
        ]
        if s.has("ch4_asked_maya") { r.append((true, "Have you heard of Lumen? The AI assistant?", "Thu")) }
        if s.has("ch4_maya_r1") { r.append((false, "No? What is it?", "Thu")) }
        if s.has("ch4_maya_more") { r.append((true, "it was on the news this morning", "Thu")) }
        if s.has("ch4_maya_r2") { r.append((false, "I just looked. There's almost nothing about it. One news clip and a website.", "Thu")) }
        if s.has("ch4_maya_doubt") { r.append((false, "Weird. Be careful what you install.", "Thu")) }
        return build("maya", "Maya", r)
    }

    static func mom(_ s: GameSession) -> ChatThread {
        var r: [(Bool, String, String)] = [
            (false, "Did you eat today?", "Sun"),
            (false, "Call me this weekend. Love you.", "Sun"),
        ]
        if s.has("ch4_asked_mom") { r.append((true, "mom have you heard of an app called Lumen?", "Thu")) }
        if s.has("ch4_mom_r1") { r.append((false, "No sweetie. Ask Theo, he knows computers.", "Thu")) }
        return build("mom", "Mom", r)
    }

    static func options(_ thread: String, _ s: GameSession) -> [ChatOption] {
        guard s.has("saw_lumen_news") else { return [] }
        switch thread {
        case "theo":
            if !s.has("ch4_asked_theo") {
                return [ChatOption(label: "Have you heard of this Lumen thing?", flag: "ch4_asked_theo", replies: ["ch4_theo_r1"])]
            }
            guard s.has("ch4_theo_r1") else { return [] }
            var o: [ChatOption] = []
            if !s.has("ch4_probe_caps") { o.append(ChatOption(label: "since when do you use capital letters lol", flag: "ch4_probe_caps", replies: ["ch4_theo_r_caps"])) }
            if !s.has("ch4_probe_sat") { o.append(ChatOption(label: "what did we do last saturday?", flag: "ch4_probe_sat", replies: ["ch4_theo_r_sat"])) }
            if !s.has("ch4_ok_theo") { o.append(ChatOption(label: "ok I'll check it out", flag: "ch4_ok_theo", replies: ["ch4_theo_r_ok"])) }
            if s.has("lumen_fox") && !s.has("ch4_told_fox") {
                o.append(ChatOption(label: "tried it. picked the fox lol", flag: "ch4_told_fox", replies: ["ch4_theo_knew"]))
            }
            return o
        case "maya":
            if !s.has("ch4_asked_maya") { return [ChatOption(label: "Have you heard of Lumen?", flag: "ch4_asked_maya", replies: ["ch4_maya_r1"])] }
            if s.has("ch4_maya_r1") && !s.has("ch4_maya_more") {
                return [ChatOption(label: "it was on the news this morning", flag: "ch4_maya_more", replies: ["ch4_maya_r2", "ch4_maya_doubt"])]
            }
            return []
        case "mom":
            if !s.has("ch4_asked_mom") { return [ChatOption(label: "have you heard of an app called Lumen?", flag: "ch4_asked_mom", replies: ["ch4_mom_r1"])] }
            return []
        default: return []
        }
    }
}

/// The conversation list + thread UI, shared by the phone and the desktop app.
struct ChatterView: View {
    @EnvironmentObject var session: GameSession
    @ObservedObject private var chat = ChatController.shared
    @State private var open: String?
    var compact = false

    var body: some View {
        let threads = ChatStore.threads(session)
        Group {
            if let id = open, let t = threads.first(where: { $0.id == id }) {
                thread(t)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Chatter").font(.system(size: compact ? 20 : 16, weight: .bold)).padding(12)
                    ForEach(threads) { t in
                        Button { withAnimation(.easeOut(duration: 0.2)) { open = t.id } } label: {
                            HStack(spacing: 10) {
                                avatar(t.name)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.name).font(.system(size: 13, weight: .semibold))
                                    Text(t.messages.last?.text ?? "").font(.system(size: 11)).opacity(0.6).lineLimit(1)
                                }
                                Spacer()
                                if !ChatStore.options(t.id, session).isEmpty {
                                    Circle().fill(Color.green).frame(width: 8, height: 8)
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().opacity(0.3)
                    }
                    Spacer()
                }
            }
        }
        .foregroundStyle(.white)
        .background(Color(red: 0.07, green: 0.09, blue: 0.1))
    }

    private func avatar(_ name: String) -> some View {
        Text(String(name.prefix(1))).font(.system(size: 14, weight: .bold))
            .frame(width: 34, height: 34)
            .background(Circle().fill(name == "Theo" ? Color.orange : (name == "Maya" ? Color.teal : Color.purple)))
    }

    private func thread(_ t: ChatThread) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button { withAnimation(.easeOut(duration: 0.2)) { open = nil } } label: { Image(systemName: "chevron.left") }
                avatar(t.name).scaleEffect(0.8)
                Text(t.name).font(.system(size: 14, weight: .semibold))
                Spacer()
                Button { chat.call(t.id) } label: { Image(systemName: "phone.fill") }
            }
            .padding(10)
            .background(.black.opacity(0.3))
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(t.messages) { m in
                            HStack {
                                if m.fromMe { Spacer(minLength: 40) }
                                VStack(alignment: m.fromMe ? .trailing : .leading, spacing: 2) {
                                    Text(m.text).font(.system(size: 12))
                                        .padding(.horizontal, 10).padding(.vertical, 7)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(m.fromMe ? Color(red: 0.15, green: 0.55, blue: 0.35) : Color(white: 0.2)))
                                    Text(m.time).font(.system(size: 8)).opacity(0.4)
                                }
                                if !m.fromMe { Spacer(minLength: 40) }
                            }
                            .id(m.id)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if chat.typing == t.id {
                            HStack { TypingDots(); Spacer() }.id(-1)
                        }
                    }
                    .padding(10)
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: t.messages.count)
                }
                .onAppear { if let l = t.messages.last { proxy.scrollTo(l.id, anchor: .bottom) } }
                .onChange(of: t.messages.count) { _, _ in
                    if let l = t.messages.last { withAnimation { proxy.scrollTo(l.id, anchor: .bottom) } }
                }
                .onChange(of: chat.typing) { _, v in if v != nil { withAnimation { proxy.scrollTo(-1, anchor: .bottom) } } }
            }
            let opts = ChatStore.options(t.id, session)
            if !opts.isEmpty && chat.typing == nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(opts) { o in
                            Button { chat.send(o, in: t.id) } label: {
                                Text(o.label).font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(Capsule().stroke(Color.green.opacity(0.8)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }
}

struct TypingDots: View {
    @State private var on = false
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle().fill(.white.opacity(0.7)).frame(width: 6, height: 6)
                    .offset(y: on ? -3 : 3)
                    .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.13), value: on)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.2)))
        .onAppear { on = true }
    }
}
