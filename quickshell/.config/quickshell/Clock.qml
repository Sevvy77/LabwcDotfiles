// The clock at the left end of the bar. A click opens the calendar on the
// current month, like sfwbar's ClockPopUp.

import QtQuick
import Quickshell

Item {
    id: clock
    required property var barWindow

    implicitWidth: label.implicitWidth + 10

    SystemClock {
        id: time
        precision: SystemClock.Minutes
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: Qt.formatTime(time.date, "HH:mm")
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (calendar.visible) {
                calendar.visible = false
            } else {
                calendar.showToday()
                calendar.visible = true
            }
        }
    }

    CalendarPopup {
        id: calendar
        anchorItem: clock
    }
}
