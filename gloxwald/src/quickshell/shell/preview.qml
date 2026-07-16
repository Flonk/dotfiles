// preview.qml — standalone lockscreen-shader preview.
//
// Renders a single scene in a normal floating window (no session lock, no bar),
// reusing the real LockContext so the clock/envelope uniforms behave exactly as
// they do on the lockscreen. Run against the working tree so it picks up freshly
// compiled .qsb files — the installed shell reads its shaders from /nix/store and
// will not see your edits.
//
//   qs -p ./quickshell/shell/preview.qml
//   SHADER_SCENE=auroras qs -p ./quickshell/shell/preview.qml
//
// See the `shader-dev` just recipe for the watch-recompile-reload loop.
import QtQuick
import Quickshell

FloatingWindow {
    id: win
    implicitWidth: 1280
    implicitHeight: 800
    color: "black"

    // Scene name from $SHADER_SCENE, defaulting to the lockscreen default.
    property string scene: (typeof Quickshell.env === "function"
        ? (Quickshell.env("SHADER_SCENE") || "yamp")
        : "yamp")

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

        Component.onCompleted: sceneLoader.setSource("shaders/scenes/" + win.scene + ".qml", {
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
            Keys.onPressed: ctx.recordKeypress()
        }

        // Scene label + name overlay.
        Text {
            anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
            color: "#aaffffff"
            font.pixelSize: 13
            text: win.scene + "   " + (sceneLoader.item?.authorText ?? "")
        }
    }
}
