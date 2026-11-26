// The clock's calendar, laid out like sfwbar's cal.widget: the time, today's
// date, then a month you can page through. Arrows (or scrolling) go a month
// at a time, the outer arrows (or Ctrl+scroll) a year; middle-click goes
// back to this month. Weeks start on Monday. Clicking outside closes it.

import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: popup
    required property Item anchorItem

    // Months since year 0, like cal.widget's YearMonth.
    property int yearMonth: 0
    readonly property int year: Math.floor(yearMonth / 12)
    readonly property int month: yearMonth % 12     // 0-11

    function showToday() {
        const now = new Date()
        yearMonth = now.getFullYear() * 12 + now.getMonth()
    }

    anchor.item: anchorItem
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Top | Edges.Right
    grabFocus: true
    visible: false
    color: "transparent"
    implicitWidth: frame.implicitWidth + 10
    implicitHeight: frame.implicitHeight + 10

    SystemClock {
        id: time
        enabled: popup.visible
        precision: SystemClock.Seconds
    }

    // The 42 days shown (six weeks from the Monday on or before the 1st).
    readonly property var days: {
        const first = new Date(year, month, 1)
        const lead = (first.getDay() + 6) % 7          // Monday = 0
        const now = time.date
        const out = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(year, month, 1 - lead + i)
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === month,
                today: d.getFullYear() === now.getFullYear()
                    && d.getMonth() === now.getMonth()
                    && d.getDate() === now.getDate()
            })
        }
        return out
    }

    Rectangle {
        id: frame
        anchors.centerIn: parent
        implicitWidth: content.implicitWidth + 20
        implicitHeight: content.implicitHeight + 20
        radius: 10
        color: Theme.bg
        border.color: Theme.crimson
        border.width: 1

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.MiddleButton
            onClicked: popup.showToday()
            onWheel: wheel => {
                const step = (wheel.modifiers & Qt.ControlModifier) ? 12 : 1
                popup.yearMonth += wheel.angleDelta.y > 0 ? -step : step
            }
        }

        ColumnLayout {
            id: content
            anchors.centerIn: parent
            spacing: 0

            Text {
                text: Qt.formatTime(time.date, "HH:mm:ss")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 32
                font.weight: Font.Medium
            }

            Text {
                id: dateLabel
                Layout.fillWidth: true
                bottomPadding: 2
                text: Qt.formatDate(time.date, "d MMMM yyyy")
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }

            // cal.widget's dashed line under the date. Its own width is 0 to
            // the layout (dashes are clipped to whatever it's given), so it
            // can't feed back into the popup's width.
            Item {
                Layout.fillWidth: true
                Layout.bottomMargin: 10
                implicitHeight: 1
                clip: true
                Row {
                    spacing: 3
                    Repeater {
                        model: 80
                        Rectangle { width: 3; height: 1; color: Theme.crimson }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                CalendarArrow { icon: "go-first"; glyph: "«"; onActivated: popup.yearMonth -= 12 }
                CalendarArrow { icon: "go-previous"; glyph: "‹"; onActivated: popup.yearMonth -= 1 }
                Text {
                    Layout.fillWidth: true
                    topPadding: 5
                    bottomPadding: 5
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().standaloneMonthName(popup.month) + " " + popup.year
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }
                CalendarArrow { icon: "go-next"; glyph: "›"; onActivated: popup.yearMonth += 1 }
                CalendarArrow { icon: "go-last"; glyph: "»"; onActivated: popup.yearMonth += 12 }
            }

            Grid {
                Layout.topMargin: 10
                columns: 7

                Repeater {
                    // Monday first; dayName counts from Sunday = 0.
                    model: [1, 2, 3, 4, 5, 6, 0]
                    CalendarCell {
                        required property int modelData
                        text: Qt.locale().dayName(modelData, Locale.ShortFormat).slice(0, 2)
                    }
                }

                Repeater {
                    model: popup.days
                    CalendarCell {
                        required property var modelData
                        text: modelData.day
                        dim: !modelData.inMonth
                        today: modelData.today
                    }
                }
            }
        }
    }

    component CalendarCell: Rectangle {
        property alias text: label.text
        property bool dim: false
        property bool today: false
        implicitWidth: 30
        implicitHeight: 30
        color: "transparent"
        border.width: today ? 1 : 0
        border.color: Theme.crimson
        Text {
            id: label
            anchors.centerIn: parent
            color: Theme.text
            opacity: dim ? 0.5 : 1
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }

    component CalendarArrow: Item {
        id: arrow
        property string icon
        property string glyph
        signal activated()
        readonly property bool themed: Quickshell.hasThemeIcon(icon)
        implicitWidth: 22
        implicitHeight: 22
        Image {
            anchors.centerIn: parent
            visible: arrow.themed
            source: arrow.themed ? Quickshell.iconPath(arrow.icon) : ""
            sourceSize: Qt.size(16, 16)
        }
        Text {
            anchors.centerIn: parent
            visible: !arrow.themed
            text: arrow.glyph
            color: Theme.text
            font.pixelSize: 16
        }
        MouseArea {
            anchors.fill: parent
            onClicked: arrow.activated()
        }
    }
}
