import QtQuick
import QtQuick.Effects

Rectangle {
    id: square

    property string label
    property color ink
    property bool dark: true
    property bool clickable: false
    property bool glow: false
    property bool busy: false
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
        visible: !square.busy
        anchors.horizontalCenterOffset: square.nudge[square.label] ?? 0
        text: square.label
        color: square.dark ? T3.ground : T3.cream
        font.family: Theme.fontFamily
        font.pixelSize: T3.labelSize
        font.weight: Font.Bold
    }

    Canvas {
        id: spinner
        anchors.centerIn: parent
        width: 10
        height: 10
        visible: square.busy
        readonly property color stroke: square.dark ? T3.ground : T3.cream
        onStrokeChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.lineWidth = 2;
            ctx.lineCap = "round";
            ctx.strokeStyle = stroke;
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, 4, 0, Math.PI * 1.5);
            ctx.stroke();
        }

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 700
            loops: Animation.Infinite
            running: square.busy
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: square.clickable
        cursorShape: Qt.PointingHandCursor
        onClicked: square.clicked()
    }
}
