pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real cpuUsage: 0
    property var coreUsages: []
    property real memoryUsage: 0
    property real diskUsage: 0
    property bool hasBattery: false
    property real batteryLevel: 0
    property bool isCharging: false
    readonly property string batteryState: !hasBattery || isCharging || batteryLevel >= 0.95 ? "charging" : batteryLevel <= 0.2 ? "critical" : "normal"

    property var _lastCpu: ({})

    function usage(prev, total, idle): real {
        if (!prev)
            return 0;
        const dt = total - prev.total;
        return dt > 0 ? Math.max(0, 1 - (idle - prev.idle) / dt) : 0;
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuFile.reload();
            memFile.reload();
            if (!batteryProc.running) batteryProc.running = true;
            if (!diskProc.running) diskProc.running = true;
        }
    }

    FileView {
        id: cpuFile
        path: "/proc/stat"
        onLoaded: {
            const next = {};
            const cores = [];
            for (const line of text().split("\n")) {
                const m = line.match(/^(cpu\d*)\s+(.*)$/);
                if (!m)
                    break;
                const n = m[2].trim().split(/\s+/).slice(0, 7).map(Number);
                const total = n.reduce((a, b) => a + b, 0);
                const idle = n[3] + (n[4] || 0);
                const u = root.usage(root._lastCpu[m[1]], total, idle);
                next[m[1]] = { total, idle };
                if (m[1] === "cpu")
                    root.cpuUsage = u;
                else
                    cores.push(u);
            }
            root._lastCpu = next;
            root.coreUsages = cores;
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const total = parseInt(t.match(/MemTotal:\s*(\d+)/)?.[1] ?? "0");
            const avail = parseInt(t.match(/MemAvailable:\s*(\d+)/)?.[1] ?? "0");
            root.memoryUsage = total > 0 ? (total - avail) / total : 0;
        }
    }

    Process {
        id: batteryProc
        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do [ -e \"$b/capacity\" ] && echo \"$(cat \"$b/capacity\") $(cat \"$b/status\")\" && exit; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().match(/^(\d+)\s+(.*)$/);
                root.hasBattery = !!m;
                if (m) {
                    root.batteryLevel = parseInt(m[1]) / 100;
                    root.isCharging = m[2] === "Charging";
                }
            }
        }
    }

    Process {
        id: diskProc
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = (text.trim().split("\n")[1] ?? "").trim().split(/\s+/).map(Number);
                if (n.length === 2 && n[1] > 0)
                    root.diskUsage = n[0] / n[1];
            }
        }
    }
}
