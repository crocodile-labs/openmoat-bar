import AppKit
import SwiftUI

/// Whether the menu row a SwiftUI view sits in is highlighted. Rows draw their
/// own selection, the way CodexBar's menu cards do, so text and badges can
/// switch to the selection colour.
final class MenuRowState: ObservableObject {
    @Published var highlighted = false
}

/// Colours for a row. A highlighted row gets a light accent tint behind it and
/// keeps its normal text colours, so it reads the same whether or not SwiftUI
/// re-renders during menu tracking.
enum RowStyle {
    static func primary(_: Bool) -> Color {
        Color(nsColor: .labelColor)
    }

    static func secondary(_: Bool) -> Color {
        Color(nsColor: .secondaryLabelColor)
    }

    static func tint(_: Bool, _ color: Color) -> Color {
        color
    }

    static let highlight = NSColor.controlAccentColor.withAlphaComponent(0.2)
}

/// An `NSView` for a menu item that hosts SwiftUI, paints the selection itself,
/// and handles clicks. AppKit redraws a view-based item when its highlight
/// changes, so `draw` is where the highlight is read.
final class HostedMenuRow: NSView {
    let state = MenuRowState()
    private let host: NSHostingView<AnyView>
    private let onClick: (() -> Void)?

    init(width: CGFloat, onClick: (() -> Void)?, content: (MenuRowState) -> AnyView) {
        self.onClick = onClick
        self.host = NSHostingView(rootView: AnyView(EmptyView()))
        super.init(frame: .zero)
        self.host.rootView = content(self.state)
        self.addSubview(self.host)
        let height = self.measure(width: width)
        self.frame = NSRect(x: 0, y: 0, width: width, height: height)
        self.host.frame = self.bounds
        self.host.autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    private func measure(width: CGFloat) -> CGFloat {
        self.host.frame = NSRect(x: 0, y: 0, width: width, height: 1)
        self.host.layoutSubtreeIfNeeded()
        return ceil(self.host.fittingSize.height)
    }

    /// Draw as highlighted outside a live menu (README screenshots).
    var previewHighlighted = false

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = self.previewHighlighted || (self.enclosingMenuItem?.isHighlighted ?? false)
        if highlighted != self.state.highlighted {
            self.state.highlighted = highlighted
        }
        if highlighted {
            RowStyle.highlight.setFill()
            NSBezierPath(roundedRect: self.bounds.insetBy(dx: 5, dy: 0), xRadius: 4, yRadius: 4).fill()
        }
        super.draw(dirtyRect)
    }

    override func mouseUp(with event: NSEvent) {
        guard let item = self.enclosingMenuItem, item.submenu == nil, let onClick = self.onClick else {
            super.mouseUp(with: event)
            return
        }
        item.menu?.cancelTracking()
        onClick()
    }
}

/// A menu item whose content is a SwiftUI row.
func rowItem(
    width: CGFloat = menuWidth,
    submenu: NSMenu? = nil,
    onClick: (() -> Void)? = nil,
    content: @escaping (MenuRowState) -> AnyView
) -> NSMenuItem {
    let item = NSMenuItem()
    item.view = HostedMenuRow(width: width, onClick: onClick, content: content)
    item.submenu = submenu
    item.isEnabled = submenu != nil || onClick != nil
    return item
}

/// A submenu built the first time it opens, so a long list does not build
/// every decision view up front (CodexBar hydrates hosted submenus the same way).
final class LazyMenu: NSMenu, NSMenuDelegate {
    private var build: ((NSMenu) -> Void)?

    init(width: CGFloat = menuWidth, build: @escaping (NSMenu) -> Void) {
        self.build = build
        super.init(title: "")
        self.autoenablesItems = false
        self.minimumWidth = width
        self.delegate = self
        // AppKit only offers to open a submenu that has items.
        self.addItem(NSMenuItem(title: "", action: nil, keyEquivalent: ""))
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let build = self.build else {
            return
        }
        self.build = nil
        menu.removeAllItems()
        build(menu)
    }
}
