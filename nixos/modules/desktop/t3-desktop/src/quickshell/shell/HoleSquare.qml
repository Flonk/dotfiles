import QtQuick

Rectangle {
    id: square

    property string label
    property color ink
    property bool dark: true
    property bool clickable: false
    signal clicked
    readonly property var nudge: ({ R: 0.8 })

    width: 16
    height: 16
    radius: 4
    color: ink
    border.width: 1
    border.color: T3.lighten(ink, 0.2)

    Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: square.nudge[square.label] ?? 0
        text: square.label
        color: square.dark ? T3.ground : T3.cream
        font.family: Theme.fontFamily
        font.pixelSize: T3.labelSize
        font.weight: Font.Bold
    }

    MouseArea {
        anchors.fill: parent
        enabled: square.clickable
        cursorShape: Qt.PointingHandCursor
        onClicked: square.clicked()
    }
}
