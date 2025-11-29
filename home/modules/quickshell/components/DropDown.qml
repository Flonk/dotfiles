// DropDown.qml - Expandable dropdown section
import QtQuick
import QtQuick.Controls

Item {
    id: root
    
    property string label: ""
    property string icon: ""
    property int iconLeftPadding: 0
    property bool expanded: false
    property color textColor: Theme.app600
    property color backgroundColor: "#000000"
    property int horizontalPadding: 4
    property int verticalPadding: 3
    property int maxContentHeight: 150
    property alias contentItem: contentContainer
    
    default property alias content: contentContainer.children
    
    width: parent ? parent.width : implicitWidth
    implicitWidth: parent ? parent.width : 200
    implicitHeight: expanded ? headerItem.height + Math.min(contentContainer.childrenRect.height, maxContentHeight) : headerItem.height
    height: implicitHeight
    
    Behavior on implicitHeight {
        NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
    }
    
    Rectangle {
        id: headerItem
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28
        color: Theme.app700 // blue background
        radius: 0
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.expanded = !root.expanded;
            }
        }
        Text {
            anchors.centerIn: parent
            text: root.icon
            font.pointSize: 9
            font.family: Theme.fontFamilyUiNf
            color: Theme.app100 // dark text
            opacity: 0.95
        }
    }
    
    // Content container
    Item {
        id: contentWrapper
        anchors.top: headerItem.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.expanded ? Math.min(contentContainer.childrenRect.height, root.maxContentHeight) : 0
        clip: true
        
        Behavior on height {
            NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
        }
        
        Flickable {
            id: flickable
            anchors.fill: parent
            contentHeight: contentContainer.childrenRect.height
            boundsBehavior: Flickable.StopAtBounds
            
            Item {
                id: contentContainer
                width: flickable.width
                height: childrenRect.height
            }
        }
        
        // Custom scrollbar
        Rectangle {
            id: scrollbar
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 2
            color: "transparent"
            visible: flickable.contentHeight > flickable.height
            
            Rectangle {
                width: parent.width
                height: Math.max(20, flickable.height * (flickable.height / flickable.contentHeight))
                y: flickable.contentY * (flickable.height / flickable.contentHeight)
                color: root.textColor
                opacity: 0.6
            }
        }
    }
}
