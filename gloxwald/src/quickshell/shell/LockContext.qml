import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: root
    signal unlocked()

    property string shader: "yamp"
    // Concrete scene, resolved once per lock by resolveShader() and shared by every
    // monitor's LockSurface so they all render the same shader.
    property string activeShader: ""

    readonly property var _allShaders: [
        "002_blue", "20221105_inercia_intended_one", "2d_clouds", "3d_fire_340",
        "8x8_pixel_character", "abacate_with_suggar", "apollonian_with_a_twist_ii",
        "ashanoha", "auroras", "breathing_rings", "cat_and_boy_12", "chilly_waves_2",
        "colorful_underwater_bubbles_ii", "crazy_spiral_thing", "dark_transit",
        "disco_sun_vortex", "discoteq_2", "fragment_plane", "gliding",
        "global_wind_circulation", "glsl_2d_tutorials", "hexagonal_grid_traversal_3d",
        "hexagonal_pattern_logic", "inside_the_torus", "isovalues_3",
        "mandelbrot_distance", "mobius_spiral", "monster", "racing_to_the_future",
        "raymarched_hexagonal_truchet", "raytraced_transformed_spheres",
        "renkli_toplar", "segmented_spiral_whirlpool", "shadertober_06b_husky",
        "sincos_3d", "starship_reentry", "superquadratic_reflections",
        "synthwave_canyon", "the_universe_within", "ui_noise_halo", "ui_test_5",
        "voxel_star_field", "wavey_spheres", "weird_truchet", "windows_95", "yamp",
    ]

    function resolveShader() {
        activeShader = (shader !== "random")
            ? shader
            : _allShaders[Math.floor(Math.random() * _allShaders.length)];
    }

    Component.onCompleted: resolveShader()

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
        const t = (Date.now() - clockStart) / 1000;
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
