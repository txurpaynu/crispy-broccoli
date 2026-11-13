import UIKit
import SpriteKit

/// 16x16 pixel art drawn in code: the 1998 dev build's tiles and sprites.
/// REPLACEMENT POINT: put real 16x16 PNGs in the bundle named "retro_<key>.png"
/// (e.g. retro_grass.png, retro_player_down.png) and they are used instead.
@MainActor
enum RetroArt {
    private static var cache: [String: SKTexture] = [:]

    static func texture(_ key: String) -> SKTexture {
        if let t = cache[key] { return t }
        let img = UIImage(named: "retro_" + key) ?? draw(key)
        let t = SKTexture(image: img)
        t.filteringMode = .nearest
        cache[key] = t
        return t
    }

    static func key(forTile c: Character, x: Int, y: Int) -> String {
        switch c {
        case ".": return (x * 7 + y * 13) % 5 == 0 ? "grass2" : "grass"
        case ",": return "flowers"
        case "=": return "path"
        case "~": return (x + y) % 2 == 0 ? "water" : "water2"
        case "s": return "sand"
        case "T": return "tree"
        case "R": return "roof"
        case "H": return "wall"
        case "D": return "door"
        case "S": return "sign"
        case "L": return "lh_base"
        case "l": return "lh_top"
        case "F": return "fence"
        case "X": return "missing"
        case "#": return "devwall"
        case "d": return "devdoor"
        case "r": return "devfloor"
        case "b": return "bed"
        case "k": return "terminal"
        case "C": return "chest"
        case "?": return "void"
        default: return "missing"
        }
    }

    // palette
    static let grassA = UIColor(red: 0.35, green: 0.66, blue: 0.29, alpha: 1)
    static let grassB = UIColor(red: 0.27, green: 0.55, blue: 0.24, alpha: 1)
    static let skin = UIColor(red: 0.98, green: 0.8, blue: 0.62, alpha: 1)

