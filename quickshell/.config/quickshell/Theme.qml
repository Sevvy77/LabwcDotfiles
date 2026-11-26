// Crimson Dark, shared by the bar, the launcher and the lock screen. The same
// colours as alacritty and the OB-Crimson-Dark GTK theme.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // Bar (was sfwbar.config's palette)
    readonly property color bg: "#140c0d"
    readonly property color barBg: Qt.alpha(bg, 0.85)
    readonly property color text: "#e8d5d0"
    readonly property color bright: "#f5e9e6"
    readonly property color crimson: "#9b2730"
    // The focused window's tab: darker than the accent, so a tab that fills
    // the bar isn't a wall of bright red.
    readonly property color focusedTab: "#7c1f26"
    readonly property color crimsonHot: "#e5484d"
    readonly property color graphTrough: Qt.rgba(0.5, 0.5, 0.5, 0.3)

    // Launcher and lock screen (was fuzzel.ini's palette)
    readonly property color panelBg: Qt.rgba(0x1f / 255, 0x14 / 255, 0x16 / 255, 0xdd / 255)
    readonly property color solidBg: "#1f1416"
    readonly property color match: "#ff7a7f"
    readonly property color selection: Qt.rgba(0x3a / 255, 0x22 / 255, 0x26 / 255, 0xdd / 255)
    readonly property color muted: "#8c7470"

    readonly property string font: "Sans"
    readonly property string monoFont: "monospace"
    readonly property int fontSize: 12      // px, like sfwbar's "12px Sans"

    readonly property int barHeight: 31
    readonly property int radius: 4

    // Opens programs the way sfwbar's ExecTerm did (CPU and memory clicks)
    // and runs launcher entries marked Terminal=true.
    readonly property string terminal: "alacritty"

    readonly property string wallpaper: Quickshell.env("HOME") + "/Pictures/wallpaper.png"
}
