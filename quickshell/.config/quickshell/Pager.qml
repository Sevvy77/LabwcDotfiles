// labwc's workspaces (the <desktops> names in rc.xml): the current one is
// highlighted, click one to switch to it. Loaded by Bar.qml.

import QtQuick
import Quickshell.WindowManager

Row {
    // sfwbar's button margin: 3px top and bottom, 2px either side.
    spacing: 4
    leftPadding: 2
    rightPadding: 2

    Repeater {
        model: WindowManager.windowsets

        Rectangle {
            id: ws
            required property var modelData
            readonly property bool active: modelData.active
            readonly property bool hovered: mouse.containsMouse

            visible: modelData.shouldDisplay
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height - 6
            width: Math.max(20, label.implicitWidth + 8) + 10
            radius: Theme.radius
            border.width: 1
            border.color: active ? Qt.rgba(0, 0, 0, 0.4)
                : hovered ? Qt.alpha(Theme.crimsonHot, 0.6)
                : Qt.alpha(Theme.crimson, 0.3)
            color: active ? Theme.crimson
                : hovered ? Qt.alpha(Theme.crimsonHot, 0.25)
                : Qt.alpha(Theme.crimson, 0.12)

            Text {
                id: label
                anchors.centerIn: parent
                text: ws.modelData.name
                color: ws.active ? Theme.bright : Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: if (ws.modelData.canActivate) ws.modelData.activate()
            }
        }
    }
}