    private static func img(_ draw: (CGContext) -> Void) -> UIImage {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1; f.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16), format: f).image { ctx in draw(ctx.cgContext) }
    }

    private static func px(_ c: CGContext, _ col: UIColor, _ x: Int, _ y: Int, _ w: Int = 1, _ h: Int = 1) {
        c.setFillColor(col.cgColor)
        c.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    private static func grass(_ c: CGContext, alt: Bool) {
        px(c, grassA, 0, 0, 16, 16)
        let dots = alt ? [(2, 3), (9, 1), (13, 7), (5, 11), (11, 13), (7, 6)] : [(3, 4), (12, 2), (6, 12), (14, 11)]
        for (x, y) in dots { px(c, grassB, x, y); px(c, grassB, x + 1, y - 1) }
    }

    static func draw(_ key: String) -> UIImage {
        switch key {
        case "grass": return img { grass($0, alt: false) }
        case "grass2": return img { grass($0, alt: true) }
        case "flowers": return img { c in
            grass(c, alt: false)
            for (x, y, col) in [(3, 3, UIColor.white), (10, 5, UIColor.yellow), (6, 11, UIColor(red: 1, green: 0.5, blue: 0.7, alpha: 1)), (12, 12, UIColor.white)] as [(Int, Int, UIColor)] {
                px(c, col, x, y, 2, 2); px(c, .orange, x, y)
            }
        }
        case "path": return img { c in
            px(c, UIColor(red: 0.82, green: 0.7, blue: 0.48, alpha: 1), 0, 0, 16, 16)
            for (x, y) in [(2, 5), (9, 2), (12, 10), (5, 13), (14, 4)] { px(c, UIColor(red: 0.7, green: 0.58, blue: 0.38, alpha: 1), x, y, 2, 1) }
        }
        case "water", "water2": return img { c in
            px(c, UIColor(red: 0.18, green: 0.38, blue: 0.75, alpha: 1), 0, 0, 16, 16)
            let o = key == "water" ? 0 : 4
            for y in stride(from: 3, to: 16, by: 6) { px(c, UIColor(red: 0.45, green: 0.65, blue: 0.95, alpha: 1), (o + y) % 12, y, 4, 1) }
        }
        case "sand": return img { c in
            px(c, UIColor(red: 0.93, green: 0.85, blue: 0.6, alpha: 1), 0, 0, 16, 16)
            for (x, y) in [(3, 3), (11, 6), (6, 12), (13, 13)] { px(c, UIColor(red: 0.85, green: 0.75, blue: 0.5, alpha: 1), x, y) }
        }
        case "tree": return img { c in
            grass(c, alt: false)
            px(c, UIColor(red: 0.45, green: 0.3, blue: 0.15, alpha: 1), 7, 11, 2, 4)
            px(c, UIColor(red: 0.1, green: 0.38, blue: 0.16, alpha: 1), 3, 2, 10, 9)
            px(c, UIColor(red: 0.1, green: 0.38, blue: 0.16, alpha: 1), 2, 4, 12, 5)
            px(c, UIColor(red: 0.2, green: 0.5, blue: 0.22, alpha: 1), 5, 3, 3, 2)
        }
        case "roof": return img { c in
            px(c, UIColor(red: 0.72, green: 0.2, blue: 0.18, alpha: 1), 0, 0, 16, 16)
            for y in stride(from: 3, to: 16, by: 4) { px(c, UIColor(red: 0.55, green: 0.12, blue: 0.12, alpha: 1), 0, y, 16, 1) }
        }
        case "wall": return img { c in
            px(c, UIColor(red: 0.92, green: 0.85, blue: 0.7, alpha: 1), 0, 0, 16, 16)
            px(c, UIColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 1), 4, 5, 4, 4)
            px(c, UIColor(red: 0.5, green: 0.4, blue: 0.3, alpha: 1), 0, 15, 16, 1)
        }
        case "door": return img { c in
            px(c, UIColor(red: 0.92, green: 0.85, blue: 0.7, alpha: 1), 0, 0, 16, 16)
            px(c, UIColor(red: 0.45, green: 0.28, blue: 0.15, alpha: 1), 4, 3, 8, 13)
            px(c, .yellow, 10, 9)
        }
        case "sign": return img { c in
            grass(c, alt: false)
            px(c, UIColor(red: 0.45, green: 0.3, blue: 0.15, alpha: 1), 7, 9, 2, 6)
            px(c, UIColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1), 2, 3, 12, 7)
            px(c, UIColor(red: 0.4, green: 0.25, blue: 0.12, alpha: 1), 4, 5, 8, 1)
            px(c, UIColor(red: 0.4, green: 0.25, blue: 0.12, alpha: 1), 4, 7, 6, 1)
        }
        case "lh_top": return img { c in
            px(c, UIColor(red: 0.93, green: 0.85, blue: 0.6, alpha: 1), 0, 0, 16, 16)
            px(c, UIColor(red: 0.8, green: 0.15, blue: 0.15, alpha: 1), 2, 2, 12, 3)
            px(c, UIColor(red: 1, green: 0.95, blue: 0.5, alpha: 1), 3, 5, 10, 6)
            px(c, .white, 2, 11, 12, 5)
        }
        case "lh_base": return img { c in
            px(c, UIColor(red: 0.93, green: 0.85, blue: 0.6, alpha: 1), 0, 0, 16, 16)
            px(c, .white, 2, 0, 12, 16)
            px(c, UIColor(red: 0.8, green: 0.15, blue: 0.15, alpha: 1), 2, 4, 12, 4)
            px(c, UIColor(red: 0.8, green: 0.15, blue: 0.15, alpha: 1), 2, 12, 12, 4)
        }
        case "fence": return img { c in
            grass(c, alt: false)
            px(c, UIColor(red: 0.85, green: 0.75, blue: 0.6, alpha: 1), 0, 6, 16, 2)
            px(c, UIColor(red: 0.85, green: 0.75, blue: 0.6, alpha: 1), 0, 10, 16, 2)
            px(c, UIColor(red: 0.7, green: 0.6, blue: 0.45, alpha: 1), 2, 3, 3, 12)
            px(c, UIColor(red: 0.7, green: 0.6, blue: 0.45, alpha: 1), 11, 3, 3, 12)
        }
        case "missing": return img { c in
            for y in 0..<4 { for x in 0..<4 { px(c, (x + y) % 2 == 0 ? UIColor.magenta : .black, x * 4, y * 4, 4, 4) } }
        }
        case "devwall": return img { c in
            px(c, UIColor(white: 0.45, alpha: 1), 0, 0, 16, 16)
            px(c, UIColor(white: 0.3, alpha: 1), 0, 0, 16, 1); px(c, UIColor(white: 0.3, alpha: 1), 0, 8, 16, 1)
            px(c, UIColor(white: 0.3, alpha: 1), 5, 0, 1, 8); px(c, UIColor(white: 0.3, alpha: 1), 11, 8, 1, 8)
        }
        case "devdoor": return img { c in
            px(c, UIColor(white: 0.45, alpha: 1), 0, 0, 16, 16)
            px(c, UIColor(white: 0.18, alpha: 1), 3, 2, 10, 14)
            px(c, UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1), 5, 6, 6, 2)
        }
        case "devfloor": return img { c in
            px(c, UIColor(red: 0.12, green: 0.13, blue: 0.2, alpha: 1), 0, 0, 16, 16)
            px(c, UIColor(red: 0.2, green: 0.22, blue: 0.32, alpha: 1), 0, 0, 16, 1)
            px(c, UIColor(red: 0.2, green: 0.22, blue: 0.32, alpha: 1), 0, 0, 1, 16)
        }
        case "bed": return img { c in
            px(c, UIColor(red: 0.12, green: 0.13, blue: 0.2, alpha: 1), 0, 0, 16, 16)
            for y in 0..<4 { for x in 0..<3 { px(c, (x + y) % 2 == 0 ? UIColor.magenta : .black, 2 + x * 4, 1 + y * 4, 4, 4) } }
        }
        case "terminal": return img { c in
            px(c, UIColor(red: 0.12, green: 0.13, blue: 0.2, alpha: 1), 0, 0, 16, 16)
            px(c, UIColor(white: 0.6, alpha: 1), 2, 2, 12, 10)
            px(c, UIColor(red: 0.05, green: 0.2, blue: 0.08, alpha: 1), 3, 3, 10, 8)
            px(c, .green, 4, 5, 5, 1); px(c, .green, 4, 7, 3, 1)
            px(c, UIColor(white: 0.5, alpha: 1), 5, 12, 6, 2)
        }
        case "chest": return img { c in
            grass(c, alt: false)
            px(c, UIColor(red: 0.55, green: 0.33, blue: 0.15, alpha: 1), 2, 5, 12, 9)
            px(c, UIColor(red: 0.4, green: 0.22, blue: 0.1, alpha: 1), 2, 8, 12, 1)
            px(c, .yellow, 7, 8, 2, 2)
        }
        case "void": return img { c in px(c, .black, 0, 0, 16, 16); px(c, UIColor(white: 0.15, alpha: 1), 6, 9) }
        case "player_down", "player_up", "player_left", "player_right": return img { c in drawKid(c, key) }
        case "wren": return img { c in
            px(c, UIColor(white: 0.85, alpha: 1), 4, 1, 8, 4)
            px(c, skin, 5, 4, 6, 4)
            px(c, .black, 6, 5); px(c, .black, 9, 5)
            px(c, UIColor(red: 0.45, green: 0.25, blue: 0.55, alpha: 1), 3, 8, 10, 7)
            px(c, UIColor(red: 0.35, green: 0.18, blue: 0.4, alpha: 1), 3, 14, 10, 1)
        }
        case "fox": return img { c in drawFox(c) }
        default: return img { c in px(c, .magenta, 0, 0, 16, 16) }
        }
    }

    private static func drawKid(_ c: CGContext, _ key: String) {
        let hair = UIColor(red: 0.35, green: 0.2, blue: 0.1, alpha: 1)
        let shirt = UIColor(red: 0.2, green: 0.45, blue: 0.85, alpha: 1)
        let pants = UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1)
        px(c, hair, 4, 1, 8, 3)
        px(c, skin, 4, 3, 8, 5)
        switch key {
        case "player_up": px(c, hair, 4, 3, 8, 4)
        case "player_left": px(c, .black, 5, 5); px(c, hair, 10, 3, 2, 3)
        case "player_right": px(c, .black, 10, 5); px(c, hair, 4, 3, 2, 3)
        default: px(c, .black, 6, 5); px(c, .black, 9, 5)
        }
        px(c, shirt, 4, 8, 8, 4)
        px(c, pants, 5, 12, 6, 3)
        px(c, .black, 5, 15, 2, 1); px(c, .black, 9, 15, 2, 1)
        // the paper lantern
        let lx = key == "player_left" ? 1 : 12
        px(c, UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), lx, 9, 3, 4)
        px(c, UIColor(red: 1, green: 1, blue: 0.7, alpha: 1), lx + 1, 10)
    }

    /// Placeholder in-world Vexley: pink fox, cyan ears, white muzzle, cyan bow tie.
    private static func drawFox(_ c: CGContext) {
        let pink = UIColor(red: 0.96, green: 0.2, blue: 0.55, alpha: 1)
        let cyan = UIColor(red: 0.3, green: 0.85, blue: 0.95, alpha: 1)
        px(c, pink, 3, 1, 3, 4); px(c, pink, 10, 1, 3, 4)
        px(c, cyan, 4, 2, 1, 2); px(c, cyan, 11, 2, 1, 2)
        px(c, pink, 3, 4, 10, 6)
        px(c, .white, 5, 7, 6, 3)
        px(c, .black, 5, 5); px(c, .black, 10, 5); px(c, .black, 7, 8, 2, 1)
        px(c, cyan, 6, 10, 4, 1); px(c, cyan, 7, 11, 2, 1)
        px(c, pink, 4, 11, 8, 4)
        px(c, .white, 6, 12, 4, 3)
        px(c, pink, 12, 10, 3, 3); px(c, .white, 14, 9, 2, 2)
    }
}
