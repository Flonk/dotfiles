// BrightnessDisplay.qml
import QtQuick
import QtQuick.Controls

Item {
    id: root
    
    // Set explicit size to avoid binding loops
    implicitWidth: brightnessRow.implicitWidth
    implicitHeight: brightnessRow.implicitHeight

    Row {
        id: brightnessRow
        spacing: 5

        Text {
            text: BrightnessWidget.brightnessIcon
            font.pointSize: Theme.fontSizeNormal
            font.family: Theme.fontFamilyUiNf
            color: Theme.app400
        }

        Text {
            text: BrightnessWidget.brightnessText
            font.pointSize: Theme.fontSizeNormal
            font.family: Theme.fontFamilyUiNf
            color: Theme.app400  // text color
        }
    }
    
    MouseArea {
        anchors.fill: parent
        
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
                BrightnessWidget.increaseBrightness();
            } else if (wheel.angleDelta.y < 0) {
                BrightnessWidget.decreaseBrightness();
            }
        }
    }
}