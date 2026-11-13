import Foundation

/// Dispatch for Chapters 4–8 (filled in chapter by chapter).
extension StoryDirector {
    func laterFlag(_ f: String) {
        ch4Flag(f)
        ch5Flag(f)
        facilityFlag(f)
    }
    func laterEvent(_ e: String) -> Bool { facilityEvent(e) }
    func laterTick() {}
    func laterDesktopEntered() {
        ch4DesktopEntered()
    }
    func laterPageVisited(_ url: String) {
        if url == "lumen-ai.com" { session.set("visited_lumen_site") }
        ch5PageVisited(url)
    }
    func laterLumenSuggestions() -> [(String, String)] { ch5LumenSuggestions() }
    func chapterTalk() {
        switch session.day {
        case 4: start("ch4_confront")
        case 5, 6: start("ch5_idle")
        default: start("ch3_idle_gen")
        }
    }

    func laptopPrompt() -> String? { ch5LaptopPrompt() }
    func useLaptop() { ch5UseLaptop() }
}

extension StoryDirector {
    /// Drift visited a page.
    func pageVisited(_ url: String) {
        laterPageVisited(url)
    }
}
