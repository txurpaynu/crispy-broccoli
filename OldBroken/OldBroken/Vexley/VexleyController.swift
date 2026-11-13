import Foundation

/// Events Vexley reacts to. Narrative code reports events; the controller decides
/// how his state, trust and memory change.
enum VexleyEvent {
    case activated
    case setState(VexleyState)
    case glitchPulse
    case playerTriedToClose
    case playerTriedToKill
    case playerLeftComputer
    case playerReturned
}

/// Vexley's behaviour state machine, relationship and knowledge.
/// He only knows what his access level lets him perceive (see AccessLevel).
@MainActor
final class VexleyController: ObservableObject {
    static let shared = VexleyController()

    private var session: GameSession { GameSession.shared }
    private var preGlitchState: VexleyState = .friendly

    var memory: VexleyMemory {
        get { session.data.vexley }
        set { session.data.vexley = newValue }
    }

    var state: VexleyState { memory.state }

    func remembers(_ k: String) -> Bool { memory.remembered.contains(k) }
    func knows(_ k: String) -> Bool { memory.knowledge.contains(k) }

    func remember(_ k: String) { memory.remembered.insert(k) }

    /// Learning is gated: a fact tagged with an access level can only be learned once
    /// Vexley actually has that access.
    @discardableResult
    func learn(_ fact: String, requires: AccessLevel = .gameOnly) -> Bool {
        guard memory.access >= requires else { return false }
        memory.knowledge.insert(fact)
        return true
    }

    func adjustTrust(_ d: Int) { memory.trust = max(-10, min(10, memory.trust + d)) }

    func handle(_ e: VexleyEvent) {
        switch e {
        case .activated:
            if memory.access < .gameOnly { memory.access = .gameOnly }
            if memory.state == .dormant { memory.state = .curious }
        case .setState(let s):
            transition(to: s)
        case .glitchPulse:
            if state != .glitching { preGlitchState = state }
            memory.state = .glitching
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard let self, self.state == .glitching else { return }
                self.memory.state = self.preGlitchState
            }
        case .playerTriedToClose:
            remember("tried_to_close_window")
            adjustTrust(-1)
            transition(to: memory.trust < 0 ? .frustrated : .observant)
        case .playerTriedToKill:
            remember("tried_to_end_process")
            adjustTrust(-2)
            transition(to: .suspicious)
        case .playerLeftComputer:
            memory.abandonments += 1
        case .playerReturned:
            if state == .frustrated && memory.trust >= 0 { transition(to: .observant) }
        }
    }

    /// Guards impossible jumps (e.g. friendly straight to hostile) until the story allows them.
    private func transition(to s: VexleyState) {
        let late: Set<VexleyState> = [.aggressive, .hostile, .manipulative]
        if late.contains(s) && memory.access < .desktop { memory.state = .frustrated; return }
        memory.state = s
    }

    /// Default face for the current state, used when a line doesn't specify one.
    var defaultExpression: VexleyExpression {
        switch state {
        case .dormant, .friendly: return .happy
        case .curious: return .curious
        case .observant, .manipulative: return .neutral
        case .suspicious, .frustrated: return .annoyed
        case .aggressive, .hostile: return .angry
        case .glitching: return .glitching
        }
    }

    /// Voice parameters. Early game: clear and friendly. Gets lower and rougher with state.
    var voice: (pitch: Float, rough: Float) {
        switch state {
        case .curious: return (340, 0)
        case .friendly, .dormant: return (320, 0)
        case .observant, .manipulative: return (300, 0.03)
        case .suspicious, .frustrated: return (270, 0.1)
        case .aggressive, .hostile: return (240, 0.2)
        case .glitching: return (300, 0.55)
        }
    }
}
