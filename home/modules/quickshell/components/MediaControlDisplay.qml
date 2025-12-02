// MediaControlDisplay.qml
import QtQuick

Item {
    id: root
    width: parent.width
    height: infoRow.height + 1 + albumArt.height + 1 + progressBar.height + 1 + controlRow.height

    // Root hover area for triggering marquee anywhere in the display
    MouseArea {
        id: rootHoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.ArrowCursor
        
        onWheel: (wheel) => {
            if (!MediaControlWidget.currentPlayer) return;
            
            // Set the pending direction
            scrollDebouncer.pendingScrollDirection = wheel.angleDelta.y;
            
            // Restart the debounce timer
            scrollDebouncer.scrollDebounceTimer.restart();
        }
    }

    // Debounce scroll events
    QtObject {
        id: scrollDebouncer
        property var pendingScrollDirection: null
        property var scrollDebounceTimer: Timer {
            interval: 150
            repeat: false
            onTriggered: {
                if (scrollDebouncer.pendingScrollDirection !== null && MediaControlWidget.currentPlayer) {
                    if (scrollDebouncer.pendingScrollDirection > 0) {
                        // Scroll up - previous song
                        if (MediaControlWidget.currentPlayer.canGoPrevious) {
                            MediaControlWidget.currentPlayer.previous();
                        }
                    } else {
                        // Scroll down - next song
                        if (MediaControlWidget.currentPlayer.canGoNext) {
                            MediaControlWidget.currentPlayer.next();
                        }
                    }
                    scrollDebouncer.pendingScrollDirection = null;
                }
            }
        }
    }

    // Artist / title marquee row (top)
    Column {
        id: infoRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 1

        MarqueeText {
            id: mediaArtist
            height: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 3
            anchors.rightMargin: 3
            text: (MediaControlWidget.currentArtist || "").toUpperCase()
            font.family: Theme.fontFamilyUiNf
            font.pointSize: Theme.fontSizeTiny
            font.weight: Font.Bold
            textColor: MediaControlWidget.isPlaying ? Theme.app600 : Theme.app400
            textOpacity: 0.8
            alignment: Qt.AlignLeft
            marqueeBehavior: "repeat"
            marqueeDelay: 800
            marqueeSpeed: 30
            hovered: MediaControlWidget.isPlaying && (rootHoverArea.containsMouse || controlRowMouseArea.containsMouse)
        }

        MarqueeText {
            id: mediaTitle
            height: 12
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 3
            anchors.rightMargin: 3
            text: (MediaControlWidget.currentTitle || "No media").toUpperCase()
            font.family: Theme.fontFamilyUiNf
            font.pointSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            textColor: MediaControlWidget.isPlaying ? Theme.app800 : Theme.app500
            textOpacity: 0.95
            alignment: Qt.AlignLeft
            marqueeBehavior: "repeat"
            marqueeDelay: 800
            marqueeSpeed: 30
            hovered: MediaControlWidget.isPlaying && (rootHoverArea.containsMouse || controlRowMouseArea.containsMouse)
        }
    }

    // Hover area for triggering marquee on artist/title (now redundant but kept for reference)
    MouseArea {
        id: infoHoverArea
        anchors.fill: infoRow
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.ArrowCursor
        visible: false
    }

    // Album art
    Image {
        id: albumArt
        anchors.top: infoRow.bottom
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: Theme.barSize
        height: Theme.barSize
        source: MediaControlWidget.albumArtUrl
        visible: MediaControlWidget.albumArtUrl !== ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        cache: true
        
        MouseArea {
            anchors.fill: parent
            onClicked: MediaControlWidget.togglePlaying()
        }
    }

    // Progress bar
    Rectangle {
        id: progressBar
        anchors.top: albumArt.bottom
        anchors.topMargin: 1
        anchors.left: parent.left
        anchors.right: parent.right
        height: 4
        color: Theme.app150
        visible: MediaControlWidget.albumArtUrl !== ""

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: {
                const player = MediaControlWidget.currentPlayer;
                if (!player) return 0;
                const pos = player.position || 0;
                const len = player.length || 1;
                return parent.width * Math.min(1, Math.max(0, pos / len));
            }
            color: Theme.error600

            Behavior on width {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.Linear
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: MediaControlWidget.currentPlayer !== null
        repeat: true
        onTriggered: {
            if (MediaControlWidget.currentPlayer) {
                MediaControlWidget.currentPlayer.positionChanged();
            }
        }
    }

    // Control buttons row (bottom)
    MouseArea {
        id: controlRowMouseArea
        anchors.top: progressBar.bottom
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: controlRow.width
        height: controlRow.height
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        acceptedButtons: Qt.NoButton

        Row {
            id: controlRow
            anchors.centerIn: parent
            spacing: 0

            // Play/Pause button
            Item {
                width: 16
                height: 17

                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: MediaControlWidget.isPlaying ? 0 : 1
                    text: MediaControlWidget.isPlaying ? "\uf04c" : "\uf04b"
                    font.family: Theme.fontFamilyUiNf
                    font.pointSize: MediaControlWidget.isPlaying ? 8 : 7
                    color: Theme.app800
                    opacity: 0.95
                }

                MouseArea {
                    id: playPauseMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    propagateComposedEvents: false
                    onClicked: MediaControlWidget.togglePlaying()
                }
            }

            Rectangle {
                width: 1
                height: 15
                color: Theme.app150
            }

            // Previous button
            Item {
                width: 15
                height: 17

                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -0.5
                    text: "\uf048"
                    font.family: Theme.fontFamilyUiNf
                    font.pointSize: 8
                    color: Theme.app600
                    opacity: 0.95
                }

                MouseArea {
                    id: prevMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    propagateComposedEvents: false
                    onClicked: MediaControlWidget.previous()
                }
            }

            Rectangle {
                width: 1
                height: 15
                color: Theme.app150
            }

            // Next button
            Item {
                width: 16
                height: 17

                Text {
                    anchors.centerIn: parent
                    text: "\uf051"
                    font.family: Theme.fontFamilyUiNf
                    font.pointSize: 8
                    color: Theme.app600
                    opacity: 0.95
                }

                MouseArea {
                    id: nextMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    propagateComposedEvents: false
                    onClicked: MediaControlWidget.next()
                }
            }
        }
    }
}
