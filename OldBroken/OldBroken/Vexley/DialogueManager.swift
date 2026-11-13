import Foundation
import Combine

// MARK: - Data

struct DialogueEffects: Codable {
    var trust: Int?
    var remember: [String]?
    var learn: [String]?
    var setFlags: [String]?
    var state: VexleyState?
}

struct DialogueCondition: Codable {
    var flags: [String]?
    var notFlags: [String]?
    var anyFlags: [String]?
    var remembered: [String]?
    var notRemembered: [String]?
    var minTrust: Int?
    var maxTrust: Int?
    var minAccess: AccessLevel?
    var maxAccess: AccessLevel?
}

struct DialogueChoice: Codable {
    let text: String
    let next: String?
    var effects: DialogueEffects?
    var condition: DialogueCondition?
}

struct DialogueRedirect: Codable {
    let condition: DialogueCondition
    let to: String
}

struct DialogueNode: Codable, Identifiable {
    let id: String
    let speaker: String
    var expression: VexleyExpression?
    let text: String
    var next: String?
    var choices: [DialogueChoice]?
    var effects: DialogueEffects?
    var events: [String]?
    var redirects: [DialogueRedirect]?
}

// MARK: - Manager

/// Runs data-driven dialogue (Data/dialogue_ch1.json): conditions, effects on Vexley's
/// memory/trust/state, UI events, and a typewriter that can visibly rewrite words
/// using the markup [old->new].
@MainActor
final class DialogueManager: ObservableObject {
    @Published private(set) var node: DialogueNode?
    @Published private(set) var shown = ""
    @Published private(set) var typing = false
    @Published private(set) var visibleChoices: [DialogueChoice] = []

    /// Called for every UI event a node triggers ("glitch", "open_helper_door", ...).
    var onEvent: ((String) -> Void)?
    /// Called with the id of the node that ended a conversation.
    var onFinish: ((String) -> Void)?

    private let nodes: [String: DialogueNode]
    private var frames: [String] = []
    private var frameIndex = 0
    private var timer: Timer?
    private var vexley: VexleyController { VexleyController.shared }
    private var session: GameSession { GameSession.shared }

    init(file: String) {
        let list = DataLoader.load(file, as: [DialogueNode].self) ?? []
        nodes = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }

    var isActive: Bool { node != nil }

    var expression: VexleyExpression {
        node?.expression ?? vexley.defaultExpression
    }

    func start(_ id: String) {
        go(id)
    }

    private func go(_ idIn: String?) {
        var id = idIn
        // follow redirects
        var hops = 0
        while let cur = id, let n = nodes[cur], let reds = n.redirects, hops < 8,
              let r = reds.first(where: { evaluate($0.condition) }) {
            id = r.to
            hops += 1
        }
        guard let id, let n = nodes[id] else {
            let last = node?.id ?? ""
            node = nil
            shown = ""
            visibleChoices = []
            onFinish?(last)
            return
        }
        node = n
        if let e = n.effects { apply(e) }
        n.events?.forEach { onEvent?($0) }
        visibleChoices = (n.choices ?? []).filter { $0.condition.map(evaluate) ?? true }
        startTyping(substitute(n.text))
    }

    /// A button: finish typing, or advance.
    func advance() {
        guard let n = node else { return }
        if typing {
            finishTyping()
            return
        }
        guard visibleChoices.isEmpty else { return }
        AudioManager.shared.play(.retroSelect)
        go(n.next)
    }

    func choose(_ c: DialogueChoice) {
        guard !typing else { return }
        AudioManager.shared.play(.retroSelect)
        if let e = c.effects { apply(e) }
        go(c.next)
    }

    func cancel() {
        timer?.invalidate()
        node = nil
        shown = ""
        typing = false
        visibleChoices = []
    }

    // MARK: Conditions & effects

    func evaluate(_ c: DialogueCondition) -> Bool {
        let m = vexley.memory
        if let f = c.flags, !f.allSatisfy({ session.has($0) }) { return false }
        if let f = c.notFlags, f.contains(where: { session.has($0) }) { return false }
        if let f = c.anyFlags, !f.contains(where: { session.has($0) }) { return false }
        if let r = c.remembered, !r.allSatisfy({ m.remembered.contains($0) }) { return false }
        if let r = c.notRemembered, r.contains(where: { m.remembered.contains($0) }) { return false }
        if let t = c.minTrust, m.trust < t { return false }
        if let t = c.maxTrust, m.trust > t { return false }
        if let a = c.minAccess, m.access < a { return false }
        if let a = c.maxAccess, m.access > a { return false }
        return true
    }

    private func apply(_ e: DialogueEffects) {
        if let t = e.trust { vexley.adjustTrust(t) }
        e.remember?.forEach { vexley.remember($0) }
        e.learn?.forEach { vexley.learn($0) }
        if let s = e.state { vexley.handle(.setState(s)) }
        e.setFlags?.forEach { session.set($0) }
    }

    private func substitute(_ t: String) -> String {
        let now = Date()
        let cal = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "MMMM"
        return t.replacingOccurrences(of: "{year}", with: String(cal.component(.year, from: now)))
            .replacingOccurrences(of: "{month}", with: df.string(from: now))
            .replacingOccurrences(of: "{time}", with: session.clockText)
    }

    // MARK: Typewriter with live rewriting

    static func buildFrames(_ text: String) -> [String] {
        var frames: [String] = []
        var out = ""
        var i = text.startIndex
        while i < text.endIndex {
            if text[i] == "[", let close = text[i...].firstIndex(of: "]"),
               let arrow = text[i..<close].range(of: "->") {
                let old = String(text[text.index(after: i)..<arrow.lowerBound])
                let new = String(text[arrow.upperBound..<close])
                for ch in old { out.append(ch); frames.append(out) }
                for _ in 0..<14 { frames.append(out) }          // hesitate
                for _ in old { out.removeLast(); frames.append(out) }
                for _ in 0..<5 { frames.append(out) }
                for ch in new { out.append(ch); frames.append(out) }
                i = text.index(after: close)
            } else {
                out.append(text[i])
                frames.append(out)
                i = text.index(after: i)
            }
        }
        return frames
    }

    private func startTyping(_ text: String) {
        timer?.invalidate()
        frames = Self.buildFrames(text)
        frameIndex = 0
        shown = ""
        typing = true
        let isVexley = node?.speaker == "VEXLEY" || node?.speaker == "???"
        let interval = isVexley ? 0.034 : 0.022
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.stepTyping(isVexley: isVexley) }
        }
    }

    private func stepTyping(isVexley: Bool) {
        guard frameIndex < frames.count else { finishTyping(); return }
        let prev = shown
        shown = frames[frameIndex]
        frameIndex += 1
        if shown.count > prev.count, let last = shown.last, !last.isWhitespace, frameIndex % 2 == 0 {
            if isVexley {
                let v = vexley.voice
                let jitter = Float.random(in: -18...18)
                AudioManager.shared.play(.vexleyVoice(pitch: v.pitch + jitter, rough: v.rough))
            } else {
                AudioManager.shared.play(.retroBlip)
            }
        } else if shown.count < prev.count {
            AudioManager.shared.play(.keyTap)
        }
    }

    private func finishTyping() {
        timer?.invalidate()
        timer = nil
        shown = frames.last ?? ""
        typing = false
    }
}
