import QtQuick

Item {
    id: root
    property alias text: first.text
    property alias font: first.font
    property alias textColor: first.color
    property bool scrolling: false
    property real speed: 15
    property int gap: 13
    property real offset: 0
    readonly property bool overflows: first.implicitWidth > width
    readonly property bool active: scrolling && overflows

    implicitHeight: first.implicitHeight
    clip: true
    onActiveChanged: if (!active) offset = 0

    Text {
        id: first
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        x: -root.offset
    }

    Text {
        visible: root.active
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        x: first.x + first.implicitWidth + root.gap
        text: first.text
        font: first.font
        color: first.color
    }

    NumberAnimation on offset {
        running: root.active
        loops: Animation.Infinite
        from: 0
        to: first.implicitWidth + root.gap
        duration: (first.implicitWidth + root.gap) / root.speed * 1000
    }
}
