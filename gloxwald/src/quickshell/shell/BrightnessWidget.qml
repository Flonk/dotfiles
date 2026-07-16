// BrightnessWidget.qml  
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real brightness: 0.5
    property real brightnessIncrement: 0.005
    
    // Detect if we have ddcutil for external monitors or just use brightnessctl
    property bool useSystemBrightness: true
    
    function setBrightness(value: real): void {
        const clampedValue = Math.max(0, Math.min(1, value));
        const percentage = Math.round(clampedValue * 100);
        
        brightness = clampedValue;
        
        // Use brightnessctl for built-in displays
        Quickshell.execDetached(["brightnessctl", "s", `${percentage}%`]);
    }

    function increaseBrightness(): void {
        setBrightness(brightness + brightnessIncrement);
    }

    function decreaseBrightness(): void {
        setBrightness(brightness - brightnessIncrement);
    }

    // Initialize brightness on startup
    Component.onCompleted: {
        initProc.running = true;
    }

    // Process to get current brightness
    Process {
        id: initProc
        
        command: ["sh", "-c", "echo a b c $(brightnessctl g) $(brightnessctl m)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(" ");
                if (parts.length >= 5) {
                    const current = parseInt(parts[3], 10) || 0;
                    const max = parseInt(parts[4], 10) || 1;
                    root.brightness = current / max;
                }
            }
        }
        
        onExited: (code) => {
            if (code !== 0) {
                console.log("Failed to get brightness, using default");
                root.brightness = 0.5;
            }
        }
    }

    // Helper for brightness icon
    property string brightnessIcon: {
        if (brightness > 0.75) return "☀️";
        if (brightness > 0.5) return "🌤️";  
        if (brightness > 0.25) return "⛅";
        return "🌙";
    }

    // Helper for brightness text
    property string brightnessText: `${Math.round(brightness * 100)}%`
}