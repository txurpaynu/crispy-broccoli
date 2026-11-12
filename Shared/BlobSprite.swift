import SwiftUI

/// Every pose the character can be drawn in. The in-app engine picks one each frame.
/// If you add PNG frames (see ShimejiCompanion/Sprites/README.md) each pose maps to an image.
enum SpritePose: String, CaseIterable {
    case stand, walk1, walk2, sit, sleep, fall, jump, dragged, land
    case climb1, climb2, hang1, hang2
}

/// The placeholder companion: a soft pink blob with ears, drawn entirely in SwiftUI
/// so the app needs no image assets. Feet always point to the bottom of the frame;
/// the engine rotates the view when it is on a wall or the ceiling.
struct BlobSprite: View {
    var pose: SpritePose
    var mood: Mood = .happy
    var facingRight: Bool = true
    var style: CompanionStyle = .default

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let m = Metrics(pose: pose)
            let look: CGFloat = facingRight ? 1 : -1

            ZStack {
                // Feet
                HStack(spacing: s * 0.14) {
                    foot(s).offset(y: m.leftFootLift * s)
                    foot(s).offset(y: m.rightFootLift * s)
                }
                .offset(x: m.feetForward * s * look, y: s * 0.40)

                // Arms (only for some poses)
                if m.armsUp {
                    HStack(spacing: s * 0.62) {
                        arm(s).rotationEffect(.degrees(-30))
                        arm(s).rotationEffect(.degrees(30))
                    }
                    .offset(y: -s * 0.12 + m.bodyDrop * s)
                }

                // Ears
                HStack(spacing: s * 0.24) {
                    ear(s).rotationEffect(.degrees(-18))
                    ear(s).rotationEffect(.degrees(18))
                }
                .offset(y: -s * 0.26 * m.sy + m.bodyDrop * s + s * 0.08)

                // Body
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [style.body, style.bodyShade],
                            center: UnitPoint(x: 0.4, y: 0.35),
                            startRadius: s * 0.05,
                            endRadius: s * 0.5
                        )
                    )
                    .overlay(Ellipse().stroke(style.outline, lineWidth: max(1, s * 0.03)))
                    .frame(width: s * 0.78 * m.sx, height: s * 0.64 * m.sy)
                    .offset(y: s * 0.08 + m.bodyDrop * s)

                // Face
                face(s)
                    .offset(x: s * 0.05 * look, y: s * 0.08 + m.bodyDrop * s)

                if pose == .sleep {
                    Text("z")
                        .font(.system(size: s * 0.2, weight: .bold, design: .rounded))
                        .foregroundStyle(style.outline.opacity(0.7))
                        .offset(x: s * 0.36, y: -s * 0.34)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: Parts

    private func foot(_ s: CGFloat) -> some View {
        Ellipse()
            .fill(style.bodyShade)
            .overlay(Ellipse().stroke(style.outline, lineWidth: max(1, s * 0.025)))
            .frame(width: s * 0.2, height: s * 0.12)
    }

    private func arm(_ s: CGFloat) -> some View {
        Capsule()
            .fill(style.bodyShade)
            .overlay(Capsule().stroke(style.outline, lineWidth: max(1, s * 0.025)))
            .frame(width: s * 0.1, height: s * 0.22)
    }

    private func ear(_ s: CGFloat) -> some View {
        Ellipse()
            .fill(style.bodyShade)
            .overlay(Ellipse().stroke(style.outline, lineWidth: max(1, s * 0.025)))
            .frame(width: s * 0.18, height: s * 0.26)
    }

    private func face(_ s: CGFloat) -> some View {
        let (eyes, mouth) = expression
        return ZStack {
            HStack(spacing: s * 0.2) {
                EyeView(kind: eyes, size: s, color: style.eye, mirrored: false)
                EyeView(kind: eyes, size: s, color: style.eye, mirrored: true)
            }
            .offset(y: -s * 0.03)

            HStack(spacing: s * 0.34) {
                Ellipse().fill(style.blush.opacity(0.55)).frame(width: s * 0.12, height: s * 0.06)
                Ellipse().fill(style.blush.opacity(0.55)).frame(width: s * 0.12, height: s * 0.06)
            }
            .offset(y: s * 0.05)

            MouthView(kind: mouth, size: s, color: style.eye)
                .offset(y: s * 0.07)
        }
    }

    private var expression: (EyeKind, MouthKind) {
        switch pose {
        case .sleep: return (.closed, .flat)
        case .dragged: return (.squeeze, .open)
        case .fall: return (.wide, .open)
        case .jump: return (.happy, .bigSmile)
        default: break
        }
        switch mood {
        case .happy: return (.open, .smile)
        case .excited: return (.happy, .bigSmile)
        case .curious: return (.open, .open)
        case .sleepy: return (.closed, .flat)
        case .sad: return (.open, .frown)
        }
    }
}

