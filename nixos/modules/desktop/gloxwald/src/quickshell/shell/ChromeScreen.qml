import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: root
    required property var modelData
    readonly property vector2d screenSize: Qt.vector2d(modelData.width, modelData.height)

    component Reserve: PanelWindow {
        screen: root.modelData
        color: "transparent"
        implicitWidth: 1
        implicitHeight: 1
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "gloxwald-chrome-reserve"
    }

    Reserve {
        anchors { top: true; left: true; right: true }
        exclusiveZone: T3.band
    }

    Reserve {
        anchors { left: true; top: true; bottom: true }
        exclusiveZone: T3.border
    }

    Reserve {
        anchors { right: true; top: true; bottom: true }
        exclusiveZone: T3.border
    }

    Reserve {
        anchors { bottom: true; left: true; right: true }
        exclusiveZone: T3.border
    }

    PanelWindow {
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "gloxwald-chrome"

        ChromeSurface {
            anchors.fill: parent
            screenSize: root.screenSize
        }
    }

    PanelWindow {
        screen: root.modelData
        anchors { top: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        implicitHeight: T3.band
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "gloxwald-header"

        ChromeHeader {
            anchors.fill: parent
            screenSize: root.screenSize
            monitor: Hyprland.monitorFor(root.modelData)
        }
    }
}
