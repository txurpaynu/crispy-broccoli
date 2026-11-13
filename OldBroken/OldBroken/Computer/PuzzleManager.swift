import Foundation

struct OldFilePuzzle: Codable {
    let path: String
    let passphrase: String
    let keysPerSecond: Double
    let maxJobSeconds: Double
    let failsBeforeHint: Int
}

struct PuzzleData: Codable {
    let oldFile: OldFilePuzzle
}

/// Character sets KeySmith can brute force.
enum KeyCharset: String, CaseIterable, Identifiable {
    case digits = "0–9"
    case letters = "A–Z"
    case alnum = "A–Z 0–9"
    case printable = "All printable"

    var id: String { rawValue }

    var chars: [Character] {
        switch self {
        case .digits: return Array("0123456789")
        case .letters: return Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        case .alnum: return Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        case .printable: return (32...126).map { Character(UnicodeScalar($0)) }
        }
    }
}

/// The OLD file puzzle. Solvable by logic, not guessing:
///  - notes_dont_ship.txt: passphrase = CODENAME + year it was packed
///  - changelog_legacy.txt: codename is LANTERN
///  - OLD's dates are corrupted, so the exact year is unknown ("19??")
///  - The box says 1999 (release year) — a red herring; it was packed earlier.
///  - KeySmith with prefix LANTERN (+4 digits) or LANTERN19 (+2 digits) finds it.
@MainActor
final class PuzzleManager {
    static let shared = PuzzleManager()

    let old: OldFilePuzzle

    private init() {
        old = DataLoader.load("puzzles", as: PuzzleData.self)?.oldFile
            ?? OldFilePuzzle(path: ComputerSimulationManager.oldPath, passphrase: "LANTERN1998",
                             keysPerSecond: 120_000, maxJobSeconds: 180, failsBeforeHint: 2)
    }

    var session: GameSession { GameSession.shared }

    nonisolated static func normalize(_ s: String) -> String {
        s.uppercased().filter { !$0.isWhitespace }
    }

    // MARK: Manual passphrase entry

    func tryPassphrase(_ input: String, path: String) -> Bool {
        let guess = Self.normalize(input)
        AudioManager.shared.play(.keyTap)
        if path == old.path && guess == old.passphrase {
            decrypt()
            session.say("...Wait. That actually worked?")
            return true
        }
        AudioManager.shared.play(.uiError)
        let fails = session.increment("old_fails")
        if guess.hasPrefix("LANTERN") {
            let year = guess.dropFirst("LANTERN".count)
            if year == "1999" {
                session.say("1999 is when it came out. But it was packed before release... wasn't it?")
            } else {
                session.say("Right scheme, I think. Wrong year.")
            }
        } else if fails == 1 {
            session.say("Not that.")
        }
        if fails >= old.failsBeforeHint && !session.has("old_needs_tool") {
            session.set("old_needs_tool")
            session.say("The dates on the file are corrupted. I don't know what year it was packed.")
            session.say("People must crack these things somehow. Somebody online has to have tried.")
        }
        return false
    }

    // MARK: KeySmith

    struct Mask {
        var prefix: String
        var unknown: Int
        var charset: KeyCharset

        var keyspace: Double { pow(Double(charset.chars.count), Double(unknown)) }
        var preview: String { Self.clean(prefix) + String(repeating: "?", count: unknown) }
        static func clean(_ s: String) -> String { PuzzleManager.normalize(s) }
    }

    func seconds(for mask: Mask) -> Double { mask.keyspace / old.keysPerSecond }

    func isTooLong(_ mask: Mask) -> Bool { seconds(for: mask) > old.maxJobSeconds }

    /// Where in the keyspace the real key sits (0...1), or nil if this mask can never find it.
    func matchPosition(_ mask: Mask, path: String) -> Double? {
        guard path == old.path else { return nil }
        let key = Array(old.passphrase)
        let prefix = Array(Mask.clean(mask.prefix))
        guard prefix.count + mask.unknown == key.count, key.starts(with: prefix) else { return nil }
        let rest = key[prefix.count...]
        let chars = mask.charset.chars
        var index = 0.0
        for c in rest {
            guard let i = chars.firstIndex(of: c) else { return nil }
            index = index * Double(chars.count) + Double(i)
        }
        return mask.keyspace <= 1 ? 1 : (index + 1) / mask.keyspace
    }

    func randomCandidate(_ mask: Mask) -> String {
        let chars = mask.charset.chars
        return Mask.clean(mask.prefix) + String((0..<mask.unknown).map { _ in chars.randomElement() ?? "?" })
    }

    func jobFinished(found: Bool, mask: Mask) {
        session.increment("keysmith_runs")
        if found {
            decrypt()
            session.say("\(old.passphrase). 1998. A year before it came out. Of course.")
        } else {
            let p = Mask.clean(mask.prefix)
            if !p.hasPrefix("LANTERN") && !p.isEmpty {
                session.say("Nothing. The note said codename plus year. What was the codename?")
            } else if p.isEmpty {
                session.say("Nothing. I should use what I know as the prefix.")
            } else {
                session.say("Nothing. Codename, then a year... how many characters is a year?")
            }
        }
    }

    // MARK: Result

    func decrypt() {
        guard !session.has("old_decrypted") else { return }
        let comp = ComputerSimulationManager.shared
        comp.mutateFS { f in
            f.update(at: old.path) { n in
                n.kind = .app
                n.launches = "oldgame"
                n.sizeKB = 51_390
                var m = n.meta ?? [:]
                m["Type"] = "Application (unpacked)"
                m["Encryption"] = "None"
                n.meta = m
            }
        }
        AudioManager.shared.play(.decryptSuccess)
        session.set("old_decrypted")
        comp.notify(app: "Pane", title: "OLD", body: "paperlight_dev.exe was unpacked. Open OLD to run it.")
    }

    nonisolated static func formatDuration(_ s: Double) -> String {
        if s < 1 { return "under a second" }
        if s < 90 { return "\(Int(s.rounded())) seconds" }
        if s < 5400 { return "\(Int((s / 60).rounded())) minutes" }
        if s < 172_800 { return "\(Int((s / 3600).rounded())) hours" }
        if s < 63_072_000 { return "\(Int((s / 86400).rounded())) days" }
        let years = s / 31_536_000
        if years > 1e9 { return "longer than the universe has existed" }
        return "\(Int(years).formatted()) years"
    }

    nonisolated static func formatCount(_ n: Double) -> String {
        if n < 1e15 { return Int(n).formatted() }
        return String(format: "%.2e", n)
    }
}
