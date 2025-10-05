// SystemBar.qml - Reusable dual-layer system bar component
import QtQuick
import Quickshell

Item {
    id: root
    
    // Public properties
    property string label: ""
    property real value: 0.0  // 0.0 to 1.0
    property color backgroundBarColor: Theme.wm200
    property color foregroundBarColor: Theme.wm400
    property color backgroundTextColor: Theme.wm300
    property color foregroundTextColor: Theme.wm800
    property color errorColor: Theme.error400
    property color errorTextColor: Theme.error800
    property color errorBackgroundTextColor: Theme.error400
    property real errorThreshold: 0.9  // Show error color when value exceeds this
    property bool enableErrorThreshold: true  // Allow disabling error threshold
    property bool barVisible: true
    
    // Custom color override (for special cases like charging)
    property color customBarColor: "transparent"
    property color customBackgroundTextColor: "transparent"
    property color customForegroundTextColor: "transparent"
    property bool useCustomColors: false
    
    // Mouse interaction properties
    property bool enableMouseInteraction: false
    property var valueChangedCallback: null  // Function to call when value changes
    property real mouseStep: 0.01      // Step size for wheel events
    
    // Background bar (always full width)
    Rectangle {
        id: backgroundBar
        anchors.fill: parent
        color: root.backgroundBarColor
        visible: root.barVisible
        
        // Background label (darker)
        Text {
            text: root.label
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            font.pointSize: Theme.fontSizeTiny
            font.family: Theme.fontFamilyUiNf
            color: {
                if (root.useCustomColors) return root.customBackgroundTextColor;
                if (root.enableErrorThreshold && root.value > root.errorThreshold) return root.errorBackgroundTextColor;
                return root.backgroundTextColor;
            }
            opacity: 0.9
        }
    }
    
    // Foreground bar (proportional to value)
    Rectangle {
        id: foregroundBar
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.top: parent.top
        anchors.topMargin: 0
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        width: Math.max(1, (parent.width - 2) * root.value)
        radius: 0
        visible: root.barVisible
        clip: true
        
        color: {
            if (root.useCustomColors) return root.customBarColor;
            if (root.enableErrorThreshold && root.value > root.errorThreshold) return root.errorColor;
            return root.foregroundBarColor;
        }
        
        // Foreground label (brighter)
        Text {
            text: root.label
            anchors.left: parent.left
            anchors.leftMargin: 3  // 4px from container edge - 1px margin
            anchors.verticalCenter: parent.verticalCenter
            font.pointSize: Theme.fontSizeTiny
            font.family: Theme.fontFamilyUiNf
            color: {
                if (root.useCustomColors) return root.customForegroundTextColor;
                if (root.enableErrorThreshold && root.value > root.errorThreshold) return root.errorTextColor;
                return root.foregroundTextColor;
            }
            opacity: 0.9
        }
    }
    
    // Optional mouse interaction area
    MouseArea {
        anchors.fill: parent
        enabled: root.enableMouseInteraction && root.valueChangedCallback !== null
        
        onClicked: function(mouse) {
            if (!enabled || !root.valueChangedCallback) return;
            
            // Map click position to value (account for margins)
            const clickRatio = Math.max(0, Math.min(1, (mouse.x - 1) / (width - 2)));
            root.valueChangedCallback(clickRatio);
        }
        
        onPositionChanged: function(mouse) {
            if (!enabled || !root.valueChangedCallback || !pressed) return;
            
            // Map drag position to value (account for margins)
            const dragRatio = Math.max(0, Math.min(1, (mouse.x - 1) / (width - 2)));
            root.valueChangedCallback(dragRatio);
        }
        
        onWheel: (wheel) => {
            if (!enabled || !root.valueChangedCallback) return;
            
            if (wheel.angleDelta.y > 0) {
                root.valueChangedCallback(Math.min(1.0, root.value + root.mouseStep));
            } else if (wheel.angleDelta.y < 0) {
                root.valueChangedCallback(Math.max(0.0, root.value - root.mouseStep));
            }
        }
    }
}