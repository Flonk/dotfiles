import QtQuick

Rectangle {
    id: btn
    property string label
    property bool active: false
    property color accent: "#3aa8b8"
    signal clicked()
    implicitWidth: btnText.implicitWidth + 16
    implicitHeight: 24
    radius: 4
    color: active ? accent : (btnMouse.pressed ? "#55ffffff" : btnMouse.containsMouse ? "#33ffffff" : "#1affffff")
    Text {
        id: btnText
        anchors.centerIn: parent
        text: btn.label
        color: btn.active ? "black" : "white"
        font.pixelSize: 12
    }
    MouseArea {
        id: btnMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: btn.clicked()
    }
}

