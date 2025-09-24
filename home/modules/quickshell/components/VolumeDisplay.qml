// VolumeDisplay.qml
import QtQuick
import QtQuick.Controls

Item {
    id: root
    
    // Set explicit size to avoid binding loops
    implicitWidth: volumeRow.implicitWidth
    implicitHeight: volumeRow.implicitHeight

    Row {
        id: volumeRow
        spacing: 5

        Text {
            text: VolumeWidget.volumeIcon
            font.pointSize: Theme.fontSizeNormal
            font.family: Theme.fontFamilyUiNf
            color: Theme.app400
        }

        Text {
            text: VolumeWidget.volumeText || "---"
            font.pointSize: Theme.fontSizeNormal
            font.family: Theme.fontFamilyUiNf
            color: VolumeWidget.muted ? Theme.error400 : Theme.app400  // text color
        }
    }
    
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                VolumeWidget.toggleMute();
            }
        }
        
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
                VolumeWidget.incrementVolume();
            } else if (wheel.angleDelta.y < 0) {
                VolumeWidget.decrementVolume();
            }
        }
    }
}