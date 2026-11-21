import QtQuick
import Quickshell.Io

Item {
    id: hole

    property Item frame: null
    property var states: ({})
    property var subagents: ({})
    property int dot: 16
    property int gap: 4
    property int padding: 9

    readonly property var modelRank: ["opus", "sonnet", "haiku"]
    readonly property var modelLetter: ({ opus: "O", sonnet: "S", haiku: "H" })
    readonly property var stateColor: ({ online: "#66b16a", thinking: "#d6b13c", heavy: Theme.error400, waiting: Theme.wm800, offline: "#6b7078" })
    readonly property var hosts: {
        const seen = {};
        for (const name of Object.keys(states))
            seen[name.slice(0, name.lastIndexOf("-"))] = true;
        return Object.keys(seen).sort().reverse();
    }
    readonly property var cells: {
        const out = [];
        for (const host of hosts)
            for (const model of modelRank)
                out.push({ name: host + "-" + model, model: model });
        return out;
    }

    readonly property vector4d cutout: {
        x; y; width; height; visible; parent?.x; parent?.y; parent?.parent?.x; parent?.parent?.y; frame?.width;
        if (!frame || !visible)
            return Qt.vector4d(0, 0, 0, 0);
        const p = mapToItem(frame, 0, 0);
        return Qt.vector4d(Math.round(p.x) + 1, Math.round(p.y), width - 2, height);
    }

    visible: hosts.length > 0
    implicitWidth: 2 + 2 * padding + 3 * dot + 2 * gap
    implicitHeight: T3.band

    Process {
        id: feed
        running: true
        command: ["mosquitto_sub", "-h", "127.0.0.1", "-v", "-t", "agent/+/state", "-t", "agent/+/subagents"]
        stdout: SplitParser {
            onRead: line => {
                const cut = line.indexOf(" ");
                const topic = cut < 0 ? line : line.slice(0, cut);
                const payload = cut < 0 ? "" : line.slice(cut + 1).trim();
                const [, name, kind] = topic.split("/");
                if (!name)
                    return;
                const key = kind === "subagents" ? "subagents" : "states";
                const next = Object.assign({}, hole[key]);
                if (payload)
                    next[name] = payload;
                else
                    delete next[name];
                hole[key] = next;
            }
        }
        onExited: retry.start()
    }

    Timer {
        id: retry
        interval: 5000
        onTriggered: feed.running = true
    }

    Grid {
        x: 1 + hole.padding
        anchors.verticalCenter: parent.verticalCenter
        columns: 3
        rowSpacing: hole.gap
        columnSpacing: hole.gap

        Repeater {
            model: hole.cells

            Rectangle {
                id: cell
                required property var modelData
                readonly property string state: hole.states[modelData.name] ?? "offline"
                readonly property int subs: state === "offline" ? 0 : parseInt(hole.subagents[modelData.name] ?? "0") || 0
                readonly property color ink: hole.stateColor[state] ?? hole.stateColor.offline

                width: hole.dot
                height: hole.dot
                radius: hole.dot / 2
                color: ink
                border.width: 1
                border.color: T3.lighten(ink, 0.2)

                Text {
                    anchors.centerIn: parent
                    text: cell.subs > 0 ? String(cell.subs) : hole.modelLetter[cell.modelData.model] ?? "?"
                    color: cell.state === "offline" ? T3.cream : T3.ground
                    font.family: Theme.fontFamily
                    font.pixelSize: T3.labelSize
                    font.weight: Font.Bold
                    font.capitalization: Font.AllUppercase
                }
            }
        }
    }
}
