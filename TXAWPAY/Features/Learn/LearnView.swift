import SwiftUI
import SwiftData
import Charts

struct LearnView: View {
    @Query(sort: \LearningGoal.createdAt, order: .reverse) private var goals: [LearningGoal]
    @Query(sort: \StudySession.date, order: .reverse) private var sessions: [StudySession]
    @EnvironmentObject private var router: AppRouter
    @State private var creating = false
    @State private var showCompleted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                summary
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    SectionHeader(title: "Goals", actionTitle: "New goal") { creating = true }
                    let active = goals.filter { !$0.isCompleted }
                    if goals.isEmpty {
                        EmptyStateView(symbol: "graduationcap", title: "What would you like to learn?",
                                       message: "A language, an instrument, a programming skill — set a gentle goal and log your sessions.",
                                       actionTitle: "Create a goal") { creating = true }
                    }
                    ForEach(active) { g in NavigationLink(value: g) { GoalRow(goal: g) }.buttonStyle(.plain) }
                    let done = goals.filter(\.isCompleted)
                    if !done.isEmpty {
                        DisclosureGroup("Completed (\(done.count))", isExpanded: $showCompleted) {
                            ForEach(done) { g in NavigationLink(value: g) { GoalRow(goal: g) }.buttonStyle(.plain) }
                        }
                        .tint(Theme.textSecondary)
                    }
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    SectionHeader(title: "Recent sessions", actionTitle: "Log session") { router.open(StudySessionRoute(goalID: nil)) }
                    if sessions.isEmpty {
                        Text("No study sessions yet.").font(Typo.callout).foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(sessions.prefix(10)) { s in SessionRow(session: s) }
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("Learn")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.open(StudySessionRoute(goalID: nil)) } label: { Image(systemName: "timer") }
                    .accessibilityLabel("Log study session")
            }
        }
        .sheet(isPresented: $creating) { NavigationStack { LearningGoalEditor(goal: nil) } }
    }

    /// Weekly and monthly totals plus a 7-day chart. No streaks, no pressure.
    private var summary: some View {
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let monthStart = DateMath.startOfMonth(Date())
        let week = sessions.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.durationMinutes }
        let month = sessions.filter { $0.date >= monthStart }.reduce(0) { $0 + $1.durationMinutes }
        let days: [DayTotal] = (0..<7).reversed().map { offset in
            let day = cal.startOfDay(for: cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date())
            let total = sessions.filter { cal.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.durationMinutes }
            return DayTotal(day: day, minutes: total)
        }
        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.s) {
                StatTile(value: DateMath.minutesText(week), label: "This week", symbol: "calendar")
                StatTile(value: DateMath.minutesText(month), label: "This month", symbol: "calendar.badge.clock", tint: Theme.gold)
            }
            if sessions.contains(where: { $0.date >= cal.date(byAdding: .day, value: -7, to: Date())! }) {
                Chart(days) { item in
                    BarMark(x: .value("Day", item.day, unit: .day), y: .value("Minutes", item.minutes))
                        .foregroundStyle(Theme.accent.gradient)
                        .cornerRadius(6)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
                .frame(height: 140)
                .cardStyle()
                .accessibilityLabel("Study minutes over the last seven days")
            }
        }
    }
}

struct GoalRow: View {
    let goal: LearningGoal
    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ProgressRing(progress: goal.progress, tint: goal.isCompleted ? Theme.jungle : Theme.accent).frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(goal.skillName).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                Label(goal.category.label, systemImage: goal.category.symbol).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                Text("\(DateMath.minutesText(goal.totalMinutes)) studied\(goal.targetDate.map { " · target \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "")")
                    .font(Typo.caption).foregroundStyle(Theme.textTertiary)
            }
            Spacer()
        }
        .cardStyle(padding: Theme.Spacing.m)
    }
}

