import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property string corner: "tl"
    property real radius: T3.windowRadius
    property real stroke: T3.windowBorder
    property color fill: T3.ground
    property color line: "black"

    width: radius
    height: radius
    rotation: ({ tl: 0, tr: 90, br: 180, bl: 270 })[corner]

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: root.fill
            startX: 0
            startY: 0
            PathLine { x: root.radius; y: 0 }
            PathArc {
                x: 0
                y: root.radius
                radiusX: root.radius
                radiusY: root.radius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: 0; y: 0 }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.line
            strokeWidth: root.stroke
            capStyle: ShapePath.FlatCap
            startX: root.radius
            startY: root.stroke / 2
            PathArc {
                x: root.stroke / 2
                y: root.radius
                radiusX: root.radius - root.stroke / 2
                radiusY: root.radius - root.stroke / 2
                direction: PathArc.Counterclockwise
            }
        }
    }
}
