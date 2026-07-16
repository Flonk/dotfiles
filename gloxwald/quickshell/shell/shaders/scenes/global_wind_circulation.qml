import QtQuick
import "../.."
Item {
    property var context
    property int frameCount: 0
    property var dummyTexture
    readonly property string authorText: "'Global Wind Circulation' by davidar"
    readonly property bool interactive: true

    LockShaderPass {
        id: bufA; visible: false; width: parent.width; height: parent.height
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "global_wind_circulation_bufferA"
    }
    ShaderEffectSource { id: bufASrc; sourceItem: bufA; hideSource: true }

    LockShaderPass {
        id: bufB; visible: false; width: parent.width; height: parent.height
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "global_wind_circulation_bufferB"
        iChannel0: bufASrc
        iChannel1: bufBSrc
    }
    ShaderEffectSource { id: bufBSrc; sourceItem: bufB; hideSource: true; recursive: true }

    LockShaderPass {
        id: bufC; visible: false; width: parent.width; height: parent.height
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "global_wind_circulation_bufferC"
        iChannel0: bufCSrc
        iChannel1: bufBSrc
    }
    ShaderEffectSource { id: bufCSrc; sourceItem: bufC; hideSource: true; recursive: true }

    LockShaderPass {
        anchors.fill: parent
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "global_wind_circulation"
        iChannel0: bufASrc
        iChannel1: bufBSrc
        iChannel2: bufCSrc
    }
}
