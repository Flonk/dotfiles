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

  // No window-level margin - let the backdrop create the drawer effect
  margins.bottom: 0

  property int cavaWidth: 214
  property int backdropBorderWidth: 8

  implicitWidth: cavaWidth + (backdropBorderWidth * 2)  // Expand to fit backdrop
  implicitHeight: appController.isExtended ? (Theme.barHeight + appController.extendedOffset) : Theme.barHeight
  
  // Animate window height changes
  Behavior on implicitHeight {
    NumberAnimation {
      duration: 300
      easing.type: Easing.OutCubic
    }
  }

  // Get the Hyprland monitor for this window's screen
  property var hyprlandMonitor: Hyprland.monitorFor(screen)

  // Backdrop rectangle behind StackedCava - extends like a drawer
  Rectangle {
    id: backdrop
    width: parent.width
    height: appController.isExtended ? parent.height : Theme.barHeight
    color: Theme.app900
    
    // In retracted state: no top border (radius only on top)
    // In extended state: top border visible (radius on top)
    topLeftRadius: appController.isExtended ? 2 : 0
    topRightRadius: appController.isExtended ? 2 : 0
    bottomLeftRadius: 0
    bottomRightRadius: 0
    
    // Always anchor to bottom of window
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    
    // Animate backdrop height changes
    Behavior on height {
      NumberAnimation {
        duration: 300
        easing.type: Easing.OutCubic
      }
    }
    
    Behavior on topLeftRadius {
      NumberAnimation { duration: 300 }
    }
    
    Behavior on topRightRadius {
      NumberAnimation { duration: 300 }
    }
    
    z: 100  // Behind the cavaDisplay
  }

  // Position StackedCava - moves up when extended
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
    
    // Move up when extended - but 8px less than backdrop to show top border
    anchors.bottom: parent.bottom
    anchors.bottomMargin: appController.isExtended ? (appController.extendedOffset - backdropBorderWidth) : 0
    anchors.horizontalCenter: parent.horizontalCenter
    
    // Animate StackedCava movement
    Behavior on anchors.bottomMargin {
      NumberAnimation {
        duration: 300
        easing.type: Easing.OutCubic
      }
    }
    
    z: 101  // In front of the backdrop
  }
}