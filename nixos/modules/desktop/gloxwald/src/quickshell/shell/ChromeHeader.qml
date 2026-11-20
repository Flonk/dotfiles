import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
    id: root
    property var monitor: null
    property vector2d screenSize: Qt.vector2d(width, height)
    property bool interactive: true

    readonly property real center: width / 2
    readonly property real markGap: T3.markSize / 2 + 16
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
    readonly property var active: ToplevelManager.activeToplevel
    readonly property string meta: [
        (active?.appId ?? "").split(".").pop(),
        Hyprland.focusedWorkspace ? "ws " + Hyprland.focusedWorkspace.name : ""
    ].filter(s => s).join(" · ")

    component Label: Text {
        height: root.height
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

    ChromeSurface {
        anchors.fill: parent
        screenSize: root.screenSize
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
        id: left
        x: 16
        spacing: 14

        Row {
            spacing: 2

            Repeater {
                model: root.workspaces

                Rectangle {
                    required property var modelData
                    readonly property bool focused: modelData.focused
                    anchors.verticalCenter: parent.verticalCenter
                    width: wsLabel.implicitWidth + 16
                    height: 20
                    radius: 10
                    color: focused ? T3.ink : "transparent"

                    Label {
                        id: wsLabel
                        anchors.centerIn: parent
                        height: 20
                        text: modelData.name
                        color: focused ? T3.accent2 : T3.ink
                        opacity: focused || wsMouse.containsMouse ? 1 : 0.6
                    }

                    MouseArea {
                        id: wsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.interactive
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${modelData.name} })`)
                    }
                }
            }
        }

        Item {
            visible: MediaControlWidget.currentPlayer !== null
            width: 220
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
                font.pixelSize: T3.labelSize + 1
                font.weight: Font.Bold
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
    }

    Label {
        anchors.right: parent.right
        anchors.rightMargin: parent.width - root.center + root.markGap
        width: Math.max(0, Math.min(implicitWidth, root.center - root.markGap - left.x - left.width - 24))
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        text: root.meta
    }

    Text {
        x: root.center + root.markGap
        width: Math.max(0, Math.min(implicitWidth, right.x - x - 24))
        height: root.height
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: root.active?.title ?? ""
        color: T3.ink
        font.family: Theme.fontFamily
        font.pixelSize: T3.titleSize
        font.weight: Font.Bold
    }

    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: 16
        spacing: 16

        Status {
            text: (WifiWidget.isConnected ? "" : "") + "  ↑" + WifiWidget.formatRate(WifiWidget.uploadRate) + " ↓" + WifiWidget.formatRate(WifiWidget.downloadRate)
            clickable: true
            buttons: Qt.LeftButton | Qt.RightButton
            onClicked: m => m.button === Qt.RightButton ? Clipboard.copy(WifiWidget.localIp, "🏠 Local IP copied!") : WifiWidget.openCommander()
        }

        Status {
            text: "CPU " + Math.round(SystemMonitor.cpuUsage * 100)
        }

        Status {
            text: "MEM " + Math.round(SystemMonitor.memoryUsage * 100)
        }

        Status {
            text: "DSK " + Math.round(SystemMonitor.diskUsage * 100)
        }

        Status {
            text: ({ busy: "HEADPHONES ..", ok: "HEADPHONES ✓", fail: "HEADPHONES ✗" })[HeadphonesWidget.status] ?? "HEADPHONES"
            clickable: !HeadphonesWidget.busy
            onClicked: HeadphonesWidget.reconnect()
        }

        Status {
            text: "BRT " + Math.round(BrightnessWidget.brightness * 100)
            clickable: true
            buttons: Qt.NoButton
            onScrolled: d => BrightnessWidget.setBrightness(BrightnessWidget.brightness + d * 0.01)
        }

        Status {
            text: VolumeWidget.muted ? "MUTE" : "VOL " + Math.round(VolumeWidget.volume * 100)
            clickable: true
            buttons: Qt.RightButton
            onClicked: VolumeWidget.toggleMute()
            onScrolled: d => VolumeWidget.setVolume(VolumeWidget.volume + d * 0.01)
        }

        Status {
            visible: SystemMonitor.hasBattery
            text: "BAT " + Math.round(SystemMonitor.batteryLevel * 100) + (SystemMonitor.isCharging ? "+" : SystemMonitor.batteryState === "critical" ? "!" : "")
        }

        Status {
            visible: LanguageWidget.available
            text: LanguageWidget.label
            clickable: true
            onClicked: LanguageWidget.cycle()
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
    }
}
