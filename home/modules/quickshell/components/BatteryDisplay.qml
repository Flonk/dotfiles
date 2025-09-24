// BatteryDisplay.qml
import QtQuick
import QtQuick.Controls

Row {
    id: root
    
    spacing: 3
    visible: BatteryWidget.hasBattery

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: BatteryWidget.getBatteryIcon ? BatteryWidget.getBatteryIcon() : "🔋"
        font.pointSize: Theme.fontSizeNormal
        font.family: Theme.fontFamilyUiNf
        color: Theme.app400
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: BatteryWidget.batteryText || "---"
        font.pointSize: Theme.fontSizeNormal
        font.family: Theme.fontFamilyUiNf
        color: {
            if (!BatteryWidget.hasBattery) return Theme.app200;  // borders
            if (BatteryWidget.isCharging) return Theme.wm800;  // charging uses wm800
            if (BatteryWidget.batteryLevel < 0.2) return Theme.error400;  // low battery
            return Theme.app400;  // normal text color
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: BatteryWidget.getChargingIndicator ? BatteryWidget.getChargingIndicator() : ""
        font.pointSize: Theme.fontSizeSmall
        font.family: Theme.fontFamilyUiNf
        color: Theme.wm800  // charging indicator
        visible: BatteryWidget.isCharging
    }
}