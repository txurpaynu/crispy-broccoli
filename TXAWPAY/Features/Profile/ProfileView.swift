import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserSettings]
    @Query private var entries: [JournalEntry]
    @Query private var trips: [TravelTrip]
    @Query private var projects: [CreativeProject]
    @Query private var memories: [Memory]
    @EnvironmentObject private var backup: BackupManager
    @State private var editingProfile = false

    private var profile: UserSettings? { profiles.first }

    var body: some View {
        List {
            Section {
                VStack(spacing: Theme.Spacing.m) {
                    AvatarView(fileName: profile?.avatarFileName ?? "", initials: initials, size: 96)
                    Text(profile?.displayName.isEmpty == false ? profile!.displayName : "Your world")
                        .font(Typo.title)
                        .foregroundStyle(Theme.textPrimary)
                    if let bio = profile?.bio, !bio.isEmpty {
                        Text(bio).font(Typo.callout).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                    }
                    Button("Edit profile") { editingProfile = true }
                        .buttonStyle(SecondaryButtonStyle())
                    HStack(spacing: Theme.Spacing.s) {
                        miniStat("\(entries.filter { !$0.isDemo }.count)", "entries")
                        miniStat("\(trips.count)", "trips")
                        miniStat("\(projects.count)", "projects")
                        miniStat("\(memories.count)", "memories")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.s)
            }
            .listRowBackground(Color.clear)

            Section("Your data") {
                link(.backup, subtitle: backup.isEnabled ? backup.overallState.label : "Off")
                link(.restore)
                link(.exportData)
                link(.storage)
            }
            Section("Settings") {
                link(.settingsAppearance)
                link(.settingsNotifications)
                link(.settingsPrivacy)
            }
            Section("Your world") {
                link(.yearbook)
                link(.timeline)
                link(.memoryVault)
                link(.search)
            }
            Section {
                link(.about)
            }
        }
        .screenBackground()
        .navigationTitle("Profile")
        .sheet(isPresented: $editingProfile) {
            if let profile { ProfileEditor(profile: profile) }
        }
    }

    private var initials: String {
        let name = profile?.displayName ?? ""
        let parts = name.split(separator: " ").prefix(2).compactMap(\.first)
        return parts.isEmpty ? "T" : String(parts).uppercased()
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.headline, design: .rounded)).foregroundStyle(Theme.textPrimary)
            Text(label).font(Typo.caption).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.surface))
    }

    private func link(_ module: AppModule, subtitle: String? = nil) -> some View {
        NavigationLink(value: module) {
            NavRow(symbol: module.symbol, title: module.title, subtitle: subtitle, tint: module.tint)
        }
    }
}

struct ProfileEditor: View {
    @Bindable var profile: UserSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var bio = ""
    @State private var avatar = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        SinglePhotoPicker(fileName: $avatar) {
                            VStack {
                                AvatarView(fileName: avatar, initials: String(name.prefix(1)).uppercased(), size: 88)
                                Text("Choose photo").font(Typo.caption)
                            }
                        }
                        Spacer()
                    }
                    if !avatar.isEmpty {
                        Button("Remove photo", role: .destructive) { MediaStore.shared.delete(avatar); avatar = "" }
                    }
                }
                Section("Name") { TextField("Your name", text: $name).textContentType(.name) }
                Section("About you") { TextField("A line about you (optional)", text: $bio, axis: .vertical).lineLimit(2...5) }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        profile.displayName = name.trimmingCharacters(in: .whitespaces)
                        profile.bio = bio
                        profile.avatarFileName = avatar
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .onAppear { name = profile.displayName; bio = profile.bio; avatar = profile.avatarFileName }
        }
    }
}

// MARK: - Appearance

struct AppearanceSettingsView: View {
    @AppStorage(AppSettings.Keys.appearance) private var appearance = AppearanceMode.system.rawValue
    @AppStorage(AppSettings.Keys.inspirationEnabled) private var inspiration = true

    var body: some View {
        List {
            Section("Appearance") {
                ForEach(AppearanceMode.allCases) { mode in
                    Button { appearance = mode.rawValue } label: {
                        HStack {
                            Label(mode.label, systemImage: mode.symbol).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if appearance == mode.rawValue { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                        }
                    }
                }
            }
            Section {
                HStack(spacing: Theme.Spacing.m) {
                    preview(.light)
                    preview(.dark)
                }
                .listRowBackground(Color.clear)
            }
            Section {
                Toggle("Daily inspiration on Home", isOn: $inspiration)
            } footer: {
                Text("A quiet quote or reflection prompt. You can also hide it for the day from Home.")
            }
        }
        .screenBackground()
        .navigationTitle("Appearance")
    }

    private func preview(_ scheme: ColorScheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Good evening").font(Typo.title3).foregroundStyle(Theme.textPrimary)
            RoundedRectangle(cornerRadius: 8).fill(Theme.surface).frame(height: 30)
                .overlay(alignment: .leading) { Capsule().fill(Theme.accent).frame(width: 50, height: 8).padding(.leading, 8) }
            HStack { Circle().fill(Theme.gold).frame(width: 10); Circle().fill(Theme.jungle).frame(width: 10) }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.background))
        .environment(\.colorScheme, scheme)
        .accessibilityHidden(true)
    }
}

