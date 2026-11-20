// AppLauncherDisplay.qml - flat launcher button, launches vicinae
import QtQuick
import Quickshell

Section {
    id: root

    property bool interactive: true

    width: 180
    topPadding: 0; bottomPadding: 0
    backgroundColor: launchMouse.containsMouse ? Qt.lighter("#5277c3", 1.3) : "#5277c3"
    showTopBorder: false
    glassEffect: false

    Item {
        width: parent.width; height: 20

        Text {
            id: launchText
            anchors.centerIn: parent; anchors.verticalCenterOffset: 1
            text: "NIXOS ROCKS"
            font.family: Theme.fontFamily; font.pointSize: Theme.fontSizeSmall; font.weight: Font.Bold
            color: "#000000"
        }

        MouseArea {
            id: launchMouse
            enabled: root.interactive
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached(["vicinae", "open"])
        }
    }
}
