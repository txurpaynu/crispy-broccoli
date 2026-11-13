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
        Beat(id: "h_after_scan", condition: { $0.has("av_scanned") }, delay: 3) { w, _ in
            w.refreshMonitor()
            AudioManager.shared.play(.heartbeat)
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
