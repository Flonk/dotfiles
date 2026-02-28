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
    property alias radius: sectionRect.radius
    property color backgroundColor: "#000000"
    property color topBorderColor: Theme.app200
    property int topBorderHeight: 1
    property bool showTopBorder: true
    property color bottomBorderColor: Theme.app200
    property int bottomBorderHeight: 0
    property bool showBottomBorder: false
    clip: true
    
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
        border.color: "transparent"
        border.width: 0
        radius: 0
        
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
    }
    
    // Size based on first child's size
    implicitWidth: contentItem.childrenRect.width + leftPadding + rightPadding + leftMargin + rightMargin
    implicitHeight: contentItem.childrenRect.height + topPadding + bottomPadding + topMargin + bottomMargin
    
    // Use implicit size by default
    width: parent ? parent.width : implicitWidth
    height: implicitHeight
}
