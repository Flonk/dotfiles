// preview.qml — standalone lockscreen-shader preview.
//
// Renders yamp in a normal floating window (no session lock, no bar),
// reusing the real LockContext so the clock/envelope uniforms behave exactly as
// they do on the lockscreen. Run against the working tree so it picks up freshly
// compiled .qsb files — the installed shell reads its shaders from /nix/store and
// will not see your edits.
//
//   qs -p ./quickshell/shell/preview.qml
//
// See the `shader-dev` just recipe for the watch-recompile-reload loop.
import QtQuick
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: win
    implicitWidth: 1280
    implicitHeight: 800
    color: "black"

    readonly property bool dev: Quickshell.env("SHADER_DEV") === "1"
    property bool scenesOpen: true
    readonly property var modeNames: ["base", "field", "drop", "3d amp", "halftone", "shadow", "penrose", "scope", "spectrum", "prism", "gasket", "gravity", "fluid", "flap", "grid", "stars", "shatter", "title", "iris", "ink", "typewriter", "peel", "glitch", "blinds", "stamp", "fish", "traffic", "conveyor"]

    component DevButton: Rectangle {
        id: btn
        property string label
        property bool active: false
        property color accent: "#3aa8b8"
        signal clicked()
        implicitWidth: btnText.implicitWidth + 16
        implicitHeight: 24
        radius: 4
        color: active ? accent : (btnMouse.pressed ? "#55ffffff" : btnMouse.containsMouse ? "#33ffffff" : "#1affffff")
        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.label
            color: btn.active ? "black" : "white"
            font.pixelSize: 12
        }
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: btn.clicked()
        }
    }

    FileView {
        path: "/tmp/claude-1000/-home-flo-repos-personal-dotfiles/fb121087-7040-40a5-8153-d912d0bad83a/scratchpad/jump"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { const a = text().split(":"), m = parseInt(a[0]); if (a.length > 1) { ctx.trafficMapPinned = true; ctx.trafficMap = parseInt(a[1]); ctx.trafficCars = a.length > 2 ? parseInt(a[2]) : -1; const d = a.length > 3 ? parseInt(a[3]) : 0; ctx.trafficDebug = (d & 1) !== 0; ctx.trafficMinimap = (d & 2) !== 0; ctx.trafficMeter = (d & 4) !== 0; ctx.trafficStuck = (d & 8) !== 0; } if (m >= 0) ctx.jumpToMode(m); }
    }

    LockContext {
        id: ctx
        Component.onCompleted: {
            clockStart = Date.now();
            elapsedTime = 0;
            shuffleModes();
            if (Quickshell.env("SHADER_START")) jumpToMode(parseInt(Quickshell.env("SHADER_START")));
        }
    }

    Item {
        id: surface
        anchors.fill: parent

        property int frameCount: 0
        Connections {
            target: surface.Window.window
            function onFrameSwapped() {
                surface.frameCount += 1;
                ctx.frameTick(surface);
            }
        }
        Timer {
            interval: 100
            running: true
            repeat: true
            onTriggered: ctx.frameTick(surface)
        }

        // 1x1 dummy texture for unused iChannel slots (mirrors LockSurface).
        ShaderEffectSource {
            id: dummyTexture
            sourceItem: Rectangle { width: 1; height: 1; color: "#111" }
            hideSource: true
        }

        Loader {
            id: sceneLoader
            anchors.fill: parent
        }

        // the scene is loaded here, outside quickshell's own reload, so watch
        // the built scene file and reload it ourselves; a bumped query makes
        // the engine compile it afresh instead of reusing its cached copy
        property int sceneRev: 0
        function loadScene() {
            sceneLoader.setSource("shaders/scenes/yamp.qml" + (sceneRev ? "?r=" + sceneRev : ""), {
                "context": Qt.binding(() => ctx),
                "frameCount": Qt.binding(() => surface.frameCount),
                "dummyTexture": dummyTexture,
            });
        }
        Component.onCompleted: loadScene()
        FileView {
            path: Qt.resolvedUrl("shaders/scenes/yamp.qml").toString().replace(/^file:\/\//, "")
            watchChanges: true
            onFileChanged: sceneReload.restart()
        }
        Timer {
            id: sceneReload
            interval: 300
            onTriggered: { surface.sceneRev++; surface.loadScene(); }
        }

        // Interactive scenes read key envelopes; let the preview drive them.
        MouseArea {
            anchors.fill: parent
            onClicked: keyInput.forceActiveFocus()
        }
        TextInput {
            id: keyInput
            focus: true
            visible: false
            Keys.onPressed: event => {
                ctx.recordKeypress();
            }
        }

        Rectangle {
            visible: win.dev
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
                    text: (win.scenesOpen ? "\u25be " : "\u25b8 ") + "t " + ctx.elapsedTime.toFixed(1) + "s   x" + ctx.timeScale
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.scenesOpen = !win.scenesOpen }
                }

                Column {
                    visible: win.scenesOpen
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
                                    label: { const s = ctx.sceneTable.find(x => x.mode === modelData); return win.modeNames[modelData] + (s ? " " + s.weight + " " + s.length : ""); }
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
            visible: win.dev
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
                        path: Qt.resolvedUrl("shaders/assets/maps.json").toString().replace("file://", "")
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
}
