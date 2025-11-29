// WifiDisplay.qml - WiFi network dropdown display
import QtQuick

DropDown {
    id: root
    
    property color wifiTextColor: Theme.app600
    property color wifiBarColor: Theme.app600
    
    width: parent.width
    label: ""
    icon: WifiWidget.isConnected ? "\uf1eb" : "\uf127"
    textColor: root.wifiTextColor
    
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
