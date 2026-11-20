import QtQuick
import Quickshell.Hyprland

Row {
    id: root
    required property var monitor

    readonly property var workspaces: (Hyprland.workspaces?.values ?? [])
        .filter(w => w?.monitor && root.monitor && w.monitor.name === root.monitor.name)
        .sort((a, b) => {
            const x = parseInt(a.name), y = parseInt(b.name);
            return isNaN(x) || isNaN(y) ? a.name.localeCompare(b.name) : x - y;
        })

    Repeater {
        model: root.workspaces

        BarSegment {
            required property var modelData
            padding: 12
            text: modelData.name
            color: modelData.focused ? Theme.wm800 : "transparent"
            textColor: modelData.focused ? Theme.app150 : Theme.app600
            clickable: true
            onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${modelData.name} })`)
        }
    }
}
