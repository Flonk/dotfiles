import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: root
    signal unlocked()

    property int devMode: -1
    property real devModeAt: 0

    property real devGoldAt: -1000
    property bool matte: false
    property real solidMatte: matte ? 1 : 0
    Behavior on solidMatte {
        NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
    }
    property real timeScale: 1
    property real _anchorT: 0
    property double _anchorMs: 0

    property int devPrevMode: -1
    property real devPrevAt: 0
    property real devSwitchAt: -1000
    property vector2d prismBeam: Qt.vector2d(0, 0)
    // traffic sub-modes: -1 the grid, else a map baked by gen_maps.py (same
    // order as its MAPS); rolled each time the scene comes on unless pinned
    readonly property var trafficMapNames: ["magic roundabout", "arc de triomphe", "spaghetti junction", "newark airport", "katy freeway", "auckland cmj", "putrajaya", "puxi viaduct", "nanpu bridge", "diverging diamond", "praterstern", "votivkirche", "mixing bowl", "squirrel hill", "huangjuewan", "central park south", "acropolis", "salzburg", "monaco", "le quesnoy"]
    property int trafficMap: 0
    property bool trafficMapPinned: false
    property int trafficCars: -1
    property bool trafficDebug: false
    property bool trafficMinimap: false
    property bool trafficMeter: false
    property bool trafficStuck: false
    property bool showGrid: false

    readonly property int modeCount: 28
    readonly property real sceneLength: 240
    readonly property var sceneTable: [
        { name: "base", mode: 0, weight: 1, length: 1 },
        { name: "field", mode: 1, weight: 1, length: 1 },
        { name: "drop", mode: 2, weight: 1, length: 1 },
        { name: "3d amp", mode: 3, weight: 1, length: 1 },
        { name: "halftone", mode: 4, weight: 1, length: 1 },
        { name: "shadow", mode: 5, weight: 1, length: 1 },
        { name: "penrose", mode: 6, weight: 1, length: 1 },
        { name: "scope", mode: 7, weight: 1, length: 1 },
        { name: "spectrum", mode: 8, weight: 1, length: 1 },
        { name: "prism", mode: 9, weight: 2, length: 1 },
        { name: "gasket", mode: 10, weight: 1, length: 1 },
        { name: "gravity", mode: 11, weight: 1, length: 1 },
        { name: "fluid", mode: 12, weight: 1, length: 1 },
        { name: "grid", mode: 14, weight: 2, length: 1 },
        { name: "stars", mode: 15, weight: 1, length: 1 },
        { name: "fish", mode: 25, weight: 2, length: 1 },
        { name: "traffic", mode: 26, weight: 5, length: 2 },
        { name: "conveyor", mode: 27, weight: 1, length: 1 }
    ]
    readonly property var sceneModes: sceneTable.map(s => s.mode)
    readonly property var transitionModes: [13, 16, 17, 18, 19, 20, 21, 22, 23, 24]
    readonly property var transitionLengths: ({ 13: 10.5, 16: 9.5, 17: 6, 18: 6.5, 19: 7, 20: 7, 21: 7, 22: 6, 23: 7, 24: 6.5 })
    readonly property var modeDurations: {
        let d = new Array(modeCount).fill(sceneLength);
        for (const s of sceneTable) d[s.mode] = sceneLength * s.length;
        for (const m in transitionLengths) d[m] = transitionLengths[m];
        return d;
    }
    readonly property int playlistScenes: 48
    property var modeOrder: interleave(sceneModes, i => transitionModes[i % transitionModes.length])
    function interleave(scenes, pick) {
        let o = [];
        for (let i = 0; i < scenes.length; i++) o.push(scenes[i], pick(i));
        return o;
    }
    readonly property var seqInfo: {
        const pl = modeOrder, dur = pl.map(x => modeDurations[x]);
        if (heldSeq) {
            const s = heldSeq.slot % pl.length, b = (s + pl.length - 1) % pl.length;
            return [pl[s], Math.min(elapsedTime - heldSeq.start, dur[s] - 1), heldSeq.lap, pl[b], pl[(s + 1) % pl.length], dur[s], dur[b], s];
        }
        const total = dur.reduce((a, b) => a + b, 0);
        let skip = 0, since = elapsedTime;
        if (devMode >= 0) {
            const ds = Math.max(pl.indexOf(devMode % modeCount), 0);
            for (let i = 0; i < ds; i++) skip += dur[i];
            since = elapsedTime - devModeAt;
        }
        const c = ((since + skip) % total + total) % total;
        let acc = 0, slot = 0;
        while (slot < pl.length - 1 && c >= acc + dur[slot]) acc += dur[slot++];
        const lap = Math.floor((since + skip) / total) * pl.length + slot;
        const before = (slot + pl.length - 1) % pl.length;
        return [pl[slot], c - acc, lap, pl[before], pl[(slot + 1) % pl.length], dur[slot], dur[before], slot];
    }
    readonly property vector4d seqA: Qt.vector4d(seqInfo[0], seqInfo[1], seqInfo[2], seqInfo[3])
    readonly property vector4d seqB: Qt.vector4d(seqInfo[4], seqInfo[5], seqInfo[6], 0)
    function shuffled(a) {
        let o = a.slice();
        for (let i = o.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [o[i], o[j]] = [o[j], o[i]];
        }
        return o;
    }
    function pickScenes(n) {
        const live = sceneTable.filter(s => s.weight > 0);
        let o = [];
        for (let i = 0; i < n; i++) {
            const pool = live.length > 1 ? live.filter(s => s.mode !== o[o.length - 1]) : live;
            let r = Math.random() * pool.reduce((a, s) => a + s.weight, 0), pick = pool[pool.length - 1].mode;
            for (const s of pool) if ((r -= s.weight) < 0) { pick = s.mode; break; }
            o.push(pick);
        }
        return o;
    }
    function shuffleModes() {
        const t = shuffled(transitionModes);
        modeOrder = interleave(pickScenes(playlistScenes), i => t[i % t.length]);
    }
    property int prismRoll: 0

    property bool holdScene: false
    property var heldSeq: null
    function _hold() {
        heldSeq = null;
        if (!holdScene) return;
        const s = seqInfo;
        heldSeq = transitionModes.indexOf(s[0]) >= 0
            ? { slot: s[7] + 1, start: elapsedTime, lap: s[2] + 1 }
            : { slot: s[7], start: elapsedTime - s[1], lap: s[2] };
    }
    onHoldSceneChanged: _hold()

    function jumpToMode(i) {
        if (i >= 0 && modeOrder.indexOf(i % modeCount) < 0) modeOrder = [i % modeCount, transitionModes[0]].concat(modeOrder);
        devPrevMode = devMode;
        devPrevAt = devModeAt;
        devSwitchAt = elapsedTime;
        devMode = i;
        devModeAt = elapsedTime;
        _hold();
    }
    function sendGoldWave() {
        devGoldAt = elapsedTime;
    }
    function sendFail() {
        lastFailedUnlockTime = elapsedTime;
    }
    function _rebase() {
        _anchorT = elapsedTime;
        _anchorMs = Date.now();
    }
    function setTimeScale(s) {
        _rebase();
        timeScale = s;
    }
    function skip(seconds) {
        _rebase();
        _anchorT += seconds;
    }

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false

    // Envelope timing state (seconds since lock start)
    // Advanced from the clock-owner surface's frameSwapped signal (frameTick):
    // vsync-locked wall-clock time, driven once — not N times — on N monitors.
    // Each tick dirties the ShaderEffects, which schedules the next frame,
    // so the loop is self-sustaining while any surface exists.
    property real elapsedTime: 0
    property double clockStart: 0
    property var _clockOwner: null

    function frameTick(owner) {
        if (_clockOwner === null) _clockOwner = owner;
        if (_clockOwner !== owner) return;
        if (_anchorMs !== 0 && timeScale === 0) return;
        const now = Date.now();
        const t = _anchorMs === 0
            ? (now - clockStart) / 1000
            : _anchorT + (now - _anchorMs) / 1000 * timeScale;
        // always advance so the repaint chain never stalls
        elapsedTime = t > elapsedTime ? t : elapsedTime + 0.0005;
    }
    function releaseClock(owner) {
        if (_clockOwner === owner) _clockOwner = null;
    }
    property real lastKeyTime: -1000.0
    property real lastFailedUnlockTime: -1000.0
    property real authStartedTime: -1000.0

    // Envelope base values for seamless mid-animation keypresses
    property real keypulseBase: 0.0
    property real keyBase: 0.0

    onCurrentTextChanged: showFailure = false

    function recordKeypress() {
        // Sample current envelope values as bases for the next animation
        let age = elapsedTime - lastKeyTime;
        if (age < 0.11) {
            let ramp = Math.min(age / 0.03, 1.0);
            let p = keypulseBase * (1.0 - ramp) + ramp;
            let decay = Math.max((age - 0.03) / 0.08, 0.0);
            keypulseBase = p * (1.0 - decay * decay);
        } else {
            keypulseBase = 0.0;
        }
        if (age < 3.06) {
            let ramp = Math.min(age / 0.06, 1.0);
            let p = keyBase * (1.0 - ramp) + ramp;
            let decay = Math.max((age - 1.06) / 2.0, 0.0);
            keyBase = Math.max(0.0, p * (1.0 - decay));
        } else {
            keyBase = 0.0;
        }
        lastKeyTime = elapsedTime;
    }

    function tryUnlock() {
        if (currentText === "") return;
        unlockInProgress = true;
        authStartedTime = elapsedTime;
        pam.start();
    }

    PamContext {
        id: pam
        configDirectory: "pam"
        config: "password.conf"

        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root.currentText);
            }
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                Qt.callLater(() => root.unlocked());
            } else {
                root.lastFailedUnlockTime = root.elapsedTime;
                root.currentText = "";
                root.showFailure = true;
            }
            root.authStartedTime = -1000.0;
            root.unlockInProgress = false;
        }
    }
}
