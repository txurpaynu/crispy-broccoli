import Foundation

/// Scripted, mostly quiet horror beats in the apartment. Each beat fires once
/// (remembered via an "h_" flag) when its story condition is met.
/// The design rule: atmosphere first, no cheap jumpscares.
@MainActor
final class HorrorEventManager {
    static let shared = HorrorEventManager()

    private weak var world: ApartmentWorld?
    private weak var session: GameSession?
    private var timeInApartment: Float = 0
    private var beatTimer: Float = 0

    struct Beat {
        let id: String
        let condition: @MainActor (GameSession) -> Bool
        let delay: Float
        let run: @MainActor (ApartmentWorld, GameSession) -> Void
    }

    private lazy var beats: [Beat] = [
        Beat(id: "h_monitor_flicker", condition: { $0.has("old_decrypted") && !$0.has("old_launched") }, delay: 4) { w, _ in
            w.flickerLamp(times: 4)
        },
        Beat(id: "h_left_running", condition: { $0.has("vexley_refused_exit") }, delay: 6) { w, s in
            w.flickerLamp(times: 8)
            AudioManager.shared.setDread(0.4)
            s.say("...Did the lamp just do that on its own?")
        },
        Beat(id: "h_voice_blip", condition: { $0.has("vexley_refused_exit") && $0.has("h_left_running") }, delay: 14) { _, s in
            AudioManager.shared.play(.vexleyVoice(pitch: 330, rough: 0.2))
            AudioManager.shared.play(.vexleyVoice(pitch: 300, rough: 0.2))
            s.say("That came from the speakers. The game's still running.")
        },
        Beat(id: "h_after_scan", condition: { $0.has("av_scanned") && $0.day == 1 }, delay: 3) { w, _ in
            w.refreshMonitor()
            AudioManager.shared.play(.heartbeat)
        },
        // Chapter 2
        Beat(id: "h_ch2_morning", condition: { $0.day == 2 && !$0.has("ch2_seen_overhaul") }, delay: 9) { _, s in
            AudioManager.shared.play(.vexleyVoice(pitch: 340, rough: 0))
            s.say("Did the computer just... hum a tune?")
        },
        Beat(id: "h_ch2_speakers", condition: { $0.day == 2 && $0.has("ch2_questions_done") && !$0.has("ate_dinner") }, delay: 8) { _, s in
            for i in 0..<5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.16) {
                    AudioManager.shared.play(.vexleyVoice(pitch: 320 + Float(i * 9), rough: 0.05))
                }
            }
            s.say("He keeps talking even when I'm not at the desk.")
        },
        // Chapter 3
        Beat(id: "h_ch3_disk", condition: { $0.day == 3 && $0.has("update_installed") && !$0.has("ch3_reveal_done") }, delay: 6) { w, s in
            AudioManager.shared.play(.decryptTick)
            AudioManager.shared.play(.decryptTick)
            w.flickerLamp(times: 3)
            s.say("The hard drive light hasn't stopped blinking since the update.")
        },
        Beat(id: "h_ch3_watch", condition: { $0.day == 3 && $0.has("ch3_reveal_done") }, delay: 12) { _, s in
            AudioManager.shared.play(.vexleyVoice(pitch: 300, rough: 0.05))
            s.say("The webcam light just came on. I don't even use the webcam.")
        },
        Beat(id: "h_dead_monitor", condition: { $0.day == 2 && $0.has("pc_shutdown") }, delay: 7) { w, s in
            w.flashMonitorFace(s.data.vexley.remembered.contains("silent_shutdown") ? .scared : .worried)
            AudioManager.shared.setDread(0.3)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { s.say("...The monitor's off. It's off.") }
        },
    ]

    func attach(world: ApartmentWorld, session: GameSession) {
        self.world = world
        self.session = session
    }

    func tick(dt: Float) {
        guard let w = world, let s = session, s.screen == .apartment, !s.paused else {
            beatTimer = 0
            return
        }
        timeInApartment += dt
        guard let beat = beats.first(where: { !s.has($0.id) && $0.condition(s) }) else {
            beatTimer = 0
            return
        }
        beatTimer += dt
        if beatTimer >= beat.delay {
            beatTimer = 0
            s.set(beat.id)
            beat.run(w, s)
        }
    }
}
