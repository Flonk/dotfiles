pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real brightness: 0
    property string device: ""
    property int max: 0

    function setBrightness(value: real): void {
        brightness = Math.max(0, Math.min(1, value));
        Quickshell.execDetached(["brightnessctl", "s", `${Math.round(brightness * 100)}%`]);
    }

    Process {
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0].split(",");
                if (f.length >= 5 && parseInt(f[4]) > 0) {
                    root.max = parseInt(f[4]);
                    root.brightness = parseInt(f[2]) / root.max;
                    root.device = f[0];
                }
            }
        }
    }

    FileView {
        id: level
        path: root.device ? `/sys/class/backlight/${root.device}/brightness` : ""
        blockLoading: true
        onLoaded: {
            const v = parseInt(text());
            if (root.max > 0 && !isNaN(v))
                root.brightness = v / root.max;
        }
    }

    Timer {
        interval: 150
        running: root.device !== ""
        repeat: true
        onTriggered: level.reload()
    }
}
