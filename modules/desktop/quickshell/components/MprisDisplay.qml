// MprisDisplay.qml
import QtQuick

MouseArea {
    id: mouseArea
    width: displayRect.width
    height: displayRect.height
    acceptedButtons: Qt.LeftButton
    hoverEnabled: true
    
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
        color: Theme.app150
        width: Theme.barSize
        height: 18
        radius: 2

        MarqueeText {
            id: titleText
            anchors.fill: parent
            anchors.margins: 3
            text: (MprisWidget.currentTitle || "No media").toUpperCase()
            font.family: Theme.fontFamilyUiNf
            font.pointSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            textColor: MprisWidget.isPlaying ? Theme.app800 : Theme.app600
            textOpacity: 0.95
            alignment: Qt.AlignRight
            marqueeDelay: 800
            hovered: mouseArea.containsMouse
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