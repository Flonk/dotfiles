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
    property int inset: 0
    property int topInset: T3.border
    property int radius: 0
    property real lift: 0.2
    property bool topEdge: true
    property bool label: false
    signal clicked(var mouse)
    signal scrolled(int direction)

    readonly property real level: Math.max(0, Math.min(1, value))
    readonly property bool hovered: hover.containsMouse
    readonly property color rest: T3.rest
    readonly property color ink: critical ? Theme.error400 : color
    readonly property color restEdge: T3.lighten(rest, lift)
    readonly property color inkEdge: T3.lighten(ink, lift)

    implicitWidth: barWidth
    implicitHeight: T3.band

    Item {
        id: bar
        y: meter.topInset + meter.inset
        width: meter.barWidth
        height: meter.height - meter.topInset - 2 * meter.inset

        readonly property real filled: meter.muted ? 0 : meter.level
        readonly property int fillHeight: Math.round((height - (meter.topEdge ? 2 : 1)) * filled)
        readonly property real edgeAt: fillHeight > 0 ? (height - 1 - fillHeight) / height : 1

        Rectangle {
            anchors.fill: parent
            radius: meter.radius
            gradient: Gradient {
                GradientStop { position: 0; color: bar.edgeAt > 0 ? meter.restEdge : meter.inkEdge }
                GradientStop { position: Math.max(0, bar.edgeAt - 0.0001); color: bar.edgeAt > 0 ? meter.restEdge : meter.inkEdge }
                GradientStop { position: bar.edgeAt; color: meter.inkEdge }
                GradientStop { position: 1; color: meter.inkEdge }
            }
        }

        Rectangle {
            id: well
            anchors { fill: parent; margins: 1; topMargin: meter.topEdge ? 1 : 0 }
            radius: Math.max(0, meter.radius - 1)
            color: meter.rest

            Item {
                anchors.bottom: parent.bottom
                width: parent.width
                height: bar.fillHeight
                clip: true

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: well.width
                    height: well.height
                    radius: well.radius
                    color: meter.ink
                }
            }
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
