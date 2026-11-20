pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var _palette: ({ accent2: "#69b1e0" })

    property FileView _paletteFile: FileView {
        path: Quickshell.shellPath("chrome/palette.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root._palette = JSON.parse(text());
            } catch (e) {
                console.warn("[T3] Failed to parse palette.json:", e);
            }
        }
    }

    readonly property int band: 40
    readonly property int border: 4
    readonly property int radius: 13
    readonly property int outerRadius: 17
    readonly property int windowBorder: 2
    readonly property int markSize: 26

    readonly property color accent2: _palette.accent2
    readonly property color ground: Theme.ground
    readonly property color ink: "#000000"
    readonly property color cream: "#ddd6c4"

    readonly property int labelSize: 10
    readonly property real labelTracking: 1.2
    readonly property int titleSize: 13
}
