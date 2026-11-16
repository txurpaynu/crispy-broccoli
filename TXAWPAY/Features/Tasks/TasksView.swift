import SwiftUI
import SwiftData

struct TasksView: View {
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @Environment(\.modelContext) private var context
    @State private var editing: TaskItem?
    @State private var creating = false
    @State private var showCompleted = false

    private var open: [TaskItem] {
        tasks.filter { !$0.isDone }.sorted {
            ($0.dueDate ?? .distantFuture, -$0.priorityRaw) < ($1.dueDate ?? .distantFuture, -$1.priorityRaw)
        }
    }
    private var done: [TaskItem] { tasks.filter(\.isDone).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) } }

    var body: some View {
        List {
            if tasks.isEmpty {
                EmptyStateView(symbol: "checklist", title: "No tasks", message: "Small steps keep the current moving. Add something you'd like to do.",
                               actionTitle: "Add task") { creating = true }
                    .listRowBackground(Color.clear)
            }
            if !open.isEmpty {
                Section("To do") {
                    ForEach(open) { t in
                        TaskRow(task: t).contentShape(Rectangle()).onTapGesture { editing = t }
                    }
                    .onDelete { idx in delete(idx.map { open[$0] }) }
                }
            }
            if !done.isEmpty {
                Section {
                    DisclosureGroup("Completed (\(done.count))", isExpanded: $showCompleted) {
                        ForEach(done) { t in TaskRow(task: t) }
                            .onDelete { idx in delete(idx.map { done[$0] }) }
                    }
                }
            }
        }
        .screenBackground()
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }.accessibilityLabel("New task")
            }
        }
        .sheet(isPresented: $creating) { TaskEditor(task: nil) }
        .sheet(item: $editing) { TaskEditor(task: $0) }
    }

    private func delete(_ items: [TaskItem]) {
        for t in items { context.delete(t) }
        try? context.save()
        Task { await NotificationService.shared.refreshAll(context: context) }
    }
}

struct TaskRow: View {
    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    task.isDone.toggle()
                    task.completedAt = task.isDone ? Date() : nil
                    try? context.save()
                }
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isDone ? Theme.jungle : (task.priority == .high ? Theme.gold : Theme.textTertiary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isDone ? "Mark as not done" : "Mark as done")

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? Theme.textTertiary : Theme.textPrimary)
                if let due = task.dueDate {
                    Text(task.hasDueTime ? due.formatted(date: .abbreviated, time: .shortened) : DateMath.relativeDayText(due))
                        .font(Typo.caption)
                        .foregroundStyle(task.isOverdue ? Theme.danger : Theme.textSecondary)
                }
            }
            Spacer()
            if task.reminderEnabled { Image(systemName: "bell").font(.caption).foregroundStyle(Theme.textTertiary) }
        }
        .padding(.vertical, 6)
    }
}

struct TaskEditor: View {
    let task: TaskItem?
    var presetTitle: String = ""
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var hasDue = false
    @State private var due = Date()
    @State private var hasTime = false
    @State private var priority = TaskPriority.normal
    @State private var remind = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What needs doing?", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical).lineLimit(1...5)
                }
                Section {
                    Toggle("Due date", isOn: $hasDue)
                    if hasDue {
                        Toggle("Specific time", isOn: $hasTime)
                        DatePicker("Due", selection: $due, displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date])
                        Toggle("Remind me", isOn: $remind)
                    }
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases) { Text($0.label).tag($0) }
                    }
                }
                if task != nil {
                    Section {
                        Button("Delete task", role: .destructive) {
                            if let task { context.delete(task); try? context.save() }
                            Task { await NotificationService.shared.refreshAll(context: context) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(task == nil ? "New task" : "Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let task {
                    title = task.title; notes = task.notes; hasDue = task.dueDate != nil; due = task.dueDate ?? Date()
                    hasTime = task.hasDueTime; priority = task.priority; remind = task.reminderEnabled
                } else { title = presetTitle }
            }
        }
    }

    private func save() {
        let t = task ?? TaskItem(title: "")
        t.title = title.trimmingCharacters(in: .whitespaces)
        t.notes = notes
        t.dueDate = hasDue ? (hasTime ? due : Calendar.current.startOfDay(for: due)) : nil
        t.hasDueTime = hasDue && hasTime
        t.priority = priority
        t.reminderEnabled = hasDue && remind
        if task == nil { context.insert(t) }
        try? context.save()
        Task {
            if t.reminderEnabled { await NotificationService.shared.requestPermission() }
            await NotificationService.shared.refreshAll(context: context)
        }
        dismiss()
    }
}

// MARK: - Events & reminders

struct EventsView: View {
    @Query(sort: \LifeEvent.date) private var events: [LifeEvent]
    @Query(sort: \Reminder.fireDate) private var reminders: [Reminder]
    @Environment(\.modelContext) private var context
    @State private var editingEvent: LifeEvent?
    @State private var newEvent = false
    @State private var editingReminder: Reminder?
    @State private var newReminder = false

