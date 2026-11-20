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
    readonly property bool on: info !== null && info.on
    property real px: 0
    property real py: 0
    property bool settled: false

    function place() {
        if (!info)
            return;
        if (info.x !== px || info.y !== py) {
            settled = false;
            px = info.x;
            py = info.y;
        }
        settle.restart();
    }

    onInfoChanged: place()
    Component.onCompleted: place()

    Timer {
        id: settle
        interval: 220
        onTriggered: root.settled = true
    }

    anchors.left: isLeft
    anchors.right: !isLeft
    anchors.top: isTop
    anchors.bottom: !isTop
    margins.left: isLeft ? px : 0
    margins.right: !isLeft ? monitor.width - px : 0
    margins.top: isTop ? py : 0
    margins.bottom: !isTop ? monitor.height - py : 0
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: T3.windowRadius
    implicitHeight: T3.windowRadius
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "gloxwald-corner"

    CornerWedge {
        anchors.centerIn: parent
        visible: root.on && root.settled
        corner: root.corner
        line: root.info?.tab ? "transparent" : root.info?.active ? Theme.wm800 : "black"
    }
}
