import QtQuick

Column {
    id: gallery

    property int cell: 440
    property color band: "#4ea8c9"

    readonly property var kinds: [
        { name: "info", time: "12:47:29", source: "skynet", topic: "screenshot/taken", text: "somebody has taken a screenshot", detail: "2026-11-21-124346_skynet.png", level: "info" },
        { name: "attention", time: "12:48:02", source: "claude/flo-chonkler-opus", topic: "agent/flo-chonkler-opus/event", text: "flo-chonkler-opus needs your input", detail: "", level: "warn", attention: true },
        { name: "warn", time: "12:49:13", source: "claude/claude-hetzner-haiku", topic: "agent/claude-hetzner-haiku/event", text: "claude-hetzner-haiku went offline", detail: "", level: "warn" },
        { name: "error", time: "12:50:40", source: "t3cron", topic: "cron/error", text: "bad schedule 'nonsense': invalid pattern", detail: "nightly-backup", level: "error" },
        { name: "verbose", time: "12:51:00", source: "t3cron", topic: "cron/fired", text: "fired standup -> demo/standup", detail: "", level: "verbose" },
        { name: "no data", time: "12:52:11", source: "cli", topic: "demo/hello", text: "hello from the cli", detail: "", level: "info" },
        { name: "long", time: "12:53:30", source: "claude/flo-chonkler-sonnet", topic: "agent/flo-chonkler-sonnet/event", text: "flo-chonkler-sonnet is running 3 subagents while refactoring the chrome shader and the header layout", detail: "a-very-long-detail-value-that-will-definitely-not-fit-in-here.png", level: "info" },
        { name: "non-schema", time: "12:54:05", source: "", topic: "demo/legacy", text: "not a schema event", detail: "", level: "", conforming: false }
    ]

    readonly property var variants: [
        { name: "live: time / text / detail", showTime: true, showDetail: true },
        { name: "no time", showTime: false, showDetail: true },
        { name: "inline time", showTime: true, showDetail: false, inline: true },
        { name: "old: full head", showTime: true, showSource: true, showTopic: true, showDetail: true }
    ]

    spacing: 14

    component Caption: Text {
        color: T3.cream
        opacity: 0.6
        font.family: Theme.fontFamily
        font.pixelSize: T3.labelSize
        font.weight: Font.Bold
        font.letterSpacing: T3.labelTracking
        font.capitalization: Font.AllUppercase
    }

    Repeater {
        model: gallery.variants

        Column {
            id: variantRow
            required property var modelData
            spacing: 6

            Caption {
                text: variantRow.modelData.name
            }

            Grid {
            columns: 2
            spacing: 8

            Repeater {
                model: gallery.kinds

                Rectangle {
                    required property var modelData
                    width: gallery.cell
                    height: T3.band
                    color: gallery.band
                    clip: true

                    BusEvent {
                        x: 8
                        width: parent.width - 16
                        anchors.verticalCenter: parent.verticalCenter
                        time: parent.modelData.time
                        source: parent.modelData.source
                        topic: parent.modelData.topic
                        text: parent.modelData.text
                        detail: parent.modelData.detail
                        level: parent.modelData.level
                        attention: parent.modelData.attention ?? false
                        conforming: parent.modelData.conforming ?? true
                        showTime: variantRow.modelData.showTime
                        showSource: variantRow.modelData.showSource ?? false
                        showTopic: variantRow.modelData.showTopic ?? false
                        showDetail: variantRow.modelData.showDetail
                        inline: variantRow.modelData.inline ?? false
                    }
                }
            }
            }
        }
    }
}
