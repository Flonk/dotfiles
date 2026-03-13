// MediaControlDisplay.qml
import QtQuick

Item {
    id: root
    width: parent.width
    implicitHeight: layoutColumn.implicitHeight
    height: implicitHeight

    property int artistTopPadding: 7
    property int titleBottomPadding: 6
    property int titleGap: -2
    property int imageTopMargin: 1
    property int imageBottomMargin: 1
    property int progressBarHeight: 4
    property int buttonHeight: 22
    property int buttonFontSize: 8
    property int marqueeSpeed: 15
    property color textColor: "#000000"

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

    Column {
        id: layoutColumn
        anchors.fill: parent
        spacing: 0

        // <div backdrop><artist /><title /></div>
        Rectangle {
            id: infoContainer
            width: parent.width
            color: "transparent"

            implicitHeight: root.artistTopPadding + mediaArtist.height + root.titleGap + mediaTitle.height + root.titleBottomPadding
            height: implicitHeight

            Column {
                id: infoColumn
                anchors.top: parent.top
                anchors.topMargin: root.artistTopPadding
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: root.titleGap

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
                    textColor: root.textColor
                    textOpacity: MediaControlWidget.isPlaying ? 0.85 : 0.55
                    alignment: Qt.AlignLeft
                    marqueeBehavior: "repeat"
                    marqueeDelay: 800
                    marqueeSpeed: root.marqueeSpeed
                    hovered: MediaControlWidget.isPlaying
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
                    textColor: root.textColor
                    textOpacity: MediaControlWidget.isPlaying ? 0.95 : 0.65
                    alignment: Qt.AlignLeft
                    marqueeBehavior: "repeat"
                    marqueeDelay: 800
                    marqueeSpeed: root.marqueeSpeed
                    hovered: MediaControlWidget.isPlaying
                }
            }
        }

        // <div><img /><progress /></div>
        Rectangle {
            id: mediaContainer
            width: parent.width
            color: "#000000"
            visible: true

            implicitHeight: Theme.barSize + root.imageTopMargin + root.imageBottomMargin + root.progressBarHeight
            height: implicitHeight

            Image {
                id: albumArt
                anchors.top: parent.top
                anchors.topMargin: root.imageTopMargin
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.barSize
                height: Theme.barSize
                source: MediaControlWidget.albumArtUrl || ""
                visible: (MediaControlWidget.albumArtUrl || "") !== ""
                fillMode: Image.PreserveAspectCrop
                smooth: true
                cache: true
                opacity: rootHoverArea.containsMouse ? 1.0 : 0.5

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: MediaControlWidget.togglePlaying()
                }
            }

            Rectangle {
                id: progressBar
                anchors.top: albumArt.bottom
                anchors.topMargin: root.imageBottomMargin
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.progressBarHeight
                color: Theme.app150

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
        }

        // <div><buttons /></div> (buttons area is full-width so its backdrop is full-width)
        Rectangle {
            id: buttonsContainer
            width: parent.width
            color: "transparent"
            height: root.buttonHeight

            property int thirdWidth: Math.floor(width / 3)
            property int remainderWidth: width - (thirdWidth * 3)

            Row {
                id: controlRow
                anchors.fill: parent
                spacing: 0

                // Play/Pause (left third + remainder)
                Item {
                    id: playZone
                    width: buttonsContainer.thirdWidth + buttonsContainer.remainderWidth
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: MediaControlWidget.isPlaying ? 0 : 1
                        text: MediaControlWidget.isPlaying ? "\uf04c" : "\uf04b"
                        font.family: Theme.fontFamilyUiNf
                        font.pointSize: root.buttonFontSize
                        color: root.textColor
                        opacity: 0.95
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MediaControlWidget.togglePlaying()
                    }
                }

                // Previous (middle third)
                Item {
                    id: prevZone
                    width: buttonsContainer.thirdWidth
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -0.5
                        text: "\uf048"
                        font.family: Theme.fontFamilyUiNf
                        font.pointSize: root.buttonFontSize
                        color: root.textColor
                        opacity: 0.95
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MediaControlWidget.previous()
                    }
                }

                // Next (right third)
                Item {
                    id: nextZone
                    width: buttonsContainer.thirdWidth
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        text: "\uf051"
                        font.family: Theme.fontFamilyUiNf
                        font.pointSize: root.buttonFontSize
                        color: root.textColor
                        opacity: 0.95
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MediaControlWidget.next()
                    }
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
}
