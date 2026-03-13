// MiniBar.qml - Reusable horizontal mini-bar component (matches CPU bar style)
import QtQuick

Rectangle {
    id: root
    
    property real value: 0.0  // 0.0 to 1.0
    property color barColor: Theme.wm800
    property color errorColor: Theme.error400
    property real errorThreshold: 0.9
    property bool fillFromRight: false
    property bool enableErrorThreshold: true
    
    color: Theme.app150
    
    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: root.fillFromRight ? undefined : parent.left
        anchors.right: root.fillFromRight ? parent.right : undefined
        width: Math.max(1, parent.width * Math.max(0, Math.min(1, root.value)))
        radius: 0
        
        color: {
            const usage = root.value;
            if (root.enableErrorThreshold && usage > root.errorThreshold) return root.errorColor;
            return root.barColor;
        }
        
        Behavior on width {
            NumberAnimation {
                duration: 120
                easing.type: Easing.InOutQuad
            }
        }
    }
}
