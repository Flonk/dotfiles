import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Column {
    id: root

    property bool interactive: true
    property int lines: 3

    readonly property var known: [
        { label: "MOMENTUM TW 4", node: "bluez_output.80_C3_BA_53_78_8B.1", mac: "80:C3:BA:53:78:8B" },
        { label: "Logitech BT Adapter", node: "bluez_output.EC_81_93_9A_F8_F5.1" },
        { label: "Laptop Speakers", node: "alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Speaker__sink" }
    ]

    readonly property var sinks: (Pipewire.nodes?.values ?? []).filter(n => n && n.isSink && !n.isStream && /^(bluez|alsa)_output\./.test(n.name))

    readonly property var entries: {
        const pick = k => ({ label: k.label, mac: k.mac ?? "", node: sinks.find(n => n.name === k.node) ?? null });
        const extra = sinks
            .filter(n => n.name.startsWith("bluez_output.") && !known.some(k => k.node === n.name))
            .map(n => ({ label: n.description, mac: "", node: n }));
        const ordered = [pick(known[0]), pick(known[1])].concat(extra, [pick(known[2])]);
        return ordered.filter(e => e.node || e.mac).slice(0, lines);
    }

    readonly property string autoName: entries.find(e => e.node)?.node.name ?? ""
    readonly property string activeName: Pipewire.defaultAudioSink?.name ?? ""

    function choose(entry) {
        if (!entry.node)
            Quickshell.execDetached(["sh", "-c", "wpctl clear-default 0; bluetoothctl connect " + entry.mac]);
        else if (entry.node.name === autoName)
            Quickshell.execDetached(["wpctl", "clear-default", "0"]);
        else
            Quickshell.execDetached(["wpctl", "set-default", String(entry.node.id)]);
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Repeater {
        model: root.entries

        Item {
            id: line
            required property var modelData
            readonly property bool active: modelData.node !== null && modelData.node.name === root.activeName
            readonly property string suffix: modelData.mac === "" ? "" : ({ busy: " ..", ok: " ✓", fail: " ✗" })[HeadphonesWidget.status] ?? ""
            width: row.implicitWidth
            height: 12
            opacity: hover.containsMouse ? 1 : active ? 0.9 : modelData.node ? 0.5 : 0.3

            Row {
                id: row
                height: parent.height
                spacing: 4

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4
                    height: 4
                    color: T3.ink
                    opacity: line.active ? 1 : 0
                }

                Text {
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: line.modelData.label + line.suffix
                    color: T3.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: T3.labelSize
                    font.weight: Font.Bold
                    font.letterSpacing: T3.labelTracking
                    font.capitalization: Font.AllUppercase
                }
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.interactive
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: m => {
                    if (m.button === Qt.RightButton) {
                        if (line.modelData.mac !== "")
                            HeadphonesWidget.reconnect();
                    } else {
                        root.choose(line.modelData);
                    }
                }
            }
        }
    }
}
