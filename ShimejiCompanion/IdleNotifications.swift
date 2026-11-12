import Foundation
import UserNotifications

@MainActor
enum IdleNotifications {
    static let preferenceKey = "vexleyIdleNotificationsEnabled"
    private static let requestID = "vexley.bored.checkin"

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
