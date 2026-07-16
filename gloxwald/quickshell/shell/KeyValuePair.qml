// KeyValuePair.qml - Single-line icon/value display
import QtQuick

Item {
    id: root
    
    property string label: ""
    property string value: ""
    property color labelColor: Theme.app600
    property color valueColor: Theme.app600
    property real labelOpacity: 0.85
    property real valueOpacity: 0.95
    property int labelPointSize: Theme.fontSizeBig
    property int valuePointSize: Theme.fontSizeBig
    property int singleLineSpacing: 6
    property bool valueBold: true
    property string fontFamily: Theme.fontFamily
    property string valueFontFamily: Theme.fontFamily
    property int labelLeftPadding: 0
    property int horizontalPadding: 7
    clip: true
    width: parent ? parent.width : implicitWidth
    implicitWidth: horizontalPadding + singleLineLabelText.implicitWidth + singleLineSpacing + singleLineValueText.implicitWidth + horizontalPadding
    implicitHeight: Math.max(singleLineLabelText.implicitHeight, singleLineValueText.implicitHeight)
    height: implicitHeight
    
    Text {
        id: singleLineLabelText
        text: root.label
        anchors.left: parent.left
        anchors.leftMargin: root.horizontalPadding + root.labelLeftPadding
        anchors.verticalCenter: parent.verticalCenter
        font.pointSize: root.labelPointSize
        font.family: root.fontFamily
        color: root.labelColor
        opacity: root.labelOpacity
        elide: Text.ElideNone
        wrapMode: Text.NoWrap
        maximumLineCount: 1
        width: implicitWidth
    }
    Text {
        id: singleLineValueText
        text: root.value
        anchors.left: singleLineLabelText.right
        anchors.leftMargin: root.singleLineSpacing
        anchors.right: parent.right
        anchors.rightMargin: root.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        font.pointSize: root.valuePointSize
        font.family: root.valueFontFamily
        font.bold: root.valueBold
        color: root.valueColor
        opacity: root.valueOpacity
        elide: Text.ElideNone
        wrapMode: Text.NoWrap
        maximumLineCount: 1
    }
}
