import AppKit

/// Finds the app's images. In `MoatBar.app` they sit in `Contents/Resources`
/// (`Scripts/package_app.sh` copies them there); under `swift run` they are in
/// the SwiftPM resource bundle next to the binary. SwiftPM's own `Bundle.module`
/// is not used because it stops the app when the bundle is not where it expects.
enum AppResources {
    static func image(_ name: String) -> NSImage? {
        if let image = Bundle.main.image(forResource: name) {
            return image
        }
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("MoatBar_MoatBar.bundle"),
            Bundle.main.resourceURL?.appendingPathComponent("MoatBar_MoatBar.bundle"),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("MoatBar_MoatBar.bundle"),
        ]
        for url in candidates.compactMap({ $0 }) {
            if let image = Bundle(url: url)?.image(forResource: name) {
                return image
            }
        }
        return nil
    }
}
