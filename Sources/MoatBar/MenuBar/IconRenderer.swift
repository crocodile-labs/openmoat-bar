import AppKit
import MoatBarCore

/// Draws the menu bar icon: the OpenMoat croc, marked for the current state.
enum IconRenderer {
    /// Menu bar height is 22 pt; the croc is 16 pt tall.
    static let logoHeight: CGFloat = 16

    static let logo: NSImage? = AppResources.image("logo-float")

    static func image(for state: IconState) -> NSImage {
        guard let logo = self.logo else {
            return NSImage(size: NSSize(width: 18, height: 18))
        }
        let logoSize = NSSize(width: self.logoHeight * logo.size.width / logo.size.height, height: self.logoHeight)
        let padding: CGFloat = 3
        let size = NSSize(width: logoSize.width + padding * 2, height: logoSize.height + 4)

        let image = NSImage(size: size, flipped: false) { rect in
            let logoRect = NSRect(
                x: padding,
                y: (rect.height - logoSize.height) / 2,
                width: logoSize.width,
                height: logoSize.height
            )
            switch state {
            case .unprotected:
                self.fillBackground(rect, color: .systemRed)
            case .attention:
                self.fillBackground(rect, color: .systemOrange)
            default:
                break
            }
            let alpha: CGFloat = state == .unavailable ? 0.4 : 1
            logo.draw(in: logoRect, from: .zero, operation: .sourceOver, fraction: alpha)
            if state == .newBlocks {
                let dot = NSRect(x: rect.maxX - 6, y: rect.maxY - 6, width: 5, height: 5)
                NSColor.systemRed.setFill()
                NSBezierPath(ovalIn: dot).fill()
            }
            return true
        }
        image.accessibilityDescription = state.accessibilityLabel
        return image
    }

    private static func fillBackground(_ rect: NSRect, color: NSColor) {
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
    }
}
