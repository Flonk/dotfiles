import QtQuick

Item {
    id: meter

    property string icon
    property color color: Theme.wm800
    property real value: 0
    property bool muted: false
    property bool critical: false
    property bool interactive: true
    property int buttons: Qt.NoButton
    property int barWidth: 20
    property bool label: false
    signal clicked(var mouse)
    signal scrolled(int direction)

    readonly property real level: Math.max(0, Math.min(1, value))
    readonly property bool hovered: hover.containsMouse
    readonly property color ink: critical ? Theme.error400 : color

    implicitWidth: barWidth
    implicitHeight: T3.band

    Item {
        id: bar
        width: meter.barWidth
        height: meter.height

        readonly property int fillHeight: Math.round((height - 1) * (meter.muted ? 0 : meter.level))

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: parent.width
            height: bar.fillHeight
            color: meter.ink
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: T3.lighten(meter.ink, 0.2)
        }

        Repeater {
            model: [false, true]

            Item {
                required property bool modelData
                readonly property int split: bar.height - 1 - bar.fillHeight
                y: modelData ? split : 0
                width: bar.width
                height: modelData ? bar.height - split : split
                clip: true

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: bar.height - 4 - height - parent.y
                    text: meter.icon
                    color: parent.modelData ? T3.ground : T3.cream
                    opacity: parent.modelData ? 0.85 : 0.75
                    font.family: Theme.fontFamily
                    font.pixelSize: meter.label ? T3.labelSize : 13
                    font.weight: meter.label ? Font.Bold : Font.Normal
                }
            }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        enabled: meter.interactive
        acceptedButtons: meter.buttons
        cursorShape: meter.buttons !== Qt.NoButton ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: m => meter.clicked(m)
        onWheel: w => meter.scrolled(w.angleDelta.y > 0 ? 1 : -1)
    }
}
