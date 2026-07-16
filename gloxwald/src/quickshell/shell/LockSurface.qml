import QtQuick
import Quickshell

Item {
    id: root
    required property var context

    // Resolved scene name from the shared context (identical on every monitor)
    property string shader: context.activeShader

    property string _activeShader: ""

    function _pickShader() {
        _activeShader = shader;
    }

    // Per-surface frame counter; also drives the shared clock in LockContext
    // (frameTick ignores all but the first surface that ever ticked)
    property int _iFrame: 0
    Connections {
        target: root.Window.window
        function onFrameSwapped() {
            root._iFrame += 1;
            root.context.frameTick(root);
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

    onShaderChanged: _reloadShader()
    Component.onCompleted: _reloadShader()

    function _reloadShader() {
        _pickShader();
        shaderLoader.setSource("shaders/scenes/" + _activeShader + ".qml", {
            "context": Qt.binding(() => root.context),
            "frameCount": Qt.binding(() => root._iFrame),
            "dummyTexture": dummyTexture,
        });
    }

    // ---- Shader background (loaded per-shader) ----
    Loader {
        id: shaderLoader
        anchors.fill: parent
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

    // ---- Bottom bar (reuses the real bar) ----
    BarContent {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        lockscreen: true
        interactive: false
        authorText: root.authorText
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
