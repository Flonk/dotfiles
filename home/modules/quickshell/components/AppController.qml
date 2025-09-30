// AppController.qml - Per-screen controller for application window state
import Quickshell
import QtQuick

QtObject {
    id: root
    
    // Property to control if cava window is extended
    property bool isExtended: false
    
    // Signal to notify when state changes
    signal toggleExtension()
    
    // Function to toggle the extension state
    function toggle() {
        isExtended = !isExtended
        toggleExtension()
    }
    
    // Property for the margin offset when extended
    readonly property int extendedOffset: 20
}