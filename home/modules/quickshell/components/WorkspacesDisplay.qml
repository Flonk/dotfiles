// WorkspacesDisplay.qml
import QtQuick
import QtQuick.Controls
import Quickshell.Hyprland

Row {
    id: root
    
    // This will be set by the Bar to the current screen's monitor
    required property var monitor
    
    spacing: 0  // no margin between squares
    
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
            
            width: Theme.barHeight  // square: barHeight x barHeight
            height: Theme.barHeight  // barHeight high
            radius: 0  // sharp corners for seamless connection
            
            // app150 backdrop for all
            color: Theme.app150
            
            // Active workspace gets 1px wm800 border
            border.color: modelData.focused ? Theme.wm800 : "transparent"
            border.width: modelData.focused ? 1 : 0
            
            Text {
                anchors.centerIn: parent
                text: modelData.name
                font.pointSize: Theme.fontSizeSmall
                font.family: Theme.fontFamilyUiNf
                // Active workspace: wm800 text, others: app600 text
                color: modelData.focused ? Theme.wm800 : Theme.app600
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