// MprisDisplay.qml
import QtQuick

MouseArea {
    id: mouseArea
    width: displayRect.width
    height: displayRect.height
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    
    // Hide when no track info
    visible: MprisWidget.currentTrack !== ""
    
    // Debounce scroll events
    property var pendingScrollDirection: null
    property var scrollDebounceTimer: Timer {
        interval: 150 // ms debounce delay
        repeat: false
        onTriggered: {
            if (pendingScrollDirection !== null && MprisWidget.currentPlayer) {
                if (pendingScrollDirection > 0) {
                    // Scroll up - previous song
                    if (MprisWidget.currentPlayer.canGoPrevious) {
                        MprisWidget.currentPlayer.previous();
                    }
                } else {
                    // Scroll down - next song
                    if (MprisWidget.currentPlayer.canGoNext) {
                        MprisWidget.currentPlayer.next();
                    }
                }
                pendingScrollDirection = null;
            }
        }
    }
    
    Rectangle {
        id: displayRect
        color: Theme.app150  // backdrop color
        width: Math.min(trackText.implicitWidth + 16, 300)  // maxWidth 300 with 8px padding on each side
        height: Theme.barHeight  // barHeight high
        radius: 2  // match other components
        
        Text {
            id: trackText
            text: MprisWidget.currentTrack || "No media playing"
            color: MprisWidget.isPlaying ? Theme.app600 : Theme.app400  // Dynamic color based on playing state
            font.family: Theme.fontFamilyUi  // uiNf font
            font.pointSize: Theme.fontSizeSmall  // normal size
            
            // Center the text within the rectangle
            anchors.centerIn: parent
            anchors.margins: 8
            
            // Truncate long text
            elide: Text.ElideRight
            width: Math.min(implicitWidth, parent.width - 16)  // Account for padding
            
            // Smooth color transition
            Behavior on color {
                ColorAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
    
    // Click to toggle play/pause
    onClicked: (mouse) => {
        if (MprisWidget.currentPlayer) {
            if (MprisWidget.currentPlayer.canTogglePlaying) {
                MprisWidget.currentPlayer.togglePlaying();
            }
        }
    }

    // Scroll for next/previous song with proper debouncing
    onWheel: (wheel) => {
        if (!MprisWidget.currentPlayer) return;
        
        // Set the pending direction (positive for up/previous, negative for down/next)
        pendingScrollDirection = wheel.angleDelta.y;
        
        // Restart the debounce timer
        scrollDebounceTimer.restart();
    }
}