import SwiftUI
import SwiftData

/// One item on the life timeline, drawn from any module.
struct TimelineItem: Identifiable {
    enum Kind: String, CaseIterable, Identifiable {
        case journal = "Journal", trip = "Trips", project = "Projects", learning = "Learning", event = "Events", memory = "Memories"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .journal: "book.closed"
            case .trip: "airplane"
            case .project: "checkmark.seal"
            case .learning: "graduationcap"
            case .event: "flag"
            case .memory: "sparkles"
            }
        }
        var tint: Color {
            switch self {
            case .journal: Theme.accent
            case .trip: Theme.earth
            case .project: Theme.gold
            case .learning: Color(hex: 0x6F6A9A)
            case .event: Theme.jungle
            case .memory: Theme.gold
            }
        }
    }

    let id: String
    let kind: Kind
    let date: Date
    let title: String
    let subtitle: String
    let thumbnail: String?
    let open: () -> Void
}

/// Builds timeline items. Only *notable* journal entries (important/favorite)
/// appear by default, so the timeline reads as a life history rather than a diary.
@MainActor
enum TimelineBuilder {
    static func items(context: ModelContext, router: AppRouter, includeAllEntries: Bool) -> [TimelineItem] {
        func all<T: PersistentModel>(_ t: T.Type) -> [T] { (try? context.fetch(FetchDescriptor<T>())) ?? [] }
        var items: [TimelineItem] = []
        for e in all(JournalEntry.self) where includeAllEntries || e.isImportant || e.isFavorite {
            items.append(TimelineItem(id: "j\(e.id)", kind: .journal, date: e.date, title: e.displayTitle,
                                      subtitle: e.isImportant ? "Important moment" : "Journal", thumbnail: e.photoAttachments.first?.fileName,
                                      open: { router.open(e) }))
        }
        for t in all(TravelTrip.self) where t.status == .completed || t.status == .ongoing {
            items.append(TimelineItem(id: "t\(t.id)", kind: .trip, date: t.startDate, title: t.title,
                                      subtitle: t.destination.isEmpty ? "Trip" : t.destination,
                                      thumbnail: t.coverFileName.isEmpty ? nil : t.coverFileName, open: { router.open(t) }))
        }
        for p in all(CreativeProject.self) where p.status == .completed {
            items.append(TimelineItem(id: "p\(p.id)", kind: .project, date: p.completedAt ?? p.modifiedAt, title: p.name,
                                      subtitle: "Project completed", thumbnail: p.coverFileName.isEmpty ? nil : p.coverFileName, open: { router.open(p) }))
        }
        for g in all(LearningGoal.self) where g.isCompleted {
            items.append(TimelineItem(id: "g\(g.id)", kind: .learning, date: g.completedAt ?? g.createdAt, title: g.skillName,
                                      subtitle: "Learning goal achieved", thumbnail: nil, open: { router.open(g) }))
        }
        for e in all(LifeEvent.self) where e.date <= Date() {
            items.append(TimelineItem(id: "e\(e.id)", kind: .event, date: e.date, title: e.title, subtitle: e.kind.label,
                                      thumbnail: nil, open: { router.open(AppModule.events) }))
        }
        for m in all(Memory.self) {
            items.append(TimelineItem(id: "m\(m.id)", kind: .memory, date: m.date, title: m.displayTitle, subtitle: m.kind.label,
                                      thumbnail: m.sortedAttachments.first?.fileName, open: { router.open(m) }))
        }
        return items.sorted { $0.date > $1.date }
    }
}

struct LifeTimelineView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter
    @State private var items: [TimelineItem] = []
    @State private var kinds = Set(TimelineItem.Kind.allCases)
    @State private var allEntries = false
    @State private var year: Int? = nil
    @State private var newEvent = false

    private var years: [Int] { Array(Set(items.map { DateMath.year(of: $0.date) })).sorted(by: >) }

    private var filtered: [TimelineItem] {
        items.filter { kinds.contains($0.kind) && (year == nil || DateMath.year(of: $0.date) == year) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TimelineItem.Kind.allCases) { k in
                            Button {
                                if kinds.contains(k) { kinds.remove(k) } else { kinds.insert(k) }
                            } label: { Chip(text: k.rawValue, symbol: k.symbol, color: k.tint, isSelected: kinds.contains(k)) }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                if filtered.isEmpty {
                    EmptyStateView(symbol: "point.3.connected.trianglepath.dotted", title: "Your story unfolds here",
                                   message: "Important journal moments, trips, finished projects, learning milestones and events gather into one history.",
                                   actionTitle: "Add a life event") { newEvent = true }
                } else {
                    let groups = Dictionary(grouping: filtered) { DateMath.year(of: $0.date) }
                    ForEach(groups.keys.sorted(by: >), id: \.self) { y in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(String(y))
                                .font(.system(.largeTitle, design: .serif).weight(.semibold))
                                .foregroundStyle(Theme.gold)
                                .padding(.horizontal)
                                .padding(.bottom, Theme.Spacing.s)
                            ForEach(groups[y] ?? []) { item in
                                TimelineRow(item: item)
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .screenBackground()
        .navigationTitle("Life Timeline")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Year", selection: $year) {
                        Text("All years").tag(Int?.none)
                        ForEach(years, id: \.self) { Text(String($0)).tag(Int?.some($0)) }
                    }
                    Toggle("Include every journal entry", isOn: $allEntries)
                    Button { newEvent = true } label: { Label("Add life event", systemImage: "flag") }
                } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                .accessibilityLabel("Timeline options")
            }
        }
        .sheet(isPresented: $newEvent, onDismiss: reload) { LifeEventEditor(event: nil) }
        .onAppear(perform: reload)
        .onChange(of: allEntries) { _, _ in reload() }
    }

    private func reload() {
        items = TimelineBuilder.items(context: context, router: router, includeAllEntries: allEntries)
    }
}

struct TimelineRow: View {
    let item: TimelineItem
    var body: some View {
        Button(action: item.open) {
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                VStack(spacing: 0) {
                    Circle().fill(item.kind.tint).frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(Theme.background, lineWidth: 2))
                    Rectangle().fill(Theme.separator).frame(width: 2).frame(maxHeight: .infinity)
                }
                .frame(width: 12)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.date.formatted(date: .long, time: .omitted)).font(Typo.caption).foregroundStyle(Theme.textTertiary)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(item.kind.rawValue, systemImage: item.kind.symbol).font(Typo.eyebrow).foregroundStyle(item.kind.tint)
                            Text(item.title).font(Typo.headline).foregroundStyle(Theme.textPrimary).multilineTextAlignment(.leading)
                            Text(item.subtitle).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        if let thumb = item.thumbnail {
                            MediaThumbnail(fileName: thumb, maxPixel: 200, cornerRadius: 10).frame(width: 56, height: 56)
                        }
                    }
                    .cardStyle(padding: Theme.Spacing.m)
                }
                .padding(.bottom, Theme.Spacing.m)
            }
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}
