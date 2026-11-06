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

FloatingWindow {
    id: win
    implicitWidth: 1280
    implicitHeight: 800
    color: "black"

    readonly property bool dev: Quickshell.env("SHADER_DEV") === "1"
    readonly property var modeNames: ["base", "field", "drop", "3d amp", "halftone", "shadow", "penrose", "scope", "spectrum", "prism", "gasket", "gravity"]

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

    LockContext {
        id: ctx
        Component.onCompleted: {
            clockStart = Date.now();
            elapsedTime = 0;
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

        Component.onCompleted: sceneLoader.setSource("shaders/scenes/yamp.qml", {
            "context": Qt.binding(() => ctx),
            "frameCount": Qt.binding(() => surface.frameCount),
            "dummyTexture": dummyTexture,
        })

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
                if (win.dev && event.key === Qt.Key_M) {
                    ctx.matte = !ctx.matte;
                    event.accepted = true;
                    return;
                }
                if (win.dev && event.key === Qt.Key_P) {
                    ctx.setTimeScale(ctx.timeScale === 0 ? 1 : 0);
                    event.accepted = true;
                    return;
                }
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
                    text: "t " + ctx.elapsedTime.toFixed(1) + "s   x" + ctx.timeScale
                }

                Row {
                    spacing: 4
                    DevButton { label: "auto"; active: ctx.devMode < 0; onClicked: ctx.jumpToMode(-1) }
                    Repeater {
                        model: win.modeNames
                        DevButton {
                            required property int index
                            required property string modelData
                            label: modelData ? (index + 1) + " " + modelData : String(index + 1)
                            active: ctx.devMode === index
                            onClicked: ctx.jumpToMode(index)
                        }
                    }
                }

                Row {
                    spacing: 4
                    DevButton { label: "gold wave"; accent: "#d9a530"; onClicked: ctx.sendGoldWave() }
                    DevButton { label: "keypress"; onClicked: ctx.recordKeypress() }
                    DevButton { label: "fail"; accent: "#e35532"; onClicked: ctx.sendFail() }
                    DevButton { label: "matte"; active: ctx.matte; onClicked: ctx.matte = !ctx.matte }
                }

                Row {
                    spacing: 4
                    DevButton {
                        label: ctx.timeScale === 0 ? "play" : "pause"
                        onClicked: ctx.setTimeScale(ctx.timeScale === 0 ? 1 : 0)
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
            }
        }

        Text {
            anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
            color: "#aaffffff"
            font.pixelSize: 13
            text: "yamp   " + (sceneLoader.item?.authorText ?? "")
                + (win.dev
                    ? "   mode " + (ctx.devMode < 0 ? "auto" : ctx.devMode + 1) + "   [m matte, p pause]"
                    : "")
        }
    }
}
