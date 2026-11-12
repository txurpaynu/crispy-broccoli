import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Anything that can answer the user. Two implementations:
/// Apple's on-device model (free, offline, iOS 26 + Apple Intelligence) and a scripted fallback.
struct BrainReply {
    var text: String
    /// The face the mascot makes while saying it.
    var face: Face
}

@MainActor
protocol CompanionBrain: AnyObject {
    var label: String { get }
    func reply(to text: String, mood: Mood) async -> BrainReply
    func reset(name: String, persona: String)
}

@MainActor
enum BrainFactory {
    /// Picks the best brain the device supports.
    static func make(name: String, persona: String) -> CompanionBrain {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if AppleIntelligenceBrain.isAvailable {
                return AppleIntelligenceBrain(name: name, persona: persona)
            }
        }
        #endif
        return ScriptedBrain(name: name)
    }

    /// Human-readable reason shown in the chat header when we fall back.
    static var unavailableReason: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return AppleIntelligenceBrain.unavailableReason
        }
        return "Apple Intelligence needs iOS 26 or newer."
        #else
        return "This build was made without Apple Intelligence support."
        #endif
    }
}

// MARK: - Apple Intelligence (Foundation Models)

#if canImport(FoundationModels)
/// Guided generation: the model must answer with text AND pick one of the mascot's faces.
@available(iOS 26.0, *)
@Generable
struct MascotReply {
    @Guide(description: "What you say back to the user, in character, one to three short sentences")
    var text: String

    @Guide(description: "The facial expression you make in reaction to the user's message")
    var expression: MascotExpression
}

@available(iOS 26.0, *)
@Generable
enum MascotExpression: String {
    case happy, excited, annoyed, angry, worried, scared

    var face: Face { Face(rawValue: rawValue) ?? .happy }
}

@available(iOS 26.0, *)
@MainActor
final class AppleIntelligenceBrain: CompanionBrain {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This iPhone doesn't support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings > Apple Intelligence & Siri."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still downloading. Try again in a bit."
        case .unavailable:
            return "Apple Intelligence isn't available right now."
        }
    }

    let label = "Apple Intelligence · on-device"
    private var session: LanguageModelSession
    private var instructions: String
    private let fallback: ScriptedBrain

    init(name: String, persona: String) {
        instructions = Personality.instructions(name: name, persona: persona)
        session = LanguageModelSession(instructions: instructions)
        fallback = ScriptedBrain(name: name)
        session.prewarm()
    }

    func reset(name: String, persona: String) {
        instructions = Personality.instructions(name: name, persona: persona)
        session = LanguageModelSession(instructions: instructions)
        fallback.reset(name: name, persona: persona)
    }

    func reply(to text: String, mood: Mood) async -> BrainReply {
        if session.isResponding { return BrainReply(text: "One sec, I'm still thinking! (>_<)", face: .annoyed) }
        let prompt = "(You are currently feeling \(mood.label.lowercased()).)\n\(text)"
        do {
            let response = try await session.respond(to: prompt, generating: MascotReply.self)
            let reply = response.content
            return BrainReply(text: reply.text.trimmingCharacters(in: .whitespacesAndNewlines),
                              face: reply.expression.face)
        } catch {
            // Usually the context window filled up, or a guardrail tripped.
            // Start a fresh session so the next message works, and show the 404 face.
            session = LanguageModelSession(instructions: instructions)
            return BrainReply(text: "Huh? My brain glitched... can you say that again?", face: .error404)
        }
    }
}
#endif

// MARK: - Scripted fallback

@MainActor
final class ScriptedBrain: CompanionBrain {
    let label = "Scripted replies"
    private var name: String

    init(name: String) { self.name = name }

    func reset(name: String, persona: String) { self.name = name }

    func reply(to text: String, mood: Mood) async -> BrainReply {
        try? await Task.sleep(nanoseconds: 500_000_000)
        let lower = text.lowercased()
        for entry in Personality.scriptedReplies where entry.keywords.contains(where: { lower.contains($0) }) {
            let line = (entry.replies.randomElement() ?? "").replacingOccurrences(of: "%NAME%", with: name)
            return BrainReply(text: line, face: entry.face)
        }
        if mood == .sleepy, Bool.random() {
            return BrainReply(text: Personality.sleepyLines.randomElement()!, face: .annoyed)
        }
        return BrainReply(text: Personality.scriptedDefault.randomElement()!, face: .happy)
    }
}
