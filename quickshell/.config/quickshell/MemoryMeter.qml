// Memory in use, filling from the bottom (sfwbar's memory scale). Click to
// open top sorted by memory.

import QtQuick
import Quickshell

Rectangle {
    id: meter
    required property var barWindow

    implicitWidth: 9
    color: Theme.graphTrough
    border.color: Theme.crimson
    border.width: 1

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 1
        height: Math.round((parent.height - 2) * SystemStats.memory)
        color: Theme.crimsonHot
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Quickshell.execDetached([Theme.terminal, "-e", "top", "-o", "%MEM"])
    }

    BarTooltip {
        target: meter
        text: "Memory: " + (SystemStats.memory * 100).toFixed(1) + "%"
        hovered: mouse.containsMouse
    }
}
