pragma Singleton
import QtQuick

// Colours and sizes for the Quick View. Text and backgrounds follow the
// desktop's palette (light or dark, KDE, GNOME or Windows); the verdict and
// level colours are the macOS app's, lighter on a dark background.
QtObject {
    id: theme

    readonly property SystemPalette palette: SystemPalette { colorGroup: SystemPalette.Active }
    readonly property bool dark: palette.window.hslLightness < 0.5

    readonly property color window: palette.window
    readonly property color text: palette.windowText
    readonly property color secondary: Qt.rgba(text.r, text.g, text.b, 0.62)
    readonly property color tertiary: Qt.rgba(text.r, text.g, text.b, 0.4)
    readonly property color divider: Qt.rgba(text.r, text.g, text.b, 0.12)
    readonly property color hover: Qt.rgba(text.r, text.g, text.b, 0.07)
    readonly property color track: Qt.rgba(text.r, text.g, text.b, 0.06)
    readonly property color codeBackground: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color accent: palette.highlight

    readonly property color red: dark ? "#ff6961" : "#d93025"
    readonly property color orange: dark ? "#ffb340" : "#e8710a"
    readonly property color blue: dark ? "#6cb6ff" : "#1a73e8"
    readonly property color green: dark ? "#5fd38d" : "#188038"

    readonly property int gutter: 14
    readonly property int radius: 8
    readonly property string mono: Qt.platform.os === "windows" ? "Consolas" : "monospace"

    /// The colour for a tone the model sends: a verdict key or a level/check tone.
    function tone(name) {
        switch (name) {
        case "deny": case "bad": return red;
        case "ask": case "warn": return orange;
        case "deferred": case "info": return blue;
        case "allow": case "ok": return green;
        default: return tertiary;
        }
    }

    /// `rrggbb` for image://moatbar/agent/<host>/<rrggbb>.
    function hex(c) {
        function part(v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2); }
        return part(c.r) + part(c.g) + part(c.b);
    }
}
