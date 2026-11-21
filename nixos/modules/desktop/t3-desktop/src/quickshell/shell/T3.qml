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

    readonly property int band: 47
    readonly property int border: 4
    readonly property int radius: 13
    readonly property int outerRadius: 17
    readonly property int windowBorder: 2
    readonly property int markSize: 26

    readonly property color accent2: _palette.accent2
    readonly property color ground: Theme.ground
    readonly property color ink: "#000000"
    readonly property color cream: "#ddd6c4"

    readonly property int labelSize: Theme.labelSize
    readonly property real labelTracking: Theme.labelTracking
    readonly property int titleSize: 13

    readonly property color rest: Qt.rgba(0.16 + 0.84 * ground.r, 0.16 + 0.84 * ground.g, 0.16 + 0.84 * ground.b, 1)
    readonly property real lift: 0.2

    function lighten(c, by) {
        const dec = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        const enc = v => v <= 0.0031308 ? 12.92 * v : 1.055 * Math.pow(v, 1 / 2.4) - 0.055;
        const r = dec(c.r), g = dec(c.g), b = dec(c.b);
        const l1 = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
        const m1 = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
        const s1 = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
        const L = 0.2104542553 * l1 + 0.793617785 * m1 - 0.0040720468 * s1;
        const A = 1.9779984951 * l1 - 2.428592205 * m1 + 0.4505937099 * s1;
        const B = 0.0259040371 * l1 + 0.7827717662 * m1 - 0.808675766 * s1;
        const lifted = Math.min(1, Math.max(0, L + by * (1 - L)));
        const toLin = k => {
            const l = Math.pow(lifted + 0.3963377774 * A * k + 0.2158037573 * B * k, 3);
            const m = Math.pow(lifted - 0.1055613458 * A * k - 0.0638541728 * B * k, 3);
            const s = Math.pow(lifted - 0.0894841775 * A * k - 1.291485548 * B * k, 3);
            return [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, -0.0041960863 * l - 0.7034186147 * m + 1.7076147022 * s];
        };
        const fits = k => toLin(k).every(v => v >= -1e-4 && v <= 1 + 1e-4);
        let k = 1;
        if (!fits(1)) {
            let lo = 0, hi = 1;
            for (let i = 0; i < 24; i++) {
                const mid = (lo + hi) / 2;
                if (fits(mid)) lo = mid; else hi = mid;
            }
            k = lo;
        }
        const out = toLin(k).map(v => enc(Math.min(1, Math.max(0, v))));
        return Qt.rgba(out[0], out[1], out[2], 1);
    }
}
