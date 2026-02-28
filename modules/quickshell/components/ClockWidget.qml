import QtQuick
import Quickshell.Io

Section {
    property int sectionMargin: 3  // Can be overridden from parent
    property int sectionRadius: 5  // Can be overridden from parent
    property int sectionVerticalPadding: 4
    property int sectionHorizontalPadding: 0
    property bool sectionClip: true
    property color sectionBackgroundColor: "#000000"
    property color sectionTopBorderColor: Theme.app200
    property int sectionTopBorderHeight: 1
    property bool sectionShowTopBorder: true
    
    topMargin: sectionMargin
    bottomMargin: sectionMargin
    leftMargin: sectionMargin
    rightMargin: sectionMargin
    radius: sectionRadius
    topPadding: sectionVerticalPadding
    bottomPadding: sectionVerticalPadding
    leftPadding: sectionHorizontalPadding
    rightPadding: sectionHorizontalPadding
    clip: sectionClip
    backgroundColor: sectionBackgroundColor
    topBorderColor: sectionTopBorderColor
    topBorderHeight: sectionTopBorderHeight
    showTopBorder: sectionShowTopBorder
    
    Item {
        width: Theme.barSize - (sectionMargin * 2)
        height: {
            // Calculate total height of all children
            let total = 0;
            for (let i = 0; i < clockColumn.children.length; i++) {
                const child = clockColumn.children[i];
                if (child.height !== undefined) {
                    total += child.height;
                } else if (child.implicitHeight !== undefined) {
                    total += child.implicitHeight;
                }
            }
            return total + clockColumn.spacing * (clockColumn.children.length - 1) + 6;  // Add spacing and top/bottom padding
        }
        
        Column {
            id: clockColumn
            anchors.centerIn: parent
            spacing: 1
            width: parent.width
            
            // Month-Day text
            Text {
                id: dateText
                text: Qt.formatDateTime(new Date(), "MMM d").toUpperCase()
                font.pointSize: Theme.fontSizeNormal
                font.family: Theme.fontFamilyUiNf
                color: Theme.app600
                opacity: 0.6
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            // Spacer to match bottom padding
            Item { width: 1; height: 6 }
            
            // Hour: HH
            Text {
                id: hourText
                text: Qt.formatDateTime(new Date(), "HH")
                font.pointSize: Theme.fontSizeBigger
                font.family: Theme.fontFamilyUiNf
                color: Theme.app800
                anchors.horizontalCenter: parent.horizontalCenter
                font.bold: true
            }
            
            // Minute: mm
            Text {
                id: minuteText
                text: Qt.formatDateTime(new Date(), "mm")
                font.pointSize: Theme.fontSizeBigger
                font.family: Theme.fontFamilyUiNf
                color: Theme.app800
                anchors.horizontalCenter: parent.horizontalCenter
                font.bold: true
            }
            
            // Second: ss
            Text {
                id: secondText
                text: Qt.formatDateTime(new Date(), "ss")
                font.pointSize: Theme.fontSizeBigger
                font.family: Theme.fontFamilyUiNf
                color: Theme.app600
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: 0.7
            }
        }
        
        // Update timer
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                const now = new Date();
                dateText.text = Qt.formatDateTime(now, "MMM d").toUpperCase();
                hourText.text = Qt.formatDateTime(now, "HH");
                minuteText.text = Qt.formatDateTime(now, "mm");
                secondText.text = Qt.formatDateTime(now, "ss");
            }
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
}