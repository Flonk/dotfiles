// ActiveWindowWidget.qml
pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    property string windowTitle: ""
    property string windowClass: ""
    property int maxTitleLength: 50  // Truncate long titles

    // Listen for Hyprland events using the singleton
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindow") {
                // Parse the event data - format is "windowclass,windowtitle"
                const parsed = event.parse(2);  // We know activewindow has 2 arguments
                if (parsed.length >= 2) {
                    root.windowClass = parsed[0] || "";
                    root.windowTitle = parsed[1] || "";
                } else {
                    // No active window
                    root.windowClass = "";
                    root.windowTitle = "";
                }
            }
        }
    }

    // Also track the activeToplevel property directly
    property var activeToplevel: Hyprland.activeToplevel
    
    onActiveToplevelChanged: {
        if (activeToplevel) {
            root.windowTitle = activeToplevel.title || "";
            root.windowClass = activeToplevel.class || "";
        } else {
            root.windowTitle = "";
            root.windowClass = "";
        }
    }

    // Helper properties
    property string displayTitle: {
        if (!windowTitle) return "";
        if (windowTitle.length <= maxTitleLength) return windowTitle;
        return windowTitle.substring(0, maxTitleLength - 3) + "...";
    }
}