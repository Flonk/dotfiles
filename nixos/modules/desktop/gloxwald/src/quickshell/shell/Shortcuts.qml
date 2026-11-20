// Shortcuts.qml
import QtQuick
import Quickshell

Item {
    id: root

    // Global shortcuts would typically be handled by your window manager,
    // but we can provide some basic shortcuts for when the bar has focus

    focus: true
    
    Keys.onPressed: (event) => {
        // Volume controls
        if (event.key === Qt.Key_VolumeUp) {
            VolumeWidget.incrementVolume();
            event.accepted = true;
        } else if (event.key === Qt.Key_VolumeDown) {
            VolumeWidget.decrementVolume();
            event.accepted = true;
        } else if (event.key === Qt.Key_VolumeMute) {
            VolumeWidget.toggleMute();
            event.accepted = true;
        }
        
        // Brightness controls
        else if (event.key === Qt.Key_MonBrightnessUp) {
            BrightnessWidget.increaseBrightness();
            event.accepted = true;
        } else if (event.key === Qt.Key_MonBrightnessDown) {
            BrightnessWidget.decreaseBrightness();
            event.accepted = true;
        }
        
        // Custom key combinations (Ctrl+Alt+...)
        else if (event.modifiers === (Qt.ControlModifier | Qt.AltModifier)) {
            switch (event.key) {
                case Qt.Key_Plus:
                case Qt.Key_Equal:
                    VolumeWidget.incrementVolume();
                    event.accepted = true;
                    break;
                case Qt.Key_Minus:
                    VolumeWidget.decrementVolume(); 
                    event.accepted = true;
                    break;
                case Qt.Key_M:
                    VolumeWidget.toggleMute();
                    event.accepted = true;
                    break;
                case Qt.Key_Up:
                    BrightnessWidget.increaseBrightness();
                    event.accepted = true;
                    break;
                case Qt.Key_Down:
                    BrightnessWidget.decreaseBrightness();
                    event.accepted = true;
                    break;
            }
        }
    }
}