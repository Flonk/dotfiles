// MemoryDisplay.qml
import QtQuick
import QtQuick.Controls

Row {
    id: root
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