struct SessionRow: View {
    let session: StudySession
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            IconBadge(symbol: session.goal?.category.symbol ?? "book", tint: Color(hex: 0x6F6A9A), size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.subject.isEmpty ? (session.goal?.skillName ?? "Study session") : session.subject)
                    .font(Typo.body).foregroundStyle(Theme.textPrimary)
                Text("\(session.date.formatted(date: .abbreviated, time: .omitted)) · \(DateMath.minutesText(session.durationMinutes))")
                    .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                if !session.learned.isEmpty { Text(session.learned).font(Typo.caption).foregroundStyle(Theme.textTertiary).lineLimit(2) }
            }
            Spacer()
        }
        .cardStyle(padding: Theme.Spacing.m)
    }
}

struct LearningGoalDetailView: View {
    @Bindable var goal: LearningGoal
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var editingSession: StudySession?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    HStack(spacing: Theme.Spacing.l) {
                        ProgressRing(progress: goal.progress, lineWidth: 8).frame(width: 84, height: 84)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(goal.skillName).font(Typo.title).foregroundStyle(Theme.textPrimary)
                            Label(goal.category.label, systemImage: goal.category.symbol).foregroundStyle(Theme.textSecondary)
                            Text(DateMath.minutesText(goal.totalMinutes) + " in \((goal.sessions ?? []).count) sessions")
                                .font(Typo.caption).foregroundStyle(Theme.textTertiary)
                        }
                    }
                    if !goal.summary.isEmpty { Text(goal.summary).font(Typo.bodySerif) }
                    VStack(alignment: .leading) {
                        Text("Progress").font(Typo.eyebrow).foregroundStyle(Theme.textSecondary)
                        Slider(value: $goal.progress, in: 0...1, step: 0.05) { Text("Progress") }
                            .onChange(of: goal.progress) { _, _ in try? context.save() }
                    }
                    Toggle(isOn: Binding(get: { goal.isCompleted }, set: { done in
                        goal.isCompleted = done
                        goal.completedAt = done ? Date() : nil
                        if done { goal.progress = 1 }
                        try? context.save()
                        if done { router.showToast("Goal completed — well done", symbol: "checkmark.seal.fill") }
                    })) { Label("Completed", systemImage: "checkmark.seal") }
                }
                .padding(.vertical, 4)
            }
            Section("Dates") {
                LabeledContent("Started", value: goal.startDate.formatted(date: .abbreviated, time: .omitted))
                if let t = goal.targetDate { LabeledContent("Target", value: t.formatted(date: .abbreviated, time: .omitted)) }
            }
            if !goal.notes.isEmpty { Section("Notes") { Text(goal.notes) } }
            if !goal.resources.isEmpty { Section("Resources") { Text(goal.resources) } }
            Section {
                Button { router.open(StudySessionRoute(goalID: goal.id)) } label: { Label("Log a session", systemImage: "plus") }
                ForEach(goal.sortedSessions) { s in
                    Button { editingSession = s } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(s.date.formatted(date: .abbreviated, time: .omitted)) · \(DateMath.minutesText(s.durationMinutes))")
                                .foregroundStyle(Theme.textPrimary)
                            if !s.subject.isEmpty { Text(s.subject).font(Typo.caption).foregroundStyle(Theme.textSecondary) }
                            if !s.learned.isEmpty { Text("Learned: \(s.learned)").font(Typo.caption).foregroundStyle(Theme.textSecondary) }
                            if !s.nextSteps.isEmpty { Text("Next: \(s.nextSteps)").font(Typo.caption).foregroundStyle(Theme.textTertiary) }
                        }
                    }
                }
                .onDelete { idx in
                    let list = goal.sortedSessions
                    for i in idx { context.delete(list[i]) }
                    try? context.save()
                }
            } header: { Text("Study sessions") }
        }
        .screenBackground()
        .navigationTitle(goal.skillName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { editing = true } label: { Label("Edit goal", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete goal", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $editing) { NavigationStack { LearningGoalEditor(goal: goal) } }
        .sheet(item: $editingSession) { s in NavigationStack { StudySessionEditor(goalID: s.goal?.id, session: s) } }
        .confirmationDialog("Delete this goal and its sessions?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                RecentsStore.shared.remove(id: goal.id)
                context.delete(goal); try? context.save(); dismiss()
            }
        }
        .onAppear { RecentsStore.shared.record(.goal, id: goal.id, title: goal.skillName) }
    }
}

