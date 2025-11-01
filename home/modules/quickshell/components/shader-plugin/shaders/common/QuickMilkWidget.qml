// QuickMilkWidget.qml - Generic audio-reactive shader visualization using Quickmilk data
import QtQuick
import QtQml
import Quickmilk 1.0

Rectangle {
    id: root
    color: "transparent"

    property real initialWidth: 300
    property real initialHeight: 300
    width: initialWidth
    height: initialHeight

    property int fps: 60
    property int maxBars: 80

    property color backgroundColor: Qt.rgba(0.05, 0.05, 0.08, 0.9)
    property color accentColorA: Qt.rgba(0.65, 0.47, 0.92, 1.0)
    property color accentColorB: Qt.rgba(0.25, 0.72, 0.96, 1.0)

    // Allow callers to override the compiled shader paths
    readonly property string defaultFragmentShaderSource: "experiment.frag.qsb"
    readonly property string defaultVertexShaderSource: "flat.vert.qsb"
    property var fragmentShaderSource: defaultFragmentShaderSource
    property var vertexShaderSource: defaultVertexShaderSource

    // Mesh resolution overrides; negative values fall back to width/height
    property int meshColumns: -1
    property int meshRows: -1
    readonly property int resolvedMeshColumns: meshColumns > 0 ? meshColumns : Math.max(1, Math.round(width))
    readonly property int resolvedMeshRows: meshRows > 0 ? meshRows : Math.max(1, Math.round(height))

    property alias shaderEffect: effect
    readonly property var levelsTexture: dataTextureSource

    Quickmilk {
        id: quickmilk
        maxBars: root.maxBars
        enableMonstercatFilter: true
    }

    QuickmilkDataTexture {
        id: dataTexture
        visible: false
        width: maxBars
        height: 1
        maxFps: root.fps
        maxBars: root.maxBars
        hub: quickmilk.hub
    }

    ShaderEffectSource {
        id: dataTextureSource
        sourceItem: dataTexture
        hideSource: true
        live: true
    }

    function resolveShader(path) {
        if (!path) {
            return "";
        }
        const value = path.toString ? path.toString() : path;
        if (value.startsWith("file:") || value.startsWith("qrc:") || value.startsWith("data:")) {
            return value;
        }
        return Qt.resolvedUrl(value);
    }

    ShaderEffect {
        id: effect
        anchors.fill: parent
        property real time: 0
        property vector2d resolution: Qt.vector2d(width, height)
        property variant source: dataTextureSource
        property color backgroundColor: root.backgroundColor
        property color accentColorA: root.accentColorA
        property color accentColorB: root.accentColorB

        mesh: GridMesh {
            resolution: Qt.size(root.resolvedMeshColumns, root.resolvedMeshRows)
        }

        vertexShader: resolveShader(root.vertexShaderSource)
        fragmentShader: resolveShader(root.fragmentShaderSource)

        NumberAnimation on time {
            from: 0
            to: 100000
            duration: 600000
            loops: Animation.Infinite
            running: true
        }
    }
}
