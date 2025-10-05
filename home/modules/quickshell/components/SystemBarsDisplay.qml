// SystemBarsDisplay.qml - Compact multi-bar system status widget using SystemBar components
import QtQuick
import Quickshell

Item {
    id: root
    
    // Theme colors - using app colors instead of wm colors
    property color backgroundBarColor: "transparent"
    property color foregroundBarColor: Theme.wm900
    property color backgroundTextColor: Theme.app800
    property color foregroundTextColor: Theme.app100
    property color errorColor: Theme.error400
    property color chargingColor: Theme.success600     // New charging bar color
    property color chargingTextColor: Theme.app100 // Bright text when charging
    property color chargingTextColorDark: Theme.success400 // Darker text when charging
    
    // Calculate total dimensions - two containers side by side + padding
    width: 130  // 120px content + 10px horizontal padding (5px each side)
    height: Theme.barHeight
    
    // Content container with padding
    Item {
        anchors.fill: parent
        anchors.margins: 0  // 5px horizontal padding
        anchors.topMargin: 0  // 2px vertical padding
        anchors.bottomMargin: 0  // 2px vertical padding
    
        // Left container - MEM (top) and DISK (bottom)
        Item {
            id: leftContainer
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 60
            
            // Memory bar (top half)
            SystemBar {
                id: memoryBar
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.right: parent.right
                height: parent.height / 2
                
                label: "MEM"
                value: SystemMonitor.memoryUsage
                backgroundBarColor: root.backgroundBarColor
                foregroundBarColor: root.foregroundBarColor
                backgroundTextColor: root.backgroundTextColor
                foregroundTextColor: root.foregroundTextColor
                errorColor: root.errorColor
            }
            
            // Disk bar (bottom half)
            SystemBar {
                id: diskBar
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                height: parent.height / 2
                
                label: "DISK"
                value: SystemMonitor.diskUsage
                backgroundBarColor: root.backgroundBarColor
                foregroundBarColor: root.foregroundBarColor
                backgroundTextColor: root.backgroundTextColor
                foregroundTextColor: root.foregroundTextColor
                errorColor: root.errorColor
            }
        }
        
        // Right container - BRIGHTNESS (top) and BATTERY (bottom)
        Item {
            id: rightContainer
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 60
            
            // Brightness bar (top half) - interactive brightness control
            SystemBar {
                id: brightnessBar
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.right: parent.right
                height: parent.height / 2
                
                label: "BRT"
                value: BrightnessWidget.brightness
                backgroundBarColor: root.backgroundBarColor
                foregroundBarColor: root.foregroundBarColor
                backgroundTextColor: root.backgroundTextColor
                foregroundTextColor: root.foregroundTextColor
                errorColor: root.errorColor
                enableErrorThreshold: false  // Brightness shouldn't turn red at high levels
                
                // Enable mouse interaction for brightness control
                enableMouseInteraction: true
                valueChangedCallback: function(newValue) {
                    BrightnessWidget.setBrightness(newValue);
                }
                mouseStep: 0.01  // 5% brightness steps for mouse wheel
            }
            
            // Battery bar (bottom half)
            SystemBar {
                id: batteryBar
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                height: parent.height / 2
                
                label: "BAT"
                value: SystemMonitor.batteryLevel
                barVisible: SystemMonitor.hasBattery
                backgroundBarColor: root.backgroundBarColor
                foregroundBarColor: root.foregroundBarColor
                backgroundTextColor: root.backgroundTextColor
                foregroundTextColor: root.foregroundTextColor
                errorColor: root.errorColor
                
                // Custom battery colors based on charging state
                useCustomColors: {
                    return true;
                }
                
                customBarColor: {
                    if (!SystemMonitor.hasBattery) return root.chargingColor;
                    const colorState = SystemMonitor.getBatteryColorState();
                    if (colorState === "charging") return root.chargingColor;
                    if (colorState === "critical") return root.errorColor;
                    return Theme.wm500;  // Window manager color for normal discharge
                }
                
                customBackgroundTextColor: {
                    if (!SystemMonitor.hasBattery) return root.chargingTextColorDark;
                    const colorState = SystemMonitor.getBatteryColorState();
                    return (colorState === "charging") ? root.chargingTextColorDark : root.backgroundTextColor;
                }
                
                customForegroundTextColor: {
                    if (!SystemMonitor.hasBattery) return root.chargingTextColor;
                    const colorState = SystemMonitor.getBatteryColorState();
                    return (colorState === "charging") ? root.chargingTextColor : root.foregroundTextColor;
                }
            }
        }
    }
}