import QtQuick

Item {
    id: root
    height: 20
    implicitWidth: 270

    readonly property var player: MediaControlWidget.currentPlayer
    readonly property string line: {
        const artist = MediaControlWidget.currentArtist.trim();
        const title = (MediaControlWidget.currentTitle || "No media").trim();
        return artist ? `${artist} - ${title}` : title;
    }

    component MediaButton: BarText {
        id: button
        property bool can: false
        signal triggered()
        width: 20
        horizontalAlignment: Text.AlignHCenter
        font.weight: Font.Normal
        opacity: can ? 0.95 : 0.35

        MouseArea {
            anchors.fill: parent
            enabled: button.can
            cursorShape: Qt.PointingHandCursor
            onClicked: button.triggered()
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onWheel: w => {
            if (!root.player)
                return;
            skip.direction = w.angleDelta.y;
            skip.restart();
        }
    }

    Timer {
        id: skip
        property int direction: 0
        interval: 150
        onTriggered: direction > 0 ? MediaControlWidget.previous() : MediaControlWidget.next()
    }

    Timer {
        interval: 1000
        running: MediaControlWidget.isPlaying
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    Row {
        id: buttons
        x: 6
        spacing: 6

        MediaButton {
            text: ""
            can: MediaControlWidget.canGoPrevious()
            onTriggered: MediaControlWidget.previous()
        }

        MediaButton {
            text: MediaControlWidget.isPlaying ? "" : ""
            can: MediaControlWidget.canTogglePlaying()
            onTriggered: MediaControlWidget.togglePlaying()
        }

        MediaButton {
            text: ""
            can: MediaControlWidget.canGoNext()
            onTriggered: MediaControlWidget.next()
        }
    }

    Item {
        anchors { left: buttons.right; leftMargin: 6; right: parent.right; top: parent.top; bottom: parent.bottom }
        clip: true

        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: root.player ? parent.width * Math.min(1, Math.max(0, (root.player.position || 0) / (root.player.length || 1))) : 0
            color: Qt.rgba(Theme.wm800.r, Theme.wm800.g, Theme.wm800.b, 0.3)
            Behavior on width {
                NumberAnimation { duration: 200 }
            }
        }

        MarqueeText {
            anchors { left: parent.left; right: parent.right; leftMargin: 6; rightMargin: 6; verticalCenter: parent.verticalCenter }
            text: root.line
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            textColor: Theme.textDim
            opacity: MediaControlWidget.isPlaying ? 0.95 : 0.65
            scrolling: MediaControlWidget.isPlaying
        }

        MouseArea {
            anchors.fill: parent
            enabled: MediaControlWidget.canTogglePlaying()
            cursorShape: Qt.PointingHandCursor
            onClicked: MediaControlWidget.togglePlaying()
        }
    }
}
