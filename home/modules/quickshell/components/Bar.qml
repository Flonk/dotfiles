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
        bottom: true
        left: true
        right: true
      }

      implicitHeight: Theme.barHeight + 2  // Add 2px for the top border
      color: Theme.app150  // bar background
      
      // Top border only
      Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        color: Theme.app200
      }

      // Get the Hyprland monitor for this screen
      property var hyprlandMonitor: Hyprland.monitorFor(modelData)

      // Content area below the border
      Item {
        anchors.top: parent.top
        anchors.topMargin: 2  // Below the 2px border
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        // Left flex container
        Rectangle {
          anchors.left: parent.left
          anchors.leftMargin: 2
          anchors.verticalCenter: parent.verticalCenter
          color: Theme.app200
          
          implicitWidth: leftRow.implicitWidth + 2
          implicitHeight: Theme.barHeight
          
          Row {
            id: leftRow
            anchors.left: parent.left
            anchors.leftMargin: 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2  // 2px spacing between elements

            AppLauncherDisplay {}
            WorkspacesDisplay {
              monitor: hyprlandMonitor
            }
            ActiveWindowDisplay {}
          }
        }

        // Center flex container
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          color: Theme.app200
          
          implicitWidth: centerRow.implicitWidth + 4
          implicitHeight: Theme.barHeight
          
          Row {
            id: centerRow
            anchors.centerIn: parent
            spacing: 2  // 2px spacing between elements

            StackedCavaDisplay {
              id: cavaDisplay
              barCount: 40
              barWidth: 4
              barSpacing: 1
              maxBarHeight: Theme.barHeight
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

            MprisDisplay {}
          }
        }

        // Right flex container
        Rectangle {
          anchors.right: parent.right
          anchors.rightMargin: 2
          anchors.verticalCenter: parent.verticalCenter
          color: Theme.app200
          
          implicitWidth: rightRow.implicitWidth + 2
          implicitHeight: Theme.barHeight
          
          Row {
            id: rightRow
            anchors.right: parent.right
            anchors.rightMargin: 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2  // 2px spacing between elements

            // CPU Display with backdrop
            Rectangle {
              color: Theme.app150
              width: cpuDisplay.width
              height: cpuDisplay.height
              
              CpuDisplay {
                id: cpuDisplay
                barWidth: 4
                barSpacing: 1
                topRadius: 2
                bottomRadius: 2
                maxBarHeight: Theme.barHeight
              }
            }

            // System Bars Display with backdrop
            Rectangle {
              color: Theme.app150
              width: systemBars.width
              height: systemBars.height
              radius: 2
              
              SystemBarsDisplay {
                id: systemBars
              }
            }

            ClockWidget {}
          }
        }
      } // End of content Item
    }
  }
}