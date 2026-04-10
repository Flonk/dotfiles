// BarWindow.qml - Main bar panel window
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
  id: barWindow
  required property var screenInfo
  required property var appController
  screen: screenInfo

  anchors {
    right: true
    top: true
    bottom: true
  }

  WlrLayershell.layer: WlrLayer.Top

  implicitWidth: Theme.barSize
  color: Theme.app200

  // Get the Hyprland monitor for this window's screen
  property var hyprlandMonitor: Hyprland.monitorFor(screen)
  property int cavaMargin: 10
  property int sectionMargin: 2  // Global section margin
  property int sectionRadius: 3  // Global section border radius
  property int sectionHorizontalPadding: 0  // Global section horizontal padding
  property int sectionVerticalPadding: 4  // Global section vertical padding
  property bool sectionClipContent: true
  property color sectionBackgroundColor: Theme.app200
  property color sectionTopBorderColor: Theme.app200
  property int sectionTopBorderHeight: 1
  property bool sectionShowTopBorder: true

  // Content area
  Image {
    anchors.fill: parent
    source: Theme.logoTileGrey
    fillMode: Image.Tile
    opacity: 1.0
    z: 0
  }

  // Left border - dark outer + light inner
  Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 1
    color: Qt.rgba(0, 0, 0, 1)
    z: 1
  }
  Rectangle {
    anchors.left: parent.left
    anchors.leftMargin: 1
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 1
    color: Qt.rgba(1, 1, 1, 0.2)
    z: 1
  }

  Item {
    anchors.fill: parent
    anchors.leftMargin: 3

    // Top flex container
    Rectangle {
      anchors.top: parent.top
      anchors.topMargin: 2
      anchors.horizontalCenter: parent.horizontalCenter
      color: "transparent"
      
      implicitWidth: Theme.barSize
      implicitHeight: topColumn.implicitHeight
      
      Column {
        id: topColumn
        anchors.top: parent.top
        anchors.topMargin: 0
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 5

        AppLauncherDisplay {}
        WorkspacesDisplay {
          monitor: hyprlandMonitor
        }
      }
    }

    // (CAVA visualizer section removed)

    // Bottom flex container
    Item {
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 2
      anchors.horizontalCenter: parent.horizontalCenter
      
      implicitWidth: Theme.barSize
      implicitHeight: bottomColumn.implicitHeight
      
      Column {
        id: bottomColumn
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: barWindow.sectionMargin

        SystemBarsDisplay {
          id: systemBars
          sectionMargin: barWindow.sectionMargin
          sectionRadius: barWindow.sectionRadius
          sectionVerticalPadding: barWindow.sectionVerticalPadding
          sectionHorizontalPadding: barWindow.sectionHorizontalPadding
          sectionClip: barWindow.sectionClipContent
          sectionBackgroundColor: barWindow.sectionBackgroundColor
          sectionTopBorderColor: barWindow.sectionTopBorderColor
          sectionTopBorderHeight: barWindow.sectionTopBorderHeight
          sectionShowTopBorder: barWindow.sectionShowTopBorder
        }
      }
    }
  } // End of content Item
}