pragma Singleton
import QtQuick

QtObject {
    readonly property int band: 40
    readonly property int border: 4
    readonly property int gapsOut: 12
    readonly property int radius: 13
    readonly property int outerRadius: 17
    readonly property int windowRadius: 8
    readonly property int windowBorder: 2
    readonly property real turn: 110 * Math.PI / 180
    readonly property int markSize: 26

    readonly property color accent: "#f6722b"
    readonly property color accent2: "#ffa203"
    readonly property color accent3: "#facb4c"
    readonly property color ground: "#100e0a"
    readonly property color ink: "#000000"
    readonly property color cream: "#ddd6c4"

    readonly property int labelSize: 10
    readonly property real labelTracking: 1.2
    readonly property int titleSize: 13
}
