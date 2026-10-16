import AppKit
import MoatBarCore
import SwiftUI

// Renders the README screenshots from the app's own views with made-up data:
//   Scripts/snapshots.sh  →  docs/images/*.png
// The menu is drawn item by item (an NSMenu can't be captured offscreen), so the
// window chrome is approximate; every row is the real view the menu shows.

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/images")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

_ = NSApplication.shared
NSApp.appearance = NSAppearance(named: .aqua)

let calendar = Calendar.current
let now = calendar.date(bySettingHour: 11, minute: 30, second: 0, of: Date()) ?? Date()
let snapshot = Sample.snapshot(now: now)

// MARK: - Drawing helpers

func png(_ view: NSView, scale: CGFloat = 2) -> Data {
    view.layoutSubtreeIfNeeded()
    let size = view.bounds.size
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width * scale),
        pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = size
    view.cacheDisplay(in: view.bounds, to: rep)
    // Layer-only content (the tab bar's pill and lines) is drawn on top.
    if let context = NSGraphicsContext(bitmapImageRep: rep) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        drawLayers(of: view, in: context.cgContext, origin: .zero)
        NSGraphicsContext.restoreGraphicsState()
    }
    return rep.representation(using: .png, properties: [:])!
}

/// Draw the tab bars' layers, which `cacheDisplay` skips.
func drawLayers(of view: NSView, in context: CGContext, origin: CGPoint) {
    for sub in view.subviews {
        let frame = sub.frame
        let point = CGPoint(x: origin.x + frame.minX, y: origin.y + frame.minY)
        if let bar = sub as? AgentTabBar, let layer = bar.layer {
            context.saveGState()
            context.translateBy(x: point.x, y: point.y)
            for sublayer in layer.sublayers ?? [] {
                context.saveGState()
                context.translateBy(x: sublayer.frame.minX, y: sublayer.frame.minY)
                let path = CGPath(
                    roundedRect: CGRect(origin: .zero, size: sublayer.bounds.size),
                    cornerWidth: sublayer.cornerRadius,
                    cornerHeight: sublayer.cornerRadius,
                    transform: nil
                )
                if let color = sublayer.backgroundColor {
                    context.addPath(path)
                    context.setFillColor(color)
                    context.fillPath()
                }
                context.restoreGState()
            }
            context.restoreGState()
            // Draw the bar's labels and icons again over the pill.
            for child in bar.subviews {
                let rect = child.frame.offsetBy(dx: point.x, dy: point.y)
                if let label = child as? NSTextField {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    let text = NSAttributedString(string: label.stringValue, attributes: [
                        .font: label.font ?? NSFont.systemFont(ofSize: 11),
                        .foregroundColor: label.textColor ?? NSColor.labelColor,
                        .paragraphStyle: style,
                    ])
                    text.draw(in: rect)
                } else if let icon = child as? NSImageView, let image = icon.image {
                    tinted(image, icon.contentTintColor ?? .labelColor).draw(in: rect)
                }
            }
        } else {
            drawLayers(of: sub, in: context, origin: point)
        }
    }
}

/// A template image filled with one colour.
func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    NSImage(size: image.size, flipped: false) { rect in
        image.draw(in: rect)
        color.set()
        rect.fill(using: .sourceAtop)
        return true
    }
}

/// A plain menu row for items without a view (footer, headers, separators).
struct PlainRow: View {
    let title: String
    let key: String
    let enabled: Bool

