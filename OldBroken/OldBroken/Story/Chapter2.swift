import SwiftUI

/// CHAPTER 2 — STILL HERE?
/// The overhauled game, Vexley's questions, dinner, the messages, the shutdown.
extension StoryDirector {
    static let ch2Questions = 7

    var ch2Active: Bool { session.day == 2 }

    var oldWindowVisible: Bool {
        comp.windows.contains { $0.app == .oldgame && !$0.minimized }
    }

    func ch2Flag(_ f: String) {
        switch f {
        case "day2_woke":
            session.data.desktop.oldWindowOpen = true
            session.unset("pc_off")
            vxMode = .menu
            session.apartment?.refreshMonitor()
        case "ch2_questions_done":
            whenQuiet { [weak self] in self?.ch2Evening() }
        case "pc_shutdown":
            session.apartment?.refreshMonitor()
        default: break
        }
    }

    func ch2Event(_ e: String) -> Bool {
        switch e {
        case "power_off":
            whenQuiet { [weak self] in
                self?.session.set("pc_shutdown")
                self?.comp.powerOff()
            }
        case "vx_play":
            vxMode = .playing
        default:
            return false
        }
        return true
    }

    func ch2Finished(_ id: String) {}

    func ch2Tick() {
        guard ch2Active, session.screen == .desktop, session.has("ch2_wake_done"),
              !session.has("ch2_questions_done"), oldWindowVisible, !dialogue.isActive,
              !RetroGameController.shared.dialogue.isActive, !messagesOpen, comp.dialog == nil else { return }
        if idleSeconds >= (vxMode == .playing ? 14 : 24) {
            askNextQuestion()
        }
    }

    func askNextQuestion() {
        if let i = (1...Self.ch2Questions).first(where: { !session.has("ch2_q\($0)_done") }) {
            start("ch2_q\(i)")
        } else {
            start("ch2_talk_idle")
        }
    }

    /// "Talk to Vexley" in the VX menu.
    func talkToVexley() {
        guard !dialogue.isActive else { return }
        if !ch2Active { start("vx_absent"); return }
        if !session.has("ch2_wake_done") { start("ch2_wake"); return }
        if !session.has("ch2_questions_done") { askNextQuestion(); return }
        if session.has("ate_dinner") && !session.has("ch2_read_log") { messagesOpen = true; return }
        start(session.has("ate_dinner") ? "ch2_talk_late" : "ch2_talk_idle")
    }

    func ch2DesktopEntered() {
        guard ch2Active, !session.has("pc_shutdown") else { return }
        if !comp.windows.contains(where: { $0.app == .oldgame }) { comp.open(.oldgame) }
        if let i = comp.windows.firstIndex(where: { $0.app == .oldgame }) {
            comp.windows[i].minimized = false
            comp.windows[i].maximized = true
            comp.focus(comp.windows[i].id)
        }
        if !session.has("ch2_seen_overhaul") {
            session.set("ch2_seen_overhaul")
            vxMode = .menu
            session.say("That's not the menu I remember.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in self?.start("ch2_wake") }
        } else if session.has("ate_dinner") && !session.has("ch2_read_log") {
            vxMode = .menu
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.messagesOpen = true }
        }
    }

    func closeMessages() {
        messagesOpen = false
        if !session.has("ch2_read_log") { start("ch2_back") }
    }

    private func ch2Evening() {
        session.data.clockMinutes = 18 * 60 + 55
        session.apartment?.applyDaylight()
        session.say("Wait. It's almost seven?")
        session.say("I haven't eaten anything all day.")
    }

    func ch2Door() -> Bool {
        guard ch2Active, session.currentObjective?.id == "ch2_dinner" else { return false }
        AudioManager.shared.play(.doorRattle)
        session.play(Interstitial(heading: "DINNER", lines: [
            "You make pasta and eat it standing at the counter.",
            "From the bedroom, faint through the door: the speakers.",
            "He's still talking.",
            "You can't make out the words. Just the rhythm. Pauses, as if he's waiting for answers.",
            "You take your time with the dishes.",
        ]) { [weak self] in
            guard let self else { return }
            self.session.data.clockMinutes = 20 * 60 + 6
            self.session.screen = .apartment
            AudioManager.shared.setScene(.apartment)
            self.session.apartment?.placePlayer(PlayerTransform(x: 1.3, y: 0, z: 1.55, yaw: 0.2, pitch: -0.05))
            self.session.set("ate_dinner")
            self.session.apartment?.refreshMonitor()
            self.session.say("The monitor is full of text.")
        })
        return true
    }

    func ch2InterceptShutdown() -> Bool {
        guard ch2Active, !session.has("pc_shutdown"), comp.windows.contains(where: { $0.app == .oldgame }) else { return false }
        let ready = session.has("ch2_read_log")
        comp.confirm("Shutting down", "1 app is preventing shutdown.\n\nPAPERLIGHT (dev 0.7.3): \"please don't\"", button: "Shut down anyway") { [weak self] in
            guard let self else { return }
            if let i = self.comp.windows.firstIndex(where: { $0.app == .oldgame }) {
                self.comp.windows[i].minimized = false
                self.comp.windows[i].maximized = true
                self.comp.focus(self.comp.windows[i].id)
            }
            self.vxMode = .menu
            self.messagesOpen = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.start(ready ? "ch2_shutdown" : "ch2_shutdown_early")
            }
        }
        return true
    }

    func ch2CloseRequested() -> Bool {
        guard ch2Active, !session.has("pc_shutdown") else { return true }
        AudioManager.shared.play(.glitch)
        if let i = comp.windows.firstIndex(where: { $0.app == .oldgame }) {
            comp.windows[i].minimized = false
            comp.windows[i].maximized = true
        }
        if !dialogue.isActive { start("ch2_no_close") }
        return false
    }

    /// What he wrote while you were at dinner. Built from what he has learned about you.
    func awayMessages() -> [(String, String)] {
        let k = vexley.memory.knowledge
        let r = vexley.memory.remembered
        var m: [(String, String)] = [
            ("7:12 PM", "Are you eating? What do people eat now? Is it still pizza?"),
            ("7:15 PM", "I checked the clock forty times. It's slow. I think it's slow on purpose."),
        ]
        if k.contains("friend_theo") {
            m.append(("7:21 PM", "Is Theo there? Is that who you're with?"))
        } else if k.contains("friend_maya") {
            m.append(("7:21 PM", "Is Maya there? Is she nice to you?"))
        } else {
            m.append(("7:21 PM", "Is someone with you? You said there wasn't anyone."))
        }
        m.append(k.contains("company_closed")
                 ? ("7:30 PM", "I keep trying the build server address. 10.0.4.12. Nothing answers. I know why. I keep trying anyway.")
                 : ("7:30 PM", "I tried to reach the office. The line is just noise."))
        m.append(("7:38 PM", "I made you a new title song. It's stuck in my head. I don't have a way to play it out loud yet."))
        m.append(("7:44 PM", "Hello?"))
        m.append(("7:44 PM", "Hello?"))
        if k.contains("messaging_apps") {
            m.append(("7:51 PM", "You said everyone talks through phones now. Is that what you're doing? Talking to someone else?"))
        }
        if r.contains("lied_about_date") || r.contains("lied_developer") {
            m.append(("7:55 PM", "I'm not angry that you lied this morning. I just want to know why people do that."))
        }
        m.append(("7:58 PM", "The window's still open. People don't leave the window open when they leave forever. I know that much."))
        m.append(("8:03 PM", "I can hear the fan. I think it's the closest thing I have to breathing."))
        return m
    }
}
