import Foundation
import AVFoundation

/// Every sound in the slice is synthesised at runtime, so the game needs no audio files.
/// REPLACEMENT POINT: to use recorded audio, map a `SoundEvent` to an AVAudioPlayer
/// in `play(_:)` and leave the synth as the fallback.
enum SoundEvent {
    case uiClick, uiConfirm, uiError, keyTap, mouseClick, notification, chapterSting
    case footstep, doorRattle, lampSwitch, pickup, paper, bedSheets
    case retroBlip, retroStep, retroBump, retroSelect, retroStart
    case glitch, glitchLong, vexleyVoice(pitch: Float, rough: Float)
    case downloadDone, decryptTick, decryptSuccess, coin, fanfare, errorBuzz
    case powerOn, powerOff, heartbeat
}

enum AudioScene {
    case title, apartment, desktop, retro, retroDread, silence, facility, chase
}

final class AudioManager {
    static let shared = AudioManager()

    private let engine = AVAudioEngine()
    fileprivate let synth = Synth(sampleRate: 44_100)
    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("[Audio] session: \(error)") }

        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let s = synth
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, abl -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(abl)
            guard let raw = buffers[0].mData else { return noErr }
            let ptr = raw.assumingMemoryBound(to: Float.self)
            s.render(into: ptr, count: Int(frameCount))
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = Float(GameSettings.shared.masterVolume)
        do { try engine.start() } catch { print("[Audio] engine: \(error)") }
    }

    func setMasterVolume(_ v: Float) { engine.mainMixerNode.outputVolume = v }

    func play(_ e: SoundEvent) { synth.trigger(e) }

    func setScene(_ s: AudioScene) { synth.setScene(s) }

    /// 0...1 — raises the low drone and detunes the retro music. Used by horror beats.
    func setDread(_ v: Float) { synth.setDread(v) }
}

// MARK: - Synth

