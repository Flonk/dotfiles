import QtQuick
import Quickshell.Io

Rectangle {
    color: Theme.app150  // backdrop color
    width: clockText.implicitWidth + 16  // 8px padding on each side
    height: Theme.barHeight  // barHeight high
    radius: 2  // match other components
    
    Text {
        id: clockText
        text: Time.time
        font.pointSize: Theme.fontSizeNormal
        font.family: Theme.fontFamilyUiNf
        color: Theme.app600  // app600 text color
        
        // Center the text within the rectangle
        anchors.centerIn: parent
    }
    
    MouseArea {
        anchors.fill: parent
        onClicked: {
            // Get current ISO timestamp
            const now = new Date();
            const isoTimestamp = now.toISOString();
            
            // Copy to clipboard using wl-copy with the timestamp as argument
            clipboardProcess.command = ["wl-copy", isoTimestamp];
            clipboardProcess.running = true;
            
            // Show notification
            notificationProcess.running = true;
        }
        
        cursorShape: Qt.PointingHandCursor
    }
    
    // Process to copy timestamp to clipboard
    Process {
        id: clipboardProcess
        // command will be set dynamically in the click handler
        
        onExited: (code) => {
            if (code === 0) {
                console.log("Timestamp copied to clipboard");
            }
        }
    }
    
    // Process to show notification
    Process {
        id: notificationProcess
        command: ["notify-send", "-u", "low", "Timestamp Copied", "ISO timestamp saved to clipboard"]
        
        onExited: (code) => {
            if (code === 0) {
                console.log("Notification sent");
            }
        }
    }
}