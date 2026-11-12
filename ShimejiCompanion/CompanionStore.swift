import SwiftUI
import Combine

struct ChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable { case user, companion }
    var id = UUID()
    var role: Role
    var text: String
}

/// The companion's state: mood, chat history, persona, speech bubble and Live Activity.
@MainActor
final class CompanionStore: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published private(set) var happiness: Int
    @Published private(set) var isThinking = false
    @Published private(set) var bubble: String?
    @Published private(set) var name: String
    @Published private(set) var persona: String
    @Published private(set) var brainLabel: String
    /// A temporary reaction face. When nil the mascot shows its resting face for the mood.
    @Published private(set) var reaction: Face?

    let live = LiveActivityManager()
    private var brain: CompanionBrain
    private var bubbleTask: Task<Void, Never>?
    private var reactionTask: Task<Void, Never>?
    private var lastLiveMessage = "I'm here! Tap to chat with me."
    private var decayTimer: Timer?
    private let defaults = UserDefaults.standard
    private var liveObserver: AnyCancellable?

    init() {
        let savedName = UserDefaults.standard.string(forKey: "name") ?? Personality.defaultName
        let savedPersona = UserDefaults.standard.string(forKey: "persona") ?? Personality.defaultPersona
        name = savedName
        persona = savedPersona
        happiness = UserDefaults.standard.object(forKey: "happiness") as? Int ?? 70
        let b = BrainFactory.make(name: savedName, persona: savedPersona)
        brain = b
        brainLabel = b.label
        if let data = UserDefaults.standard.data(forKey: "messages"),
           let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = saved
        }
        // Re-render views that read store.live.* when the Live Activity changes.
        liveObserver = live.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        decayTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.changeHappiness(by: -1) }
        }
    }

    var usingAppleIntelligence: Bool { !(brain is ScriptedBrain) }
    var fallbackReason: String? { usingAppleIntelligence ? nil : BrainFactory.unavailableReason }

    var mood: Mood {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 23 || hour < 6 { return .sleepy }
        if happiness >= 85 { return .excited }
        if happiness >= 60 { return .happy }
        if happiness >= 30 { return .curious }
        return .sad
    }

    /// The face the mascot is making right now.
    var face: Face { reaction ?? Face.resting(for: mood) }

    /// 0...1, fed to the engine so a sleepy companion naps more.
    var sleepiness: Double { mood == .sleepy ? 0.8 : (mood == .sad ? 0.3 : 0.05) }

    // MARK: Chat

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        messages.append(ChatMessage(role: .user, text: text))
        isThinking = true
        react(.happy, for: 30)
        say("…", duration: 30)
        Task {
            let answer = await brain.reply(to: text, mood: mood)
            var face = answer.face
            let lower = text.lowercased()
            if lower.contains("glitch") || lower.contains("404") || lower.contains("creepypasta") { face = .glitch }
            messages.append(ChatMessage(role: .companion, text: answer.text))
            isThinking = false
            switch face {
            case .angry: changeHappiness(by: -3)
            case .annoyed: changeHappiness(by: -1)
            default: changeHappiness(by: 2)
            }
            react(face, for: 8)
            say(answer.text, duration: 7)
            saveMessages()
        }
    }

    func clearChat() {
        messages = []
        brain.reset(name: name, persona: persona)
        saveMessages()
    }

    // MARK: Persona

    func updatePersona(name newName: String, persona newPersona: String) {
        name = newName.isEmpty ? Personality.defaultName : newName
        persona = newPersona.isEmpty ? Personality.defaultPersona : newPersona
        defaults.set(name, forKey: "name")
        defaults.set(persona, forKey: "persona")
        brain.reset(name: name, persona: persona)
        messages = []
        saveMessages()
        say("I'm \(name) now! Nice to meet you~")
    }

    func resetPersona() {
        updatePersona(name: Personality.defaultName, persona: Personality.defaultPersona)
    }

    // MARK: Character events

    func handle(_ event: ShimejiEvent) {
        switch event {
        case .petted:
            changeHappiness(by: 3)
            react(happiness > 80 ? .excited : .happy, for: 3)
            say(Personality.petLines.randomElement()!)
        case .pickedUp:
            react(.scared, for: 60)
            if Double.random(in: 0..<1) < 0.5 { say(Personality.pickupLines.randomElement()!) }
        case .thrown, .landedHard:
            react(.angry, for: 4)
            if bubble == nil || Double.random(in: 0..<1) < 0.3 {
                changeHappiness(by: -1)
                say(Personality.throwLines.randomElement()!)
            }
        case .landed:
            // Let go gently: stop looking scared a moment after landing.
            if reaction == .scared { react(.worried, for: 1.5) }
        case .startedSleeping:
            react(.annoyed, for: 14)
            say(Personality.sleepyLines.randomElement()!, duration: 3)
        case .wokeUp:
            react(.annoyed, for: 2)
        case .idleThought:
            guard !isThinking else { break }
            let hour = Calendar.current.component(.hour, from: Date())
            if hour == 3, Double.random(in: 0..<1) < 0.3 {
                react(.glitch, for: 3)
                say("...", duration: 3)
            } else {
                say(Personality.idleLines.randomElement()!)
            }
        }
    }

    func appBecameActive() {
        say(Personality.greetings.randomElement()!)
    }

    func appWentToBackground() {
        live.update(liveState(message: Personality.goodbyeLines.randomElement()!))
    }

    // MARK: Reactions

    func react(_ face: Face, for seconds: Double) {
        reactionTask?.cancel()
        reaction = face
        live.update(liveState(message: lastLiveMessage))
        reactionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.reaction = nil
        }
    }

    // MARK: Speech bubble

    func say(_ text: String, duration: Double = 4) {
        bubbleTask?.cancel()
        bubble = text
        if text != "…" { live.update(liveState(message: text)) }
        bubbleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.bubble = nil
        }
    }

    // MARK: Live Activity

    func toggleLiveActivity() {
        if live.isRunning {
            live.stop()
        } else {
            live.start(name: name, state: liveState(message: "I'm here! Tap to chat with me."))
        }
    }

    private func liveState(message: String) -> CompanionAttributes.ContentState {
        lastLiveMessage = message
        return CompanionAttributes.ContentState(message: message, mood: mood, happiness: happiness, face: face)
    }

    // MARK: Persistence

    private func changeHappiness(by delta: Int) {
        happiness = min(100, max(0, happiness + delta))
        defaults.set(happiness, forKey: "happiness")
    }

    private func saveMessages() {
        let recent = Array(messages.suffix(60))
        if let data = try? JSONEncoder().encode(recent) {
            defaults.set(data, forKey: "messages")
        }
    }
}
