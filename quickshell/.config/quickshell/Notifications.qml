// Notification popups (was mako), in the top-right corner of the screen,
// newest at the top. Styled and behaving as the mako config did:
//   - a 2px crimson border; low urgency gets a dim border, critical a red
//     one on a lighter background
//   - they stay until clicked unless the app gives a timeout
//   - left-click: the notification's default action (or just dismiss it);
//     right-click: dismiss; other actions show as buttons
//   - a progress hint ("value") fills the background, like mako's
//     progress-color
//   - at most 5 shown; the rest wait, counted at the bottom
//
//   quickshell ipc call notifications dismissAll        (makoctl dismiss -a)
//   quickshell ipc call notifications dismissNewest     (makoctl dismiss)
//   quickshell ipc call notifications toggleDnd         (do not disturb: hold
//                                                        popups until it's off)

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland

Scope {
    id: root

    readonly property int maxVisible: 5
    readonly property int popupWidth: 300
    property bool dnd: false

    // Newest first.
    readonly property var all: server.trackedNotifications.values.slice().reverse()
    readonly property var shown: all.slice(0, maxVisible)

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        imageSupported: true
        persistenceSupported: true
        onNotification: n => { n.tracked = true }
    }

    IpcHandler {
        target: "notifications"
        function dismissAll(): void {
            for (const n of server.trackedNotifications.values.slice()) n.dismiss()
        }
        function dismissNewest(): void {
            if (root.all.length) root.all[0].dismiss()
        }
        function toggleDnd(): void { root.dnd = !root.dnd }
        function isDnd(): bool { return root.dnd }
        function count(): int { return server.trackedNotifications.values.length }
    }

    PanelWindow {
        id: popups
        visible: root.shown.length > 0 && !root.dnd
        anchors { top: true; right: true }
        margins { top: 10; right: 10 }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "crimson-notifications"
        color: "transparent"
        implicitWidth: root.popupWidth
        implicitHeight: column.implicitHeight

        Column {
            id: column
            width: root.popupWidth
            spacing: 10

            Repeater {
                model: root.shown
                NotificationCard {
                    required property var modelData
                    notification: modelData
                    width: root.popupWidth
                }
            }

            // mako's "(N more)" card.
            Rectangle {
                visible: root.all.length > root.maxVisible
                width: root.popupWidth
                height: more.implicitHeight + 12
                color: Qt.alpha(Theme.solidBg, 0.93)
                border.color: Theme.crimson
                border.width: 2
                Text {
                    id: more
                    anchors.centerIn: parent
                    text: "(" + (root.all.length - root.maxVisible) + " more)"
                    color: Theme.text
                    font.family: Theme.monoFont
                    font.pixelSize: 13
                }
            }
        }
    }

    component NotificationCard: Rectangle {
        id: card
        required property var notification
        readonly property var n: notification
        readonly property bool critical: n.urgency === NotificationUrgency.Critical
        readonly property bool low: n.urgency === NotificationUrgency.Low
        readonly property var defaultAction: n.actions.find(a => a.identifier === "default") ?? null
        readonly property var buttons: n.actions.filter(a => a.identifier !== "default")
        readonly property real progress: {
            const v = n.hints ? n.hints.value : undefined
            return v === undefined || v === null ? -1 : Math.max(0, Math.min(100, Number(v))) / 100
        }
        readonly property string iconSource: {
            if (n.image) return n.image
            const icon = n.appIcon
            if (!icon) return ""
            if (icon.startsWith("/")) return "file://" + icon
            if (icon.indexOf("://") >= 0) return icon
            return Quickshell.iconPath(icon, true)
        }

        implicitHeight: content.implicitHeight + 10
        color: critical ? Qt.rgba(0x2e / 255, 0x1b / 255, 0x1e / 255, 0xee / 255)
                        : Qt.rgba(0x1f / 255, 0x14 / 255, 0x16 / 255, 0xee / 255)
        border.width: 2
        border.color: critical ? Theme.crimsonHot : low ? "#2e1b1e" : Theme.crimson

        // Progress, drawn over the background like mako's "over" mode.
        Rectangle {
            visible: card.progress >= 0
            x: 2; y: 2
            width: (card.width - 4) * Math.max(0, card.progress)
            height: card.height - 4
            color: "#3a2226"
        }

        // Expire after the app's timeout; with none (or "server default"),
        // stay until clicked, as mako does by default.
        Timer {
            running: card.n.expireTimeout > 0 && !area.containsMouse
            interval: card.n.expireTimeout          // milliseconds
            onTriggered: card.n.expire()
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => {
                if (event.button === Qt.LeftButton && card.defaultAction) card.defaultAction.invoke()
                else card.n.dismiss()
            }
        }

        Row {
            id: content
            x: 5
            y: 5
            width: card.width - 10
            spacing: 6

            Image {
                id: icon
                visible: card.iconSource !== "" && status === Image.Ready
                width: visible ? Math.min(64, implicitWidth) : 0
                height: width
                sourceSize: Qt.size(64, 64)
                fillMode: Image.PreserveAspectFit
                source: card.iconSource
            }

            Column {
                width: content.width - (icon.visible ? icon.width + content.spacing : 0)
                spacing: 2

                Text {
                    width: parent.width
                    text: card.n.summary
                    font.bold: true
                    font.family: Theme.monoFont
                    font.pixelSize: 13
                    color: card.critical ? Theme.bright : Theme.text
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    visible: text !== ""
                    width: parent.width
                    text: card.n.body
                    textFormat: Text.StyledText
                    font.family: Theme.monoFont
                    font.pixelSize: 13
                    color: card.critical ? Theme.bright : Theme.text
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }

                Flow {
                    id: actionsRow
                    visible: card.buttons.length > 0
                    width: parent.width
                    spacing: 4
                    topPadding: 3

                    Repeater {
                        model: card.buttons
                        Rectangle {
                            required property var modelData
                            width: label.implicitWidth + 12
                            height: label.implicitHeight + 6
                            radius: Theme.radius
                            color: hover.containsMouse ? Theme.crimson : Qt.alpha(Theme.crimson, 0.25)
                            border.color: Theme.crimson
                            border.width: 1
                            Text {
                                id: label
                                anchors.centerIn: parent
                                text: parent.modelData.text
                                color: Theme.bright
                                font.family: Theme.monoFont
                                font.pixelSize: 12
                            }
                            MouseArea {
                                id: hover
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: parent.modelData.invoke()
                            }
                        }
                    }
                }
            }
        }
    }
}
