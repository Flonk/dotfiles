// WorkspacesDisplay.qml
import QtQuick
import QtQuick.Controls
import Quickshell.Hyprland

Row {
    id: root
    
    // This will be set by the Bar to the current screen's monitor
    required property var monitor
    property int textVerticalOffset: 0
    
    spacing: 0
    height: 20

    WorkspacesWidget {
        id: workspacesWidget
        monitor: root.monitor
    }

    property var filteredWorkspaces: workspacesWidget.workspaces

    Repeater {
        model: root.filteredWorkspaces

        delegate: Rectangle {
            required property var modelData

            width: wsText.implicitWidth + 24
            height: 20
            radius: 0
            color: modelData.focused ? Theme.wm800 : "transparent"

            Text {
                id: wsText
                anchors.centerIn: parent; anchors.verticalCenterOffset: root.textVerticalOffset
                text: modelData.name
                font.pointSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
                font.weight: Font.Bold
                color: modelData.focused ? Theme.app150 : Theme.app600
            }

            MouseArea {
                anchors.fill: parent
                onClicked: workspacesWidget.switchToWorkspace(modelData.name)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}