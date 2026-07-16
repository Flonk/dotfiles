import QtQuick
import "../.."
Item {
    property var context
    property int frameCount: 0
    property var dummyTexture
    readonly property string authorText: "'UI Noise Halo' by magician0809"
    readonly property bool interactive: true

    Image { id: noise; source: "../assets/fractalnoise.png"; visible: false }
    ShaderEffectSource { id: noiseSrc; sourceItem: noise; hideSource: true }

    LockShaderPass {
        anchors.fill: parent
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "ui_noise_halo"
        iChannel0: noiseSrc
    }
}
