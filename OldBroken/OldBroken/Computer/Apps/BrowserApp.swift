import SwiftUI

struct WebBlock: Codable, Hashable {
    let t: String
    let text: String?
    let author: String?
    let meta: String?
    let href: String?
    let action: String?
}

struct WebPage: Codable {
    let url: String
    let title: String
    let theme: String
    let blocks: [WebBlock]
}

struct SearchRule: Codable {
    let keywords: [String]
    let results: [String]
}

struct BrowserData: Codable {
    let pages: [WebPage]
    let search: [SearchRule]

    static let shared: BrowserData = DataLoader.load("browser", as: BrowserData.self) ?? BrowserData(pages: [], search: [])

    func page(_ url: String) -> WebPage? {
        let clean = url.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return pages.first { $0.url == clean }
    }

    func results(for query: String) -> [WebPage] {
        let q = query.lowercased()
        var urls: [String] = []
        for rule in search where rule.keywords.contains(where: { q.contains($0) }) {
            for r in rule.results where !urls.contains(r) { urls.append(r) }
        }
        return urls.compactMap { page($0) }
    }
}

/// "Drift", the in-game web browser. All pages are fictional and data-driven (browser.json).
struct BrowserApp: View {
    @EnvironmentObject var comp: ComputerSimulationManager
    @EnvironmentObject var session: GameSession
    @State private var url = "drift://home"
    @State private var address = ""
    @State private var back: [String] = []
    @State private var query = ""
    @State private var searchResults: [WebPage]? = nil
    @State private var lastQuery = ""
    @State private var showHistory = false

