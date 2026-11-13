import SwiftUI

/// CHAPTER 4 — EVERYONE KNOWS YOU
/// The TV turns itself on to a news story about LUMEN. "Theo" vouches for it.
/// Lumen asks you to pick a look, and only one look ever loads.
extension StoryDirector {
    var ch4Active: Bool { session.day == 4 }

    func ch4Flag(_ f: String) {
        switch f {
        case "day4_woke":
            session.set("tv_on")
            session.apartment?.setTV(true)
        case "ch4_probe_caps", "ch4_probe_sat":
            if !session.has("ch4_probed") {
                session.set("ch4_probed")
                vexley.remember("player_suspects_theo")
            }
        case "ch4_theo_r_caps":
            session.say("Theo hasn't used a capital letter since 2009.")
        case "ch4_theo_r_sat":
            session.say("\"The usual.\" We didn't do anything last Saturday. I was home. He was at his sister's.")
        case "ch4_theo_r1":
            session.say("That doesn't sound like Theo. ...But he does like new stuff.")
        case "ch4_maya_doubt":
            session.say("One clip and a website. Maya's not wrong.")
        case "ch4_theo_knew":
            session.say("\"I knew you would.\" How?")
            AudioManager.shared.play(.heartbeat)
        case "lumen_q_weather", "lumen_q_joke", "lumen_q_who", "lumen_q_vexley", "lumen_q_remind", "lumen_q_theo":
            let n = ["lumen_q_weather", "lumen_q_joke", "lumen_q_who", "lumen_q_vexley", "lumen_q_remind", "lumen_q_theo"].filter { session.has($0) }.count
            if n >= 3 && !session.has("ch4_used_lumen") {
                whenQuiet { [weak self] in
                    self?.session.set("ch4_used_lumen")
                    self?.session.data.clockMinutes = max(self?.session.data.clockMinutes ?? 0, 22 * 60 + 40)
                    self?.session.say("It's almost eleven. I've been talking to an app for hours.")
                }
            }
        default: break
        }
    }

    func sawNews() {
        guard !session.has("saw_lumen_news") else { return }
        session.set("saw_lumen_news")
        session.say("Lumen. Never heard of it. \"Everyone's talking about it.\"")
        session.say("I'll ask Theo. He always knows this stuff first.")
    }

    func ch4DesktopEntered() {
        guard session.day >= 4, !session.has("chatter_synced") else { return }
        session.set("chatter_synced")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.comp.notify(app: "Chatter", title: "Your phone is connected", body: "Messages will now sync to this PC.")
            self?.session.say("I never set that up.")
        }
    }

    func lumenChoseFox() {
        guard !session.has("lumen_fox") else { return }
        AudioManager.shared.play(.uiConfirm)
        session.set("lumen_fox")
        vexley.remember("player_chose_fox")
        vexley.adjustTrust(1)
        session.say("The fox one. Like Vexley.")
        session.say("...That's a coincidence. Right?")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.start("lumen_hello") }
    }

    /// What you can ask Lumen right now.
    func lumenSuggestions() -> [(String, String)] {
        var s: [(String, String)] = []
        if session.day >= 5 && !session.has("ch5_asked_mobile") { s.append(("Is there a phone app?", "ch5_mobile")) }
        if !session.has("lumen_q_weather") { s.append(("What's the weather?", "lumen_weather")) }
        if !session.has("lumen_q_joke") { s.append(("Tell me a joke", "lumen_joke")) }
        if !session.has("lumen_q_who") { s.append(("Who made you?", "lumen_who")) }
        if !session.has("lumen_q_vexley") {
            s.append(("Do you know Vexley?", vexley.memory.trust >= 3 ? "lumen_vexley_alt" : "lumen_vexley"))
        }
        if !session.has("lumen_q_remind") { s.append(("Remind me to sleep", "lumen_remind")) }
        if session.has("ch4_asked_theo") && !session.has("lumen_q_theo") { s.append(("Do you know my friend Theo?", "lumen_theo")) }
        s += laterLumenSuggestions()
        if s.isEmpty { s.append(("How are you?", "lumen_howareyou")) }
        return s
    }
}
