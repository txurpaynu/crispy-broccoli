import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: GameSession

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch session.screen {
            case .title:
                TitleView()
            case .apartment:
                ApartmentView()
            case .desktop:
                DesktopRootView()
            case .endSlice:
                EndSliceView()
            }

            if session.screen != .title {
                OverlayStack()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: session.screen)
    }
}

/// Narration subtitles, banners, chapter cards and the inspect view sit above every screen.
struct OverlayStack: View {
    @EnvironmentObject var session: GameSession
    @EnvironmentObject var settings: GameSettings

    var body: some View {
        ZStack {
            VStack {
                if let b = session.banner {
                    BannerView(banner: b)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .id(b.id)
                }
                Spacer()
                if settings.subtitles, let n = session.narration {
                    NarrationView(line: n)
                        .transition(.opacity)
                        .id(n.id)
                        .padding(.bottom, session.screen == .apartment ? 18 : 46)
                }
            }
            .padding(.horizontal, 60)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.25), value: session.banner)
            .animation(.easeInOut(duration: 0.25), value: session.narration)

            if let doc = session.inspecting {
                InspectView(doc: doc) { session.inspecting = nil }
                    .transition(.opacity)
            }
            if let ch = session.chapterCard {
                ChapterCardView(chapter: ch) { session.chapterCard = nil }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.inspecting?.id)
        .animation(.easeInOut(duration: 0.6), value: session.chapterCard?.id)
    }
}
