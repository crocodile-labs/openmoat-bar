import AppKit
import MoatBarCore

/// The agent tabs: All, then each installed agent with its icon, name and a
/// line in its protection colour.
///
/// AppKit, not SwiftUI: while a menu is open AppKit runs its event-tracking
/// loop, and SwiftUI state changes did not show until the menu closed. This
/// view takes the click itself and moves a layer-backed selection pill with a
/// Core Animation transition, which runs during tracking (CodexBar's provider
/// switcher is an AppKit view for the same reason).
final class AgentTabBar: NSView {
    struct Tab {
        let host: String?
        let title: String
        let lineColor: NSColor
    }

    private let tabs: [Tab]
    private(set) var selected: String?
    private let onSelect: (String?) -> Void

    private let pill = CALayer()
    private struct Cell {
        let icon: NSImageView
        let label: NSTextField
        let line: CALayer
    }

    private var cells: [Cell] = []

    static let height: CGFloat = 58
    private static let inset: CGFloat = 10
    private static let gap: CGFloat = 4

    init(width: CGFloat, tabs: [Tab], selected: String?, onSelect: @escaping (String?) -> Void) {
        self.tabs = tabs
        self.selected = selected
        self.onSelect = onSelect
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.height))
        self.wantsLayer = true
        self.pill.cornerRadius = 8
        self.pill.backgroundColor = NSColor.controlAccentColor.cgColor
        self.layer?.addSublayer(self.pill)
        for tab in tabs {
            self.addCell(for: tab)
        }
        self.layoutCells()
        self.applySelection(animated: false)
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
        let line = CALayer()
        line.backgroundColor = tab.lineColor.cgColor
        line.cornerRadius = 1.5
        self.addSubview(icon)
        self.addSubview(label)
        self.layer?.addSublayer(line)
        self.cells.append(Cell(icon: icon, label: label, line: line))
    }

    private func tabFrame(_ index: Int) -> NSRect {
        let count = CGFloat(max(self.tabs.count, 1))
        let usable = self.bounds.width - Self.inset * 2 - Self.gap * (count - 1)
        let width = usable / count
        let x = Self.inset + CGFloat(index) * (width + Self.gap)
        return NSRect(x: x, y: 4, width: width, height: Self.height - 8)
    }

    private func layoutCells() {
        for (index, cell) in self.cells.enumerated() {
            let frame = self.tabFrame(index)
            cell.icon.frame = NSRect(x: frame.midX - 8, y: frame.maxY - 22, width: 16, height: 16)
            cell.label.frame = NSRect(x: frame.minX, y: frame.minY + 9, width: frame.width, height: 15)
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
            let color: NSColor = on ? .white : .labelColor
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
