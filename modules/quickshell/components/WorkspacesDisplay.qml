// WorkspacesDisplay.qml
import QtQuick
import QtQuick.Controls
import Quickshell.Hyprland

Column {
    id: root
    
    // This will be set by the Bar to the current screen's monitor
    required property var monitor
    
    spacing: 4  // margin between squares
    width: Theme.barSize
    
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
            
            width: Theme.barSize / 1.5  // square size
            height: Theme.barSize / 1.5  // square size
            radius: Theme.barSize  // sharp corners for seamless connection
            
            // Active workspace gets 1px wm800 border
            border.color: modelData.focused ? Theme.wm800 : "transparent"
            border.width: modelData.focused ? 0 : 0
            color: modelData.focused ? Theme.wm800 : "transparent"

            anchors.horizontalCenter: root.horizontalCenter
            
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