import SwiftUI

/// The area the shimeji lives in. It walks on the bottom edge, climbs the sides
/// and crawls along the top. Drag it to pick it up, flick to throw, tap to pet,
/// tap empty floor to call it over.
struct StageView: View {
    @ObservedObject var engine: ShimejiEngine
    @ObservedObject var store: CompanionStore

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in engine.walk(toX: location.x) }

                CharacterView(
                    pose: engine.pose,
                    mood: store.mood,
                    face: store.face,
                    facingRight: engine.facingRight,
                    surface: engine.surface,
                    rotation: engine.rotationDegrees
                )
                .frame(width: engine.size, height: engine.size)
                .contentShape(Rectangle())
                .onTapGesture { engine.pet() }
                .gesture(
                    DragGesture(minimumDistance: 6, coordinateSpace: .named("stage"))
                        .onChanged { value in engine.drag(to: value.location) }
                        .onEnded { value in engine.endDrag(velocity: value.velocity) }
                )
                .position(engine.position)

                if let text = store.bubble {
                    SpeechBubble(text: text)
                        .frame(maxWidth: min(260, geo.size.width - 24))
                        .fixedSize(horizontal: false, vertical: true)
                        .position(bubblePosition(in: geo.size))
                        .allowsHitTesting(false)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .coordinateSpace(.named("stage"))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.bubble)
            .onAppear {
                engine.setBounds(geo.size)
                engine.start()
            }
            .onChange(of: geo.size) { _, newSize in engine.setBounds(newSize) }
        }
    }

    private func bubblePosition(in size: CGSize) -> CGPoint {
        let half = min(130, (size.width - 24) / 2)
        let x = min(max(engine.position.x, half + 12), size.width - half - 12)
        // Below the character when it's near the top, otherwise above.
        let above = engine.position.y > engine.size * 1.6
        let y = above ? engine.position.y - engine.size * 0.95 : engine.position.y + engine.size * 0.95
        return CGPoint(x: x, y: y)
    }
}

struct SpeechBubble: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded).weight(.medium))
            .foregroundStyle(Color(red: 0.3, green: 0.17, blue: 0.22))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            )
    }
}