// MARK: - Notifications

struct NotificationSettingsView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var service = NotificationService.shared
    @AppStorage(AppSettings.Keys.journalReminderEnabled) private var journalOn = false
    @AppStorage(AppSettings.Keys.journalReminderTime) private var journalTime = 21 * 3600.0
    @AppStorage(AppSettings.Keys.hydrationRemindersEnabled) private var hydrationOn = false
    @AppStorage(AppSettings.Keys.hydrationStartHour) private var hStart = 9
    @AppStorage(AppSettings.Keys.hydrationEndHour) private var hEnd = 20
    @AppStorage(AppSettings.Keys.hydrationIntervalHours) private var hEvery = 2
    @AppStorage(AppSettings.Keys.notifyTasks) private var tasks = true
    @AppStorage(AppSettings.Keys.notifyBirthdays) private var birthdays = true
    @AppStorage(AppSettings.Keys.notifyEvents) private var events = true
    @AppStorage(AppSettings.Keys.notifyLearning) private var learning = true
    @AppStorage(AppSettings.Keys.notifyWorkouts) private var workouts = true
    @AppStorage(AppSettings.Keys.learningReminderTime) private var learningTime = 18 * 3600.0

    var body: some View {
        List {
            Section {
                switch service.authorization {
                case .authorized, .provisional, .ephemeral:
                    Label("Notifications are allowed", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.jungle)
                case .denied:
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Notifications are turned off for TXAWPAY", systemImage: "bell.slash")
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                default:
                    Button("Allow notifications") { Task { await service.requestPermission(); await refresh() } }
                }
            } footer: {
                Text("TXAWPAY only uses local notifications on this iPhone, never more than you turn on here.")
            }

            Section("Journal") {
                Toggle("Daily journal reminder", isOn: $journalOn)
                if journalOn { DatePicker("Time", selection: timeBinding($journalTime), displayedComponents: .hourAndMinute) }
            }
            Section("Wellbeing") {
                Toggle("Hydration reminders", isOn: $hydrationOn)
                if hydrationOn {
                    Stepper("From \(hStart):00", value: $hStart, in: 5...hEnd)
                    Stepper("Until \(hEnd):00", value: $hEnd, in: hStart...23)
                    Stepper("Every \(hEvery) h", value: $hEvery, in: 1...6)
                }
                Toggle("Scheduled workouts", isOn: $workouts)
            }
            Section {
                Toggle("Tasks with reminders", isOn: $tasks)
                Toggle("Birthdays", isOn: $birthdays)
                Toggle("Events and important dates", isOn: $events)
                Toggle("Learning goals", isOn: $learning)
                if learning { DatePicker("Learning nudge time", selection: timeBinding($learningTime), displayedComponents: .hourAndMinute) }
            } header: {
                Text("Reminders")
            } footer: {
                Text("Individual reminders are switched on per task, person, date, goal or workout.")
            }
        }
        .screenBackground()
        .navigationTitle("Notifications")
        .task { await service.updateStatus() }
        .onChange(of: [journalOn, hydrationOn, tasks, birthdays, events, learning, workouts]) { _, _ in Task { await refresh() } }
        .onChange(of: journalTime) { _, _ in Task { await refresh() } }
        .onChange(of: learningTime) { _, _ in Task { await refresh() } }
        .onChange(of: [hStart, hEnd, hEvery]) { _, _ in Task { await refresh() } }
    }

    private func refresh() async {
        if (journalOn || hydrationOn) && service.authorization == .notDetermined { await service.requestPermission() }
        await service.refreshAll(context: context)
    }

    private func timeBinding(_ seconds: Binding<Double>) -> Binding<Date> {
        Binding(get: {
            Calendar.current.startOfDay(for: Date()).addingTimeInterval(seconds.wrappedValue)
        }, set: { date in
            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
            seconds.wrappedValue = Double((c.hour ?? 0) * 3600 + (c.minute ?? 0) * 60)
        })
    }
}

// MARK: - Privacy

