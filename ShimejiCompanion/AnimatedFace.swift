import SwiftUI
import UIKit
import ImageIO

/// Loads the animated GIF faces bundled in ShimejiCompanion/Expressions once and caches them.
/// To change a face, replace the GIF with the same file name (transparent background, square).
@MainActor
enum FaceLibrary {
    private static var cache: [Face: UIImage] = [:]

    /// True when the GIFs are in the app bundle (otherwise the drawn blob is used).
    static let available: Bool = Bundle.main.url(forResource: Face.happy.rawValue, withExtension: "gif") != nil

    static func image(for face: Face) -> UIImage? {
        if let cached = cache[face] { return cached }
        guard let url = Bundle.main.url(forResource: face.rawValue, withExtension: "gif"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        var frames: [UIImage] = []
        var total: Double = 0
        for i in 0..<CGImageSourceGetCount(source) {
            guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            frames.append(UIImage(cgImage: cg))
            total += frameDuration(source, i)
        }
        guard !frames.isEmpty else { return nil }
        let image = frames.count == 1 ? frames[0] : UIImage.animatedImage(with: frames, duration: total)
        cache[face] = image
        return image
    }

    private static func frameDuration(_ source: CGImageSource, _ index: Int) -> Double {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else { return 0.1 }
        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double ?? 0
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double ?? 0.1
        let d = unclamped > 0 ? unclamped : clamped
        return d < 0.02 ? 0.1 : d
    }
}

/// Plays one face GIF. Changing `face` swaps the animation instantly.
struct AnimatedFaceView: UIViewRepresentable {
    var face: Face

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.image = FaceLibrary.image(for: face)
        context.coordinator.face = face
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        guard context.coordinator.face != face else { return }
        context.coordinator.face = face
        view.image = FaceLibrary.image(for: face)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var face: Face?
    }
}
