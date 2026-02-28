// WorkspacesWidget.qml
import Quickshell
import Quickshell.Hyprland
import QtQuick

Item {
    id: root

    // Required property: the monitor this widget is for
    required property var monitor

    // Get workspaces filtered by this monitor
    property var workspaces: {
        if (!monitor || !Hyprland.workspaces || !Hyprland.workspaces.values) {
            return [];
        }
        
        const allWorkspaces = Hyprland.workspaces.values;
        const filtered = [];
        
        for (let i = 0; i < allWorkspaces.length; i++) {
            const workspace = allWorkspaces[i];
            if (workspace && workspace.monitor && workspace.monitor.name === monitor.name) {
                filtered.push(workspace);
            }
        }
        
        // Sort by workspace id/name
        filtered.sort((a, b) => {
            const aNum = parseInt(a.name);
            const bNum = parseInt(b.name);
            
            if (!isNaN(aNum) && !isNaN(bNum)) {
                return aNum - bNum;
            }
            
            return a.name.localeCompare(b.name);
        });
        
        return filtered;
    }
    
    // Listen for workspace changes
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "workspace" || 
                event.name === "createworkspace" || 
                event.name === "destroyworkspace" ||
                event.name === "moveworkspace") {
                // The workspaces property will automatically update
                // due to reactive bindings when Hyprland.workspaces changes
            }
        }
    }

    // Function to switch to a workspace
    function switchToWorkspace(workspaceId) {
        Hyprland.dispatch(`workspace ${workspaceId}`);
    }
}