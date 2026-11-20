import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    screen: monitor
    required property string corner
    required property var monitor
    readonly property var info: WindowCorners.cornersFor(monitor.name)?.[corner] ?? null
    readonly property bool isLeft: corner === "tl" || corner === "bl"
    readonly property bool isTop: corner === "tl" || corner === "tr"

    visible: info !== null && info.on
    anchors.left: isLeft
    anchors.right: !isLeft
    anchors.top: isTop
    anchors.bottom: !isTop
    margins.left: isLeft && info ? info.x : 0
    margins.right: !isLeft && info ? monitor.width - info.x : 0
    margins.top: isTop && info ? info.y : 0
    margins.bottom: !isTop && info ? monitor.height - info.y : 0
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: T3.windowRadius
    implicitHeight: T3.windowRadius
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "gloxwald-corner"

    CornerWedge {
        anchors.centerIn: parent
        corner: root.corner
        line: root.info?.active ? Theme.wm800 : "black"
    }
}
