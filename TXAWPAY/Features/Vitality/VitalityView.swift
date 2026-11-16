import SwiftUI
import SwiftData

/// Wellbeing and routines. Success is measured in consistency, rest and how
/// you feel — there is deliberately no weight or calorie tracking here.
struct VitalityView: View {
    enum VitalityTab: String, CaseIterable, Identifiable { case today = "Today", workouts = "Workouts", library = "Library", journal = "Rest & notes"; var id: String { rawValue } }

    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @Query(sort: \WellbeingLog.date, order: .reverse) private var logs: [WellbeingLog]
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Environment(\.modelContext) private var context
    @State private var tab: VitalityTab = .today
    @State private var newWorkout = false
    @State private var newTemplate = false
    @State private var newRoutine = false
    @State private var editingRoutine: Routine?
    @State private var newLog: WellbeingKind?
    @State private var newExercise = false

    private var library: [Exercise] { allExercises.filter { $0.isLibraryItem && $0.workout == nil } }
    private var history: [Workout] { workouts.filter { !$0.isTemplate } }
    private var templates: [Workout] { workouts.filter(\.isTemplate) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Picker("Section", selection: $tab) { ForEach(VitalityTab.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented)
                switch tab {
                case .today: today
                case .workouts: workoutsTab
                case .library: libraryTab
                case .journal: restTab
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("Vitality")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { newWorkout = true } label: { Label("Log workout", systemImage: "figure.run") }
                    Button { newTemplate = true } label: { Label("Plan a workout", systemImage: "calendar.badge.plus") }
                    Button { newRoutine = true } label: { Label("New routine", systemImage: "sun.horizon") }
                    Button { newLog = .sleep } label: { Label("Sleep note", systemImage: "bed.double") }
                    Button { newLog = .recovery } label: { Label("Recovery note", systemImage: "leaf") }
                    Button { newExercise = true } label: { Label("Add to exercise library", systemImage: "books.vertical") }
                } label: { Image(systemName: "plus") }
                .accessibilityLabel("Add")
            }
        }
        .sheet(isPresented: $newWorkout) { NavigationStack { WorkoutEditor(workout: nil, isTemplate: false) } }
        .sheet(isPresented: $newTemplate) { NavigationStack { WorkoutEditor(workout: nil, isTemplate: true) } }
        .sheet(isPresented: $newRoutine) { RoutineEditor(routine: nil) }
        .sheet(item: $editingRoutine) { RoutineEditor(routine: $0) }
        .sheet(item: $newLog) { WellbeingLogEditor(kind: $0) }
        .sheet(isPresented: $newExercise) { ExerciseLibraryEditor() }
    }

    // MARK: Today

    private var todayHydration: WellbeingLog? {
        logs.first { $0.kind == .hydration && Calendar.current.isDateInToday($0.date) }
    }

    private var today: some View {
        let cal = Calendar.current
        let monthStart = DateMath.startOfMonth(Date())
        let monthCount = history.filter { $0.isCompleted && $0.date >= monthStart }.count
        let weekday = cal.component(.weekday, from: Date())
        let planned = templates.filter { $0.scheduledWeekdays.contains(weekday) }
        let lastSleep = logs.first { $0.kind == .sleep }

        return VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack(spacing: Theme.Spacing.s) {
                StatTile(value: "\(monthCount)", label: "Sessions this month", symbol: "figure.walk", tint: Theme.jungle)
                StatTile(value: lastSleep.map { String(format: "%.1f h", $0.value) } ?? "—", label: "Last sleep", symbol: "bed.double", tint: Color(hex: 0x6F6A9A))
            }

            // Hydration: tap to add a glass. A gentle count, not a quota.
            HStack {
                IconBadge(symbol: "drop.fill", tint: Theme.accent)
                VStack(alignment: .leading) {
                    Text("Water today").font(Typo.headline).foregroundStyle(Theme.textPrimary)
                    Text("\(Int(todayHydration?.value ?? 0)) glasses").font(Typo.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button { adjustWater(-1) } label: { Image(systemName: "minus.circle").font(.title2) }
                    .disabled((todayHydration?.value ?? 0) <= 0)
                    .accessibilityLabel("Remove a glass")
                Button { adjustWater(1) } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                    .accessibilityLabel("Add a glass")
            }
            .cardStyle()

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(title: "Planned for today")
                if planned.isEmpty {
                    Text("Nothing planned. Rest days count too.").font(Typo.callout).foregroundStyle(Theme.textSecondary)
                }
                ForEach(planned) { t in
                    HStack {
                        NavigationLink(value: t) { NavRow(symbol: "figure.strengthtraining.traditional", title: t.name, subtitle: "\((t.exercises ?? []).count) exercises", tint: Theme.jungle) }
                            .buttonStyle(.plain)
                        Spacer()
                        Button("Done") { logFromTemplate(t) }.buttonStyle(SecondaryButtonStyle())
                    }
                }
            }
            .cardStyle()

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(title: "Routines", actionTitle: "New") { newRoutine = true }
                if routines.isEmpty {
                    Text("Morning stretches, evening wind-down — small rituals that hold a day together.")
                        .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                }
                ForEach(routines.filter(\.isActive)) { r in
                    HStack(alignment: .top) {
                        Button {
                            r.lastCompleted = r.completedToday ? nil : Date()
                            try? context.save()
                        } label: {
                            Image(systemName: r.completedToday ? "checkmark.circle.fill" : "circle").font(.title3)
                                .foregroundStyle(r.completedToday ? Theme.jungle : Theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(r.completedToday ? "Mark routine not done" : "Mark routine done")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name).foregroundStyle(Theme.textPrimary)
                            Text("\(r.timeOfDay) · \(r.steps.joined(separator: " · "))").font(Typo.caption).foregroundStyle(Theme.textSecondary).lineLimit(2)
                        }
                        Spacer()
                        Button { editingRoutine = r } label: { Image(systemName: "pencil") }.buttonStyle(.plain).foregroundStyle(Theme.textTertiary)
                            .accessibilityLabel("Edit routine")
                    }
                }
            }
            .cardStyle()

            milestones
        }
    }

    /// Encouraging, non-punitive milestones based on totals only (no streak breaking).
    private var milestones: some View {
        let total = history.filter(\.isCompleted).count
        let thresholds = [1, 5, 10, 25, 50, 100, 250]
        let reached = thresholds.filter { total >= $0 }
        let next = thresholds.first { total < $0 }
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Milestones")
            if reached.isEmpty {
                Text("Your first logged session will appear here.").font(Typo.callout).foregroundStyle(Theme.textSecondary)
            } else {
                FlowLayout {
                    ForEach(reached, id: \.self) { n in Chip(text: "\(n) session\(n == 1 ? "" : "s")", symbol: "rosette", color: Theme.gold) }
                }
            }
            if let next { Text("\(next - total) more to reach \(next).").font(Typo.caption).foregroundStyle(Theme.textTertiary) }
        }
        .cardStyle()
    }

    private func adjustWater(_ delta: Double) {
        if let log = todayHydration {
            log.value = max(0, log.value + delta)
        } else if delta > 0 {
            context.insert(WellbeingLog(kind: .hydration, value: delta))
        }
        try? context.save()
    }

    private func logFromTemplate(_ t: Workout) {
        let w = Workout(name: t.name, date: Date())
        w.isCompleted = true
        w.durationMinutes = t.durationMinutes
        context.insert(w)
        for e in t.sortedExercises {
            let copy = Exercise(name: e.name, sets: e.sets, reps: e.reps, durationSeconds: e.durationSeconds)
            copy.sortOrder = e.sortOrder; copy.notes = e.notes
            context.insert(copy); copy.workout = w
        }
        try? context.save()
    }

    // MARK: Workouts

    private var workoutsTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(title: "Schedule", subtitle: "Planned workouts", actionTitle: "Plan") { newTemplate = true }
                if templates.isEmpty { Text("Plan workouts for specific weekdays.").font(Typo.callout).foregroundStyle(Theme.textSecondary) }
                ForEach(templates) { t in
                    NavigationLink(value: t) {
                        NavRow(symbol: "calendar", title: t.name, subtitle: weekdayText(t.scheduledWeekdays), tint: Theme.jungle)
                    }
                    .buttonStyle(.plain)
                }
            }
            .cardStyle()
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(title: "History", actionTitle: "Log") { newWorkout = true }
                if history.isEmpty {
                    EmptyStateView(symbol: "figure.run", title: "No workouts logged", message: "Walks, yoga, climbing, lifting — every kind of movement counts.")
                }
                ForEach(history) { w in
                    NavigationLink(value: w) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(w.name).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                                Text("\(w.date.formatted(date: .abbreviated, time: .omitted))\(w.durationMinutes > 0 ? " · \(DateMath.minutesText(w.durationMinutes))" : "") · \((w.exercises ?? []).count) exercises")
                                    .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if w.isCompleted { Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.jungle) }
                        }
                        .cardStyle(padding: Theme.Spacing.m)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func weekdayText(_ days: [Int]) -> String {
        guard !days.isEmpty else { return "Not scheduled" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return days.sorted().compactMap { (1...7).contains($0) ? symbols[$0 - 1] : nil }.joined(separator: ", ")
    }

    // MARK: Library

    private var libraryTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Exercise library", actionTitle: "Add") { newExercise = true }
            if library.isEmpty {
                Text("Save exercises you like so you can add them to workouts quickly.").font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
            ForEach(library) { e in
                HStack {
                    VStack(alignment: .leading) {
                        Text(e.name).foregroundStyle(Theme.textPrimary)
                        Text([e.focusArea, e.summaryLine].filter { !$0.isEmpty }.joined(separator: " · ")).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Button(role: .destructive) { context.delete(e); try? context.save() } label: { Image(systemName: "trash") }
                        .buttonStyle(.plain).foregroundStyle(Theme.textTertiary)
                        .accessibilityLabel("Delete \(e.name)")
                }
                .cardStyle(padding: Theme.Spacing.m)
            }
        }
    }

    // MARK: Rest & notes

    private var restTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack {
                ForEach([WellbeingKind.sleep, .recovery, .activity]) { k in
                    Button { newLog = k } label: { Label(k.label, systemImage: k.symbol) }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            let entries = logs.filter { $0.kind != .hydration }
            if entries.isEmpty {
                EmptyStateView(symbol: "moon.stars", title: "Rest is part of it", message: "Note how you slept, how your body is recovering, and the activity you enjoyed.")
            }
            ForEach(entries) { l in
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    IconBadge(symbol: l.kind.symbol, tint: l.kind == .sleep ? Color(hex: 0x6F6A9A) : Theme.jungle, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(l.kind.label).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                            if l.value > 0 { Text(String(format: "%.1f %@", l.value, l.kind.unit)).foregroundStyle(Theme.textSecondary) }
                            if l.quality > 0 { Text(String(repeating: "★", count: l.quality)).foregroundStyle(Theme.gold).font(.caption) }
                        }
                        Text(l.date.formatted(date: .abbreviated, time: .omitted)).font(Typo.caption).foregroundStyle(Theme.textTertiary)
                        if !l.notes.isEmpty { Text(l.notes).font(Typo.callout).foregroundStyle(Theme.textSecondary) }
                    }
                    Spacer()
                }
                .cardStyle(padding: Theme.Spacing.m)
                .contextMenu { Button(role: .destructive) { context.delete(l); try? context.save() } label: { Label("Delete", systemImage: "trash") } }
            }
        }
    }
}


