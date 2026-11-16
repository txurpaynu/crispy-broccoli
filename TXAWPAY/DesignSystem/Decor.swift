import SwiftUI

// Decorative pieces derived from the TXAWPAY artwork: the parchment-and-gold
// icon, the sunlit coastal landscape and the hydro texture with gold ribbons.
// They're used with restraint: headers, highlight cards and the lock screen.

/// A thin gold rule with a small diamond in the middle, echoing the icon's filigree.
struct GoldDivider: View {
    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(LinearGradient(colors: [.clear, Theme.gold], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
            Image(systemName: "diamond.fill")
                .font(.system(size: 7))
                .foregroundStyle(Theme.gold)
            Rectangle().fill(LinearGradient(colors: [Theme.gold, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

/// Wide header that shows the coastal landscape artwork fading into the screen background.
struct HeroHeader<Content: View>: View {
    var height: CGFloat = 300
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geo in
                Image("HeroLandscape")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: height, alignment: .center)
                    .clipped()
            }
            .frame(height: height)
            .accessibilityHidden(true)

            // Fade into the screen background so content below sits naturally.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: Theme.background.opacity(0.35), location: 0.45),
                    .init(color: Theme.background, location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom)
            .frame(height: height)

            content()
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
        }
        .frame(height: height)
    }
}

/// A rounded card that uses the hydro texture as its background, for highlights.
struct HydroCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    Image("HydroTexture")
                        .resizable()
                        .scaledToFill()
                    LinearGradient(colors: [Brand.deepTeal.opacity(0.55), Brand.deepTeal.opacity(0.15)],
                                   startPoint: .bottomLeading, endPoint: .topTrailing)
                }
                .accessibilityHidden(true)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .strokeBorder(Theme.gold.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: Brand.deepTeal.opacity(0.18), radius: 14, y: 8)
            .environment(\.colorScheme, .dark) // text on the texture is always light
    }
}

/// The app mark (cropped icon art) in a soft gold-rimmed tile.
struct AppMark: View {
    var size: CGFloat = 72
    var body: some View {
        Image("IconArt")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .shadow(color: Brand.sunlitGold.opacity(0.35), radius: 10, y: 4)
            .accessibilityLabel("TXAWPAY")
    }
}
