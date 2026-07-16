import QtQuick
import "../.."
Item {
    property var context
    property int frameCount: 0
    property var dummyTexture
    readonly property string authorText: "'Superquadratic Reflections' by mrange"
    readonly property bool interactive: false

    LockShaderPass {
        id: bufA; visible: false; width: parent.width; height: parent.height
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "superquadratic_reflections_bufferA"
    }
    ShaderEffectSource { id: bufASrc; sourceItem: bufA; hideSource: true }

    LockShaderPass {
        anchors.fill: parent
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "superquadratic_reflections"
        iChannel0: bufASrc
    }
}
