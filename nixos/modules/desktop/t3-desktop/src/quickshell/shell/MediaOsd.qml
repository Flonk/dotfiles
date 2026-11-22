import QtQuick
import Quickshell.Services.Mpris

Item {
    id: osd

    property bool armed: false
    property bool active: false
    property string kind
    property string icon
    property string label
    property string detail
    property real value: -1
    property color tint: T3.accent2
    property int hold: 1600

    readonly property var player: MediaControlWidget.currentPlayer

    function pop(k, i, l, d, v, c) {
        if (!armed)
            return;
        kind = k;
        icon = i;
        label = l;
        detail = d;
        value = v;
        tint = c;
        active = true;
        hide.restart();
    }

    function volume() {
        const v = VolumeWidget.volume;
        const m = VolumeWidget.muted;
        pop("volume", m ? "\u{f0581}" : v < 0.34 ? "\u{f057f}" : v < 0.67 ? "\u{f0580}" : "\u{f057e}", m ? "muted" : "volume", VolumeWidget.sinkName, m ? 0 : v, Theme.wm800);
    }

    function media() {
        const p = player;
        if (!p)
            return;
        const playing = p.isPlaying;
        pop("media", playing ? "\u{f040a}" : "\u{f03e4}", [p.trackArtist, p.trackTitle].filter(s => s).join(" — ") || p.identity, playing ? "playing" : "paused", p.lengthSupported && p.length > 0 ? p.position / p.length : -1, T3.accent2);
    }

    clip: true

    Timer {
        running: true
        interval: 2500
        onTriggered: osd.armed = true
    }

    Timer {
        id: hide
        interval: osd.hold
        onTriggered: osd.active = false
    }

    Timer {
        interval: 250
        repeat: true
        running: osd.active && osd.kind === "media"
        onTriggered: {
            osd.player?.positionChanged();
            if (osd.player?.length > 0)
                osd.value = osd.player.position / osd.player.length;
        }
    }

    Connections {
        target: VolumeWidget
        function onVolumeChanged() { osd.volume(); }
        function onMutedChanged() { osd.volume(); }
        function onMicMutedChanged() {
            osd.pop("mic", VolumeWidget.micMuted ? "\u{f036d}" : "\u{f036c}", VolumeWidget.micMuted ? "mic muted" : "mic live", VolumeWidget.source?.description ?? "", -1, VolumeWidget.micMuted ? Theme.error400 : "#66b16a");
        }
    }

    Connections {
        target: BrightnessWidget
        function onBrightnessChanged() {
            osd.pop("brightness", "\u{f00df}", "brightness", "", BrightnessWidget.brightness, "#c6932e");
        }
    }

    Connections {
        target: MediaControlWidget
        function onIsPlayingChanged() { osd.media(); }
        function onCurrentTitleChanged() { if (MediaControlWidget.currentTitle) osd.media(); }
    }

    Item {
        id: body
        width: parent.width
        height: parent.height
        y: osd.active ? 0 : parent.height
        opacity: osd.active ? 1 : 0

        Behavior on y {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 220 }
        }

        Text {
            id: glyph
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            width: 36
            horizontalAlignment: Text.AlignHCenter
            text: osd.icon
            color: osd.tint
            font.family: Theme.fontFamily
            font.pixelSize: 30
        }

        Column {
            anchors { left: glyph.right; leftMargin: 12; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 6

            Item {
                width: parent.width
                height: title.implicitHeight

                Text {
                    id: title
                    anchors { left: parent.left; right: amount.left; rightMargin: 12 }
                    elide: Text.ElideRight
                    text: osd.label + (osd.detail ? "  ·  " + osd.detail : "")
                    color: T3.cream
                    font.family: Theme.fontFamily
                    font.pixelSize: T3.labelSize
                    font.weight: Font.Bold
                    font.letterSpacing: T3.labelTracking
                    font.capitalization: Font.AllUppercase
                }

                Text {
                    id: amount
                    anchors.right: parent.right
                    visible: osd.value >= 0 && osd.kind !== "media"
                    text: Math.round(osd.value * 100) + "%"
                    color: T3.cream
                    font.family: Theme.fontFamily
                    font.pixelSize: T3.labelSize
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                }
            }

            Row {
                id: bar
                visible: osd.value >= 0
                readonly property int count: 32
                readonly property real cell: (width - (count - 1) * spacing) / count
                width: parent.width
                height: 8
                spacing: 2

                Repeater {
                    model: bar.count

                    Rectangle {
                        required property int index
                        width: bar.cell
                        height: bar.height
                        radius: 1
                        color: (index + 0.5) / bar.count <= osd.value ? osd.tint : Qt.rgba(T3.cream.r, T3.cream.g, T3.cream.b, 0.12)
                    }
                }
            }
        }
    }
}
