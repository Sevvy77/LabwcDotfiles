// Status icons (StatusNotifierItem), like sfwbar's tray. Icons of apps that
// report themselves passive are hidden. Click: the app's main action (or its
// menu, for apps that only have a menu). Right-click: its menu. Middle-click:
// its secondary action. Scroll: passed to the app.

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Row {
    id: tray
    required property var barWindow

    rightPadding: 1

    // The open menu's item, and the submenus opened inside it.
    property var menuItem: null
    property var submenus: []      // [{ opener, title }]

    Repeater {
        model: SystemTray.items

        Item {
            id: slot
            required property var modelData
            readonly property var item: modelData

            visible: item.status !== Status.Passive
            width: visible ? 22 : 0
            height: tray.height

            Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                sourceSize: Qt.size(18, 18)
                source: slot.item.icon
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: event => {
                    if (event.button === Qt.MiddleButton) {
                        slot.item.secondaryActivate()
                    } else if (event.button === Qt.RightButton
                               || (slot.item.onlyMenu && slot.item.hasMenu)) {
                        if (slot.item.hasMenu) tray.openMenu(slot.item, slot)
                    } else {
                        slot.item.activate()
                    }
                }
                onWheel: wheel => {
                    if (wheel.angleDelta.y !== 0) slot.item.scroll(wheel.angleDelta.y / 120, false)
                    else if (wheel.angleDelta.x !== 0) slot.item.scroll(wheel.angleDelta.x / 120, true)
                }
            }

            BarTooltip {
                target: slot
                text: slot.item.tooltipTitle || slot.item.title
                hovered: mouse.containsMouse && !trayMenu.visible
            }
        }
    }

    // The app sends its menu (and each submenu) over D-Bus after we ask for
    // it, so wait until it's here, or a moment has passed, before showing
    // it. And since labwc draws a popup that changes size while open
    // stretched, going into or out of a submenu closes the menu and opens
    // it again at its new size.
    property bool switching: false

    function openMenu(item, anchor) {
        closeSubmenus()
        menuItem = item
        rootOpener.menu = item.menu
        trayMenu.anchorItem = anchor
        showWhenReady()
    }

    function showLevel(change) {
        switching = true
        trayMenu.visible = false
        change()
        switching = false
        showWhenReady()
    }

    function showWhenReady() {
        menuWait.waited = 0
        menuWait.restart()
    }

    Timer {
        id: menuWait
        property int waited: 0
        interval: 20
        repeat: true
        onTriggered: {
            waited += interval
            if (trayMenu.entries.length > 0 || waited >= 400) {
                stop()
                if (tray.menuItem) trayMenu.visible = true
            }
        }
    }

    function closeSubmenus() {
        const s = submenus
        submenus = []
        // Innermost first: each submenu's entry belongs to the level above.
        for (let i = s.length - 1; i >= 0; i--) s[i].opener.destroy()
    }

    QsMenuOpener { id: rootOpener }

    Component {
        id: openerComponent
        QsMenuOpener {}
    }

    MenuPopup {
        id: trayMenu
        readonly property var level: tray.submenus.length ? tray.submenus[tray.submenus.length - 1] : null
        entries: level ? level.opener.children.values : rootOpener.children.values
        title: level ? level.title : ""

        onActivated: entry => {
            if (entry.hasChildren) {
                tray.showLevel(() => {
                    const opener = openerComponent.createObject(tray, { menu: entry })
                    tray.submenus = tray.submenus.concat([{ opener: opener, title: entry.text.replace(/_/g, "") }])
                })
            } else {
                entry.triggered()
                visible = false
            }
        }
        onBack: tray.showLevel(() => {
            const s = tray.submenus.slice()
            const top = s.pop()
            tray.submenus = s
            top.opener.destroy()
        })
        onVisibleChanged: if (!visible && !tray.switching) {
            menuWait.stop()
            tray.closeSubmenus()
            tray.menuItem = null
        }
    }
}
