// A tab for every open window, sharing the bar's free width equally (as
// sfwbar's homogeneous taskbar did). Click: focus the window, or minimize it
// if it's already focused. Middle-click: close. Right-click: focus, close,
// (un)minimize, (un)maximize.
//
// labwc doesn't say which workspace a window is on, so every window is
// listed, whichever workspace you're on.

import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: taskbar
    required property var barWindow

    readonly property var windows: ToplevelManager.toplevels.values
    readonly property real tabWidth: windows.length > 0 ? Math.floor(width / windows.length) : 0

    // The window whose right-click menu is open.
    property var menuWindow: null

    Row {
        anchors.fill: parent

        Repeater {
            model: ToplevelManager.toplevels

            Rectangle {
                id: tab
                required property var modelData
                readonly property var win: modelData
                readonly property bool focused: win.activated
                readonly property bool hovered: mouse.containsMouse
                readonly property var entry: DesktopEntries.heuristicLookup(win.appId)

                width: taskbar.tabWidth
                height: parent.height
                radius: Theme.radius
                border.width: 1
                border.color: focused ? Qt.rgba(0, 0, 0, 0.4)
                    : hovered ? Qt.alpha(Theme.crimsonHot, 0.6)
                    : Qt.alpha(Theme.crimson, 0.3)
                color: focused ? Theme.focusedTab
                    : hovered ? Qt.alpha(Theme.crimsonHot, 0.25)
                    : Qt.alpha(Theme.crimson, 0.12)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    anchors.rightMargin: 5
                    spacing: 5

                    Image {
                        id: icon
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        sourceSize: Qt.size(24, 24)
                        source: Quickshell.iconPath(tab.entry?.icon ?? tab.win.appId, "application-x-executable")
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - icon.width - parent.spacing
                        elide: Text.ElideRight
                        text: tab.win.title || tab.entry?.name || tab.win.appId
                        color: tab.focused ? Theme.bright : Theme.text
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: event => {
                        if (event.button === Qt.MiddleButton) {
                            tab.win.close()
                        } else if (event.button === Qt.RightButton) {
                            taskbar.menuWindow = tab.win
                            windowMenu.anchorItem = tab
                            windowMenu.visible = true
                        } else if (tab.focused && !tab.win.minimized) {
                            tab.win.minimized = true
                        } else {
                            tab.win.activate()
                        }
                    }
                }

                BarTooltip {
                    target: tab
                    text: tab.win.title
                    hovered: mouse.containsMouse && !windowMenu.visible
                }
            }
        }
    }

    // sfwbar's winops menu.
    MenuPopup {
        id: windowMenu
        entries: [
            { text: "Focus", icon: Quickshell.iconPath("focus-windows-symbolic", true), act: "focus" },
            { text: "Close", icon: Quickshell.iconPath("window-close-symbolic", true), act: "close" },
            { text: "(Un)minimize", icon: Quickshell.iconPath("window-minimize-symbolic", true), act: "minimize" },
            { text: "(Un)maximize", icon: Quickshell.iconPath("window-maximize-symbolic", true), act: "maximize" },
        ]
        onActivated: entry => {
            const w = taskbar.menuWindow
            visible = false
            if (!w) return
            switch (entry.act) {
            case "focus": w.activate(); break
            case "close": w.close(); break
            case "minimize": w.minimized = !w.minimized; break
            case "maximize": w.maximized = !w.maximized; break
            }
        }
        onVisibleChanged: if (!visible) taskbar.menuWindow = null
    }
}
