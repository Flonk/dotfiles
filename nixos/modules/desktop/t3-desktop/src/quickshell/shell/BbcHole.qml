import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: hole

    property Item frame: null
    property var states: ({})
    property var subagents: ({})
    property var metas: ({})
    property var mutexStates: ({})
    property var mutexWaiting: ({})
    property int dot: 16
    property int gap: 4
    property int padding: 9

    readonly property var modelLetter: ({ opus: "O", sonnet: "S", haiku: "H" })
    readonly property var stateColor: ({ online: T3.accent2, thinking: "#d6b13c", heavy: Theme.error400, waiting: "#948fe8", offline: "#6b7078" })
    readonly property var mutexColor: ({ off: "#6b7078", free: T3.accent2, busy: "#d6b13c", held: "#d6b13c", yours: "#d6b13c" })
    readonly property var mutexColorFor: ({ vpn3it: { free: "#6b7078", held: T3.accent2 } })
    readonly property var mutexLabel: ({ crdp: "R", vpn3it: "3" })
    readonly property var mutexAction: ({ vpn3it: ["vpn3it-toggle"], crdp: ["vpn3it", "crdp", "grab"] })
    readonly property var mutexes: Object.keys(mutexStates).sort()
    function metaOf(name) {
        try {
            return JSON.parse(metas[name] ?? "null");
        } catch (e) {
            return null;
        }
    }

    readonly property var cells: {
        const out = [];
        const names = new Set(Object.keys(metas));
        for (const name of Object.keys(states))
            if (states[name] !== "offline")
                names.add(name);
        for (const name of names) {
            const m = metaOf(name);
            const model = m?.model ?? name.slice(name.lastIndexOf("-") + 1);
            out.push({
                name: name,
                host: m?.installation ?? name.slice(0, name.lastIndexOf("-")),
                label: m?.icon ?? modelLetter[model] ?? name.slice(name.lastIndexOf("-") + 1, name.lastIndexOf("-") + 2).toUpperCase()
            });
        }
        return out.sort((a, b) => a.host === b.host ? a.name.localeCompare(b.name) : b.host.localeCompare(a.host));
    }

    readonly property vector4d cutout: {
        x; y; width; height; visible; parent?.x; parent?.y; parent?.parent?.x; parent?.parent?.y; frame?.width;
        if (!frame || !visible)
            return Qt.vector4d(0, 0, 0, 0);
        const p = mapToItem(frame, 0, 0);
        return Qt.vector4d(Math.round(p.x) + 1, Math.round(p.y), width - 2, height);
    }

    property bool hidden: false

    visible: !hidden && (cells.length > 0 || mutexes.length > 0)
    implicitWidth: 2 + 2 * padding + content.implicitWidth
    implicitHeight: T3.band

    Process {
        id: feed
        running: true
        command: ["mosquitto_sub", "-h", "127.0.0.1", "-F", "%t %p", "-t", "agent/+/state", "-t", "agent/+/subagents", "-t", "agent/+/meta", "-t", "mutex/+/state", "-t", "mutex/+/waiting"]
        stdout: SplitParser {
            onRead: line => {
                const cut = line.indexOf(" ");
                const topic = cut < 0 ? line : line.slice(0, cut);
                const payload = cut < 0 ? "" : line.slice(cut + 1).trim();
                const [root, name, kind] = topic.split("/");
                if (!name)
                    return;
                const key = root === "mutex" ? (kind === "waiting" ? "mutexWaiting" : "mutexStates") : kind === "subagents" ? "subagents" : kind === "meta" ? "metas" : "states";
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
        visible: hole.cells.length > 0
        flow: Grid.TopToBottom
        rows: 2
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
                label: subs > 0 ? String(subs) : modelData.label
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
                id: mutexSquare
                required property string modelData
                readonly property string mstate: hole.mutexStates[modelData] ?? "free"
                readonly property int waiting: parseInt(hole.mutexWaiting[modelData] ?? "0") || 0
                property bool pending: false
                property bool failed: false
                onMstateChanged: pending = false
                ink: failed || (waiting > 0 && mstate !== "yours") ? Theme.error400 : (hole.mutexColorFor[modelData] ?? hole.mutexColor)[mstate] ?? hole.stateColor.offline
                dark: failed || !(mstate === "off" || (modelData in hole.mutexColorFor && mstate === "free"))
                label: failed ? "!" : waiting > 0 ? String(waiting) : hole.mutexLabel[modelData] ?? modelData.slice(0, 2)
                glow: mstate === "yours" && !failed
                busy: pending && !failed
                clickable: modelData in hole.mutexAction && !pending
                onClicked: {
                    failed = false;
                    pending = true;
                    settle.restart();
                    action.command = hole.mutexAction[modelData];
                    action.running = true;
                }

                Process {
                    id: action
                    onExited: code => {
                        if (code === 0)
                            return;
                        mutexSquare.pending = false;
                        mutexSquare.failed = true;
                        failure.restart();
                    }
                }

                Timer {
                    id: settle
                    interval: 5000
                    onTriggered: mutexSquare.pending = false
                }

                Timer {
                    id: failure
                    interval: 2000
                    onTriggered: mutexSquare.failed = false
                }
            }
        }
    }
    }
}
