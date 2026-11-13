import Foundation

/// Screen-to-screen flow: apartment <-> desktop, sleeping, the end of the slice.
extension GameSession {
    var canSleep: Bool { has("av_scanned") && !has("slept") }

    func enterDesktop() {
        set("sat_at_pc")
        screen = .desktop
        AudioManager.shared.setScene(.desktop)
        DesktopHooks.onEnter?(self)
    }

    func leaveDesktop() {
        DesktopHooks.onLeave?(self)
        screen = .apartment
        AudioManager.shared.setScene(.apartment)
        apartment?.standUp()
        autosave()
    }

    func sleep() {
        set("slept")
        autosave()
        AudioManager.shared.setScene(.silence)
        screen = .endSlice
    }
}

/// Filled in by the computer simulation so GameSession doesn't depend on it directly.
@MainActor
enum DesktopHooks {
    static var onEnter: ((GameSession) -> Void)?
    static var onLeave: ((GameSession) -> Void)?
}
