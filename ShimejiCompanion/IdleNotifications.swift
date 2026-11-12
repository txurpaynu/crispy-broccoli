import Foundation
import UserNotifications

@MainActor
enum IdleNotifications {
    static let preferenceKey = "vexleyIdleNotificationsEnabled"
    private static let requestID = "vexley.bored.checkin"
    private static let randomThoughtPrefix = "vexley.random-thought."

    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [requestID])
    }



    /// Pre-schedule one gentle thought at a random daytime time for each of the next seven days.
    /// iOS delivers these locally; the app does not need to run in the background.
    static func scheduleRandomThoughts(name: String) {
        guard UserDefaults.standard.bool(forKey: "vexleyRandomThoughtsEnabled") else {
            cancelRandomThoughts()
            return
        }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else { return }

            center.getPendingNotificationRequests { requests in
                let oldIDs = requests
                    .map(\\.identifier)
                    .filter { $0.hasPrefix(randomThoughtPrefix) }
                center.removePendingNotificationRequests(withIdentifiers: oldIDs)

                guard UserDefaults.standard.bool(forKey: "vexleyRandomThoughtsEnabled") else { return }
                let thoughts = [
                    "Quick question: would you explore a hidden cave or a haunted game level?",
                    "I found a weird old-game memory. Want to hear it sometime?",
                    "Tiny thought: clouds look like the sky's loading screen.",
                    "If you spot a good snack today, tell me what it tastes like.",
                    "I made up a new side quest: find one interesting thing outside.",
                    "Got a strange fact for me? I'm collecting them."
                ]

                for dayOffset in 0..<7 {
                    guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }
                    var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
                    components.hour = Int.random(in: 10...21)
                    components.minute = Int.random(in: 0...59)
                    guard let fireDate = Calendar.current.date(from: components), fireDate > Date() else { continue }

                    let content = UNMutableNotificationContent()
                    content.title = name
                    content.body = thoughts.randomElement() ?? "Tell me something interesting when you have a moment."
                    content.sound = .default
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let request = UNNotificationRequest(
                        identifier: "\\(randomThoughtPrefix)\\(UUID().uuidString)",
                        content: content,
                        trigger: trigger
                    )
                    center.add(request)
                }
            }
        }
    }

    static func cancelRandomThoughts() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\\.identifier)
                .filter { $0.hasPrefix(randomThoughtPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// Queue one playful check-in for two hours after the app goes into the background.
    /// Returning to the app cancels it; it is never repeated automatically.
    static func schedule(name: String) {
        guard UserDefaults.standard.bool(forKey: preferenceKey) else { return }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else { return }

            let lines = [
                "I'm bored. Come bother me for a minute?",
                "It's awfully quiet in here. Got anything weird to tell me?",
                "I have been dramatically staring at the wall. Please provide a distraction.",
                "Is it snack time yet? I have lost track of everything.",
                "Hey, when you're free, I could use a little company."
            ]
            let content = UNMutableNotificationContent()
            content.title = name
            content.body = lines.randomElement() ?? "I'm bored. Come say hi?"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2 * 60 * 60, repeats: false)
            let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
            center.add(request)
        }
    }
}
