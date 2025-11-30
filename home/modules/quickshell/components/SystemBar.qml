// SystemBar.qml - Two-line system bar: label+percentage, then horizontal mini-bar
import QtQuick
import Quickshell

Item {
    id: root
    
    // Public properties
    property string label: ""
    property real value: 0.0  // 0.0 to 1.0
    property color textColor: Theme.app600
    property color errorColor: Theme.error400
    property real errorThreshold: 0.9
    property bool enableErrorThreshold: true
    property string icon: ""
    property bool displayAsPercent: true
    property string valueSuffix: ""
    readonly property string formattedValue: displayAsPercent
        ? Math.round(root.value * 100).toString() + root.valueSuffix
        : root.value.toString()
    
    // Custom color override
    property color customTextColor: "transparent"
    property bool useCustomColors: false
    
    // Mouse interaction
    property bool enableMouseInteraction: false
    property var valueChangedCallback: null
    property real mouseStep: 0.01
    
    // Layout options
    property int verticalPadding: 3
    property int iconLeftPadding: 0
    property int iconPointSize: Theme.fontSizeBig
    property int valuePointSize: Theme.fontSizeBig
    implicitHeight: contentColumn.implicitHeight
    height: implicitHeight

    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Item { width: 1; height: root.verticalPadding }

        KeyValuePair {
            id: labelLine
            width: parent.width
            label: root.icon !== "" ? root.icon : root.label
            value: root.formattedValue
            labelLeftPadding: root.iconLeftPadding
            labelPointSize: root.iconPointSize
            valuePointSize: root.valuePointSize
            labelColor: {
                if (root.useCustomColors) return root.customTextColor;
                return root.textColor;
            }
            valueColor: {
                if (root.useCustomColors) return root.customTextColor;
                if (root.enableErrorThreshold && root.value > root.errorThreshold) return root.errorColor;
                return root.textColor;
            }
        }

        Item { width: parent.width; height: root.verticalPadding }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enableMouseInteraction && root.valueChangedCallback !== null
        onClicked: function(mouse) {
            if (!enabled || !root.valueChangedCallback) return;
            const clickRatio = Math.max(0, Math.min(1, mouse.x / width));
            root.valueChangedCallback(clickRatio);
        }
        onPositionChanged: function(mouse) {
            if (!enabled || !root.valueChangedCallback || !pressed) return;
            const dragRatio = Math.max(0, Math.min(1, mouse.x / width));
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