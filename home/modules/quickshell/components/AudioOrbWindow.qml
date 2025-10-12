import Quickshell
import Quickshell.Wayland
import QtQuick
import ShaderPlugin 1.0

PanelWindow {
  id: window
  required property var screenInfo
  screen: screenInfo

  WlrLayershell.layer: WlrLayer.Top
  exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    right: true
  }
  margins.top: 48
  margins.right: 48

  implicitWidth: 320
  implicitHeight: 320
  color: "transparent"

  Rectangle {
    anchors.fill: parent
    radius: 16
    color: Qt.rgba(0.04, 0.04, 0.06, 0.75)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1

    AudioShaderWidget {
      anchors.fill: parent
      anchors.margins: 12
    }
  }
}
