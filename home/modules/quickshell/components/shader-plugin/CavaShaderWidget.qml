// CavaShaderWidget.qml - Music visualizer using GLSL shader
import QtQuick

Rectangle {
    id: root
    
    width: 200
    height: 30
    color: "transparent"
    
    // Required: Pass in the cava provider (CavaWidget or CavaMicrophoneWidget)
    required property var cavaProvider
    
    // Configurable FPS for the animation
    property int fps: 30
    property int maxBars: 128
    
    property int barCount: Math.max(1, Math.min(maxBars, cavaProvider ? cavaProvider.values.length : 0))

    Canvas {
        id: dataCanvas
        visible: false
        width: root.barCount
        height: 1
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const values = root.cavaProvider ? root.cavaProvider.values : [];
            const count = Math.min(values.length, width);
            for (let i = 0; i < count; ++i) {
                const value = Math.max(0, Math.min(1, values[i] ?? 0));
                const intensity = Math.round(value * 255);
                ctx.fillStyle = `rgba(${intensity},0,0,1)`;
                ctx.fillRect(i, 0, 1, 1);
            }
        }
    }

    Component.onCompleted: {
        root.barCount = Math.max(1, Math.min(root.maxBars, root.cavaProvider ? root.cavaProvider.values.length : 0));
        dataCanvas.width = root.barCount;
        dataCanvas.requestPaint();
        dataTextureSource.scheduleUpdate();
        shader.iBarCount = root.barCount;
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
        property var iDataTexture: dataTextureSource
        
        fragmentShader: "cava_bars.frag.qsb"
        
        // Animation timer for smooth updates
        Timer {
            interval: 1000 / root.fps
            running: true
            repeat: true
            onTriggered: {
                shader.iTime += interval / 1000.0
            }
        }
    }
    
    // Update shader when cava values change
    Connections {
        target: root.cavaProvider
        function onValuesChanged() {
            root.barCount = Math.max(1, Math.min(root.maxBars, root.cavaProvider.values.length));
            dataCanvas.width = root.barCount;
            dataCanvas.requestPaint();
            dataTextureSource.scheduleUpdate();
            shader.iBarCount = root.barCount;
        }
    }
    
    property var barValues: root.cavaProvider ? root.cavaProvider.values : []
}
