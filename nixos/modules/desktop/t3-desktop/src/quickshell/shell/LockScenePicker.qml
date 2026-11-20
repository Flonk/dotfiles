import QtQuick

Column {
    id: root
    required property var context
    readonly property var ctx: context
    property bool open: true
    property int columns: 1
    property real buttonWidth: 120
    readonly property var modeNames: ["base", "field", "drop", "3d amp", "halftone", "shadow", "penrose", "scope", "spectrum", "prism", "gasket", "gravity", "fluid", "flap", "grid", "stars", "shatter", "title", "iris", "ink", "typewriter", "peel", "glitch", "blinds", "stamp", "fish", "traffic", "conveyor"]
    spacing: 8

    Text {
        color: "#ccffffff"
        font.pixelSize: 12
        font.family: "monospace"
        text: (root.open ? "▾ " : "▸ ") + "t " + root.ctx.elapsedTime.toFixed(1) + "s   x" + root.ctx.timeScale
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.open = !root.open }
    }

    Column {
        visible: root.open
        spacing: 2
        DevButton { width: root.buttonWidth; label: "auto"; active: root.ctx.devMode < 0; onClicked: { root.ctx.trafficMapPinned = false; root.ctx.jumpToMode(-1); } }
        Repeater {
            model: [{ title: "scenes", modes: root.ctx.sceneModes, accent: "#3aa8b8" }, { title: "transitions", modes: root.ctx.transitionModes, accent: "#d9a530" }]
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
                Grid {
                    columns: root.columns
                    spacing: 2
                    Repeater {
                        model: group.modelData.modes
                        DevButton {
                            required property int modelData
                            width: root.buttonWidth
                            accent: group.modelData.accent
                            label: { const s = root.ctx.sceneTable.find(x => x.mode === modelData); return root.modeNames[modelData] + (s ? " " + s.weight + " " + s.length : ""); }
                            active: root.ctx.devMode === modelData
                            onClicked: root.ctx.jumpToMode(modelData)
                        }
                    }
                }
            }
        }
    }
}
