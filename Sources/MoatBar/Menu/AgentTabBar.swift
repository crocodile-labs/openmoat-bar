import AppKit
import MoatBarCore

/// The agent tabs: All, then every agent OpenMoat supports, each with its icon,
/// name and a line in its protection colour. An agent that isn't installed is
/// drawn faded but can still be picked.
///
/// AppKit, not SwiftUI: while a menu is open AppKit runs its event-tracking
/// loop, and SwiftUI state changes did not show until the menu closed. This
/// view takes the click itself and moves a layer-backed selection pill with a
/// Core Animation transition, which runs during tracking (CodexBar's provider
/// switcher is an AppKit view for the same reason).
///
/// More tabs than fit in a row wrap into further rows of equal width, like
/// CodexBar's multi-row switcher, instead of scrolling: a scroll view inside a
/// menu does not take trackpad scrolling reliably during tracking.
final class AgentTabBar: NSView {
    struct Tab {
        let host: String?
        let title: String
        let lineColor: NSColor
        /// The agent isn't installed on this machine.
        var faded = false
    }

    private struct Cell {
        let icon: NSImageView
        let label: NSTextField
        let line: CALayer
    }

    private let tabs: [Tab]
    private(set) var selected: String?
    private let onSelect: (String?) -> Void
    private let pill = CALayer()
    private var cells: [Cell] = []

    /// Most tabs in one row before wrapping.
    static let maxColumns = 5
    static let rowHeight: CGFloat = 50
    private static let inset: CGFloat = 10
    private static let gap: CGFloat = 4
    private static let rowGap: CGFloat = 4
    private static let verticalPadding: CGFloat = 4

    private var columns: Int {
        min(max(self.tabs.count, 1), Self.maxColumns)
    }

    private var rows: Int {
        (self.tabs.count + Self.maxColumns - 1) / Self.maxColumns
    }

    static func height(forTabs count: Int) -> CGFloat {
        let rows = max(1, (count + self.maxColumns - 1) / self.maxColumns)
        return CGFloat(rows) * self.rowHeight + CGFloat(rows - 1) * self.rowGap + self.verticalPadding * 2
    }

    init(width: CGFloat, tabs: [Tab], selected: String?, onSelect: @escaping (String?) -> Void) {
        self.tabs = tabs
        self.selected = selected
        self.onSelect = onSelect
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.height(forTabs: tabs.count)))
        self.wantsLayer = true
        self.pill.cornerRadius = 8
        self.pill.backgroundColor = NSColor.controlAccentColor.cgColor
        self.layer?.addSublayer(self.pill)
        for tab in tabs {
            self.addCell(for: tab)
        }
        self.layoutCells()
        self.applySelection(animated: false)
        self.setAccessibilityRole(.tabGroup)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    // MARK: - Layout

    private func addCell(for tab: Tab) {
        let icon = NSImageView()
        if let host = tab.host, let image = AppResources.agentIcon(host) {
            icon.image = image
        } else {
            icon.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
        }
        icon.imageScaling = .scaleProportionallyUpOrDown
        let label = NSTextField(labelWithString: tab.title)
        label.font = .systemFont(ofSize: 11)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        let line = CALayer()
        line.backgroundColor = tab.lineColor.cgColor
        line.cornerRadius = 1.5
        line.opacity = tab.faded ? 0.5 : 1
        self.addSubview(icon)
        self.addSubview(label)
        self.layer?.addSublayer(line)
        self.cells.append(Cell(icon: icon, label: label, line: line))
    }

    /// The frame of tab `index`: rows fill top to bottom, each row left to right.
    private func tabFrame(_ index: Int) -> NSRect {
        let columns = CGFloat(self.columns)
        let usable = self.bounds.width - Self.inset * 2 - Self.gap * (columns - 1)
        let width = usable / columns
        let row = index / Self.maxColumns
        let column = index % Self.maxColumns
        let x = Self.inset + CGFloat(column) * (width + Self.gap)
        let top = self.bounds.height - Self.verticalPadding - CGFloat(row) * (Self.rowHeight + Self.rowGap)
        return NSRect(x: x, y: top - Self.rowHeight, width: width, height: Self.rowHeight)
    }

    private func layoutCells() {
        for (index, cell) in self.cells.enumerated() {
            let frame = self.tabFrame(index)
            cell.icon.frame = NSRect(x: frame.midX - 8, y: frame.maxY - 22, width: 16, height: 16)
            cell.label.frame = NSRect(x: frame.minX + 2, y: frame.minY + 9, width: frame.width - 4, height: 15)
            cell.line.frame = NSRect(x: frame.minX + 12, y: frame.minY + 4, width: frame.width - 24, height: 3)
        }
    }

    // MARK: - Selection

    private var selectedIndex: Int {
        self.tabs.firstIndex { $0.host == self.selected } ?? 0
    }

    func select(_ host: String?, animated: Bool) {
        self.selected = host
        self.applySelection(animated: animated)
    }

    private func applySelection(animated: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(animated ? 0.2 : 0)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        CATransaction.setDisableActions(!animated)
        self.pill.frame = self.tabFrame(self.selectedIndex)
        CATransaction.commit()
        for (index, cell) in self.cells.enumerated() {
            let on = index == self.selectedIndex
            let faded = self.tabs[index].faded && !on
            let color: NSColor = on ? .white : (faded ? .tertiaryLabelColor : .labelColor)
            cell.label.textColor = color
            cell.label.font = .systemFont(ofSize: 11, weight: on ? .semibold : .regular)
            cell.icon.contentTintColor = color
        }
    }

    // MARK: - Mouse

    /// A menu sends the click to the item's view; take both halves of it so the
    /// menu does not treat it as choosing an item and close.
    override func mouseDown(with _: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        let point = self.convert(event.locationInWindow, from: nil)
        guard let index = self.tabs.indices.first(where: { self.tabFrame($0).contains(point) }) else {
            return
        }
        let host = self.tabs[index].host
        guard host != self.selected else {
            return
        }
        self.select(host, animated: true)
        self.onSelect(host)
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }
}
