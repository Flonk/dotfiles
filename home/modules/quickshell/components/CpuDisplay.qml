// CpuDisplay.qml
import QtQuick
import QtQuick.Controls

Row {
    id: root
    spacing: 3
    
    property int barWidth: 4
    property int barSpacing: 1
    property int topRadius: 2
    property int bottomRadius: 2
    property int maxBarHeight: 30
    property int horizontalPadding: 5
    
    Item {
        id: cpuDisplayRoot
        width: (SystemMonitor.coreCount * root.barWidth) + ((SystemMonitor.coreCount - 1) * root.barSpacing) + (root.horizontalPadding * 2)
        height: root.maxBarHeight

        // CPU label at top left
        Text {
            text: "CPU"
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: root.horizontalPadding
            anchors.topMargin: 3
            font.pointSize: Theme.fontSizeSmall
            font.family: Theme.fontFamilyUiNf
            color: Theme.app400
            opacity: 0.7
            z: 0
        }

        // Percentage text at top right
        Text {
            id: percentText
            text: Math.round(SystemMonitor.cpuUsage * 100)
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: root.horizontalPadding
            anchors.topMargin: 3
            font.pointSize: Theme.fontSizeBig
            font.family: Theme.fontFamilyUiNf
            color: Theme.app600
            z: 3
            opacity: 0.8
        }

        Row {
            id: barRow
            anchors.fill: parent
            anchors.margins: 0
            anchors.leftMargin: root.horizontalPadding
            anchors.rightMargin: root.horizontalPadding
            spacing: root.barSpacing
            z: 2
            Repeater {
                model: SystemMonitor.coreCount
                Rectangle {
                    width: root.barWidth
                    height: Math.max(1, cpuDisplayRoot.height * (SystemMonitor.coreUsages[index] || 0))
                    radius: root.topRadius
                    anchors.bottom: parent.bottom
                    color: {
                        const usage = SystemMonitor.coreUsages[index] || 0;
                        if (usage > 0.9) return Theme.error400;  // CPU >90%
                        return Theme.wm800;  // normal bars
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }
    }
}