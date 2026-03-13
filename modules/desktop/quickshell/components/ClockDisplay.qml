// ClockDisplay.qml - Clock display component
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    
    property color textColor: "#000000"
    
    width: parent ? parent.width : Theme.barSize
    height: {
        let total = 0;
        for (let i = 0; i < clockColumn.children.length; i++) {
            const child = clockColumn.children[i];
            if (child.height !== undefined) {
                total += child.height;
            } else if (child.implicitHeight !== undefined) {
                total += child.implicitHeight;
            }
        }
        return total + clockColumn.spacing * (clockColumn.children.length - 1) + 9;
    }
    
    Column {
        id: clockColumn
        anchors.centerIn: parent
        spacing: 1
        width: parent.width
        
        Text {
            id: hourText
            text: Qt.formatDateTime(new Date(), "HH")
            font.pointSize: Theme.fontSizeHuge
            font.family: Theme.fontFamilyUiNf
            color: root.textColor
            anchors.horizontalCenter: parent.horizontalCenter
            font.bold: true
        }
        
        Text {
            id: minuteText
            text: Qt.formatDateTime(new Date(), "mm")
            font.pointSize: Theme.fontSizeHuge
            font.family: Theme.fontFamilyUiNf
            color: root.textColor
            anchors.horizontalCenter: parent.horizontalCenter
            font.bold: true
        }
        
        Text {
            id: secondText
            text: Qt.formatDateTime(new Date(), "ss")
            font.pointSize: Theme.fontSizeHuge
            font.family: Theme.fontFamilyUiNf
            color: Theme.app600
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: 0.7
            font.bold: true
        }
        
        Item { width: 1; height: 2 }
        
        Text {
            id: dateText
            text: Qt.formatDateTime(new Date(), "MMM d").toUpperCase()
            font.pointSize: Theme.fontSizeSmall
            font.family: Theme.fontFamilyUiNf
            font.bold: true
            color: root.textColor
            opacity: 0.6
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
        }
    }
    
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
            const now = new Date();
            const isoTimestamp = now.toISOString();
            clipboardProcess.command = ["wl-copy", isoTimestamp];
            clipboardProcess.running = true;
            notificationProcess.running = true;
        }
        cursorShape: Qt.PointingHandCursor
    }
    
    Process {
        id: clipboardProcess
        onExited: (code) => {
            if (code === 0) {
                console.log("Timestamp copied to clipboard");
            }
        }
    }
    
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
