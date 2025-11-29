// SystemBarsDisplay.qml - Compact multi-bar system status widget using SystemBar components
import QtQuick
import Quickshell
import Quickshell.Io

Column {
    id: root
    spacing: root.sectionMargin
    width: Theme.barSize
    
    property int sectionMargin: 3  // Can be overridden from parent
    property int sectionRadius: 5  // Can be overridden from parent
    property int sectionVerticalPadding: 4
    property int sectionHorizontalPadding: 0
    property bool sectionClip: true
    property color sectionBackgroundColor: "#000000"
    property color sectionTopBorderColor: Theme.app200
    property int sectionTopBorderHeight: 1
    property bool sectionShowTopBorder: true
    
    // Theme colors
    property color barColor: Theme.app600
    property color textColor: Theme.app600
    property color warningColor: "#FFA500"  // Orange
    property color errorColor: Theme.error400
    property color chargingColor: Theme.success600
    
    // MEM / DSK / CPU
    Section {
        width: parent.width
        topMargin: root.sectionMargin
        bottomMargin: root.sectionMargin
        leftMargin: root.sectionMargin
        rightMargin: root.sectionMargin
        radius: root.sectionRadius
        topPadding: root.sectionVerticalPadding
        bottomPadding: root.sectionVerticalPadding
        leftPadding: root.sectionHorizontalPadding
        rightPadding: root.sectionHorizontalPadding
        clip: root.sectionClip
        backgroundColor: root.sectionBackgroundColor
        topBorderColor: root.sectionTopBorderColor
        topBorderHeight: root.sectionTopBorderHeight
        showTopBorder: root.sectionShowTopBorder
        Column {
            id: metricsColumn
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0
            SystemBar {
                id: memoryBar
                width: parent.width
                icon: "\uefc5"
                iconLeftPadding: -1
                iconPointSize: Theme.fontSizeNormal
                verticalPadding: 1
                label: "MEM"
                value: SystemMonitor.memoryUsage
                showBar: false
                textColor: SystemMonitor.memoryUsage > 0.8 ? root.warningColor : root.textColor
                errorColor: root.errorColor
            }
            SystemBar {
                id: diskBar
                width: parent.width
                icon: "\uf0c7"
                iconLeftPadding: 1
                verticalPadding: 1
                label: "DSK"
                value: SystemMonitor.diskUsage
                showBar: false
                textColor: SystemMonitor.diskUsage > 0.8 ? root.warningColor : root.textColor
                errorColor: root.errorColor
            }
            CpuDisplay {
                id: cpuDisplay
                width: parent.width
                barWidth: 3
                barSpacing: 1
                topRadius: 0
                bottomRadius: 0
                maxBarWidth: Theme.barSize
                fillFromRight: true
            }
        }
    }
    // CLOCK
    Section {
        width: parent.width
        topMargin: root.sectionMargin
        bottomMargin: root.sectionMargin
        leftMargin: root.sectionMargin
        rightMargin: root.sectionMargin
        radius: root.sectionRadius
        topPadding: root.sectionVerticalPadding
        bottomPadding: root.sectionVerticalPadding
        leftPadding: root.sectionHorizontalPadding
        rightPadding: root.sectionHorizontalPadding
        clip: root.sectionClip
        backgroundColor: root.sectionBackgroundColor
        topBorderColor: root.sectionTopBorderColor
        topBorderHeight: root.sectionTopBorderHeight
        showTopBorder: root.sectionShowTopBorder
        Item {
            width: Theme.barSize - (root.sectionMargin * 2)
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
                return total + clockColumn.spacing * (clockColumn.children.length - 1) + 6;
            }
            Column {
                id: clockColumn
                anchors.centerIn: parent
                spacing: 1
                width: parent.width
                Text {
                    id: dateText
                    text: Qt.formatDateTime(new Date(), "MMM d").toUpperCase()
                    font.pointSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamilyUiNf
                    color: Theme.app600
                    opacity: 0.6
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Item { width: 1; height: 6 }
                Text {
                    id: hourText
                    text: Qt.formatDateTime(new Date(), "HH")
                    font.pointSize: Theme.fontSizeBigger
                    font.family: Theme.fontFamilyUiNf
                    color: Theme.app800
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.bold: true
                }
                Text {
                    id: minuteText
                    text: Qt.formatDateTime(new Date(), "mm")
                    font.pointSize: Theme.fontSizeBigger
                    font.family: Theme.fontFamilyUiNf
                    color: Theme.app800
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.bold: true
                }
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
    }
    // WIFI
    Section {
        width: parent.width
        topMargin: root.sectionMargin
        bottomMargin: root.sectionMargin
        leftMargin: root.sectionMargin
        rightMargin: root.sectionMargin
        radius: root.sectionRadius
        topPadding: 0
        bottomPadding: 0
        leftPadding: root.sectionHorizontalPadding
        rightPadding: root.sectionHorizontalPadding
        clip: root.sectionClip
        backgroundColor: root.sectionBackgroundColor
        topBorderColor: root.sectionTopBorderColor
        topBorderHeight: root.sectionTopBorderHeight
        showTopBorder: root.sectionShowTopBorder
        WifiDisplay {
            width: parent.width
            wifiTextColor: root.textColor
            wifiBarColor: root.barColor
        }
    }
    // BRIGHTNESS
    Section {
        width: parent.width
        topMargin: root.sectionMargin
        bottomMargin: root.sectionMargin
        leftMargin: root.sectionMargin
        rightMargin: root.sectionMargin
        radius: root.sectionRadius
        topPadding: 2
        bottomPadding: 0
        leftPadding: root.sectionHorizontalPadding
        rightPadding: root.sectionHorizontalPadding
        clip: root.sectionClip
        backgroundColor: root.barColor
        topBorderColor: root.sectionTopBorderColor
        topBorderHeight: root.sectionTopBorderHeight
        showTopBorder: root.sectionShowTopBorder
        SystemBar {
            id: brightnessBar
            width: Theme.barSize - (root.sectionMargin * 2) - (root.sectionHorizontalPadding * 2)
            icon: "\uf522"
            iconLeftPadding: 0
            fillFromRight: true
            verticalPadding: 1
            label: "BRT"
            value: BrightnessWidget.brightness
            barVisible: false
            barColor: root.barColor
            textColor: root.textColor
            errorColor: root.errorColor
            enableErrorThreshold: false
            useCustomColors: true
            customBarColor: "#000000"
            customTextColor: "#000000"
            enableMouseInteraction: true
            valueChangedCallback: function(newValue) {
                BrightnessWidget.setBrightness(newValue);
            }
            mouseStep: 0.01
        }
    }
    // BATTERY
    Section {
        width: parent.width
        topMargin: root.sectionMargin
        bottomMargin: root.sectionMargin
        leftMargin: root.sectionMargin
        rightMargin: root.sectionMargin
        radius: root.sectionRadius
        topPadding: 2
        bottomPadding: 0
        leftPadding: root.sectionHorizontalPadding
        rightPadding: root.sectionHorizontalPadding
        clip: root.sectionClip
        backgroundColor: {
            if (!SystemMonitor.hasBattery) return root.chargingColor;
            const colorState = SystemMonitor.getBatteryColorState();
            if (colorState === "charging") return root.chargingColor;
            if (colorState === "critical") return root.errorColor;
            return root.warningColor;
        }
        topBorderColor: root.sectionTopBorderColor
        topBorderHeight: root.sectionTopBorderHeight
        showTopBorder: root.sectionShowTopBorder
        SystemBar {
            id: batteryBar
            width: Theme.barSize - (root.sectionMargin * 2) - (root.sectionHorizontalPadding * 2)
            icon: "\udb85\udc0b"
            iconLeftPadding: 2
            fillFromRight: true
            verticalPadding: 1
            label: "BAT"
            value: SystemMonitor.batteryLevel
            barVisible: false
            barOnTop: false
            barColor: root.barColor
            textColor: root.textColor
            errorColor: root.errorColor
            enableErrorThreshold: false
            useCustomColors: true
            customBarColor: "#000000"
            customTextColor: "#000000"
        }
    }
}