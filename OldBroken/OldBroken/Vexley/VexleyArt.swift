import SwiftUI
import UIKit
import ImageIO

/// Loads Vexley's expression GIFs (the authoritative 2D design from the companion app).
@MainActor
enum VexleyArt {
    private static var animated: [VexleyExpression: UIImage] = [:]
    private static var stills: [VexleyExpression: UIImage] = [:]

    static func animatedImage(_ e: VexleyExpression) -> UIImage? {
        if let c = animated[e] { return c }
        guard let frames = loadFrames(e.assetName), !frames.images.isEmpty else { return nil }
        let img = frames.images.count == 1 ? frames.images[0] : UIImage.animatedImage(with: frames.images, duration: frames.duration)
        animated[e] = img
        return img
    }

    static func still(_ e: VexleyExpression) -> UIImage? {
        if let c = stills[e] { return c }
        guard let frames = loadFrames(e.assetName), let first = frames.images.first else { return nil }
        stills[e] = first
        return first
    }

    private static func loadFrames(_ name: String) -> (images: [UIImage], duration: Double)? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "gif"),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        var imgs: [UIImage] = []
        var total = 0.0
        for i in 0..<CGImageSourceGetCount(src) {
            guard let cg = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            imgs.append(UIImage(cgImage: cg))
            var d = 0.1
            if let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any],
               let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                let u = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double ?? 0
                let c = gif[kCGImagePropertyGIFDelayTime] as? Double ?? 0.1
                d = u > 0 ? u : c
                if d < 0.02 { d = 0.1 }
            }
            total += d
        }
        return (imgs, total)
    }
}

/// Plays one expression GIF; swapping `expression` swaps the animation.
struct VexleyFaceView: UIViewRepresentable {
    var expression: VexleyExpression

    func makeUIView(context: Context) -> UIImageView {
        let v = UIImageView()
        v.contentMode = .scaleAspectFit
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        v.setContentHuggingPriority(.defaultLow, for: .vertical)
        v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        v.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        v.image = VexleyArt.animatedImage(expression)
        context.coordinator.current = expression
        return v
    }

    func updateUIView(_ v: UIImageView, context: Context) {
        guard context.coordinator.current != expression else { return }
        context.coordinator.current = expression
        v.image = VexleyArt.animatedImage(expression)
    }

    func makeCoordinator() -> Coord { Coord() }
    final class Coord { var current: VexleyExpression? }
}

/// Textures for the 3D monitor once OLD is running.
@MainActor
enum MonitorImages {
    static func retroRunning() -> UIImage {
        ProcTex.render(CGSize(width: 512, height: 304)) { c, s in
            c.setFillColor(UIColor(red: 0.05, green: 0.12, blue: 0.08, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: s))
            for y in stride(from: 0, to: Int(s.height), by: 16) {
                for x in stride(from: 0, to: Int(s.width), by: 16) where (x / 16 + y / 16) % 3 == 0 {
                    c.setFillColor(UIColor(red: 0.15, green: 0.4, blue: 0.2, alpha: 1).cgColor)
                    c.fill(CGRect(x: x, y: y, width: 16, height: 16))
                }
            }
            c.setFillColor(UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1).cgColor)
            c.fill(CGRect(x: 248, y: 144, width: 16, height: 16))
            scanlines(c, s)
        }
    }

    static func vexleyWatching(expression: VexleyExpression) -> UIImage {
        ProcTex.render(CGSize(width: 512, height: 304)) { c, s in
            c.setFillColor(UIColor(red: 0.04, green: 0.02, blue: 0.05, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: s))
            if let face = VexleyArt.still(expression) {
                face.draw(in: CGRect(x: s.width / 2 - 130, y: 22, width: 260, height: 260))
            }
            scanlines(c, s)
        }
    }

    private static func scanlines(_ c: CGContext, _ s: CGSize) {
        c.setFillColor(UIColor(white: 0, alpha: 0.25).cgColor)
        for y in stride(from: 0, to: Int(s.height), by: 3) {
            c.fill(CGRect(x: 0, y: CGFloat(y), width: s.width, height: 1))
        }
    }
}
