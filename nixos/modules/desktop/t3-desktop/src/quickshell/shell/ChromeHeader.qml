import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root
    property var monitor: null
    property vector2d screenSize: Qt.vector2d(width, height)
    property bool interactive: true

    readonly property real center: width / 2
    readonly property vector4d cutout: coreMeter.cutout
    readonly property real markGap: T3.markSize / 2 + 24
    property real markScale: markMouse.containsMouse ? 1.15 : 1
    Behavior on markScale {
        NumberAnimation { duration: 150 }
    }
    readonly property real markSize: T3.markSize * markScale

    readonly property var workspaces: (Hyprland.workspaces?.values ?? [])
        .filter(w => w?.monitor && root.monitor && w.monitor.name === root.monitor.name)
        .sort((a, b) => {
            const x = parseInt(a.name), y = parseInt(b.name);
            return isNaN(x) || isNaN(y) ? a.name.localeCompare(b.name) : x - y;
        })

    component Label: Text {
        height: T3.band
        verticalAlignment: Text.AlignVCenter
        color: T3.ink
        font.family: Theme.fontFamily
        font.pixelSize: T3.labelSize
        font.weight: Font.Bold
        font.letterSpacing: T3.labelTracking
        font.capitalization: Font.AllUppercase
    }

    component Status: Label {
        id: status
        property bool clickable: false
        property int buttons: Qt.LeftButton
        signal clicked(var mouse)
        signal scrolled(int direction)
        opacity: hover.containsMouse ? 1 : 0.8
        scale: hover.containsMouse && clickable ? 1.15 : 1
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
        Behavior on scale {
            NumberAnimation { duration: 150 }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.interactive
            acceptedButtons: status.clickable ? status.buttons : Qt.NoButton
            cursorShape: status.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: m => status.clicked(m)
            onWheel: w => status.scrolled(w.angleDelta.y > 0 ? 1 : -1)
        }
    }

    component Copy: Status {
        property string value
        property string title
        text: value || "--"
        clickable: value !== ""
        onClicked: Clipboard.copy(value, title)
    }

    ChromeSurface {
        anchors.fill: parent
        screenSize: root.screenSize
        cutout: root.cutout
        markRect: Qt.vector4d(root.center - root.markSize / 2, (root.height - root.markSize) / 2, root.markSize, root.markSize)
    }

    MouseArea {
        id: markMouse
        x: root.center - T3.markSize / 2 - 8
        width: T3.markSize + 16
        height: parent.height
        hoverEnabled: true
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["vicinae", "open"])
    }

    Row {
        x: 16
        spacing: 16

        Row {
            spacing: 2

            Repeater {
                model: root.workspaces

                Item {
                    id: ws
                    required property var modelData
                    readonly property bool focused: modelData.focused
                    width: wsLabel.implicitWidth + 16
                    height: T3.band

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: 20
                        radius: 10
                        color: ws.focused ? T3.ink : "transparent"
                    }

                    Label {
                        id: wsLabel
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ws.modelData.name
                        color: ws.focused ? T3.accent2 : T3.ink
                        opacity: ws.focused || wsMouse.containsMouse ? 1 : 0.6
                    }

                    MouseArea {
                        id: wsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.interactive
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${ws.modelData.name} })`)
                    }
                }
            }
        }

        Row {
            spacing: 10

            Status {
                text: (WifiWidget.isConnected ? "" : "") + "  ↑" + WifiWidget.formatRate(WifiWidget.uploadRate) + " ↓" + WifiWidget.formatRate(WifiWidget.downloadRate)
                clickable: true
                onClicked: WifiWidget.openCommander()
            }

            Copy {
                value: WifiWidget.localIp
                title: "🏠 Local IP copied!"
            }

            Copy {
                value: WifiWidget.gatewayIp
                title: "🚪 Gateway IP copied!"
            }

            Copy {
                value: WifiWidget.publicIp
                title: "🌐 Public IP copied!"
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: root.width - root.center + root.markGap
        spacing: 16

        Status {
            text: "DSK " + Math.round(SystemMonitor.diskUsage * 100)
        }

        Status {
            text: "MEM " + Math.round(SystemMonitor.memoryUsage * 100)
        }

        Row {
            spacing: 8

            Status {
                id: cpuLabel
                text: "CPU " + Math.round(SystemMonitor.cpuUsage * 100)
            }

            CoreMeter {
                id: coreMeter
                frame: root
                values: SystemMonitor.coreUsages
            }
        }
    }

    Item {
        visible: MediaControlWidget.currentPlayer !== null
        x: root.center + root.markGap
        width: 270
        height: root.height
        opacity: mediaMouse.containsMouse ? 1 : 0.8

        Label {
            id: mediaIcon
            text: MediaControlWidget.isPlaying ? "" : ""
        }

        MarqueeText {
            anchors { left: mediaIcon.right; leftMargin: 8; right: parent.right; verticalCenter: parent.verticalCenter }
            text: [MediaControlWidget.currentArtist, MediaControlWidget.currentTitle].filter(s => s).join(" - ")
            font.family: Theme.fontFamily
            font.pixelSize: T3.labelSize
            font.weight: Font.Bold
            font.letterSpacing: T3.labelTracking
            font.capitalization: Font.AllUppercase
            textColor: T3.ink
            scrolling: MediaControlWidget.isPlaying
        }

        MouseArea {
            id: mediaMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.interactive
            cursorShape: Qt.PointingHandCursor
            onClicked: MediaControlWidget.togglePlaying()
            onWheel: w => w.angleDelta.y > 0 ? MediaControlWidget.previous() : MediaControlWidget.next()
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 16
        spacing: 16

        AgentBars {}

        Status {
            text: ({ busy: "HEADPHONES ..", ok: "HEADPHONES ✓", fail: "HEADPHONES ✗" })[HeadphonesWidget.status] ?? "HEADPHONES"
            clickable: !HeadphonesWidget.busy
            onClicked: HeadphonesWidget.reconnect()
        }

        Row {
            spacing: 0

            Meter {
                icon: "\u{f00df}"
                color: "#c6932e"
                value: BrightnessWidget.brightness
                interactive: root.interactive
                onScrolled: d => BrightnessWidget.setBrightness(BrightnessWidget.brightness + d * 0.01)
            }

            Meter {
                icon: VolumeWidget.muted ? "\u{f0581}" : "\u{f057e}"
                color: Theme.wm800
                value: VolumeWidget.volume
                muted: VolumeWidget.muted
                interactive: root.interactive
                buttons: Qt.RightButton
                onClicked: VolumeWidget.toggleMute()
                onScrolled: d => VolumeWidget.setVolume(VolumeWidget.volume + d * 0.01)
            }

            Meter {
                visible: SystemMonitor.hasBattery
                icon: SystemMonitor.isCharging ? "\u{f0084}" : SystemMonitor.batteryState === "critical" ? "\u{f0083}" : "\u{f0079}"
                color: "#66b16a"
                value: SystemMonitor.batteryLevel
                critical: !SystemMonitor.isCharging && SystemMonitor.batteryState === "critical"
                interactive: root.interactive
            }
        }

        Status {
            text: Qt.formatDateTime(clock.now, "dd.MM. hh:mm")
            clickable: true
            onClicked: Clipboard.copy(new Date().toISOString(), "🕒 Timestamp copied!")

            Timer {
                id: clock
                property date now: new Date()
                interval: 1000
                running: true
                repeat: true
                onTriggered: now = new Date()
            }
        }

        Status {
            visible: LanguageWidget.available
            text: LanguageWidget.label
            clickable: true
            onClicked: LanguageWidget.cycle()
        }
    }
}
