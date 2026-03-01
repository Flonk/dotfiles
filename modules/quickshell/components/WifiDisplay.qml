// WifiDisplay.qml - WiFi network dropdown display
import QtQuick

DropDown {
    id: root
    
    property color wifiTextColor: Theme.app600
    property color wifiIconColor: Theme.app600
    property color wifiBarColor: Theme.app600
    property color wifiHoverColor: Theme.app600
    property color wifiHoverBackground: "#000000"

    function speedInKilobits(bytesPerSecond) {
        const value = Number(bytesPerSecond);
        if (!isFinite(value) || value <= 0) {
            return 0;
        }
        return Math.max(0, Math.round((value * 8) / 1000));
    }

    function formatSpeedLabel(prefix, bytesPerSecond) {
        const kbps = speedInKilobits(bytesPerSecond);
        let digits = kbps.toString();
        if (digits.length < 7) {
            digits = digits.padStart(7, " ");
        }
        return `${prefix}${digits}`;
    }
    function formatIpValue(value) {
        return value && value.length ? value : "--";
    }

    function copyIpToClipboard(label, value) {
        if (!value || !value.length) return;
        WifiWidget.copyToClipboard(value);
        const messageLabel = label && label.length ? label : "IP";
        WifiWidget.sendNotification(messageLabel + " Copied to Clipboard", value);
    }
    
    width: parent.width
    label: ""
    icon: WifiWidget.isConnected ? "\uf1eb" : "\uf127"
    textColor: root.wifiTextColor
    headerRightClickEnabled: true
    disabled: !WifiWidget.isEnabled
    headerHeight: 98
    headerContent: Component {
        Item {
            anchors.fill: parent
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Item {
                    id: iconContainer
                    width: parent.width
                    height: wifiIconText.implicitHeight + 4
                    property real iconOffset: wifiIconMetrics.valid
                        ? (wifiIconMetrics.advanceWidth / 2) - (wifiIconMetrics.boundingRect.x + wifiIconMetrics.boundingRect.width / 2)
                        : 0
                    TextMetrics {
                        id: wifiIconMetrics
                        font: wifiIconText.font
                        text: wifiIconText.text
                    }
                    Text {
                        id: wifiIconText
                        text: root.icon
                        font.pointSize: 10
                        font.family: Theme.fontFamilyUiNf
                        color: root.wifiIconColor
                        opacity: 0.95
                        width: implicitWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenterOffset: iconContainer.iconOffset
                    }
                }
                Item { width: 1; height: 4 }
                Text {
                    id: upstreamText
                    text: root.formatSpeedLabel("\uf062", WifiWidget.uploadRate)
                    font.pointSize: 6
                    font.family: Theme.fontFamilyUiNf
                    color: root.wifiTextColor
                    opacity: WifiWidget.isConnected ? 0.9 : 0.5
                    anchors.left: parent.left
                    anchors.right: parent.right
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideNone
                }
                Text {
                    id: downstreamText
                    text: root.formatSpeedLabel("\uf063", WifiWidget.downloadRate)
                    font.pointSize: 6
                    font.family: Theme.fontFamilyUiNf
                    color: root.wifiTextColor
                    opacity: WifiWidget.isConnected ? 0.9 : 0.5
                    anchors.left: parent.left
                    anchors.right: parent.right
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideNone
                }
                Item { width: 1; height: 4 }
                Item {
                    width: parent.width
                    height: 2
                }
                Item {
                    width: parent.width
                    height: localIpText.implicitHeight
                    Rectangle {
                        anchors.fill: parent
                        color: localIpMouseArea.containsMouse ? root.wifiHoverBackground : "transparent"
                        opacity: localIpMouseArea.containsMouse ? 0.85 : 0
                        radius: 2
                    }
                    MarqueeText {
                        id: localIpText
                        text: root.formatIpValue(WifiWidget.localIp)
                        font.pointSize: 6
                        font.family: Theme.fontFamilyUiNf
                        textColor: localIpMouseArea.containsMouse ? root.wifiHoverColor : root.wifiTextColor
                        textOpacity: WifiWidget.isConnected ? 0.9 : 0.5
                        anchors.left: parent.left
                        anchors.right: parent.right
                        alignment: Qt.AlignRight
                        hovered: localIpMouseArea.containsMouse
                        height: implicitHeight
                    }
                    MouseArea {
                        id: localIpMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: WifiWidget.localIp && WifiWidget.localIp.length
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.copyIpToClipboard("Local IP", WifiWidget.localIp)
                    }
                }
                Item {
                    width: parent.width
                    height: gatewayIpText.implicitHeight
                    Rectangle {
                        anchors.fill: parent
                        color: gatewayIpMouseArea.containsMouse ? root.wifiHoverBackground : "transparent"
                        opacity: gatewayIpMouseArea.containsMouse ? 0.85 : 0
                        radius: 2
                    }
                    MarqueeText {
                        id: gatewayIpText
                        text: root.formatIpValue(WifiWidget.gatewayIp)
                        font.pointSize: 6
                        font.family: Theme.fontFamilyUiNf
                        textColor: gatewayIpMouseArea.containsMouse ? root.wifiHoverColor : root.wifiTextColor
                        textOpacity: WifiWidget.isConnected ? 0.9 : 0.5
                        anchors.left: parent.left
                        anchors.right: parent.right
                        alignment: Qt.AlignRight
                        hovered: gatewayIpMouseArea.containsMouse
                        height: implicitHeight
                    }
                    MouseArea {
                        id: gatewayIpMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: WifiWidget.gatewayIp && WifiWidget.gatewayIp.length
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.copyIpToClipboard("Gateway IP", WifiWidget.gatewayIp)
                    }
                }
                Item {
                    width: parent.width
                    height: publicIpText.implicitHeight
                    Rectangle {
                        anchors.fill: parent
                        color: publicIpMouseArea.containsMouse ? root.wifiHoverBackground : "transparent"
                        opacity: publicIpMouseArea.containsMouse ? 0.85 : 0
                        radius: 2
                    }
                    MarqueeText {
                        id: publicIpText
                        text: root.formatIpValue(WifiWidget.publicIp)
                        font.pointSize: 6
                        font.family: Theme.fontFamilyUiNf
                        textColor: publicIpMouseArea.containsMouse ? root.wifiHoverColor : root.wifiTextColor
                        textOpacity: WifiWidget.isConnected ? 0.9 : 0.5
                        anchors.left: parent.left
                        anchors.right: parent.right
                        alignment: Qt.AlignRight
                        hovered: publicIpMouseArea.containsMouse
                        height: implicitHeight
                    }
                    MouseArea {
                        id: publicIpMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: WifiWidget.publicIp && WifiWidget.publicIp.length
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.copyIpToClipboard("Public IP", WifiWidget.publicIp)
                    }
                }
            }
        }
    }
    
    onHeaderRightClicked: {
        WifiWidget.toggleWifi();
    }
    
    Column {
        width: parent.width
        spacing: 2
        
        // Connected network at the top
        Item {
            visible: WifiWidget.isConnected
            width: parent.width
            height: visible ? connectedText.implicitHeight + 6 : 0
            
            Rectangle {
                anchors.fill: parent
                color: root.wifiBarColor
                opacity: 0.3
                radius: 0
            }
            
            Text {
                id: connectedText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                text: WifiWidget.connectedSsid + " ✓"
                font.pointSize: 7
                font.family: Theme.fontFamilyUiNf
                color: root.wifiTextColor
                opacity: 0.9
                font.bold: true
            }
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    WifiWidget.disconnect();
                }
            }
        }
        
        // Available networks
        Repeater {
            model: WifiWidget.availableNetworks
            delegate: Item {
                width: parent.width
                height: ssidText.implicitHeight + 6
                
                Rectangle {
                    anchors.fill: parent
                    color: ssidMouseArea.containsMouse ? root.wifiBarColor : "transparent"
                    opacity: 0.2
                    radius: 0
                }
                
                Text {
                    id: ssidText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    text: modelData.ssid + (modelData.secure ? " 🔒" : "")
                    font.pointSize: 7
                    font.family: Theme.fontFamilyUiNf
                    color: root.wifiTextColor
                    opacity: 0.8
                }
                
                MouseArea {
                    id: ssidMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        WifiWidget.connect(modelData.ssid);
                    }
                }
            }
        }
    }
}
