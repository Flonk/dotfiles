import QtQuick

Item {
    id: ev

    property string time
    property string source
    property string topic
    property string text
    property string detail
    property string level
    property bool attention
    property bool conforming: true

    property bool showTime: true
    property bool showSource: false
    property bool showTopic: false
    property bool showDetail: true
    property bool inline: false

    readonly property var levelColor: ({ error: Theme.error400, warn: "#d6b13c", info: T3.cream })
    readonly property string flag: conforming ? "" : "? "
    readonly property string head: [showTime ? time : "", showSource ? source : "", showTopic ? topic : ""].filter(s => s).join("  ")
    readonly property var rows: inline
        ? [{ text: flag + [showTime ? time : "", text].filter(s => s).join("  "), dim: !conforming, small: false }]
        : [
            { text: head ? flag + head : "", dim: true, small: true },
            { text: (head ? "" : flag) + text, dim: !conforming, small: false },
            { text: showDetail ? detail : "", dim: true, small: true }
        ].filter(r => r.text !== "")

    implicitHeight: lines.implicitHeight

    Rectangle {
        width: 3
        height: parent.height
        radius: 1
        color: ev.attention ? Theme.error400 : ev.levelColor[ev.level] ?? T3.ink
        opacity: ev.attention || ev.level in ev.levelColor ? 1 : 0.35
    }

    Column {
        id: lines
        x: 9
        width: parent.width - x
        spacing: 1

        Repeater {
            model: ev.rows

            Text {
                required property var modelData
                width: lines.width
                text: modelData.text
                elide: Text.ElideRight
                wrapMode: modelData.small ? Text.NoWrap : Text.Wrap
                maximumLineCount: modelData.small ? 1 : 2
                lineHeight: 0.95
                color: T3.ink
                opacity: modelData.dim ? 0.55 : 1
                font.family: Theme.fontFamily
                font.pixelSize: modelData.small ? T3.labelSize - 1 : T3.labelSize
                font.weight: modelData.small ? Font.Normal : Font.Medium
            }
        }
    }
}
