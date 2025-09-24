// Bar.qml
import Quickshell
import Quickshell.Hyprland
import QtQuick
import CavaPlugin

Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      anchors {
        top: true
        left: true
        right: true
      }

      implicitHeight: 30
      color: Theme.app150  // bar background

      // Get the Hyprland monitor for this screen
      property var hyprlandMonitor: Hyprland.monitorFor(modelData)

      // Left side - Workspaces, System info and active window
      Row {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 15

        WorkspacesDisplay {
          monitor: hyprlandMonitor
        }
        SystemDisplay {}
        ActiveWindowDisplay {}
        MprisDisplay {}
        CavaDisplay {
          barCount: 20
          maxBarHeight: 18
          barColor: Theme.wm800  // regular bars
        }
        MicrophoneCavaDisplay {
          barCount: 15
          maxBarHeight: 15
          barColor: Theme.app800  // microphone visualizer
        }
      }

      // Right side - Volume, Brightness, Battery, and Clock
      Row {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 15

        VolumeDisplay {}
        BrightnessDisplay {}
        BatteryDisplay {}
        ClockWidget {
          color: Theme.app400  // text color
          font.family: Theme.fontFamilyUiNf  // uiNf font
          font.pointSize: Theme.fontSizeNormal  // normal size
        }
      }
    }
  }
}