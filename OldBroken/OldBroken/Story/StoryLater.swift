import Foundation

/// Dispatch for Chapters 4–8 (filled in chapter by chapter).
extension StoryDirector {
    func laterFlag(_ f: String) {
        ch4Flag(f)
    }
    func laterEvent(_ e: String) -> Bool { false }
    func laterTick() {}
    func laterDesktopEntered() {
        ch4DesktopEntered()
    }
    func laterPageVisited(_ url: String) {
        if url == "lumen-ai.com" { session.set("visited_lumen_site") }
    }
    func laterLumenSuggestions() -> [(String, String)] { [] }
    func chapterTalk() {
        switch session.day {
        case 4: start("ch4_confront")
        default: start("ch3_idle_gen")
        }
    }

    // Laptop (Chapter 5). Placeholder lines until then.
    func laptopPrompt() -> String? { "Laptop" }
    func useLaptop() { session.say("My old laptop. It still turns on, barely.") }
}

extension StoryDirector {
    /// Drift visited a page.
    func pageVisited(_ url: String) {
        laterPageVisited(url)
    }
}
