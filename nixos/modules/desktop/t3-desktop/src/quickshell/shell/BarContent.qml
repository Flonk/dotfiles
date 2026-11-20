import QtQuick
import Quickshell

Item {
    id: bar
    property var monitor: null
    property bool interactive: true
    property string authorText: ""
    property bool lockscreen: false
    readonly property int gap: 60

    height: 20

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    BarSegment {
        id: launcher
        objectName: "launcher"
        anchors.horizontalCenter: parent.horizontalCenter
        width: 180
        text: "NIXOS ROCKS"
        textColor: "black"
        color: hovered ? Qt.lighter(Theme.launcher, 1.3) : Theme.launcher
        clickable: bar.interactive
        onClicked: Quickshell.execDetached(["vicinae", "open"])
    }

    Row {
        visible: !bar.lockscreen
        anchors.right: launcher.left
        anchors.rightMargin: bar.gap
        layoutDirection: Qt.RightToLeft

        BarSegment {
            objectName: "cpu"
            text: "CPU " + Math.round(SystemMonitor.cpuUsage * 100)
            textColor: SystemMonitor.cpuUsage > 0.8 ? Theme.warning : Theme.text

            Item {
                width: cores.width
                height: 20

                Row {
                    id: cores
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    height: 14
                    spacing: 1

                    Repeater {
                        model: SystemMonitor.coreUsages
                        Rectangle {
                            required property real modelData
                            anchors.bottom: parent.bottom
                            width: 2
                            height: Math.max(1, parent.height * Math.min(1, modelData))
                            color: modelData > 0.8 ? Theme.error400 : Theme.textDim
                        }
                    }
                }
            }
        }

        BarSegment {
            objectName: "memory"
            text: "MEM " + Math.round(SystemMonitor.memoryUsage * 100)
            textColor: SystemMonitor.memoryUsage > 0.8 ? Theme.warning : Theme.text
        }

        BarSegment {
            objectName: "disk"
            text: "DSK " + Math.round(SystemMonitor.diskUsage * 100)
            textColor: SystemMonitor.diskUsage > 0.8 ? Theme.warning : Theme.text
        }
    }

    BarSegment {
        objectName: "media"
        visible: !bar.lockscreen
        anchors.left: launcher.right
        anchors.leftMargin: bar.gap
        padding: 0

        MediaControlDisplay {
            width: 270
        }
    }

    Row {
        anchors.left: parent.left
        spacing: 6

        WorkspacesDisplay {
            objectName: "workspaces"
            visible: bar.monitor !== null
            monitor: bar.monitor
        }

        BarSegment {
            objectName: "author"
            visible: bar.authorText !== ""
            text: bar.authorText
            textColor: Theme.textDim
        }

        BarSegment {
            objectName: "wifi"
            visible: !bar.lockscreen

            WifiDisplay {}
        }
    }

    Row {
        anchors.right: parent.right

        BarSegment {
            objectName: "headphones"
            visible: !bar.lockscreen
            text: HeadphonesWidget.busy ? "HEADPHONES .." : "HEADPHONES"
            textColor: "black"
            color: ({ busy: Theme.warning, ok: Theme.success600, fail: Theme.error400 })[HeadphonesWidget.status] ?? Theme.headphones
            clickable: bar.interactive && !HeadphonesWidget.busy
            onClicked: HeadphonesWidget.reconnect()
        }

        BarSegment {
            objectName: "brightness"
            visible: !bar.lockscreen
            text: "BRT " + Math.round(BrightnessWidget.brightness * 100)
            textColor: "black"
            color: Theme.brightness
            clickable: bar.interactive
            onScrolled: d => BrightnessWidget.setBrightness(BrightnessWidget.brightness + d * 0.01)
        }

        BarSegment {
            objectName: "volume"
            visible: !bar.lockscreen
            text: "VOL " + Math.round(VolumeWidget.volume * 100)
            textColor: VolumeWidget.muted ? Theme.warning : "black"
            color: Theme.volume
            clickable: bar.interactive
            acceptedButtons: Qt.RightButton
            onClicked: VolumeWidget.toggleMute()
            onScrolled: d => VolumeWidget.setVolume(VolumeWidget.volume + d * 0.01)
        }

        BarSegment {
            objectName: "battery"
            text: "BAT " + Math.round(SystemMonitor.batteryLevel * 100)
            textColor: "black"
            color: ({ charging: Theme.success600, critical: Theme.error400 })[SystemMonitor.batteryState] ?? Theme.warning
        }

        BarSegment {
            objectName: "clock"
            text: Qt.formatDateTime(clockTick.now, "dd.MM. hh:mm:ss")
            textColor: Theme.textDim
            clickable: bar.interactive
            onClicked: Clipboard.copy(new Date().toISOString(), "🕒 Timestamp copied!")

            Timer {
                id: clockTick
                property date now: new Date()
                interval: 1000
                running: true
                repeat: true
                onTriggered: now = new Date()
            }
        }

        BarSegment {
            objectName: "language"
            visible: !bar.lockscreen && LanguageWidget.available
            text: LanguageWidget.label
            color: hovered ? Theme.volume : Theme.app150
            textColor: hovered ? Theme.app100 : Theme.textDim
            clickable: bar.interactive
            onClicked: LanguageWidget.cycle()
        }
    }
}
