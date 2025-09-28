// MprisDisplay.qml
import QtQuick

Rectangle {
    color: Theme.app150  // backdrop color
    width: Math.min(trackText.implicitWidth + 16, 300)  // maxWidth 200 with 8px padding on each side
    height: Theme.barHeight  // barHeight high
    radius: 2  // match other components
    
    // Hide when no track info
    visible: MprisWidget.currentTrack !== ""
    
    Text {
        id: trackText
        text: MprisWidget.currentTrack || "No media playing"
        color: Theme.app600  // text color
        font.family: Theme.fontFamilyUiNf  // uiNf font
        font.pointSize: Theme.fontSizeSmall  // normal size
        
        // Center the text within the rectangle
        anchors.centerIn: parent
        anchors.margins: 8
        
        // Truncate long text
        elide: Text.ElideRight
        width: Math.min(implicitWidth, parent.width - 16)  // Account for padding
    }
}