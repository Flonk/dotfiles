pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real brightness: 0

    function setBrightness(value: real): void {
        brightness = Math.max(0, Math.min(1, value));
        Quickshell.execDetached(["brightnessctl", "s", `${Math.round(brightness * 100)}%`]);
    }

    Process {
        id: poll
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length >= 5 && parseInt(f[4]) > 0)
                    root.brightness = parseInt(f[2]) / parseInt(f[4]);
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }
}
