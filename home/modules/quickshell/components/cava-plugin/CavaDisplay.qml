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
    
    property var activeProvider: root.providerType === "microphone" ? CavaMicrophoneWidget : CavaWidget
    
    Component.onCompleted: {
        // Configure the singleton provider
        activeProvider.bars = root.barCount
        activeProvider.noiseReduction = root.noiseReduction
        activeProvider.enableMonstercatFilter = root.enableMonstercatFilter
        
        // Connect to the provider's signal
        activeProvider.valuesChanged.connect(function() {
            root.frame++;
            if (root.frame % 2 != 0) { return; }
            
            // Update bar heights based on spectrum data
            for (let i = 0; i < repeater.count; i++) {
                let barItem = repeater.itemAt(i);
                if (barItem) {
                    barItem.normalizedValue = activeProvider.values[i];
                }
            }
        });
    }
    
    Repeater {
        id: repeater
        model: root.barCount
        
        Rectangle {
            width: root.barWidth
            height: 0  
            
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
            
            property real normalizedValue: 0
            
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