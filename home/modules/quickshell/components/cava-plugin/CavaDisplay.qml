// CavaDisplay.qml - Audio visualizer component
import QtQuick
import CavaPlugin 1.0

Row {
    id: root
    spacing: 0
    height: maxBarHeight  // Set explicit height for the container
    
    property int barCount: 20
    property int maxBarHeight: 30
    property color barColor: "#7dc383"
    
    CavaProvider {
        id: cavaProvider
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