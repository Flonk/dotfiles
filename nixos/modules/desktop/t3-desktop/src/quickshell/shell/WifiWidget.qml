pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string iface: ""
    readonly property bool isConnected: iface !== ""
    property real uploadRate: 0
    property real downloadRate: 0
    readonly property bool isHighTraffic: downloadRate >= 30e6 / 8 || uploadRate >= 10e6 / 8
    property string localIp: ""
    property string gatewayIp: ""
    property string publicIp: ""
    property var _lastSample: null

    function formatRate(bytesPerSecond: real): string {
        const units = ["B", "K", "M", "G", "T"];
        let value = Number(bytesPerSecond);
        let unit = 0;
        if (!isFinite(value) || value <= 0)
            return "  0B";
        while (value >= 1000 && unit < units.length - 1) {
            value /= 1000;
            unit++;
        }
        const mantissa = unit === 0 || value >= 10 ? Math.round(value).toString() : value.toFixed(1);
        return mantissa.padStart(3, " ") + units[unit];
    }

    function openCommander(): void {
        Quickshell.execDetached(["xdg-open", "vicinae://launch/@dagimg-dot/store.vicinae.wifi-commander/scan-wifi"]);
    }

    function run(proc): void {
        if (!proc.running)
            proc.running = true;
    }

    onIfaceChanged: {
        _lastSample = null;
        uploadRate = 0;
        downloadRate = 0;
        localIp = "";
        gatewayIp = "";
        publicIp = "";
        if (isConnected) {
            run(infoProc);
            run(publicIpProc);
        }
    }

    Process {
        id: statusProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const wifi = text.split("\n").map(l => l.split(":")).find(p => p[1] === "wifi" && (p[2] ?? "").startsWith("connected"));
                root.iface = wifi ? wifi[0] : "";
            }
        }
    }

    Process {
        id: statsProc
        command: ["cat", `/sys/class/net/${root.iface}/statistics/rx_bytes`, `/sys/class/net/${root.iface}/statistics/tx_bytes`]
        stdout: StdioCollector {
            onStreamFinished: {
                const [rx, tx] = text.trim().split(/\s+/).map(Number);
                if (isNaN(rx) || isNaN(tx))
                    return;
                const now = Date.now();
                const last = root._lastSample;
                if (last) {
                    const dt = Math.max(0.001, (now - last.t) / 1000);
                    root.downloadRate = Math.max(0, (rx - last.rx) / dt);
                    root.uploadRate = Math.max(0, (tx - last.tx) / dt);
                }
                root._lastSample = { t: now, rx, tx };
            }
        }
    }

    Process {
        id: infoProc
        command: ["sh", "-c", "printf '%s\\n%s\\n' \"$(ip -4 -o addr show dev \"$1\" | awk '{split($4, a, \"/\"); print a[1]; exit}')\" \"$(ip route show default | awk '{print $3; exit}')\"", "sh", root.iface]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.localIp = (lines[0] ?? "").trim();
                root.gatewayIp = (lines[1] ?? "").trim();
            }
        }
    }

    Process {
        id: publicIpProc
        command: ["sh", "-c", "curl -s -4 --max-time 5 https://ifconfig.me || curl -s -6 --max-time 5 https://ifconfig.me"]
        stdout: StdioCollector {
            onStreamFinished: root.publicIp = text.trim()
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.run(statusProc)
    }

    Timer {
        interval: 2000
        running: root.isConnected
        repeat: true
        triggeredOnStart: true
        onTriggered: root.run(statsProc)
    }

    Timer {
        interval: 10000
        running: root.isConnected
        repeat: true
        onTriggered: root.run(infoProc)
    }

    Timer {
        interval: 300000
        running: root.isConnected
        repeat: true
        onTriggered: root.run(publicIpProc)
    }
}
