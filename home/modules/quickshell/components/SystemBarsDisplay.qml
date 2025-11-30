// SystemBarsDisplay.qml - Compact multi-bar system status widget using SystemBar components
import QtQuick
import Quickshell
import Quickshell.Io

Column {
    id: root
    spacing: root.sectionVerticalGap
    width: Theme.barSize
    
    property int sectionMargin: 0  // Can be overridden from parent
    property int sectionRadius: 5  // Can be overridden from parent
    property int sectionVerticalPadding: 6
    property int sectionVerticalGap: 0
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
    property bool wifiWarningActive: WifiWidget.isHighTraffic
    
    // MEM / DSK / CPU
    Section {
        width: parent.width
        topMargin: root.sectionMargin
        bottomMargin: root.sectionVerticalGap
        leftMargin: root.sectionMargin
        rightMargin: root.sectionMargin
        radius: root.sectionRadius
        topPadding: root.sectionVerticalPadding
        bottomPadding: Math.max(0, root.sectionVerticalPadding - 3)
        leftPadding: root.sectionHorizontalPadding
        rightPadding: root.sectionHorizontalPadding
        clip: root.sectionClip
        backgroundColor: root.sectionBackgroundColor
        topBorderColor: root.sectionTopBorderColor
        topBorderHeight: root.sectionTopBorderHeight
        showTopBorder: false
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
    // WIFI
    Section {
        width: parent.width
        topMargin: root.sectionVerticalGap
        bottomMargin: root.sectionVerticalGap
        leftMargin: Math.max(0, root.sectionMargin - 2)
        rightMargin: Math.max(0, root.sectionMargin - 2)
        radius: root.sectionRadius
        topPadding: 0
        bottomPadding: 0
        leftPadding: root.sectionHorizontalPadding
        rightPadding: root.sectionHorizontalPadding
        clip: root.sectionClip
        backgroundColor: root.wifiWarningActive ? root.warningColor : root.sectionBackgroundColor
        topBorderColor: root.sectionTopBorderColor
        topBorderHeight: root.sectionTopBorderHeight
        showTopBorder: root.sectionShowTopBorder
        bottomBorderColor: root.wifiWarningActive ? root.warningColor : root.sectionTopBorderColor
        bottomBorderHeight: 1
        showBottomBorder: true
        WifiDisplay {
            width: parent.width
            wifiTextColor: root.wifiWarningActive ? "#000000" : root.textColor
            wifiBarColor: root.wifiWarningActive ? "#000000" : root.barColor
            backgroundColor: root.wifiWarningActive ? root.warningColor : Theme.app700
            wifiHoverColor: root.wifiWarningActive ? root.warningColor : Theme.app600
            wifiHoverBackground: root.wifiWarningActive ? "#000000" : "#000000"
        }
    }
    // BLUETOOTH
    Section {
        width: parent.width
        topMargin: root.sectionVerticalGap
        bottomMargin: root.sectionVerticalGap
        leftMargin: root.sectionMargin
        rightMargin: root.sectionMargin
        radius: root.sectionRadius
        topPadding: 1
        bottomPadding: 0
        leftPadding: root.sectionHorizontalPadding
        rightPadding: root.sectionHorizontalPadding
        clip: root.sectionClip
        backgroundColor: root.sectionBackgroundColor
        topBorderColor: root.sectionTopBorderColor
        topBorderHeight: root.sectionTopBorderHeight
        showTopBorder: root.sectionShowTopBorder
        BluetoothDisplay {
            width: parent.width
            btTextColor: root.textColor
            btBarColor: root.barColor
        }
    }
    // BRIGHTNESS
    Section {
        width: parent.width
        topMargin: root.sectionVerticalGap
        bottomMargin: root.sectionVerticalGap
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
            verticalPadding: 1
            label: "BRT"
            value: BrightnessWidget.brightness
            textColor: "#000000"
            errorColor: root.errorColor
            enableErrorThreshold: false
            enableMouseInteraction: true
            valueChangedCallback: function(newValue) {
                BrightnessWidget.setBrightness(newValue);
            }
            mouseStep: 0.01
        }
    }
    // CLOCK
    Section {
        width: parent.width
        topMargin: root.sectionVerticalGap
        bottomMargin: root.sectionVerticalGap
        leftMargin: root.sectionMargin
        rightMargin: root.sectionMargin
        radius: root.sectionRadius
        topPadding: root.sectionVerticalPadding + 2
        bottomPadding: root.sectionVerticalPadding
        leftPadding: root.sectionHorizontalPadding
        rightPadding: root.sectionHorizontalPadding
        clip: root.sectionClip
        backgroundColor: Theme.app800
        topBorderColor: root.sectionTopBorderColor
        topBorderHeight: root.sectionTopBorderHeight
        showTopBorder: root.sectionShowTopBorder
        
        ClockDisplay {
            width: parent.width
        }
    }
    // BATTERY
    Section {
        width: parent.width
        topMargin: root.sectionVerticalGap
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
            verticalPadding: 1
            label: "BAT"
            value: SystemMonitor.batteryLevel
            textColor: "#000000"
            errorColor: root.errorColor
            enableErrorThreshold: false
        }
    }

    Connections {
        target: WifiWidget
        function onIsHighTrafficChanged() {
            root.wifiWarningActive = WifiWidget.isHighTraffic;
            console.log("[SystemBarsDisplay] wifiWarningActive", root.wifiWarningActive, "download", WifiWidget.downloadRate, "upload", WifiWidget.uploadRate);
        }
    }
}