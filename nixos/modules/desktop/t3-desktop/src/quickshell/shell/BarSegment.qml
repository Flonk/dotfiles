import QtQuick

Rectangle {
    id: root
    property alias text: label.text
    property alias textColor: label.color
    property int padding: 8
    property bool clickable: false
    property int acceptedButtons: Qt.LeftButton
    readonly property bool hovered: mouse.containsMouse
    default property alias content: row.data
    signal clicked(var mouse)
    signal scrolled(int direction)

    implicitWidth: row.implicitWidth + 2 * padding
    width: implicitWidth
    height: 20
    color: Theme.segment

    Row {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4

        BarText {
            id: label
            visible: text !== ""
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: root.clickable
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: root.acceptedButtons
        onClicked: m => root.clicked(m)
        onWheel: w => root.scrolled(w.angleDelta.y > 0 ? 1 : -1)
    }
}
