import AppKit

/// The Refresh row. It stays in the menu across rebuilds and keeps the menu
/// open when clicked: it spins while moat is read, then says when the data is
/// from, and the content above it updates in place (as CodexBar's persistent
/// Refresh row does). AppKit so it draws while the menu is tracking; the
/// spinner animates on its own thread.
final class RefreshMenuRow: NSView {
    enum State: Equatable {
        case idle
        case refreshing
        case done(Date)
        case failed(String)
    }

    var state: State = .idle {
        didSet { self.render() }
    }

    /// Called when the row is clicked while not already refreshing.
    var onRefresh: (() -> Void)?

    private let title = NSTextField(labelWithString: "Refresh")
    private let status = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()
    private var settle: DispatchWorkItem?

    static let rowHeight: CGFloat = 24

    init(width: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.rowHeight))
        self.title.font = .menuFont(ofSize: 0)
        self.status.font = .systemFont(ofSize: 12)
        self.status.alignment = .right
        self.spinner.style = .spinning
        self.spinner.controlSize = .small
        self.spinner.isDisplayedWhenStopped = false
        self.spinner.usesThreadedAnimation = true
        for view in [self.title, self.status, self.spinner] {
            self.addSubview(view)
        }
        self.setAccessibilityRole(.button)
        self.setAccessibilityLabel("Refresh")
        self.render()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func layout() {
        super.layout()
        let inset: CGFloat = 14
        self.title.frame = NSRect(x: inset, y: 3, width: 140, height: 17)
        self.spinner.frame = NSRect(x: self.bounds.width - inset - 16, y: 4, width: 16, height: 16)
        let statusRight = self.state == .refreshing ? self.spinner.frame.minX - 6 : self.bounds.width - inset
        self.status.frame = NSRect(x: inset + 140, y: 4, width: statusRight - inset - 140, height: 16)
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
        guard self.state != .refreshing else {
            return
        }
        self.onRefresh?()
    }

    private func render() {
        self.settle?.cancel()
        switch self.state {
        case .idle:
            self.status.stringValue = "⌘R"
            self.status.textColor = .tertiaryLabelColor
            self.spinner.stopAnimation(nil)
        case .refreshing:
            self.status.stringValue = "Reading moat…"
            self.status.textColor = .secondaryLabelColor
            self.spinner.startAnimation(nil)
        case .done:
            self.status.stringValue = "Updated just now"
            self.status.textColor = .systemGreen
            self.spinner.stopAnimation(nil)
            self.settleBack(after: 3)
        case let .failed(message):
            self.status.stringValue = message
            self.status.textColor = .systemRed
            self.spinner.stopAnimation(nil)
            self.settleBack(after: 5)
        }
        self.needsLayout = true
    }

    /// Go back to showing the shortcut after a while.
    private func settleBack(after seconds: TimeInterval) {
        let work = DispatchWorkItem { [weak self] in
            self?.state = .idle
        }
        self.settle = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}
