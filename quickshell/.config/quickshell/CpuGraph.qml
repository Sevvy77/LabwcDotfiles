// CPU use over the last few seconds, one pixel column a second, in a small
// crimson-bordered box (sfwbar's cpu chart). Click to open top.

import QtQuick
import Quickshell

Rectangle {
    id: graph
    required property var barWindow

    implicitWidth: 9
    color: Theme.graphTrough
    border.color: Theme.crimson
    border.width: 1

    Row {
        id: bars
        anchors.fill: parent
        anchors.margins: 1
        layoutDirection: Qt.RightToLeft

        Repeater {
            // Newest on the right.
            model: SystemStats.cpuHistory.slice(-Math.max(1, Math.floor(bars.width))).reverse()
            Item {
                required property real modelData
                width: 1
                height: bars.height
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: 1
                    height: Math.round(parent.height * parent.modelData)
                    color: Theme.crimsonHot
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Quickshell.execDetached([Theme.terminal, "-e", "btop"])
    }

    BarTooltip {
        target: graph
        text: "CPU: " + (SystemStats.cpu * 100).toFixed(1) + "%"
        hovered: mouse.containsMouse
    }
}
