// CameraWidget.qml
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string status: "idle"
    readonly property bool busy: root.status === "busy"

    function reset(): void {
        if (root.busy)
            return;
        root.status = "busy";
        settleTimer.stop();
        resetProc.running = true;
    }

    Process {
        id: resetProc

        command: ["systemctl", "start", "camera-reset.service"]

        onExited: (code) => {
            root.status = code === 0 ? "ok" : "fail";
            settleTimer.restart();
        }
    }

    Timer {
        id: settleTimer
        interval: 3000
        onTriggered: root.status = "idle"
    }
}
