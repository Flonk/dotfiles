// AppLauncherDisplay.qml - GLOXWALD logo button that launches vicinae
import QtQuick
import Quickshell

Item {
    id: root

    property bool hovered: gloxwaldMouse.containsMouse

    width: gloxwaldText.implicitWidth - 20
    height: 20
    clip: true

    Text {
        id: gloxwaldText
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 2
        text: "GLOXWALD"
        font.family: "Hypik"
        font.pointSize: 26
        color: gloxwaldMouse.containsMouse
            ? Qt.rgba(Theme.app800.r * 0.8 + Theme.wm800.r * 0.2, Theme.app800.g * 0.8 + Theme.wm800.g * 0.2, Theme.app800.b * 0.8 + Theme.wm800.b * 0.2, 1.0)
            : Theme.app800
        scale: gloxwaldMouse.containsMouse ? 1.15 : 1.0
        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: gloxwaldMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["vicinae", "open"])
    }
}
