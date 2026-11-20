pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real volume: 0
    property bool muted: false

    function setVolume(value: real): void {
        volume = Math.max(0, Math.min(1, value));
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", `${Math.round(volume * 100)}%`]);
    }

    function toggleMute(): void {
        muted = !muted;
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
    }

    Process {
        id: poll
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/Volume:\s+([\d.]+)(\s+\[MUTED\])?/);
                if (m) {
                    root.volume = parseFloat(m[1]) || 0;
                    root.muted = !!m[2];
                }
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
