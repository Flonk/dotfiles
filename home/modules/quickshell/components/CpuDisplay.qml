// CpuDisplay.qml
import QtQuick
import QtQuick.Controls

Item {
    id: root
    
    property int barWidth: 4
    property int barSpacing: 1
    property int topRadius: 2
    property int bottomRadius: 2
    property int maxBarWidth: 30
    property string cpuIcon: "\uf4bc"
    property int iconLeftPadding: 0
    property bool fillFromRight: false
    property int horizontalPadding: 2
    property int barHeight: 16  // Fixed height for vertical bars
    
    width: parent.width
    implicitHeight: {
        const topMargin = 0;
        const spacing = 2;
        const bottomPadding = 0;
        return topMargin + labelColumn.implicitHeight + spacing + root.barHeight + bottomPadding;
    }
    height: implicitHeight
    
    Item {
        id: cpuDisplayRoot
        anchors.fill: parent
        anchors.topMargin: 0  // Top padding
        anchors.bottomMargin: 0  // Bottom padding
        width: parent.width

        // Icon + percentage line (top)
        KeyValuePair {
            id: labelColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            label: root.cpuIcon
            value: Math.round(SystemMonitor.cpuUsage * 100).toString()
            labelPointSize: Theme.fontSizeNormal
            valuePointSize: Theme.fontSizeNormal
            labelLeftPadding: root.iconLeftPadding
        }

        Row {
            id: barRow
            anchors.top: labelColumn.bottom
            anchors.topMargin: 2
            anchors.left: parent.left
            anchors.leftMargin: 0
            anchors.right: parent.right
            anchors.rightMargin: 0
            height: root.barHeight
            spacing: root.barSpacing
            z: 2
            Repeater {
                model: SystemMonitor.coreCount
                delegate: Item {
                    width: {
                        const totalSpacing = (SystemMonitor.coreCount - 1) * root.barSpacing;
                        const availableWidth = barRow.width - totalSpacing;
                        return Math.floor(availableWidth / SystemMonitor.coreCount);
                    }
                    height: barRow.height
                    
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height * (SystemMonitor.coreUsages[index] || 0)
                        color: {
                            const usage = SystemMonitor.coreUsages[index] || 0;
                            if (usage > 0.9) return Theme.error400;
                            return Theme.app600;
                        }
                    }
                }
            }
        }
    }
}