// AppController.qml - Per-screen controller for application window state
import Quickshell
import QtQuick

QtObject {
    id: root
    
    property bool isExtended: false
    signal toggleExtension()
    
    function toggle() {
        isExtended = !isExtended
        toggleExtension()
    }
}