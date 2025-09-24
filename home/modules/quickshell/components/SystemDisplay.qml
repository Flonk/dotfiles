// SystemDisplay.qml
import QtQuick
import QtQuick.Controls

Row {
    id: root
    
    spacing: 15

    // CPU Usage with per-core bars
    Row {
        spacing: 3
        
        Text {
            text: SystemMonitor.getCpuIcon()
            font.pointSize: Theme.fontSizeNormal
            font.family: Theme.fontFamilyUiNf
            color: Theme.app400
        }
        
        Text {
            text: SystemMonitor.getCpuText()
            font.pointSize: Theme.fontSizeNormal
            font.family: Theme.fontFamilyUiNf
            color: SystemMonitor.cpuUsage > 0.8 ? Theme.error400 : Theme.app400  // text color
        }
        
        // CPU core bars
        Row {
            spacing: 0
            
            Repeater {
                model: SystemMonitor.coreCount
                
                Rectangle {
                    width: 4
                    height: parent.parent.height || 20
                    color: Theme.app200  // borders
                    
                    Rectangle {
                        width: parent.width
                        height: parent.height * (SystemMonitor.coreUsages[index] || 0)
                        anchors.bottom: parent.bottom
                        color: {
                            const usage = SystemMonitor.coreUsages[index] || 0;
                            if (usage > 0.9) return Theme.error400;  // CPU >90%
                            return Theme.wm800;  // normal bars
                        }
                    }
                }
            }
        }
    }

    // Memory Usage
    Row {
        spacing: 3
        
        Text {
            text: SystemMonitor.getMemoryIcon()
            font.pointSize: Theme.fontSizeNormal
            font.family: Theme.fontFamilyUiNf
            color: Theme.app400
        }
        
        Text {
            text: SystemMonitor.getMemoryText()
            font.pointSize: Theme.fontSizeNormal
            font.family: Theme.fontFamilyUiNf
            color: SystemMonitor.memoryUsage > 0.9 ? Theme.error400 : Theme.app400  // text color
        }
    }
}