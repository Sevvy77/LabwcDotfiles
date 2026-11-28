// Battery charge as a percentage, read from /sys/class/power_supply every
// 30 seconds (no upower needed). Hidden on machines with no system battery,
// so desktops don't get it. Peripheral batteries (scope "Device": mice,
// headsets) are left out. With more than one battery, it shows their
// combined charge. Turns bright red at 15% or less while not charging.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: battery
    required property var barWindow

    property int percent: -1          // -1: no battery found
    property string status: ""        // Charging, Discharging, Full, ...
    readonly property bool charging: status === "Charging"
    readonly property bool low: percent >= 0 && percent <= 15 && !charging

    visible: percent >= 0
    implicitWidth: label.implicitWidth + 10

    // Prints "<percent> <status>" for the system batteries, or nothing.
    Process {
        id: probe
        command: ["sh", "-c", `
            now=0 full=0 caps=0 n=0 status=
            for d in /sys/class/power_supply/*; do
                [ "$(cat "$d/type" 2>/dev/null)" = Battery ] || continue
                [ "$(cat "$d/scope" 2>/dev/null)" = Device ] && continue
                [ -r "$d/capacity" ] || continue
                n=$((n + 1))
                caps=$((caps + $(cat "$d/capacity")))
                s=$(cat "$d/status" 2>/dev/null)
                [ "$s" = Charging ] || [ -z "$status" ] && status=$s
                if [ -r "$d/energy_full" ]; then
                    now=$((now + $(cat "$d/energy_now"))); full=$((full + $(cat "$d/energy_full")))
                elif [ -r "$d/charge_full" ]; then
                    now=$((now + $(cat "$d/charge_now"))); full=$((full + $(cat "$d/charge_full")))
                fi
            done
            [ $n -gt 0 ] || exit 0
            if [ $n -gt 1 ] && [ $full -gt 0 ]; then pct=$((now * 100 / full)); else pct=$((caps / n)); fi
            [ $pct -gt 100 ] && pct=100
            echo "$pct \${status:-Unknown}"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().match(/^(\d+) (.*)$/)
                battery.percent = m ? Number(m[1]) : -1
                battery.status = m ? m[2] : ""
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: battery.percent + "%" + (battery.charging ? "+" : "")
        color: battery.low ? Theme.crimsonHot : Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.bold: battery.low
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
    }

    BarTooltip {
        target: battery
        text: "Battery: " + battery.percent + "% (" + battery.status.toLowerCase() + ")"
        hovered: mouse.containsMouse
    }
}
