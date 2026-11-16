import SwiftUI
import UIKit

// MARK: - Brand palette
//
// TXAWPAY's palette is built from six foundation colours. Interface tokens
// below are *semantic* (background, surface, text…) and resolve differently
// in light and dark appearance, so views never hard-code a raw brand colour
// for something that must adapt.

enum Brand {
    static let oceanTurquoise = Color(hex: 0x39AFC0)
    static let deepTeal       = Color(hex: 0x164D58)
    static let sunlitGold     = Color(hex: 0xC69B55)
    static let warmIvory      = Color(hex: 0xF1E5D2)
    static let earthBrown     = Color(hex: 0x76503B)
    static let jungleGreen    = Color(hex: 0x647B50)
}

enum Theme {
    // Backgrounds
    static let background = Color.dynamic(light: 0xF6EEE1, dark: 0x0A1F25)
    static let backgroundDeep = Color.dynamic(light: 0xF1E5D2, dark: 0x07171C)
    static let surface = Color.dynamic(light: 0xFFFBF5, dark: 0x11303A)
    static let surfaceRaised = Color.dynamic(light: 0xFFFFFF, dark: 0x173C47)
    static let surfaceSunken = Color.dynamic(light: 0xEFE4D3, dark: 0x0D2830)

    // Text
    static let textPrimary = Color.dynamic(light: 0x123F48, dark: 0xF1E5D2)
    static let textSecondary = Color.dynamic(light: 0x4E6B70, dark: 0xB9C7C4)
    static let textTertiary = Color.dynamic(light: 0x86999A, dark: 0x7F9A9C)

    // Accents
    static let accent = Color.dynamic(light: 0x2E9DAE, dark: 0x5CC6D4)   // turquoise, tuned for contrast
    static let accentSoft = Color.dynamic(light: 0xD7EEF0, dark: 0x173F47)
    static let gold = Color.dynamic(light: 0xB4863E, dark: 0xD7B072)
    static let goldSoft = Color.dynamic(light: 0xF3E6CC, dark: 0x3A3220)
    static let earth = Color.dynamic(light: 0x76503B, dark: 0xC09A7F)
    static let jungle = Color.dynamic(light: 0x647B50, dark: 0x9DB585)
    static let danger = Color.dynamic(light: 0xB4513F, dark: 0xE58A76)
    static let separator = Color.dynamic(light: 0xE4D7C3, dark: 0x1F4752)

    // Gradients — used sparingly (headers, icon, highlights).
    static let hydroGradient = LinearGradient(
        colors: [Color.dynamic(light: 0x1C5D69, dark: 0x0F3C46), Color.dynamic(light: 0x39AFC0, dark: 0x237C89)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let dawnGradient = LinearGradient(
        colors: [Color.dynamic(light: 0xFFF8EC, dark: 0x0F2C34), Color.dynamic(light: 0xF1E5D2, dark: 0x0A1F25)],
        startPoint: .top, endPoint: .bottom)

    static let emberGradient = LinearGradient(
        colors: [Brand.sunlitGold.opacity(0.9), Brand.earthBrown.opacity(0.85)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // Metrics
    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
        static let large: CGFloat = 22
        static let xl: CGFloat = 28
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
}

// MARK: - Typography
//
// Titles use the system serif (New York) for warmth and elegance; body text
// stays in SF for legibility. Every style is built on a Dynamic Type text
// style so it scales with the user's accessibility settings.

enum Typo {
    static let largeTitle = Font.system(.largeTitle, design: .serif).weight(.semibold)
    static let title = Font.system(.title2, design: .serif).weight(.semibold)
    static let title3 = Font.system(.title3, design: .serif).weight(.semibold)
    static let headline = Font.system(.headline, design: .default)
    static let body = Font.system(.body)
    static let bodySerif = Font.system(.body, design: .serif)
    static let callout = Font.system(.callout)
    static let caption = Font.system(.caption)
    static let eyebrow = Font.system(.caption, design: .default).weight(.semibold)
    static let number = Font.system(.title, design: .rounded).weight(.semibold)
}

// MARK: - Colour helpers

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// A colour that resolves per trait collection (light / dark).
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// Parses "#RRGGBB" strings stored in models (e.g. category colours).
    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        let value = UInt32(cleaned, radix: 16) ?? 0x39AFC0
        self.init(hex: value)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

/// Palette offered to the user for categories, collections and tags.
enum PaletteChoice: String, CaseIterable, Identifiable {
    case turquoise = "#39AFC0"
    case teal = "#164D58"
    case gold = "#C69B55"
    case earth = "#76503B"
    case jungle = "#647B50"
    case coral = "#C9725B"
    case lagoon = "#2F7F8C"
    case dusk = "#6F6A9A"

    var id: String { rawValue }
    var color: Color { Color(hexString: rawValue) }
}
