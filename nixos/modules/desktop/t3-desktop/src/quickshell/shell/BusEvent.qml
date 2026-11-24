import QtQuick

Item {
    id: ev

    property string time
    property string source
    property string topic
    property string text
    property string detail
    property string icon
    property string level
    property bool attention
    property bool conforming: true
    property color ink: T3.ink

    property bool showTime: true
    property bool showSource: false
    property bool showTopic: false
    property bool showDetail: true
    property bool inline: false
    property bool columns: false

    readonly property var levelColor: ({ error: Theme.error400, warn: "#d6b13c", info: T3.cream })
    readonly property var iconColor: ({ error: Theme.error400, warn: "#d6b13c", info: T3.accent2 })
    readonly property real indent: icon ? 30 : 9
    readonly property string flag: conforming ? "" : "? "
    readonly property string head: [showTime ? time : "", showSource ? source : "", showTopic ? topic : ""].filter(s => s).join("  ")
    readonly property var rows: inline
        ? [{ text: flag + [showTime ? time : "", text].filter(s => s).join("  "), dim: !conforming, small: false }]
        : [
            { text: head ? flag + head : "", dim: true, small: true },
            { text: (head ? "" : flag) + text, dim: !conforming, small: false },
            { text: showDetail ? detail : "", dim: true, small: true }
        ].filter(r => r.text !== "")

    implicitHeight: columns ? Math.max(Math.ceil(lineMetrics.height * 0.95 * 3), message.implicitHeight, meta.implicitHeight) : lines.implicitHeight

    FontMetrics {
        id: lineMetrics
        font.family: Theme.fontFamily
        font.pixelSize: T3.labelSize
        font.weight: Font.Medium
    }

    Text {
        visible: ev.icon !== ""
        width: 22
        height: parent.height
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: ev.icon
        color: ev.attention ? Theme.error400 : ev.iconColor[ev.level] ?? ev.ink
        opacity: ev.attention || ev.level in ev.iconColor ? 1 : 0.55
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(T3.labelSize * 1.6)
    }

    Rectangle {
        width: 3
        visible: ev.icon === ""
        height: parent.height
        radius: 1
        color: ev.attention ? Theme.error400 : ev.levelColor[ev.level] ?? ev.ink
        opacity: ev.attention || ev.level in ev.levelColor ? 1 : 0.35
    }

    Column {
        id: lines
        visible: !ev.columns
        x: ev.indent
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
                color: ev.ink
                opacity: modelData.dim ? 0.55 : 1
                font.family: Theme.fontFamily
                font.pixelSize: modelData.small ? T3.labelSize - 1 : T3.labelSize
                font.weight: modelData.small ? Font.Normal : Font.Medium
            }
        }
    }

    Text {
        id: message
        visible: ev.columns
        x: ev.indent
        width: parent.width - x - meta.width - 16
        anchors.verticalCenter: parent.verticalCenter
        text: ev.flag + ev.text
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
        lineHeight: 0.95
        color: ev.ink
        opacity: ev.conforming ? 1 : 0.55
        font.family: Theme.fontFamily
        font.pixelSize: T3.labelSize
        font.weight: Font.Medium
    }

    Column {
        id: meta
        visible: ev.columns
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, parent.width * 0.3)
        spacing: 1

        Repeater {
            model: [ev.showTime ? ev.time : "", ev.showSource ? ev.source : "", ev.showTopic ? ev.topic : "", ev.showDetail ? ev.detail : ""].filter(s => s)

            Text {
                required property string modelData
                anchors.right: parent.right
                width: Math.min(implicitWidth, meta.parent.width * 0.3)
                horizontalAlignment: Text.AlignRight
                text: modelData
                elide: Text.ElideLeft
                color: ev.ink
                opacity: 0.55
                font.family: Theme.fontFamily
                font.pixelSize: T3.labelSize - 1
            }
        }
    }
}
