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
    property color backgroundColor: Theme.app700
    property int horizontalPadding: 4
    property int verticalPadding: 3
    property int maxContentHeight: 150
    property alias contentItem: contentContainer
    property bool headerRightClickEnabled: false
    property bool disabled: false
    property real iconRotation: 0
    property real iconScale: 1.0
    property Component headerContent: null
    property int headerHeight: 28
    
    signal headerRightClicked()
    
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
        height: root.headerHeight
        color: root.disabled ? "transparent" : root.backgroundColor
        border.color: root.disabled ? Theme.error600 : "transparent"
        border.width: root.disabled ? 2 : 0
        radius: 0
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton && root.headerRightClickEnabled) {
                    root.headerRightClicked();
                } else if (mouse.button === Qt.LeftButton) {
                    root.expanded = !root.expanded;
                }
            }
        }
        Loader {
            id: headerContentLoader
            anchors.fill: parent
            sourceComponent: root.headerContent
            active: root.headerContent !== null
        }

        Text {
            anchors.centerIn: parent
            text: root.icon
            font.pointSize: 9 * root.iconScale
            font.family: Theme.fontFamily
            color: root.disabled ? Theme.error600 : Theme.app100
            opacity: 0.95
            rotation: root.iconRotation
            visible: !headerContentLoader.active
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
