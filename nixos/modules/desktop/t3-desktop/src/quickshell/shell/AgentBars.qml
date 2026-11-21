import QtQuick
import Quickshell.Io

Row {
    id: root

    property var states: ({})
    property var subagents: ({})
    readonly property var modelLetter: ({ haiku: "H", sonnet: "S", opus: "O" })
    readonly property var modelRank: ["opus", "sonnet", "haiku"]
    readonly property var stateColor: ({ online: "#66b16a", thinking: "#d6b13c", heavy: Theme.error400, waiting: Theme.wm800, offline: "#6b7078" })
    readonly property var hosts: {
        const byHost = {};
        for (const name of Object.keys(states)) {
            const cut = name.lastIndexOf("-");
            const host = name.slice(0, cut);
            (byHost[host] = byHost[host] || []).push(name);
        }
        return Object.keys(byHost).sort().map(host => byHost[host].sort((a, b) => modelRank.indexOf(modelOf(a)) - modelRank.indexOf(modelOf(b))));
    }

    function modelOf(name) {
        return name.slice(name.lastIndexOf("-") + 1);
    }

    spacing: 4
    visible: hosts.length > 0

    Process {
        id: feed
        running: true
        command: ["mosquitto_sub", "-h", "127.0.0.1", "-v", "-t", "agent/+/state", "-t", "agent/+/subagents"]
        stdout: SplitParser {
            onRead: line => {
                const cut = line.indexOf(" ");
                const topic = cut < 0 ? line : line.slice(0, cut);
                const state = cut < 0 ? "" : line.slice(cut + 1).trim();
                const [, name, kind] = topic.split("/");
                if (!name)
                    return;
                const key = kind === "subagents" ? "subagents" : "states";
                const next = Object.assign({}, root[key]);
                if (state)
                    next[name] = state;
                else
                    delete next[name];
                root[key] = next;
            }
        }
        onExited: retry.start()
    }

    Timer {
        id: retry
        interval: 5000
        onTriggered: feed.running = true
    }

    Repeater {
        model: root.hosts

        Row {
            id: group
            required property var modelData
            spacing: 0

            Repeater {
                model: group.modelData

                Meter {
                    id: bar
                    required property string modelData
                    readonly property string state: root.states[modelData] ?? "offline"
                    readonly property int subs: state === "offline" ? 0 : parseInt(root.subagents[modelData] ?? "0") || 0

                    barWidth: 10
                    topEdge: false
                    label: true
                    interactive: false
                    color: root.stateColor[state] ?? root.stateColor.offline
                    value: 1
                    icon: subs > 0 ? String(subs) : root.modelLetter[root.modelOf(modelData)] ?? "?"
                }
            }
        }
    }
}
