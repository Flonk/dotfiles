import QtQuick
import "../.."
Item {
    property var context
    property int frameCount: 0
    property var dummyTexture
    readonly property string authorText: "'Monster' by iq"
    readonly property bool interactive: false

    Image { id: tex; source: "../assets/monster_iChannel0.jpg"; visible: false }
    ShaderEffectSource { id: texSrc; sourceItem: tex; hideSource: true }

    LockShaderPass {
        anchors.fill: parent
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "monster"
        iChannel0: texSrc
    }
}
