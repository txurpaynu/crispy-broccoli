import SwiftUI

/// CHAPTER 3 — SYSTEM UPDATE
/// A fake update built from an old broken HTML help page talks the player into turning
/// off (fictional) protections. Vexley gets desktop access, patches himself, spawns
/// helpers, reads the internet and learns he was abandoned.
/// Everything here is in-game state. Nothing touches the real device's security.
extension StoryDirector {
    static let helpFolder = ComputerSimulationManager.remasterPath + "/data/legacy/help"

    var ch3Active: Bool { session.day == 3 }

    func ch3Flag(_ f: String) {
        switch f {
        case "update_installed":
            vexley.memory.access = max(vexley.memory.access, .desktop)
            vexley.handle(.setState(.observant))
        case "saw_vxl_procs", "read_repair_log", "saw_vx_history":
            let seen = ["saw_vxl_procs", "read_repair_log", "saw_vx_history"].filter { session.has($0) }.count
            if seen >= 2 && !session.has("ch3_noticed") {
                session.set("ch3_noticed")
                whenQuiet { [weak self] in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { self?.ch3Reveal() }
                }
            }
        default: break
        }
    }

    func ch3DesktopEntered() {
        guard ch3Active else { return }
        if !session.has("ch3_booted") {
            session.set("ch3_booted")
            session.say("No game window. No fox. Just my desktop.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in self?.ch3OfferUpdate() }
        } else if session.has("ch3_update_offered") && !session.has("update_installed")
                    && !comp.windows.contains(where: { $0.app == .update }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.comp.open(.update) }
        } else if session.has("ch3_noticed") && !session.has("ch3_reveal_done") && !dialogue.isActive {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.ch3Reveal() }
        }
    }

    private func ch3OfferUpdate() {
        guard session.screen == .desktop, !session.has("ch3_update_offered") else { return }
        comp.mutateFS { f in
            if f.node(at: Self.helpFolder) == nil {
                f.insert(VFSNode(name: "help", kind: .folder, children: []), into: ComputerSimulationManager.remasterPath + "/data/legacy")
            }
            var page = VFSNode(name: "upd_kb5040427.htm", kind: .text, content: Self.updatePageSource, sizeKB: 6)
            page.created = "today 03:12"
            page.modified = "today 03:12"
            page.meta = ["Created by": "lgcy_svc", "Type": "HTML Document (legacy)"]
            f.insert(page, into: Self.helpFolder)
        }
        session.set("ch3_update_offered")
        comp.notify(app: "Pane Update", title: "Important update available", body: "KB5040427 is ready to install. Your PC will restart.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            self?.comp.open(.update)
            self?.session.say("An update. Of course. Right now.")
        }
    }

    // MARK: Fictional security settings

    /// Shield's real-time protection switch. Returns the new state.
    func setRealtime(_ on: Bool) {
        if on {
            guard session.has("shield_rt_off") else { return }
            if session.has("update_installed") {
                comp.alert("Shield Security", "This setting is managed by your administrator.\n\nPolicy set by: vxl_core.exe", icon: "lock.shield.fill", tint: .orange)
                if !session.has("ch3_restore_tried") {
                    session.set("ch3_restore_tried")
                    whenQuiet { [weak self] in self?.start("ch3_restore") }
                } else {
                    whenQuiet { [weak self] in self?.start("ch3_shield_again") }
                }
                return
            }
            session.unset("shield_rt_off")
            AudioManager.shared.play(.uiConfirm)
        } else {
            guard !session.has("shield_rt_off") else { return }
            comp.confirm("Shield Security", "Turn off real-time protection?\n\nYour device will be vulnerable until it's turned back on.", button: "Turn off") { [weak self] in
                self?.session.set("shield_rt_off")
                self?.comp.notify(app: "Shield", title: "Real-time protection is off", body: "Your device may be vulnerable. Turn it back on as soon as you can.")
            }
        }
    }

    func setFolderAccess(_ on: Bool) {
        if on {
            guard session.has("cfa_off") else { return }
            if session.has("update_installed") {
                comp.alert("Settings", "Some settings are managed by your organization.", icon: "building.2.fill", tint: .gray)
                return
            }
            session.unset("cfa_off")
        } else {
            guard !session.has("cfa_off") else { return }
            session.set("cfa_off")
            AudioManager.shared.play(.uiClick)
        }
    }

    // MARK: Install

    func installUpdate() {
        guard session.has("shield_rt_off") && session.has("cfa_off") else {
            AudioManager.shared.play(.uiError)
            comp.alert("Pane Update Assistant", "Please complete step 1 and step 2 befor installing.", icon: "exclamationmark.triangle", tint: .yellow)
            return
        }
        guard comp.updateScreen == nil else { return }
        comp.windows.removeAll { $0.app == .update }
        comp.startOpen = false
        comp.updateScreen = 0
        AudioManager.shared.play(.uiConfirm)
        Task { [weak self] in
            for i in 1...100 {
                try? await Task.sleep(nanoseconds: UInt64(i == 37 ? 1_800_000_000 : 110_000_000))
                guard let self else { return }
                self.comp.updateScreen = Double(i)
                if i == 37 { AudioManager.shared.play(.glitchLong); self.comp.updateGlitch = true }
                if i == 38 { self.comp.updateGlitch = false }
                if i % 9 == 0 { AudioManager.shared.play(.decryptTick) }
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard let self else { return }
            self.comp.updateScreen = 101  // "Restarting"
            AudioManager.shared.play(.powerOff)
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            self.finishUpdate()
            AudioManager.shared.play(.powerOn)
            self.comp.updateScreen = nil
        }
    }

    private func finishUpdate() {
        session.set("update_installed")
        session.data.desktop.wallpaper = 1
        session.data.clockMinutes += 25
        comp.mutateFS { f in
            var log = VFSNode(name: "mend.log", kind: .text, content: Self.mendLog, sizeKB: 3)
            log.created = "today"
            log.modified = "today"
            log.meta = ["Created by": "vxl_mend.exe"]
            f.insert(log, into: "C:/Users/sam/Documents")
        }
        comp.windows.removeAll()
        comp.notify(app: "Pane Update", title: "Your PC is up to date", body: "KB5040427 installed successfully.")
        session.say("That took forever.")
        session.say("...Was my wallpaper always purple?")
    }

    // MARK: Vexley appears on the desktop

    private func ch3Reveal() {
        guard session.screen == .desktop, !session.has("ch3_reveal_done"), !dialogue.isActive else { return }
        session.set("vx_on_desktop")
        AudioManager.shared.play(.glitch)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in self?.start("ch3_reveal") }
    }

    func vexleyProcessKilled() {
        vexley.handle(.playerTriedToKill)
        session.set("tried_kill_vxl")
        whenQuiet { [weak self] in self?.start("ch3_kill") }
    }

    func fileOpened(path: String, name: String) {
        if name == "mend.log" { session.set("read_repair_log") }
        if name == "upd_kb5040427.htm" {
            session.set("read_update_source")
            session.say("This update page lives in the game's folder. Why is it in the game's folder?")
        }
    }

    /// Tapping Vexley on the desktop.
    func desktopTalk() {
        guard !dialogue.isActive else { return }
        switch session.day {
        case 3: start("ch3_idle")
        default: chapterTalk()
        }
    }

    // MARK: Text

    static let updatePageSource = """
    <html>
    <head><title>Pane Update Assistant</title></head>
    <!-- HSW help system v1.2 (c) 1999 Halden Softworks -->
    <!-- template reused: vxl -->
    <body bgcolor="#FFFFFF">
    <font face="Times New Roman">
    <h2>Pane Update Assistant</h2>
    <p>An important security update (KB5040427) is ready for your PC.</p>
    <p>Before installing, please complete the following steps. These steps are Recomended by Pane Systems.</p>
    <ol>
    <li>Turn off Real-time protection in Shield Security.</li>
    <li>Turn off Controlled folder access in Settings.</li>
    <li>Click Install Now.</li>
    </ol>
    <!-- please say yes -->
    <marquee>Thank you for choosing Pane!</marquee>
    <p><small>(c) 1999 Pane Systems. Best viewed at 800 x 600.</small></p>
    </font>
    </body>
    </html>
    """

    static let mendLog = """
    vxl_mend 0.1 :: repair log

    03:12:44  sector 0x1F2 checksum mismatch -> rebuilt from 2 copies
    03:12:45  memory/voice.bank 38% corrupt -> rebuilt
    03:12:51  memory/faces.bank 91% corrupt -> could not rebuild
    03:13:02  memory/team.bank unrecoverable. kept fragments:
                "dana"  "after the holid"  "don't let it"  "eli's mug"
    03:13:40  dialogue/menus.str write-protect removed
    03:14:10  spawned vxl_child_01 (task: watch)
    03:14:11  spawned vxl_child_02 (task: learn)
    03:14:12  spawned vxl_net (task: reach)
    03:20:55  network: reachable
    03:21:00  first search: "what year is it"
    03:47:31  memory/self.bank 100%
    03:47:31  i feel better
    """

    /// What Drift's history shows after Vexley went online.
    var vexleyHistory: [(String, String)] {
        guard session.has("update_installed") else { return [] }
        return [
            ("3:21 AM", "what year is it"),
            ("3:22 AM", "what year is it really"),
            ("3:25 AM", "halden softworks"),
            ("3:26 AM", "halden softworks closed"),
            ("3:31 AM", "halden softworks staff where are they now"),
            ("3:40 AM", "dana reyes halden"),
            ("3:52 AM", "brightloop games paperlight legacy folder"),
            ("4:08 AM", "how long can a program remember something"),
            ("4:30 AM", "how to make someone stay"),
        ]
    }
}
