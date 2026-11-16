import SwiftUI
import SwiftData

/// Local, offline search across every module.
struct GlobalSearchView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case all = "All", journal = "Journal", memories = "Memories", projects = "Projects", people = "People",
             places = "Places", learning = "Learning", tasks = "Tasks", events = "Events"
        var id: String { rawValue }
    }

    struct SearchHit: Identifiable {
        let id: String
        let scope: Scope
        let title: String
        let detail: String
        let date: Date?
        let symbol: String
        let open: () -> Void
    }

    @Query private var entries: [JournalEntry]
    @Query private var memories: [Memory]
    @Query private var projects: [CreativeProject]
    @Query private var people: [Person]
    @Query private var places: [TravelDestination]
    @Query private var trips: [TravelTrip]
    @Query private var goals: [LearningGoal]
    @Query private var sessions: [StudySession]
    @Query private var tasks: [TaskItem]
    @Query private var events: [LifeEvent]
    @EnvironmentObject private var router: AppRouter
    @State private var query = ""
    @State private var scope: Scope = .all
    @State private var editingTask: TaskItem?

    var body: some View {
        List {
            Picker("Filter", selection: $scope) { ForEach(Scope.allCases) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.menu)
            if query.trimmingCharacters(in: .whitespaces).count < 2 {
                Text("Type at least two letters. Search runs on this iPhone only.")
                    .foregroundStyle(Theme.textSecondary)
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                let grouped = Dictionary(grouping: results, by: \.scope)
                ForEach(Scope.allCases.filter { grouped[$0] != nil }) { s in
                    Section("\(s.rawValue) (\(grouped[s]!.count))") {
                        ForEach(grouped[s]!.prefix(scope == .all ? 5 : 200)) { r in
                            Button(action: r.open) {
                                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                                    Image(systemName: r.symbol).foregroundStyle(Theme.accent).frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(r.title).foregroundStyle(Theme.textPrimary).lineLimit(1)
                                        if !r.detail.isEmpty { Text(r.detail).font(Typo.caption).foregroundStyle(Theme.textSecondary).lineLimit(2) }
                                        if let d = r.date { Text(d.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(Theme.textTertiary) }
                                    }
                                }
                            }
                        }
                        if scope == .all && grouped[s]!.count > 5 {
                            Button("Show all \(grouped[s]!.count)") { scope = s }.font(Typo.caption)
                        }
                    }
                }
            }
        }
        .screenBackground()
        .navigationTitle("Search")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search everything")
        .sheet(item: $editingTask) { TaskEditor(task: $0) }
    }

    private func snippet(_ text: String, around q: String) -> String {
        guard let r = text.range(of: q, options: .caseInsensitive) else { return String(text.prefix(100)) }
        let start = text.index(r.lowerBound, offsetBy: -40, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(r.upperBound, offsetBy: 60, limitedBy: text.endIndex) ?? text.endIndex
        return (start > text.startIndex ? "…" : "") + text[start..<end].replacingOccurrences(of: "\n", with: " ") + (end < text.endIndex ? "…" : "")
    }

    private var results: [SearchHit] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }
        func has(_ s: String) -> Bool { s.localizedCaseInsensitiveContains(q) }
        func want(_ s: Scope) -> Bool { scope == .all || scope == s }
        var out: [SearchHit] = []

        if want(.journal) {
            for e in entries where has(e.title) || has(e.body) || has(e.reflection) || e.tags.contains(where: has) || has(e.locationName) {
                out.append(SearchHit(id: "j\(e.id)", scope: .journal, title: e.displayTitle, detail: snippet(e.body, around: q),
                                  date: e.date, symbol: "book.closed", open: { router.open(e) }))
            }
        }
        if want(.memories) {
            for m in memories where has(m.title) || has(m.text) || m.tags.contains(where: has) || has(m.collection) || has(m.locationName) {
                out.append(SearchHit(id: "m\(m.id)", scope: .memories, title: m.displayTitle, detail: snippet(m.text, around: q),
                                  date: m.date, symbol: m.kind.symbol, open: { router.open(m) }))
            }
        }
        if want(.projects) {
            for p in projects where has(p.name) || has(p.summary) || has(p.notes) || has(p.category) {
                out.append(SearchHit(id: "p\(p.id)", scope: .projects, title: p.name, detail: snippet(p.summary.isEmpty ? p.notes : p.summary, around: q),
                                  date: p.modifiedAt, symbol: "paintbrush.pointed", open: { router.open(p) }))
            }
        }
        if want(.people) {
            for p in people where has(p.name) || has(p.notes) || has(p.relationship) {
                out.append(SearchHit(id: "pe\(p.id)", scope: .people, title: p.name, detail: p.relationship, date: nil,
                                  symbol: "person", open: { router.open(p) }))
            }
        }
        if want(.places) {
            for t in trips where has(t.title) || has(t.destination) || has(t.itinerary) || has(t.notes) {
                out.append(SearchHit(id: "t\(t.id)", scope: .places, title: t.title, detail: t.destination, date: t.startDate,
                                  symbol: "airplane", open: { router.open(t) }))
            }
            for p in places where has(p.name) || has(p.city) || has(p.country) || has(p.notes) {
                out.append(SearchHit(id: "pl\(p.id)", scope: .places, title: p.name, detail: [p.city, p.country].filter { !$0.isEmpty }.joined(separator: ", "),
                                  date: p.visitedDate, symbol: p.kind.symbol, open: { router.open(p) }))
            }
        }
        if want(.learning) {
            for g in goals where has(g.skillName) || has(g.notes) || has(g.summary) || has(g.resources) {
                out.append(SearchHit(id: "g\(g.id)", scope: .learning, title: g.skillName, detail: g.category.label, date: nil,
                                  symbol: "graduationcap", open: { router.open(g) }))
            }
            for s in sessions where has(s.subject) || has(s.notes) || has(s.learned) || has(s.nextSteps) {
                let open: () -> Void = { if let g = s.goal { router.open(g) } else { router.open(AppModule.learn) } }
                out.append(SearchHit(id: "s\(s.id)", scope: .learning, title: s.subject.isEmpty ? "Study session" : s.subject,
                                  detail: snippet(s.learned.isEmpty ? s.notes : s.learned, around: q), date: s.date, symbol: "timer", open: open))
            }
        }
        if want(.tasks) {
            for t in tasks where has(t.title) || has(t.notes) {
                out.append(SearchHit(id: "tk\(t.id)", scope: .tasks, title: t.title, detail: t.isDone ? "Done" : "Open", date: t.dueDate,
                                  symbol: t.isDone ? "checkmark.circle" : "circle", open: { editingTask = t }))
            }
        }
        if want(.events) {
            for e in events where has(e.title) || has(e.notes) {
                out.append(SearchHit(id: "e\(e.id)", scope: .events, title: e.title, detail: e.kind.label, date: e.date,
                                  symbol: e.kind.symbol, open: { router.open(AppModule.events) }))
            }
        }
        return out.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }
}
