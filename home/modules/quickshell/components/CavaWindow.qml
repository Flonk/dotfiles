// CavaWindow.qml - Standalone Cava visualizer window
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import CavaPlugin

PanelWindow {
  required property var screenInfo
  required property var appController
  screen: screenInfo

  anchors {
    bottom: true
  }

  WlrLayershell.layer: WlrLayer.Top
  exclusionMode: ExclusionMode.Ignore

  // Position at bottom center with animated margin
  margins.bottom: appController.isExtended ? appController.extendedOffset : 0

  // Animate margin changes
  Behavior on margins.bottom {
    NumberAnimation {
      duration: 300
      easing.type: Easing.OutCubic
    }
  }

  property int cavaWidth: 214
  property int backdropBorderWidth: 8

  implicitWidth: cavaWidth + (backdropBorderWidth * 2)  // Expand to fit backdrop
  implicitHeight: Theme.barHeight

  // Get the Hyprland monitor for this window's screen
  property var hyprlandMonitor: Hyprland.monitorFor(screen)
  

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
    backdropColor: Theme.app100
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
    systemAudioCompressionFactor: 1.4
    microphoneCompressionFactor: 1.1
    
    // Position the StackedCava explicitly
    anchors.centerIn: parent
    z: 101  // In front of the backdrop
  }

  // Backdrop rectangle behind StackedCava
  Rectangle {
    id: backdrop
    width: parent.width  // Fill the expanded window width
    height: Theme.barHeight
    color: Theme.app900
    radius: 2
    
    // Center in parent window
    anchors.centerIn: parent
    z: 100  // Behind the cavaDisplay
  }
}