import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root
    required property var context

    property bool renderScene: true

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
            if (root.renderScene) root.context.frameTick(root);
        }
    }
    Component.onDestruction: root.context.releaseClock(root)

    ShaderEffectSource {
        id: dummyTexture
        sourceItem: Rectangle { width: 1; height: 1; color: "#111" }
        hideSource: true
    }

    property string authorText: shaderLoader.item?.authorText ?? ""

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

    Loader {
        id: shaderLoader
        anchors.fill: parent
        asynchronous: true
    }

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
        cutout4: lockHeader.cutout4
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

    MouseArea {
        anchors.fill: parent
        onClicked: passwordInput.forceActiveFocus()
    }

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
