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

        ShaderEffectSource {
            id: dummyTexture
            sourceItem: Rectangle { width: 1; height: 1; color: "#111" }
            hideSource: true
        }

        Loader {
            id: sceneLoader
            anchors.fill: parent
        }

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
