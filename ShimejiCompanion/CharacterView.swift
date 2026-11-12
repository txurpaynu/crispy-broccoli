import SwiftUI
import UIKit

/// Optional Shimeji-ee style PNG frames (shime1.png, shime2.png, ...) for a full-body
/// character. Only used when there are no face GIFs. See Sprites/README.md.
enum SpriteFrames {
    static let mapping: [SpritePose: String] = [
        .stand: "shime1",
        .walk1: "shime2",
        .walk2: "shime3",
        .fall: "shime4",
        .dragged: "shime5",
        .sit: "shime11",
        .climb1: "shime12",
        .climb2: "shime13",
        .land: "shime18",
        .sleep: "shime21",
        .jump: "shime22",
        .hang1: "shime23",
        .hang2: "shime24",
    ]

    static let available: Bool = UIImage(named: "shime1") != nil

    static func image(for pose: SpritePose) -> UIImage? {
        guard available else { return nil }
        return mapping[pose].flatMap { UIImage(named: $0) } ?? UIImage(named: "shime1")
    }
}

/// Draws the companion for the current engine state.
/// Priority: fox face GIFs (mascot head) → full-body PNG frames → drawn placeholder blob.
struct CharacterView: View {
    var pose: SpritePose
    var mood: Mood
    var face: Face
    var facingRight: Bool
    var surface: Surface
    var rotation: Double

    var body: some View {
        if FaceLibrary.available {
            MascotHead(pose: pose, face: face, rotation: rotation)
        } else if let image = SpriteFrames.image(for: pose) {
            let flip: Bool = {
                switch surface {
                case .rightWall: return true
                case .leftWall: return false
                default: return facingRight
                }
            }()
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .scaleEffect(x: flip ? -1 : 1, y: 1)
        } else {
            BlobSprite(pose: pose, mood: mood, facingRight: facingRight)
                .rotationEffect(.degrees(rotation))
        }
    }
}

/// The mascot is a head, so it hops instead of walking, squishes when it lands,
/// stretches when grabbed and sticks to walls and the ceiling sideways/upside down.
private struct MascotHead: View {
    var pose: SpritePose
    var face: Face
    var rotation: Double

    var body: some View {
        let t = transform
        AnimatedFaceView(face: face)
            .scaleEffect(x: t.sx, y: t.sy, anchor: .bottom)
            .rotationEffect(.degrees(t.tilt), anchor: .bottom)
            .offset(y: t.hop)
            .rotationEffect(.degrees(rotation))
            .animation(.spring(response: 0.18, dampingFraction: 0.55), value: pose)
    }

    private var transform: (sx: CGFloat, sy: CGFloat, tilt: Double, hop: CGFloat) {
        switch pose {
        case .walk1, .climb1, .hang1: return (0.96, 1.04, -7, -10)
        case .walk2, .climb2, .hang2: return (1.04, 0.96, 7, 0)
        case .land: return (1.15, 0.82, 0, 0)
        case .sit: return (1.05, 0.95, 0, 0)
        case .sleep: return (1.06, 0.92, 10, 0)
        case .dragged: return (0.9, 1.12, 0, 0)
        case .jump: return (0.94, 1.08, 0, 0)
        case .fall: return (1.0, 1.0, 12, 0)
        case .stand: return (1, 1, 0, 0)
        }
    }
}
