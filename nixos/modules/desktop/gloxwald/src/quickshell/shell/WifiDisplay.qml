import QtQuick
import Quickshell

Row {
    id: root
    spacing: 6

    function rate(bytesPerSecond: real): string {
        const units = ["B", "K", "M", "G", "T"];
        let value = Number(bytesPerSecond);
        let unit = 0;
        if (!isFinite(value) || value <= 0)
            return "  0B";
        while (value >= 1000 && unit < units.length - 1) {
            value /= 1000;
            unit++;
        }
        const mantissa = unit === 0 || value >= 10 ? Math.round(value).toString() : value.toFixed(1);
        return mantissa.padStart(3, " ") + units[unit];
    }

    readonly property var items: [
        { text: WifiWidget.isConnected ? "" : "", color: WifiWidget.isHighTraffic ? Theme.warning : Theme.textStrong },
        { text: "", color: Theme.text },
        { text: rate(WifiWidget.uploadRate), color: Theme.text },
        { text: "", color: Theme.text },
        { text: rate(WifiWidget.downloadRate), color: Theme.text },
        { text: WifiWidget.localIp || "--", copy: WifiWidget.localIp, title: "🏠 Local IP copied!" },
        { text: WifiWidget.gatewayIp || "--", copy: WifiWidget.gatewayIp, title: "🚪 Gateway IP copied!" },
        { text: WifiWidget.publicIp || "--", copy: WifiWidget.publicIp, title: "🌐 Public IP copied!" }
    ]

    Repeater {
        model: root.items.length

        BarText {
            required property int index
            readonly property var item: root.items[index]
            readonly property bool copyable: item.copy !== undefined
            text: item.text
            font.weight: copyable ? Font.Normal : Font.Bold
            color: !copyable ? item.color : mouse.containsMouse ? Theme.textStrong : Theme.textDim
            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (parent.copyable)
                        Clipboard.copy(parent.item.copy, parent.item.title);
                    else
                        Quickshell.execDetached(["xdg-open", "vicinae://launch/@dagimg-dot/store.vicinae.wifi-commander/scan-wifi"]);
                }
            }
        }
    }
}
