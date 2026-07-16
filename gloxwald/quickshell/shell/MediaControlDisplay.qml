// MediaControlDisplay.qml
import QtQuick

Item {
    id: root
    width: parent.width
    implicitHeight: root.buttonHeight
    height: implicitHeight

    property int horizontalPadding: 6
    property int buttonGap: 6
    property int buttonHeight: 20
    property int buttonFontSize: 8
    property int marqueeSpeed: 15
    property int textLanePadding: 6
    property color textColor: "#000000"
    property color iconColor: textColor
    property int textVerticalOffset: 0
    readonly property string mediaLine: {
        const artist = (MediaControlWidget.currentArtist || "").trim();
        const title = (MediaControlWidget.currentTitle || "No media").trim();
        return artist.length ? `${artist} - ${title}` : title;
    }
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

    Row {
        id: buttonsContainer
        anchors.left: parent.left
        anchors.leftMargin: root.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: root.textVerticalOffset
        height: root.buttonHeight
        spacing: root.buttonGap

        Item {
            width: root.buttonHeight
            height: root.buttonHeight

            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -0.5
                text: "\uf048"
                font.family: Theme.fontFamily
                font.pointSize: root.buttonFontSize
                color: root.iconColor
                opacity: MediaControlWidget.canGoPrevious() ? 0.95 : 0.35
            }

            MouseArea {
                anchors.fill: parent
                enabled: MediaControlWidget.canGoPrevious()
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: MediaControlWidget.previous()
            }
        }

        Item {
            width: root.buttonHeight
            height: root.buttonHeight

            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: MediaControlWidget.isPlaying ? 0 : 1
                text: MediaControlWidget.isPlaying ? "\uf04c" : "\uf04b"
                font.family: Theme.fontFamily
                font.pointSize: root.buttonFontSize
                color: root.iconColor
                opacity: MediaControlWidget.canTogglePlaying() ? 0.95 : 0.35
            }

            MouseArea {
                anchors.fill: parent
                enabled: MediaControlWidget.canTogglePlaying()
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: MediaControlWidget.togglePlaying()
            }
        }

        Item {
            width: root.buttonHeight
            height: root.buttonHeight

            Text {
                anchors.centerIn: parent
                text: "\uf051"
                font.family: Theme.fontFamily
                font.pointSize: root.buttonFontSize
                color: root.iconColor
                opacity: MediaControlWidget.canGoNext() ? 0.95 : 0.35
            }

            MouseArea {
                anchors.fill: parent
                enabled: MediaControlWidget.canGoNext()
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: MediaControlWidget.next()
            }
        }
    }

    Item {
        id: progressBarContainer
        anchors.left: buttonsContainer.right
        anchors.leftMargin: root.buttonGap
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: root.textVerticalOffset
        height: root.buttonHeight

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: {
                    const player = MediaControlWidget.currentPlayer;
                    if (!player) return 0;
                    const pos = player.position || 0;
                    const len = player.length || 1;
                    return Math.max(0, parent.width * Math.min(1, Math.max(0, pos / len)));
                }
                color: Qt.rgba(Theme.wm800.r, Theme.wm800.g, Theme.wm800.b, 0.3)

                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.Linear
                    }
                }
            }
        }

        MarqueeText {
            id: mediaLineText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.textLanePadding
            anchors.rightMargin: root.textLanePadding
            anchors.verticalCenter: parent.verticalCenter
            height: implicitHeight
            text: root.mediaLine
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            textColor: root.textColor
            textOpacity: MediaControlWidget.isPlaying ? 0.95 : 0.65
            alignment: Qt.AlignLeft
            marqueeBehavior: "repeat"
            marqueeDelay: 250
            marqueeSpeed: root.marqueeSpeed
            hovered: MediaControlWidget.isPlaying && (rootHoverArea.containsMouse || implicitWidth > width)
        }

        MouseArea {
            anchors.fill: parent
            enabled: MediaControlWidget.canTogglePlaying()
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: MediaControlWidget.togglePlaying()
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
}
