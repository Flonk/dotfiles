// AppLauncherDisplay.qml - Single square button with grimace emoji that launches vicinae
import QtQuick
import Quickshell

Rectangle {
    id: root
    
    width: Theme.barSize
    height: Theme.barSize
    color: "transparent"
    clip: true  // Clip at the rectangle level too
    property real hoverScale: 1.0
    property var iconOptions: [
        {
            type: "image",
            value: Theme.logoAndampAmpBlue,
            zoom: 0.6
        },
        {
            type: "text",
            value: "🥸",
            zoom: 1.25
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
        scale: root.hoverScale
        
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
        }
        
        // Render either emoji text or image source based on current icon
        Text {
            anchors.centerIn: parent
            text: currentIcon && currentIcon.type === "text" ? currentIcon.value : ""
            visible: currentIcon && currentIcon.type === "text"
            font.pointSize: Theme.barSize * (currentIcon && currentIcon.zoom ? currentIcon.zoom : 1.0)
            font.family: Theme.fontFamilyUi
            color: Theme.app800
            clip: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Image {
            anchors.centerIn: parent
            width: Theme.barSize * (currentIcon && currentIcon.zoom ? currentIcon.zoom : 0.85)
            height: Theme.barSize * (currentIcon && currentIcon.zoom ? currentIcon.zoom : 0.85)
            source: currentIcon && currentIcon.type === "image" ? currentIcon.value : ""
            visible: currentIcon && currentIcon.type === "image"
            fillMode: Image.PreserveAspectFit
            smooth: true
            antialiasing: true
        }
    }
    
    // Click handler to launch vicinae
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
                Quickshell.execDetached(["vicinae", "open"]);
            }
        }
        
        // Visual feedback on hover
        hoverEnabled: true
        onEntered: {
            root.hoverScale = 1.1;
        }
        onExited: {
            root.hoverScale = 1.0;
        }
    }
}