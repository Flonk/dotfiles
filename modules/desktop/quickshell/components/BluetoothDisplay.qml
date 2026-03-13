// BluetoothDisplay.qml - Bluetooth device dropdown display
import QtQuick

DropDown {
    id: root
    
    property color btTextColor: Theme.app600
    property color btBarColor: Theme.app600
    
    width: parent.width
    label: ""
    icon: BluetoothWidget.isEnabled ? "\udb80\udcaf" : "\udb80\udcb2"
    textColor: root.btTextColor
    headerRightClickEnabled: true
    disabled: !BluetoothWidget.isEnabled
    iconRotation: 270
    iconScale: 1.5
    
    onHeaderRightClicked: {
        BluetoothWidget.toggleBluetooth();
    }
    
    onExpandedChanged: {
        if (expanded) {
            BluetoothWidget.refresh();
        }
    }
    
    Column {
        width: parent.width
        spacing: 2
        
        // Scan toggle button
        Item {
            width: parent.width
            height: scanText.implicitHeight + 6
            
            Rectangle {
                anchors.fill: parent
                color: BluetoothWidget.isScanning ? Theme.success600 : "transparent"
                opacity: 1.0
                radius: 0
            }
            
            Text {
                id: scanText
                anchors.centerIn: parent
                text: "\uf002"
                font.pointSize: 9
                font.family: Theme.fontFamilyUiNf
                color: BluetoothWidget.isScanning ? "#000000" : root.btTextColor
                opacity: 0.95
            }
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    BluetoothWidget.toggleScan();
                }
            }
        }
        
        // Connected devices
        Repeater {
            model: BluetoothWidget.connectedDevices
            delegate: Item {
                width: parent.width
                height: deviceColumn.implicitHeight + 6
                
                Rectangle {
                    anchors.fill: parent
                    color: deviceMouseArea.containsMouse ? root.btBarColor : root.btBarColor
                    opacity: deviceMouseArea.containsMouse ? 0.4 : 0.3
                    radius: 0
                }
                
                Column {
                    id: deviceColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: 0
                    
                    Text {
                        text: modelData.name + " ✓"
                        font.pointSize: 7
                        font.family: Theme.fontFamilyUiNf
                        color: root.btTextColor
                        opacity: 1.0
                        font.bold: true
                    }
                    
                    Text {
                        text: modelData.address
                        font.pointSize: 6
                        font.family: Theme.fontFamilyUiNf
                        color: root.btTextColor
                        opacity: 0.8
                    }
                }
                
                MouseArea {
                    id: deviceMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            BluetoothWidget.disconnectDevice(modelData.address, modelData.name);
                        }
                    }
                }
            }
        }
        
        // Trusted devices
        Repeater {
            model: BluetoothWidget.trustedDevices
            delegate: Item {
                width: parent.width
                height: trustedColumn.implicitHeight + 6
                
                Rectangle {
                    anchors.fill: parent
                    color: trustedMouseArea.containsMouse ? root.btBarColor : "transparent"
                    opacity: 0.2
                    radius: 0
                }
                
                Column {
                    id: trustedColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: 0
                    
                    Text {
                        text: modelData.name
                        font.pointSize: 7
                        font.family: Theme.fontFamilyUiNf
                        color: root.btTextColor
                        opacity: 0.95
                    }
                    
                    Text {
                        text: modelData.address
                        font.pointSize: 6
                        font.family: Theme.fontFamilyUiNf
                        color: root.btTextColor
                        opacity: 0.7
                    }
                }
                
                MouseArea {
                    id: trustedMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            BluetoothWidget.connectDevice(modelData.address, modelData.name);
                        }
                    }
                }
            }
        }
        
        // Available devices
        Repeater {
            model: BluetoothWidget.availableDevices
            delegate: Item {
                width: parent.width
                height: availableColumn.implicitHeight + 6
                
                Rectangle {
                    anchors.fill: parent
                    color: availableMouseArea.containsMouse ? root.btBarColor : "transparent"
                    opacity: 0.15
                    radius: 0
                }
                
                Column {
                    id: availableColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: 0
                    
                    Text {
                        text: modelData.name
                        font.pointSize: 7
                        font.family: Theme.fontFamilyUiNf
                        color: root.btTextColor
                        opacity: 0.9
                    }
                    
                    Text {
                        text: modelData.address
                        font.pointSize: 6
                        font.family: Theme.fontFamilyUiNf
                        color: root.btTextColor
                        opacity: 0.6
                    }
                }
                
                MouseArea {
                    id: availableMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            BluetoothWidget.connectDevice(modelData.address, modelData.name);
                        }
                    }
                }
            }
        }
    }
}
