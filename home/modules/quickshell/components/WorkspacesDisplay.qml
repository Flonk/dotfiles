// WorkspacesDisplay.qml
import QtQuick
import QtQuick.Controls
import Quickshell.Hyprland

Row {
    id: root
    
    // This will be set by the Bar to the current screen's monitor
    required property var monitor
    
    spacing: 4  // no margin between squares
    height: Theme.barHeight
    
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
            
            width: Theme.barHeight / 1.5  // square: barHeight x barHeight
            height: Theme.barHeight / 1.5  // barHeight high
            radius: Theme.barHeight  // sharp corners for seamless connection
            
            // Active workspace gets 1px wm800 border
            border.color: modelData.focused ? Theme.wm800 : "transparent"
            border.width: modelData.focused ? 0 : 0
            color: modelData.focused ? Theme.wm800 : Theme.app150

            anchors.verticalCenter: root.verticalCenter
            
            Text {
                anchors.centerIn: parent
                text: modelData.name
                font.pointSize: Theme.fontSizeSmall
                font.family: Theme.fontFamilyUiNf
                // Active workspace: wm800 text, others: app600 text
                color: modelData.focused ? Theme.app150 : Theme.app600
                font.bold: modelData.focused
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    workspacesWidget.switchToWorkspace(modelData.name);
                }
                
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}