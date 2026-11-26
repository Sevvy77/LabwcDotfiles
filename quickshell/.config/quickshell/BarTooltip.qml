// A tooltip above a bar item, shown after the pointer rests on it. Set
// `hovered` from the item's HoverHandler or MouseArea.

import QtQuick
import Quickshell

PopupWindow {
    id: tip
    required property Item target
    property string text: ""
    property bool hovered: false

    anchor.item: target
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.margins.top: -4
    visible: false
    color: "transparent"
    implicitWidth: box.implicitWidth
    implicitHeight: box.implicitHeight

    onHoveredChanged: {
        if (hovered) delay.restart()
        else { delay.stop(); visible = false }
    }
    onTextChanged: if (text === "") visible = false

    Timer {
        id: delay
        interval: 500
        onTriggered: tip.visible = tip.hovered && tip.text !== ""
    }

    Rectangle {
        id: box
        implicitWidth: label.implicitWidth + 12
        implicitHeight: label.implicitHeight + 8
        color: Theme.bg
        border.color: Theme.crimson
        border.width: 1
        radius: Theme.radius

        Text {
            id: label
            anchors.centerIn: parent
            text: tip.text
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }
}
