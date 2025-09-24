// MicrophoneCavaDisplay.qml - Microphone audio visualizer component
import QtQuick
import CavaPlugin 1.0

Row {
    id: root
    spacing: 0
    
    property int barCount: 15
    property int maxBarHeight: 25
    property color barColor: "#e74c3c"
    
    MicrophoneCavaProvider {
        id: microphoneProvider
        bars: root.barCount
        
        onValuesChanged: {
            // Update bar heights based on spectrum data
            for (let i = 0; i < repeater.count; i++) {
                let item = repeater.itemAt(i);
                if (item) {
                    item.targetHeight = values[i] * root.maxBarHeight;
                }
            }
        }
    }
    
    Repeater {
        id: repeater
        model: root.barCount
        
        Rectangle {
            width: 4
            height: 0  
            color: root.barColor
            
            anchors.bottom: parent.bottom
            
            topLeftRadius: 2
            topRightRadius: 2
            bottomLeftRadius: 0
            bottomRightRadius: 0
            
            property real targetHeight: 0  
            
            Behavior on height {
                NumberAnimation { duration: 10; easing.type: Easing.Linear }
            }
            
            onTargetHeightChanged: {
                height = Math.max(0, targetHeight); 
            }
        }
    }
}
