import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: barWindow
    required property var modelData
    screen: modelData

    anchors {
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Top
    implicitHeight: 20
    color: "transparent"

    BarContent {
        anchors.fill: parent
        monitor: Hyprland.monitorFor(barWindow.screen)
    }
}
