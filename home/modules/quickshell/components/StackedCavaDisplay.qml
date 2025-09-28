// StackedCavaDisplay.qml - Overlayed audio visualizers
import QtQuick
import CavaPlugin 1.0
import Quickshell

Item {
    id: root
    width: (barCount * barWidth) + ((barCount - 1) * barSpacing) + (horizontalPadding * 2)
    height: maxBarHeight
    
    property int barCount: 40
    property int maxBarHeight: 30
    property int barWidth: 4
    property int barSpacing: 0
    property color systemAudioColorLow: "#7dc383"
    property color systemAudioColorHigh: "#a8e6a3"
    property color microphoneColorLow: "#e74c3c"
    property color microphoneColorHigh: "#ff6b6b"
    property color backdropColor: "#f0f0f0"
    property string systemAudioAnchor: "bottom"  // "bottom", "top", "center"
    property string microphoneAnchor: "top"      // "bottom", "top", "center"
    property int topRadius: 2
    property int bottomRadius: 0
    property int backdropRadius: 4
    property color borderColor: "#f0f0f0"
    property int borderWidth: 1
    property int horizontalPadding: 0
    property int verticalPadding: 0
    property real noiseReduction: 0.3
    property bool enableMonstercatFilter: false
    property color volumeSliderColor: "white"
    property real volumeSliderOpacity: 0.3
    property real volumeSliderForegroundOpacity: 0.05
    property real systemAudioCompressionFactor: 1.0
    property real microphoneCompressionFactor: 1.0
    
    // Computed properties for internal use
    property int effectiveBarHeight: maxBarHeight - (verticalPadding * 2)
    
    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: root.backdropColor
        radius: root.backdropRadius
        z: 0
    }
    
        // System audio - top layer (more important), grows from bottom up
    CavaDisplay {
        providerType: "cava"
        barCount: root.barCount
        maxBarHeight: root.effectiveBarHeight
        barWidth: root.barWidth
        barSpacing: root.barSpacing
        anchorMode: root.systemAudioAnchor
        barColor: root.systemAudioColorLow
        barGradientColor: root.systemAudioColorHigh
        topRadius: root.topRadius
        bottomRadius: root.bottomRadius
        noiseReduction: root.noiseReduction
        enableMonstercatFilter: root.enableMonstercatFilter
        compressionFactor: root.systemAudioCompressionFactor
        z: 3
        anchors.left: parent.left
        anchors.leftMargin: root.horizontalPadding
        anchors.right: parent.right
        anchors.rightMargin: root.horizontalPadding
        anchors.bottom: root.systemAudioAnchor === "bottom" ? parent.bottom : undefined
        anchors.bottomMargin: root.systemAudioAnchor === "bottom" ? root.verticalPadding : 0
        anchors.top: root.systemAudioAnchor === "top" ? parent.top : undefined
        anchors.topMargin: root.systemAudioAnchor === "top" ? root.verticalPadding : 0
        anchors.verticalCenter: root.systemAudioAnchor === "center" ? parent.verticalCenter : undefined
        
        // Flip system audio bars when anchored to top
        transform: systemAudioFlipTransform
        
        Scale {
            id: systemAudioFlipTransform
            origin.x: parent ? parent.width / 2 : 0
            origin.y: parent ? parent.height / 2 : 0
            yScale: root.systemAudioAnchor === "top" ? -1 : 1
        }
    }
    
    // Microphone audio - bottom layer, grows from top down  
    CavaDisplay {
        providerType: "microphone"
        barCount: root.barCount
        maxBarHeight: root.effectiveBarHeight
        barWidth: root.barWidth
        barSpacing: root.barSpacing
        anchorMode: root.microphoneAnchor
        barColor: root.microphoneColorLow
        barGradientColor: root.microphoneColorHigh
        topRadius: root.topRadius
        bottomRadius: root.bottomRadius
        noiseReduction: root.noiseReduction
        enableMonstercatFilter: root.enableMonstercatFilter
        compressionFactor: root.microphoneCompressionFactor
        z: 2
        
        anchors.left: parent.left
        anchors.leftMargin: root.horizontalPadding
        anchors.right: parent.right
        anchors.rightMargin: root.horizontalPadding
        anchors.bottom: root.microphoneAnchor === "bottom" ? parent.bottom : undefined
        anchors.bottomMargin: root.microphoneAnchor === "bottom" ? root.verticalPadding : 0
        anchors.top: root.microphoneAnchor === "top" ? parent.top : undefined
        anchors.topMargin: root.microphoneAnchor === "top" ? root.verticalPadding : 0
        anchors.verticalCenter: root.microphoneAnchor === "center" ? parent.verticalCenter : undefined
        
        // Make microphone bars grow from top instead of bottom when anchored to top
        transform: microphoneFlipTransform
        
        Scale {
            id: microphoneFlipTransform
            origin.x: parent ? parent.width / 2 : 0
            origin.y: parent ? parent.height / 2 : 0
            yScale: root.microphoneAnchor === "top" ? -1 : 1
        }
    }
    
    // Volume Indicator (triangle at volume position)
    Rectangle {
        id: volumeIndicator
        anchors.left: parent.left
        anchors.right: parent.right  
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        
        color: "transparent" // No background
        z: 1
        
        // Triangle volume indicator
        Canvas {
            id: volumeTriangle
            x: root.horizontalPadding + (parent.width - root.horizontalPadding) * VolumeWidget.volume - 3  // Center the 6px wide triangle
            y: 0  // Stick to the top without padding
            width: 6
            height: 4  // Made shorter (less high)
            
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = Theme.app300;
                
                // Draw downward-pointing triangle (since it's at the top now)
                ctx.beginPath();
                ctx.moveTo(3, 3);    // Bottom point (center)
                ctx.lineTo(0, 0);    // Top left
                ctx.lineTo(6, 0);    // Top right
                ctx.closePath();
                ctx.fill();
            }
            
            // Repaint when volume changes
            Connections {
                target: VolumeWidget
                function onVolumeChanged() {
                    volumeTriangle.requestPaint();
                }
            }
        }
        
        // Mouse interaction (full width but respects mapping)
        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) {
                // Map click position to volume (account for horizontalPadding minimum)
                const clickRatio = Math.max(0, (mouse.x - root.horizontalPadding) / (width - root.horizontalPadding));
                const newVolume = Math.max(0, Math.min(1, clickRatio));
                VolumeWidget.setVolume(newVolume);
            }
            
            onPositionChanged: function(mouse) {
                if (pressed) {
                    // Map drag position to volume (account for horizontalPadding minimum)
                    const dragRatio = Math.max(0, (mouse.x - root.horizontalPadding) / (width - root.horizontalPadding));
                    const newVolume = Math.max(0, Math.min(1, dragRatio));
                    VolumeWidget.setVolume(newVolume);
                }
            }
            
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) {
                    VolumeWidget.incrementVolume();
                } else if (wheel.angleDelta.y < 0) {
                    VolumeWidget.decrementVolume();
                }
            }
        }
    }
}