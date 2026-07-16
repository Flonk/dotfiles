import QtQuick
import "../.."
Item {
    property var context
    property int frameCount: 0
    property var dummyTexture
    readonly property string authorText: "'Voxel Star Field' by nethe550"
    readonly property bool interactive: false

    LockShaderPass {
        id: bufA; visible: false; width: parent.width; height: parent.height
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "voxel_star_field_bufferA"
    }
    ShaderEffectSource { id: bufASrc; sourceItem: bufA; hideSource: true }

    LockShaderPass {
        id: bufB; visible: false; width: parent.width; height: parent.height
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "voxel_star_field_bufferB"
    }
    ShaderEffectSource { id: bufBSrc; sourceItem: bufB; hideSource: true }

    LockShaderPass {
        anchors.fill: parent
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "voxel_star_field"
        iChannel0: bufASrc
        iChannel1: bufBSrc
    }
}