struct PrivacySettingsView: View {
    @EnvironmentObject private var lock: AppLock
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context
    @Environment(\.cloudKitActive) private var cloudKitActive
    @AppStorage(AppSettings.Keys.appLockEnabled) private var lockEnabled = false
    @AppStorage(AppSettings.Keys.lockOnBackgroundDelay) private var grace = 0
    @AppStorage(AppSettings.Keys.cloudSyncEnabled) private var cloudSync = false
    @AppStorage(AppSettings.Keys.demoModeActive) private var demoActive = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: Binding(get: { lockEnabled }, set: { newValue in
                    Task {
                        let ok = await lock.setEnabled(newValue)
                        if !ok, let e = lock.lastError { router.showToast(e, symbol: "lock.slash", isError: true) }
                    }
                })) {
                    Label("Lock with \(lock.biometryName)", systemImage: lock.biometrySymbol)
                }
                if lockEnabled {
                    Picker("Require unlock", selection: $grace) {
                        Text("Immediately").tag(0)
                        Text("After 1 minute").tag(60)
                        Text("After 5 minutes").tag(300)
                        Text("After 15 minutes").tag(900)
                    }
                }
            } header: {
                Text("App lock")
            } footer: {
                Text("If \(lock.biometryName) fails you can always use your device passcode. TXAWPAY also hides its content in the app switcher while locked.")
            }

            Section {
                Toggle("Sync with iCloud (CloudKit)", isOn: $cloudSync)
                HStack {
                    Text("Status")
                    Spacer()
                    Text(cloudKitActive ? "Active" : (cloudSync ? "Starts after relaunch" : "Off"))
                        .foregroundStyle(Theme.textSecondary)
                }
            } header: {
                Text("Sync")
            } footer: {
                Text("Optional. Syncs your TXAWPAY data through your private iCloud database so it appears on your other devices. Takes effect the next time TXAWPAY launches. Requires a build signed with the iCloud capability. Journal Markdown backups work independently of this setting.")
            }

            Section {
                Label("No account, no ads, no analytics, no tracking.", systemImage: "hand.raised")
                Label("Your data stays on your iPhone, plus only the iCloud or Files locations you choose.", systemImage: "iphone")
                Label("Journal text is never sent anywhere except your chosen backup folder.", systemImage: "lock.doc")
            } header: {
                Text("Your privacy")
            }
            .font(Typo.callout)

            Section {
                if demoActive {
                    Button("Remove demo content", role: .destructive) {
                        DemoData.remove(from: context)
                        router.showToast("Demo content removed")
                    }
                } else {
                    Button("Show demo content") {
                        DemoData.insert(into: context)
                        router.showToast("Demo content added (labelled DEMO)")
                    }
                }
            } header: {
                Text("Demo mode")
            } footer: {
                Text("Adds clearly labelled sample content so you can explore TXAWPAY. It is never included in backups or exports and can be removed with one tap.")
            }
        }
        .screenBackground()
        .navigationTitle("Privacy & Security")
    }
}

// MARK: - Storage

struct StorageView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter
    @State private var mediaSize: Int64 = 0
    @State private var storeSize: Int64 = 0
    @State private var localBackupSize: Int64 = 0
    @State private var counts: [(String, Int)] = []

    var body: some View {
        List {
            Section("On this iPhone") {
                row("Photos & videos", FileSizeCalculator.text(mediaSize))
                row("Database", FileSizeCalculator.text(storeSize))
                row("On-device backup folder", FileSizeCalculator.text(localBackupSize))
            }
            Section("Items") {
                ForEach(counts, id: \.0) { row($0.0, "\($0.1)") }
            }
            Section {
                Button("Clean up unused media files") {
                    let removed = MediaStore.shared.removeOrphans(keeping: referencedMedia())
                    router.showToast(removed == 0 ? "Nothing to clean up" : "Removed \(removed) unused files")
                    Task { await load() }
                }
            } footer: {
                Text("Removes photos and videos that no entry, memory, trip, project or person uses anymore.")
            }
        }
        .screenBackground()
        .navigationTitle("Storage")
        .task { await load() }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).foregroundStyle(Theme.textSecondary) }
    }

    private func referencedMedia() -> Set<String> {
        let bundle = DataExportService.makeBundle(context: context)
        var names = DataExportService.mediaFiles(in: bundle)
        // Demo items aren't exported but may reference media too.
        for a in (try? context.fetch(FetchDescriptor<JournalAttachment>())) ?? [] { names.insert(a.fileName) }
        return names
    }

    private func load() async {
        func count<T: PersistentModel>(_ t: T.Type) -> Int { (try? context.fetchCount(FetchDescriptor<T>())) ?? 0 }
        counts = [("Journal entries", count(JournalEntry.self)), ("Memories", count(Memory.self)), ("Trips", count(TravelTrip.self)),
                  ("Places", count(TravelDestination.self)), ("Projects", count(CreativeProject.self)), ("Learning goals", count(LearningGoal.self)),
                  ("People", count(Person.self)), ("Workouts", count(Workout.self)), ("Tasks", count(TaskItem.self))]
        let sizes = await Task.detached(priority: .utility) { () -> (Int64, Int64, Int64) in
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("TXAWPAY")
            let media = MediaStore.shared.totalSize()
            return (media, FileSizeCalculator.size(of: support) - media, FileSizeCalculator.size(of: docs))
        }.value
        mediaSize = sizes.0; storeSize = sizes.1; localBackupSize = sizes.2
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                AppMark(size: 120).padding(.top, Theme.Spacing.xl)
                Text("TXAWPAY").font(.system(.largeTitle, design: .serif).weight(.semibold)).tracking(6)
                    .foregroundStyle(Theme.textPrimary)
                Text("Your world, in one place.").font(Typo.bodySerif.italic()).foregroundStyle(Theme.textSecondary)
                GoldDivider().padding(.horizontal, 60)
                Text("A private home for your days, journeys, ideas, learning and the people you care about. Everything stays with you: no account, no server, no ads.")
                    .font(Typo.callout).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center).padding(.horizontal)
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                    .font(Typo.caption).foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .screenBackground()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
