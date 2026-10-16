import AppKit

/// A menu row that copies a command and stays open.
///
/// A normal menu item closes the menu when clicked, which leaves no sign that
/// anything was copied. This row takes the click itself, copies, and swaps its
/// hint for "Copied" so the person can keep reading. It is AppKit so the change
/// draws while the menu is tracking.
final class CopyMenuRow: NSView {
    private let command: String
    private let title = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private let hint = NSTextField(labelWithString: "Copy")
    private var resetHint: DispatchWorkItem?

    static let rowHeight: CGFloat = 40

    /// - Parameters:
    ///   - title: what the command is for ("Copy check command").
    ///   - command: the exact text copied, shown under the title.
    init(title: String, command: String, width: CGFloat) {
        self.command = command
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.rowHeight))

        self.title.stringValue = title
        self.title.font = .systemFont(ofSize: 13)
        self.detail.stringValue = command
        self.detail.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        self.detail.textColor = .secondaryLabelColor
        self.detail.lineBreakMode = .byTruncatingMiddle
        self.hint.font = .systemFont(ofSize: 12, weight: .medium)
        self.hint.textColor = .controlAccentColor
        self.hint.alignment = .right
        for label in [self.title, self.detail, self.hint] {
            self.addSubview(label)
        }
        self.setAccessibilityRole(.button)
        self.setAccessibilityLabel("\(title): \(command)")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func layout() {
        super.layout()
        let inset: CGFloat = 14
        let hintWidth: CGFloat = 64
        let textWidth = self.bounds.width - inset * 2 - hintWidth - 8
        self.title.frame = NSRect(x: inset, y: 19, width: textWidth, height: 17)
        self.detail.frame = NSRect(x: inset, y: 4, width: textWidth, height: 15)
        self.hint.frame = NSRect(x: self.bounds.width - inset - hintWidth, y: 12, width: hintWidth, height: 16)
    }

    override func draw(_ dirtyRect: NSRect) {
        if self.enclosingMenuItem?.isHighlighted ?? false {
            RowStyle.highlight.setFill()
            NSBezierPath(roundedRect: self.bounds.insetBy(dx: 5, dy: 0), xRadius: 4, yRadius: 4).fill()
        }
        super.draw(dirtyRect)
    }

    /// Swallow the press so the menu does not treat it as choosing an item.
    override func mouseDown(with _: NSEvent) {}

    override func mouseUp(with _: NSEvent) {
        Actions.copy(self.command)
        self.hint.stringValue = "Copied ✓"
        self.hint.textColor = .systemGreen
        self.resetHint?.cancel()
        let reset = DispatchWorkItem { [weak self] in
            self?.hint.stringValue = "Copy"
            self?.hint.textColor = .controlAccentColor
        }
        self.resetHint = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: reset)
    }
}

/// A menu item that copies `command` and keeps the menu open.
func copyItem(_ title: String, command: String, width: CGFloat = menuWidth) -> NSMenuItem {
    let item = NSMenuItem()
    item.view = CopyMenuRow(title: title, command: command, width: width)
    item.toolTip = "Copies \(command) to paste into Terminal"
    return item
}