struct LearningGoalEditor: View {
    let goal: LearningGoal?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var summary = ""
    @State private var category = LearningCategory.languages
    @State private var start = Date()
    @State private var hasTarget = false
    @State private var target = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var notes = ""
    @State private var resources = ""
    @State private var remind = false

    var body: some View {
        Form {
            Section {
                TextField("Skill (e.g. Korean, Swift, watercolour)", text: $name)
                TextField("Description", text: $summary, axis: .vertical).lineLimit(2...5)
                Picker("Category", selection: $category) { ForEach(LearningCategory.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) } }
            }
            Section {
                DatePicker("Start", selection: $start, displayedComponents: .date)
                Toggle("Target date", isOn: $hasTarget)
                if hasTarget { DatePicker("Target", selection: $target, in: start..., displayedComponents: .date) }
                Toggle("Weekly gentle reminder", isOn: $remind)
            }
            Section("Notes") { TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...8) }
            Section("Resources") { TextField("Books, courses, links", text: $resources, axis: .vertical).lineLimit(2...8) }
        }
        .navigationTitle(goal == nil ? "New goal" : "Edit goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let g = goal ?? LearningGoal(skillName: "")
                    g.skillName = name.trimmingCharacters(in: .whitespaces); g.summary = summary; g.category = category
                    g.startDate = start; g.targetDate = hasTarget ? target : nil; g.notes = notes; g.resources = resources
                    g.reminderEnabled = remind
                    if goal == nil { context.insert(g) }
                    try? context.save()
                    Task {
                        if remind { await NotificationService.shared.requestPermission() }
                        await NotificationService.shared.refreshAll(context: context)
                    }
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            guard let goal else { return }
            name = goal.skillName; summary = goal.summary; category = goal.category; start = goal.startDate
            hasTarget = goal.targetDate != nil; target = goal.targetDate ?? target; notes = goal.notes; resources = goal.resources
            remind = goal.reminderEnabled
        }
    }
}

/// Log or edit a study session. Works pushed or inside a sheet's NavigationStack.
struct StudySessionEditor: View {
    let goalID: UUID?
    let session: StudySession?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @Query(sort: \LearningGoal.skillName) private var goals: [LearningGoal]
    @State private var selectedGoal: UUID?
    @State private var subject = ""
    @State private var date = Date()
    @State private var minutes = 30
    @State private var notes = ""
    @State private var learned = ""
    @State private var next = ""

    var body: some View {
        Form {
            Section {
                Picker("Goal", selection: $selectedGoal) {
                    Text("No goal").tag(UUID?.none)
                    ForEach(goals.filter { !$0.isCompleted || $0.id == selectedGoal }) { Text($0.skillName).tag(UUID?.some($0.id)) }
                }
                TextField("Subject", text: $subject)
                DatePicker("Date", selection: $date)
                Stepper("Duration: \(DateMath.minutesText(minutes))", value: $minutes, in: 5...600, step: 5)
            }
            Section("What I learned") { TextField("Key takeaways", text: $learned, axis: .vertical).lineLimit(2...8) }
            Section("Next steps") { TextField("What's next", text: $next, axis: .vertical).lineLimit(1...6) }
            Section("Notes") { TextField("Notes", text: $notes, axis: .vertical).lineLimit(1...8) }
        }
        .navigationTitle(session == nil ? "Study session" : "Edit session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let s = session ?? StudySession(subject: "")
                    s.subject = subject.trimmingCharacters(in: .whitespaces); s.date = date; s.durationMinutes = minutes
                    s.notes = notes; s.learned = learned; s.nextSteps = next
                    if session == nil { context.insert(s) }
                    s.goal = goals.first { $0.id == selectedGoal }
                    try? context.save()
                    router.showToast("Session logged")
                    dismiss()
                }
                .disabled(subject.trimmingCharacters(in: .whitespaces).isEmpty && selectedGoal == nil)
            }
        }
        .onAppear {
            selectedGoal = goalID
            if let session {
                subject = session.subject; date = session.date; minutes = session.durationMinutes
                notes = session.notes; learned = session.learned; next = session.nextSteps
            }
        }
    }
}

struct DayTotal: Identifiable {
    let day: Date
    let minutes: Int
    var id: Date { day }
}
