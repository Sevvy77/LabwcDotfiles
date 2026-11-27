// The bottom bar, one per output (or only the outputs picked in
// ~/.config/crimson/bar-outputs; see shell.qml). Left to right, as sfwbar
// had it: clock (click for the calendar), workspaces, window tabs, CPU and
// memory graphs (click for top), tray.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { left: true; right: true; bottom: true }
    implicitHeight: Theme.barHeight
    color: Theme.barBg
    WlrLayershell.namespace: "crimson-bar"

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Clock {
            Layout.fillHeight: true
            barWindow: bar
        }

        // Workspaces come from the ext-workspace protocol (labwc 0.8.2 and
        // later), through Quickshell.WindowManager. Loaded separately so a
        // Quickshell too old to have that module still gets the rest of
        // the bar.
        Loader {
            Layout.fillHeight: true
            Layout.leftMargin: 3
            Layout.rightMargin: 3
            source: "Pager.qml"
            visible: status === Loader.Ready
        }

        Taskbar {
            Layout.fillWidth: true
            Layout.fillHeight: true
            barWindow: bar
        }

        CpuGraph {
            Layout.fillHeight: true
            Layout.margins: 2
            barWindow: bar
        }

        MemoryMeter {
            Layout.fillHeight: true
            Layout.margins: 2
            barWindow: bar
        }

        Tray {
            Layout.fillHeight: true
            barWindow: bar
        }
    }
}
