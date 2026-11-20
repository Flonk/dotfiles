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
            path: Quickshell.shellPath("shaders/scenes/yamp.qml")
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

        LockDevPanel {
            anchors.fill: parent
            visible: win.dev
            context: ctx
            onRestart: { surface.sceneRev++; surface.loadScene(); }
        }
    }
}
