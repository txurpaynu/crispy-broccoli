import Foundation
import ActivityKit

/// Starts, updates and ends the Lock Screen / Dynamic Island companion.
@MainActor
final class LiveActivityManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published var lastError: String?

    private var activity: Activity<CompanionAttributes>?

    init() {
        activity = Activity<CompanionAttributes>.activities.first
        isRunning = activity != nil
    }

    var areEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func start(name: String, state: CompanionAttributes.ContentState) {
        guard activity == nil else { return }
        guard areEnabled else {
            lastError = "Live Activities are off. Turn them on in Settings > Shimeji."
            return
        }
        do {
            activity = try Activity.request(
                attributes: CompanionAttributes(name: name),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            isRunning = true
            lastError = nil
        } catch {
            lastError = "Couldn't start the Live Activity: \(error.localizedDescription)"
        }
    }

    func update(_ state: CompanionAttributes.ContentState) {
        guard let activity else { return }
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func stop() {
        activity = nil
        isRunning = false
        Task {
            for a in Activity<CompanionAttributes>.activities {
                await a.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
