import QtQuick
import Quickshell.Io
import "../.."
Item {
    id: scene
    property var context
    property int frameCount: 0
    property var dummyTexture
    readonly property string authorText: "'yamp' by Flonk"
    readonly property bool interactive: true

    Image { id: tex; source: "../assets/yamp_sdf.png"; visible: false; onStatusChanged: scene.rebake() }
    ShaderEffectSource { id: texSrc; sourceItem: tex; hideSource: true }
    Image { id: noise; source: "../assets/random.png"; visible: false; onStatusChanged: scene.rebake() }
    ShaderEffectSource { id: noiseSrc; sourceItem: noise; hideSource: true }
    Image { id: photo; source: "../assets/clouds_photo.jpg"; visible: false; onStatusChanged: scene.rebake() }
    ShaderEffectSource {
        id: photoSrc; sourceItem: photo; hideSource: true
        wrapMode: ShaderEffectSource.Repeat
    }
    Image { id: flapFont; source: "../assets/flap_font.png"; visible: false }
    ShaderEffectSource { id: flapFontSrc; sourceItem: flapFont; hideSource: true }
    Image { id: sky; source: "../assets/sky.png"; visible: false; smooth: false }
    // the map data reloads when gen-maps rewrites it: images are cached by
    // url, so a bumped query (dropped when resolved to a file) forces a read
    property int mapsRev: Date.now() % 100000
    Image { id: maps; source: "../assets/maps.png?r=" + scene.mapsRev; visible: false; smooth: false; cache: false; onStatusChanged: if (status === Image.Ready) mapStaticSrc.scheduleUpdate() }
    FileView {
        path: Qt.resolvedUrl("../assets/maps.png").toString().replace(/^file:\/\//, "")
        watchChanges: true
        onFileChanged: scene.mapsRev++
    }
    ShaderEffectSource { id: mapsSrc; sourceItem: maps; hideSource: true; smooth: false }
    Image { id: mapLabels; source: "../assets/map_labels.png?r=" + scene.mapsRev; visible: false; cache: false }
    ShaderEffectSource { id: mapLabelsSrc; sourceItem: mapLabels; hideSource: true }
    ShaderEffectSource { id: skySrc; sourceItem: sky; hideSource: true; smooth: false }
    Image { id: labels; source: "../assets/penrose_labels.png"; visible: false; onStatusChanged: scene.rebake() }
    ShaderEffectSource { id: labelsSrc; sourceItem: labels; hideSource: true }

    readonly property int modeCount: 17
    readonly property int scopeMode: 7
    function modeLive(t, mode, at, m) {
        if (context.heldSeq) return context.seqInfo[0] === m;
        const pl = context.modeOrder, dur = pl.map(x => context.modeDurations[x]);
        const total = dur.reduce((a, b) => a + b, 0);
        const since = mode >= 0 ? t - at : t;
        let skip = 0;
        if (mode >= 0) for (let i = 0; i < Math.max(pl.indexOf(mode), 0); i++) skip += dur[i];
        const c = ((since + skip) % total + total) % total;
        let acc = 0, slot = 0;
        while (slot < pl.length - 1 && c >= acc + dur[slot]) acc += dur[slot++];
        const mt = c - acc;
        const tr = context.transitionModes.indexOf(pl[slot]) >= 0;
        return pl[slot] === m || (tr && (pl[(slot + pl.length - 1) % pl.length] === m || pl[(slot + 1) % pl.length] === m));
    }
    readonly property bool scopeLive: context ? modeLive(context.elapsedTime, context.devMode, context.devModeAt, scopeMode)
        || (context.elapsedTime - context.devSwitchAt < 1 && modeLive(context.devSwitchAt, context.devPrevMode, context.devPrevAt, scopeMode)) : false
    readonly property bool gravityLive: context ? modeLive(context.elapsedTime, context.devMode, context.devModeAt, 11)
        || (context.elapsedTime - context.devSwitchAt < 1 && modeLive(context.devSwitchAt, context.devPrevMode, context.devPrevAt, 11)) : false
    readonly property bool fishLive: context ? modeLive(context.elapsedTime, context.devMode, context.devModeAt, 25)
        || (context.elapsedTime - context.devSwitchAt < 1 && modeLive(context.devSwitchAt, context.devPrevMode, context.devPrevAt, 25)) : false
    readonly property bool trafficLive: context ? modeLive(context.elapsedTime, context.devMode, context.devModeAt, 26)
        || (context.elapsedTime - context.devSwitchAt < 1 && modeLive(context.devSwitchAt, context.devPrevMode, context.devPrevAt, 26)) : false
    onTrafficLiveChanged: if (trafficLive && context && !context.trafficMapPinned)
        context.trafficMap = Math.floor(Math.random() * context.trafficMapNames.length)
    readonly property bool conveyorLive: context ? modeLive(context.elapsedTime, context.devMode, context.devModeAt, 27)
        || (context.elapsedTime - context.devSwitchAt < 1 && modeLive(context.devSwitchAt, context.devPrevMode, context.devPrevAt, 27)) : false
    readonly property bool fluidLive: context ? modeLive(context.elapsedTime, context.devMode, context.devModeAt, 12)
        || (context.elapsedTime - context.devSwitchAt < 1 && modeLive(context.devSwitchAt, context.devPrevMode, context.devPrevAt, 12)) : false
    // the post pass (FXAA) only runs for the modes that ask for it (MODE_AA,
    // the 3d ones); otherwise the main pass draws straight to the screen
    readonly property bool aaLive: context ? [3, 4, 5].some(m => modeLive(context.elapsedTime, context.devMode, context.devModeAt, m)) : true
    readonly property bool starsLive: context ? modeLive(context.elapsedTime, context.devMode, context.devModeAt, 15)
        || (context.elapsedTime - context.devSwitchAt < 1 && modeLive(context.devSwitchAt, context.devPrevMode, context.devPrevAt, 15)) : false

    readonly property matrix4x4 planets: {
        const T = (Date.now() / 86400000 + 2440587.5 - 2451545.0) / 36525;
        const r = Math.PI / 180;
        const el = [
            [0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255,
             0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418],
            [1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891,
             0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343],
            [5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909,
             -0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106],
            [9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448,
             -0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794]];
        const earth = [1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0,
                       0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0];
        const mags = [-4.2, 0.6, -2.3, 0.8];
        function helio(p) {
            const v = i => p[i] + p[i + 6] * T;
            const a = v(0), e = v(1), I = v(2) * r, L = v(3), w = v(4), O = v(5);
            const M = ((L - w) % 360) * r, om = (w - O) * r, Om = O * r;
            let E = M;
            for (let i = 0; i < 8; i++) E = M + e * Math.sin(E);
            const xp = a * (Math.cos(E) - e), yp = a * Math.sqrt(1 - e * e) * Math.sin(E);
            const co = Math.cos(om), so = Math.sin(om), cO = Math.cos(Om), sO = Math.sin(Om), cI = Math.cos(I), sI = Math.sin(I);
            return [(co * cO - so * sO * cI) * xp + (-so * cO - co * sO * cI) * yp,
                    (co * sO + so * cO * cI) * xp + (-so * sO + co * cO * cI) * yp,
                    so * sI * xp + co * sI * yp];
        }
        const g = helio(earth), eps = 23.43928 * r, m = new Array(16).fill(0);
        for (let p = 0; p < 4; p++) {
            const h = helio(el[p]);
            const x = h[0] - g[0], y = h[1] - g[1], z = h[2] - g[2];
            const v = [x, y * Math.cos(eps) - z * Math.sin(eps), y * Math.sin(eps) + z * Math.cos(eps)];
            const n = Math.hypot(v[0], v[1], v[2]);
            for (let c = 0; c < 3; c++) m[c * 4 + p] = v[c] / n;
            m[12 + p] = mags[p];
        }
        return Qt.matrix4x4(...m);
    }
    property var issTle: null
    property matrix4x4 bodies: Qt.matrix4x4(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    Process {
        running: true
        command: ["sh", "-c", "f=\"${XDG_CACHE_HOME:-$HOME/.cache}/gloxwald-iss.tle\"; if [ ! -s \"$f\" ] || [ -n \"$(find \"$f\" -mmin +360)\" ]; then curl -sf --max-time 8 'https://celestrak.org/NORAD/elements/gp.php?CATNR=25544&FORMAT=TLE' -o \"$f.tmp\" && mv \"$f.tmp\" \"$f\"; fi; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: scene.issTle = scene.parseTle(text)
        }
    }
    Timer {
        interval: 200
        running: scene.starsLive
        repeat: true
        triggeredOnStart: true
        onTriggered: scene.bodies = scene.computeBodies(Date.now())
    }
    function parseTle(text) {
        const l = text.split("\n").map(s => s.trim());
        const a = l.find(s => s.startsWith("1 ")), b = l.find(s => s.startsWith("2 "));
        if (!a || !b) return null;
        const yy = parseInt(a.substr(18, 2)), doy = parseFloat(a.substr(20, 12));
        const year = yy < 57 ? 2000 + yy : 1900 + yy;
        return {
            epoch: Date.UTC(year, 0, 1) / 86400000 + 2440587.5 + doy - 1,
            ndot: parseFloat(a.substr(33, 10)),
            inc: parseFloat(b.substr(8, 8)),
            raan: parseFloat(b.substr(17, 8)),
            ecc: parseFloat("0." + b.substr(26, 7)),
            argp: parseFloat(b.substr(34, 8)),
            m0: parseFloat(b.substr(43, 8)),
            n: parseFloat(b.substr(52, 11))
        };
    }
    function computeBodies(ms) {
        const r = Math.PI / 180, jd = ms / 86400000 + 2440587.5, d = jd - 2451545.0;
        const eps = 23.43928 * r, lat = 48.2082 * r, lon = 16.3738 * r;
        const eq = (l, b) => [Math.cos(b) * Math.cos(l), Math.cos(b) * Math.sin(l) * Math.cos(eps) - Math.sin(b) * Math.sin(eps),
                              Math.cos(b) * Math.sin(l) * Math.sin(eps) + Math.sin(b) * Math.cos(eps)];
        const norm = v => { const n = Math.hypot(v[0], v[1], v[2]); return [v[0] / n, v[1] / n, v[2] / n]; };
        const gmst = (280.46061837 + 360.98564736629 * d) * r;
        const obs = t => [6371 * Math.cos(lat) * Math.cos(t + lon), 6371 * Math.cos(lat) * Math.sin(t + lon), 6371 * Math.sin(lat)];
        const g = (357.529 + 0.98560028 * d) * r;
        const sun = eq((280.459 + 0.98564736 * d + 1.915 * Math.sin(g) + 0.020 * Math.sin(2 * g)) * r, 0);
        const L = 218.316 + 13.176396 * d, Mm = (134.963 + 13.064993 * d) * r, F = (93.272 + 13.229350 * d) * r;
        const dist = 385001 - 20905 * Math.cos(Mm);
        const mg = eq((L + 6.289 * Math.sin(Mm)) * r, 5.128 * Math.sin(F) * r).map(c => c * dist);
        const o = obs(gmst);
        const moon = norm([mg[0] - o[0], mg[1] - o[1], mg[2] - o[2]]);
        const illum = (1 - (moon[0] * sun[0] + moon[1] * sun[1] + moon[2] * sun[2])) / 2;
        const m = new Array(16).fill(0);
        const put = (c, v, w) => { m[c] = v[0]; m[4 + c] = v[1]; m[8 + c] = v[2]; m[12 + c] = w; };
        put(0, moon, illum);
        put(1, sun, 0);
        const tle = scene.issTle;
        if (tle) {
            const iss = t => {
                const dd = t - 2451545.0, dt = (t - tle.epoch) * 86400, mu = 398600.4418, re = 6378.137, j2 = 1.08263e-3;
                const n0 = tle.n * 2 * Math.PI / 86400, nd = 2 * tle.ndot * 2 * Math.PI / (86400 * 86400);
                const a = Math.pow(mu / (n0 * n0), 1 / 3), e = tle.ecc, i = tle.inc * r, pp = a * (1 - e * e);
                const k = 1.5 * j2 * (re / pp) * (re / pp) * n0;
                const Om = tle.raan * r - k * Math.cos(i) * dt, w = tle.argp * r + k * (2 - 2.5 * Math.sin(i) * Math.sin(i)) * dt;
                const M = tle.m0 * r + n0 * dt + 0.5 * nd * dt * dt;
                let E = M;
                for (let j = 0; j < 8; j++) E = M + e * Math.sin(E);
                const x = a * (Math.cos(E) - e), y = a * Math.sqrt(1 - e * e) * Math.sin(E);
                const cw = Math.cos(w), sw = Math.sin(w), cO = Math.cos(Om), sO = Math.sin(Om), ci = Math.cos(i), si = Math.sin(i);
                const p = [(cw * cO - sw * sO * ci) * x + (-sw * cO - cw * sO * ci) * y,
                           (cw * sO + sw * cO * ci) * x + (-sw * sO + cw * cO * ci) * y,
                           sw * si * x + cw * si * y];
                const ob = obs((280.46061837 + 360.98564736629 * dd) * r);
                const v = [p[0] - ob[0], p[1] - ob[1], p[2] - ob[2]];
                const up = norm(ob), alt = (v[0] * up[0] + v[1] * up[1] + v[2] * up[2]) / Math.hypot(v[0], v[1], v[2]);
                const sd = p[0] * sun[0] + p[1] * sun[1] + p[2] * sun[2];
                const perp = Math.hypot(p[0] - sd * sun[0], p[1] - sd * sun[1], p[2] - sd * sun[2]);
                return { dir: norm(v), up: alt > 0, lit: sd > 0 || perp > re };
            };
            const now = iss(jd), prev = iss(jd - 6 / 86400);
            if (Math.abs(jd - tle.epoch) < 14 && now.up) {
                put(2, now.dir, now.lit ? 2 : 1);
                put(3, prev.dir, scene.context ? scene.context.elapsedTime : 0);
            }
        }
        return Qt.matrix4x4(...m);
    }
    readonly property bool prismLive: context ? modeLive(context.elapsedTime, context.devMode, context.devModeAt, 9)
        || (context.elapsedTime - context.devSwitchAt < 1 && modeLive(context.devSwitchAt, context.devPrevMode, context.devPrevAt, 9)) : false

    function rebake() {
        roomStaticSrc.scheduleUpdate();
        roomLightSrc.scheduleUpdate();
        penroseSrc.scheduleUpdate();
        prismRebuild();
        mapStaticSrc.scheduleUpdate();
    }
    onWidthChanged: rebake()
    onHeightChanged: rebake()

    LockShaderPass {
        id: roomStatic
        anchors.fill: parent
        dummyTexture: parent.dummyTexture
        shaderName: "yamp_bufferRoomStatic"
        blending: false
        iChannel0: texSrc
        iChannel1: noiseSrc
        iChannel2: photoSrc
        onIClockChanged: roomStaticSrc.scheduleUpdate()
        onStatusChanged: if (status === ShaderEffect.Compiled) roomStaticSrc.scheduleUpdate()
    }
    ShaderEffectSource {
        id: roomStaticSrc; sourceItem: roomStatic; hideSource: true
        live: false; format: ShaderEffectSource.RGBA16F
    }

    LockShaderPass {
        id: roomLight
        anchors.fill: parent
        dummyTexture: parent.dummyTexture
        shaderName: "yamp_bufferRoomLight"
        blending: false
        iChannel0: texSrc
        iChannel1: noiseSrc
        iChannel2: photoSrc
        onStatusChanged: if (status === ShaderEffect.Compiled) roomLightSrc.scheduleUpdate()
    }
    ShaderEffectSource {
        id: roomLightSrc; sourceItem: roomLight; hideSource: true
        live: false; format: ShaderEffectSource.RGBA16F
    }

    LockShaderPass {
        id: penroseBake
        anchors.fill: parent
        dummyTexture: parent.dummyTexture
        shaderName: "yamp_bufferPenrose"
        blending: false
        iChannel0: texSrc
        iChannel1: noiseSrc
        iChannel5: labelsSrc
        onStatusChanged: if (status === ShaderEffect.Compiled) penroseSrc.scheduleUpdate()
    }
    ShaderEffectSource {
        id: penroseSrc; sourceItem: penroseBake; hideSource: true
        live: false
    }

    LockShaderPass {
        id: penroseState
        width: 32; height: 32
        context: parent.context; dummyTexture: parent.dummyTexture
        shaderName: "yamp_bufferPenroseState"
        blending: false
    }
    ShaderEffectSource {
        id: penroseStateSrc; sourceItem: penroseState; hideSource: true
        format: ShaderEffectSource.RGBA32F; smooth: false
    }

    Image { id: scopePath; source: "../assets/scope_path.png"; visible: false; smooth: false }
    ShaderEffectSource {
        id: scopePathSrc; sourceItem: scopePath; hideSource: true
        smooth: false; textureSize: Qt.size(1024, 2)
    }

    LockShaderPass {
        id: scopePass
        anchors.fill: parent
        context: parent.context; dummyTexture: parent.dummyTexture
        shaderName: "yamp_bufferScope"
        blending: false
        iChannel8: scopePathSrc
        iChannel9: scopeSrc
    }
    ShaderEffectSource {
        id: scopeSrc; sourceItem: scopePass; hideSource: true
        live: scene.scopeLive; recursive: true; mipmap: true; format: ShaderEffectSource.RGBA32F
    }


    LockShaderPass {
        id: prismState
        width: 1250; height: 32
        dummyTexture: parent.dummyTexture
        u_prism_ray: scene.prismRay
        u_prism_beam: scene.context ? scene.context.prismBeam : Qt.vector2d(0, 0)
        shaderName: scene.prismArmed ? "yamp_bufferPrismState" : ""
        blending: false
        iChannel0: texSrc
        onStatusChanged: if (status === ShaderEffect.Compiled) scene.prismRebuild()
    }
    ShaderEffectSource {
        id: prismStateSrc; sourceItem: prismState; hideSource: true
        format: ShaderEffectSource.RGBA32F; smooth: false; live: false
    }

    LockShaderPass {
        id: prismLight
        anchors.fill: parent
        dummyTexture: parent.dummyTexture
        u_prism_beam: scene.context ? scene.context.prismBeam : Qt.vector2d(0, 0)
        shaderName: scene.prismArmed ? "yamp_bufferPrismLight" : ""
        blending: false
        iChannel0: texSrc
        iChannel8: prismStateSrc
        iChannel9: prismLightSrc
        u_prism_chunk: scene.prismChunk
        onU_prism_beamChanged: scene.prismRebuild()
        u_prism_ray: scene.prismRay
        onU_prism_rayChanged: scene.prismRebuild()
        onStatusChanged: if (status === ShaderEffect.Compiled) scene.prismRebuild()
    }
    ShaderEffectSource {
        id: prismLightSrc; sourceItem: prismLight; hideSource: true
        live: false; recursive: true; format: ShaderEffectSource.RGBA32F
        onScheduledUpdateCompleted: if (scene.prismBaking) {
            if (scene.prismChunk < scene.prismChunks - 1) {
                scene.prismChunk++;
                scheduleUpdate();
            } else scene.prismBaking = false;
        }
    }
    readonly property int prismChunks: 400
    property int prismChunk: 0
    property bool prismBaking: false
    Timer {
        id: prismRebake; interval: 150
        onTriggered: {
            scene.prismChunk = 0;
            scene.prismBaking = true;
            prismLightSrc.scheduleUpdate();
        }
    }
    function prismRebuild() {
        if (!prismLive) return;
        prismStateSrc.scheduleUpdate();
        prismRebake.restart();
    }

    readonly property real prismScale: 0.5
    readonly property vector2d prismCenter: Qt.vector2d(0.05, 0)
    property vector4d prismRay: Qt.vector4d(0, 0, 0, 0)
    function prismRoll() {
        const asp = width / Math.max(height, 1), m = 0.03;
        let s = Math.random() * (asp + 1), from;
        if (s < asp / 2) from = Qt.vector2d(-s, 0.5 + m);
        else if (s < asp / 2 + 1) from = Qt.vector2d(-asp / 2 - m, 0.5 - (s - asp / 2));
        else from = Qt.vector2d(-(s - asp / 2 - 1), -0.5 - m);
        const jr = Math.random() < 0.5 ? 0.01 * Math.random() : 0.12 * Math.random();
        const ja = Math.random() * 2 * Math.PI;
        const to = Qt.vector2d(prismCenter.x + jr * Math.cos(ja), prismCenter.y + jr * Math.sin(ja));
        prismRay = Qt.vector4d((from.x - prismCenter.x) / prismScale, (from.y - prismCenter.y) / prismScale,
            Math.atan2(to.y - from.y, to.x - from.x), 0);
    }
    property bool prismArmed: false
    onPrismLiveChanged: if (prismLive) {
        prismArmed = true;
        prismRoll();
    }
    Timer { interval: 30000; running: scene.prismLive; repeat: true; onTriggered: scene.prismRoll() }
    Connections {
        target: scene.context
        function onPrismRollChanged() { scene.prismRoll(); }
    }

    LockShaderPass {
        id: gravState
        width: 38; height: 34
        context: parent.context; dummyTexture: parent.dummyTexture
        u_aspect: scene.width / Math.max(scene.height, 1)
        shaderName: "yamp_bufferGravState"
        blending: false
        iChannel9: gravStateSrc
    }
    ShaderEffectSource {
        id: gravStateSrc; sourceItem: gravState; hideSource: true
        live: scene.gravityLive; recursive: true; smooth: false; format: ShaderEffectSource.RGBA32F
    }

    LockShaderPass {
        id: gravTrail
        anchors.fill: parent
        context: parent.context; dummyTexture: parent.dummyTexture
        shaderName: "yamp_bufferGravTrail"
        blending: false
        iChannel8: gravStateSrc
        iChannel9: gravTrailSrc
    }
    ShaderEffectSource {
        id: gravTrailSrc; sourceItem: gravTrail; hideSource: true
        live: scene.gravityLive; recursive: true; format: ShaderEffectSource.RGBA32F
    }

    LockShaderPass {
        id: fishPass
        width: 1024; height: 132
        context: parent.context; dummyTexture: parent.dummyTexture
        u_aspect: scene.width / Math.max(scene.height, 1)
        shaderName: "yamp_bufferFish"
        blending: false
        iChannel9: fishSrc
    }
    ShaderEffectSource {
        id: fishSrc; sourceItem: fishPass; hideSource: true
        live: scene.fishLive; recursive: true; smooth: false; format: ShaderEffectSource.RGBA32F
    }

    LockShaderPass {
        id: conveyorPass
        width: 1024; height: 43
        context: parent.context; dummyTexture: parent.dummyTexture
        u_aspect: scene.width / Math.max(scene.height, 1)
        shaderName: "yamp_bufferConveyor"
        iChannel0: texSrc
        blending: false
        iChannel9: conveyorSrc
    }
    ShaderEffectSource {
        id: conveyorSrc; sourceItem: conveyorPass; hideSource: true
        live: scene.conveyorLive; recursive: true; smooth: false; format: ShaderEffectSource.RGBA32F
    }

    LockShaderPass {
        id: conveyorDraw
        anchors.fill: parent
        context: parent.context; dummyTexture: parent.dummyTexture
        shaderName: "yamp_bufferConveyorDraw"
        blending: false
        iChannel0: texSrc
        iChannel1: noiseSrc
        iChannel17: conveyorSrc
    }
    ShaderEffectSource {
        id: conveyorDrawSrc; sourceItem: conveyorDraw; hideSource: true
        live: scene.conveyorLive
    }

    LockShaderPass {
        id: trafficPass
        width: 1024; height: 132
        context: parent.context; dummyTexture: parent.dummyTexture
        u_aspect: scene.width / Math.max(scene.height, 1)
        shaderName: "yamp_bufferTraffic"
        iChannel20: mapsSrc
        blending: false
        iChannel9: trafficSrc
    }
    ShaderEffectSource {
        id: trafficSrc; sourceItem: trafficPass; hideSource: true
        live: scene.trafficLive; recursive: true; smooth: false; format: ShaderEffectSource.RGBA32F
    }

    // the traffic map's roads, bridges and buildings, baked when the map changes
    LockShaderPass {
        id: mapStatic
        anchors.fill: parent
        context: parent.context; dummyTexture: parent.dummyTexture
        shaderName: "yamp_bufferMapStatic"
        blending: false
        iChannel0: texSrc
        iChannel1: noiseSrc
        iChannel20: mapsSrc
        onU_traffic_mapChanged: mapStaticSrc.scheduleUpdate()
        onStatusChanged: if (status === ShaderEffect.Compiled) mapStaticSrc.scheduleUpdate()
    }
    ShaderEffectSource {
        id: mapStaticSrc; sourceItem: mapStatic; hideSource: true
        live: false; format: ShaderEffectSource.RGBA32F
    }

    LockShaderPass {
        id: fluidPass
        width: Math.max(1, Math.round(256 * scene.width / Math.max(scene.height, 1))); height: 257
        context: parent.context; dummyTexture: parent.dummyTexture
        shaderName: "yamp_bufferFluid"
        blending: false
        iChannel9: fluidSrc
    }
    ShaderEffectSource {
        id: fluidSrc; sourceItem: fluidPass; hideSource: true
        live: scene.fluidLive; recursive: true; smooth: false; format: ShaderEffectSource.RGBA32F
    }

    LockShaderPass {
        id: starsPass
        width: 111; height: 1
        u_planets: scene.planets
        u_bodies: scene.bodies
        context: parent.context; dummyTexture: parent.dummyTexture
        u_aspect: scene.width / Math.max(scene.height, 1)
        shaderName: "yamp_bufferStars"
        blending: false
        iChannel14: skySrc
    }
    ShaderEffectSource {
        id: starsSrc; sourceItem: starsPass; hideSource: true
        live: scene.starsLive; smooth: false; format: ShaderEffectSource.RGBA32F
    }

    LockShaderPass {
        id: mainPass
        anchors.fill: parent
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "yamp"
        iChannel0: texSrc
        iChannel1: noiseSrc
        iChannel2: photoSrc
        iChannel3: roomStaticSrc
        iChannel4: roomLightSrc
        iChannel5: labelsSrc
        iChannel6: penroseSrc
        iChannel7: penroseStateSrc
        iChannel8: prismLightSrc
        iChannel9: scopeSrc
        iChannel10: gravStateSrc
        iChannel11: gravTrailSrc
        iChannel12: fluidSrc
        iChannel13: flapFontSrc
        iChannel14: skySrc
        iChannel15: starsSrc
        iChannel16: fishSrc
        iChannel17: conveyorSrc
        iChannel18: conveyorDrawSrc
        iChannel19: trafficSrc
        iChannel20: mapsSrc
        iChannel21: mapStaticSrc
        iChannel22: mapLabelsSrc
        u_planets: scene.planets
        u_bodies: scene.bodies
    }
    ShaderEffectSource { id: mainSrc; sourceItem: mainPass; hideSource: scene.aaLive; live: scene.aaLive }

    LockShaderPass {
        visible: scene.aaLive
        anchors.fill: parent
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "yamp_postFxaa"
        iChannel0: mainSrc
    }
}
