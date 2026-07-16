// LanguageWidget.qml - Current input method (via skynet-i18n)
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string label: ""
    property bool available: false

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.update()
    }

    Process {
        id: statusProc
        command: ["skynet-i18n", "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out.length > 0) {
                    root.label = out;
                    root.available = true;
                }
            }
        }

        onExited: (code) => {
            if (code !== 0) {
                root.available = false;
            }
        }
    }

    function update(): void {
        if (!statusProc.running) {
            statusProc.running = true;
        }
    }

    function cycle(): void {
        Quickshell.execDetached(["skynet-i18n", "cycle"]);
        refreshDelay.restart();
    }

    Timer {
        id: refreshDelay
        interval: 150
        onTriggered: root.update()
    }

    Component.onCompleted: {
        update();
    }
}
