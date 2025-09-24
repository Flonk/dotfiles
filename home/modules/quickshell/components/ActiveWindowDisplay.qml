// ActiveWindowDisplay.qml
import QtQuick
import QtQuick.Controls

Row {
    id: root
    
    spacing: 5

    Text {
        text: ActiveWindowWidget.displayTitle
        font.pointSize: Theme.fontSizeNormal  // normal size
        font.family: Theme.fontFamilyUiNf  // uiNf font
        color: Theme.app400  // text color
        
        // Fade out effect for long titles
        opacity: ActiveWindowWidget.windowTitle.length > 0 ? 1.0 : 0.6
    }
}