import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root
    required property var context

    // Only the largest screen renders the shader; the rest stay black
    // (bar and input still work) — one GPU-heavy render per lock
    property bool renderScene: true

    // Per-surface frame counter; also drives the shared clock in LockContext
    // (frameTick ignores all but the first surface that ever ticked)
    property int _iFrame: 0
    property bool _presented: false
    Connections {
        target: root.Window.window
        function onFrameSwapped() {
            root._iFrame += 1;
            if (!root._presented) {
                root._presented = true;
                root._reloadShader();
            }
            // black surfaces barely repaint — they can't sustain the clock
            // loop, so never own it
            if (root.renderScene) root.context.frameTick(root);
        }
    }
    Component.onDestruction: root.context.releaseClock(root)

    // 1x1 dummy texture for unused iChannel slots
    ShaderEffectSource {
        id: dummyTexture
        sourceItem: Rectangle { width: 1; height: 1; color: "#111" }
        hideSource: true
    }

    property string authorText: shaderLoader.item?.authorText ?? ""

    // Black base so shaders with partial alpha don't bleed through
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    property int sceneRev: 0
    onRenderSceneChanged: _reloadShader()
    onSceneRevChanged: _reloadShader()

    function _reloadShader() {
        if (!_presented)
            return;
        if (!renderScene) {
            shaderLoader.setSource("");
            return;
        }
        shaderLoader.setSource("shaders/scenes/yamp.qml" + (sceneRev ? "?r=" + sceneRev : ""), {
            "context": Qt.binding(() => root.context),
            "frameCount": Qt.binding(() => root._iFrame),
            "dummyTexture": dummyTexture,
        });
    }

    // ---- Shader background (loaded per-shader, render surface only) ----
    Loader {
        id: shaderLoader
        anchors.fill: parent
        asynchronous: true
    }

    // ---- Keypress dot indicator (for shaders without built-in feedback) ----
    Rectangle {
        id: keypressDot
        visible: shaderLoader.item && !shaderLoader.item.interactive
        anchors.centerIn: parent
        width: root.height * 0.08
        height: width
        radius: width / 2
        color: "white"
        opacity: 0

        SequentialAnimation {
            id: dotFlash
            NumberAnimation { target: keypressDot; property: "opacity"; to: 0.9; duration: 30 }
            NumberAnimation { target: keypressDot; property: "opacity"; to: 0; duration: 80; easing.type: Easing.OutQuad }
        }

        Connections {
            target: root.context
            function onCurrentTextChanged() {
                if (keypressDot.visible && root.context.currentText.length > 0)
                    dotFlash.restart();
            }
        }
    }

    ChromeSurface {
        anchors.fill: parent
        overlayMode: 1
        cutout: lockHeader.cutout
        cutout2: lockHeader.cutout2
        cutout3: lockHeader.cutout3
    }

    ChromeHeader {
        id: lockHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: T3.band
        screenSize: Qt.vector2d(root.width, root.height)
        monitor: Hyprland.focusedMonitor
        interactive: false
    }

    // ---- Hidden password input ----
    TextInput {
        id: passwordInput
        focus: true
        echoMode: TextInput.Password
        visible: false

        text: root.context.currentText
        onTextChanged: {
            if (text !== root.context.currentText) {
                root.context.currentText = text;
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Backspace && text.length === 0)
                return;
            root.context.recordKeypress();
        }

        Keys.onReturnPressed: {
            root.context.tryUnlock();
        }
        Keys.onEnterPressed: {
            root.context.tryUnlock();
        }
    }

    // Keep password input focused
    MouseArea {
        anchors.fill: parent
        onClicked: passwordInput.forceActiveFocus()
    }

    // ---- Failure flash overlay (for shaders without built-in feedback) ----
    Rectangle {
        anchors.fill: parent
        visible: shaderLoader.item && !shaderLoader.item.interactive
        color: "#e35532"
        opacity: root.context.showFailure ? 0.35 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
}
