import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
  id: window
  required property var screenInfo
  screen: screenInfo

  WlrLayershell.layer: WlrLayer.Top
  exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    left: true
  }
  margins.top: 48
  margins.left: 48

  implicitWidth: 500
  implicitHeight: 500
  color: "transparent"

  Rectangle {
    anchors.fill: parent
    radius: 16
    color: Qt.rgba(0.04, 0.04, 0.06, 0.75)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1

    Text {
      anchors.centerIn: parent
      text: "Visualizer disabled"
      font.pixelSize: 20
      color: Theme.app50
    }
  }
}