struct WorkoutDetailView: View {
    @Bindable var workout: Workout
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(workout.name).font(Typo.title)
                    Text(workout.isTemplate ? "Planned workout" : workout.date.formatted(date: .complete, time: .shortened))
                        .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                    if workout.durationMinutes > 0 { Label(DateMath.minutesText(workout.durationMinutes), systemImage: "clock") }
                }
                if !workout.isTemplate {
                    Toggle("Completed", isOn: $workout.isCompleted).onChange(of: workout.isCompleted) { _, _ in try? context.save() }
                }
            }
            Section("Exercises") {
                if (workout.exercises ?? []).isEmpty { Text("No exercises added.").foregroundStyle(Theme.textSecondary) }
                ForEach(workout.sortedExercises) { e in
                    VStack(alignment: .leading) {
                        Text(e.name)
                        if !e.summaryLine.isEmpty { Text(e.summaryLine).font(Typo.caption).foregroundStyle(Theme.textSecondary) }
                        if !e.notes.isEmpty { Text(e.notes).font(Typo.caption).foregroundStyle(Theme.textTertiary) }
                    }
                }
            }
            if !workout.notes.isEmpty { Section("Notes") { Text(workout.notes) } }
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $editing) { NavigationStack { WorkoutEditor(workout: workout, isTemplate: workout.isTemplate) } }
        .confirmationDialog("Delete this workout?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                context.delete(workout); try? context.save()
                Task { await NotificationService.shared.refreshAll(context: context) }
                dismiss()
            }
        }
    }
}

