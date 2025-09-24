// MprisDisplay.qml
import QtQuick

Text {
    text: MprisWidget.currentTrack || "No media playing"
    color: Theme.app400  // text color
    font.family: Theme.fontFamilyUiNf  // uiNf font
    font.pointSize: Theme.fontSizeNormal  // normal size
    
    // Hide when no track info
    visible: MprisWidget.currentTrack !== ""
    
    // Truncate long text
    elide: Text.ElideRight
    width: Math.min(implicitWidth, 300)
}