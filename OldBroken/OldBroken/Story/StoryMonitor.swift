import UIKit

/// What the 3D monitor shows in the apartment, chapter by chapter.
@MainActor
enum StoryMonitor {
    static let pink = UIColor(red: 1, green: 0.45, blue: 0.75, alpha: 1)
    static let blue = UIColor(red: 0.55, green: 0.7, blue: 1, alpha: 1)

    static func image(for s: GameSession) -> (UIImage, UIColor)? {
        switch s.day {
        case 1:
            return nil
        case 2:
            if s.has("ate_dinner") && !s.has("ch2_read_log") { return (MonitorImages.messagesWaiting(), pink) }
            return (MonitorImages.overhaul(), pink)
        case 3 where s.has("vx_on_desktop"):
            return (MonitorImages.desktopWithVexley(), pink)
        default:
            if s.has("vx_on_desktop") { return (MonitorImages.desktopWithVexley(), pink) }
            return (ProcTex.monitorIdle(), blue)
        }
    }
}

extension MonitorImages {
    static func off() -> UIImage {
        ProcTex.render(CGSize(width: 64, height: 38)) { c, s in
            c.setFillColor(UIColor(white: 0.015, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: s))
        }
    }

    /// The VX edition title screen, seen from across the room.
    static func overhaul() -> UIImage {
        ProcTex.render(CGSize(width: 512, height: 304)) { c, s in
            let colors = [UIColor(red: 0.04, green: 0.05, blue: 0.2, alpha: 1).cgColor,
                          UIColor(red: 0.32, green: 0.1, blue: 0.36, alpha: 1).cgColor,
                          UIColor(red: 0.95, green: 0.45, blue: 0.5, alpha: 1).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.6, 1])!
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: s.height), options: [])
            for i in 0..<12 {
                let x = CGFloat((i * 211) % 512), y = CGFloat(40 + (i * 97) % 220)
                c.setFillColor(UIColor(red: 1, green: 0.75, blue: 0.4, alpha: 0.85).cgColor)
                c.fill(CGRect(x: x, y: y, width: 6, height: 9))
            }
            let p = NSMutableParagraphStyle(); p.alignment = .left
            let t: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 44, weight: .black),
                                                    .foregroundColor: UIColor(red: 1, green: 0.85, blue: 0.65, alpha: 1), .paragraphStyle: p]
            ("PAPERLIGHT" as NSString).draw(in: CGRect(x: 28, y: 46, width: 320, height: 60), withAttributes: t)
            for i in 0..<4 {
                c.setFillColor(UIColor(red: 1, green: 0.4, blue: 0.7, alpha: 0.55).cgColor)
                let r = CGRect(x: 30, y: 130 + CGFloat(i) * 32, width: 170, height: 22)
                c.addPath(UIBezierPath(roundedRect: r, cornerRadius: 11).cgPath)
                c.fillPath()
            }
            if let face = VexleyArt.still(.happy) {
                face.draw(in: CGRect(x: 300, y: 70, width: 190, height: 190))
            }
        }
    }

    /// The purple desktop, and him, standing on the taskbar.
    static func desktopWithVexley() -> UIImage {
        ProcTex.render(CGSize(width: 512, height: 304)) { c, s in
            let colors = [UIColor(red: 0.12, green: 0.05, blue: 0.18, alpha: 1).cgColor,
                          UIColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: s.height), options: [])
            c.setFillColor(UIColor(white: 0, alpha: 0.7).cgColor)
            c.fill(CGRect(x: 0, y: s.height - 26, width: s.width, height: 26))
            for i in 0..<5 {
                c.setFillColor(UIColor(white: 1, alpha: 0.12).cgColor)
                c.fill(CGRect(x: 14, y: 14 + CGFloat(i) * 44, width: 30, height: 30))
            }
            if let face = VexleyArt.still(.happy) {
                face.draw(in: CGRect(x: 330, y: s.height - 26 - 110, width: 110, height: 110))
            }
        }
    }

    static func messagesWaiting() -> UIImage {
        ProcTex.render(CGSize(width: 512, height: 304)) { c, s in
            c.setFillColor(UIColor(red: 0.08, green: 0.03, blue: 0.09, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: s))
            for i in 0..<9 {
                let w = CGFloat(160 + (i * 53) % 220)
                c.setFillColor(UIColor(red: 0.45, green: 0.1, blue: 0.32, alpha: 1).cgColor)
                c.addPath(UIBezierPath(roundedRect: CGRect(x: 60, y: 16 + CGFloat(i) * 31, width: w, height: 22), cornerRadius: 9).cgPath)
                c.fillPath()
            }
        }
    }
}
