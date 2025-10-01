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
  margins.bottom: 0

  property int cavaWidth: 214
  property int backdropBorderWidth: 2
  property int borderRadius: 2
  property int extendedOffset: backdropBorderWidth + 20

  implicitWidth: cavaWidth + (backdropBorderWidth * 2)
  implicitHeight: Theme.barHeight + extendedOffset
  color: "transparent"
  
  Behavior on implicitHeight {
    NumberAnimation {
      duration: 300
      easing.type: Easing.OutCubic
    }
  }

  property var hyprlandMonitor: Hyprland.monitorFor(screen)

  Item {
    id: backdropContainer
    width: parent.width
    height: Theme.barHeight + extendedOffset + backdropBorderWidth
    clip: true
    
    anchors.bottom: parent.bottom
    anchors.bottomMargin: appController.isExtended ? -backdropBorderWidth : -(Theme.barHeight + extendedOffset + backdropBorderWidth)
    anchors.horizontalCenter: parent.horizontalCenter
    
    Behavior on anchors.bottomMargin {
      NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    
    z: 1
    
    Rectangle {
      id: backdrop
      width: parent.width
      height: Theme.barHeight + extendedOffset + backdropBorderWidth + borderRadius
      color: Theme.app300
      radius: borderRadius
      
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      
      Behavior on anchors.bottomMargin {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
      }
      z: 2
    }
  }

  Item {
    id: cavaContainer
    width: cavaWidth
    height: appController.isExtended ? (Theme.barHeight + extendedOffset - backdropBorderWidth) : Theme.barHeight
    clip: true
    
    anchors.bottom: parent.bottom
    // Keep the container fully within the window's bounds to avoid PanelWindow clipping the top.
    // When extended, the correct bottomMargin to align the container's top with the window's top is the border width.
    anchors.bottomMargin: appController.isExtended ? backdropBorderWidth : 0
    anchors.horizontalCenter: parent.horizontalCenter
    
    Behavior on anchors.bottomMargin {
      NumberAnimation {
        duration: 300
        easing.type: Easing.OutCubic
      }
    }
    
    Behavior on height {
      NumberAnimation {
        duration: 300
        easing.type: Easing.OutCubic
      }
    }
    
    z: 2
    
    StackedCavaDisplay {
      id: cavaDisplay
      barCount: 40
      barWidth: 4
      barSpacing: 1
      maxBarHeight: appController.isExtended ? (Theme.barHeight + extendedOffset - backdropBorderWidth) : Theme.barHeight
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
      
      width: cavaWidth
      height: maxBarHeight
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      
      Behavior on maxBarHeight {
        NumberAnimation {
          duration: 300
          easing.type: Easing.OutCubic
        }
      }
      
      Behavior on height {
        NumberAnimation {
          duration: 300
          easing.type: Easing.OutCubic
        }
      }
    }
  }
}