    var body: some View {
        HStack {
            Text(self.title).foregroundColor(self.enabled ? .primary : .secondary)
            Spacer()
            if !self.key.isEmpty {
                Text("⌘\(self.key.uppercased())").foregroundColor(.secondary)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 14)
        .frame(height: 22)
    }
}

/// Lay out a menu's items the way the menu shows them, in a rounded panel.
func panel(for menu: NSMenu, width: CGFloat, highlight: Int? = nil) -> NSView {
    var rows: [NSView] = []
    for (index, item) in menu.items.enumerated() {
        if item.isSeparatorItem {
            let line = NSBox(frame: NSRect(x: 0, y: 0, width: width, height: 11))
            line.boxType = .custom
            line.borderWidth = 0
            line.fillColor = .clear
            let rule = NSBox(frame: NSRect(x: 12, y: 5, width: width - 24, height: 1))
            rule.boxType = .custom
            rule.borderWidth = 0
            rule.fillColor = NSColor.separatorColor
            line.addSubview(rule)
            rows.append(line)
        } else if let view = item.view {
            if let row = view as? HostedMenuRow {
                row.previewHighlighted = index == highlight
                row.needsDisplay = true
            }
            view.frame.size.width = width
            rows.append(view)
        } else {
            let plain = PlainRow(title: item.title, key: item.keyEquivalent, enabled: item.isEnabled)
            let row = NSHostingView(rootView: plain)
            row.frame = NSRect(x: 0, y: 0, width: width, height: 22)
            rows.append(row)
        }
    }
    let padding: CGFloat = 6
    let height = rows.reduce(0) { $0 + $1.frame.height } + padding * 2
    let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
    container.wantsLayer = true
    container.layer?.backgroundColor = NSColor(calibratedWhite: 0.96, alpha: 1).cgColor
    container.layer?.cornerRadius = 10
    container.layer?.borderColor = NSColor(calibratedWhite: 0.78, alpha: 1).cgColor
    container.layer?.borderWidth = 0.5
    var y = height - padding
    for row in rows {
        y -= row.frame.height
        // A fixed slot per row: hosting views lay themselves out at their
        // superview's origin, so each gets a superview of its own.
        let slot = NSView(frame: NSRect(x: 0, y: y, width: width, height: row.frame.height))
        row.frame = NSRect(x: 0, y: 0, width: width, height: row.frame.height)
        row.autoresizingMask = []
        slot.addSubview(row)
        container.addSubview(slot)
    }
    return container
}

/// Open a lazy submenu so its items exist.
func opened(_ menu: NSMenu?) -> NSMenu? {
    guard let menu else {
        return nil
    }
    (menu as? LazyMenu)?.menuNeedsUpdate(menu)
    return menu
}

/// A backdrop: menu bar strip with the croc icon, then the panels side by side.
func scene(panels: [(NSView, CGFloat)], size: NSSize) -> NSView {
    let root = NSView(frame: NSRect(origin: .zero, size: size))
    root.wantsLayer = true
    let gradient = CAGradientLayer()
    gradient.frame = root.bounds
    gradient.colors = [NSColor(calibratedRed: 0.36, green: 0.62, blue: 0.5, alpha: 1).cgColor,
                       NSColor(calibratedRed: 0.11, green: 0.35, blue: 0.27, alpha: 1).cgColor]
    root.layer?.addSublayer(gradient)
    let bar = NSView(frame: NSRect(x: 0, y: size.height - 24, width: size.width, height: 24))
    bar.wantsLayer = true
    bar.layer?.backgroundColor = NSColor(calibratedWhite: 1, alpha: 0.35).cgColor
    root.addSubview(bar)
    let icon = NSImageView(image: IconRenderer.image(for: .newBlocks))
    icon.frame = NSRect(x: size.width - 110, y: size.height - 23, width: icon.image?.size.width ?? 40, height: 22)
    root.addSubview(icon)
    var x = size.width - 16
    for (view, top) in panels {
        x -= view.frame.width
        view.frame.origin = NSPoint(x: x, y: size.height - 30 - top - view.frame.height)
        root.addSubview(view)
        x -= 4
    }
    return root
}

// MARK: - Menu with Blocked → list → one decision

let builder = MenuBuilder(
    snapshot: snapshot,
    error: nil,
    selectedHost: nil,
    onSelectHost: { _ in },
    onRefresh: {},
    onSettings: {},
    onActivity: { _ in },
    now: now
)
let menu = NSMenu()
builder.fill(menu)
let blockedIndex = menu.items.firstIndex { $0.view is HostedMenuRow } ?? 0
let main = panel(for: menu, width: menuWidth, highlight: blockedIndex)

let list = opened(menu.items[blockedIndex].submenu)!
let firstEvent = list.items.firstIndex { $0.view is HostedMenuRow } ?? 1
let listPanel = panel(for: list, width: MenuBuilder.submenuWidth, highlight: firstEvent)
let decision = opened(list.items[firstEvent].submenu)!
let decisionPanel = panel(for: decision, width: MenuBuilder.submenuWidth)

/// Height a menu item takes in `panel`.
func rowHeight(_ item: NSMenuItem) -> CGFloat {
    item.isSeparatorItem ? 11 : (item.view?.frame.height ?? 22)
}

let rowTop = menu.items.prefix(blockedIndex).reduce(CGFloat(6)) { $0 + rowHeight($1) }
let eventTop = list.items.prefix(firstEvent).reduce(rowTop) { $0 + rowHeight($1) }
let sceneHeight = max(main.frame.height, eventTop + decisionPanel.frame.height) + 60
let menuScene = scene(
    panels: [(main, 0), (listPanel, rowTop - 6), (decisionPanel, eventTop - 6)],
    size: NSSize(width: menuWidth + MenuBuilder.submenuWidth * 2 + 60, height: sceneHeight)
)
try png(menuScene).write(to: outDir.appendingPathComponent("menu.png"))

// MARK: - One agent's tab

let agentBuilder = MenuBuilder(
    snapshot: snapshot,
    error: nil,
    selectedHost: "claude-code",
    onSelectHost: { _ in },
    onRefresh: {},
    onSettings: {},
    onActivity: { _ in },
    now: now
)
let agentMenu = NSMenu()
agentBuilder.fill(agentMenu)
let agentPanel = panel(for: agentMenu, width: menuWidth)
let agentScene = scene(
    panels: [(agentPanel, 0)],
    size: NSSize(width: menuWidth + 60, height: agentPanel.frame.height + 60)
)
try png(agentScene).write(to: outDir.appendingPathComponent("agent-tab.png"))

// MARK: - Welcome, Activity, icon states

let welcome = NSHostingView(rootView: WelcomeView(preferences: Preferences.shared, onOpenMenu: {}, onQuit: {})
    .background(Color(nsColor: .windowBackgroundColor)))
welcome.frame = NSRect(x: 0, y: 0, width: 460, height: welcome.fittingSize.height)
try png(welcome).write(to: outDir.appendingPathComponent("welcome.png"))

let activity = ActivityModel()
activity.show(snapshot)
let activityRoot = ActivityView(model: activity).background(Color(nsColor: .windowBackgroundColor))
let activityView = NSHostingView(rootView: activityRoot)
activityView.frame = NSRect(x: 0, y: 0, width: 1040, height: 600)
try png(activityView).write(to: outDir.appendingPathComponent("activity.png"))

let states: [(IconState, String)] = [
    (.quiet, "All protected"), (.newBlocks, "New blocks"), (.attention, "Needs a look"),
    (.unprotected, "Not protected"), (.unavailable, "moat missing"),
]
let strip = NSView(frame: NSRect(x: 0, y: 0, width: 150 * CGFloat(states.count), height: 70))
strip.wantsLayer = true
strip.layer?.backgroundColor = NSColor(calibratedRed: 0.11, green: 0.35, blue: 0.27, alpha: 1).cgColor
for (index, (state, label)) in states.enumerated() {
    let image = NSImageView(image: IconRenderer.image(for: state))
    image.frame = NSRect(x: 150 * CGFloat(index) + 50, y: 32, width: image.image?.size.width ?? 44, height: 22)
    strip.addSubview(image)
    let text = NSTextField(labelWithString: label)
    text.textColor = .white
    text.font = .systemFont(ofSize: 12, weight: .medium)
    text.alignment = .center
    text.frame = NSRect(x: 150 * CGFloat(index), y: 8, width: 150, height: 18)
    strip.addSubview(text)
}
try png(strip).write(to: outDir.appendingPathComponent("icon-states.png"))

print("wrote", outDir.path)
