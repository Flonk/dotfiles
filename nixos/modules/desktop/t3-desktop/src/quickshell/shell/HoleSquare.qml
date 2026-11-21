import QtQuick

Rectangle {
    property string label
    property color ink
    property bool dark: true

    width: 16
    height: 16
    radius: 4
    color: ink
    border.width: 1
    border.color: T3.lighten(ink, 0.2)

    Text {
        anchors.centerIn: parent
        text: parent.label
        color: parent.dark ? T3.ground : T3.cream
        font.family: Theme.fontFamily
        font.pixelSize: T3.labelSize
        font.weight: Font.Bold
    }
}
