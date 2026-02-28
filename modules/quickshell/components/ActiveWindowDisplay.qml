// ActiveWindowDisplay.qml
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    color: Theme.app150  // backdrop color
    width: Math.min(titleText.implicitWidth + 16, 300)  // clamp to 300px with 8px padding on each side
    height: Theme.barHeight  // bar height
    radius: 2  // match other components
    
    // Hide when no active window
    visible: ActiveWindowWidget.displayTitle !== ""
    
    Text {
        id: titleText
        text: ActiveWindowWidget.displayTitle
        font.pointSize: Theme.fontSizeNormal  // normal size
        font.family: Theme.fontFamilyUi  // uiNf font
        color: Theme.app600  // text color
        
        // Center the text within the rectangle
        anchors.centerIn: parent
        anchors.margins: 8
        
        // Truncate long text
        elide: Text.ElideRight
        width: Math.min(implicitWidth, parent.width - 16)  // Account for padding
        
        // Fade out effect for long titles
        opacity: ActiveWindowWidget.windowTitle.length > 0 ? 1.0 : 0.6
    }
}