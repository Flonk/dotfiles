import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: root
    required property var modelData
    readonly property vector2d screenSize: Qt.vector2d(modelData.width, modelData.height)
    readonly property int depth: T3.border + T3.radius + 1

    component Reserve: PanelWindow {
        screen: root.modelData
        color: "transparent"
        implicitWidth: 1
        implicitHeight: 1
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "t3-desktop-chrome-reserve"
    }

    component Edge: PanelWindow {
        id: edge
        required property vector2d at
        screen: root.modelData
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "t3-desktop-chrome-edge"

        ChromeSurface {
            anchors.fill: parent
            screenSize: root.screenSize
            origin: edge.at
            overlayMode: 1
        }
    }

    Reserve {
        anchors { top: true; left: true; right: true }
        exclusiveZone: T3.band - T3.windowBorder
    }

    Reserve {
        anchors { left: true; top: true; bottom: true }
        exclusiveZone: T3.border - T3.windowBorder
    }

    Reserve {
        anchors { right: true; top: true; bottom: true }
        exclusiveZone: T3.border - T3.windowBorder
    }

    Reserve {
        anchors { bottom: true; left: true; right: true }
        exclusiveZone: T3.border - T3.windowBorder
    }

    PanelWindow {
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "t3-desktop-chrome"

        ChromeSurface {
            anchors.fill: parent
            screenSize: root.screenSize
        }
    }

    Edge {
        anchors { left: true; top: true; bottom: true }
        implicitWidth: root.depth
        at: Qt.vector2d(0, 0)
    }

    Edge {
        anchors { right: true; top: true; bottom: true }
        implicitWidth: root.depth
        at: Qt.vector2d(root.screenSize.x - root.depth, 0)
    }

    Edge {
        anchors { bottom: true; left: true; right: true }
        implicitHeight: root.depth
        at: Qt.vector2d(0, root.screenSize.y - root.depth)
    }

    Edge {
        anchors { top: true; left: true; right: true }
        margins.top: T3.band
        implicitHeight: T3.radius + 1
        at: Qt.vector2d(0, T3.band)
    }

    PanelWindow {
        screen: root.modelData
        anchors { top: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        implicitHeight: T3.band
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "t3-desktop-header"

        ChromeHeader {
            anchors.fill: parent
            screenSize: root.screenSize
            monitor: Hyprland.monitorFor(root.modelData)
        }
    }
}
