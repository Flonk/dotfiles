import QtQuick
import Quickshell.Io

Item {
    id: ticker

    property var ignore: ["cron/jobs", "cron/status", "agent/+/state", "agent/+/subagents"]
    readonly property var levels: ["error", "warn", "info", "http", "verbose", "debug", "silly"]
    readonly property var levelColor: ({ error: Theme.error400, warn: "#d6b13c", info: T3.accent2 })
    property int hold: 30000
    property int duration: 220
    property Item current: null
    property Item frame: null
    property Item join: null
    property int padding: 12

    readonly property vector4d cutout: {
        x; y; width; height; visible; parent?.x; parent?.y; frame?.width; join?.x; join?.width; join?.visible; join?.parent?.x;
        if (!frame || !visible || width <= 0)
            return Qt.vector4d(0, 0, 0, 0);
        const p = mapToItem(frame, 0, 0);
        const right = join && join.visible ? join.mapToItem(frame, join.width, 0).x - 1 : p.x + width - 1;
        return Qt.vector4d(Math.round(p.x) + 1, Math.round(p.y), Math.round(right - p.x - 1), height);
    }

    function matches(filter, topic) {
        const f = filter.split("/"), t = topic.split("/");
        for (let i = 0; i < f.length; i++) {
            if (f[i] === "#")
                return true;
            if (i >= t.length || (f[i] !== "+" && f[i] !== t[i]))
                return false;
        }
        return f.length === t.length;
    }

    function parse(payload) {
        try {
            const v = JSON.parse(payload);
            if (v && typeof v.timestamp === "string" && typeof v.source === "string" && levels.includes(v.level) && typeof v.attention === "boolean" && typeof v.description === "string")
                return v;
        } catch (e) {}
        return null;
    }

    function details(data) {
        return data && typeof data.detail === "string" ? data.detail : "";
    }

    function show(topic, payload) {
        if (ignore.some(f => matches(f, topic)))
            return;
        const ev = parse(payload);
        const at = ev ? new Date(ev.timestamp) : new Date();
        if (current)
            current.leave();
        current = line.createObject(ticker, {
            time: Qt.formatTime(isNaN(at) ? new Date() : at, "HH:mm:ss"),
            source: ev ? ev.source : "",
            topic: topic,
            text: ev ? ev.description : payload,
            detail: ev ? details(ev.data) : "",
            level: ev ? ev.level : "",
            attention: ev ? ev.attention : false,
            conforming: ev !== null
        });
    }

    clip: true

    Process {
        id: feed
        running: true
        command: ["mosquitto_sub", "-h", "127.0.0.1", "-F", "%t %p", "-R", "-t", "#"]
        stdout: SplitParser {
            onRead: data => {
                const cut = data.indexOf(" ");
                ticker.show(cut < 0 ? data : data.slice(0, cut), cut < 0 ? "" : data.slice(cut + 1).replace(/\s+/g, " ").trim());
            }
        }
        onExited: retry.start()
    }

    Timer {
        id: retry
        interval: 5000
        onTriggered: feed.running = true
    }

    Component {
        id: line

        Item {
            id: entry
            property string time
            property string source
            property string topic
            property string text
            property string detail
            property string level
            property bool attention
            property bool conforming
            readonly property real rest: (ticker.height - height) / 2

            function leave() {
                if (ticker.current === entry)
                    ticker.current = null;
                enter.stop();
                exit.start();
            }

            x: ticker.padding
            width: ticker.width - 2 * ticker.padding
            height: view.implicitHeight
            y: ticker.height

            Component.onCompleted: enter.start()

            NumberAnimation {
                id: enter
                target: entry
                property: "y"
                to: entry.rest
                duration: ticker.duration
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                id: exit
                target: entry
                property: "y"
                to: -entry.height
                duration: ticker.duration
                easing.type: Easing.InCubic
                onFinished: entry.destroy()
            }

            Timer {
                running: true
                interval: ticker.hold
                onTriggered: entry.leave()
            }

            BusEvent {
                id: view
                width: parent.width
                ink: T3.cream
                time: entry.time
                source: entry.source
                topic: entry.topic
                text: entry.text
                detail: entry.detail
                level: entry.level
                attention: entry.attention
                conforming: entry.conforming
            }
        }
    }
}
