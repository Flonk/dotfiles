import QtQuick

Item {
    id: root
    required property var context
    property bool showRelock: false
    signal restart()

    Rectangle {
        anchors { left: parent.left; top: parent.top; margins: 12 }
        width: picker.implicitWidth + 20
        height: picker.implicitHeight + 20
        radius: 6
        color: "#cc111111"
        border.color: "#33ffffff"

        LockScenePicker {
            id: picker
            anchors.centerIn: parent
            context: root.context
        }
    }

    Rectangle {
        anchors { right: parent.right; bottom: parent.bottom; margins: 12 }
        width: tools.implicitWidth + 20
        height: tools.implicitHeight + 20
        radius: 6
        color: "#cc111111"
        border.color: "#33ffffff"

        LockSceneTools {
            id: tools
            anchors.centerIn: parent
            context: root.context
            showRelock: root.showRelock
            onRestart: root.restart()
        }
    }
}
