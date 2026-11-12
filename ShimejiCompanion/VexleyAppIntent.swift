import AppIntents
import UserNotifications

struct VexleySawAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Tell Vexley About an App"
    static var description = IntentDescription("Let Vexley know which app you just opened.")
    static var openAppWhenRun = false

    @Parameter(title: "App Name")
    var appName: String

    func perform() async throws -> some IntentResult {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else {
            return .result(dialog: "Turn on notifications in Shimeji settings so I can react.")
        }

        let content = UNMutableNotificationContent()
        content.title = "Vexley"
        content.body = "Oh, \(appName)? What are you getting up to in there?"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "vexley.app-open.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try await center.add(request)
        return .result(dialog: "I told Vexley you opened \(appName).")
    }
}
