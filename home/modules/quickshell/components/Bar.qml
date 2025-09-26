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
        StackedCavaDisplay {
          barCount: 40
          barWidth: 4
          barSpacing: 1
          maxBarHeight: 30
          systemAudioColorLow: Theme.wm400
          systemAudioColorHigh: Theme.wm700
          microphoneColorLow: Theme.app300
          microphoneColorHigh: Theme.app400
          backdropColor: Theme.app150
          systemAudioAnchor: "center"
          microphoneAnchor: "top"
          topRadius: 2
          bottomRadius: 2
          backdropRadius: 0
          borderColor: Theme.app200
          borderWidth: 2
          horizontalPadding: 8
          verticalPadding: 2
          noiseReduction: 0.2
          enableMonstercatFilter: true
          volumeSliderColor: Theme.app200
          volumeSliderOpacity: 0.8
          volumeSliderForegroundOpacity: 0.0
          systemAudioCompressionFactor: 1.5
          microphoneCompressionFactor: 0.9
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