/// Tiny real-time synth. Main thread enqueues events behind a lock; the audio
/// thread drains them and renders.
fileprivate final class Synth {
    struct Voice {
        var kind: Int       // 0 sine, 1 square, 2 noise, 3 crushed noise, 4 sweep sine, 5 formant
        var freq: Float
        var freqEnd: Float
        var gain: Float
        var length: Int
        var t: Int = 0
        var phase: Float = 0
        var phase2: Float = 0
        var delay: Int = 0
        var rough: Float = 0
    }

    struct Ambience {
        var room: Float = 0, fan: Float = 0, hum: Float = 0, music: Float = 0, drone: Float = 0
    }

    let sr: Float
    private let lock = NSLock()
    private var pending: [Voice] = []
    private var voices: [Voice] = []
    private var target = Ambience()
    private var cur = Ambience()
    private var dread: Float = 0

    // ambience state (audio thread only)
    private var brown: Float = 0
    private var humPhase: Float = 0
    private var fanPhase: Float = 0
    private var dronePhase: Float = 0
    private var musicPhase: Float = 0
    private var musicSample: Int = 0
    private var rng: UInt32 = 0x9E3779B9

    init(sampleRate: Float) { sr = sampleRate }

    private func noise() -> Float {
        rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5
        return Float(rng) / Float(UInt32.max) * 2 - 1
    }

    func setScene(_ s: AudioScene) {
        var a = Ambience()
        switch s {
        case .title: a.drone = 0.05; a.room = 0.02
        case .apartment: a.room = 0.06; a.fan = 0.02; a.hum = 0.012
        case .desktop: a.room = 0.04; a.fan = 0.05; a.hum = 0.015
        case .retro: a.fan = 0.04; a.music = 0.05
        case .retroDread: a.fan = 0.04; a.music = 0.03; a.drone = 0.05
        case .silence: break
        case .facility: a.room = 0.03; a.drone = 0.045; a.hum = 0.006
        case .chase: a.drone = 0.1; a.hum = 0.03; a.fan = 0.03
        }
        lock.lock(); target = a; lock.unlock()
    }

    func setDread(_ v: Float) {
        lock.lock(); dread = max(0, min(1, v)); lock.unlock()
    }

    private func ms(_ m: Float) -> Int { Int(sr * m / 1000) }

    func trigger(_ e: SoundEvent) {
        var v: [Voice] = []
        switch e {
        case .uiClick: v = [Voice(kind: 0, freq: 1800, freqEnd: 1200, gain: 0.08, length: ms(25))]
        case .uiConfirm: v = [Voice(kind: 0, freq: 880, freqEnd: 880, gain: 0.06, length: ms(90)),
                              Voice(kind: 0, freq: 1320, freqEnd: 1320, gain: 0.05, length: ms(120), delay: ms(70))]
        case .uiError, .errorBuzz: v = [Voice(kind: 1, freq: 140, freqEnd: 120, gain: 0.08, length: ms(260))]
        case .keyTap: v = [Voice(kind: 2, freq: 0, freqEnd: 0, gain: 0.07, length: ms(18))]
        case .mouseClick: v = [Voice(kind: 2, freq: 0, freqEnd: 0, gain: 0.05, length: ms(10))]
        case .notification: v = [Voice(kind: 0, freq: 1046, freqEnd: 1046, gain: 0.07, length: ms(140)),
                                 Voice(kind: 0, freq: 1568, freqEnd: 1568, gain: 0.06, length: ms(220), delay: ms(110))]
        case .chapterSting: v = [Voice(kind: 4, freq: 55, freqEnd: 41, gain: 0.25, length: ms(2600)),
                                 Voice(kind: 3, freq: 0, freqEnd: 0, gain: 0.05, length: ms(400))]
        case .footstep: v = [Voice(kind: 2, freq: 0, freqEnd: 0, gain: 0.05, length: ms(45)),
                             Voice(kind: 4, freq: 90, freqEnd: 60, gain: 0.08, length: ms(60))]
        case .doorRattle: v = (0..<4).map { i in Voice(kind: 2, freq: 0, freqEnd: 0, gain: 0.12, length: ms(50), delay: ms(Float(i) * 90)) }
        case .lampSwitch: v = [Voice(kind: 2, freq: 0, freqEnd: 0, gain: 0.12, length: ms(12))]
        case .pickup: v = [Voice(kind: 2, freq: 0, freqEnd: 0, gain: 0.06, length: ms(60)),
                           Voice(kind: 4, freq: 220, freqEnd: 330, gain: 0.04, length: ms(80))]
        case .paper: v = [Voice(kind: 2, freq: 0, freqEnd: 0, gain: 0.05, length: ms(220))]
        case .bedSheets: v = [Voice(kind: 2, freq: 0, freqEnd: 0, gain: 0.05, length: ms(600))]
        case .retroBlip: v = [Voice(kind: 1, freq: 880, freqEnd: 880, gain: 0.04, length: ms(30))]
        case .retroStep: v = [Voice(kind: 1, freq: 110, freqEnd: 90, gain: 0.025, length: ms(25))]
        case .retroBump: v = [Voice(kind: 1, freq: 70, freqEnd: 60, gain: 0.06, length: ms(70))]
        case .retroSelect: v = [Voice(kind: 1, freq: 660, freqEnd: 990, gain: 0.05, length: ms(80))]
        case .retroStart: v = [Voice(kind: 1, freq: 523, freqEnd: 523, gain: 0.05, length: ms(100)),
                               Voice(kind: 1, freq: 659, freqEnd: 659, gain: 0.05, length: ms(100), delay: ms(110)),
                               Voice(kind: 1, freq: 784, freqEnd: 784, gain: 0.05, length: ms(100), delay: ms(220)),
                               Voice(kind: 1, freq: 1046, freqEnd: 1046, gain: 0.05, length: ms(300), delay: ms(330))]
        case .glitch: v = [Voice(kind: 3, freq: 0, freqEnd: 0, gain: 0.12, length: ms(140))]
        case .glitchLong: v = [Voice(kind: 3, freq: 0, freqEnd: 0, gain: 0.14, length: ms(700)),
                               Voice(kind: 4, freq: 600, freqEnd: 40, gain: 0.08, length: ms(700))]
        case .vexleyVoice(let pitch, let rough):
            v = [Voice(kind: 5, freq: pitch, freqEnd: pitch * 0.92, gain: 0.05, length: ms(55), rough: rough)]
        case .downloadDone: v = [Voice(kind: 0, freq: 784, freqEnd: 784, gain: 0.06, length: ms(120)),
                                 Voice(kind: 0, freq: 1175, freqEnd: 1175, gain: 0.06, length: ms(200), delay: ms(120))]
        case .decryptTick: v = [Voice(kind: 1, freq: 2000, freqEnd: 2000, gain: 0.015, length: ms(8))]
        case .decryptSuccess: v = [Voice(kind: 1, freq: 440, freqEnd: 440, gain: 0.05, length: ms(120)),
                                   Voice(kind: 1, freq: 880, freqEnd: 880, gain: 0.05, length: ms(260), delay: ms(130))]
        case .coin: v = [Voice(kind: 1, freq: 988, freqEnd: 988, gain: 0.04, length: ms(60)),
                         Voice(kind: 1, freq: 1319, freqEnd: 1319, gain: 0.04, length: ms(140), delay: ms(60))]
        case .fanfare: v = [523, 659, 784, 1046, 1318].enumerated().map { i, f in
            Voice(kind: 1, freq: Float(f), freqEnd: Float(f), gain: 0.04, length: ms(160), delay: ms(Float(i) * 90)) }
        case .powerOn: v = [Voice(kind: 4, freq: 60, freqEnd: 9000, gain: 0.05, length: ms(500)),
                            Voice(kind: 2, freq: 0, freqEnd: 0, gain: 0.08, length: ms(30))]
        case .powerOff: v = [Voice(kind: 4, freq: 4000, freqEnd: 40, gain: 0.06, length: ms(400))]
        case .heartbeat: v = [Voice(kind: 4, freq: 60, freqEnd: 40, gain: 0.25, length: ms(120)),
                              Voice(kind: 4, freq: 55, freqEnd: 38, gain: 0.2, length: ms(140), delay: ms(260))]
        }
        lock.lock()
        pending.append(contentsOf: v)
        lock.unlock()
    }

    // Simple 8-note loop for the original game (square wave, period-appropriate).
    private let melody: [Float] = [392, 523, 659, 523, 440, 523, 587, 494, 392, 523, 659, 784, 698, 659, 587, 523]

    func render(into out: UnsafeMutablePointer<Float>, count: Int) {
        lock.lock()
        if !pending.isEmpty { voices.append(contentsOf: pending); pending.removeAll(keepingCapacity: true) }
        let tgt = target
        let dr = dread
        lock.unlock()

        let twoPi: Float = 2 * .pi
        let noteLen = Int(sr * 0.28)
        for i in 0..<count {
            // smooth ambience levels
            cur.room += (tgt.room - cur.room) * 0.0005
            cur.fan += (tgt.fan - cur.fan) * 0.0005
            cur.hum += (tgt.hum - cur.hum) * 0.0005
            cur.music += (tgt.music - cur.music) * 0.0005
            cur.drone += (tgt.drone + dr * 0.08 - cur.drone) * 0.0005

            var s: Float = 0
            let n = noise()
            brown = (brown + n * 0.02) * 0.998
            s += brown * cur.room * 3
            fanPhase += 118 / sr; if fanPhase > 1 { fanPhase -= 1 }
            s += (sin(fanPhase * twoPi) * 0.3 + n * 0.15) * cur.fan
            humPhase += 50 / sr; if humPhase > 1 { humPhase -= 1 }
            s += (sin(humPhase * twoPi) + 0.4 * sin(humPhase * 3 * twoPi)) * cur.hum
            dronePhase += (41 - dr * 3) / sr; if dronePhase > 1 { dronePhase -= 1 }
            s += sin(dronePhase * twoPi) * cur.drone + sin(dronePhase * 1.5 * twoPi) * cur.drone * 0.4

            if cur.music > 0.0005 {
                musicSample += 1
                let idx = (musicSample / noteLen) % melody.count
                let within = musicSample % noteLen
                let detune: Float = 1 - dr * 0.06 * sin(Float(musicSample) / sr * 0.7)
                musicPhase += melody[idx] * detune / sr; if musicPhase > 1 { musicPhase -= 1 }
                let env = max(0, 1 - Float(within) / Float(noteLen))
                s += (musicPhase < 0.5 ? 1 : -1) * cur.music * env * 0.6
            }

            var vi = 0
            while vi < voices.count {
                var v = voices[vi]
                if v.delay > 0 {
                    v.delay -= 1; voices[vi] = v; vi += 1; continue
                }
                let p = Float(v.t) / Float(max(1, v.length))
                let env = min(1, Float(v.t) / (sr * 0.004)) * (1 - p)
                let f = v.freq + (v.freqEnd - v.freq) * p
                var x: Float = 0
                switch v.kind {
                case 0, 4:
                    v.phase += f / sr; if v.phase > 1 { v.phase -= 1 }
                    x = sin(v.phase * twoPi)
                case 1:
                    v.phase += f / sr; if v.phase > 1 { v.phase -= 1 }
                    x = v.phase < 0.5 ? 1 : -1
                case 2:
                    x = noise()
                case 3:
                    if v.t % 7 == 0 { v.phase = (noise() > 0 ? 1 : -1) * (Float(Int(noise() * 4)) / 4) }
                    x = v.phase
                default:
                    // formant-ish "voice": fundamental + two harmonics, optional roughness
                    v.phase += f / sr; if v.phase > 1 { v.phase -= 1 }
                    v.phase2 += f * 2.7 / sr; if v.phase2 > 1 { v.phase2 -= 1 }
                    x = sin(v.phase * twoPi) * 0.6 + sin(v.phase2 * twoPi) * 0.3
                    if v.rough > 0 { x = x * (1 - v.rough) + (x > 0 ? 1 : -1) * v.rough * 0.5 + n * v.rough * 0.2 }
                }
                s += x * v.gain * env
                v.t += 1
                if v.t >= v.length {
                    voices.remove(at: vi)
                } else {
                    voices[vi] = v; vi += 1
                }
            }
            out[i] = max(-1, min(1, s))
        }
    }
}
