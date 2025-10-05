// BarWindow.qml - Main bar panel window
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import CavaPlugin
import ShaderPlugin

PanelWindow {
  required property var screenInfo
  required property var appController
  screen: screenInfo

  anchors {
    bottom: true
    left: true
    right: true
  }

  WlrLayershell.layer: WlrLayer.Bottom

  implicitHeight: Theme.barHeight + 2  // Just bar + border, no extension
  color: Theme.app150  // bar background
  
  // Top border only
  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 2
    color: Theme.app200
  }

  // Get the Hyprland monitor for this window's screen
  property var hyprlandMonitor: Hyprland.monitorFor(screen)
  property int cavaMargin: 10

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
      color: "transparent"
      
      implicitWidth: leftRow.implicitWidth
      implicitHeight: Theme.barHeight
      
      Row {
        id: leftRow
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        AppLauncherDisplay {}
        WorkspacesDisplay {
          monitor: hyprlandMonitor
        }
        ActiveWindowDisplay {}
      }
    }

    // Left of center section - modules with right border only (since cava provides left border)
    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.horizontalCenter
      anchors.rightMargin: cavaDisplay.width / 2 + cavaMargin
      anchors.verticalCenter: parent.verticalCenter
      height: Theme.barHeight
      color: "transparent"
      
      Row {
        id: leftOfCenterRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        layoutDirection: Qt.RightToLeft
        spacing: 0
        
        // Cava toggle button
        Rectangle {
          width: Theme.barHeight / 1.5
          height: Theme.barHeight / 1.5
          color: appController.isExtended ? Theme.wm400 : Theme.app200
          radius: Theme.barHeight
          
          // Animated color transition
          Behavior on color {
            ColorAnimation {
              duration: 200
              easing.type: Easing.OutCubic
            }
          }
          
          // Up/down arrow icon
          Text {
            anchors.centerIn: parent
            text: appController.isExtended ? " " : " "
            font.pointSize: Theme.fontSizeSmall
            font.family: Theme.fontFamilyUi
            color: appController.isExtended ? Theme.wm800 : Theme.app600
            
            // Animate text color
            Behavior on color {
              ColorAnimation {
                duration: 300
                easing.type: Easing.OutCubic
              }
            }
          }
          
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: appController.toggle()
          }
        }
      }
    }

    // Center container - shader-based cava visualizer with real audio data
    CavaShaderWidget {
      id: cavaShaderDisplay
      width: 300
      height: Theme.barHeight
      systemProvider: CavaWidget
      microphoneProvider: CavaMicrophoneWidget
      fps: 30
      maxBars: 40
      systemAnchor: "center"
      microphoneAnchor: "bottom"
      systemColorLow: Theme.wm400
      systemColorHigh: Theme.wm700
      microphoneColorLow: Theme.app300
      microphoneColorHigh: Theme.app600
      
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
    }
    
    // Right of center section
    Rectangle {
      anchors.left: parent.horizontalCenter
      anchors.leftMargin: cavaShaderDisplay.width / 2 + cavaMargin
      anchors.verticalCenter: parent.verticalCenter
      height: Theme.barHeight
      color: "transparent"
      
      Row {
        id: rightOfCenterRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        MprisDisplay {
          id: mprisDisplay
          anchors.verticalCenter: parent.verticalCenter
        }
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