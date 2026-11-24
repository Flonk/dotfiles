import QtQuick
import QtQuick.Effects

Rectangle {
    id: square

    property string label
    property color ink
    property bool dark: true
    property bool clickable: false
    property bool glow: false
    signal clicked
    readonly property var nudge: ({ R: 0.8 })

    width: 16
    height: 16
    radius: 4
    color: ink
    border.width: 1
    border.color: T3.lighten(ink, glow ? 0.5 : 0.2)

    layer.enabled: glow
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: square.ink
        shadowBlur: 1.0
        shadowScale: 1.15
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        autoPaddingEnabled: true
    }

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