    var body: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let upcoming = events.filter { $0.date >= today }
        let past = events.filter { $0.date < today }.reversed()
        List {
            Section("Upcoming events") {
                if upcoming.isEmpty { Text("No upcoming events.").foregroundStyle(Theme.textSecondary) }
                ForEach(upcoming) { e in eventRow(e) }
                    .onDelete { idx in for i in idx { context.delete(upcoming[i]) }; save() }
            }
            Section("Reminders") {
                if reminders.isEmpty { Text("No custom reminders.").foregroundStyle(Theme.textSecondary) }
                ForEach(reminders) { r in
                    Button { editingReminder = r } label: {
                        HStack {
                            Image(systemName: r.isEnabled ? "bell.fill" : "bell.slash").foregroundStyle(Theme.accent)
                            VStack(alignment: .leading) {
                                Text(r.title).foregroundStyle(Theme.textPrimary)
                                Text("\(r.repeats.label) · \(r.fireDate.formatted(date: r.repeats == .daily ? .omitted : .abbreviated, time: .shortened))")
                                    .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
                .onDelete { idx in for i in idx { context.delete(reminders[i]) }; save() }
            }
            if !past.isEmpty {
                Section("Past events") {
                    ForEach(Array(past)) { e in eventRow(e) }
                }
            }
        }
        .screenBackground()
        .navigationTitle("Events & Reminders")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { newEvent = true } label: { Label("New event", systemImage: "calendar.badge.plus") }
                    Button { newReminder = true } label: { Label("New reminder", systemImage: "bell.badge") }
                } label: { Image(systemName: "plus") }
                .accessibilityLabel("Add")
            }
        }
        .sheet(isPresented: $newEvent) { LifeEventEditor(event: nil) }
        .sheet(item: $editingEvent) { LifeEventEditor(event: $0) }
        .sheet(isPresented: $newReminder) { ReminderEditor(reminder: nil) }
        .sheet(item: $editingReminder) { ReminderEditor(reminder: $0) }
    }

    private func eventRow(_ e: LifeEvent) -> some View {
        Button { editingEvent = e } label: {
            HStack {
                IconBadge(symbol: e.kind.symbol, tint: Theme.accent, size: 34)
                VStack(alignment: .leading) {
                    Text(e.title).foregroundStyle(Theme.textPrimary)
                    Text(e.date.formatted(date: .abbreviated, time: .shortened)).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func save() {
        try? context.save()
        Task { await NotificationService.shared.refreshAll(context: context) }
    }
}

struct LifeEventEditor: View {
    let event: LifeEvent?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var date = Date()
    @State private var kind = LifeEventKind.event
    @State private var notes = ""
    @State private var remind = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                DatePicker("Date", selection: $date)
                Picker("Type", selection: $kind) { ForEach(LifeEventKind.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) } }
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...6)
                if date > Date() { Toggle("Remind me", isOn: $remind) }
                if let event {
                    Button("Delete event", role: .destructive) {
                        context.delete(event); try? context.save()
                        Task { await NotificationService.shared.refreshAll(context: context) }
                        dismiss()
                    }
                }
            }
            .navigationTitle(event == nil ? "New event" : "Edit event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let e = event ?? LifeEvent(title: "", date: date)
                        e.title = title.trimmingCharacters(in: .whitespaces); e.date = date; e.kind = kind; e.notes = notes
                        e.reminderEnabled = remind && date > Date()
                        if event == nil { context.insert(e) }
                        try? context.save()
                        Task {
                            if e.reminderEnabled { await NotificationService.shared.requestPermission() }
                            await NotificationService.shared.refreshAll(context: context)
                        }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let event { title = event.title; date = event.date; kind = event.kind; notes = event.notes; remind = event.reminderEnabled }
            }
        }
    }
}

struct ReminderEditor: View {
    let reminder: Reminder?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var message = ""
    @State private var date = Date().addingTimeInterval(3600)
    @State private var repeats = ReminderRepeat.none
    @State private var enabled = true

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Message (optional)", text: $message)
                DatePicker("When", selection: $date)
                Picker("Repeat", selection: $repeats) { ForEach(ReminderRepeat.allCases) { Text($0.label).tag($0) } }
                Toggle("Enabled", isOn: $enabled)
                if repeats == .none && date < Date() {
                    ValidationHint(message: "This time is in the past, so it won't notify.")
                }
                if let reminder {
                    Button("Delete reminder", role: .destructive) {
                        context.delete(reminder); try? context.save()
                        Task { await NotificationService.shared.refreshAll(context: context) }
                        dismiss()
                    }
                }
            }
            .navigationTitle(reminder == nil ? "New reminder" : "Edit reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let r = reminder ?? Reminder(title: "", fireDate: date)
                        r.title = title.trimmingCharacters(in: .whitespaces); r.message = message; r.fireDate = date
                        r.repeats = repeats; r.isEnabled = enabled
                        if reminder == nil { context.insert(r) }
                        try? context.save()
                        Task {
                            await NotificationService.shared.requestPermission()
                            await NotificationService.shared.refreshAll(context: context)
                        }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let reminder { title = reminder.title; message = reminder.message; date = reminder.fireDate; repeats = reminder.repeats; enabled = reminder.isEnabled }
            }
        }
    }
}
