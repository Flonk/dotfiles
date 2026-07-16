import QtQuick
import "../.."
Item {
    property var context
    property int frameCount: 0
    property var dummyTexture
    readonly property string authorText: "'Isovalues 3' by FabriceNeyret2"
    readonly property bool interactive: true

    LockShaderPass {
        id: bufA; visible: false; width: parent.width; height: parent.height
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "isovalues_3_bufferA"
        iChannel0: bufASrc
    }
    ShaderEffectSource { id: bufASrc; sourceItem: bufA; hideSource: true; recursive: true }

    LockShaderPass {
        anchors.fill: parent
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "isovalues_3"
        iChannel0: bufASrc
    }
}
