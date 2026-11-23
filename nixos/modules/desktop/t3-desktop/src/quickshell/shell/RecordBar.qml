import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property var session: null
    property double now: Date.now()

    readonly property string elapsed: {
        if (!session)
            return "";
        const s = Math.max(0, Math.floor((now - session.started) / 1000));
        const pad = n => String(n).padStart(2, "0");
        const h = Math.floor(s / 3600);
        return (h > 0 ? h + ":" : "") + pad(Math.floor(s / 60) % 60) + ":" + pad(s % 60);
    }

    function apply(payload) {
        if (payload.startsWith("{")) {
            try {
                session = JSON.parse(payload);
                now = Date.now();
                return;
            } catch (e) {}
        }
        session = null;
    }

    Process {
        id: feed
        running: true
        command: ["mosquitto_sub", "-h", "127.0.0.1", "-t", "screen/record/state"]
        stdout: SplitParser {
            onRead: data => root.apply(data.trim())
        }
        onExited: retry.start()
    }

    Timer {
        id: retry
        interval: 5000
        onTriggered: feed.running = true
    }

    Timer {
        interval: 250
        repeat: true
        running: root.session !== null
        onTriggered: root.now = Date.now()
    }

    component Label: Text {
        anchors.verticalCenter: parent.verticalCenter
        color: T3.ink
        font.family: Theme.fontFamily
        font.pixelSize: T3.labelSize
        font.weight: Font.Bold
        font.letterSpacing: T3.labelTracking
        font.capitalization: Font.AllUppercase
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: frame
            required property var modelData
            readonly property var s: root.session
            readonly property int edge: 3

            screen: modelData
            visible: s !== null && s.output === modelData.name && (s.mode === "region" || s.mode === "window")
            anchors { top: true; left: true }
            margins {
                top: s ? Math.round(s.y - modelData.y - edge) : 0
                left: s ? Math.round(s.x - modelData.x - edge) : 0
            }
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: s ? s.w + 2 * edge : 1
            implicitHeight: s ? s.h + 2 * edge : 1
            color: "transparent"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "t3-desktop-recorder-frame"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: frame.edge
                border.color: Theme.error400
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property var s: root.session
            readonly property int gap: 8

            readonly property real localX: s ? s.x - modelData.x : 0
            readonly property real localY: s ? s.y - modelData.y : 0
            readonly property real below: localY + (s ? s.h : 0) + gap
            readonly property real above: localY - gap - implicitHeight
            readonly property real top: below + implicitHeight <= modelData.height - T3.border ? below
                : above >= T3.band ? above
                : localY + (s ? s.h : 0) - implicitHeight - 2 * gap
            readonly property real left: Math.max(T3.border, Math.min(modelData.width - implicitWidth - T3.border, localX + ((s ? s.w : 0) - implicitWidth) / 2))

            screen: modelData
            visible: s !== null && s.output === modelData.name
            anchors { top: true; left: true }
            margins { top: Math.round(top); left: Math.round(left) }
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: bar.width
            implicitHeight: bar.height
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "t3-desktop-recorder"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                id: bar
                width: row.implicitWidth + 2 * 10
                height: 30
                radius: 8
                color: T3.accent2
                border.width: 1
                border.color: T3.lighten(T3.accent2, 0.25)

                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: 9

                    Rectangle {
                        id: dot
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.error400
                        border.width: 1
                        border.color: T3.ink

                        SequentialAnimation on opacity {
                            running: win.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutQuad }
                        }
                    }

                    Label {
                        text: "rec"
                    }

                    Label {
                        text: root.elapsed
                        font.features: { "tnum": 1 }
                    }

                    Label {
                        text: win.s ? win.s.w + "×" + win.s.h : ""
                        opacity: 0.55
                    }

                    Rectangle {
                        id: stop
                        anchors.verticalCenter: parent.verticalCenter
                        width: stopLabel.implicitWidth + 16
                        height: 18
                        radius: 4
                        color: stopArea.containsMouse ? T3.lighten(T3.ink, 0.15) : T3.ink
                        border.width: 1
                        border.color: T3.lighten(T3.ink, 0.25)

                        Row {
                            id: stopLabel
                            anchors.centerIn: parent
                            spacing: 5

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 1
                                color: Theme.error400
                            }

                            Label {
                                text: "stop"
                                color: T3.cream
                            }
                        }

                        MouseArea {
                            id: stopArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["t3os", "screen", "record", "stop", "-c"])
                        }
                    }
                }
            }
        }
    }
}
