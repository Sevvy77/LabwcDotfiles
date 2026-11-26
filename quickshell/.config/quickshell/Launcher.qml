// The app launcher (was fuzzel), opened by Super+k:
//   quickshell ipc call launcher toggle
// Type to search names, generic names ("Web Browser"), keywords and
// categories; matched letters are highlighted. With nothing typed, the apps
// you start most come first. Enter starts the selected app, Esc closes.
// Up/Down, Ctrl+p/n, Tab/Shift+Tab, Page Up/Down and Ctrl+Home/End move.
// Apps marked Terminal=true open in the terminal.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: launcher

    readonly property int rows: 15
    readonly property int rowHeight: 22
    property string query: ""

    visible: false
    color: "transparent"
    // No anchors: the compositor centres it on the focused output.
    implicitWidth: 360
    implicitHeight: box.implicitHeight
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "crimson-launcher"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function open() {
        query = ""
        input.text = ""
        list.currentIndex = 0
        visible = true
        input.forceActiveFocus()
    }
    function close() { visible = false }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.visible ? launcher.close() : launcher.open() }
        function open(): void { launcher.open() }
        function close(): void { launcher.close() }
    }

    // How often each app has been started, so the usual ones come first.
    FileView {
        id: usageFile
        path: Quickshell.statePath("launcher-usage.json")
        printErrors: false
        JsonAdapter {
            id: usage
            property var counts: ({})
        }
    }

    function launch(entry) {
        if (!entry) return
        const counts = Object.assign({}, usage.counts)
        counts[entry.id] = (counts[entry.id] || 0) + 1
        usage.counts = counts
        usageFile.writeAdapter()

        if (entry.runInTerminal) {
            Quickshell.execDetached({
                command: [Theme.terminal, "-e"].concat(entry.command),
                workingDirectory: entry.workingDirectory || Quickshell.env("HOME"),
            })
        } else {
            entry.execute()
        }
        close()
    }

    // --- Matching ---------------------------------------------------------

    // Positions of `q`'s letters in `s`, in order (case-insensitive), or
    // null. Prefers a contiguous run, then word starts.
    function matchPositions(s, q) {
        const ls = s.toLowerCase()
        const at = ls.indexOf(q)
        if (at >= 0) return Array.from({ length: q.length }, (_, i) => at + i)
        const pos = []
        let j = 0
        for (let i = 0; i < ls.length && j < q.length; i++) {
            if (ls[i] === q[j]) { pos.push(i); j++ }
        }
        return j === q.length ? pos : null
    }

    function score(entry, q) {
        const name = entry.name.toLowerCase()
        if (name === q) return 1000
        if (name.startsWith(q)) return 900 - name.length
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 800 - name.length
        if (name.indexOf(q) >= 0) return 700 - name.indexOf(q)
        const pos = matchPositions(entry.name, q)
        if (pos) return 500 - (pos[pos.length - 1] - pos[0])  // tighter is better
        const extra = [entry.genericName, entry.comment].concat(entry.keywords, entry.categories)
            .filter(Boolean).join(" ").toLowerCase()
        if (extra.indexOf(q) >= 0) return 300
        return -1
    }

    readonly property var results: {
        const q = query.trim().toLowerCase()
        const counts = usage.counts
        const apps = DesktopEntries.applications.values.filter(e => !e.noDisplay)
        const scored = []
        for (const e of apps) {
            const s = q === "" ? 0 : score(e, q)
            if (s >= 0) scored.push({ entry: e, score: s, uses: counts[e.id] || 0 })
        }
        scored.sort((a, b) => b.score - a.score || b.uses - a.uses
                     || a.entry.name.localeCompare(b.entry.name))
        return scored.map(r => r.entry)
    }

    function highlighted(name) {
        const esc = c => c === "&" ? "&amp;" : c === "<" ? "&lt;" : c === ">" ? "&gt;" : c
        const q = query.trim().toLowerCase()
        const pos = q === "" ? null : matchPositions(name, q)
        if (!pos) return Array.from(name).map(esc).join("")
        const set = new Set(pos)
        let out = ""
        for (let i = 0; i < name.length; i++) {
            out += set.has(i) ? `<font color="${Theme.match}">${esc(name[i])}</font>` : esc(name[i])
        }
        return out
    }

    function move(delta) {
        if (results.length === 0) return
        list.currentIndex = Math.max(0, Math.min(results.length - 1, list.currentIndex + delta))
        list.positionViewAtIndex(list.currentIndex, ListView.Contain)
    }

    // --- Look ---------------------------------------------------------------

    Rectangle {
        id: box
        width: parent.width
        implicitHeight: 10 + promptRow.height + 6 + list.height + 10
        radius: 10
        color: Theme.panelBg
        border.color: Theme.crimson
        border.width: 1

        Row {
            id: promptRow
            x: 14
            y: 10
            width: parent.width - 28
            height: launcher.rowHeight

            Text {
                id: prompt
                anchors.verticalCenter: parent.verticalCenter
                text: "> "
                color: Theme.text
                font.family: Theme.monoFont
                font.pixelSize: 15
            }

            TextInput {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - prompt.width
                color: Theme.text
                selectionColor: Theme.crimson
                selectedTextColor: Theme.bright
                font.family: Theme.monoFont
                font.pixelSize: 15
                focus: true
                clip: true
                onTextChanged: {
                    launcher.query = text
                    list.currentIndex = 0
                    list.positionViewAtBeginning()
                }

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier
                    let handled = true
                    switch (event.key) {
                    case Qt.Key_Escape: launcher.close(); break
                    case Qt.Key_Return:
                    case Qt.Key_Enter: launcher.launch(launcher.results[list.currentIndex]); break
                    case Qt.Key_Up: launcher.move(-1); break
                    case Qt.Key_Down: launcher.move(1); break
                    case Qt.Key_Backtab: launcher.move(-1); break
                    case Qt.Key_Tab: launcher.move(1); break
                    case Qt.Key_PageUp: launcher.move(-launcher.rows); break
                    case Qt.Key_PageDown: launcher.move(launcher.rows); break
                    case Qt.Key_P: if (ctrl) launcher.move(-1); else handled = false; break
                    case Qt.Key_N: if (ctrl) launcher.move(1); else handled = false; break
                    case Qt.Key_Home: if (ctrl) launcher.move(-1e9); else handled = false; break
                    case Qt.Key_End: if (ctrl) launcher.move(1e9); else handled = false; break
                    default: handled = false
                    }
                    event.accepted = handled
                }
            }
        }

        ListView {
            id: list
            x: 10
            y: promptRow.y + promptRow.height + 6
            width: parent.width - 20
            height: launcher.rows * launcher.rowHeight
            clip: true
            model: launcher.results
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: 0

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool selected: ListView.isCurrentItem

                width: list.width
                height: launcher.rowHeight
                radius: 2
                color: selected ? Theme.selection : "transparent"

                Image {
                    id: icon
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    sourceSize: Qt.size(16, 16)
                    source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, true) : ""
                }

                Text {
                    x: 40
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 8
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                    text: launcher.highlighted(row.modelData.name)
                    color: row.selected ? Theme.bright : Theme.text
                    font.family: Theme.monoFont
                    font.pixelSize: 15
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: list.currentIndex = row.index
                    onClicked: launcher.launch(row.modelData)
                }
            }
        }
    }
}
