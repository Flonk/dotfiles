// BatteryWidget.qml
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Battery properties
    property real batteryLevel: 0.5
    property bool isCharging: false
    property bool hasBattery: false
    property string batteryStatus: "Unknown"
    
    // Update interval
    property int updateInterval: 10000  // 10 seconds for battery

    // Initialize battery monitoring on startup
    Component.onCompleted: {
        batteryTimer.start();
        updateBatteryInfo();
    }

    // Battery update timer
    Timer {
        id: batteryTimer
        running: true
        interval: root.updateInterval
        repeat: true
        triggeredOnStart: true
        
        onTriggered: {
            updateBatteryInfo();
        }
    }

    function updateBatteryInfo(): void {
        batteryProc.running = true;
    }

    // Battery status process
    Process {
        id: batteryProc
        
        command: ["sh", "-c", "find /sys/class/power_supply -name 'BAT*' | head -1 | xargs -I {} sh -c 'echo $(cat {}/capacity) $(cat {}/status)'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output && output !== "") {
                    const parts = output.split(/\s+/);
                    if (parts.length >= 2) {
                        root.hasBattery = true;
                        root.batteryLevel = parseInt(parts[0], 10) / 100.0;
                        root.batteryStatus = parts[1];
                        root.isCharging = parts[1] === "Charging";
                    } else {
                        root.hasBattery = false;
                    }
                } else {
                    root.hasBattery = false;
                }
            }
        }
        
        onExited: (code) => {
            if (code !== 0) {
                root.hasBattery = false;
            }
        }
    }

    // Helper function to get battery icon
    function getBatteryIcon(): string {
        if (!hasBattery) return "";
        
        if (isCharging) {
            return "🔌";
        }
        
        if (batteryLevel > 0.9) return "🔋";
        if (batteryLevel > 0.75) return "🔋";
        if (batteryLevel > 0.5) return "🔋";
        if (batteryLevel > 0.25) return "🪫";
        return "🪫";
    }

    // Helper for battery text
    property string batteryText: hasBattery ? `${Math.round(batteryLevel * 100)}%` : ""
    
    // Helper for charging indicator
    function getChargingIndicator(): string {
        if (!hasBattery) return "";
        return isCharging ? " ⚡" : "";
    }
}