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
        fontFamily: "DejaVuSansM Nerd Font"
    })

    property var _data: _fallback

    property FileView _themeFile: FileView {
        path: Quickshell.env("GLOXWALD_THEME") || (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickshell-theme.json"
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
    readonly property int fontSizeSmall: Math.round(_data.fontSize * 0.9)
    readonly property string fontFamily: _data.fontFamily

    function shade(f: real): color {
        return Qt.rgba(app600.r * f, app600.g * f, app600.b * f, 1);
    }

    readonly property color textStrong: shade(0.9)
    readonly property color text: shade(0.75)
    readonly property color textDim: shade(0.5)
    readonly property color segment: Qt.rgba(app200.r, app200.g, app200.b, 0.2)
    readonly property color warning: "#ffa500"
    readonly property color launcher: "#5277c3"
    readonly property color brightness: "#bda551"
    readonly property color volume: "#7493a3"
    readonly property color headphones: "#a3746f"
}
