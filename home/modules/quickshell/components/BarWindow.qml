// BarWindow.qml - Main bar panel window
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import Quickmilk 1.0
import ShaderPlugin 1.0

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

  WlrLayershell.layer: WlrLayer.Bottom

  implicitWidth: Theme.barSize
  color: Theme.app150  // bar background

  // Get the Hyprland monitor for this window's screen
  property var hyprlandMonitor: Hyprland.monitorFor(screen)
  property int cavaMargin: 10
  property int sectionMargin: 0  // Global section margin
  property int sectionRadius: 0  // Global section border radius
  property int sectionHorizontalPadding: 0  // Global section horizontal padding
  property int sectionVerticalPadding: 4  // Global section vertical padding
  property bool sectionClipContent: true
  property color sectionBackgroundColor: "transparent"
  property color sectionTopBorderColor: Theme.app200
  property int sectionTopBorderHeight: 1
  property bool sectionShowTopBorder: true

  // Content area
  Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 1
    color: Theme.app200
    z: 1
  }

  Item {
    anchors.fill: parent
    anchors.leftMargin: 1

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

    // Top of center section - modules with bottom border only (since cava provides top border)
    Rectangle {
      anchors.top: parent.top
      anchors.bottom: centerStack.top
      anchors.bottomMargin: cavaMargin
      anchors.horizontalCenter: parent.horizontalCenter
      width: Theme.barSize
      color: "transparent"
      
      Column {
        id: topOfCenterColumn
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0
        
        Section {
          width: Theme.barSize
          topMargin: sectionMargin
          bottomMargin: sectionMargin
          leftMargin: sectionMargin
          rightMargin: sectionMargin
          radius: sectionRadius
          topPadding: sectionVerticalPadding
          bottomPadding: sectionVerticalPadding
          leftPadding: sectionHorizontalPadding
          rightPadding: sectionHorizontalPadding
          clip: sectionClipContent
          backgroundColor: sectionBackgroundColor
          topBorderColor: sectionTopBorderColor
          topBorderHeight: sectionTopBorderHeight
          showTopBorder: sectionShowTopBorder
          
          MprisDisplay {
            id: mprisDisplay
            width: Theme.barSize - (sectionMargin * 2) - (sectionHorizontalPadding * 2)
          }
        }
      }
    }

    // Center container - stack legacy CAVA (default) with optional shader variant
    Column {
      id: centerStack
      anchors.verticalCenter: parent.verticalCenter
      anchors.right: parent.right
      spacing: cavaMargin
      width: Theme.barSize

      /*/
      CavaShaderWidget {
        id: cavaShaderDisplay
        width: 220
        height: Theme.barSize
        volumeWidget: VolumeWidget
        fps: 30
        maxBars: 40
        systemAnchor: "center"
        microphoneAnchor: "bottom"
        systemColorLow: Theme.wm200
        systemColorHigh: Theme.wm800
        microphoneColorLow: Theme.app100
        microphoneColorHigh: Theme.app600
        backgroundColor: Theme.app150
        volumeBarColor: Theme.success600
      }
      /*/
      Section {
        width: Theme.barSize
        topMargin: sectionMargin
        bottomMargin: sectionMargin
        leftMargin: sectionMargin
        rightMargin: sectionMargin
        radius: sectionRadius
        topPadding: sectionVerticalPadding
        bottomPadding: sectionVerticalPadding
        leftPadding: sectionHorizontalPadding
        rightPadding: sectionHorizontalPadding
        clip: sectionClipContent
        backgroundColor: sectionBackgroundColor
        topBorderColor: sectionTopBorderColor
        topBorderHeight: sectionTopBorderHeight
        showTopBorder: sectionShowTopBorder
        
        CavaLegacyShaderWidget {
          id: legacyCavaDisplay
          width: Theme.barSize - (sectionMargin * 2) - (sectionHorizontalPadding * 2)
          height: 220
          volumeWidget: VolumeWidget
          fps: 30
          maxBars: 40
          systemAnchor: "center"
          microphoneAnchor: "bottom"
          systemColorLow: Theme.wm200
          systemColorHigh: Theme.wm800
          microphoneColorLow: Theme.app100
          microphoneColorHigh: Theme.app600
          backgroundColor: Theme.app150
          volumeBarColor: Theme.success600
          monstercatFilter: true
        }
      }
      //*/
    }

    // Bottom of center section
    Rectangle {
      anchors.top: centerStack.bottom
      anchors.topMargin: cavaMargin
      anchors.horizontalCenter: parent.horizontalCenter
      width: Theme.barSize
      color: "transparent"
      
      Column {
        id: bottomOfCenterColumn
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0
      }
    }

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