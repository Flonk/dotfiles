import QtQuick
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
    Image { id: labels; source: "../assets/penrose_labels.png"; visible: false; onStatusChanged: scene.rebake() }
    ShaderEffectSource { id: labelsSrc; sourceItem: labels; hideSource: true }

    readonly property int modeCount: 11
    readonly property real modeDur: 480
    readonly property int scopeMode: 7
    function modeLive(t, mode, at, m) {
        let since = mode >= 0 ? t - at : t;
        let c = ((since + (mode >= 0 ? mode * modeDur : 0)) % (modeCount * modeDur) + modeCount * modeDur) % (modeCount * modeDur);
        let to = Math.floor(c / modeDur), mt = c - to * modeDur;
        return to === m || (to === (m + 1) % modeCount && mt < 1 && since > mt);
    }
    readonly property bool scopeLive: context ? modeLive(context.elapsedTime, context.devMode, context.devModeAt, scopeMode)
        || (context.elapsedTime - context.devSwitchAt < 1 && modeLive(context.devSwitchAt, context.devPrevMode, context.devPrevAt, scopeMode)) : false
    readonly property bool prismLive: context ? modeLive(context.elapsedTime, context.devMode, context.devModeAt, 9)
        || (context.elapsedTime - context.devSwitchAt < 1 && modeLive(context.devSwitchAt, context.devPrevMode, context.devPrevAt, 9)) : false

    function rebake() {
        roomStaticSrc.scheduleUpdate();
        roomLightSrc.scheduleUpdate();
        penroseSrc.scheduleUpdate();
        prismRebuild();
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
    }
    ShaderEffectSource { id: mainSrc; sourceItem: mainPass; hideSource: true }

    LockShaderPass {
        anchors.fill: parent
        context: parent.context; frameCount: parent.frameCount; dummyTexture: parent.dummyTexture
        shaderName: "yamp_postFxaa"
        iChannel0: mainSrc
    }
}
