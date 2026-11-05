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
    property bool fxaa: true
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

    function jumpToMode(i) {
        devPrevMode = devMode;
        devPrevAt = devModeAt;
        devSwitchAt = elapsedTime;
        devMode = i;
        devModeAt = elapsedTime;
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
