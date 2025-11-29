// AppLauncherDisplay.qml - Single square button with grimace emoji that launches walker
import QtQuick
import Quickshell

Rectangle {
    id: root
    
    width: Theme.barSize
    height: Theme.barSize
    color: Theme.app200
    clip: true  // Clip at the rectangle level too
    property var iconOptions: [
        {
            type: "text",
            value: "🥸"
        },
        {
            type: "image",
            value: Theme.logoAndampAmpBlue
        }
    ]
    property int iconIndex: 0
    readonly property var currentIcon: iconOptions.length > 0 ? iconOptions[iconIndex % iconOptions.length] : null

    function cycleIcon() {
        if (!iconOptions.length) {
            return;
        }
        iconIndex = (iconIndex + 1) % iconOptions.length;
    }
    
    // Clipping container for the oversized emoji
    Item {
        anchors.fill: parent
        clip: true  // Force clipping at container level
        
        // Render either emoji text or image source based on current icon
        Text {
            anchors.centerIn: parent
            text: currentIcon && currentIcon.type === "text" ? currentIcon.value : ""
            visible: currentIcon && currentIcon.type === "text"
            font.pointSize: Theme.barSize * 1.25
            font.family: Theme.fontFamilyUi
            color: Theme.app800
            clip: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Image {
            anchors.centerIn: parent
            width: Theme.barSize * 0.85
            height: Theme.barSize * 0.85
            source: currentIcon && currentIcon.type === "image" ? currentIcon.value : ""
            visible: currentIcon && currentIcon.type === "image"
            fillMode: Image.PreserveAspectFit
            smooth: true
            antialiasing: true
        }
    }
    
    // Click handler to launch walker
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor  // Show pointer cursor on hover
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.cycleIcon();
                return;
            }
            if (mouse.button === Qt.LeftButton) {
                Quickshell.execDetached(["walker", "-t", "mytheme"]);
            }
        }
        
        // Visual feedback on hover
        hoverEnabled: true
        onEntered: {
            root.color = Qt.lighter(Theme.app200, 1.1);
        }
        onExited: {
            root.color = Theme.app200;
        }
    }
}