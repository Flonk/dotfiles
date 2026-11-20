import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    required property var context
    readonly property var ctx: context
    property bool scenesOpen: true
    readonly property var modeNames: ["base", "field", "drop", "3d amp", "halftone", "shadow", "penrose", "scope", "spectrum", "prism", "gasket", "gravity", "fluid", "flap", "grid", "stars", "shatter", "title", "iris", "ink", "typewriter", "peel", "glitch", "blinds", "stamp", "fish", "traffic", "conveyor"]
    property bool showRelock: false
    signal restart()

    Rectangle {
        anchors { left: parent.left; top: parent.top; margins: 12 }
        width: panel.implicitWidth + 20
        height: panel.implicitHeight + 20
        radius: 6
        color: "#cc111111"
        border.color: "#33ffffff"

        Column {
            id: panel
            anchors.centerIn: parent
            spacing: 8

            Text {
                color: "#ccffffff"
                font.pixelSize: 12
                font.family: "monospace"
                text: (root.scenesOpen ? "\u25be " : "\u25b8 ") + "t " + ctx.elapsedTime.toFixed(1) + "s   x" + ctx.timeScale
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.scenesOpen = !root.scenesOpen }
            }

            Column {
                visible: root.scenesOpen
                spacing: 2
                DevButton { width: 120; label: "auto"; active: ctx.devMode < 0; onClicked: { ctx.trafficMapPinned = false; ctx.jumpToMode(-1); } }
                Repeater {
                    model: [{ title: "scenes", modes: ctx.sceneModes, accent: "#3aa8b8" }, { title: "transitions", modes: ctx.transitionModes, accent: "#d9a530" }]
                    Column {
                        id: group
                        required property var modelData
                        spacing: 2
                        topPadding: 6
                        Text {
                            text: group.modelData.title
                            color: group.modelData.accent
                            font.pixelSize: 11
                            font.family: "monospace"
                            font.bold: true
                        }
                        Repeater {
                            model: group.modelData.modes
                            DevButton {
                                required property int modelData
                                width: 120
                                accent: group.modelData.accent
                                label: { const s = ctx.sceneTable.find(x => x.mode === modelData); return root.modeNames[modelData] + (s ? " " + s.weight + " " + s.length : ""); }
                                active: ctx.devMode === modelData
                                onClicked: ctx.jumpToMode(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors { right: parent.right; bottom: parent.bottom; margins: 12 }
        width: sceneTools.implicitWidth + 20
        height: sceneTools.implicitHeight + 20
        radius: 6
        color: "#cc111111"
        border.color: "#33ffffff"

        Column {
            id: sceneTools
            anchors.centerIn: parent
            spacing: 8

            Grid {
                columns: 5
                spacing: 4
                visible: ctx.devMode === 26
                FileView {
                    id: mapCars
                    property var cars: []
                    path: Quickshell.shellPath("shaders/assets/maps.json")
                    watchChanges: true
                    onFileChanged: reload()
                    onLoaded: cars = JSON.parse(text())
                }
                Repeater {
                    model: ctx.trafficMapNames
                    DevButton {
                        required property string modelData
                        required property int index
                        label: modelData + (mapCars.cars[index] !== undefined ? " " + mapCars.cars[index] : "")
                        active: ctx.trafficMap === index
                        onClicked: { ctx.trafficMapPinned = true; ctx.trafficCars = -1; ctx.trafficMap = index; }
                    }
                }
            }

            Row {
                spacing: 4
                visible: ctx.devMode === 9
                DevButton { label: "beam ↑"; onClicked: ctx.prismBeam = Qt.vector2d(ctx.prismBeam.x + 0.02, ctx.prismBeam.y) }
                DevButton { label: "beam ↓"; onClicked: ctx.prismBeam = Qt.vector2d(ctx.prismBeam.x - 0.02, ctx.prismBeam.y) }
                DevButton { label: "tilt ↑"; onClicked: ctx.prismBeam = Qt.vector2d(ctx.prismBeam.x, ctx.prismBeam.y + Math.PI / 360) }
                DevButton { label: "tilt ↓"; onClicked: ctx.prismBeam = Qt.vector2d(ctx.prismBeam.x, ctx.prismBeam.y - Math.PI / 360) }
                DevButton { label: "reroll"; accent: "#d9a530"; onClicked: ctx.prismRoll++ }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#ccffffff"
                    font.pixelSize: 12
                    font.family: "monospace"
                    text: "  height " + ctx.prismBeam.x.toFixed(2) + "  tilt " + (ctx.prismBeam.y * 180 / Math.PI).toFixed(1) + "°"
                }
            }

            Row {
                spacing: 4
                DevButton {
                    label: ctx.timeScale === 0 ? "play" : "pause"
                    onClicked: ctx.setTimeScale(ctx.timeScale === 0 ? 1 : 0)
                }
                DevButton {
                    label: "hold"
                    active: ctx.holdScene
                    onClicked: ctx.holdScene = !ctx.holdScene
                }
                Repeater {
                    model: [0.25, 1, 4, 16]
                    DevButton {
                        required property real modelData
                        label: "x" + modelData
                        active: ctx.timeScale === modelData
                        onClicked: ctx.setTimeScale(modelData)
                    }
                }
                DevButton { label: "+10s"; onClicked: ctx.skip(10) }
                DevButton { label: "+60s"; onClicked: ctx.skip(60) }
                DevButton { label: "+8m"; onClicked: ctx.skip(480) }
                DevButton { label: "restart"; accent: "#d9a530"; onClicked: root.restart() }
                DevButton { label: "relock"; accent: "#d9a530"; visible: root.showRelock; onClicked: root.ctx.reset() }
                DevButton {
                    label: "lanes"
                    visible: ctx.seqInfo[0] === 26
                    active: ctx.trafficDebug
                    onClicked: ctx.trafficDebug = !ctx.trafficDebug
                }
                DevButton {
                    label: "minimap"
                    visible: ctx.seqInfo[0] === 26
                    active: ctx.trafficMinimap
                    onClicked: ctx.trafficMinimap = !ctx.trafficMinimap
                }
                DevButton {
                    label: "meter"
                    visible: ctx.seqInfo[0] === 26
                    active: ctx.trafficMeter
                    onClicked: ctx.trafficMeter = !ctx.trafficMeter
                }
                DevButton {
                    label: "stuck"
                    visible: ctx.seqInfo[0] === 26
                    active: ctx.trafficStuck
                    onClicked: ctx.trafficStuck = !ctx.trafficStuck
                }
                DevButton {
                    label: "grid"
                    visible: ctx.seqInfo[0] === 27
                    active: ctx.showGrid
                    onClicked: ctx.showGrid = !ctx.showGrid
                }
            }
        }
    }
}
