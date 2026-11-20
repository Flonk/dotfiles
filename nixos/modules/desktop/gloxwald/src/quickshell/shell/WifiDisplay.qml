// WifiDisplay.qml - Compact horizontal wifi status display
import QtQuick
import Quickshell

Row {
    id: root
    spacing: 6

    property color wifiIconColor: "#FFFFFF"
    property color arrowIconColor: "#FFFFFF"
    property color speedColor: "#FFFFFF"
    property color ipColor: "#FFFFFF"
    property color ipHoverColor: "#FFFFFF"
    property color warningColor: "#FFA500"
    property bool wifiWarningActive: false
    property int textVerticalOffset: 0

    function formatRate(bytesPerSecond) {
        const units = ["B", "K", "M", "G", "T"];
        let value = Number(bytesPerSecond);
        let unitIndex = 0;
        if (!isFinite(value) || value <= 0) return "  0B";
        while (value >= 1000 && unitIndex < units.length - 1) { value /= 1000; unitIndex++; }
        const mantissa = (unitIndex === 0 || value >= 10) ? Math.round(value).toString() : (Math.round(value * 10) / 10).toFixed(1);
        return mantissa.padStart(3, " ") + units[unitIndex];
    }

    function openWifiCommander() {
        Quickshell.execDetached(["xdg-open", "vicinae://launch/@dagimg-dot/store.vicinae.wifi-commander/scan-wifi"]);
    }

    Item {
        width: wifiIcon.implicitWidth; height: 20
        Text {
            id: wifiIcon
            anchors.verticalCenter: parent.verticalCenter
            text: WifiWidget.isConnected ? "\uf1eb" : "\uf127"
            font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall; font.weight: Font.Bold
            color: root.wifiWarningActive ? root.warningColor : root.wifiIconColor
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openWifiCommander() }
    }
    Item {
        width: upArrow.implicitWidth; height: 20
        Text {
            id: upArrow
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf062"
            font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall; font.weight: Font.Bold
            color: root.arrowIconColor
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openWifiCommander() }
    }
    Item {
        width: upSpeed.implicitWidth; height: 20
        Text {
            id: upSpeed
            anchors.verticalCenter: parent.verticalCenter
            text: root.formatRate(WifiWidget.uploadRate)
            font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall; font.weight: Font.Bold
            color: root.speedColor
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openWifiCommander() }
    }
    Item {
        width: downArrow.implicitWidth; height: 20
        Text {
            id: downArrow
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf063"
            font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall; font.weight: Font.Bold
            color: root.arrowIconColor
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openWifiCommander() }
    }
    Item {
        width: downSpeed.implicitWidth; height: 20
        Text {
            id: downSpeed
            anchors.verticalCenter: parent.verticalCenter
            text: root.formatRate(WifiWidget.downloadRate)
            font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall; font.weight: Font.Bold
            color: root.speedColor
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openWifiCommander() }
    }
    Item {
        width: localIpText.implicitWidth; height: 20
        Text {
            id: localIpText
            anchors.verticalCenter: parent.verticalCenter
            text: WifiWidget.localIp || "--"
            font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall
            color: localIpMouse.containsMouse ? root.ipHoverColor : root.ipColor
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        MouseArea {
            id: localIpMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Quickshell.execDetached(["sh", "-c", "echo -n '" + WifiWidget.localIp + "' | wl-copy && notify-send '\uD83C\uDFE0 Local IP copied!' '" + WifiWidget.localIp + " was copied to the clipboard'"]);
            }
        }
    }
    Item {
        width: gatewayIpText.implicitWidth; height: 20
        Text {
            id: gatewayIpText
            anchors.verticalCenter: parent.verticalCenter
            text: WifiWidget.gatewayIp || "--"
            font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall
            color: gatewayIpMouse.containsMouse ? root.ipHoverColor : root.ipColor
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        MouseArea {
            id: gatewayIpMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Quickshell.execDetached(["sh", "-c", "echo -n '" + WifiWidget.gatewayIp + "' | wl-copy && notify-send '\uD83D\uDEAA Gateway IP copied!' '" + WifiWidget.gatewayIp + " was copied to the clipboard'"]);
            }
        }
    }
    Item {
        width: publicIpText.implicitWidth; height: 20
        Text {
            id: publicIpText
            anchors.verticalCenter: parent.verticalCenter
            text: WifiWidget.publicIp || "--"
            font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall
            color: publicIpMouse.containsMouse ? root.ipHoverColor : root.ipColor
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        MouseArea {
            id: publicIpMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Quickshell.execDetached(["sh", "-c", "echo -n '" + WifiWidget.publicIp + "' | wl-copy && notify-send '\uD83C\uDF10 Public IP copied!' '" + WifiWidget.publicIp + " was copied to the clipboard'"]);
            }
        }
    }
}
