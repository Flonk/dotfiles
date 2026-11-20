import QtQuick
import Quickshell
import Quickshell.Io

Column {
    id: root
    required property var context
    readonly property var ctx: context
    property bool showRelock: false
    property int mapColumns: 5
    property real flowWidth: 0
    signal restart()
    spacing: 8

    Grid {
        columns: root.mapColumns
        spacing: 4
        visible: root.ctx.devMode === 26
        FileView {
            id: mapCars
            property var cars: []
            path: Quickshell.shellPath("shaders/assets/maps.json")
            watchChanges: true
            onFileChanged: reload()
            onLoaded: cars = JSON.parse(text())
        }
        Repeater {
            model: root.ctx.trafficMapNames
            DevButton {
                required property string modelData
                required property int index
                label: modelData + (mapCars.cars[index] !== undefined ? " " + mapCars.cars[index] : "")
                active: root.ctx.trafficMap === index
                onClicked: { root.ctx.trafficMapPinned = true; root.ctx.trafficCars = -1; root.ctx.trafficMap = index; }
            }
        }
    }

    Flow {
        width: root.flowWidth > 0 ? root.flowWidth : undefined
        spacing: 4
        visible: root.ctx.devMode === 9
        DevButton { label: "beam ↑"; onClicked: root.ctx.prismBeam = Qt.vector2d(root.ctx.prismBeam.x + 0.02, root.ctx.prismBeam.y) }
        DevButton { label: "beam ↓"; onClicked: root.ctx.prismBeam = Qt.vector2d(root.ctx.prismBeam.x - 0.02, root.ctx.prismBeam.y) }
        DevButton { label: "tilt ↑"; onClicked: root.ctx.prismBeam = Qt.vector2d(root.ctx.prismBeam.x, root.ctx.prismBeam.y + Math.PI / 360) }
        DevButton { label: "tilt ↓"; onClicked: root.ctx.prismBeam = Qt.vector2d(root.ctx.prismBeam.x, root.ctx.prismBeam.y - Math.PI / 360) }
        DevButton { label: "reroll"; accent: "#d9a530"; onClicked: root.ctx.prismRoll++ }
        Text {
            height: 24
            verticalAlignment: Text.AlignVCenter
            color: "#ccffffff"
            font.pixelSize: 12
            font.family: "monospace"
            text: "  height " + root.ctx.prismBeam.x.toFixed(2) + "  tilt " + (root.ctx.prismBeam.y * 180 / Math.PI).toFixed(1) + "°"
        }
    }

    Flow {
        width: root.flowWidth > 0 ? root.flowWidth : undefined
        spacing: 4
        DevButton {
            label: root.ctx.timeScale === 0 ? "play" : "pause"
            onClicked: root.ctx.setTimeScale(root.ctx.timeScale === 0 ? 1 : 0)
        }
        DevButton {
            label: "hold"
            active: root.ctx.holdScene
            onClicked: root.ctx.holdScene = !root.ctx.holdScene
        }
        Repeater {
            model: [0.25, 1, 4, 16]
            DevButton {
                required property real modelData
                label: "x" + modelData
                active: root.ctx.timeScale === modelData
                onClicked: root.ctx.setTimeScale(modelData)
            }
        }
        DevButton { label: "+10s"; onClicked: root.ctx.skip(10) }
        DevButton { label: "+60s"; onClicked: root.ctx.skip(60) }
        DevButton { label: "+8m"; onClicked: root.ctx.skip(480) }
        DevButton { label: "restart"; accent: "#d9a530"; onClicked: root.restart() }
        DevButton { label: "relock"; accent: "#d9a530"; visible: root.showRelock; onClicked: root.ctx.reset() }
        DevButton {
            label: "lanes"
            visible: root.ctx.seqInfo[0] === 26
            active: root.ctx.trafficDebug
            onClicked: root.ctx.trafficDebug = !root.ctx.trafficDebug
        }
        DevButton {
            label: "minimap"
            visible: root.ctx.seqInfo[0] === 26
            active: root.ctx.trafficMinimap
            onClicked: root.ctx.trafficMinimap = !root.ctx.trafficMinimap
        }
        DevButton {
            label: "meter"
            visible: root.ctx.seqInfo[0] === 26
            active: root.ctx.trafficMeter
            onClicked: root.ctx.trafficMeter = !root.ctx.trafficMeter
        }
        DevButton {
            label: "stuck"
            visible: root.ctx.seqInfo[0] === 26
            active: root.ctx.trafficStuck
            onClicked: root.ctx.trafficStuck = !root.ctx.trafficStuck
        }
        DevButton {
            label: "grid"
            visible: root.ctx.seqInfo[0] === 27
            active: root.ctx.showGrid
            onClicked: root.ctx.showGrid = !root.ctx.showGrid
        }
    }
}
