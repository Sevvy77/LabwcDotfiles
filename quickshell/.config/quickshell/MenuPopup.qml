// A Crimson menu above a bar item, styled like sfwbar's GTK menus: a 2px
// crimson border, rows that turn crimson under the pointer. Used for a
// window tab's right-click menu and for tray menus.
//
// `entries` is a list of objects with QsMenuEntry's fields (text, icon,
// enabled, isSeparator, hasChildren, buttonType, checkState): either real
// QsMenuEntry objects (tray menus) or plain ones (the window menu). Picking
// one emits activated(entry); the owner decides what that does. A non-empty
// `title` shows a back row, for submenus.
//
// Don't change `entries` while it's open: labwc stretches the old picture of
// a popup to its new size instead of showing the new one. Close it, change
// them, and open it again (Tray.qml does).

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: menu
    property Item anchorItem: null
    property var entries: []
    property string title: ""
    signal activated(var entry)
    signal back()

    anchor.item: anchorItem
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Top | Edges.Right
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
    grabFocus: true
    visible: false
    color: "transparent"
    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight

    // Long menus (a list of 100 languages) scroll instead of running off
    // the screen.
    readonly property int maxHeight: {
        const win = anchorItem ? anchorItem.QsWindow.window : null
        return Math.max(200, (win && win.screen ? win.screen.height : 800) - Theme.barHeight - 60)
    }
    onEntriesChanged: flick.contentY = 0

    Rectangle {
        id: frame
        implicitWidth: Math.max(140, column.implicitWidth + 8)
        implicitHeight: Math.min(column.implicitHeight + 8, menu.maxHeight)
        color: Theme.bg
        border.color: Theme.crimson
        border.width: 2

        Flickable {
            id: flick
            x: 4
            y: 4
            width: frame.width - 8
            height: frame.height - 8
            contentHeight: column.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            // A layout, not a Column, so the menu is as wide as its widest row.
            ColumnLayout {
                id: column
                width: flick.width
                spacing: 0

                MenuRow {
                    visible: menu.title !== ""
                    label: "‹  " + menu.title
                    Layout.fillWidth: true
                    onClicked: menu.back()
                }

                Repeater {
                    model: menu.entries

                    Item {
                        id: slot
                        required property var modelData
                        Layout.fillWidth: true
                        implicitWidth: modelData.isSeparator === true ? 0 : row.implicitWidth
                        implicitHeight: modelData.isSeparator === true ? 7 : row.implicitHeight

                        Rectangle {
                            visible: slot.modelData.isSeparator === true
                            anchors.centerIn: parent
                            width: parent.width - 4
                            height: 1
                            color: Qt.alpha(Theme.crimson, 0.5)
                        }

                        MenuRow {
                            id: row
                            visible: slot.modelData.isSeparator !== true
                            width: parent.width
                            label: slot.modelData.text ?? ""
                            icon: slot.modelData.icon ?? ""
                            enabled: slot.modelData.enabled ?? true
                            arrow: slot.modelData.hasChildren ?? false
                            // QsMenuButtonType: 0 none, 1 checkbox, 2 radio.
                            check: (slot.modelData.buttonType ?? 0) === 0 ? ""
                                : slot.modelData.checkState === Qt.Checked
                                    ? ((slot.modelData.buttonType === 2) ? "●" : "✓") : " "
                            onClicked: menu.activated(slot.modelData)
                        }
                    }
                }
            }
        }
    }

    component MenuRow: Rectangle {
        id: r
        property string label
        property string icon
        property string check: ""
        property bool arrow: false
        signal clicked()
        readonly property bool hot: area.containsMouse && enabled

        implicitWidth: inner.implicitWidth + 8
        implicitHeight: 26
        color: hot ? Theme.crimson : "transparent"

        Row {
            id: inner
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Text {
                visible: r.check !== ""
                width: 12
                text: r.check
                color: r.hot ? Theme.bright : Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                anchors.verticalCenter: parent.verticalCenter
            }

            Image {
                id: img
                visible: r.icon !== ""
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                source: r.icon
                sourceSize: Qt.size(16, 16)
                // Symbolic icons are drawn dark; tint them to the text colour
                // (brighten to white first, or the tint stays dark).
                layer.enabled: r.icon.indexOf("-symbolic") >= 0
                layer.effect: MultiEffect {
                    brightness: 1
                    colorization: 1
                    colorizationColor: r.hot ? Theme.bright : Theme.text
                }
            }

            Text {
                text: r.label.replace(/_(?!_)/g, "").replace(/__/g, "_")   // strip mnemonics
                color: r.hot ? Theme.bright : Theme.text
                opacity: r.enabled ? 1 : 0.5
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: r.arrow ? 18 : 6
            }
        }

        Text {
            visible: r.arrow
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: r.hot ? Theme.bright : Theme.text
            font.pixelSize: Theme.fontSize + 2
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (r.enabled) r.clicked()
        }
    }
}
