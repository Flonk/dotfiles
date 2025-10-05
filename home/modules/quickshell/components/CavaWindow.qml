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
      color: Theme.app200
      radius: borderRadius
      
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      
      z: 2
    }
  }

  Item {
    id: cavaContainer
    width: cavaWidth
    height: appController.isExtended ? (Theme.barHeight + extendedOffset - backdropBorderWidth) : Theme.barHeight
    clip: true
    
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 0
    anchors.horizontalCenter: parent.horizontalCenter
        
    Behavior on height {
      NumberAnimation {
        duration: 300
        easing.type: Easing.OutCubic
      }
    }
    
    z: 2
    
    
  }
}