struct WorkoutEditor: View {
    let workout: Workout?
    let isTemplate: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    struct DraftExercise: Identifiable {
        var id = UUID()
        var name = ""
        var sets = 3
        var reps = 10
        var seconds = 0
        var notes = ""
    }

    @State private var name = ""
    @State private var date = Date()
    @State private var minutes = 30
    @State private var notes = ""
    @State private var completed = true
    @State private var weekdays: Set<Int> = []
    @State private var remind = false
    @State private var drafts: [DraftExercise] = []

    private var library: [Exercise] { allExercises.filter { $0.isLibraryItem && $0.workout == nil } }

    var body: some View {
        Form {
            Section {
                TextField("Workout name", text: $name)
                if isTemplate {
                    VStack(alignment: .leading) {
                        Text("Days").font(Typo.caption).foregroundStyle(Theme.textSecondary)
                        HStack {
                            ForEach(1...7, id: \.self) { d in
                                let symbol = Calendar.current.veryShortWeekdaySymbols[d - 1]
                                Button {
                                    if weekdays.contains(d) { weekdays.remove(d) } else { weekdays.insert(d) }
                                } label: {
                                    Text(symbol).frame(width: 32, height: 32)
                                        .background(Circle().fill(weekdays.contains(d) ? Theme.accent : Theme.accentSoft))
                                        .foregroundStyle(weekdays.contains(d) ? Color.white : Theme.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Toggle("Remind me on these days", isOn: $remind)
                } else {
                    DatePicker("Date", selection: $date)
                    Toggle("Completed", isOn: $completed)
                }
                Stepper("Duration: \(DateMath.minutesText(minutes))", value: $minutes, in: 0...600, step: 5)
            }
            Section("Exercises") {
                ForEach($drafts) { $d in
                    VStack(alignment: .leading) {
                        TextField("Exercise", text: $d.name)
                        Stepper("Sets: \(d.sets)", value: $d.sets, in: 0...50)
                        Stepper("Reps: \(d.reps)", value: $d.reps, in: 0...500)
                        Stepper("Duration: \(d.seconds == 0 ? "—" : DateMath.durationText(seconds: d.seconds))", value: $d.seconds, in: 0...7200, step: 15)
                        TextField("Notes", text: $d.notes)
                    }
                }
                .onDelete { drafts.remove(atOffsets: $0) }
                Button { drafts.append(DraftExercise()) } label: { Label("Add exercise", systemImage: "plus") }
                if !library.isEmpty {
                    Menu {
                        ForEach(library) { e in
                            Button(e.name) { drafts.append(DraftExercise(name: e.name, sets: e.sets, reps: e.reps, seconds: e.durationSeconds, notes: e.notes)) }
                        }
                    } label: { Label("Add from library", systemImage: "books.vertical") }
                }
            }
            Section("Notes") { TextField("How did it feel?", text: $notes, axis: .vertical).lineLimit(2...6) }
        }
        .navigationTitle(isTemplate ? "Planned workout" : (workout == nil ? "Log workout" : "Edit workout"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
        }
        .onAppear {
            guard let workout else { return }
            name = workout.name; date = workout.date; minutes = workout.durationMinutes; notes = workout.notes
            completed = workout.isCompleted; weekdays = Set(workout.scheduledWeekdays); remind = workout.reminderEnabled
            drafts = workout.sortedExercises.map { DraftExercise(name: $0.name, sets: $0.sets, reps: $0.reps, seconds: $0.durationSeconds, notes: $0.notes) }
        }
    }

    private func save() {
        let w = workout ?? Workout(name: "", date: date, isTemplate: isTemplate)
        w.name = name.trimmingCharacters(in: .whitespaces); w.date = date; w.durationMinutes = minutes; w.notes = notes
        w.isCompleted = isTemplate ? false : completed
        w.scheduledWeekdays = weekdays.sorted(); w.reminderEnabled = isTemplate && remind
        if workout == nil { context.insert(w) }
        for old in w.exercises ?? [] { context.delete(old) }
        for (i, d) in drafts.enumerated() where !d.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let e = Exercise(name: d.name.trimmingCharacters(in: .whitespaces), sets: d.sets, reps: d.reps, durationSeconds: d.seconds)
            e.notes = d.notes; e.sortOrder = i; e.date = date
            context.insert(e); e.workout = w
        }
        try? context.save()
        Task {
            if w.reminderEnabled { await NotificationService.shared.requestPermission() }
            await NotificationService.shared.refreshAll(context: context)
        }
        dismiss()
    }
}

struct ExerciseLibraryEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var focus = ""
    @State private var sets = 3
    @State private var reps = 10
    @State private var seconds = 0
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Exercise name", text: $name)
                TextField("Focus (e.g. mobility, legs, core)", text: $focus)
                Stepper("Default sets: \(sets)", value: $sets, in: 0...50)
                Stepper("Default reps: \(reps)", value: $reps, in: 0...500)
                Stepper("Duration: \(seconds == 0 ? "—" : DateMath.durationText(seconds: seconds))", value: $seconds, in: 0...7200, step: 15)
                TextField("Technique notes", text: $notes, axis: .vertical)
            }
            .navigationTitle("Library exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let e = Exercise(name: name.trimmingCharacters(in: .whitespaces), sets: sets, reps: reps, durationSeconds: seconds)
                        e.isLibraryItem = true; e.focusArea = focus; e.notes = notes
                        context.insert(e); try? context.save(); dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct RoutineEditor: View {
    let routine: Routine?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var steps: [String] = [""]
    @State private var timeOfDay = "Morning"
    @State private var active = true

    var body: some View {
        NavigationStack {
            Form {
                TextField("Routine name", text: $name)
                Picker("Time of day", selection: $timeOfDay) {
                    ForEach(["Morning", "Midday", "Evening", "Anytime"], id: \.self) { Text($0) }
                }
                Section("Steps") {
                    ForEach(steps.indices, id: \.self) { i in TextField("Step \(i + 1)", text: $steps[i]) }
                    Button { steps.append("") } label: { Label("Add step", systemImage: "plus") }
                }
                Toggle("Show on Today", isOn: $active)
                if let routine {
                    Button("Delete routine", role: .destructive) { context.delete(routine); try? context.save(); dismiss() }
                }
            }
            .navigationTitle(routine == nil ? "New routine" : "Edit routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let r = routine ?? Routine(name: "")
                        r.name = name.trimmingCharacters(in: .whitespaces)
                        r.steps = steps.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        r.timeOfDay = timeOfDay; r.isActive = active
                        if routine == nil { context.insert(r) }
                        try? context.save(); dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let routine else { return }
                name = routine.name; steps = routine.steps.isEmpty ? [""] : routine.steps; timeOfDay = routine.timeOfDay; active = routine.isActive
            }
        }
    }
}

struct WellbeingLogEditor: View {
    let kind: WellbeingKind
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var value = 7.5
    @State private var quality = 3
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                switch kind {
                case .sleep:
                    Stepper(String(format: "Hours slept: %.1f", value), value: $value, in: 0...16, step: 0.5)
                    Picker("How rested do you feel?", selection: $quality) { ForEach(1...5, id: \.self) { Text(String(repeating: "★", count: $0)).tag($0) } }
                case .activity:
                    Stepper("Minutes: \(Int(value))", value: $value, in: 0...600, step: 5)
                case .recovery, .hydration:
                    Picker("How does your body feel?", selection: $quality) { ForEach(1...5, id: \.self) { Text(String(repeating: "★", count: $0)).tag($0) } }
                }
                TextField(kind == .sleep ? "Dreams, how you woke up…" : "Notes", text: $notes, axis: .vertical).lineLimit(3...10)
            }
            .navigationTitle(kind.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let log = WellbeingLog(kind: kind, value: kind == .recovery ? 0 : value, date: date)
                        log.quality = kind == .activity ? 0 : quality
                        log.notes = notes
                        context.insert(log); try? context.save(); dismiss()
                    }
                }
            }
            .onAppear { if kind == .activity { value = 30 } }
        }
    }
}
