import QtQuick
import Quickshell

Row {
    id: root
    spacing: 6

    readonly property var items: [
        { text: WifiWidget.isConnected ? "" : "", color: WifiWidget.isHighTraffic ? Theme.warning : Theme.textStrong },
        { text: "", color: Theme.text },
        { text: WifiWidget.formatRate(WifiWidget.uploadRate), color: Theme.text },
        { text: "", color: Theme.text },
        { text: WifiWidget.formatRate(WifiWidget.downloadRate), color: Theme.text },
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
                        WifiWidget.openCommander();
                }
            }
        }
    }
}
