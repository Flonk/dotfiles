import QtQuick
import Quickshell

ShaderEffect {
    id: root
    property vector2d origin: Qt.vector2d(0, 0)
    property vector2d screenSize: Qt.vector2d(width, height)
    property vector4d markRect: Qt.vector4d(0, 0, 0, 0)
    property real overlayMode: 0
    property real plain: 0
    property vector4d cutout: Qt.vector4d(0, 0, 0, 0)

    readonly property vector2d itemSize: Qt.vector2d(width, height)
    readonly property real bandHeight: T3.band
    readonly property real border: T3.border
    readonly property real radius: T3.radius
    readonly property real outerRadius: T3.outerRadius
    readonly property color ground: T3.ground
    readonly property color accent: Theme.wm800

    property var noiseTex: noise
    property var dotsTex: dots
    property var markTex: markSource
    property var grainTex: grain
    property var gradientTex: gradient
    property var logoTex: logo

    vertexShader: "chrome/chrome.vert.qsb"
    fragmentShader: "chrome/chrome.frag.qsb" + (Quickshell.env("T3_DESKTOP_DEV") ? "?b=" + _boot : "")
    readonly property double _boot: Date.now()

    Image {
        id: noise
        source: "chrome/noise.png"
        visible: false
    }

    Image {
        id: dots
        source: "chrome/dots.png"
        visible: false
    }

    Image {
        id: gradient
        source: "chrome/gradient.png"
        visible: false
    }

    Image {
        id: logo
        source: "chrome/andamp_sdf.png"
        visible: false
    }

    Image {
        id: grain
        source: "chrome/grain.png"
        smooth: false
        visible: false
    }

    Text {
        id: markText
        width: Math.max(1, root.markRect.z)
        height: Math.max(1, root.markRect.w)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        topPadding: height * 0.05
        text: "T3"
        color: "white"
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.markRect.z * 15 / 40)
        font.weight: Font.Bold
    }

    ShaderEffectSource {
        id: markSource
        sourceItem: markText
        hideSource: true
        visible: false
    }
}
