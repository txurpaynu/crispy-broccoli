import Foundation
import UserNotifications
import SwiftData

/// Local notifications only. Nothing is scheduled unless the user turns the
/// matching reminder on, and the whole schedule is rebuilt from the data, so
/// deleted items never leave stale notifications behind.
///
/// iOS allows 64 pending local notifications per app; `refreshAll` keeps the
/// soonest ones within that budget.
@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()
    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let budget = 60

    func updateStatus() async {
        authorization = await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestPermission() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await updateStatus()
        return granted
    }

    private struct Pending {
        var id: String
        var title: String
        var body: String
        var components: DateComponents
        var repeats: Bool
        var sortDate: Date
    }

    /// Rebuilds every scheduled notification from the current data and settings.
    func refreshAll(context: ModelContext) async {
        await updateStatus()
        guard authorization == .authorized || authorization == .provisional || authorization == .ephemeral else { return }
        let d = UserDefaults.standard
        let cal = Calendar.current
        var items: [Pending] = []
        let now = Date()

        // Journal reminder (daily).
        if d.bool(forKey: AppSettings.Keys.journalReminderEnabled) {
            let secs = d.double(forKey: AppSettings.Keys.journalReminderTime)
            items.append(Pending(id: "journal.daily", title: "A moment for your journal",
                                 body: "How was today? A few lines are enough.",
                                 components: DateComponents(hour: Int(secs) / 3600, minute: (Int(secs) % 3600) / 60),
                                 repeats: true, sortDate: now))
        }

        // Hydration (daily, between start and end hour).
        if d.bool(forKey: AppSettings.Keys.hydrationRemindersEnabled) {
            let start = d.integer(forKey: AppSettings.Keys.hydrationStartHour)
            let end = d.integer(forKey: AppSettings.Keys.hydrationEndHour)
            let step = max(1, d.integer(forKey: AppSettings.Keys.hydrationIntervalHours))
            for hour in stride(from: start, through: max(start, end), by: step) {
                items.append(Pending(id: "hydration.\(hour)", title: "Water break", body: "A glass of water keeps the current flowing.",
                                     components: DateComponents(hour: hour, minute: 0), repeats: true, sortDate: now))
            }
        }

        // Tasks with a due date and reminder enabled.
        if d.bool(forKey: AppSettings.Keys.notifyTasks) {
            let tasks = (try? context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.reminderEnabled && !$0.isDone }))) ?? []
            for t in tasks {
                guard let due = t.dueDate else { continue }
                let fire = t.hasDueTime ? due : (cal.date(bySettingHour: 9, minute: 0, second: 0, of: due) ?? due)
                guard fire > now else { continue }
                items.append(Pending(id: "task.\(t.id)", title: "Task", body: t.title,
                                     components: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire),
                                     repeats: false, sortDate: fire))
            }
        }

        // Birthdays and important dates (yearly at 9:00).
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        if d.bool(forKey: AppSettings.Keys.notifyBirthdays) {
            for p in people where p.birthdayReminder {
                guard let b = p.birthday, let next = DateMath.nextOccurrence(of: b, repeatsYearly: true) else { continue }
                var c = cal.dateComponents([.month, .day], from: b); c.hour = 9
                items.append(Pending(id: "birthday.\(p.id)", title: "Birthday", body: "It's \(p.name)'s birthday today.",
                                     components: c, repeats: true, sortDate: next))
            }
        }
        if d.bool(forKey: AppSettings.Keys.notifyEvents) {
            let dates = (try? context.fetch(FetchDescriptor<ImportantDate>(predicate: #Predicate { $0.remind }))) ?? []
            for item in dates {
                guard let next = item.nextOccurrence else { continue }
                var c = item.repeatsYearly ? cal.dateComponents([.month, .day], from: item.date)
                                           : cal.dateComponents([.year, .month, .day], from: item.date)
                c.hour = 9
                let who = item.person.map { " · \($0.name)" } ?? ""
                items.append(Pending(id: "date.\(item.id)", title: item.kind.label, body: item.title + who,
                                     components: c, repeats: item.repeatsYearly, sortDate: next))
            }
            let events = (try? context.fetch(FetchDescriptor<LifeEvent>(predicate: #Predicate { $0.reminderEnabled }))) ?? []
            for e in events where e.date > now {
                items.append(Pending(id: "event.\(e.id)", title: "Upcoming", body: e.title,
                                     components: cal.dateComponents([.year, .month, .day, .hour, .minute], from: e.date),
                                     repeats: false, sortDate: e.date))
            }
            let reminders = (try? context.fetch(FetchDescriptor<Reminder>(predicate: #Predicate { $0.isEnabled }))) ?? []
            for r in reminders {
                guard let next = r.nextFire else { continue }
                let comps: DateComponents
                switch r.repeats {
                case .none: comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: r.fireDate)
                case .daily: comps = cal.dateComponents([.hour, .minute], from: r.fireDate)
                case .weekly: comps = cal.dateComponents([.weekday, .hour, .minute], from: r.fireDate)
                case .yearly: comps = cal.dateComponents([.month, .day, .hour, .minute], from: r.fireDate)
                }
                items.append(Pending(id: "reminder.\(r.id)", title: r.title, body: r.message,
                                     components: comps, repeats: r.repeats != .none, sortDate: next))
            }
        }

        // Learning goals: a gentle weekly nudge on the goal's start weekday.
        if d.bool(forKey: AppSettings.Keys.notifyLearning) {
            let goals = (try? context.fetch(FetchDescriptor<LearningGoal>(predicate: #Predicate { $0.reminderEnabled && !$0.isCompleted }))) ?? []
            let secs = d.double(forKey: AppSettings.Keys.learningReminderTime)
            for g in goals {
                var c = DateComponents(hour: Int(secs) / 3600, minute: (Int(secs) % 3600) / 60)
                c.weekday = cal.component(.weekday, from: g.startDate)
                items.append(Pending(id: "learning.\(g.id)", title: "Learning time", body: "A little time for \(g.skillName)?",
                                     components: c, repeats: true, sortDate: now))
            }
        }

        // Scheduled workouts (weekly, 8:00 on chosen weekdays).
        if d.bool(forKey: AppSettings.Keys.notifyWorkouts) {
            let workouts = (try? context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.reminderEnabled && $0.isTemplate }))) ?? []
            for w in workouts {
                for day in w.scheduledWeekdays {
                    items.append(Pending(id: "workout.\(w.id).\(day)", title: "Movement", body: "\(w.name) is on today's plan.",
                                         components: DateComponents(hour: 8, minute: 0, weekday: day), repeats: true, sortDate: now))
                }
            }
        }

        center.removeAllPendingNotificationRequests()
        for item in items.sorted(by: { $0.sortDate < $1.sortDate }).prefix(budget) {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: item.components, repeats: item.repeats)
            try? await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }
}