// MARK: - Pose metrics

private struct Metrics {
    var sx: CGFloat = 1
    var sy: CGFloat = 1
    var bodyDrop: CGFloat = 0
    var leftFootLift: CGFloat = 0
    var rightFootLift: CGFloat = 0
    var feetForward: CGFloat = 0
    var armsUp = false

    init(pose: SpritePose) {
        switch pose {
        case .stand:
            break
        case .walk1, .climb1, .hang1:
            leftFootLift = -0.05; bodyDrop = -0.02
        case .walk2, .climb2, .hang2:
            rightFootLift = -0.05; bodyDrop = -0.02
        case .sit:
            sx = 1.08; sy = 0.9; bodyDrop = 0.04; feetForward = 0.1
        case .sleep:
            sx = 1.12; sy = 0.84; bodyDrop = 0.06
        case .land:
            sx = 1.2; sy = 0.78; bodyDrop = 0.07
        case .fall:
            sx = 0.94; sy = 1.06; armsUp = true; leftFootLift = 0.03; rightFootLift = -0.03
        case .jump:
            sx = 0.92; sy = 1.08; armsUp = true; bodyDrop = -0.03
        case .dragged:
            sx = 0.86; sy = 1.14; armsUp = true; bodyDrop = 0.02; leftFootLift = 0.04; rightFootLift = 0.06
        }
    }
}

// MARK: - Eyes & mouth

enum EyeKind { case open, closed, happy, wide, squeeze }
enum MouthKind { case smile, bigSmile, open, flat, frown }

private struct EyeView: View {
    var kind: EyeKind
    var size: CGFloat
    var color: Color
    var mirrored: Bool

    var body: some View {
        let s = size
        let w = s * 0.1
        let line = max(1, s * 0.03)
        Group {
            switch kind {
            case .open:
                ZStack(alignment: .topLeading) {
                    Ellipse().fill(color).frame(width: s * 0.075, height: s * 0.1)
                    Circle().fill(.white).frame(width: s * 0.03, height: s * 0.03).offset(x: s * 0.012, y: s * 0.015)
                }
            case .wide:
                Circle().stroke(color, lineWidth: line).frame(width: s * 0.09, height: s * 0.09)
            case .closed:
                Path { p in
                    p.move(to: CGPoint(x: 0, y: w * 0.3))
                    p.addQuadCurve(to: CGPoint(x: w, y: w * 0.3), control: CGPoint(x: w / 2, y: w * 0.8))
                }
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .frame(width: w, height: w * 0.6)
            case .happy:
                Path { p in
                    p.move(to: CGPoint(x: 0, y: w * 0.6))
                    p.addLine(to: CGPoint(x: w / 2, y: 0))
                    p.addLine(to: CGPoint(x: w, y: w * 0.6))
                }
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
                .frame(width: w, height: w * 0.6)
            case .squeeze:
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: w, y: w * 0.35))
                    p.addLine(to: CGPoint(x: 0, y: w * 0.7))
                }
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
                .frame(width: w, height: w * 0.7)
                .scaleEffect(x: mirrored ? -1 : 1, y: 1)
            }
        }
        .frame(width: s * 0.11, height: s * 0.11)
    }
}

private struct MouthView: View {
    var kind: MouthKind
    var size: CGFloat
    var color: Color

    var body: some View {
        let s = size
        let w = s * 0.1
        let line = max(1, s * 0.028)
        Group {
            switch kind {
            case .smile:
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w / 2, y: w * 0.6))
                }
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .frame(width: w, height: w * 0.4)
            case .bigSmile:
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: w * 1.2, y: 0))
                    p.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: w * 0.6, y: w * 1.1))
                }
                .fill(Color(red: 0.85, green: 0.3, blue: 0.4))
                .overlay(
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: 0))
                        p.addLine(to: CGPoint(x: w * 1.2, y: 0))
                        p.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: w * 0.6, y: w * 1.1))
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: line, lineJoin: .round))
                )
                .frame(width: w * 1.2, height: w * 0.6)
            case .open:
                Ellipse()
                    .fill(Color(red: 0.85, green: 0.3, blue: 0.4))
                    .overlay(Ellipse().stroke(color, lineWidth: line))
                    .frame(width: s * 0.06, height: s * 0.07)
            case .flat:
                Capsule().fill(color).frame(width: w * 0.7, height: line)
            case .frown:
                Path { p in
                    p.move(to: CGPoint(x: 0, y: w * 0.4))
                    p.addQuadCurve(to: CGPoint(x: w, y: w * 0.4), control: CGPoint(x: w / 2, y: -w * 0.1))
                }
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .frame(width: w, height: w * 0.4)
            }
        }
    }
}
