pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    property var clients: []
    property var monitors: []
    property string activeAddress: ""
    property int tabHeight: 22
    property bool pending: false

    function refresh(): void {
        if (proc.running)
            pending = true;
        else
            proc.running = true;
    }

    function cornersFor(monitorName: string): var {
        const mon = monitors.find(m => m.name === monitorName);
        if (!mon)
            return null;
        const bw = T3.windowBorder;
        const boxes = clients
            .filter(c => c.monitor === mon.id && c.workspace?.id === mon.activeWorkspace?.id && !c.floating && c.mapped)
            .map(c => ({
                x0: c.at[0] - bw - mon.x,
                y0: c.at[1] - bw - mon.y,
                x1: c.at[0] + c.size[0] + bw - mon.x,
                y1: c.at[1] + c.size[1] + bw - mon.y,
                active: c.address === activeAddress,
                fullscreen: c.fullscreen > 0
            }));
        if (boxes.length === 0 || boxes.some(b => b.fullscreen))
            return null;
        const left = Math.min(...boxes.map(b => b.x0));
        const right = Math.max(...boxes.map(b => b.x1));
        const bottom = Math.max(...boxes.map(b => b.y1));
        const top = Math.min(...boxes.map(b => b.y0 - (b.y0 > T3.band + T3.gapsOut + 1 ? tabHeight : 0)));
        const reach = tabHeight + 4;
        const pick = (x, y) => {
            const hits = boxes.filter(b => x >= b.x0 - 1 && x <= b.x1 + 1 && y >= b.y0 - reach && y <= b.y1 + 1);
            const tab = y === top && hits.length > 0 && hits.every(b => b.y0 > top + 1);
            return { x, y, on: hits.length > 0, active: hits.some(b => b.active), tab };
        };
        return { tl: pick(left, top), tr: pick(right, top), bl: pick(left, bottom), br: pick(right, bottom) };
    }

    Process {
        id: proc
        command: ["sh", "-c", "printf '{\"clients\":%s,\"active\":%s,\"monitors\":%s,\"tab\":%s}' \"$(hyprctl -j clients)\" \"$(hyprctl -j activewindow)\" \"$(hyprctl -j monitors)\" \"$(hyprctl -j getoption plugin:hy3:tabs:height)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.clients = j.clients;
                    root.monitors = j.monitors;
                    root.activeAddress = j.active?.address ?? "";
                    root.tabHeight = j.tab?.int ?? 22;
                } catch (e) {
                    console.warn("[WindowCorners]", e);
                }
            }
        }
        onExited: {
            if (root.pending) {
                root.pending = false;
                running = true;
            }
        }
    }

    Timer {
        id: debounce
        interval: 30
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            debounce.restart();
        }
    }

    Component.onCompleted: refresh()
}
