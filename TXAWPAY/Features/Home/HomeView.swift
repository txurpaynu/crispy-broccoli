import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var recents: RecentsStore
    @Query private var profiles: [UserSettings]
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \TaskItem.createdAt) private var tasks: [TaskItem]
    @Query(sort: \LifeEvent.date) private var events: [LifeEvent]
    @Query private var importantDates: [ImportantDate]
    @Query private var people: [Person]
    @Query(sort: \TravelTrip.startDate) private var trips: [TravelTrip]
    @Query(sort: \LearningGoal.createdAt, order: .reverse) private var goals: [LearningGoal]
    @Query(sort: \Reminder.fireDate) private var reminders: [Reminder]
    @Query(sort: \CreativeProject.modifiedAt, order: .reverse) private var projects: [CreativeProject]
    @Query(sort: \Memory.date) private var memories: [Memory]
    @Query(sort: \TravelTrip.modifiedAt, order: .reverse) private var recentTrips: [TravelTrip]
    @AppStorage(AppSettings.Keys.inspirationEnabled) private var inspirationEnabled = true
    @AppStorage(AppSettings.Keys.hideInspirationUntil) private var hideInspirationUntil = 0.0
    @State private var newTaskTitle = ""
    @FocusState private var taskFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                HeroHeader(height: 290) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                            .font(Typo.eyebrow)
                            .tracking(1.5)
                            .foregroundStyle(Theme.gold)
                        Text(greeting)
                            .font(Typo.largeTitle)
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
                .padding(.bottom, -Theme.Spacing.l)

                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    quickActions
                    if showInspiration { inspirationCard }
                    todaySection
                    upcomingSection
                    goalsSection
                    continueSection
                    recentJournal
                    modulesGrid
                }
                .padding(.horizontal)
            }
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Greeting

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 5..<12: base = "Good morning"
        case 12..<18: base = "Good afternoon"
        default: base = "Good evening"
        }
        let name = profiles.first?.displayName.split(separator: " ").first.map(String.init) ?? ""
        return name.isEmpty ? base : "\(base), \(name)"
    }

    // MARK: Quick actions

    private struct QuickAction: Identifiable {
        let id = UUID()
        let title: String
        let symbol: String
        let tint: Color
        let action: () -> Void
    }

    private var actions: [QuickAction] {
        [
            QuickAction(title: "Write", symbol: "square.and.pencil", tint: Theme.accent) { router.newJournalEntry = true },
            QuickAction(title: "Memory", symbol: "sparkles", tint: Theme.gold) { router.capture(.memory) },
            QuickAction(title: "Task", symbol: "checkmark.circle", tint: Theme.jungle) { router.capture(.task) },
            QuickAction(title: "Project", symbol: "lightbulb", tint: Theme.gold) { router.capture(.projectIdea) },
            QuickAction(title: "Study", symbol: "graduationcap", tint: Color(hex: 0x6F6A9A)) { router.open(StudySessionRoute(goalID: nil)) },
            QuickAction(title: "Place", symbol: "mappin.and.ellipse", tint: Theme.earth) { router.capture(.place) },
            QuickAction(title: "Person", symbol: "person.badge.plus", tint: Theme.earth) { router.open(NewPersonRoute()) },
            QuickAction(title: "Thought", symbol: "bubble.left", tint: Theme.accent) { router.capture(.thought) }
        ]
    }

    private var quickActions: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
            ForEach(actions) { a in
                Button(action: a.action) {
                    VStack(spacing: 6) {
                        Image(systemName: a.symbol)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(a.tint)
                            .frame(width: 52, height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Theme.surface)
                                    .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
                            )
                        Text(a.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(a.title)
            }
        }
    }

    // MARK: Inspiration

    private var showInspiration: Bool {
        inspirationEnabled && Date().timeIntervalSince1970 > hideInspirationUntil
    }

    private var inspirationCard: some View {
        let item = InspirationService.today()
        return HydroCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack {
                    Label(item.isPrompt ? "Reflection" : "Inspiration", systemImage: item.isPrompt ? "leaf" : "quote.opening")
                        .font(Typo.eyebrow)
                        .foregroundStyle(Brand.sunlitGold)
                    Spacer()
                    Button {
                        hideInspirationUntil = (Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()).timeIntervalSince1970
                    } label: {
                        Image(systemName: "xmark").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                    }
                    .accessibilityLabel("Hide for today")
                }
                Text(item.text)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                if let source = item.source {
                    Text("— \(source)").font(Typo.caption).foregroundStyle(.white.opacity(0.8))
                }
                if item.isPrompt {
                    Button {
                        router.open(PromptEntryRoute(prompt: item.text), in: .journal)
                    } label: {
                        Label("Write about it", systemImage: "square.and.pencil")
                            .font(Typo.callout.weight(.semibold))
                            .foregroundStyle(Brand.warmIvory)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: Today

    private var todayTasks: [TaskItem] {
        tasks.filter { t in
                if t.isDone { return t.completedAt.map(Calendar.current.isDateInToday) ?? false }
                guard let due = t.dueDate else { return true }
                return due < Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
            }
            .sorted { a, b in
                if a.isDone != b.isDone { return !a.isDone }
                return a.priorityRaw > b.priorityRaw
            }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Today", subtitle: todayTasks.isEmpty ? nil : "\(todayTasks.filter { !$0.isDone }.count) open",
                          actionTitle: "All tasks") { router.open(AppModule.tasks) }
            VStack(spacing: 0) {
                ForEach(todayTasks.prefix(6)) { task in
                    TaskRow(task: task)
                    Divider().padding(.leading, 36)
                }
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle").foregroundStyle(Theme.accent)
                    TextField("Add a task for today", text: $newTaskTitle)
                        .focused($taskFieldFocused)
                        .submitLabel(.done)
                        .onSubmit(addTask)
                    if !newTaskTitle.isEmpty {
                        Button("Add", action: addTask).font(Typo.callout.weight(.semibold))
                    }
                }
                .padding(.vertical, 10)
            }
            .cardStyle(padding: Theme.Spacing.m)
        }
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        context.insert(TaskItem(title: title, dueDate: Calendar.current.startOfDay(for: Date())))
        try? context.save()
        newTaskTitle = ""
        router.showToast("Task added")
    }

    // MARK: Upcoming

    private struct Upcoming: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let date: Date
        let symbol: String
        let tint: Color
    }

    private var upcoming: [Upcoming] {
        let horizon = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        let today = Calendar.current.startOfDay(for: Date())
        var items: [Upcoming] = []
        for e in events where e.date >= today && e.date <= horizon {
            items.append(Upcoming(id: "e\(e.id)", title: e.title, subtitle: e.kind.label, date: e.date, symbol: e.kind.symbol, tint: Theme.accent))
        }
        for p in people {
            if let b = p.birthday, let next = DateMath.nextOccurrence(of: b, repeatsYearly: true), next <= horizon {
                items.append(Upcoming(id: "b\(p.id)", title: "\(p.name)'s birthday", subtitle: "Birthday", date: next, symbol: "gift", tint: Theme.gold))
            }
        }
        for d in importantDates {
            if let next = d.nextOccurrence, next <= horizon {
                let who = d.person.map { " · \($0.name)" } ?? ""
                items.append(Upcoming(id: "d\(d.id)", title: d.title + who, subtitle: d.kind.label, date: next, symbol: d.kind.symbol, tint: Theme.earth))
            }
        }
        for t in trips where t.isUpcoming && t.startDate <= horizon.addingTimeInterval(60 * 86400) {
            items.append(Upcoming(id: "t\(t.id)", title: t.title, subtitle: "Trip", date: t.startDate, symbol: "airplane", tint: Theme.accent))
        }
        for r in reminders where r.isEnabled {
            if let next = r.nextFire, next <= horizon {
                items.append(Upcoming(id: "r\(r.id)", title: r.title, subtitle: "Reminder", date: next, symbol: "bell", tint: Theme.jungle))
            }
        }
        return items.sorted { $0.date < $1.date }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Coming up", subtitle: "Next 30 days", actionTitle: "Events") { router.open(AppModule.events) }
            if upcoming.isEmpty {
                Text("Nothing scheduled. Add events, birthdays or trips and they'll appear here.")
                    .font(Typo.callout).foregroundStyle(Theme.textSecondary).cardStyle()
            } else {
                VStack(spacing: Theme.Spacing.s) {
                    ForEach(upcoming.prefix(5)) { item in
                        HStack(spacing: Theme.Spacing.m) {
                            IconBadge(symbol: item.symbol, tint: item.tint, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(Typo.body).foregroundStyle(Theme.textPrimary).lineLimit(1)
                                Text(item.subtitle).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Text(DateMath.relativeDayText(item.date))
                                .font(Typo.caption.weight(.semibold))
                                .foregroundStyle(DateMath.daysUntil(item.date) <= 1 ? Theme.accent : Theme.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .cardStyle()
            }
        }
    }

    // MARK: Goals

    @ViewBuilder
    private var goalsSection: some View {
        let active = goals.filter { !$0.isCompleted }.prefix(3)
        let activeProjects = projects.filter { $0.status == .inProgress || $0.status == .planning }.prefix(2)
        if !active.isEmpty || !activeProjects.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(title: "Your goals")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.m) {
                        ForEach(Array(active)) { g in
                            NavigationLink(value: g) {
                                goalCard(title: g.skillName, subtitle: g.category.label, progress: g.progress, symbol: g.category.symbol)
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(Array(activeProjects)) { p in
                            NavigationLink(value: p) {
                                goalCard(title: p.name, subtitle: p.status.label, progress: p.progress, symbol: p.status.symbol)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func goalCard(title: String, subtitle: String, progress: Double, symbol: String) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            ProgressRing(progress: progress).frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Typo.headline).foregroundStyle(Theme.textPrimary).lineLimit(2)
                Label(subtitle, systemImage: symbol).font(Typo.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: 230, alignment: .leading)
        .cardStyle(padding: Theme.Spacing.m)
    }

    // MARK: Continue

    @ViewBuilder
    private var continueSection: some View {
        let items = resolvedRecents
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(title: "Continue where you left off")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.m) {
                        ForEach(items) { resolved in
                            let recent = resolved.item
                            Button { resolved.open() } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Image(systemName: symbol(for: recent.kind)).foregroundStyle(Theme.accent)
                                    Text(recent.title).font(Typo.callout.weight(.medium)).foregroundStyle(Theme.textPrimary).lineLimit(2)
                                    Text(recent.openedAt.formatted(.relative(presentation: .named)))
                                        .font(Typo.caption).foregroundStyle(Theme.textTertiary)
                                }
                                .frame(width: 150, height: 96, alignment: .topLeading)
                                .cardStyle(padding: Theme.Spacing.m)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    /// Resolves recent ids to live objects (deleted items disappear automatically).
    private struct ResolvedRecent: Identifiable {
        let item: RecentItem
        let open: () -> Void
        var id: String { item.id }
    }

    private var resolvedRecents: [ResolvedRecent] {
        recents.items.prefix(8).compactMap { r in
            switch r.kind {
            case .journal:
                guard let e = entries.first(where: { $0.id == r.itemID }) else { return nil }
                return ResolvedRecent(item: r, open: { router.open(e) })
            case .project:
                guard let p = projects.first(where: { $0.id == r.itemID }) else { return nil }
                return ResolvedRecent(item: r, open: { router.open(p) })
            case .trip:
                guard let t = recentTrips.first(where: { $0.id == r.itemID }) else { return nil }
                return ResolvedRecent(item: r, open: { router.open(t) })
            case .goal:
                guard let g = goals.first(where: { $0.id == r.itemID }) else { return nil }
                return ResolvedRecent(item: r, open: { router.open(g) })
            case .person:
                guard let p = people.first(where: { $0.id == r.itemID }) else { return nil }
                return ResolvedRecent(item: r, open: { router.open(p) })
            case .memory:
                guard let m = memories.first(where: { $0.id == r.itemID }) else { return nil }
                return ResolvedRecent(item: r, open: { router.open(m) })
            }
        }
    }

    private func symbol(for kind: RecentItem.Kind) -> String {
        switch kind {
        case .journal: "book.closed"
        case .project: "paintbrush.pointed"
        case .trip: "airplane"
        case .goal: "graduationcap"
        case .person: "person"
        case .memory: "sparkles"
        }
    }

    // MARK: Journal

    private var recentJournal: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "From your journal", actionTitle: "Open") { router.selectedTab = .journal }
            let onThisDay = JournalStore.onThisDay(entries)
            if let memory = onThisDay.first {
                NavigationLink(value: memory) {
                    HStack(spacing: Theme.Spacing.m) {
                        IconBadge(symbol: "clock.arrow.circlepath", tint: Theme.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("On this day, \(memory.date.formatted(.dateTime.year()))")
                                .font(Typo.eyebrow).foregroundStyle(Theme.gold)
                            Text(memory.displayTitle).font(Typo.headline).foregroundStyle(Theme.textPrimary).lineLimit(1)
                        }
                        Spacer()
                    }
                    .cardStyle()
                }
                .buttonStyle(.plain)
            }
            if entries.isEmpty {
                Button { router.newJournalEntry = true } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Begin your first page").font(Typo.title3).foregroundStyle(Theme.textPrimary)
                        Text(InspirationService.prompt().text).font(Typo.callout).foregroundStyle(Theme.textSecondary)
                    }
                    .cardStyle()
                }
                .buttonStyle(.plain)
            } else {
                ForEach(entries.prefix(3)) { e in
                    NavigationLink(value: e) { JournalEntryCard(entry: e) }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Modules

    private var modulesGrid: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Your world")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach([AppModule.learn, .people, .vitality, .memoryVault, .timeline, .yearbook, .tasks, .search]) { m in
                    NavigationLink(value: m) {
                        HStack(spacing: 10) {
                            IconBadge(symbol: m.symbol, tint: m.tint, size: 36)
                            Text(m.title).font(Typo.callout.weight(.medium)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Spacer(minLength: 0)
                        }
                        .cardStyle(padding: Theme.Spacing.m)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Opens the editor with a reflection prompt pre-filled.
struct PromptEntryRoute: Hashable { let prompt: String }
struct NewPersonRoute: Hashable { let id = UUID() }
struct StudySessionRoute: Hashable { let goalID: UUID? }
