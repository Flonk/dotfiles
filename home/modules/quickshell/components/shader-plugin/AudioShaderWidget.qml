// AudioShaderWidget.qml - Floating audio-reactive shader visualization
import QtQuick
import QtQml
import Quickmilk 1.0
import ShaderPlugin 1.0

Rectangle {
    id: root
    width: 300
    height: 300
    color: "transparent"

    property int fps: 60
    property int maxBars: 80

    property color backgroundColor: Qt.rgba(0.05, 0.05, 0.08, 0.9)
    property color accentColorA: Qt.rgba(0.65, 0.47, 0.92, 1.0)
    property color accentColorB: Qt.rgba(0.25, 0.72, 0.96, 1.0)

    Quickmilk {
        id: quickmilk
        maxBars: root.maxBars
        enableMonstercatFilter: true
    }

    readonly property var levelsTexture: dataTextureSource

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
            resolution: Qt.size(192, 64)
        }

        vertexShader: "audio_orb.vert.qsb"
        fragmentShader: "audio_orb.frag.qsb"

        NumberAnimation on time {
            from: 0
            to: 100000
            duration: 600000
            loops: Animation.Infinite
            running: true
        }
    }
}
