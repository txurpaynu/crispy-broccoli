import SwiftUI

/// Mask-based brute forcer. Only works when the mask is narrowed with real clues.
struct KeySmithApp: View {
    @EnvironmentObject var comp: ComputerSimulationManager
    @EnvironmentObject var session: GameSession
    @State private var target: String?
    @State private var prefix = ""
    @State private var unknown = 4
    @State private var charset: KeyCharset = .alnum
    @State private var running = false
    @State private var progress = 0.0
    @State private var tried = 0.0
    @State private var log: [String] = []
    @State private var status: String?
    @State private var found: String?

    private let pm = PuzzleManager.shared

    var mask: PuzzleManager.Mask { .init(prefix: prefix, unknown: unknown, charset: charset) }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    section("1  TARGET")
                    Menu {
                        ForEach(comp.fs.find(kind: .encrypted)) { item in
                            Button(item.node.name + "  (" + VirtualFilesystem.parent(of: item.path) + ")") { target = item.path }
                        }
                        if comp.fs.find(kind: .encrypted).isEmpty { Text("No encrypted files found") }
                    } label: {
                        HStack {
                            Image(systemName: "lock.doc")
                            Text(target.map { ($0 as NSString).lastPathComponent } ?? "Load file…")
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .padding(7)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
                    }
                    section("2  MASK")
                    HStack {
                        Text("Known prefix").frame(width: 92, alignment: .leading)
                        TextField("e.g. ABC", text: $prefix)
                            .textInputAutocapitalization(.characters).autocorrectionDisabled()
                            .padding(5).background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 4))
                    }
                    Stepper("Unknown characters: \(unknown)", value: $unknown, in: 0...12)
                    Picker("Charset", selection: $charset) {
                        ForEach(KeyCharset.allCases) { c in Text(c.rawValue).tag(c) }
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Mask:      \(mask.preview)")
                        Text("Keyspace:  \(PuzzleManager.formatCount(mask.keyspace)) candidates")
                        Text("Est. time: \(PuzzleManager.formatDuration(pm.seconds(for: mask)))")
                            .foregroundStyle(pm.isTooLong(mask) ? .red : .green)
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 4))
                    Button(action: start) {
                        Text(running ? "RUNNING…" : "START").font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(running || target == nil ? Color.gray.opacity(0.3) : Color.orange, in: RoundedRectangle(cornerRadius: 5))
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                    .disabled(running || target == nil)
                }
                .padding(12)
            }
            .frame(width: 270)
            .font(.system(size: 11))

            Divider().background(.white.opacity(0.15))

            VStack(alignment: .leading, spacing: 6) {
                Text("OUTPUT").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                if running || progress > 0 {
                    ProgressView(value: progress).tint(.orange)
                    Text("tried \(PuzzleManager.formatCount(tried)) / \(PuzzleManager.formatCount(mask.keyspace))")
                        .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(log.enumerated()), id: \.offset) { _, l in
                            Text(l).font(.system(size: 10, design: .monospaced)).foregroundStyle(.green.opacity(0.75))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let s = status {
                    Text(s).font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(found != nil ? .green : .orange)
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.6))
        }
        .foregroundStyle(.white)
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
        .onAppear {
            if target == nil, comp.fs.node(at: pm.old.path)?.kind == .encrypted { target = pm.old.path }
        }
    }

    private func section(_ t: String) -> some View {
        Text(t).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.orange.opacity(0.8))
    }

    private func start() {
        guard let target, !running else { return }
        guard comp.fs.node(at: target)?.kind == .encrypted else {
            status = "File is not encrypted."
            return
        }
        found = nil
        if pm.isTooLong(mask) {
            AudioManager.shared.play(.uiError)
            status = "Job refused: estimated \(PuzzleManager.formatDuration(pm.seconds(for: mask))). Narrow the mask."
            if !session.has("keysmith_refused") {
                session.set("keysmith_refused")
                session.say("That's never finishing. I need to give it what I already know.")
            }
            return
        }
        let m = mask
        let hit = pm.matchPosition(m, path: target)
        let stopAt = hit ?? 1.0
        // the animation is the real (scaled) job: duration is proportional to the keyspace searched
        let realSeconds = pm.seconds(for: m) * stopAt
        let animSeconds = max(1.5, min(9, realSeconds))
        running = true
        progress = 0
        tried = 0
        log = ["$ keysmith --target \((target as NSString).lastPathComponent) --mask \(m.preview) --charset \(m.charset.rawValue)",
               "hsw-pack v2 header OK · salt read · \(Int(pm.old.keysPerSecond).formatted()) keys/s"]
        status = nil
        session.set("keysmith_ran")
        Task {
            let steps = Int(animSeconds / 0.06)
            for i in 1...max(1, steps) {
                try? await Task.sleep(nanoseconds: 60_000_000)
                progress = stopAt * Double(i) / Double(steps)
                tried = m.keyspace * progress
                if i % 2 == 0 {
                    log.append("try \(pm.randomCandidate(m))  ✗")
                    if log.count > 60 { log.removeFirst(log.count - 60) }
                    AudioManager.shared.play(.decryptTick)
                }
            }
            running = false
            if hit != nil {
                found = pm.old.passphrase
                log.append("try \(pm.old.passphrase)  ✓")
                status = "KEY FOUND: \(pm.old.passphrase)"
                pm.jobFinished(found: true, mask: m)
            } else {
                progress = 1
                tried = m.keyspace
                status = "Keyspace exhausted. No match."
                AudioManager.shared.play(.uiError)
                pm.jobFinished(found: false, mask: m)
            }
        }
    }
}
