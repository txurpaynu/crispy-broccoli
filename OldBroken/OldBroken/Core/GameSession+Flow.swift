import Foundation

/// Screen-to-screen flow: apartment <-> desktop, sleeping, the end of the slice.
extension GameSession {

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

}

/// Filled in by the computer simulation so GameSession doesn't depend on it directly.
@MainActor
enum DesktopHooks {
    static var onEnter: ((GameSession) -> Void)?
    static var onLeave: ((GameSession) -> Void)?
}

/// Filled in by the story layer (StoryDirector) so the core doesn't depend on it.
@MainActor
enum StoryHooks {
    static var onLoad: ((GameSession) -> Void)?
}
