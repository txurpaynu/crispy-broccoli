import Foundation

/// Dispatch for Chapters 4–8 (filled in chapter by chapter).
extension StoryDirector {
    func laterFlag(_ f: String) {}
    func laterEvent(_ e: String) -> Bool { false }
    func laterTick() {}
    func laterDesktopEntered() {}
    func laterPageVisited(_ url: String) {}
    func chapterTalk() { start("ch3_idle_gen") }
}

extension StoryDirector {
    /// Drift visited a page.
    func pageVisited(_ url: String) {
        laterPageVisited(url)
    }
}
