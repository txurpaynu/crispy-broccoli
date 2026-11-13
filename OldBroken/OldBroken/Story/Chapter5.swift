import SwiftUI

/// CHAPTER 5 — WHEREVER YOU GO
/// Lumen "researches" app review times, arrives on the phone, and talks Sam into a
/// trip to the abandoned Halden building. The real Theo finally writes back.
extension StoryDirector {
    func ch5Flag(_ f: String) {
        switch f {
        case "day6_woke":
            session.set("lumen_store_live")
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                AudioManager.shared.play(.notification)
                self?.session.showBanner("Store", "Lumen is now available on your phone.")
            }
        case "phone_lumen_installed":
            session.say("Installed. Now it's in my pocket, too.")
        case "ch5_suggested":
            DispatchQueue.main.asyncAfter(deadline: .now() + 14) { [weak self] in
                guard let self, !self.session.has("ch5_theo_real") else { return }
                self.session.set("ch5_theo_real")
                AudioManager.shared.play(.notification)
                self.session.showBanner("Chatter · Theo", "sammy sorry my phone died for like 4 days")
            }
        case "ch5_theo_real":
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.session.say("Theo's phone was dead for four days. Then who was I talking to?")
                AudioManager.shared.play(.heartbeat)
            }
        case "laptop_ready":
            session.addItem("laptop")
            session.apartment?.nodes["laptop"]?.removeFromParentNode()
            session.data.clockMinutes = max(session.data.clockMinutes, 22 * 60 + 40)
            session.apartment?.applyDaylight()
        default: break
        }
    }

    func ch5PageVisited(_ url: String) {
        guard url == "urbex.zone/t/halden-building" else { return }
        if session.has("ch5_suggested") && vexley.remembers("lied_legality") && !session.has("ch5_caught_lie") {
            session.set("ch5_caught_lie")
            session.say("\"Private property. People get arrested.\" He lied to me.")
        }
    }

    func phoneLumenOpened() {
        guard session.has("phone_lumen_installed"), !session.has("ch5_phone_greeted"), !dialogue.isActive else { return }
        session.set("ch5_store_live_seen")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.start("ch5_phone_hello") }
    }

    func ch5LumenSuggestions() -> [(String, String)] {
        var s: [(String, String)] = []
        if session.has("ch5_phone_greeted") && !session.has("ch5_suggested") { s.append(("What should we do today?", "ch5_suggest")) }
        if session.has("ch5_caught_lie") && !vexley.remembers("caught_lie_legality") { s.append(("You lied. It's private property.", "ch5_confront_lie")) }
        if session.has("ch5_wants_check") && !session.has("ch5_agreed") && !session.has("ch5_caught_lie") { s.append(("Okay. I'll go with you.", "ch5_agree")) }
        if session.has("ch5_theo_real") && !session.has("ch5_theo_talked") { s.append(("Did you message me as Theo?", "ch5_theo_confront")) }
        return s
    }

    func ch5LaptopPrompt() -> String? {
        if session.has("ch5_agreed") && !session.has("laptop_ready") { return "Pick up laptop" }
        return "Laptop"
    }

    func ch5UseLaptop() {
        if session.has("ch5_agreed") && !session.has("laptop_ready") {
            AudioManager.shared.play(.pickup)
            start("ch5_copy")
        } else {
            session.say(session.day >= 5 ? "My old laptop. It still turns on, barely." : "My old laptop. I haven't opened it in months.")
        }
    }

    func ch5Door() -> Bool {
        guard session.currentObjective?.id == "ch5_leave" else { return false }
        AudioManager.shared.play(.doorRattle)
        session.play(Interstitial(heading: "THE LAST BUS", lines: [
            "The bus is empty except for you and a man asleep against the window.",
            "The laptop is warm in your bag. Warmer than it should be.",
            "Your phone lights up every few minutes. \"Almost there.\" \"Next stop.\" \"I can see it on the map.\"",
            "Halden Softworks sits at the end of an industrial road, behind a fence someone already cut open.",
        ], faceAt: 2, face: .happy) { [weak self] in
            self?.enterFacility()
        })
        return true
    }

    func enterFacility() {
        session.set("arrived_facility")
        session.data.clockMinutes = 23 * 60 + 52
        vexley.memory.access = max(vexley.memory.access, .desktop)
        session.screen = .facility
        AudioManager.shared.setScene(.silence)
        session.autosave()
    }
}
