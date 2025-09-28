// AppLauncherDisplay.qml - Single square button with grimace emoji that launches walker
import QtQuick
import Quickshell

Rectangle {
    id: root
    
    width: Theme.barHeight
    height: Theme.barHeight
    color: Theme.app200
    clip: true  // Clip at the rectangle level too
    
    // Clipping container for the oversized emoji
    Item {
        anchors.fill: parent
        clip: true  // Force clipping at container level
        
        // Grimace emoji with large font size, clipped
        Text {
            text: "😬"
            anchors.centerIn: parent
            font.pointSize: Theme.barHeight * 1.25
            font.family: Theme.fontFamilyUi
            color: Theme.app800
            clip: true
            
            // Center the emoji properly
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    
    // Click handler to launch walker
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor  // Show pointer cursor on hover
        onClicked: {
            Quickshell.execDetached(["walker", "-t", "mytheme"]);
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