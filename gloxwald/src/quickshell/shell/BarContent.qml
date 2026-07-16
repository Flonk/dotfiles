// BarContent.qml - Reusable bar content used by both BarWindow and LockSurface
import QtQuick
import Quickshell

Item {
  id: bar

  // Optional: set to a Hyprland monitor to show workspaces
  property var monitor: null
  // Toggle sections that don't apply on the lockscreen
  property bool showWorkspaces: true
  property bool showWifi: true
  property bool interactive: true
  property string authorText: ""
  property bool lockscreen: false

  height: 20

  // Theme colors (derived from singletons)
  property int textVerticalOffset: 1
  property color textColor: Qt.rgba(Theme.app600.r * 0.55, Theme.app600.g * 0.55, Theme.app600.b * 0.55, 1.0)
  property color iconColor: Qt.rgba(Theme.app600.r * 0.8, Theme.app600.g * 0.8, Theme.app600.b * 0.8, 1.0)
  property color wifiIconColor: Qt.rgba(Theme.app600.r * 0.9, Theme.app600.g * 0.9, Theme.app600.b * 0.9, 1.0)
  property color wifiSpeedColor: Qt.rgba(Theme.app600.r * 0.65, Theme.app600.g * 0.65, Theme.app600.b * 0.65, 1.0)
  property color wifiIpColor: Qt.rgba(Theme.app600.r * 0.45, Theme.app600.g * 0.45, Theme.app600.b * 0.45, 1.0)
  property color warningColor: "#FFA500"
  property color errorColor: Theme.error400
  property color chargingColor: Theme.success600
  property int gloxwaldGap: 60
  property bool wifiWarningActive: WifiWidget.isHighTraffic

  Connections {
    target: WifiWidget
    function onIsHighTrafficChanged() {
      bar.wifiWarningActive = WifiWidget.isHighTraffic;
    }
  }

  // Black fill across full bar
  Rectangle {
    anchors.fill: parent
    color: "#000000"
  }

  // GLOXWALD glow color (shifts toward wm800 on hover)
  property color glowColor: appLauncher.hovered
      ? Qt.rgba(Theme.wm800.r * 0.3 + Theme.app200.r * 0.7, Theme.wm800.g * 0.3 + Theme.app200.g * 0.7, Theme.wm800.b * 0.3 + Theme.app200.b * 0.7, 1.0)
      : Theme.app200
  property real glowAlpha: appLauncher.hovered ? 0.95 : 0.9

  Behavior on glowColor { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

  // GLOXWALD horizontal outer glow (left)
  Item {
    x: centerSection.x - 60
    y: centerSection.y
    width: 60
    height: centerSection.height
    clip: true
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Qt.rgba(bar.glowColor.r, bar.glowColor.g, bar.glowColor.b, 0.0) }
        GradientStop { position: 1.0; color: Qt.rgba(bar.glowColor.r, bar.glowColor.g, bar.glowColor.b, bar.glowAlpha) }
      }
    }
    Image {
      anchors.fill: parent
      source: "assets/noise-tile.png"
      fillMode: Image.Tile
      opacity: 0.12
    }
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "#000000" }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }
  }
  // GLOXWALD horizontal outer glow (right)
  Item {
    x: centerSection.x + centerSection.width
    y: centerSection.y
    width: 60
    height: centerSection.height
    clip: true
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Qt.rgba(bar.glowColor.r, bar.glowColor.g, bar.glowColor.b, bar.glowAlpha) }
        GradientStop { position: 1.0; color: Qt.rgba(bar.glowColor.r, bar.glowColor.g, bar.glowColor.b, 0.0) }
      }
    }
    Item {
      anchors.fill: parent
      clip: true
      Image {
        x: -(centerSection.width % 64)
        y: 0
        width: parent.width + 64
        height: parent.height
        source: "assets/noise-tile.png"
        fillMode: Image.Tile
        opacity: 0.12
      }
    }
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 1.0; color: "#000000" }
      }
    }
  }

  // CENTER - GLOXWALD logo
  Section {
    id: centerSection
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    width: appLauncher.width
    topPadding: 0; bottomPadding: 0; leftPadding: 0; rightPadding: 0
    topMargin: 0; bottomMargin: 0; leftMargin: 0; rightMargin: 0
    backgroundColor: Qt.rgba(Theme.app200.r, Theme.app200.g, Theme.app200.b, 0.2)
    showTopBorder: false
    glassEffect: true
    AppLauncherDisplay { id: appLauncher }
  }

  // GLOXWALD 1px black vertical borders
  Rectangle { x: centerSection.x; y: centerSection.y; width: 1; height: centerSection.height; color: "#000000" }
  Rectangle { x: centerSection.x + centerSection.width - 1; y: centerSection.y; width: 1; height: centerSection.height; color: "#000000" }

  // Noise overlay on GLOXWALD section
  Image {
    anchors.fill: centerSection
    source: "assets/noise-tile.png"
    fillMode: Image.Tile
    opacity: 0.15
  }

  // LEFT OF CENTER - dsk, mem, cpu
  Row {
    id: leftOfCenterRow
    visible: !bar.lockscreen
    anchors.right: centerSection.left
    anchors.rightMargin: bar.gloxwaldGap + 8
    anchors.top: parent.top
    spacing: 0
    layoutDirection: Qt.RightToLeft

    // CPU
    Section {
      width: cpuText.implicitWidth + cpuBars.width + 12
      topPadding: 0; bottomPadding: 0
      backgroundColor: Qt.rgba(Theme.app200.r, Theme.app200.g, Theme.app200.b, 0.2)
      showTopBorder: false
      glassEffect: false

      Item {
        width: parent.width; height: 20

        Text {
          id: cpuText
          anchors.left: parent.left; anchors.leftMargin: 4
          anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: bar.textVerticalOffset
          text: "CPU " + Math.round(SystemMonitor.cpuUsage * 100)
          font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall; font.weight: Font.Bold
          color: SystemMonitor.cpuUsage > 0.8 ? bar.warningColor : bar.iconColor
        }

        Row {
          id: cpuBars
          anchors.right: parent.right; anchors.rightMargin: 4
          anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: bar.textVerticalOffset
          height: 16; spacing: 1

          Repeater {
            model: Math.max(1, SystemMonitor.coreCount)
            Rectangle {
              width: 2
              anchors.bottom: parent.bottom
              height: Math.max(1, parent.height * Math.max(0, Math.min(1, SystemMonitor.coreUsages[index] || 0)))
              color: (SystemMonitor.coreUsages[index] || 0) > 0.8 ? bar.errorColor : bar.textColor
            }
          }
        }
      }
    }

    // MEMORY
    Section {
      width: memoryText.implicitWidth + 8
      topPadding: 0; bottomPadding: 0
      backgroundColor: Qt.rgba(Theme.app200.r, Theme.app200.g, Theme.app200.b, 0.2)
      showTopBorder: false
      glassEffect: false

      Item {
        width: parent.width; height: 20
        Text {
          id: memoryText
          anchors.centerIn: parent; anchors.verticalCenterOffset: bar.textVerticalOffset
          text: "MEM " + Math.round(SystemMonitor.memoryUsage * 100)
          font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall; font.weight: Font.Bold
          color: SystemMonitor.memoryUsage > 0.8 ? bar.warningColor : bar.iconColor
        }
      }
    }

    // DISK
    Section {
      width: diskText.implicitWidth + 8
      topPadding: 0; bottomPadding: 0
      backgroundColor: Qt.rgba(Theme.app200.r, Theme.app200.g, Theme.app200.b, 0.2)
      showTopBorder: false
      glassEffect: false

      Item {
        width: parent.width; height: 20
        Text {
          id: diskText
          anchors.centerIn: parent; anchors.verticalCenterOffset: bar.textVerticalOffset
          text: "DSK " + Math.round(SystemMonitor.diskUsage * 100)
          font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall; font.weight: Font.Bold
          color: SystemMonitor.diskUsage > 0.8 ? bar.warningColor : bar.iconColor
        }
      }
    }
  }

  // RIGHT OF CENTER - media
  Row {
    id: rightOfCenterRow
    visible: !bar.lockscreen
    anchors.left: centerSection.right
    anchors.leftMargin: bar.gloxwaldGap
    anchors.top: parent.top
    spacing: 0

    Section {
      width: 270
      topPadding: 0; bottomPadding: 0; leftPadding: 1; rightPadding: 1
      backgroundColor: Qt.rgba(Theme.app200.r, Theme.app200.g, Theme.app200.b, 0.2)
      showTopBorder: false
      glassEffect: false
      clip: false

      MediaControlDisplay {
        width: 268
        textColor: bar.textColor
        iconColor: bar.iconColor
        textVerticalOffset: bar.textVerticalOffset
      }
    }
  }

  // LEFT - workspace, wifi
  Row {
    id: leftRow
    anchors.left: parent.left
    anchors.top: parent.top
    spacing: 0

    WorkspacesDisplay {
      visible: bar.showWorkspaces && bar.monitor !== null
      monitor: bar.monitor
      textVerticalOffset: bar.textVerticalOffset
    }

    Item { width: 6; height: 20; visible: bar.showWorkspaces }

    // Author credit shown on lockscreen
    Section {
      visible: bar.authorText !== ""
      width: authorLabel.implicitWidth + 10
      topPadding: 0; bottomPadding: 0
      backgroundColor: Qt.rgba(Theme.app200.r, Theme.app200.g, Theme.app200.b, 0.2)
      showTopBorder: false
      glassEffect: false

      Item {
        width: parent.width; height: 20
        Text {
          id: authorLabel
          anchors.centerIn: parent; anchors.verticalCenterOffset: bar.textVerticalOffset
          text: bar.authorText
          font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall; font.weight: Font.Bold
          color: bar.textColor
        }
      }
    }

    // WIFI
    Section {
      id: wifiSection
      visible: bar.showWifi && !bar.lockscreen
      width: wifiDisplay.implicitWidth + 26
      topPadding: 0; bottomPadding: 0
      backgroundColor: Qt.rgba(Theme.app200.r, Theme.app200.g, Theme.app200.b, 0.2)
      showTopBorder: false
      glassEffect: false

      Item {
        width: wifiDisplay.implicitWidth + 18; height: 20

        WifiDisplay {
          id: wifiDisplay
          anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: bar.textVerticalOffset
          anchors.left: parent.left; anchors.leftMargin: 12
          wifiIconColor: bar.wifiIconColor
          arrowIconColor: bar.iconColor
          speedColor: bar.wifiSpeedColor
          ipColor: bar.wifiIpColor
          ipHoverColor: bar.wifiIconColor
          warningColor: bar.warningColor
          wifiWarningActive: bar.wifiWarningActive
          textVerticalOffset: bar.textVerticalOffset
        }
      }
    }
  }

  // RIGHT - brt, vol, bat, lock, clock
  Row {
    id: rightRow
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 0

    // BRIGHTNESS
    Section {
      visible: !bar.lockscreen
      width: brightnessText.implicitWidth + 8
      topPadding: 0; bottomPadding: 0
      backgroundColor: "#bda551"
      showTopBorder: false
      glassEffect: false

      Item {
        width: parent.width; height: 20

        Text {
          id: brightnessText
          anchors.centerIn: parent; anchors.verticalCenterOffset: bar.textVerticalOffset
          text: "BRT " + Math.round(BrightnessWidget.brightness * 100)
          font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall; font.weight: Font.Bold
          color: "#000000"
        }

        MouseArea {
          enabled: bar.interactive
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onWheel: function(wheel) {
            const delta = wheel.angleDelta.y > 0 ? 0.01 : -0.01;
            BrightnessWidget.setBrightness(Math.max(0, Math.min(1, BrightnessWidget.brightness + delta)));
          }
        }
      }
    }

    // VOLUME
    Section {
      visible: !bar.lockscreen
      width: volumeText.implicitWidth + 8
      topPadding: 0; bottomPadding: 0
      backgroundColor: "#7493a3"
      showTopBorder: false
      glassEffect: false

      Item {
        width: parent.width; height: 20

        Text {
          id: volumeText
          anchors.centerIn: parent; anchors.verticalCenterOffset: bar.textVerticalOffset
          text: "VOL " + Math.round(VolumeWidget.volume * 100)
          font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall; font.weight: Font.Bold
          color: VolumeWidget.muted ? bar.warningColor : "#000000"
        }

        MouseArea {
          enabled: bar.interactive
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) VolumeWidget.toggleMute();
          }
          onWheel: function(wheel) {
            const delta = wheel.angleDelta.y > 0 ? 0.01 : -0.01;
            VolumeWidget.setVolume(Math.max(0, Math.min(1, VolumeWidget.volume + delta)));
          }
        }
      }
    }

    // BATTERY
    Section {
      width: batteryText.implicitWidth + 8
      topPadding: 0; bottomPadding: 0
      backgroundColor: {
        if (!SystemMonitor.hasBattery) return bar.chargingColor;
        const colorState = SystemMonitor.getBatteryColorState();
        if (colorState === "charging") return bar.chargingColor;
        if (colorState === "critical") return bar.errorColor;
        return bar.warningColor;
      }
      showTopBorder: false
      glassEffect: false

      Item {
        width: parent.width; height: 20

        Text {
          id: batteryText
          anchors.centerIn: parent; anchors.verticalCenterOffset: bar.textVerticalOffset
          text: "BAT " + Math.round(SystemMonitor.batteryLevel * 100)
          font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall; font.weight: Font.Bold
          color: "#000000"
        }
      }
    }

    // CLOCK
    Section {
      width: clockText.implicitWidth + 34
      topPadding: 0; bottomPadding: 0
      leftPadding: 18; rightPadding: 16
      backgroundColor: Qt.rgba(Theme.app200.r, Theme.app200.g, Theme.app200.b, 0.2)
      showTopBorder: false
      glassEffect: false

      Item {
        width: parent.width; height: 20

        Text {
          id: clockText
          anchors.centerIn: parent; anchors.verticalCenterOffset: bar.textVerticalOffset
          text: Qt.formatDateTime(new Date(), "dd.MM. hh:mm:ss")
          font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall; font.weight: Font.Bold
          color: bar.textColor
        }

        Timer {
          interval: 1000
          running: true
          repeat: true
          onTriggered: clockText.text = Qt.formatDateTime(new Date(), "dd.MM. hh:mm:ss")
        }

        MouseArea {
          enabled: bar.interactive
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            const iso = new Date().toISOString();
            Quickshell.execDetached(["sh", "-c", "echo -n '" + iso + "' | wl-copy && notify-send '\uD83D\uDD52 Timestamp copied!' '" + iso + " was copied to the clipboard'"]);
          }
        }
      }
    }

    // LANGUAGE
    Section {
      id: langSection
      visible: !bar.lockscreen && LanguageWidget.available
      width: langText.implicitWidth + 24
      topPadding: 0; bottomPadding: 0
      backgroundColor: langMouse.containsMouse ? "#7493a3" : Theme.app150
      showTopBorder: false
      glassEffect: false
      clip: true

      Item {
        width: parent.width; height: 20

        Text {
          id: langText
          anchors.centerIn: parent; anchors.verticalCenterOffset: bar.textVerticalOffset
          text: LanguageWidget.label
          font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall; font.weight: Font.Bold
          color: langMouse.containsMouse ? Theme.app100 : bar.textColor
        }

        MouseArea {
          id: langMouse
          enabled: bar.interactive
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: LanguageWidget.cycle()
        }
      }
    }

    // HOW2GLOXWALD
    Section {
      id: h2sSection
      visible: !bar.lockscreen
      width: h2sText.implicitWidth + 24
      topPadding: 0; bottomPadding: 0
      backgroundColor: h2sMouse.containsMouse || How2GloxwaldWidget.visible ? Theme.wm800 : Theme.app150
      showTopBorder: false
      glassEffect: false
      clip: true

      Item {
        width: parent.width; height: 20

        Text {
          id: h2sText
          anchors.centerIn: parent; anchors.verticalCenterOffset: bar.textVerticalOffset
          text: "HELP"
          font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall; font.weight: Font.Bold
          color: h2sMouse.containsMouse || How2GloxwaldWidget.visible ? Theme.app100 : bar.textColor
        }

        MouseArea {
          id: h2sMouse
          enabled: bar.interactive
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: How2GloxwaldWidget.toggle()
        }
      }
    }
  }
}
