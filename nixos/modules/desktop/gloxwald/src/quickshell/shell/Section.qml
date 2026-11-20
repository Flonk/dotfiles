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
    readonly property url effectiveTileSource: root.tileSource != "" ? root.tileSource : ""
    readonly property real effectiveTileOpacity: root.tileSource != "" ? root.tileOpacity : (root.glassEffect ? 0.8 : root.tileOpacity)
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

        Rectangle {
            anchors.fill: parent
            color: root.backgroundColor.a < 1.0 ? "#000000" : root.backgroundColor
            visible: root.glassEffect
        }

        // Tiled background overlay
        Image {
            anchors.fill: parent
            source: root.effectiveTileSource
            fillMode: Image.Tile
            opacity: root.effectiveTileOpacity
            visible: root.effectiveTileSource != ""
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
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.5) }
                GradientStop { position: 0.25; color: Qt.rgba(1, 1, 1, 0.1) }
                GradientStop { position: 0.5; color: "transparent" }
                GradientStop { position: 0.75; color: Qt.rgba(0, 0, 0, 0.2) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.6) }
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