    private let data = BrowserData.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button { goBack() } label: { Image(systemName: "chevron.left") }.disabled(back.isEmpty)
                Button { navigate("drift://home") } label: { Image(systemName: "house") }
                Button { showHistory.toggle() } label: { Image(systemName: "clock.arrow.circlepath") }
                TextField("Search or enter address", text: $address)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(size: 11))
                    .padding(.horizontal, 8).frame(height: 24)
                    .background(.black.opacity(0.35), in: Capsule())
                    .onSubmit { submitAddress() }
            }
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.85))
            .padding(6)
            .background(Color(red: 0.09, green: 0.1, blue: 0.13))

            if showHistory {
                historyView
            } else {
                ScrollView {
                    pageBody
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .background(background)
            }
        }
        .onAppear { address = url }
    }

    private var background: Color {
        switch data.page(url)?.theme ?? "home" {
        case "forum": return Color(red: 0.93, green: 0.92, blue: 0.88)
        case "store": return Color(red: 0.1, green: 0.11, blue: 0.16)
        case "keysmith": return Color(red: 0.08, green: 0.08, blue: 0.08)
        case "home": return Color(red: 0.12, green: 0.13, blue: 0.17)
        default: return .white
        }
    }

    private var ink: Color {
        switch data.page(url)?.theme ?? "home" {
        case "store", "keysmith", "home": return .white
        default: return Color(red: 0.1, green: 0.1, blue: 0.12)
        }
    }

    @ViewBuilder private var pageBody: some View {
        if url == "drift://search", let results = searchResults {
            VStack(alignment: .leading, spacing: 12) {
                Text("Results for \"\(lastQuery)\"").font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                if results.isEmpty {
                    Text("No results. Try different words.").font(.system(size: 13)).foregroundStyle(.white)
                }
                ForEach(results, id: \.url) { r in
                    Button { navigate(r.url) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.url).font(.system(size: 9)).foregroundStyle(.green.opacity(0.8))
                            Text(r.title).font(.system(size: 14, weight: .medium)).foregroundStyle(Color(red: 0.55, green: 0.7, blue: 1))
                            Text(r.blocks.first(where: { $0.t == "p" || $0.t == "post" })?.text ?? "")
                                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.65)).lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if let page = data.page(url) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(page.blocks.enumerated()), id: \.offset) { _, b in block(b) }
            }
            .foregroundStyle(ink)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("This site can't be reached").font(.system(size: 18, weight: .semibold))
                Text("\(url) took too long to respond.").font(.system(size: 12))
            }
            .foregroundStyle(ink)
        }
    }

    @ViewBuilder private func block(_ b: WebBlock) -> some View {
        switch b.t {
        case "h1": Text(b.text ?? "").font(.system(size: 20, weight: .bold))
        case "h2": Text(b.text ?? "").font(.system(size: 15, weight: .semibold)).padding(.top, 4)
        case "p": Text(b.text ?? "").font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
        case "small": Text(b.text ?? "").font(.system(size: 9, weight: .semibold)).opacity(0.55)
        case "meta": Text(b.text ?? "").font(.system(size: 10)).opacity(0.6)
        case "search":
            HStack {
                TextField("Search the web", text: $query)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onSubmit { search(query) }
                Button { search(query) } label: { Image(systemName: "magnifyingglass") }
            }
            .font(.system(size: 13))
            .padding(10)
            .background(.white.opacity(0.1), in: Capsule())
            .frame(maxWidth: 420)
        case "link":
            Button { navigate(b.href ?? "") } label: {
                Text(b.text ?? "").font(.system(size: 12, weight: .medium)).foregroundStyle(Color(red: 0.3, green: 0.55, blue: 1))
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
        case "post", "review":
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(b.author ?? "").font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text(b.meta ?? "").font(.system(size: 9)).opacity(0.5)
                }
                Text(b.text ?? "").font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        case "download":
            Button {
                if let file = b.action { comp.download(file) }
            } label: {
                Label(b.text ?? "Download", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Color(red: 1, green: 0.55, blue: 0.15), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        default: EmptyView()
        }
    }

    private var historyView: some View {
        let vx = StoryDirector.shared.vexleyHistory
        let mine = session.data.flags.filter { $0.hasPrefix("visited_") }.map { String($0.dropFirst(8)) }.sorted()
        return ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("History").font(.system(size: 18, weight: .bold))
                if !vx.isEmpty {
                    Text("Today, while you were asleep").font(.system(size: 10, weight: .semibold)).opacity(0.5).padding(.top, 4)
                    ForEach(Array(vx.enumerated()), id: \.offset) { _, h in
                        HStack(spacing: 10) {
                            Text(h.0).font(.system(size: 10, design: .monospaced)).opacity(0.5).frame(width: 58, alignment: .leading)
                            Image(systemName: "magnifyingglass").font(.system(size: 10)).opacity(0.6)
                            Text(h.1).font(.system(size: 12))
                        }
                    }
                }
                Text("Earlier").font(.system(size: 10, weight: .semibold)).opacity(0.5).padding(.top, 8)
                if mine.isEmpty { Text("Nothing yet.").font(.system(size: 12)).opacity(0.6) }
                ForEach(mine, id: \.self) { u in
                    Button { showHistory = false; navigate(u) } label: {
                        Text(u).font(.system(size: 12)).foregroundStyle(Color(red: 0.55, green: 0.7, blue: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundStyle(.white)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(red: 0.12, green: 0.13, blue: 0.17))
        .onAppear { if !vx.isEmpty { session.set("saw_vx_history") } }
    }

    private func submitAddress() {
        let a = address.trimmingCharacters(in: .whitespaces)
        if a.contains(".") && !a.contains(" ") || a.hasPrefix("drift://") { navigate(a) } else { search(a) }
    }

    private func search(_ q: String) {
        let t = q.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        lastQuery = t
        searchResults = data.results(for: t)
        session.set("searched_web")
        push("drift://search")
        address = t
    }

    private func navigate(_ to: String) {
        let clean = to.replacingOccurrences(of: "https://", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        push(clean)
        address = clean
        session.set("visited_" + clean)
        if clean == "retrovault.net/t/88213" { session.set("read_forum_thread") }
        if clean == "retrovault.net/t/1204" { session.set("read_fox_thread") }
        StoryDirector.shared.pageVisited(clean)
    }

    private func push(_ u: String) {
        showHistory = false
        if u != url { back.append(url) }
        url = u
        AudioManager.shared.play(.mouseClick)
    }

    private func goBack() {
        if let b = back.popLast() { url = b; address = b }
    }
}
