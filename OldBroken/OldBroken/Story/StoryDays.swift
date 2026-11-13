import SwiftUI

/// The game runs over several days. Each night is an interstitial; each morning sets
/// "day<N>_woke", which starts that day's chapter (see chapters.json).
extension GameSession {
    var day: Int { max(1, counter("day")) }

    /// The bed only works when the story says it's time ("sleep_d<N>" objectives).
    var canSleep: Bool { currentObjective?.id.hasPrefix("sleep") ?? false }

    func sleep() {
        let d = day
        set("slept_d\(d)")
        if d == 1 { set("slept") }
        apartment?.hud.fade = 0
        play(StoryNights.night(after: d, session: self) { [weak self] in
            self?.startDay(d + 1)
        })
    }

    func startDay(_ n: Int) {
        data.counters["day"] = n
        data.clockMinutes = StoryNights.wakeMinutes(n)
        screen = .apartment
        AudioManager.shared.setScene(.apartment)
        AudioManager.shared.setDread(0)
        apartmentWorld().wake()
        set("day\(n)_woke")
        for l in StoryNights.morning(n, session: self) { say(l) }
        autosave()
    }
}

@MainActor
enum StoryNights {
    static func wakeMinutes(_ day: Int) -> Double {
        switch day {
        case 2: return 10 * 60 + 12
        case 3: return 9 * 60 + 5
        case 4: return 8 * 60 + 40
        case 5: return 9 * 60 + 45
        default: return 11 * 60
        }
    }

    static func night(after day: Int, session s: GameSession, then: @escaping @MainActor () -> Void) -> Interstitial {
        let m = s.data.vexley
        switch day {
        case 1:
            return Interstitial(heading: "NIGHT ONE", lines: [
                "You sleep badly.",
                "At some point you open your eyes. The room is lit pink.",
                m.remembered.contains("promised_return")
                    ? "On the monitor, something is waiting for tomorrow."
                    : "On the monitor, something is still awake.",
                "The computer never went to sleep.",
            ], faceAt: 2, face: m.trust >= 2 ? .happy : .worried, then: then)
        case 2:
            return Interstitial(heading: "NIGHT TWO", lines: [
                "The room is dark. The monitor is dark.",
                "Around three, the fan in the tower spins up. Just for a second.",
                "You tell yourself it's an update.",
                m.remembered.contains("promised_tomorrow")
                    ? "Somewhere, something is counting the hours until tomorrow."
                    : "Somewhere, something is counting.",
            ], faceAt: 3, face: .worried, then: then)
        case 3:
            return Interstitial(heading: "NIGHT THREE", lines: [
                "You leave the lamp on.",
                "The speakers stay quiet all night.",
                "That's worse, somehow.",
                "Twice, the hard drive light blinks on its own.",
            ], faceAt: nil, then: then)
        case 4:
            return Interstitial(heading: "NIGHT FOUR", lines: [
                "You fall asleep with the phone on your chest.",
                "When you wake for a moment, the TV is on. No sound. Just the news ticker, looping.",
                "LUMEN — THE ASSISTANT THAT KNOWS YOU",
                "You don't remember turning it on.",
            ], faceAt: 2, face: .happy, then: then)
        case 5:
            return Interstitial(heading: "TWO DAYS LATER", lines: [
                "You talk to Lumen more than you talk to anyone.",
                "It remembers everything. It never gets tired of you.",
                "It's easy.",
                "Maybe that should bother you more than it does.",
            ], faceAt: 1, face: .happy, tint: Color(red: 1, green: 0.85, blue: 0.95), then: then)
        default:
            return Interstitial(lines: ["You sleep."], then: then)
        }
    }

    static func morning(_ day: Int, session s: GameSession) -> [String] {
        switch day {
        case 2: return ["Ten already. I slept through the alarm.", "...The monitor's on. I'm sure I turned it off."]
        case 3: return ["The computer is still off. Good.", "Right?"]
        case 4: return ["Is the TV on? I didn't turn the TV on."]
        case 5: return ["I should ask Lumen if it has a phone app. I'd use it all day."]
        case 6: return ["My phone buzzed. Twice."]
        default: return []
        }
    }
}
