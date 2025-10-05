// CavaShaderWidget.qml - Music visualizer using GLSL shader
import QtQuick
import CavaPlugin 1.0

Rectangle {
    id: root
    
    width: 200
    height: 30
    color: "transparent"
    
    // Providers for system and microphone audio
    property var systemProvider: CavaWidget
    property var microphoneProvider: CavaMicrophoneWidget
    
    // Configurable FPS for the animation
    property int fps: 30
    property int maxBars: 40

    // Anchoring behavior ("bottom", "top", "center")
    property string systemAnchor: "center"
    property string microphoneAnchor: "bottom"

    // Theme-driven colors
    property color systemColorLow: Theme.wm400
    property color systemColorHigh: Theme.wm700
    property color microphoneColorLow: Theme.app300
    property color microphoneColorHigh: Theme.app400

    property int barCount: 1

    function anchorToEnum(anchor) {
        switch ((anchor || "").toLowerCase()) {
        case "top": return 1;
        case "center": return 2;
        default: return 0; // bottom
        }
    }

    function updateDataTexture() {
        const sysValues = systemProvider && systemProvider.values ? systemProvider.values : [];
        const micValues = microphoneProvider && microphoneProvider.values ? microphoneProvider.values : [];
        const count = Math.max(1, Math.min(maxBars, Math.max(sysValues.length, micValues.length)));

        barCount = count;
        dataCanvas.requestPaint();
        dataTextureSource.scheduleUpdate();
    }

    onSystemProviderChanged: {
        if (systemProvider && typeof systemProvider.start === "function") {
            systemProvider.start();
        }
        if (systemProvider && systemProvider.bars !== undefined) {
            systemProvider.bars = maxBars;
        }
        if (systemProvider && systemProvider.enableMonstercatFilter !== undefined) {
            systemProvider.enableMonstercatFilter = true;
        }
        updateDataTexture();
    }

    onMicrophoneProviderChanged: {
        if (microphoneProvider && typeof microphoneProvider.start === "function") {
            microphoneProvider.start();
        }
        if (microphoneProvider && microphoneProvider.bars !== undefined) {
            microphoneProvider.bars = maxBars;
        }
        if (microphoneProvider && microphoneProvider.enableMonstercatFilter !== undefined) {
            microphoneProvider.enableMonstercatFilter = true;
        }
        updateDataTexture();
    }

    onMaxBarsChanged: {
        if (systemProvider && systemProvider.bars !== undefined) {
            systemProvider.bars = maxBars;
        }
        if (microphoneProvider && microphoneProvider.bars !== undefined) {
            microphoneProvider.bars = maxBars;
        }
        updateDataTexture();
    }

    Canvas {
        id: dataCanvas
        visible: false
        width: root.barCount
        height: 1
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const sysValues = root.systemProvider && root.systemProvider.values ? root.systemProvider.values : [];
            const micValues = root.microphoneProvider && root.microphoneProvider.values ? root.microphoneProvider.values : [];
            for (let i = 0; i < width; ++i) {
                const sys = Math.max(0, Math.min(1, sysValues[i] ?? 0));
                const mic = Math.max(0, Math.min(1, micValues[i] ?? 0));
                const r = Math.round(sys * 255);
                const g = Math.round(mic * 255);
                ctx.fillStyle = `rgba(${r},${g},0,1)`;
                ctx.fillRect(i, 0, 1, 1);
            }
        }
    }

    ShaderEffectSource {
        id: dataTextureSource
        sourceItem: dataCanvas
        hideSource: true
        live: true
    }

    ShaderEffect {
        id: shader
        anchors.fill: parent

    property real iTime: 0
    property vector2d iResolution: Qt.vector2d(width, height)
        property real iBarCount: root.barCount
        property real iSystemAnchor: root.anchorToEnum(root.systemAnchor)
        property real iMicrophoneAnchor: root.anchorToEnum(root.microphoneAnchor)
        property color systemColorLow: root.systemColorLow
        property color systemColorHigh: root.systemColorHigh
        property color microphoneColorLow: root.microphoneColorLow
        property color microphoneColorHigh: root.microphoneColorHigh
        property var iDataTexture: dataTextureSource

        fragmentShader: "cava_bars.frag.qsb"
    }
    
    // Update shader when cava values change
    Connections {
        target: root.systemProvider
        function onValuesChanged() { root.updateDataTexture(); }
    }

    Connections {
        target: root.microphoneProvider
        function onValuesChanged() { root.updateDataTexture(); }
    }

    Component.onCompleted: {
        if (systemProvider && typeof systemProvider.start === "function") {
            systemProvider.start();
        }
        if (systemProvider && systemProvider.bars !== undefined) {
            systemProvider.bars = maxBars;
        }
        if (systemProvider && systemProvider.enableMonstercatFilter !== undefined) {
            systemProvider.enableMonstercatFilter = true;
        }
        if (microphoneProvider && typeof microphoneProvider.start === "function") {
            microphoneProvider.start();
        }
        if (microphoneProvider && microphoneProvider.bars !== undefined) {
            microphoneProvider.bars = maxBars;
        }
        if (microphoneProvider && microphoneProvider.enableMonstercatFilter !== undefined) {
            microphoneProvider.enableMonstercatFilter = true;
        }
        updateDataTexture();
    }
}
