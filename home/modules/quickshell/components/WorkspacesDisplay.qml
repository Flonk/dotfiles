// WorkspacesDisplay.qml
import QtQuick
import QtQuick.Controls
import Quickshell.Hyprland

Row {
    id: root
    
    // This will be set by the Bar to the current screen's monitor
    required property var monitor
    
    spacing: 3
    
    // Use WorkspacesWidget to handle workspace logic
    WorkspacesWidget {
        id: workspacesWidget
        monitor: root.monitor
    }
    
    // Use the filtered workspaces from the widget
    property var filteredWorkspaces: workspacesWidget.workspaces

    Repeater {
        // Use filtered workspaces from our WorkspacesWidget
        model: root.filteredWorkspaces
        
        delegate: Rectangle {
            required property var modelData
            
            width: 25
            height: 18
            radius: 3
            
            // Color based on workspace state
            color: {
                if (modelData.focused) return Theme.wm800;  // focused workspace uses wm800
                if (modelData.toplevels && modelData.toplevels.length > 0) return Theme.app200; // occupied workspaces use borders color
                return Theme.app150;  // empty workspaces use background color
            }
            
            border.color: modelData.focused ? Theme.app400 : "transparent"  // text color for border
            border.width: 1
            
            Text {
                anchors.centerIn: parent
                text: modelData.name
                font.pointSize: Theme.fontSizeSmall
                font.family: Theme.fontFamilyUiNf
                color: Theme.app400  // text color
                font.bold: modelData.focused
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    workspacesWidget.switchToWorkspace(modelData.name);
                }
                
                hoverEnabled: true
                ToolTip.visible: containsMouse
                ToolTip.text: `Workspace ${modelData.name}${modelData.toplevels && modelData.toplevels.length > 0 ? ` (${modelData.toplevels.length} windows)` : " (empty)"}`
            }
        }
    }
}