// BaseCavaDisplay.qml - Base audio visualizer component
import QtQuick
import CavaPlugin 1.0

Row {
    id: root
    spacing: root.barSpacing
    height: maxBarHeight
    
    property int barCount: 40
    property int maxBarHeight: 30
    property int barWidth: 4
    property int barSpacing: 0
    property string anchorMode: "bottom"  // "bottom", "top", "center"
    property color barColor
    property color barGradientColor
    property int topRadius: 2
    property int bottomRadius: 0
    property real noiseReduction: 0.3
    property bool enableMonstercatFilter: false
    property int frame: 0 
    property real compressionFactor: 1.0 
    property string providerType: "cava"  // "cava" or "microphone"
    
    // Silence detection properties
    property real silenceThreshold: 0.015
    property int silenceTimeoutMs: 10000
    property bool isSilent: false
    property real totalAudioLevel: 0
    property int animationStaggerMs: 5
    property int animationInDurationMs: 400
    property int animationOutDurationMs: 1000
    
    property var activeProvider: root.providerType === "microphone" ? CavaMicrophoneWidget : CavaWidget
    
    Component.onCompleted: {
        activeProvider.bars = root.barCount
        activeProvider.noiseReduction = root.noiseReduction
        activeProvider.enableMonstercatFilter = root.enableMonstercatFilter
    }

    Connections {
        target: root.activeProvider
        function onValuesChanged() {
            root.frame++;
            if (root.frame % 2 != 0) { return; }

            root.totalAudioLevel = 0;
            for (let i = 0; i < root.activeProvider.values.length; i++) {
                root.totalAudioLevel += root.activeProvider.values[i];
            }
            root.totalAudioLevel /= root.activeProvider.values.length; // Average level

            for (let i = 0; i < repeater.count; i++) {
                let barItem = repeater.itemAt(i);
                if (barItem) {
                    barItem.normalizedValue = root.activeProvider.values[i];
                }
            }

            if (root.totalAudioLevel > root.silenceThreshold) {
                if (root.isSilent) {
                    root.isSilent = false;
                    for (let i = 0; i < repeater.count; i++) {
                        let barItem = repeater.itemAt(i);
                        if (barItem && barItem.returnTimer) {
                            barItem.returnTimer.interval = i * root.animationStaggerMs;
                            barItem.returnTimer.start();
                        }
                    }
                }
                silenceTimer.restart();
            }
        }
    }
    
    Timer {
        id: silenceTimer
        interval: root.silenceTimeoutMs
        running: true
        repeat: false
        onTriggered: {
            if (root.totalAudioLevel <= root.silenceThreshold) {
                root.isSilent = true;
                for (let i = 0; i < repeater.count; i++) {
                    let barItem = repeater.itemAt(i);
                    if (barItem && barItem.disappearTimer) {
                        barItem.disappearTimer.interval = i * root.animationStaggerMs;
                        barItem.disappearTimer.start();
                    }
                }
            }
        }
    }
    
    Repeater {
        id: repeater
        model: root.barCount
        
        Rectangle {
            width: root.barWidth
            height: 0  
            
            // Animation properties for silence effect
            property bool isOffScreen: false
            property real normalizedValue: 0
            
            // Timers for staggered wave animations
            property alias disappearTimer: disappearTimer
            property alias returnTimer: returnTimer
            
            Timer {
                id: disappearTimer
                running: false
                repeat: false
                onTriggered: parent.isOffScreen = true
            }
            
            Timer {
                id: returnTimer
                running: false
                repeat: false  
                onTriggered: parent.isOffScreen = false
            }
            
            transform: Translate {
                y: {
                    if (root.anchorMode !== "center" || !isOffScreen) return 0;
                    let direction = index % 2 === 0 ? 1 : 1;
                    return direction * (root.maxBarHeight + 4);
                }
                
                Behavior on y {
                    NumberAnimation {
                        duration: isOffScreen ? root.animationOutDurationMs : root.animationInDurationMs
                        easing.type: isOffScreen ? Easing.OutElastic : Easing.InBack
                        easing.amplitude: 1.2
                        easing.period: 0.5
                    }
                }
            }
            
            // Dynamic color interpolation based on height - louder = gradient color
            color: {
                let heightRatio = height / root.maxBarHeight;
                let t = heightRatio; // Full gradient interpolation (0 to 1)
                
                // Convert hex colors to color objects and interpolate
                let baseColor = Qt.color(root.barColor);
                let targetColor = Qt.color(root.barGradientColor);
                
                // Linear interpolation between colors
                let r = baseColor.r + t * (targetColor.r - baseColor.r);
                let g = baseColor.g + t * (targetColor.g - baseColor.g);
                let b = baseColor.b + t * (targetColor.b - baseColor.b);
                let a = baseColor.a + t * (targetColor.a - baseColor.a);
                
                return Qt.rgba(r, g, b, a);
            }
            
            anchors.bottom: root.anchorMode === "bottom" ? parent.bottom : undefined
            anchors.top: root.anchorMode === "top" ? parent.top : undefined
            anchors.verticalCenter: root.anchorMode === "center" ? parent.verticalCenter : undefined
            
            topLeftRadius: root.topRadius
            topRightRadius: root.topRadius
            bottomLeftRadius: root.bottomRadius
            bottomRightRadius: root.bottomRadius
            
            Behavior on height {
                NumberAnimation { 
                    duration: 40 // Smooth animation duration
                    easing.type: Easing.Linear 
                }
            }
            
            onNormalizedValueChanged: {
                // Calculate minimum height for center anchoring (cute dots)
                let minHeight = root.anchorMode === "center" ? 
                    Math.max(1, root.topRadius + root.bottomRadius) : 1;
                // Round down to next odd number for perfect centering
                if (root.anchorMode === "center" && minHeight % 2 === 0) {
                    minHeight -= 1;
                }
                
                // Lerp directly between minHeight and maxBarHeight, scaled by compressionFactor
                let scaledMaxHeight = root.maxBarHeight * root.compressionFactor;
                height = minHeight + (scaledMaxHeight - minHeight) * normalizedValue;
            }
        }
    }
}