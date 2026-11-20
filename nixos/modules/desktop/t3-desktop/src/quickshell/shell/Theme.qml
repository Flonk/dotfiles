pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property var _fallback: ({
        fontSize: 9,
        app100: "#0b0e14",
        app150: "#131721",
        app200: "#202229",
        app600: "#e6e1cf",
        app700: "#3e4b59",
        app800: "#ece8db",
        app900: "#f2f0e7",
        wm800: "#ff9624",
        error400: "#f07178",
        error600: "#ff8f40",
        success600: "#aad94c",
        ground: "#100e0a",
        labelSize: 10,
        labelTracking: 1.2,
        fontFamily: "DejaVuSansM Nerd Font"
    })

    property var _data: _fallback

    property FileView _themeFile: FileView {
        path: Quickshell.env("T3_DESKTOP_THEME") || (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickshell-theme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root._data = Object.assign({}, root._fallback, JSON.parse(text()));
            } catch (e) {
                console.warn("[Theme] Failed to parse theme.json:", e);
                root._data = root._fallback;
            }
        }
    }

    readonly property color app100: _data.app100
    readonly property color app150: _data.app150
    readonly property color app200: _data.app200
    readonly property color app600: _data.app600
    readonly property color app700: _data.app700
    readonly property color app800: _data.app800
    readonly property color app900: _data.app900
    readonly property color wm800: _data.wm800
    readonly property color error400: _data.error400
    readonly property color error600: _data.error600
    readonly property color success600: _data.success600
    readonly property color ground: _data.ground
    readonly property string fontFamily: _data.fontFamily
    readonly property int labelSize: _data.labelSize ?? 10
    readonly property real labelTracking: _data.labelTracking ?? 1.2
}
