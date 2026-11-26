// CPU and memory use, read from /proc once a second (sfwbar's cpu.source and
// memory.source did the same). Shared by every bar.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: stats

    // 0-1, latest first is last: the CPU graph draws this history.
    property var cpuHistory: []
    readonly property real cpu: cpuHistory.length ? cpuHistory[cpuHistory.length - 1] : 0
    property real memory: 0
    readonly property int historyLength: 64

    property real lastIdle: -1
    property real lastTotal: -1

    FileView {
        id: procStat
        path: "/proc/stat"
        blockLoading: true
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            // user nice system idle iowait irq softirq steal
            const idle = f[3] + (f[4] || 0)
            const total = f.slice(0, 8).reduce((a, b) => a + (b || 0), 0)
            if (stats.lastTotal >= 0 && total > stats.lastTotal) {
                const use = 1 - (idle - stats.lastIdle) / (total - stats.lastTotal)
                const h = stats.cpuHistory.slice(-(stats.historyLength - 1))
                h.push(Math.max(0, Math.min(1, use)))
                stats.cpuHistory = h
            }
            stats.lastIdle = idle
            stats.lastTotal = total
        }
    }

    FileView {
        id: procMeminfo
        path: "/proc/meminfo"
        blockLoading: true
        onLoaded: {
            const kv = {}
            for (const line of text().split("\n")) {
                const m = line.match(/^(\w+):\s+(\d+)/)
                if (m) kv[m[1]] = Number(m[2])
            }
            if (kv.MemTotal)
                stats.memory = 1 - (kv.MemAvailable ?? kv.MemFree) / kv.MemTotal
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            procStat.reload()
            procMeminfo.reload()
        }
    }
}
