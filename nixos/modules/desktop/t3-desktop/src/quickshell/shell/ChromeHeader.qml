import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root
    property var monitor: null
    property vector2d screenSize: Qt.vector2d(width, height)
    property bool interactive: true

    readonly property real center: width / 2
    readonly property vector4d cutout: sysmon.cutout
    readonly property vector4d cutout2: agents.cutout
    readonly property vector4d cutout4: ticker.cutout
    readonly property vector4d cutout3: {
        meters.x; meters.y; meters.width; meters.height; meters.parent?.x; meters.parent?.y; width;
        const p = meters.mapToItem(root, 0, 0);
        return Qt.vector4d(Math.round(p.x), Math.round(p.y), meters.width, meters.height);
    }
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
        cutout2: root.cutout2
        cutout3: root.cutout3
        cutout4: root.cutout4
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

            TextMetrics {
                id: rateMetrics
                font: ipProbe.font
                text: "0000K"
            }

            TextMetrics {
                id: ipMetrics
                font: ipProbe.font
                text: "000.000.000.000"
            }

            Label {
                id: ipProbe
                visible: false
                width: 0
            }

            Status {
                text: (WifiWidget.isConnected ? "" : "")
                font.pixelSize: Math.round(T3.labelSize * 1.2)
                clickable: true
                onClicked: WifiWidget.openCommander()
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: rateMetrics.advanceWidth + 13

                Repeater {
                    model: [[true, WifiWidget.uploadRate], [false, WifiWidget.downloadRate]]

                    Row {
                        required property var modelData
                        spacing: 3
                        anchors.right: parent.right
                        LayoutMirroring.enabled: true

                        Canvas {
                            readonly property bool up: parent.modelData[0]
                            width: 10
                            height: 12
                            opacity: 0.8
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                const tip = up ? 4 : 8, base = up ? 8 : 4;
                                ctx.strokeStyle = T3.ink;
                                ctx.lineWidth = 1.5;
                                ctx.lineCap = "square";
                                ctx.beginPath();
                                ctx.moveTo(1, base);
                                ctx.lineTo(5, tip);
                                ctx.lineTo(9, base);
                                ctx.stroke();
                            }
                        }

                        Status {
                            height: 12
                            text: WifiWidget.formatRate(parent.modelData[1])
                            clickable: true
                            onClicked: WifiWidget.openCommander()
                        }
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: ipMetrics.advanceWidth

                Copy {
                    height: 12
                    width: parent.width
                    elide: Text.ElideRight
                    value: WifiWidget.localIp
                    title: "🏠 Local IP copied!"
                }

                Copy {
                    height: 12
                    width: parent.width
                    elide: Text.ElideRight
                    value: WifiWidget.gatewayIp
                    title: "🚪 Gateway IP copied!"
                }

                Copy {
                    height: 12
                    width: parent.width
                    elide: Text.ElideRight
                    value: WifiWidget.publicIp
                    title: "🌐 Public IP copied!"
                }
            }
        }

        SysmonHole {
            id: sysmon
            frame: root
            values: SystemMonitor.coreUsages
            label: "CPU " + Math.round(SystemMonitor.cpuUsage * 100)
            rings: [
                { label: "MEM", value: SystemMonitor.memoryUsage },
                { label: "DSK", value: SystemMonitor.diskUsage }
            ]
        }

        Item {
            visible: MediaControlWidget.currentPlayer !== null
            width: 270
            height: root.height
            opacity: mediaMouse.containsMouse ? 1 : 0.8

            Label {
                id: mediaIcon
                text: "\u{f001}"
                font.pixelSize: Math.round(T3.labelSize * 1.2)
            }

            Column {
                anchors { left: mediaIcon.right; leftMargin: 8; right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: -1 }

                MarqueeText {
                    text: MediaControlWidget.currentArtist
                    width: parent.width
                    height: 12
                    font.family: Theme.fontFamily
                    font.pixelSize: T3.labelSize
                    font.weight: Font.Bold
                    font.letterSpacing: T3.labelTracking
                    font.capitalization: Font.AllUppercase
                    textColor: T3.ink
                    scrolling: MediaControlWidget.isPlaying
                }

                MarqueeText {
                    text: MediaControlWidget.currentTitle
                    width: parent.width
                    height: 12
                    font.family: Theme.fontFamily
                    font.pixelSize: T3.labelSize
                    font.weight: Font.Bold
                    font.letterSpacing: T3.labelTracking
                    font.capitalization: Font.AllUppercase
                    textColor: T3.ink
                    scrolling: MediaControlWidget.isPlaying
                }
            }

            MouseArea {
                id: mediaMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.interactive
                cursorShape: Qt.PointingHandCursor
                onClicked: MediaControlWidget.togglePlaying()
                onWheel: w => {
                    mediaSkip.direction = w.angleDelta.y;
                    mediaSkip.restart();
                }
            }

            Timer {
                id: mediaSkip
                property int direction: 0
                interval: 150
                onTriggered: direction > 0 ? MediaControlWidget.previous() : MediaControlWidget.next()
            }
        }
    }

    Bbc {
        id: ticker
        frame: root
        join: agents
        x: root.center + root.markGap
        width: Math.max(0, rightRow.x - x)
        height: root.height
    }

    Row {
        id: rightRow
        anchors.right: parent.right
        anchors.rightMargin: 16
        spacing: 16

        BbcHole {
            id: agents
            frame: root
        }

        Row {
            spacing: 10

            Label {
                text: "\u{f025}"
                opacity: 0.8
                font.pixelSize: Math.round(T3.labelSize * 1.2)
            }

            AudioSwitcher {
                anchors.verticalCenter: parent.verticalCenter
                interactive: root.interactive
            }
        }

        Row {
            id: meters
            spacing: 1
            leftPadding: 1
            rightPadding: 1

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

        Column {
            anchors.verticalCenter: parent.verticalCenter

            Status {
                anchors.right: parent.right
                height: 16
                font.pixelSize: Math.round(T3.labelSize * 1.3)
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
                anchors.right: parent.right
                height: 12
                visible: LanguageWidget.available
                text: LanguageWidget.label
                clickable: true
                onClicked: LanguageWidget.cycle()
            }
        }
    }
}
