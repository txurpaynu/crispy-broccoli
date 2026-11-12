import SafariServices
import UserNotifications

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        guard
            let item = context.inputItems.first as? NSExtensionItem,
            let message = item.userInfo?[SFExtensionMessageKey] as? [String: Any],
            message["type"] as? String == "sharePage",
            let rawURL = message["url"] as? String,
            let host = URL(string: rawURL)?.host
        else {
            complete(context, ok: false, message: "I couldn't read this page.")
            return
        }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else {
                self.complete(context, ok: false, message: "Enable Shimeji notifications first.")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Vexley"
            content.body = "I noticed you were on \(host). What's that place like?"
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "vexley.safari.\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            center.add(request) { error in
                self.complete(
                    context,
                    ok: error == nil,
                    message: error == nil ? "Told Vexley about \(host)." : "Couldn't send that to Vexley."
                )
            }
        }
    }

    private func complete(_ context: NSExtensionContext, ok: Bool, message: String) {
        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: ["ok": ok, "message": message]]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
