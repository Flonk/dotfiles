// Section.qml - A container component for grouping related UI elements
import QtQuick

Item {
    id: root
    
    // Margin around the section
    property int topMargin: 0
    property int bottomMargin: 0
    property int leftMargin: 0
    property int rightMargin: 0
    
    // Padding inside the section
    property int padding: 0
    property int topPadding: padding
    property int bottomPadding: padding
    property int leftPadding: padding
    property int rightPadding: padding
    
    // Visual properties
    property int radius: 0
    property color backgroundColor: "#000000"
    property url tileSource: ""
    property real tileOpacity: 1.0
    property bool glassEffect: false
    property color topBorderColor: Theme.app200
    property int topBorderHeight: 1
    property bool showTopBorder: true
    property color bottomBorderColor: Theme.app200
    property int bottomBorderHeight: 0
    property bool showBottomBorder: false
    clip: false
    
    // Default container for children
    default property alias contentData: contentItem.children
    
    // The actual visual section with styling
    Rectangle {
        id: sectionRect
        anchors.fill: parent
        anchors.topMargin: root.topMargin
        anchors.bottomMargin: root.bottomMargin
        anchors.leftMargin: root.leftMargin
        anchors.rightMargin: root.rightMargin
        
        color: root.backgroundColor
        border.color: root.glassEffect ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        border.width: root.glassEffect ? 1 : 0
        radius: root.radius
        layer.enabled: root.radius > 0

        // Tiled background overlay
        Image {
            anchors.fill: parent
            source: root.tileSource
            fillMode: Image.Tile
            opacity: root.tileOpacity
            visible: root.tileSource != ""
        }
        
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.topBorderHeight
            visible: root.showTopBorder && root.topBorderHeight > 0
            color: root.topBorderColor
        }
        
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.bottomBorderHeight
            visible: root.showBottomBorder && root.bottomBorderHeight > 0
            color: root.bottomBorderColor
        }
        
        // Content item with padding
        Item {
            id: contentItem
            anchors.fill: parent
            anchors.topMargin: root.topPadding
            anchors.bottomMargin: root.bottomPadding
            anchors.leftMargin: root.leftPadding
            anchors.rightMargin: root.rightPadding
        }

        // Glassy emboss gradient overlay
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            visible: root.glassEffect
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.2) }
                GradientStop { position: 0.3; color: "transparent" }
                GradientStop { position: 0.8; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.3) }
            }
        }
    }
    
    // Size based on first child's size
    implicitWidth: contentItem.childrenRect.width + leftPadding + rightPadding + leftMargin + rightMargin
    implicitHeight: contentItem.childrenRect.height + topPadding + bottomPadding + topMargin + bottomMargin
    
    // Use implicit size by default
    width: parent ? parent.width : implicitWidth
    height: implicitHeight
}