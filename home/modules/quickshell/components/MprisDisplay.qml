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
        color: Theme.app150  // backdrop color
        width: Theme.barSize  // fit to bar width
        height: rotatedWrapper.width  // After rotation, wrapper width becomes display height
        radius: 2  // match other components
        
        // Wrapper Item that gets rotated
        Item {
            id: rotatedWrapper
            anchors.bottom: parent.bottom  // Anchor to bottom since rotation goes upward
            anchors.left: parent.left
            width: Math.min(contentColumn.implicitWidth + 8, 180)  // Add padding, max 140
            height: Theme.barSize
            
            // Set transform origin to center of barSize dimension, rotate 270 for bottom-to-top reading
            transform: Rotation {
                origin.x: Theme.barSize / 2
                origin.y: Theme.barSize / 2
                angle: 270
            }
            
            Column {
                id: contentColumn
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6  // bottom padding (becomes right padding after rotation)
                anchors.left: parent.left
                spacing: 2
                
                // Artist name
                Text {
                    id: artistText
                    text: (MprisWidget.currentArtist || "").toUpperCase()
                    color: MprisWidget.isPlaying ? Theme.app600 : Theme.app400
                    font.family: Theme.fontFamilyUiNf
                    font.pointSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    opacity: 0.7
                    
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 140)
                    
                    Behavior on color {
                        ColorAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                
                // Title
                Text {
                    id: titleText
                    text: (MprisWidget.currentTitle || "No media").toUpperCase()
                    color: MprisWidget.isPlaying ? Theme.app800 : Theme.app500
                    font.family: Theme.fontFamilyUiNf
                    font.pointSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 140)
                    
                    Behavior on color {
                        ColorAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
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