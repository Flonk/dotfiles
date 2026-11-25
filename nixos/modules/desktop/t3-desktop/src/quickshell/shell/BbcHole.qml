import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: hole

    property Item frame: null
    property var states: ({})
    property var subagents: ({})
    property var mutexStates: ({})
    property var mutexWaiting: ({})
    property int dot: 16
    property int gap: 4
    property int padding: 9

    readonly property var modelRank: ["opus", "sonnet", "haiku"]
    readonly property var modelLetter: ({ opus: "O", sonnet: "S", haiku: "H" })
    readonly property var stateColor: ({ online: T3.accent2, thinking: "#d6b13c", heavy: Theme.error400, waiting: "#948fe8", offline: "#6b7078" })
    readonly property var mutexColor: ({ off: "#6b7078", free: T3.accent2, busy: "#d6b13c", held: "#d6b13c", yours: "#d6b13c" })
    readonly property var mutexColorFor: ({ vpn3it: { free: "#6b7078", held: T3.accent2 } })
    readonly property var mutexLabel: ({ crdp: "R", vpn3it: "3" })
    readonly property var mutexAction: ({ vpn3it: ["vpn3it-toggle"], crdp: ["vpn3it", "crdp", "grab"] })
    readonly property var mutexes: Object.keys(mutexStates).sort()
    readonly property var hosts: {
        const seen = {};
        for (const name of Object.keys(states))
            if (modelRank.includes(modelOf(name)))
                seen[name.slice(0, name.lastIndexOf("-"))] = true;
        return Object.keys(seen).sort().reverse();
    }
    function modelOf(name) {
        return name.slice(name.lastIndexOf("-") + 1);
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

    visible: hosts.length > 0 || mutexes.length > 0
    implicitWidth: 2 + 2 * padding + content.implicitWidth
    implicitHeight: T3.band

    Process {
        id: feed
        running: true
        command: ["mosquitto_sub", "-h", "127.0.0.1", "-F", "%t %p", "-t", "agent/+/state", "-t", "agent/+/subagents", "-t", "mutex/+/state", "-t", "mutex/+/waiting"]
        stdout: SplitParser {
            onRead: line => {
                const cut = line.indexOf(" ");
                const topic = cut < 0 ? line : line.slice(0, cut);
                const payload = cut < 0 ? "" : line.slice(cut + 1).trim();
                const [root, name, kind] = topic.split("/");
                if (!name)
                    return;
                const key = root === "mutex" ? (kind === "waiting" ? "mutexWaiting" : "mutexStates") : kind === "subagents" ? "subagents" : "states";
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

    Row {
        id: content
        x: 1 + hole.padding
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

    Grid {
        visible: hole.hosts.length > 0
        columns: 3
        rowSpacing: hole.gap
        columnSpacing: hole.gap

        Repeater {
            model: hole.cells

            HoleSquare {
                id: cell
                required property var modelData
                readonly property string state: hole.states[modelData.name] ?? "offline"
                readonly property int subs: state === "offline" ? 0 : parseInt(hole.subagents[modelData.name] ?? "0") || 0
                ink: hole.stateColor[state] ?? hole.stateColor.offline
                dark: state !== "offline"
                label: subs > 0 ? String(subs) : hole.modelLetter[modelData.model] ?? "?"
            }
        }
    }

    Grid {
        visible: hole.mutexes.length > 0
        flow: Grid.TopToBottom
        rows: 2
        rowSpacing: hole.gap
        columnSpacing: hole.gap

        Repeater {
            model: hole.mutexes

            HoleSquare {
                required property string modelData
                readonly property string state: hole.mutexStates[modelData] ?? "free"
                readonly property int waiting: parseInt(hole.mutexWaiting[modelData] ?? "0") || 0
                ink: waiting > 0 && state !== "yours" ? Theme.error400 : (hole.mutexColorFor[modelData] ?? hole.mutexColor)[state] ?? hole.stateColor.offline
                dark: !(state === "off" || (modelData in hole.mutexColorFor && state === "free"))
                label: waiting > 0 ? String(waiting) : hole.mutexLabel[modelData] ?? modelData.slice(0, 2)
                glow: state === "yours"
                clickable: modelData in hole.mutexAction
                onClicked: Quickshell.execDetached(hole.mutexAction[modelData])
            }
        }
    }
    }
}
