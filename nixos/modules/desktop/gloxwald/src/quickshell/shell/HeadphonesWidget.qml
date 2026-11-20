// HeadphonesWidget.qml
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string status: "idle"
    readonly property bool busy: root.status === "busy"

    function reconnect(): void {
        if (root.busy)
            return;
        root.status = "busy";
        settleTimer.stop();
        reconnectProc.running = true;
    }

    Process {
        id: reconnectProc

        command: ["bash", "-c", `
            target=""
            fallback=""
            for mac in $(bluetoothctl devices Paired | awk '{print $2}'); do
                info=$(bluetoothctl info "$mac")
                grep -q "Icon: audio-" <<< "$info" || continue
                [ -n "$fallback" ] || fallback=$mac
                if grep -q "Connected: yes" <<< "$info"; then
                    target=$mac
                    break
                fi
            done
            target=\${target:-$fallback}
            [ -n "$target" ] || exit 1
            bluetoothctl disconnect "$target" > /dev/null
            sleep 2
            bluetoothctl connect "$target"
        `]

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
