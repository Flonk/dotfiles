// SystemBarsDisplay.qml - Compact multi-bar system status widget using SystemBar components
import QtQuick
import Quickshell
import Quickshell.Io

Column {
    id: root
    spacing: root.sectionVerticalGap
    width: Theme.barSize
    
    property int sectionMargin: 0  // Can be overridden from parent
    property int sectionRadius: 7  // Can be overridden from parent
    property int sectionVerticalPadding: 6
    property int sectionVerticalGap: 1
    property int sectionHorizontalPadding: 1
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
    
    // MEDIA CONTROL
    Section {
        width: parent.width
        topMargin: root.sectionMargin
        bottomMargin: root.sectionVerticalGap
        leftMargin: root.sectionMargin
        rightMargin: root.sectionMargin
        radius: root.sectionRadius
        topPadding: 0
        bottomPadding: 0
        leftPadding: root.sectionHorizontalPadding
        rightPadding: root.sectionHorizontalPadding
        clip: false
        backgroundColor: Qt.rgba(Theme.app200.r, Theme.app200.g, Theme.app200.b, 0.2)
        topBorderColor: root.sectionTopBorderColor
        topBorderHeight: root.sectionTopBorderHeight
        showTopBorder: false
        glassEffect: true

        MediaControlDisplay {
            width: Theme.barSize - (root.sectionMargin * 2) - (root.sectionHorizontalPadding * 2)
            textColor: root.textColor
        }
    }

    // MEM / DSK / CPU
    Section {
        width: parent.width
        topMargin: root.sectionVerticalGap
        bottomMargin: root.sectionVerticalGap
        leftMargin: root.sectionMargin
        rightMargin: root.sectionMargin
        radius: root.sectionRadius
        topPadding: root.sectionVerticalPadding + 2
        bottomPadding: Math.max(0, root.sectionVerticalPadding - 3)
        leftPadding: root.sectionHorizontalPadding
        rightPadding: root.sectionHorizontalPadding
        clip: root.sectionClip
        backgroundColor: Qt.rgba(Theme.app200.r, Theme.app200.g, Theme.app200.b, 0.2)
        topBorderColor: root.sectionTopBorderColor
        topBorderHeight: root.sectionTopBorderHeight
        showTopBorder: false
        glassEffect: true
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
        leftMargin: root.sectionMargin
        rightMargin: root.sectionMargin
        radius: root.sectionRadius
        topPadding: 0
        bottomPadding: 0
        leftPadding: root.sectionHorizontalPadding
        rightPadding: root.sectionHorizontalPadding
        clip: root.sectionClip
        backgroundColor: Qt.rgba(Theme.app200.r, Theme.app200.g, Theme.app200.b, 0.2)
        topBorderColor: root.sectionTopBorderColor
        topBorderHeight: root.sectionTopBorderHeight
        showTopBorder: false
        showBottomBorder: false
        glassEffect: true
        WifiDisplay {
            width: parent.width
            wifiIconColor: root.wifiWarningActive ? root.warningColor : Theme.app900
            wifiTextColor: root.textColor
            wifiBarColor: root.barColor
            backgroundColor: "transparent"
            wifiHoverColor: Theme.app600
            wifiHoverBackground: "#000000"
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
        topPadding: 6
        bottomPadding: 4
        leftPadding: root.sectionHorizontalPadding
        rightPadding: root.sectionHorizontalPadding
        clip: root.sectionClip
        backgroundColor: Qt.rgba(Theme.app200.r, Theme.app200.g, Theme.app200.b, 0.2)
        showTopBorder: false
        glassEffect: true

        ClockDisplay {
            id: clockContent
            width: parent.width
            textColor: root.textColor
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
        topPadding: root.sectionVerticalPadding
        bottomPadding: root.sectionVerticalPadding
        leftPadding: root.sectionHorizontalPadding
        rightPadding: root.sectionHorizontalPadding
        clip: root.sectionClip
        backgroundColor: "#bda551"
        showTopBorder: false
        glassEffect: true

        SystemBar {
            id: brightnessBar
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
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

    // VOLUME
    Section {
        width: parent.width
        topMargin: root.sectionVerticalGap
        bottomMargin: root.sectionVerticalGap
        leftMargin: root.sectionMargin
        rightMargin: root.sectionMargin
        radius: root.sectionRadius
        topPadding: root.sectionVerticalPadding
        bottomPadding: root.sectionVerticalPadding
        leftPadding: root.sectionHorizontalPadding
        rightPadding: root.sectionHorizontalPadding
        clip: root.sectionClip
        backgroundColor: "#7493a3"
        showTopBorder: false
        glassEffect: true

        Item {
            width: parent.width
            height: volumeBar.height
            anchors.verticalCenter: parent.verticalCenter

            SystemBar {
                id: volumeBar
                width: parent.width
                icon: {
                    if (VolumeWidget.muted) return "\ueee8";
                    const v = VolumeWidget.volume;
                    if (v <= 0) return "\uf026";
                    if (v < 0.35) return "\uf027";
                    return "\uf028";
                }
                iconLeftPadding: 0
                verticalPadding: 1
                label: "VOL"
                value: VolumeWidget.volume
                textColor: VolumeWidget.muted ? root.warningColor : "#000000"
                errorColor: root.errorColor
                enableErrorThreshold: false
                enableMouseInteraction: true
                valueChangedCallback: function(newValue) {
                    VolumeWidget.setVolume(newValue);
                }
                mouseStep: 0.01
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: function(mouse) {
                    VolumeWidget.toggleMute();
                }
            }
        }
    }

    // BATTERY
    Section {
        width: parent.width
        topMargin: root.sectionVerticalGap
        bottomMargin: root.sectionVerticalGap
        leftMargin: root.sectionMargin
        rightMargin: root.sectionMargin
        radius: root.sectionRadius
        topPadding: root.sectionVerticalPadding
        bottomPadding: root.sectionVerticalPadding
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
        showTopBorder: false
        glassEffect: true
        SystemBar {
            id: batteryBar
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
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