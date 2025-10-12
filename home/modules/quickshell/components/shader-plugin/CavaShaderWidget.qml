// CavaShaderWidget.qml - Music visualizer using GLSL shader
import QtQuick
import QtQml
import Quickmilk 1.0

Rectangle {
    id: root
    
    width: 150
    height: 30
    color: "transparent"
    
    // Volume control - must be provided externally
    property var volumeWidget: null
    
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
    property color backgroundColor: Theme.app150
    property color volumeBarColor: Theme.success600
    property bool monstercatFilter: true
    property real gravityDecay: 0.97

    Quickmilk {
        id: quickmilk
        maxBars: root.maxBars
        enableMonstercatFilter: root.monstercatFilter
        gravityDecay: root.gravityDecay
    }

    property int barCount: dataTexture.barCount
    property bool isDragging: false
    property real pendingVolume: volumeWidget ? volumeWidget.volume : 0.5
    property bool hasPendingVolume: false

    function requestVolumeChange(value, immediate) {
        if (!root.volumeWidget || !root.volumeWidget.setVolume) {
            return;
        }
        const clamped = Math.max(0, Math.min(1, value));
        if (immediate === true) {
            root.volumeWidget.setVolume(clamped);
            return;
        }
        root.pendingVolume = clamped;
        root.hasPendingVolume = true;
        if (!volumeApplyTimer.running) {
            volumeApplyTimer.start();
        }
    }

    // Update texture when dragging state changes handled by QuickmilkDataTexture

    function anchorToEnum(anchor) {
        switch ((anchor || "").toLowerCase()) {
        case "top": return 1;
        case "center": return 2;
        default: return 0; // bottom
        }
    }

    Timer {
        id: volumeApplyTimer
        interval: 33
        repeat: true
        running: false
        onTriggered: {
            if (!root.hasPendingVolume) {
                if (!root.isDragging) {
                    stop();
                }
                return;
            }
            root.hasPendingVolume = false;
            root.volumeWidget.setVolume(root.pendingVolume);
            if (!root.isDragging) {
                stop();
            }
        }
    }

    QuickmilkDataTexture {
        id: dataTexture
        visible: false
        width: barCount
        height: 1
        volumeWidget: root.volumeWidget
        maxBars: root.maxBars
        maxFps: root.fps
        dragging: root.isDragging
        hub: quickmilk.hub
    }

    Connections {
        target: volumeWidget
        function onVolumeChanged() {
            if (!root.isDragging && volumeWidget) {
                root.pendingVolume = volumeWidget.volume;
            }
        }
    }

    ShaderEffectSource {
        id: dataTextureSource
        sourceItem: dataTexture
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
        property color backgroundColor: root.backgroundColor
        property color volumeBarColor: root.volumeBarColor
        property var iDataTexture: dataTextureSource

        fragmentShader: "cava_bars.frag.qsb"
        
        NumberAnimation on iTime {
            from: 0
            to: 1000000
            duration: 1000000000
            loops: Animation.Infinite
            running: true
        }
    }
    
    // Mouse area for volume control
    MouseArea {
        anchors.fill: parent
        
        onPressed: function(mouse) {
            root.isDragging = true;
            const newVolume = mouse.x / width;
            root.requestVolumeChange(newVolume);
            // Don't call updateDataTexture - onVolumeChanged will handle it
        }
        
        onReleased: {
            root.isDragging = false;
            if (root.hasPendingVolume) {
                root.volumeWidget.setVolume(root.pendingVolume);
                root.hasPendingVolume = false;
            }
            volumeApplyTimer.stop();
            // Don't call updateDataTexture - onIsDraggingChanged will handle it
        }
        
        onPositionChanged: function(mouse) {
            if (pressed) {
                const newVolume = mouse.x / width;
                root.requestVolumeChange(newVolume);
                // Don't call updateDataTexture - onVolumeChanged will handle it
            }
        }
        
        onWheel: (wheel) => {
            if (root.volumeWidget) {
                if (wheel.angleDelta.y > 0 && root.volumeWidget.incrementVolume) {
                    root.volumeWidget.incrementVolume();
                } else if (wheel.angleDelta.y < 0 && root.volumeWidget.decrementVolume) {
                    root.volumeWidget.decrementVolume();
                }
                // Don't call updateDataTexture - onVolumeChanged will handle it
            }
        }
    }

    Component.onCompleted: {
        if (volumeWidget) {
            root.pendingVolume = volumeWidget.volume;
        }
    }
}
