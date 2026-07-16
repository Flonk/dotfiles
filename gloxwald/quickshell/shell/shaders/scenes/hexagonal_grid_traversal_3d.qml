import QtQuick
import "../.."
Item {
    property var context
    property int frameCount: 0
    property var dummyTexture
    readonly property string authorText: "'Hexagonal Grid Traversal - 3D' by iq"
    readonly property bool interactive: true

    Image { id: tex0; source: "../assets/hexagonal_grid_traversal_3d_iChannel0.jpg"; visible: false }
    ShaderEffectSource { id: tex0Src; sourceItem: tex0; hideSource: true }
    Image { id: tex1; source: "../assets/random.png"; visible: false }
    ShaderEffectSource { id: tex1Src; sourceItem: tex1; hideSource: true }

    LockShaderPass {
        anchors.fill: parent
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "hexagonal_grid_traversal_3d"
        iChannel0: tex0Src
        iChannel1: tex1Src
    }
}
