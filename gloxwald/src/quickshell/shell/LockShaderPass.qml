import QtQuick
import Quickshell
import Quickshell.Io

ShaderEffect {
    id: pass

    property var context
    property int frameCount: 0
    property var dummyTexture
    property bool interactive: false
    property string shaderName: ""
    property string authorText: ""

    // Paths resolve relative to the instantiating file (shell/shaders/scenes/),
    // not this component file, so we go up one level to shell/shaders/
    vertexShader: shaderName ? "../default.vert.qsb" : ""
    fragmentShader: shaderName
        ? "../" + shaderName + ".frag.qsb" + (_dev ? "?b=" + _boot + "&r=" + _rev : "")
        : ""

    // dev hot-reload (preview only): with $SHADER_DEV set, watch the compiled
    // .qsb and bump the url query on change — Qt keys shader loads by full
    // url, so the effect reloads in place; the query is dropped again when
    // the url is resolved to a file path
    property bool _dev: Quickshell.env("SHADER_DEV") === "1"
    property int _rev: 0
    readonly property double _boot: Date.now()
    FileView {
        path: pass._dev && pass.shaderName
            ? Qt.resolvedUrl("shaders/" + pass.shaderName + ".frag.qsb")
                .toString().replace(/^file:\/\//, "")
            : ""
        watchChanges: true
        onFileChanged: reloadDebounce.restart()
    }
    Timer {
        id: reloadDebounce
        interval: 200
        onTriggered: pass._rev++
    }

    property vector3d iResolution: Qt.vector3d(width, height, 1.0)
    property real iTime: context ? context.elapsedTime : 0
    property int iFrame: frameCount
    property vector4d iMouse: Qt.vector4d(0, 0, 0, 0)
    property vector4d iClock: Qt.vector4d(0, 0, 0, 0)
    property vector4d u_clock_prev: Qt.vector4d(0, 0, 0, 0)
    property real u_clock_at: -1000
    property matrix4x4 u_bodies: Qt.matrix4x4(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    property matrix4x4 u_planets: Qt.matrix4x4(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    readonly property real u_algol: {
        const jd = Date.now() / 86400000 + 2440587.5;
        const P = 2.867328;
        const ph = (((jd - 2445641.5135) / P) % 1 + 1) % 1;
        const h = (ph > 0.5 ? ph - 1 : ph) * P * 24;
        return 2.1 + 1.3 * Math.exp(-(h / 2.6) * (h / 2.6));
    }
    readonly property real u_lst: {
        const days = Date.now() / 86400000 + 2440587.5 - 2451545.0;
        const hours = 18.697374558 + 24.06570982441908 * days + 16.3738 / 15;
        return (((hours % 24) + 24) % 24) / 24 * 2 * Math.PI;
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let d = new Date();
            let h = d.getHours();
            let m = d.getMinutes();
            let c = Qt.vector4d(Math.floor(h / 10), h % 10, Math.floor(m / 10), m % 10);
            if (!c.fuzzyEquals(pass.iClock)) {
                pass.u_clock_prev = pass.iClock;
                pass.u_clock_at = pass.iTime;
                pass.iClock = c;
            }
        }
    }

    // 32 random floats, rolled once when the pass is created — shaders read
    // them via sk_seed(i) to vary per session
    readonly property matrix4x4 iSeed0: _randMat()
    readonly property matrix4x4 iSeed1: _randMat()
    function _randMat() {
        let v = [];
        for (let i = 0; i < 16; i++) v.push(Math.random());
        return Qt.matrix4x4(...v);
    }

    property var iChannel0: dummyTexture
    property var iChannel1: dummyTexture
    property var iChannel2: dummyTexture
    property var iChannel3: dummyTexture
    property var iChannel4: dummyTexture
    property var iChannel5: dummyTexture
    property var iChannel6: dummyTexture
    property var iChannel7: dummyTexture
    property var iChannel8: dummyTexture
    property var iChannel9: dummyTexture
    property var iChannel10: dummyTexture
    property var iChannel11: dummyTexture
    property var iChannel12: dummyTexture
    property var iChannel13: dummyTexture
    property var iChannel14: dummyTexture
    property var iChannel15: dummyTexture
    property var iChannel16: dummyTexture
    property var iChannel17: dummyTexture
    property var iChannel18: dummyTexture
    property var iChannel19: dummyTexture
    property var iChannel20: dummyTexture
    property var iChannel21: dummyTexture
    property var iChannel22: dummyTexture

    property int u_indicator_type: 0
    property vector3d u_indicator_color: Qt.vector3d(1, 1, 1)
    property real u_last_key_time: context ? context.lastKeyTime : 0
    property real u_last_failed_unlock_time: context ? context.lastFailedUnlockTime : 0
    property real u_auth_started_time: context ? context.authStartedTime : 0
    property vector2d u_key_bases: context ? Qt.vector2d(context.keypulseBase, context.keyBase) : Qt.vector2d(0, 0)
    property int u_dev_mode: context ? context.devMode : -1
    property real u_dev_mode_at: context ? context.devModeAt : 0
    property real u_dev_gold_at: context ? context.devGoldAt : -1000
    property int u_dev_prev_mode: context ? context.devPrevMode : -1
    property real u_dev_prev_at: context ? context.devPrevAt : 0
    property real u_dev_switch_at: context ? context.devSwitchAt : -1000
    property real u_solid_matte: context ? context.solidMatte : 0
    property vector2d u_prism_beam: context ? context.prismBeam : Qt.vector2d(0, 0)
    property real u_prism_chunk: 0
    property vector4d u_prism_ray: Qt.vector4d(0, 0, 0, 0)
    property real u_aspect: height > 0 ? width / height : 1
    property vector4d u_seq: context ? context.seqA : Qt.vector4d(0, 0, 0, 0)
    property vector4d u_seq2: context ? context.seqB : Qt.vector4d(0, 0, 0, 0)
    property int u_traffic_map: context ? context.trafficMap : 0
    property int u_traffic_cars: context ? context.trafficCars : -1
    property int u_traffic_debug: context ? (context.trafficDebug ? 1 : 0) + (context.trafficMinimap ? 2 : 0) + (context.trafficMeter ? 4 : 0) + (context.trafficStuck ? 8 : 0) + (context.showGrid ? 16 : 0) : 0
}
