#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// ---------------------------------------------------------------------------
// Uniform block — Qt maps QML properties to these by name
// ---------------------------------------------------------------------------

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    // Shadertoy-compatible inputs
    float iTime;
    int iFrame;
    int u_indicator_type;

    float u_last_key_time;
    float u_last_failed_unlock_time;
    float u_auth_started_time;
    vec2 u_key_bases;
    int u_dev_mode;
    float u_dev_mode_at;
    float u_dev_gold_at;
    int u_dev_prev_mode;
    float u_dev_prev_at;
    float u_dev_switch_at;
    float u_solid_matte;

    vec3 iResolution;
    vec3 u_indicator_color;

    vec4 iMouse;
    vec4 iClock;

    // 32 random floats in [0,1), rerolled by the host each time the shader
    // pass is created — read them via sk_seed(i) to vary scenes per session
    mat4 iSeed0;
    mat4 iSeed1;
};

// Up to four input textures, resolved from QML properties.
layout(binding = 1) uniform sampler2D iChannel0;
layout(binding = 2) uniform sampler2D iChannel1;
layout(binding = 3) uniform sampler2D iChannel2;
layout(binding = 4) uniform sampler2D iChannel3;

// ---------------------------------------------------------------------------
// Shared constants
// ---------------------------------------------------------------------------

/// Canonical fail colour (227, 85, 50) in linear [0, 1] range.
const vec3 sk_fail_color = vec3(227.0 / 255.0, 85.0 / 255.0, 50.0 / 255.0);

// ---------------------------------------------------------------------------
// sk_ — gloxwaldlock standard library
// ---------------------------------------------------------------------------

/// Random float in [0,1) for i in 0..31, fixed for the session.
float sk_seed(int i) {
    mat4 m = i < 16 ? iSeed0 : iSeed1;
    return m[(i >> 2) & 3][i & 3];
}

float sk_ease_out_back(float t) {
    const float c1 = 4.0;
    const float c3 = c1 + 1.0;
    float x = t - 1.0;
    return 1.0 + c3 * x * x * x + c1 * x * x;
}

// _at variants evaluate the envelope at an arbitrary time t (<= iTime;
// there is no future to sample) — for phase-shifted copies of an envelope

float sk_keypulse_envelope_at(float t) {
    float age = t - u_last_key_time;
    float ramp = clamp(age / 0.03, 0.0, 1.0);
    float p = mix(u_key_bases.x, 1.0, ramp);
    float decay = clamp((age - 0.03) / 0.08, 0.0, 1.0);
    return p * (1.0 - decay * decay);
}
float sk_keypulse_envelope() { return sk_keypulse_envelope_at(iTime); }

float sk_key_envelope_at(float t) {
    float age = t - u_last_key_time;
    float ramp = clamp(age / 0.06, 0.0, 1.0);
    float p = mix(u_key_bases.y, 1.0, ramp);
    float decay = clamp((age - 1.06) / 2.0, 0.0, 1.0);
    return p * (1.0 - sk_ease_out_back(pow(decay, 0.65)));
}
float sk_key_envelope() { return sk_key_envelope_at(iTime); }

float sk_fail_envelope_at(float t) {
    float age = t - u_last_failed_unlock_time;
    float p = clamp(age / 0.03, 0.0, 1.0);
    float decay = clamp((age - 0.27) / 2.0, 0.0, 1.0);
    return p * pow(1.0 - decay, 3.0);
}
float sk_fail_envelope() { return sk_fail_envelope_at(iTime); }

float sk_load_envelope_at(float t) {
    float isLoading = step(-999.0, u_auth_started_time);
    float authAge = t - u_auth_started_time;
    float endedAge = t - u_last_failed_unlock_time;
    float loading = isLoading * clamp((authAge - 0.1) / 0.03, 0.0, 1.0);
    float unloading = (1.0 - isLoading) * clamp(1.0 - endedAge / 0.03, 0.0, 1.0);
    return loading + unloading;
}
float sk_load_envelope() { return sk_load_envelope_at(iTime); }

float sk_attention_envelope_at(float t) {
    float kf = sk_key_envelope_at(t) + sk_fail_envelope_at(t);
    float load = sk_load_envelope_at(t);
    kf = max(kf, load - 1.0);
    return min(kf + load, 1.0);
}
float sk_attention_envelope() { return sk_attention_envelope_at(iTime); }

// ---------------------------------------------------------------------------
// Shader body follows (injected by convert-shaders.sh)
// ---------------------------------------------------------------------------
// yamp: yasuo quadtree scene, X glyphs replaced by the and& ampersand.
// The build (convert-shaders.sh) concatenates NN_*.glsl in order, then
// shader.glsl:
//   00_knobs  — every tuning constant, incl. the mode table and playlist
//   10_lib    — generic helpers (rng, easing, squircle, stars)
//   20_modes  — mode sequencer machinery, structural-mode hooks
//   shader    — the scene: amp SDFs, quadtree, key indicator, mainImage
//
// Per tile, on its own clock (speed n*2*SPEED), the loop runs:
//   off (long) -> rotate (J/P counter-spin 360) -> off (short)
//   -> fill J (gradient wipe) -> fill P (offset wipe) -> on -> unfill -> loop
// sdJ/sdP sample a baked SDF texture (gen_sdf.py); the design gap (PAD) of
// the J is carved out of the P, so the pieces stay separated even mid-spin.
// Tiles are squircles (SQUIRCLENESS knob); the rim band refracts the content
// like glass (DISTORT knobs). The background noise (iChannel1) counter-scrolls
// and gets sucked toward each tile's rim, piling up into a bright event
// horizon that forms the border (PILE knobs) — no drawn ring.

// --- knobs ------------------------------------------------------------------
const float SPEED      = 0.8;    // global animation speed multiplier
const float T_OFF1     = 6.0;   // off, long (dark grey)
const float T_ROTATE   = 1.749; // J/P fast 360 spin
const float T_OFF2     = 2.5;   // off, short
const float T_FILL     = 1.104;  // duration of each white fill wipe
const float T_FILL_LAG = 0.067; // P wipe starts this long after J wipe
const float T_ON       = 2.;  // fully white hold
const float T_UNFILL   = 1.;  // wipes reverse out
const float T_REST     = 0.2;   // grey tail before the loop restarts

const float AMP_SCALE  = 0.94;  // glyph size within its tile
const float SCROLL     = 0.03; // vertical scroll speed
const float PAD_ZOOM   = 1.;   // how much tile content zooms out with the
                               // pad (1 = match the planet's shrink, 0 = off)

const float SQUIRCLENESS = 0.;   // tile shape: 0 = circle, 1 = square
const float DISTORT_BAND = 0.12;  // rim band that refracts

const float DARKEN = 0.25;        // off-amp darkening per subdivision level

const float NOISE_LO    = 0.0;   // background noise brightness range
const float NOISE_HI    = 0.05;
const float NOISE_SCALE = 3.0;   // background noise texture frequency
const float BG_SPEED    = 0.3;   // background scroll, fraction of SCROLL
const float STAR_BRIGHT = 0.7;   // starfield brightness
const float STAR_CELL   = 6.;    // star spacing in screen pixels (sheet 1)
const float STAR_R      = 0.9;   // star radius, screen pixels
const float STAR_POW    = 17.;   // brightness distribution (lower = denser)
const float STAR_DRIFT  = 0.01;  // second-sheet drift for depth parallax

// baked kaliset nebula (gen_nebula.py): the texture holds the two raw
// field layers, colored live below
const float NEB_SCALE   = 0.25;  // nebula frequency vs the background coords
const vec3  NEB1_COL    = vec3(0.20, 0.35, 0.80); // layer 1: blue wash
const float NEB1_BRIGHT = 0.9;
const vec3  NEB2_COL    = vec3(1.50, 0.50, 0.40); // layer 2: orange filaments
const float NEB2_BRIGHT = 1.8;

const float PILE_BAND = 0.001;    // event-horizon falloff width (tile units)
const float PILE_PULL = 0.35;    // how far the noise is sucked inward (uv units)
const float PILE_GAIN = 7.;      // brightness pile-up at the horizon

const float SCROLL_MIN = 0.045;  // tile content scroll speed, random per tile
const float SCROLL_MAX = 0.09;

// mode transitions circle-wipe over WIPE_DUR; the global zoom flips on ZOOM_PERIOD,
// offset by half — tuned so with the default two-mode playlist the four
// quarters run 2d-in, 2d-out, 3d-out, 3d-in
const float TRANS_DUR   = 1.2;   // zoom flip / cloud fade duration
const float WIPE_DUR    = 0.4;
const float ZOOM_PERIOD = 60. * 8.; // seconds per zoom flip
const float ZOOM_OUT    = 0.30;  // global zoom-out amount
const float ZOOM_ECC    = 5.7;   // zoom target distance from screen center
const float ZOOM_DRIFT  = 2300.7;  // zoom target orbit period (s) — offbeat
                                 // vs ZOOM_PERIOD so the spot always differs

const float RING_BRIGHT = 0.3;    // border ring brightness
const float RING_WIDTH  = 0.0025; // border ring half-width, screen-height
                                  // units — same thickness at every level

// 3d planet dressing (after Otavio Good's CC0 planet shader): a sun drifts
// around the top; each tile gets a blinn-phong glint, domain-warped clouds
// and an atmosphere ("aurora") tint on its event horizon. per-mode
// strengths live in the mode table (spec/cloud/aur)
const float SUN_PERIOD = 397.;   // sun azimuth drift period (s)
const float SUN_SWING  = 0.9;    // sun azimuth swing amplitude
const float SUN_HEIGHT = 1.8;    // sun elevation
const float SUN_Z      = 0.7;    // sun toward-viewer component
const vec3  SUN_COL    = vec3(1.66, 1.39, 0.87); // warm sun tint
const vec3  SUN_WHITE  = vec3(1.31);             // mono-mode sun tint
const float SPEC_POW   = 12.;    // glint tightness
const float SPEC_GAIN  = 0.3;    // sun reflection strength

const float CLOUD_SCALE = 1.1;   // cloud texture frequency (tile units)
const float CLOUD_DRIFT = 0.012; // cloud scroll speed
const float CLOUD_WARP  = 1.2;   // vortex swirl strength (x the blurry sample)
const float CLOUD_SHARP = 0.8;   // contrast exponent (lower = denser)
const float CLOUD_GAIN  = 3.;    // coverage boost after sharpening
const float CLOUD_HEIGHT = 0.04; // shell height: shadow offset sunward (tile units)
const float CLOUD_SHADOW = 0.75; // ground darkening under the cloud shell
const float CLOUD_FADE   = 0.1;  // cloud thinning band at the shell edge (tile units)

// full-planet terrain (terra field): the tile interior becomes ocean, the
// amps land, the filled amps high terrain; the sun then only reflects off
// the water. the amp SDFs double as height fields: distance to the coast
// drives shelves/beaches/snowlines, and its gradient drives the emboss
const vec3 WATER_COL   = vec3(0.02, 0.09, 0.18); // deep ocean
const vec3 WATER_SHALL = vec3(0.05, 0.22, 0.28); // shallow shelf at coasts
const float COAST_W    = 0.06;  // shallow shelf width (amp units) — must
                                // stay inside the SDF clamp (~0.07 usable)
const vec3 SAND_COL    = vec3(0.55, 0.47, 0.26); // beach ring
const float SAND_W     = 0.035; // beach ring width
const vec3 LAND_COL    = vec3(0.10, 0.19, 0.11); // low terrain (amps), muted
const vec3 HIGH_BOT    = vec3(0.45, 0.32, 0.18); // high terrain: rim rock...
const vec3 HIGH_TOP    = vec3(0.95, 0.95, 0.90); // ...to snowfields
const float SNOW_D     = 0.05;  // rock-to-snow rim width (amp units)
const float SNOW_DETAIL = 0.35; // how much detail mottling shows on snow
const float DETAIL_SCALE = 5.;  // terrain detail texture frequency
const float DETAIL_AMT   = 0.6; // terrain detail brightness modulation
const vec3  SPECK_COL  = vec3(0.30, 0.20, 0.10); // lowland dirt specks
const float SPECK_SCALE = 3.7;  // speck texture frequency
const float SPECK_WARP  = 1.5;  // speck spiral distortion
const float SPECK_LO    = 0.25; // speck threshold window (squared sample)
const float SPECK_HI    = 0.55;
const float SPECK_AMT   = 0.8;  // speck opacity on the lowland
const float CORNER_ROUND = 0.02; // round off sharp glyph corners (amp units)
const float COASTF_AMT   = 0.05; // baked coastline fbm amplitude (amp units)
const float AMP_PAD      = 0.25; // shrink amps within their cells so the
                                 // coast bands fit before the cell boundary
const float RELIEF     = 0.4;   // emboss strength at coasts/ridges (negative flips)
const float RELIEF_W   = 0.05;  // emboss band width (amp units), zero beyond

const vec3  AUR_COLOR   = vec3(0.15, 0.5, 1.0);  // atmosphere glow color
const vec3  AUR_SUNSET  = vec3(1.9, 0.5, 0.08);  // sun-facing rim color
const float AUR_SUN_POW = 1.;    // sunset concentration on the sun side
const float AUR_GLOW    = 0.25;  // additive horizon glow strength
const vec3  HAZE_COL    = vec3(0.45, 0.60, 0.85); // haze tint, desaturated
const float ATMO_BASE   = 0.12;  // constant atmosphere veil over the disc
const float ATMO_HAZE   = 0.45;  // limb haze: extra tint at the rim
const float ATMO_POW    = 2.;    // haze concentration toward the limb

// warhol mode: tiles become flat pop-color squares, no pad, no borders.
// each square hashes a palette color and a normal/inverted flip; the fill
// wipe is suppressed — tiles spin, then sit still. normal = black bg, amps
// printed in the color; inverted = color bg, black amps. colors are
// oklch-matched to the andamp blue (same lightness/chroma, rotated hue)
const vec3 WARHOL_COLS[4] = vec3[4](
    vec3(0.138, 0.633, 0.717),   // andamp blue
    vec3(0.768, 0.456, 0.581),   // pink
    vec3(0.482, 0.619, 0.336),   // lime
    vec3(0.764, 0.495, 0.304));  // orange
const float WARHOL_INV  = 0.5;   // chance a square is inverted

// key indicator: on keypress a black circle fills the screen while a blue
// amp zooms in; each key bumps the amp, errors turn it red, inactivity
// reverses everything
const float IND_AMP    = 0.1;   // indicator amp scale (screen units)
const float IND_BUMP   = 0.04;   // per-key amp scale bump
const float IND_BRIGHT = 0.35;   // per-key brightness bump (toward white)
const float IND_LAG    = 0.08;   // circle leads the amp by this, in and out

// and& brand gradient, sampled from andamp-amp-blue.png (top -> bottom)
const vec3 GRAD_TOP = vec3(0.212, 0.671, 0.729);
const vec3 GRAD_BOT = vec3(0.063, 0.596, 0.706);

const float FIELD_ROWS      = 24.;
const float FIELD_AMP       = 0.45;
const float FIELD_ANGLE     = 0.6;
const float FIELD_SPEED     = 0.6;
const float FIELD_LANE_VAR  = 0.5;
const float FIELD_LANE_FREQ = 0.37;
const float FIELD_LANE_RATE = 0.11;
const float FIELD_WAVE_AMP  = 0.6;
const float FIELD_WAVE_FREQ = 0.15;
const float FIELD_WAVE_RATE = 0.2;
const vec2  FIELD_CLOCK     = vec2(0.3, 1.);

const float GOLD_PERIOD = 30.;
const float GOLD_DUR    = 3.5;
const float GOLD_REACH  = 1.3;
const float GOLD_FRONT  = 0.02;
const float GOLD_TAIL   = 0.175;
const float GOLD_WOBBLE = 0.;
const float GOLD_SWELL  = 0.2;
const float GOLD_GLOW   = 0.08;
const vec3  GOLD_TOP    = GRAD_TOP;
const vec3  GOLD_BOT    = GRAD_BOT;

const float DROP_ROWS   = 12.;
const float DROP_AMP    = 0.45;
const float DROP_G      = 60.;
const vec2  DROP_RATE   = vec2(0.1, 0.35);
const float DROP_JITTER = 0.6;
const float DROP_CYCLE  = 40.;
const float DROP_FLUSH  = 1.5;
const float DROP_TILT   = 0.25;
const float DROP_SPIN   = 4.;
const float DROP_BOUNCE = 0.15;
const float DROP_FILL   = 0.35;

const float SOLID_DIST   = 3.2;
const float SOLID_FOCAL  = 2.;
const float SOLID_DEPTH  = 0.12;
const float SOLID_BEVEL  = 0.025;
const float SOLID_NEPS   = 0.02;
const vec3  SOLID_FILL_DIR = vec3(0.6, -0.6, -0.5);
const float SOLID_FILL   = 0.35;
const float SOLID_GROUND = 0.6;
const float SOLID_SPIN   = 0.15;
const float SOLID_TILT   = 0.3;
const float SOLID_TILT_RATE = 0.085;
const int   SOLID_STEPS  = 96;
const float SOLID_HIT_PX = 0.5;
const int   SOLID_SS     = 2;
const vec3  SOLID_LIGHT  = vec3(-0.6, 0.7, -0.8);
const float SOLID_SHINE  = 64.;
const float SOLID_SPEC   = 0.8;
const float SOLID_REFL   = 1.;
const float SOLID_KD     = 0.35;
const int   SOLID_BOUNCES = 2;
const float SOLID_GLOW   = 0.2;
const float SOLID_GLOW_R = 0.8;
const float MATTE_AMBIENT = 0.25;
const float MATTE_SHINE   = 8.;
const float MATTE_SPEC    = 0.08;

const float HALF_ROWS   = 64.;
const float HALF_ANGLE  = 0.785398;
const float HALF_MAX    = 0.85;
const float HALF_BG     = 0.;
const float HALF_AMBIENT = 0.08;
const float HALF_ORBIT  = 0.25;
const float HALF_LIGHT_Z = 0.6;
const float HALF_SHINE  = 24.;
const float HALF_GLINT  = 0.6;
const float HALF_DIST   = SOLID_DIST;
const float HALF_SPIN   = 0.15;
const float HALF_TILT   = 0.3;
const float HALF_TILT_RATE = 0.085;
const float HALF_CONTRAST = 1.6;
const vec3  HALF_GREY   = vec3(0.3);
const float HALF_TINT_LO = 0.2;
const float HALF_TINT_HI = 0.8;

const vec3  SHADOW_CAM    = vec3(0., 1.2, -3.5);
const vec3  SHADOW_TARGET = vec3(0., 0.5, 1.5);
const float SHADOW_FOCAL  = 1.6;
const float SHADOW_WALL_Z = 2.;
const float SHADOW_YAW    = -0.45;
const vec3  SHADOW_AMP_POS = vec3(1.77, 0.5, -3.66);
const vec3  SHADOW_LIGHT  = vec3(4.38, 0.6, -9.06);
const float SHADOW_LIGHT_RANGE = 14.;
const float SHADOW_GAIN   = 2.2;
const float SHADOW_FACE   = -0.45;
const float SHADOW_RIG_YAW = 0.28;
const float SHADOW_SWAY   = 0.25;
const float SHADOW_SWAY_RATE = 0.15;
const float SHADOW_K      = 256.;
const int   SHADOW_STEPS  = 96;
const vec3  SHADOW_WALL   = vec3(0.13, 0.42, 0.47);
const float SHADOW_FILM_GRAIN = 0.15;
const float SHADOW_FILM_FPS   = 24.;
const float SHADOW_WALL_GRAIN = 0.012;
const float SHADOW_WALL_BUMP  = 0.6;
const float SHADOW_WALL_TONE  = 0.05;
const vec3  SHADOW_FLOOR  = vec3(0.08, 0.26, 0.30);
const float SHADOW_AMB    = 0.06;
const float SHADOW_CORNER = 0.55;
const float SHADOW_FLOOR_GAIN = 3.;
const float SHADOW_PLANK_W = 0.14;
const float SHADOW_PLANK_L = 1.;
const float SHADOW_PLANK_GAP = 0.006;
const float SHADOW_PLANK_VAR = 0.15;
const float SHADOW_PLANK_DARK = 0.3;
const float SHADOW_SKIRT_H = 0.08;
const float SHADOW_SKIRT_D = 0.022;
const float SHADOW_SKIRT_BEAD = 0.55;
const vec3  SHADOW_SKIRT  = vec3(0.22, 0.48, 0.52);
const vec2  SHADOW_SKIRT_SS = vec2(0.05, 0.04);
const float SHADOW_SIDE_X    = -2.12;
const float SHADOW_COUCH_FWD  = 3.8;
const float SHADOW_COUCH_LEFT = 0.65;
const float SHADOW_COUCH_W    = 1.6;
const float SHADOW_COUCH_L    = 1.8;
const float SHADOW_COUCH_TOP  = 1.7;
const float SHADOW_COUCH_LEG  = 0.35;
const vec3  SHADOW_COUCH      = vec3(0.13, 0.21, 0.24);
const float SHADOW_LEG_TOP    = 0.085;
const float SHADOW_LEG_TOE    = 0.04;
const float SHADOW_LEG_SPLAY  = 0.05;
const float SHADOW_LEG_FERRULE = 0.05;
const vec3  SHADOW_WOOD       = vec3(0.03, 0.042, 0.046);
const float SHADOW_WOOD_SHEEN = 0.25;
const vec3  SHADOW_BRASS      = vec3(0.025, 0.032, 0.035);
const float SHADOW_BRASS_SHINE = 0.35;
const float SHADOW_COUCH_AMB  = 0.45;
const float SHADOW_COUCH_UNDER = 0.4;
const float SHADOW_COUCH_SPREAD = 0.3;
const float SHADOW_FELT_SCALE  = 0.04;
const float SHADOW_FELT_FINE   = 0.8;
const float SHADOW_FELT_MOTTLE = 0.08;
const float SHADOW_FELT_GRAIN  = 0.1;
const float SHADOW_FELT_SHEEN  = 0.06;
const float SHADOW_FELT_STONE  = 0.3;
const float SHADOW_FELT_STONE_SCALE = 0.05;
const float SHADOW_OUTLET_SCREEN_X = 0.88;
const float SHADOW_OUTLET_Y      = 0.32;
const vec2  SHADOW_OUTLET_SIZE   = vec2(0.6, 0.31);
const float SHADOW_OUTLET_T      = 0.03;
const float SHADOW_OUTLET_SOCKET = 0.095;
const float SHADOW_OUTLET_PLUG   = 0.1;
const vec3  SHADOW_OUTLET_COL    = vec3(0.2, 0.42, 0.46);
const vec3  SHADOW_OUTLET_ACCENT = vec3(0.1, 0.32, 0.35);
const float SHADOW_OUTLET_GLOSS  = 0.25;
const float SHADOW_OUTLET_SCALE  = 0.7;
const float SHADOW_OUTLET_INSERT = 0.12;
const float SHADOW_OUTLET_GROOVE = 0.004;
const float SHADOW_OUTLET_PROUD  = 0.006;
const float SHADOW_OUTLET_INSERT_TINT = 1.1;
const vec3  SHADOW_OUTLET_SS     = vec3(0.07, 0.16, 0.05);
const vec3  SHADOW_CLIP_COL      = vec3(0.4, 0.44, 0.45);
const float SHADOW_CLIP_SHINE    = 0.8;
const float SHADOW_CABLE_R       = 0.011;
const vec2  SHADOW_CABLE_DROP    = vec2(0.06, 0.34);
const float SHADOW_CABLE_LEAD    = 0.2;
const vec2  SHADOW_CABLE_OUT1    = vec2(1.2, 0.78);
const vec2  SHADOW_CABLE_OUT2    = vec2(1.2, 0.92);
const vec2  SHADOW_PHONE_SCREEN  = vec2(0.82, 0.74);
const float SHADOW_PHONE_YAW     = 0.7;
const vec3  SHADOW_PHONE_SIZE    = vec3(0.28, 0.58, 0.03);
const vec3  SHADOW_PHONE_COL     = vec3(0.02, 0.025, 0.03);
const float SHADOW_PHONE_BRIGHT  = 1.6;
const float SHADOW_PHONE_GLOW    = 0.03;
const float SHADOW_PHONE_DIGIT   = 0.045;
const float SHADOW_PHONE_TIME_Y  = 0.;
const vec3  SHADOW_CABLE_COL     = vec3(0.03, 0.045, 0.05);

const float SQ_ROOM   = 5.;
const vec3  SQ_LIGHT  = vec3(1., -2., -1.);
const float SQ_OFFSET = 1.1;
const vec3  SQ_BASE   = vec3(3.9, 0.6, 0.9);
const float SQ_GAIN   = 11.;

// --- modes -------------------------------------------------------------------
// a mode is one ModeParams entry in the playlist below; the sequencer
// (20_modes) walks it, circle-wiping between neighbours over WIPE_DUR
struct ModeParams {
    float pad;      // squircle padding to its cell edge
    float bg;       // background noise + stars visibility
    float light;    // sun diffuse: lift on the sunlit side toward white
    float dark;     // sun diffuse: shadow on the night side toward black
    float ring;     // border ring visibility (styled by RING_BRIGHT/RING_WIDTH)
    float distort;  // glass refraction strength at the tile rim
    float wham;     // extra global zoom-out
    float spec;     // sun specular glint strength
    float cloud;    // cloud coverage
    float aur;      // aurora: atmosphere tint + glow on the event horizon
    float warm;     // sun glint tint: 0 = SUN_WHITE, 1 = SUN_COL
    float terra;    // terrain palette: ocean interior, land amps,
                    // high-terrain fills, water-only glint
    float neb;      // kaliset nebula visibility in the background
    float star;     // starfield density (scales the brightness power law)
    float squir;    // tile squareness on top of SQUIRCLENESS (1 = square)
    float warhol;   // pop-palette strength (per-square colors + inversion)
    float big;      // chance a cell promotes to one huge amp
    float field;
    float drop;
    float solid;
    float halftone;
    float shadow;
};

const int MODE_COUNT = 6;
const ModeParams MODES[MODE_COUNT] = ModeParams[MODE_COUNT](
    //         pad   bg  light dark  ring distort wham   spec cloud aur  warm terra neb  star squir warhol big field drop solid halftone shadow
    // 2d base: flat — border ring, no noise/stars/shade/distortion
    ModeParams(0.01, 0., 0.,   0.,   1.,  0.,     0.,    0.,  0.,   0.,  0.,  0.,   0.,  0.,   0.,  0.,  0.15, 0., 0., 0., 0., 0.),
    ModeParams(0.01, 0., 0.,   0.,   1.,  0.,     0.,    0.,  0.,   0.,  0.,  0.,   0.,  0.,   0.,  0.,  0.15, 1., 0., 0., 0., 0.),
    ModeParams(0.01, 0., 0.,   0.,   1.,  0.,     0.,    0.,  0.,   0.,  0.,  0.,   0.,  0.,   0.,  0.,  0.15, 0.,  1., 0., 0., 0.),
    ModeParams(0.01, 0., 0.,   0.,   1.,  0.,     0.,    0.,  0.,   0.,  0.,  0.,   0.,  0.,   0.,  0.,  0.15, 0.,  0.,  1., 0., 0.),
    ModeParams(0.01, 0., 0.,   0.,   1.,  0.,     0.,    0.,  0.,   0.,  0.,  0.,   0.,  0.,   0.,  0.,  0.15, 0.,  0.,  0.,  1., 0.),
    ModeParams(0.01, 0., 0.,   0.,   1.,  0.,     0.,    0.,  0.,   0.,  0.,  0.,   0.,  0.,   0.,  0.,  0.15, 0.,  0.,  0.,  0.,  1.)
);

const float D = 480.;
const float MODE_DUR[MODE_COUNT] = float[MODE_COUNT](D, D, D, D, D, D);

// derived state boundaries — don't touch, tune the knobs above
const float ROT_START    = T_OFF1;
const float FILLJ_START  = ROT_START + T_ROTATE + T_OFF2;
const float FILLP_START  = FILLJ_START + T_FILL_LAG;
const float ON_START     = FILLP_START + T_FILL;
const float UNFILL_START = ON_START + T_ON;
const float LOOP_LEN     = UNFILL_START + T_UNFILL + T_REST;
// --- generic helpers ---------------------------------------------------------
float gZoom = 1.;   // global zoom factor, set in mainImage — part of the
                    // screen->tile-local distance scale

#define Rot(a) mat2(cos(a),-sin(a),sin(a),cos(a))
#define S(d) (1.-smoothstep(-1.3,1.3, (d)*iResolution.y ))

vec2 gSeed = vec2(0.);   // session hash offset (sk_seed), set in mainImage —
                         // reshuffles every random() draw, so the quadtree
                         // pattern differs each session

float random (vec2 p) {
    return fract(sin(dot(p.xy + gSeed, vec2(12.9898,78.233)))* 43758.5453123);
}

float cubicInOut(float t) {
  return t < 0.5
    ? 4.0 * t * t * t
    : 0.5 * pow(2.0 * t - 2.0, 3.0) + 1.0;
}

// alternates 0/1 every `period`, easing over TRANS_DUR at each flip;
// block 0 (and anything before it) is 0
float flipflop(float t, float period){
    float k = floor(t/period);
    float s = mod(k, 2.);
    float prev = (k < 0.5) ? 0. : 1.-s;
    return mix(prev, s, smoothstep(0., TRANS_DUR, t - k*period));
}

vec2 rotAround(vec2 p, vec2 c, float a){ return (p-c)*Rot(a)+c; }

// squircle tile: circle/rounded-box mix (Hyeve, shadertoy) — a true SDF,
// unlike the superellipse. Returns (distance, gradient); the gradient is
// the same mix of both shapes' gradients (mix is linear, so it's exact).
vec3 sdSquircle(vec2 p, float r, float n){
    float lp = max(length(p), 1e-6);
    vec2 q = abs(p) - n*r;
    vec2 mq = max(q, 0.);
    float lmq = length(mq);
    float square = min(max(q.x,q.y),0.) + lmq - (r - n*r);
    vec2 gsq = (lmq > 1e-6) ? sign(p)*mq/lmq
             : ((q.x > q.y) ? vec2(sign(p.x),0.) : vec2(0.,sign(p.y)));
    vec2 g = mix(p/lp, gsq, n);
    g /= max(length(g), 1e-6);
    return vec3(mix(lp - r, square, n), g);
}

// per-cell vortex swirl (otavio good's Spiral): rotational offset,
// strongest at each cell center, scaled by amt
vec2 spiral(vec2 uv, float amt){
    vec2 d = fract(uv * 2.) - 0.5;
    float blend = pow(clamp((0.5 - length(d)) * 2., 0., 1.), 1.5);
    return uv + vec2(d.y, -d.x) * blend * amt;
}

// star sheets (after the galaxy shader's starLayer): one jittered star per
// STAR_CELL-pixel cell, power-law brightness — thousands dim, a few
// bright — round and antialiased (sizes in actual screen pixels). ids wrap
// to keep the hash healthy after hours of background scroll
float starSheet(vec2 g, float cellPx, float dens){
    vec2 id = mod(floor(g), 1024.);
    vec2 f = fract(g) - 0.5;
    vec2 off = (vec2(random(id + 4.2), random(id + 8.4)) - 0.5) * 0.7;
    float dpx = length(f - off) * cellPx;
    return smoothstep(STAR_R + 0.7, STAR_R - 0.7, dpx)
         * pow(random(id), STAR_POW / max(dens, 1e-3));
}

// two sheets: the second is finer, dimmer, and drifts slowly against the
// background scroll for depth parallax. the lattice is fixed in background
// coords so stars ride the same scroll as the noise/nebula through zoom
// and pad transitions; only the pixel radius compensates for zoom so the
// dots stay STAR_R px round
float stars(vec2 p, float dens){
    float f = iResolution.y / (NOISE_SCALE * STAR_CELL);
    return starSheet(p * f, STAR_CELL / gZoom, dens)
         + starSheet(p * f * 1.7 + vec2(3.7, iTime * STAR_DRIFT),
                     STAR_CELL / (1.7 * gZoom), dens) * 0.8;
}
// --- mode sequencer ------------------------------------------------------------
// The ModeParams struct and the MODES playlist live in 00_knobs. The
// sequencer walks the playlist and swaps the global P between neighbours
// per pixel behind a circle wipe (WIPE_DUR) — so any mode expressible as parameters
// transitions for free. Structural modes (different traversal/tile content)
// branch on modeFrom/modeTo/modeBlend instead; keep those branches rare.

ModeParams P;          // active params, filled per frame by sequenceModes()
int   modeFrom  = 0;   // structural hooks branch on these
int   modeTo    = 0;
float modeBlend = 1.;  // eased from->to progress, 1 once settled
float modeTime  = 0.;  // seconds into the current playlist block
float gDropStart = 0.;

ModeParams mixParams(ModeParams a, ModeParams b, float t){
    return ModeParams(
        mix(a.pad, b.pad, t), mix(a.bg, b.bg, t),
        mix(a.light, b.light, t), mix(a.dark, b.dark, t),
        mix(a.ring, b.ring, t), mix(a.distort, b.distort, t),
        mix(a.wham, b.wham, t), mix(a.spec, b.spec, t),
        mix(a.cloud, b.cloud, t), mix(a.aur, b.aur, t),
        mix(a.warm, b.warm, t), mix(a.terra, b.terra, t),
        mix(a.neb, b.neb, t), mix(a.star, b.star, t),
        mix(a.squir, b.squir, t), mix(a.warhol, b.warhol, t),
        mix(a.big, b.big, t), mix(a.field, b.field, t),
        mix(a.drop, b.drop, t), mix(a.solid, b.solid, t),
        mix(a.halftone, b.halftone, t), mix(a.shadow, b.shadow, t));
}

float wipe(vec2 q, float t){
    float x = clamp(t / WIPE_DUR, 0., 1.);
    if(x >= 1.) return 1.;
    float r = (1. - pow(1. - x, 3.)) * (0.5 * length(iResolution.xy) / iResolution.y + 0.01);
    return S(length(q) - r);
}

ModeParams evalModes(vec2 q, float time, int devMode, float devAt){
    float skip = 0.;
    float since = time;
    if(devMode >= 0){
        for(int i = 0; i < devMode % MODE_COUNT; i++) skip += MODE_DUR[i];
        since = time - devAt;
    }
    float t = since + skip;
    float total = 0.;
    for(int i = 0; i < MODE_COUNT; i++) total += MODE_DUR[i];
    float c = mod(t, total);
    float acc = 0.;
    for(int i = 0; i < MODE_COUNT; i++){
        float d = MODE_DUR[i];
        if(c < acc + d){
            modeTo    = i;
            modeFrom  = (i + MODE_COUNT - 1) % MODE_COUNT;
            modeTime  = c - acc;
            modeBlend = wipe(q, modeTime);
            break;
        }
        acc += d;
    }
    // very first block (already active at iTime 0, wherever the skip landed
    // it): no flip-in from the notional previous mode
    if(since <= modeTime + 0.001) modeFrom = modeTo;
    if(MODES[modeTo].drop > 0.5) gDropStart = time - modeTime;
    else if(MODES[modeFrom].drop > 0.5) gDropStart = time - modeTime - MODE_DUR[modeFrom];
    ModeParams r = mixParams(MODES[modeFrom], MODES[modeTo], modeBlend);

    // clouds don't blend through transitions — the pad/zoom retune makes
    // them slide. instead they fade in for TRANS_DUR after the transition
    // lands, and fade out over the last TRANS_DUR before the next one
    float d = MODE_DUR[modeTo];
    r.cloud = MODES[modeTo].cloud
            * smoothstep(TRANS_DUR, 2.*TRANS_DUR, modeTime)
            * (1. - smoothstep(d - TRANS_DUR, d, modeTime));
    return r;
}

void sequenceModes(vec2 q){
    float sw = iTime - u_dev_switch_at;
    bool switching = sw >= 0. && sw < WIPE_DUR;
    ModeParams prev;
    if(switching) prev = evalModes(q, u_dev_switch_at, u_dev_prev_mode, u_dev_prev_at);
    P = evalModes(q, iTime, u_dev_mode, u_dev_mode_at);
    if(switching) P = mixParams(prev, P, wipe(q, sw));
}
// yamp scene body — see 00_knobs.glsl for the full scene description and
// 20_modes.glsl for the mode system. All mode-dependent values come from
// the global P; nothing here asks which mode is active.

vec3  SUN = vec3(0., 0.7, 0.7);   // sun direction, set in mainImage —
                                  // drives the glint and the aurora
float gCoast = 0.;  // coastline fbm amplitude for sdJ/sdP; set in
                    // mainImage for the scene, zeroed for the indicator
vec3  gPop = vec3(0.);  // warhol: this tile's pop color, set in quadTree
float gInv = 0.;        // warhol: 1 = inverted tile

// tile zoom pulse: up during rotate, hold, down during unfill
float pulseAnim(float n){
    float frame = mod(iTime*n*2.*SPEED, LOOP_LEN);
    if(frame >= ROT_START && frame < ROT_START+T_ROTATE)
        return cubicInOut((frame-ROT_START)/T_ROTATE);
    if(frame >= ROT_START+T_ROTATE && frame < UNFILL_START)
        return 1.;
    if(frame >= UNFILL_START && frame < UNFILL_START+T_UNFILL)
        return 1.-cubicInOut((frame-UNFILL_START)/T_UNFILL);
    return 0.;
}

// --- and& ampersand: baked SDF texture (gen_sdf.py) -------------------------
// iChannel0: R = J piece, G = P piece, B = glyph-space coastline fbm,
// glyph space [-SDF_BOX,SDF_BOX]^2 (v flipped), distances clamped to
// +-SDF_RANGE/2. The fbm is summed onto the distances (amplitude gCoast),
// sampled at the same uv — so the wobble is constant in the glyph frame
// and rotates/scales with each piece
const float PAD = 0.0464;      // design gap, measured from the artwork
const float SDF_BOX   = 0.75;
const float SDF_RANGE = 0.25;
float gFarPad = SDF_RANGE;

// the early-out branches return far + SDF_RANGE — clear of every coast
// band, so the switch never re-enters shelf/relief range (it used to sit
// at ~0.05, painting a phantom circular coastline around each amp). the
// max() keeps the field growing past the texture's clamp plateau
float sdJ(vec2 p) {
    float far = length(p) - 0.57;   // J fits in radius 0.554
    if (far > (gFarPad > 0. ? 0.05 : SDF_RANGE * 0.5)) return far + gFarPad;
    vec2 uv = vec2(p.x, -p.y)/(2.0*SDF_BOX) + 0.5;
    vec4 t = texture(iChannel0, uv);
    return max((t.r - 0.5) * SDF_RANGE + (t.b - 0.5) * gCoast, far);
}
float sdP(vec2 p) {
    float far = length(p) - 0.66;   // P fits in radius 0.646
    if (far > (gFarPad > 0. ? 0.09 : SDF_RANGE * 0.5)) return far + gFarPad;
    vec2 uv = vec2(p.x, -p.y)/(2.0*SDF_BOX) + 0.5;
    vec4 t = texture(iChannel0, uv);
    return max((t.g - 0.5) * SDF_RANGE + (t.b - 0.5) * gCoast, far);
}

// --- ampersand tile animation ----------------------------------------------
const vec2  CJ = vec2(-0.0644,-0.2581);   // J centroid (spin pivot)
const vec2  CP = vec2( 0.0148, 0.0562);   // P centroid
const vec2  SEED_J = vec2(-0.2871, 0.0267);  // wedge tip
const vec2  SEED_P = vec2(-0.0192, 0.4142);  // top of the loop
const float RJ = 0.76;                    // wipe radii covering each piece
const float RP = 1.04;

float fillAnim(float frame, float start){
    if(frame < start) return 0.;
    if(frame < start+T_FILL) return cubicInOut((frame-start)/T_FILL);
    if(frame < UNFILL_START) return 1.;
    if(frame < UNFILL_START+T_UNFILL) return 1.-cubicInOut((frame-UNFILL_START)/T_UNFILL);
    return 0.;
}

// brand gradient across the glyph (glyph space spans y in [-0.5,0.5])
vec3 ampGradient(vec2 p){
    return mix(GRAD_BOT, GRAD_TOP, clamp(p.y + 0.5, 0., 1.));
}

// cloud density — otavio's recipe on his texture (iChannel2, a lichen-rock
// photo): squared lookups at two scales, one flipped, multiplied and
// contrast-boosted; spiral-warped by a very-low-frequency sample of the
// same photo, which is where the cyclone swirls come from
float cloudDensity(vec2 cuv){
    float blur = texture(iChannel2, cuv * 0.0078).r;
    vec2 suv = spiral(cuv, blur * CLOUD_WARP);
    suv.x += iTime * CLOUD_DRIFT;
    float c1 = texture(iChannel2, suv).r;            c1 *= c1;
    float c2 = texture(iChannel2, 1. - suv * 0.5).r; c2 *= c2;
    return clamp(pow(max(c1 * c2, 0.), CLOUD_SHARP) * CLOUD_GAIN, 0., 1.);
}

vec3 drawAmp(vec2 p, float n, vec3 sq, float depth, float tileDepth, vec2 tp, vec2 tlp){
    // fake sphere: rn runs 0 at the tile center to 1 at the rim; with the
    // rim gradient that gives a surface normal
    float rn = clamp((1. - P.pad + sq.x) / (1. - P.pad), 0., 1.);
    vec3 N = vec3(sq.yz * rn, sqrt(max(1. - rn*rn, 0.)));
    float tshade = pow(1. - DARKEN, tileDepth);

    // tile distance in screen-height units: undo the zoom, the two fixed
    // x2 grid scales and the tile's subdivision levels
    float kk = 4. * exp2(tileDepth) * gZoom;
    float sqs = sq.x / kk;

    // content clip at the rim: fades out fully AT the rim so nothing leaks
    // through the border ring's outer AA, which is wider in screen space
    // than the local-unit glyph edges. in warhol (pad 0, no ring) the clip
    // flips outward instead, so the print runs flush to the square's edge —
    // the inset otherwise leaves a bg-colored grout line between tiles
    float rim = S(sqs + 1.3/iResolution.y * (1. - 2.*P.warhol));

    // the cloud sphere is CLOUD_HEIGHT larger than the ground, so clouds
    // overhang the limb; its rim clip sits that much further out, and the
    // clouds thin out over CLOUD_FADE approaching it
    float shell = CLOUD_HEIGHT * step(0.001, P.cloud) / kk;
    float cloudRim = S(sqs - shell + 1.3/iResolution.y)
                   * smoothstep(CLOUD_HEIGHT, CLOUD_HEIGHT - CLOUD_FADE, sq.x);

    // event horizon (3d): outside the tile the noise and stars get sucked
    // toward the rim and pile up into a bright horizon — background and tile
    // border in one. windowed to zero within the pad so neighbouring cells
    // agree
    float pull = PILE_BAND / (max(sq.x, 0.) + PILE_BAND);
    pull *= pull * smoothstep(max(P.pad, 1e-3), 0., sq.x);
    vec2 tps = tp + sq.yz * pull * PILE_PULL;
    float nse = texture(iChannel1, fract(tps)).r;
    vec3 base = vec3(mix(NOISE_LO, NOISE_HI, nse)) + stars(tps, P.star) * STAR_BRIGHT;
    // baked kaliset nebula (iChannel3, raw fields in rg), riding the same
    // background coords so it scrolls and gets pulled into the horizon
    // like the stars. squared -> dark space stays dark, hues stay stable
    if(P.neb > 0.001){
        vec2 nf = texture(iChannel3, tps * NEB_SCALE).rg * 2.;
        nf *= nf;
        base += (NEB1_COL * nf.x * NEB1_BRIGHT
               + NEB2_COL * nf.y * NEB2_BRIGHT) * P.neb;
    }

    // aurora: the horizon pile-up takes the atmosphere tint, plus a soft
    // additive glow. the sunset warming only appears when the sun is
    // actually BEHIND the planet (SUN.z < 0), on the rim facing it
    float sunset = pow(max(dot(sq.yz, normalize(SUN.xy)), 0.), AUR_SUN_POW)
                 * max(-SUN.z, 0.);
    vec3 aurTint = mix(vec3(1.), mix(AUR_COLOR, AUR_SUNSET, sunset), P.aur);
    vec3 v3 = vec3(base)
            + (base * PILE_GAIN + AUR_GLOW * pull * P.aur) * pull * aurTint;
    // tile interior: black, becoming ocean in terra mode, or the pop color
    // on inverted warhol tiles — unclipped, so zero-pad squares meet with
    // no dark seam at the shared edge
    vec3 col = mix(v3 * P.bg, WATER_COL * P.terra, S(sq.x));
    col = mix(col, gPop * tshade, P.warhol * gInv);

    // outside pixels are done — skip both glyph SDFs entirely
    if ((sqs - shell) * iResolution.y > 1.5) return col;

    float frame = mod(iTime*n*2.*SPEED, LOOP_LEN);
    // terra: pad the amps within their cells so the coast bands get room
    // before the cell boundary
    float ampScale = AMP_SCALE * (1. - AMP_PAD * P.terra);
    p /= ampScale;

    // rotate state: J and P counter-spin a full turn
    vec2 pJ = p, pP = p;
    if(frame >= ROT_START && frame < ROT_START+T_ROTATE){
        float a = cubicInOut((frame-ROT_START)/T_ROTATE)*6.28318530718;
        float dir = (fract(n)<0.5)? -1. : 1.;
        pJ = rotAround(p, CJ, dir*a);
        pP = rotAround(p, CP, -dir*a);
    }

    float dj = sdJ(pJ);
    float dp = max(sdP(pP), PAD - dj);            // P with the J carved out
    float dAmp = min(dj, dp) * ampScale;

    // terra: soften the glyphs — a constant inset rounds the 90° corners
    float cw = -CORNER_ROUND * P.terra;
    dAmp += cw;
    dAmp = max(sq.x, dAmp);
    // terra: detail mottling, dirt specks (a spiral-distorted cloud-texture
    // lookup), and a shallow shelf on the water approaching a coast (the
    // land overdraws its inside half)
    float dmod = 1., spk = 0., cellW = 1.;
    if(P.terra > 0.001){
        float det = texture(iChannel2, tlp * DETAIL_SCALE + 0.37).g;
        dmod = 1. + (det - 0.5) * DETAIL_AMT;
        spk = texture(iChannel2, spiral(tlp * SPECK_SCALE + 0.71, SPECK_WARP)).r;
        spk = smoothstep(SPECK_LO, SPECK_HI, spk * spk) * SPECK_AMT;
        // cell-edge window: coast bands die out before the amp cell
        // boundary so neighbouring cells agree (the horizon-pad trick)
        cellW = smoothstep(0., COAST_W, 0.5/ampScale - max(abs(p.x), abs(p.y)));
        col = mix(col, WATER_SHALL,
                  smoothstep(COAST_W, 0., dAmp) * cellW * rim * P.terra);
    }

    // grey base, darker per subdivision level; in terra mode: a sand ring
    // at the waterline, detail-modulated specked lowland inside. warhol:
    // the print color (black on inverted tiles), same depth shading
    vec3 terrLand = mix(SAND_COL, mix(LAND_COL * dmod, SPECK_COL, spk),
                        smoothstep(0., -SAND_W, dAmp));
    vec3 ampBase = mix(vec3(0.3), terrLand, P.terra);
    ampBase = mix(ampBase, gPop * (1. - gInv), P.warhol);
    col = mix(col, ampBase * pow(1. - DARKEN, depth), S(dAmp) * rim);

    // fill states: brand-gradient wipes clipped inside each piece
    float fj = fillAnim(frame, FILLJ_START);
    float fp = fillAnim(frame, FILLP_START);
    float wj = max(dj, length(pJ-SEED_J) - (fj*(RJ+0.02)-0.02));
    float wp = max(dp, length(pP-SEED_P) - (fp*(RP+0.02)-0.02));
    float dw = min(wj, wp) * ampScale + cw;   // same terra softening
    dw = max(sq.x, dw);
    // brand-gradient fill; in terra mode snow-covered high terrain with a
    // thin rock rim, detail mottling toned down on the snow. suppressed in
    // warhol — tiles keep their printed color and just sit
    vec3 fillCol = mix(ampGradient(p),
                       mix(HIGH_BOT, HIGH_TOP, smoothstep(0., -SNOW_D, dw))
                       * mix(1., dmod, SNOW_DETAIL),
                       P.terra);
    col = mix(col, fillCol, S(dw) * rim * (1. - P.warhol));

    // emboss: terrain slopes facing the sun brighten, away-facing darken,
    // strongest right at coasts and ridges. the SDF gradients come from
    // screen derivatives (y flipped back to scene orientation)
    if(P.terra > 0.001){
        vec2 sxy = normalize(SUN.xy);
        vec2 gc = vec2(dFdx(dAmp), -dFdy(dAmp));
        vec2 gr_ = vec2(dFdx(dw),  -dFdy(dw));
        float rel = dot(normalize(gc + 1e-5), sxy) * smoothstep(RELIEF_W, 0., abs(dAmp))
                  + dot(normalize(gr_ + 1e-5), sxy) * smoothstep(RELIEF_W, 0., abs(dw));
        col *= 1. + rel * RELIEF * P.terra * rim * cellW;
    }

    // clouds, drawn before the shade so they get lit and shadowed too.
    // toy-planet height: the ground is darkened by the cloud shell sunward
    // of it, so the clouds float visibly above their own drop shadows
    if(P.cloud > 0.001){
        vec2 cuv = tlp * CLOUD_SCALE;
        float shadow = cloudDensity(cuv + SUN.xy * CLOUD_HEIGHT * CLOUD_SCALE);
        col = mix(col, vec3(0.), shadow * CLOUD_SHADOW * P.cloud * rim);
        col = mix(col, vec3(1.), cloudDensity(cuv) * P.cloud * cloudRim);
    }

    // sun diffuse on the fake sphere — lift the lit side toward white,
    // shadow the night side toward black, terminator where dot(N,SUN)
    // crosses zero. the lift is scaled by the TILE's depth shade (never
    // the per-amp one, which would break the gradient inside a tile); the
    // shadow is relative, so it reads the same at every depth
    float dif = dot(N, SUN);
    col = mix(col, vec3(1.), max( dif, 0.) * P.light * tshade * S(sq.x));
    col = mix(col, vec3(0.), max(-dif, 0.) * P.dark * S(sq.x));

    // sun glint: blinn-phong specular on the fake sphere normal, over
    // everything under the glass; in terra mode only the water reflects
    vec3 H = normalize(SUN + vec3(0., 0., 1.));
    col += mix(SUN_WHITE, SUN_COL, P.warm)
         * pow(max(dot(N, H), 0.), SPEC_POW) * SPEC_GAIN * P.spec * rim
         * (1. - S(dAmp) * rim * P.terra);

    // atmospheric haze: a constant veil over the whole disc, plus more
    // toward the limb where the view ray crosses more air (N.z -> 0)
    float haze = (ATMO_BASE + pow(1. - N.z, ATMO_POW) * ATMO_HAZE) * P.aur;
    col = mix(col, HAZE_COL, haze * S(sq.x));

    // hard border ring on the rim, gated by P.ring. drawn on the
    // screen-space distance so every level gets the same thickness, and
    // darkened per subdivision level like the amps
    float dring = abs(sqs + RING_WIDTH) - RING_WIDTH;
    col = mix(col, vec3(RING_BRIGHT) * tshade, S(dring) * P.ring);
    return col;
}

vec3 quadTree(vec2 p, float nn, float depth, vec2 tp){
    p*=2.;
    vec3 sq = sdSquircle(p, 1. - P.pad, mix(SQUIRCLENESS, 1., P.squir));

    // warhol identity: each tile hashes a palette color and an invert flip
    gPop = WARHOL_COLS[int(min(fract(nn*13.7)*4., 3.))];
    gInv = step(fract(nn*29.3), WARHOL_INV);

    // glass: inside the rim band the content is sampled outward along the
    // squircle gradient, so the amps look refracted near the edge
    float lens = smoothstep(-DISTORT_BAND, 0., sq.x);
    p += sq.yz * lens*lens * P.distort;

    // cloud coords: anchored to the squircle (not the scrolling amp grid
    // inside it), offset by the TILE's seed so each planet differs
    vec2 tlp = p*0.5 + fract(nn * vec2(7.13, 3.71)) * 4.;

    // with a large pad the planet shrinks — zoom the content out to match
    float zf = 1. + P.pad / (1. - P.pad) * PAD_ZOOM;
    p *= zf;

    // extra-large level: sometimes the whole cell is one huge ampersand
    if(fract(nn*57.31) < P.big){
        return drawAmp(p*0.5, nn+0.3, sq, depth, depth, tp, tlp);
    }

    if(nn<0.5){
        float v = iTime*mix(SCROLL_MIN, SCROLL_MAX, nn*2.);
        p.y-=v+nn;
        p*=1.2;
        // the clouds ride the tile's content scroll (same screen velocity)
        // on top of their own drift
        tlp.y -= 0.5 * v / zf;
    } else {
        p*=1.2+pulseAnim(nn)*0.5;
    }

    vec2 id = floor(p);
    vec2 gr = (p-id)-0.5;

    float n = random(id)*nn;
    float n2 = n;
    vec2 cell = id;
    float ad = depth;   // per-amp depth; `depth` stays the tile's

    // four subdivision levels (the last two add the extra-small amps)
    float thresholds[4] = float[](0.3+nn, 0.8+nn, 0.9+nn*0.5, 0.93+nn*0.5);

    for (int i = 0; i < 4; i++)
    {
        n = random(cell + id + float(i) * 12.34+nn);

        if (n < thresholds[i])
            break;

        gr *= 2.0;
        cell = floor(gr);
        gr = fract(gr) - 0.5;
        ad += 1.;
    }

    return drawAmp(gr, n2+nn, sq, ad, depth, tp, tlp);
}

vec3 render(vec2 p, vec2 tp){
    p.y-=iTime*SCROLL;
    p*=2.;
    vec2 id = floor(p);
    vec2 gr = (p-id)-0.5;

    float n = random(id);
    float n2 = n;
    vec2 cell = id;
    float depth = 0.;

    float thresholds[3] = float[](0.6, 0.8, 0.9);

    for (int i = 0; i < 3; i++)
    {
        n = random(cell + id + float(i) * 12.34);

        if (n < thresholds[i])
            break;

        gr *= 2.0;
        cell = floor(gr);
        gr = fract(gr) - 0.5;
        depth += 1.;
    }

    return quadTree(gr, n2, depth, tp);
}

float goldBand(vec2 q, vec2 dir, vec2 nrm, float t, float side){
    if(t < 0. || t > 1.) return 0.;
    float front = side * mix(-GOLD_REACH, GOLD_REACH, t);
    float s = side * (dot(q, nrm) - front)
            + GOLD_WOBBLE * sin(dot(q, dir) * 5. + iTime * 1.3);
    float w = s > 0. ? GOLD_FRONT : GOLD_TAIL;
    return exp(-s * s / (w * w));
}

float goldWave(vec2 q, vec2 dir, vec2 nrm){
    float k = floor(iTime / GOLD_PERIOD);
    float start = k * GOLD_PERIOD + random(vec2(k, 3.1)) * (GOLD_PERIOD - GOLD_DUR);
    float side = (random(vec2(k, 5.9)) < 0.5) ? -1. : 1.;
    float g = goldBand(q, dir, nrm, (iTime - start) / GOLD_DUR, side);
    float mside = (fract(u_dev_gold_at * 7.31) < 0.5) ? -1. : 1.;
    return max(g, goldBand(q, dir, nrm, (iTime - u_dev_gold_at) / GOLD_DUR, mside));
}

vec3 field(vec2 p, vec2 q, vec2 tp){
    vec2 dir = vec2(cos(FIELD_ANGLE), sin(FIELD_ANGLE));
    vec2 nrm = vec2(-dir.y, dir.x);
    float u = dot(p, dir) * FIELD_ROWS;
    float v = dot(p, nrm) * FIELD_ROWS;
    v += FIELD_WAVE_AMP * sin(u * FIELD_WAVE_FREQ + iTime * FIELD_WAVE_RATE);
    float lane = floor(v);
    float ph = lane * FIELD_LANE_FREQ + iTime * FIELD_LANE_RATE;
    u -= FIELD_SPEED * (iTime - FIELD_LANE_VAR * cos(ph) / FIELD_LANE_RATE)
       + random(vec2(lane, 7.7)) * 13.;
    vec2 id = mod(vec2(floor(u), lane), 1024.);
    vec2 l = vec2(fract(u), fract(v)) - 0.5;
    vec2 lo = l.x * dir + l.y * nrm;
    float g = goldWave(q - lo / (FIELD_ROWS * gZoom), dir, nrm);
    float gb = goldWave(q, dir, nrm);
    float amp = FIELD_AMP * (1. + GOLD_SWELL * g);
    vec2 gp = lo / amp;

    float n = random(id);
    float frame = mod(iTime * mix(FIELD_CLOCK.x, FIELD_CLOCK.y, n) * 2. * SPEED
                      + n * LOOP_LEN, LOOP_LEN);
    vec2 pJ = gp, pP = gp;
    if(frame >= ROT_START && frame < ROT_START+T_ROTATE){
        float a = cubicInOut((frame-ROT_START)/T_ROTATE)*6.28318530718;
        float sd = (fract(n*7.3) < 0.5) ? -1. : 1.;
        pJ = rotAround(gp, CJ, sd*a);
        pP = rotAround(gp, CP, -sd*a);
    }
    float dj = sdJ(pJ);
    float dp = max(sdP(pP), PAD - dj);
    float k = amp / (FIELD_ROWS * gZoom);

    vec3 col = vec3(mix(NOISE_LO, NOISE_HI, texture(iChannel1, fract(tp)).r));
    col += GOLD_BOT * GOLD_GLOW * gb;
    float da = min(dj, dp);
    col = mix(col, vec3(0.3), S(da * k));
    float fj = fillAnim(frame, FILLJ_START);
    float fp = fillAnim(frame, FILLP_START);
    float wj = max(dj, length(pJ-SEED_J) - (fj*(RJ+0.02)-0.02));
    float wp = max(dp, length(pP-SEED_P) - (fp*(RP+0.02)-0.02));
    col = mix(col, ampGradient(gp), S(min(wj, wp) * k));
    vec3 gold = mix(GOLD_BOT, GOLD_TOP, clamp(gp.y + 0.5, 0., 1.));
    return mix(col, gold, g * S(da * k));
}

vec3 drop(vec2 q, vec2 tp){
    float cs = 1. / DROP_ROWS;
    float tau = iTime - gDropStart;
    float cyc = floor(tau / DROP_CYCLE);
    tau -= cyc * DROP_CYCLE;
    float flushAt = DROP_CYCLE - DROP_FLUSH;
    float fl = max(tau - flushAt, 0.);
    float sink = 0.5 * DROP_G * fl * fl;
    float tspawn = min(tau, flushAt);

    float c = floor(q.x / cs);
    float lx = fract(q.x / cs) - 0.5;
    float h = (q.y + 0.5) / cs;
    float top = DROP_ROWS + 1.;
    vec2 cid = vec2(c, cyc * 17.3);
    float rate = mix(DROP_RATE.x, DROP_RATE.y, random(cid + 0.17));
    float ns = floor(tspawn * rate);
    float j0 = floor(h + sink);

    vec3 col = vec3(mix(NOISE_LO, NOISE_HI, texture(iChannel1, fract(tp)).r));
    float kscr = DROP_AMP * cs;
    for(int i = 0; i < 5; i++){
        float k = (i == 0) ? j0 : ns - float(i - 1);
        if(k < 0. || k >= DROP_ROWS) continue;
        if(i > 0 && k == j0) continue;
        float s = (k + DROP_JITTER * random(cid + k * 1.31)) / rate;
        if(s > tspawn) continue;
        float tf = sqrt(2. * (top - k) / DROP_G);
        float dt = tau - s;
        float tilt = (random(cid + k * 2.7) - 0.5) * 2. * DROP_TILT;
        float y, ang;
        if(dt < tf){
            y = top - 0.5 * DROP_G * dt * dt;
            ang = tilt + DROP_SPIN * (tf - dt) * sign(random(cid + k * 3.3) - 0.5);
        } else {
            float b = dt - tf;
            y = k + DROP_BOUNCE * exp(-b * 8.) * abs(sin(b * 18.));
            ang = tilt;
        }
        y -= sink;
        vec2 gp = vec2(lx, h - y - 0.5) / DROP_AMP;
        if(dot(gp, gp) > 1.) continue;
        gp = gp * Rot(ang);
        float dj = sdJ(gp);
        float dp = max(sdP(gp), PAD - dj);
        vec3 ac = random(cid + k * 5.1) < DROP_FILL ? ampGradient(gp) : vec3(0.3);
        col = mix(col, ac, S(min(dj, dp) * kscr));
    }
    return col;
}

float glyphDist(vec2 p){
    float dj = sdJ(p);
    return min(dj, max(sdP(p), PAD - dj));
}

float solidMap(vec3 p){
    vec2 w = vec2(glyphDist(p.xy) + SOLID_BEVEL, abs(p.z) - SOLID_DEPTH + SOLID_BEVEL);
    return min(max(w.x, w.y), 0.) + length(max(w, 0.)) - SOLID_BEVEL;
}

vec3 solidNormal(vec3 p){
    vec2 e = vec2(SOLID_NEPS, 0.);
    vec2 g = vec2(glyphDist(p.xy + e.xy) - glyphDist(p.xy - e.xy),
                  glyphDist(p.xy + e.yx) - glyphDist(p.xy - e.yx));
    g = normalize(g + 1e-7);
    vec2 w = vec2(glyphDist(p.xy) + SOLID_BEVEL, abs(p.z) - SOLID_DEPTH + SOLID_BEVEL);
    vec2 nw = (w.x > 0. && w.y > 0.) ? normalize(w)
            : (w.x > w.y ? vec2(1., 0.) : vec2(0., 1.));
    return normalize(vec3(g * nw.x, sign(p.z) * nw.y));
}

float solidLight(vec3 n, vec3 L, vec3 F, vec3 up, float amb){
    return amb * mix(SOLID_GROUND, 1., dot(n, up) * 0.5 + 0.5)
         + (1. - amb) * max(dot(n, L), 0.)
         + SOLID_FILL * max(dot(n, F), 0.);
}

vec3 acesApprox(vec3 v){
    v = max(v, 0.) * 0.6;
    return clamp((v * (2.51 * v + 0.03)) / (v * (2.43 * v + 0.59) + 0.14), 0., 1.);
}

float raySphere4Inner(vec3 ro, vec3 rd, float ra){
    float r2 = ra * ra;
    vec3 d2 = rd * rd, d3 = d2 * rd, o2 = ro * ro, o3 = o2 * ro;
    float ka = 1. / dot(d2, d2);
    float k3 = ka * dot(ro, d3);
    float k2 = ka * dot(o2, d2);
    float k1 = ka * dot(o3, rd);
    float k0 = ka * (dot(o2, o2) - r2 * r2);
    float c2 = k2 - k3 * k3;
    float c1 = k1 + 2. * k3 * k3 * k3 - 3. * k3 * k2;
    float c0 = k0 - 3. * k3 * k3 * k3 * k3 + 6. * k3 * k3 * k2 - 4. * k3 * k1;
    float p = c2 * c2 + c0 / 3.;
    float q = c2 * c2 * c2 - c2 * c0 + c1 * c1;
    float h = q * q - p * p * p;
    if(h < 0.) return -1.;
    float sh = sqrt(h);
    float s = sign(q + sh) * pow(abs(q + sh), 1. / 3.);
    float t = sign(q - sh) * pow(abs(q - sh), 1. / 3.);
    vec2 w = vec2(s + t, s - t);
    vec2 v = vec2(w.x + c2 * 4., w.y * sqrt(3.)) * 0.5;
    float r = length(v);
    return abs(v.y) / sqrt(r + v.x) - c1 / r - k3;
}

vec3 superquadricEnv(vec3 ro, vec3 rd){
    vec3 o = vec3(0.);
    float A = 1.;
    vec3 L = normalize(SQ_LIGHT);
    for(int i = 0; i < 3; i++){
        if(A < 0.05) break;
        float z = raySphere4Inner(ro, rd, SQ_ROOM);
        if(z <= 0.) break;
        vec3 p = ro + rd * z;
        vec3 n = -normalize(p * p * p);
        float f = 1. + dot(n, rd);
        f *= f;
        o += A * pow(max(0., dot(n, L)), 9.) * (SQ_OFFSET + sin(-f + SQ_BASE));
        A *= mix(.3, .7, f);
        rd = reflect(rd, n);
        ro = p + 2e-3 * n;
    }
    vec3 c = acesApprox(o * SQ_GAIN);
    return mix(1.055 * pow(c, vec3(1. / 2.4)) - 0.055, 12.92 * c, step(c, vec3(0.0031308)));
}

float solidMarch(vec3 ro, vec3 rd, int steps, out float dmin, out float tmin){
    dmin = 1e9;
    tmin = 0.;
    vec3 bx = vec3(0.7, 0.7, SOLID_DEPTH + 0.01);
    vec3 m = 1. / (rd + vec3(1e-6));
    vec3 n0 = m * ro;
    vec3 k = abs(m) * bx;
    vec3 t1 = -n0 - k, t2 = -n0 + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    if(tN > tF || tF < 0.) return -1.;
    float t = max(tN, 0.);
    tmin = t;
    for(int i = 0; i < steps; i++){
        float d = solidMap(ro + rd * t);
        if(d < dmin){ dmin = d; tmin = t; }
        if(d < max(0.0002, t * SOLID_HIT_PX / (SOLID_FOCAL * iResolution.y))) return t;
        t += d * 0.9;
        if(t > tF) break;
    }
    return -1.;
}

vec3 solidSample(vec2 q, vec2 tp){
    vec3 bg = mix(GRAD_BOT, GRAD_TOP, 0.5) * SOLID_GLOW * (1. - smoothstep(0., SOLID_GLOW_R, length(q)))
            + vec3(mix(NOISE_LO, NOISE_HI, texture(iChannel1, fract(tp)).r));

    float a = iTime * SOLID_SPIN;
    float b = SOLID_TILT * sin(iTime * SOLID_TILT_RATE);
    mat3 ry = mat3(cos(a), 0., -sin(a), 0., 1., 0., sin(a), 0., cos(a));
    mat3 rx = mat3(1., 0., 0., 0., cos(b), sin(b), 0., -sin(b), cos(b));
    mat3 M = ry * rx;
    mat3 Mi = transpose(M);

    vec3 rd = normalize(vec3(q, SOLID_FOCAL));
    vec3 oro = Mi * vec3(0., 0., -SOLID_DIST);
    vec3 ord = Mi * rd;

    float dmin, tmin;
    float t = solidMarch(oro, ord, SOLID_STEPS, dmin, tmin);
    bool hit = t >= 0.;
    if(!hit && dmin > 1e8) return bg;
    float px = tmin / (SOLID_FOCAL * iResolution.y);
    float cov = hit ? 1. : 1. - smoothstep(0., 1.5 * px, dmin);
    if(cov < 0.001) return bg;
    if(!hit) t = tmin;

    vec3 L = Mi * normalize(SOLID_LIGHT);
    vec3 Fo = Mi * normalize(SOLID_FILL_DIR);
    vec3 up = Mi * vec3(0., 1., 0.);
    vec3 matte = vec3(0.);
    {
        vec3 po = oro + ord * t;
        vec3 no = solidNormal(po);
        vec3 base = ampGradient(po.xy) * mix(1., 0.5, 1. - abs(no.z));
        float dif = max(dot(no, L), 0.);
        float spec = pow(max(dot(no, normalize(L - ord)), 0.), MATTE_SHINE);
        matte = base * solidLight(no, L, Fo, up, MATTE_AMBIENT) + vec3(spec) * MATTE_SPEC;
    }
    if(u_solid_matte > 0.999) return mix(bg, matte, cov);

    vec3 col = vec3(0.);
    float A = 1.;
    vec3 ro = oro, dir = ord;
    for(int bnc = 0; bnc <= SOLID_BOUNCES; bnc++){
        vec3 po = ro + dir * t;
        vec3 no = solidNormal(po);
        vec3 base = ampGradient(po.xy) * mix(1., 0.5, 1. - abs(no.z));
        float dif = max(dot(no, L), 0.);
        float spec = pow(max(dot(no, normalize(L - dir)), 0.), SOLID_SHINE);
        col += A * (base * solidLight(no, L, Fo, up, 0.12) * SOLID_KD + vec3(spec) * SOLID_SPEC);
        float f = 1. + dot(no, dir);
        f *= f;
        A *= mix(.3, .7, f) * SOLID_REFL;
        dir = reflect(dir, no);
        ro = po + no * 0.015;
        if(bnc == SOLID_BOUNCES) break;
        float dm, tm;
        t = solidMarch(ro, dir, SOLID_STEPS / 2, dm, tm);
        if(t < 0.) break;
    }
    col += A * superquadricEnv(M * ro, M * dir);
    return mix(bg, mix(col, matte, u_solid_matte), cov);
}

vec3 solid(vec2 q, vec2 tp){
    gFarPad = 0.;
    vec3 c = vec3(0.);
    float px = 1. / iResolution.y;
    for(int i = 0; i < SOLID_SS; i++)
        for(int j = 0; j < SOLID_SS; j++){
            vec2 o = (vec2(i, j) + 0.5) / float(SOLID_SS) - 0.5;
            c += solidSample(q + o * px, tp);
        }
    gFarPad = SDF_RANGE;
    return c / float(SOLID_SS * SOLID_SS);
}

vec3 halftone(vec2 q, vec2 tp){
    float ca = cos(HALF_ANGLE), sa = sin(HALF_ANGLE);
    mat2 R = mat2(ca, sa, -sa, ca);
    vec2 u = R * q * HALF_ROWS;
    vec2 cid = floor(u);
    vec2 l = transpose(R) * (fract(u) - 0.5);
    vec2 qc = transpose(R) * ((cid + 0.5) / HALF_ROWS);

    float a = iTime * HALF_SPIN;
    float b = HALF_TILT * sin(iTime * HALF_TILT_RATE);
    mat3 ry = mat3(cos(a), 0., -sin(a), 0., 1., 0., sin(a), 0., cos(a));
    mat3 rx = mat3(1., 0., 0., 0., cos(b), sin(b), 0., -sin(b), cos(b));
    mat3 M = ry * rx;
    mat3 Mi = transpose(M);
    vec3 rd = normalize(vec3(qc, SOLID_FOCAL));
    vec3 oro = Mi * vec3(0., 0., -HALF_DIST);
    vec3 ord = Mi * rd;

    gFarPad = 0.;
    float dmin, tmin;
    float t = solidMarch(oro, ord, SOLID_STEPS, dmin, tmin);
    float lum = HALF_BG, glint = 0., gy = 0.;
    if(t >= 0.){
        vec3 po = oro + ord * t;
        vec3 nw = M * solidNormal(po);
        float la = iTime * HALF_ORBIT;
        vec3 L = normalize(vec3(cos(la), sin(la), -HALF_LIGHT_Z));
        lum = HALF_AMBIENT + (1. - HALF_AMBIENT) * max(dot(nw, L), 0.);
        lum = clamp((lum - 0.5) * HALF_CONTRAST + 0.5, 0., 1.);
        glint = pow(max(dot(reflect(-L, nw), -rd), 0.), HALF_SHINE) * HALF_GLINT;
        gy = po.y;
    }
    gFarPad = SDF_RANGE;

    vec3 col = vec3(mix(NOISE_LO, NOISE_HI, texture(iChannel1, fract(tp)).r));
    float s = HALF_MAX * sqrt(clamp(lum, 0., 1.));
    if(s < 0.01) return col;
    vec2 gp = l / s;
    float dj = sdJ(gp);
    float d = min(dj, max(sdP(gp), PAD - dj));
    vec3 tint = mix(HALF_GREY, mix(GRAD_BOT, GRAD_TOP, clamp(gy + 0.5, 0., 1.)), smoothstep(HALF_TINT_LO, HALF_TINT_HI, lum));
    vec3 ink = mix(tint, vec3(1.), glint);
    return mix(col, ink, S(d * s / HALF_ROWS));
}

float solidShadow(vec3 ro, vec3 rd, float tmax){
    vec3 bx = vec3(0.85, 0.85, SOLID_DEPTH + 0.15);
    vec3 m = 1. / (rd + vec3(1e-6));
    vec3 n0 = m * ro;
    vec3 k = abs(m) * bx;
    vec3 t1 = -n0 - k, t2 = -n0 + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    if(tN > tF || tF < 0. || tN > tmax) return 1.;
    float res = 1.;
    float t = max(tN, 0.);
    for(int i = 0; i < SHADOW_STEPS; i++){
        float d = solidMap(ro + rd * t);
        if(d < 0.0005) return 0.;
        if(d < 0.1) res = min(res, SHADOW_K * d / t);
        t += clamp(d, 0.002, 0.1);
        if(t > tF) break;
    }
    res = clamp(res, 0., 1.);
    return res * res * (3. - 2. * res);
}

float gPx = 0.001;

float floorBoards(vec2 xz){
    float u = xz.x / SHADOW_PLANK_W;
    float ix = floor(u);
    float v = (xz.y + random(vec2(ix, 1.7)) * SHADOW_PLANK_L) / SHADOW_PLANK_L;
    float iz = floor(v);
    vec2 e = vec2(min(fract(u), 1. - fract(u)) * SHADOW_PLANK_W,
                  min(fract(v), 1. - fract(v)) * SHADOW_PLANK_L);
    vec2 fw = vec2(gPx) + 1e-5;
    float gap = smoothstep(0., 1.5, min(e.x / fw.x, e.y / fw.y) * 0.5)
              * smoothstep(0., SHADOW_PLANK_GAP, min(e.x, e.y));
    float tone = mix(1. - SHADOW_PLANK_VAR, 1. + SHADOW_PLANK_VAR, random(vec2(ix, iz)));
    float grain = texture(iChannel2, vec2(xz.x * 0.7 + ix * 0.37, xz.y * 0.06 + iz * 0.21)).r;
    return tone * mix(0.65, 1.25, grain) * mix(SHADOW_PLANK_DARK, 1., gap);
}

float skirtProfile(vec2 p){
    float D = SHADOW_SKIRT_D, H = SHADOW_SKIRT_H;
    float R = D * SHADOW_SKIRT_BEAD;
    float hb = H - R;
    vec2 q = abs(p - vec2(D * 0.5, hb * 0.5)) - vec2(D * 0.5, hb * 0.5);
    float board = length(max(q, 0.)) + min(max(q.x, q.y), 0.);
    float bead = length(p - vec2(D * 0.55, hb)) - R;
    float k = R * 0.8;
    float h = clamp(0.5 + 0.5 * (bead - board) / k, 0., 1.);
    float d = mix(bead, board, h) - k * h * (1. - h);
    return d;
}

float skirtUnion(vec3 p){
    return min(skirtProfile(vec2(SHADOW_WALL_Z - p.z, p.y)), skirtProfile(vec2(p.x - SHADOW_SIDE_X, p.y)));
}

float sdRoundCone(vec3 p, vec3 a, vec3 b, float r1, float r2){
    vec3 ba = b - a;
    float l2 = dot(ba, ba);
    float rr = r1 - r2;
    float a2 = l2 - rr * rr;
    float il2 = 1. / l2;
    vec3 pa = p - a;
    float y = dot(pa, ba);
    float z = y - l2;
    vec3 xv = pa * l2 - ba * y;
    float x2 = dot(xv, xv);
    float y2 = y * y * l2;
    float z2 = z * z * l2;
    float k = sign(rr) * rr * rr * x2;
    if(sign(z) * a2 * z2 > k) return sqrt(x2 + z2) * il2 - r2;
    if(sign(y) * a2 * y2 < k) return sqrt(x2 + y2) * il2 - r1;
    return (sqrt(x2 * a2 * il2) + y * rr) * il2 - r1;
}

vec3 couchTop(int i){
    return vec3(i < 2 ? -0.17 : -SHADOW_COUCH_W + 0.17, SHADOW_COUCH_LEG + 0.02, i % 2 == 0 ? 0.2 : SHADOW_COUCH_L - 0.2);
}

vec3 couchFoot(int i){
    vec3 h = couchTop(i);
    return vec3(h.x + (i < 2 ? SHADOW_LEG_SPLAY : -SHADOW_LEG_SPLAY), SHADOW_LEG_TOE, h.z + (i % 2 == 0 ? -SHADOW_LEG_SPLAY : SHADOW_LEG_SPLAY));
}

float couchSdf(vec3 p, out float foot){
    vec3 b = vec3(SHADOW_COUCH_W, SHADOW_COUCH_TOP - SHADOW_COUCH_LEG, SHADOW_COUCH_L) * 0.5;
    vec3 q = abs(p - vec3(-b.x, SHADOW_COUCH_LEG + b.y, b.z)) - b + 0.08;
    float body = length(max(q, 0.)) + min(max(q.x, max(q.y, q.z)), 0.) - 0.08;
    float leg = 1e9, mat = 1.;
    for(int i = 0; i < 4; i++){
        vec3 lo = couchFoot(i);
        vec3 hi = couchTop(i);
        float d = sdRoundCone(p, lo, hi, SHADOW_LEG_TOE, SHADOW_LEG_TOP);
        vec3 pq = abs(p - vec3(hi.x, SHADOW_COUCH_LEG, hi.z)) - vec3(0.07, 0.012, 0.07);
        float plate = length(max(pq, 0.)) + min(max(pq.x, max(pq.y, pq.z)), 0.);
        if(d < leg){
            leg = d;
            mat = (p.y - lo.y + SHADOW_LEG_TOE) < SHADOW_LEG_FERRULE ? 2. : 1.;
        }
        if(plate < leg){ leg = plate; mat = 1.; }
    }
    foot = leg < body ? mat : 0.;
    return min(body, leg);
}

float couchShadow(vec3 ro, vec3 rd, float tmax){
    vec3 bmin = vec3(-SHADOW_COUCH_W - 0.1, 0., -0.2), bmax = vec3(0.15, SHADOW_COUCH_TOP + 0.1, SHADOW_COUCH_L + 0.2);
    vec3 inv = 1. / (rd + vec3(1e-6));
    vec3 ta = (bmin - ro) * inv, tb = (bmax - ro) * inv;
    vec3 t0 = min(ta, tb), t1 = max(ta, tb);
    float tN = max(max(t0.x, t0.y), t0.z), tF = min(min(t1.x, t1.y), min(t1.z, tmax));
    if(tN > tF || tF < 0.) return 1.;
    float res = 1., t = max(tN, 0.01), foot;
    for(int i = 0; i < 64; i++){
        float d = couchSdf(ro + rd * t, foot);
        if(d < 0.001) return 0.;
        res = min(res, SHADOW_K * 0.25 * d / t);
        t += clamp(d, 0.01, 0.4);
        if(t > tF) break;
    }
    return clamp(res, 0., 1.);
}

float felt(vec3 p, vec3 n){
    vec3 w = pow(abs(n), vec3(4.));
    w /= w.x + w.y + w.z;
    vec3 s = p * SHADOW_FELT_SCALE;
    float m = 0.;
    for(int i = 0; i < 2; i++){
        vec3 o = s * (i == 0 ? 1. : 2.3);
        m += (texture(iChannel1, fract(o.yz)).r * w.x + texture(iChannel1, fract(o.xz)).r * w.y + texture(iChannel1, fract(o.xy)).r * w.z) * 0.5;
    }
    vec3 f = p * SHADOW_FELT_FINE;
    float g = texture(iChannel1, fract(f.yz)).r * w.x + texture(iChannel1, fract(f.xz)).r * w.y + texture(iChannel1, fract(f.xy)).r * w.z;
    vec3 z = p * SHADOW_FELT_STONE_SCALE;
    float st = texture(iChannel2, z.yz).r * w.x + texture(iChannel2, z.xz).r * w.y + texture(iChannel2, z.xy).r * w.z;
    return mix(1. - SHADOW_FELT_MOTTLE, 1. + SHADOW_FELT_MOTTLE, m) * mix(1. - SHADOW_FELT_GRAIN, 1. + SHADOW_FELT_GRAIN, g)
         * mix(1., st, SHADOW_FELT_STONE);
}

vec2 gOutletPos, gOutletQ;
vec2 gCableDir;
vec2 gPath[5];
vec3 gPhoneC;
vec2 gPhoneU, gPhoneR;

vec3 bez3(vec3 a, vec3 b, vec3 c, vec3 d, float t){
    float s = 1. - t;
    return s * s * s * a + 3. * s * s * t * b + 3. * s * t * t * c + t * t * t * d;
}

float capsuleDist(vec3 p, vec3 a, vec3 b){
    vec3 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0., 1.));
}

float cableSdf(vec3 q){
    float S = SHADOW_OUTLET_SCALE;
    vec2 hs = SHADOW_OUTLET_SIZE * 0.5;
    float r = SHADOW_CABLE_R;
    float z0 = SHADOW_OUTLET_T * 0.27 + SHADOW_OUTLET_PLUG;
    vec3 pq = abs(q / S - vec3(hs.x * 0.5, -0.005, z0 + 0.0175)) - vec3(0.026, 0.01, 0.0175) + 0.004;
    float plug = (length(max(pq, 0.)) + min(max(pq.x, max(pq.y, pq.z)), 0.) - 0.004) * S;
    vec3 p0 = vec3(hs.x * 0.5, -0.005, z0 + 0.035) * S;
    vec3 p3 = vec3(p0.x + SHADOW_CABLE_DROP.x, -gOutletPos.y + r, SHADOW_CABLE_DROP.y);
    vec3 df = vec3(gCableDir.x, 0., gCableDir.y);
    vec3 c1 = p0 + vec3(0., 0., 0.12);
    vec3 c2 = p3 - df * 0.18 + vec3(0., 0.02, 0.);
    float d = 1e9;
    vec3 prev = p0;
    for(int i = 1; i <= 10; i++){
        vec3 cur = bez3(p0, c1, c2, p3, float(i) / 10.);
        d = min(d, capsuleDist(q, prev, cur));
        prev = cur;
    }
    return min(plug, d - r);
}

float outletSdf(vec3 q, out float mat){
    float S = SHADOW_OUTLET_SCALE;
    vec3 qs = q / S;
    vec2 hs = SHADOW_OUTLET_SIZE * 0.5;
    float th = SHADOW_OUTLET_T;
    vec2 rq = abs(qs.xy) - hs + 0.035;
    float d2 = length(max(rq, 0.)) + min(max(rq.x, rq.y), 0.) - 0.035;
    vec2 w = vec2(d2 + 0.006, abs(qs.z - th * 0.5) - th * 0.5 + 0.006);
    float plate = min(max(w.x, w.y), 0.) + length(max(w, 0.)) - 0.006;
    float insert = 1e9, clips = 1e9;
    float ih = SHADOW_OUTLET_INSERT, ib = 0.007;
    for(int i = 0; i < 2; i++){
        vec2 c = vec2(i == 0 ? -hs.x * 0.5 : hs.x * 0.5, 0.);
        vec2 hq = abs(qs.xy - c) - (ih + SHADOW_OUTLET_GROOVE) + 0.02;
        float hole = length(max(hq, 0.)) + min(max(hq.x, hq.y), 0.) - 0.02;
        plate = max(plate, -max(hole, th * 0.15 - qs.z));
        vec2 iq = abs(qs.xy - c) - ih + 0.018;
        float i2 = length(max(iq, 0.)) + min(max(iq.x, iq.y), 0.) - 0.018;
        float itop = th + SHADOW_OUTLET_PROUD;
        vec2 iw = vec2(i2 + ib, abs(qs.z - itop * 0.5) - itop * 0.5 + ib);
        float ins = min(max(iw.x, iw.y), 0.) + length(max(iw, 0.)) - ib;
        float cyl = length(qs.xy - c) - SHADOW_OUTLET_SOCKET;
        ins = max(ins, -max(cyl, th * 0.27 - qs.z));
        insert = min(insert, ins);
        vec3 kq = vec3(qs.x - c.x, abs(qs.y) - SHADOW_OUTLET_SOCKET + 0.004, qs.z - th * 0.6);
        vec3 kb = abs(kq) - vec3(0.017, 0.006, th * 0.32) + 0.002;
        clips = min(clips, length(max(kb, 0.)) + min(max(kb.x, max(kb.y, kb.z)), 0.) - 0.002);
    }
    vec3 cq = abs(qs - vec3(hs.x * 0.5, 0., th * 0.27 + SHADOW_OUTLET_PLUG * 0.5)) - vec3(0.068, 0.068, SHADOW_OUTLET_PLUG * 0.5) + 0.018;
    float charger = length(max(cq, 0.)) + min(max(cq.x, max(cq.y, cq.z)), 0.) - 0.018;
    plate *= S;
    insert *= S;
    clips *= S;
    charger *= S;
    float cable = cableSdf(q);
    float d = min(min(min(plate, insert), charger), min(cable, clips));
    mat = d == cable ? 2. : d == charger ? 1. : d == clips ? 3. : d == insert ? 4. : 0.;
    return d;
}

vec3 outletLocal(vec3 p){
    return vec3(p.x - gOutletPos.x, p.y - gOutletPos.y, SHADOW_WALL_Z - p.z);
}

float outletMarch(vec3 ro, vec3 rd, float tmax, out float mat){
    vec3 lo = outletLocal(ro), ld = vec3(rd.x, rd.y, -rd.z);
    vec3 bmin = vec3(-SHADOW_OUTLET_SIZE.x * 0.5 * SHADOW_OUTLET_SCALE - 0.01, -gOutletPos.y - 0.01, -0.01);
    vec3 bmax = vec3(SHADOW_OUTLET_SIZE.x * 0.5 * SHADOW_OUTLET_SCALE + SHADOW_CABLE_DROP.x + 0.1, SHADOW_OUTLET_SIZE.y * 0.5 * SHADOW_OUTLET_SCALE + 0.01, max(SHADOW_CABLE_DROP.y, SHADOW_OUTLET_T + SHADOW_OUTLET_PLUG + 0.2) + 0.05);
    vec3 inv = 1. / (ld + vec3(1e-7));
    vec3 ta = (bmin - lo) * inv, tb = (bmax - lo) * inv;
    vec3 t0 = min(ta, tb), t1 = max(ta, tb);
    float tN = max(max(t0.x, t0.y), t0.z), tF = min(min(t1.x, t1.y), min(t1.z, tmax));
    if(tN > tF || tF < 0.) return -1.;
    float t = max(tN, 0.);
    for(int i = 0; i < 64; i++){
        float d = outletSdf(lo + ld * t, mat);
        if(d < 0.0002) return t;
        t += d;
        if(t > tF) break;
    }
    return -1.;
}

vec3 gCo, gCright, gCfwd, gLight, gAmpPos;
mat3 gAmpMi;

vec3 outletAlbedo(vec3 qw, int id, out float emit){
    vec3 q = qw / SHADOW_OUTLET_SCALE;
    vec2 hs = SHADOW_OUTLET_SIZE * 0.5;
    float floorZ = SHADOW_OUTLET_T * 0.27 + 0.002;
    float px = gPx / SHADOW_OUTLET_SCALE + 1e-5;
    emit = 0.;
    if(id == 17) return SHADOW_CABLE_COL;
    if(id == 18) return SHADOW_CLIP_COL;
    if(id == 16){
        vec2 c = vec2(hs.x * 0.5, -0.005);
        if(q.z < SHADOW_OUTLET_T * 0.27 + SHADOW_OUTLET_PLUG - 0.004) return SHADOW_OUTLET_COL * 0.95;
        vec2 d = abs(q.xy - c);
        float port = 1. - smoothstep(-px, px, max(d.x - 0.03, d.y - 0.011));
        float tongue = 1. - smoothstep(-px, px, max(d.x - 0.024, d.y - 0.004));
        emit = 1. - smoothstep(-px, px, length(q.xy - vec2(c.x, 0.044)) - 0.006);
        return mix(mix(SHADOW_OUTLET_COL * 0.95, vec3(0.02), port), SHADOW_OUTLET_ACCENT, tongue);
    }
    if(id == 15) return SHADOW_OUTLET_COL;
    vec3 col = SHADOW_OUTLET_COL * SHADOW_OUTLET_INSERT_TINT;
    vec2 c = vec2(-hs.x * 0.5, 0.);
    vec2 r = q.xy - c;
    if(q.z < floorZ && length(r) < SHADOW_OUTLET_SOCKET){
        col *= 0.7;
        float holes = min(length(r - vec2(0.046, 0.)), length(r + vec2(0.046, 0.))) - 0.011;
        col = mix(col, vec3(0.03), 1. - smoothstep(-px, px, holes));
    }
    return col;
}

vec2 catmull(vec2 a, vec2 b, vec2 c, vec2 d, float t){
    return 0.5 * (2. * b + (c - a) * t + (2. * a - 5. * b + 4. * c - d) * t * t + (3. * b - a - 3. * c + d) * t * t * t);
}

vec3 cableFloor(vec2 p){
    float best = 1e9;
    vec2 perp = vec2(0.);
    for(int s = 0; s < 4; s++){
        vec2 a = s == 0 ? 2. * gPath[0] - gPath[1] : gPath[s - 1];
        vec2 b = gPath[s], c = gPath[s + 1];
        vec2 d = s == 3 ? 2. * gPath[4] - gPath[3] : gPath[s + 2];
        vec2 prev = b;
        for(int i = 1; i <= 6; i++){
            vec2 cur = catmull(a, b, c, d, float(i) / 6.);
            vec2 pa = p - prev, ba = cur - prev;
            vec2 h = pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0., 1.);
            float l = length(h);
            if(l < best){ best = l; perp = h / max(l, 1e-6); }
            prev = cur;
        }
    }
    return vec3(best, perp);
}

vec3 phoneLocal(vec3 p){
    vec2 d = p.xz - gPhoneC.xz;
    return vec3(dot(d, gPhoneR), p.y - SHADOW_PHONE_SIZE.z * 0.5, dot(d, gPhoneU));
}

float phoneSdfM(vec3 q, out float mat){
    vec3 b = vec3(SHADOW_PHONE_SIZE.x, SHADOW_PHONE_SIZE.z, SHADOW_PHONE_SIZE.y) * 0.5;
    vec2 rq = abs(q.xz) - b.xz + 0.04;
    float d2 = length(max(rq, 0.)) + min(max(rq.x, rq.y), 0.) - 0.04;
    vec2 w = vec2(d2 + 0.008, abs(q.y) - b.y + 0.008);
    float body = min(max(w.x, w.y), 0.) + length(max(w, 0.)) - 0.008;
    float r = SHADOW_CABLE_R;
    vec3 pq = abs(q - vec3(0., 0., -b.z - 0.018)) - vec3(0.016, 0.007, 0.02) + 0.003;
    float plug = length(max(pq, 0.)) + min(max(pq.x, max(pq.y, pq.z)), 0.) - 0.003;
    vec3 a0 = vec3(0., 0., -b.z - 0.036), a1 = vec3(0., -b.y + r, -b.z - SHADOW_CABLE_LEAD * 0.6);
    vec3 h = a0 + vec3(0., 0., -0.03);
    float stub = min(capsuleDist(q, a0, h), capsuleDist(q, h, a1)) - r;
    float acc = min(plug, stub);
    mat = acc < body ? 1. : 0.;
    return min(body, acc);
}

float phoneSdf(vec3 q){
    float m;
    return phoneSdfM(q, m);
}

bool phoneBox(vec3 ro, vec3 rd){
    vec3 lo = phoneLocal(ro);
    vec3 ld = vec3(dot(rd.xz, gPhoneR), rd.y, dot(rd.xz, gPhoneU));
    vec3 hb = vec3(SHADOW_PHONE_SIZE.x, SHADOW_PHONE_SIZE.z, SHADOW_PHONE_SIZE.y) * 0.5 + 0.02;
    vec3 inv = 1. / (ld + vec3(1e-7));
    vec3 lb = -hb - vec3(0., 0., SHADOW_CABLE_LEAD * 0.6 + 0.05);
    vec3 ta = (lb - lo) * inv, tb = (hb - lo) * inv;
    vec3 t0 = min(ta, tb), t1 = max(ta, tb);
    return max(max(t0.x, t0.y), t0.z) < min(min(t1.x, t1.y), t1.z);
}

float phoneMarch(vec3 ro, vec3 rd, float tmax){
    vec3 lo = phoneLocal(ro);
    vec3 ld = vec3(dot(rd.xz, gPhoneR), rd.y, dot(rd.xz, gPhoneU));
    vec3 hb = vec3(SHADOW_PHONE_SIZE.x, SHADOW_PHONE_SIZE.z, SHADOW_PHONE_SIZE.y) * 0.5 + 0.01;
    vec3 inv = 1. / (ld + vec3(1e-7));
    vec3 lb = -hb - vec3(0., 0., SHADOW_CABLE_LEAD * 0.6 + 0.05);
    vec3 ta = (lb - lo) * inv, tb = (hb - lo) * inv;
    vec3 t0 = min(ta, tb), t1 = max(ta, tb);
    float tN = max(max(t0.x, t0.y), t0.z), tF = min(min(t1.x, t1.y), min(t1.z, tmax));
    if(tN > tF || tF < 0.) return -1.;
    float t = max(tN, 0.);
    for(int i = 0; i < 40; i++){
        float d = phoneSdf(lo + ld * t);
        if(d < 0.0002) return t;
        t += d;
        if(t > tF) break;
    }
    return -1.;
}

float segDist(vec2 p, vec2 a, vec2 b){
    vec2 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0., 1.));
}

float digitDist(vec2 p, int n){
    int masks[10] = int[10](0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F);
    int m = masks[clamp(n, 0, 9)];
    float w = 0.5, h = 1.;
    vec2 A[7] = vec2[7](vec2(-w, h), vec2(w, h), vec2(w, 0.), vec2(-w, -h), vec2(-w, 0.), vec2(-w, h), vec2(-w, 0.));
    vec2 B[7] = vec2[7](vec2(w, h), vec2(w, 0.), vec2(w, -h), vec2(w, -h), vec2(-w, -h), vec2(-w, 0.), vec2(w, 0.));
    float d = 1e9;
    for(int s = 0; s < 7; s++)
        if(((m >> s) & 1) == 1) d = min(d, segDist(p, A[s], B[s]));
    return d - 0.13;
}

vec3 phoneScreen(vec2 s){
    float px = gPx + 1e-5;
    vec3 col = vec3(0.);
    vec4 c = iClock;
    float ch = SHADOW_PHONE_DIGIT;
    vec2 tp = (vec2(-s.y, s.x) - vec2(0., SHADOW_PHONE_TIME_Y)) / ch;
    float d = min(min(digitDist(tp - vec2(-3.3, 0.), int(c.x)), digitDist(tp - vec2(-1.3, 0.), int(c.y))),
                  min(digitDist(tp - vec2(1.3, 0.), int(c.z)), digitDist(tp - vec2(3.3, 0.), int(c.w))));
    d = min(d, min(length(tp - vec2(0., 0.45)), length(tp - vec2(0., -0.45))) - 0.15);
    return mix(col, GRAD_TOP, 1. - smoothstep(-px, px, d * ch));
}

float sceneTrace(vec3 ro, vec3 rd, out int id, out vec3 n, out vec3 clp, out vec3 cln){
    float t = 1e9;
    id = -1;
    n = vec3(0., 1., 0.);
    clp = vec3(0.);
    cln = vec3(0., 1., 0.);
    if(rd.y < 0.){ t = -ro.y / rd.y; id = 0; }
    if(rd.z > 0.){
        float tt = (SHADOW_WALL_Z - ro.z) / rd.z;
        if(tt < t){ t = tt; id = 1; n = vec3(0., 0., -1.); }
    }
    if(rd.x < 0.){
        float tt = (SHADOW_SIDE_X - ro.x) / rd.x;
        if(tt < t){ t = tt; id = 22; n = vec3(1., 0., 0.); }
    }
    {
        float ys = SHADOW_SKIRT_H * 1.05;
        float ts = ro.y <= ys ? 0. : (rd.y < 0. ? (ys - ro.y) / rd.y : 1e9);
        if(ts < t){
            for(int i = 0; i < 64; i++){
                float ds = skirtUnion(ro + rd * ts);
                if(ds < 0.0002){
                    t = ts; id = 2;
                    vec3 sp = ro + rd * ts;
                    vec2 e = vec2(0.0005, 0.);
                    n = normalize(vec3(skirtUnion(sp + e.xyy) - skirtUnion(sp - e.xyy),
                                       skirtUnion(sp + e.yxy) - skirtUnion(sp - e.yxy),
                                       skirtUnion(sp + e.yyx) - skirtUnion(sp - e.yyx)));
                    break;
                }
                ts += ds * 0.9;
                if(ts > t) break;
            }
        }
    }
    {
        float m;
        float to = outletMarch(ro, rd, t, m);
        if(to > 0. && to < t){
            t = to;
            id = m > 3.5 ? 19 : m > 2.5 ? 18 : m > 1.5 ? 17 : m > 0.5 ? 16 : 15;
            vec3 lp = outletLocal(ro + rd * to);
            clp = lp;
            vec2 e = vec2(0.0005, 0.);
            vec3 g = vec3(outletSdf(lp + e.xyy, m) - outletSdf(lp - e.xyy, m),
                          outletSdf(lp + e.yxy, m) - outletSdf(lp - e.yxy, m),
                          outletSdf(lp + e.yyx, m) - outletSdf(lp - e.yyx, m));
            n = normalize(vec3(g.x, g.y, -g.z));
        }
    }
    {
        float tp = phoneMarch(ro, rd, t);
        if(tp > 0. && tp < t){
            t = tp;
            vec3 lp = phoneLocal(ro + rd * tp);
            clp = lp;
            vec2 e = vec2(0.0005, 0.);
            vec3 g = vec3(phoneSdf(lp + e.xyy) - phoneSdf(lp - e.xyy), phoneSdf(lp + e.yxy) - phoneSdf(lp - e.yxy), phoneSdf(lp + e.yyx) - phoneSdf(lp - e.yyx));
            g = normalize(g);
            n = vec3(g.x * gPhoneR.x + g.z * gPhoneU.x, g.y, g.x * gPhoneR.y + g.z * gPhoneU.y);
            float pm;
            phoneSdfM(lp, pm);
            id = pm > 0.5 ? 17 : g.y > 0.9 ? 21 : 20;
        }
    }
    {
        vec3 lro = vec3(dot(ro - gCo, gCright), ro.y, dot(ro - gCo, gCfwd));
        vec3 lrd = vec3(dot(rd, gCright), rd.y, dot(rd, gCfwd));
        float tc = 0., foot;
        for(int i = 0; i < 80; i++){
            float d = couchSdf(lro + lrd * tc, foot);
            if(d < 0.0005 * (1. + tc)){
                if(tc < t){
                    t = tc;
                    id = foot > 1.5 ? 7 : foot > 0.5 ? 6 : 5;
                    vec2 e = vec2(0.002, 0.);
                    vec3 lp = lro + lrd * tc;
                    clp = lp;
                    vec3 ln = normalize(vec3(couchSdf(lp + e.xyy, foot) - couchSdf(lp - e.xyy, foot),
                                             couchSdf(lp + e.yxy, foot) - couchSdf(lp - e.yxy, foot),
                                             couchSdf(lp + e.yyx, foot) - couchSdf(lp - e.yyx, foot)));
                    n = ln.x * gCright + vec3(0., ln.y, 0.) + ln.z * gCfwd;
                    cln = ln;
                }
                break;
            }
            tc += d;
            if(tc > t) break;
        }
    }
    return t;
}

float raufaser(vec2 w){
    vec2 u = w / (SHADOW_WALL_GRAIN * 512.);
    float h = texture(iChannel1, fract(u)).r * 0.6 + texture(iChannel1, fract(u * 2.3 + 0.37)).r * 0.4;
    return h * h;
}

vec3 shadeScene(vec3 ro, vec3 rd, float t, int id, vec3 n, vec3 clp, vec3 cln, vec3 grain){
    if(id < 0) return grain;
    vec3 p = ro + rd * t;
    gPx = t / (SHADOW_FOCAL * iResolution.y) / sqrt(max(abs(dot(n, rd)), 0.3));
    if(id == 21) return phoneScreen(clp.xz) * SHADOW_PHONE_BRIGHT + grain;
    vec3 cf = id == 0 ? cableFloor(p.xz) : vec3(1e9, 0., 0.);
    bool onCable = cf.x < SHADOW_CABLE_R;
    if(onCable){
        float a = cf.x / SHADOW_CABLE_R;
        n = normalize(vec3(cf.y * a, sqrt(max(1. - a * a, 0.)), cf.z * a));
    }
    float rauh = 0.5;
    if(id == 1 || id == 22){
        vec2 wv = id == 1 ? p.xy : p.zy;
        vec3 T = id == 1 ? vec3(1., 0., 0.) : vec3(0., 0., 1.);
        float e = SHADOW_WALL_GRAIN;
        rauh = raufaser(wv);
        vec2 g = vec2(raufaser(wv + vec2(e, 0.)) - rauh, raufaser(wv + vec2(0., e)) - rauh) / e;
        float fade = 1. - smoothstep(1., 4., gPx / SHADOW_WALL_GRAIN);
        n = normalize(n - (g.x * T + g.y * vec3(0., 1., 0.)) * SHADOW_WALL_BUMP * SHADOW_WALL_GRAIN * fade);
    }
    vec3 tl = gLight - p;
    float dist = length(tl);
    vec3 ld = tl / dist;
    float dif = max(dot(n, ld), 0.) / (1. + pow(dist / SHADOW_LIGHT_RANGE, 2.));

    float sh = 1.;
    if(dif > 0.){
        gFarPad = 0.;
        sh = solidShadow(gAmpMi * (p + n * 0.002 - gAmpPos), gAmpMi * ld, dist);
        gFarPad = SDF_RANGE;
    }
    if(dif > 0. && sh > 0.){
        float m;
        if(outletMarch(p + n * 0.002, ld, dist, m) > 0.) sh = 0.;
    }
    if(dif > 0. && sh > 0. && id < 5){
        vec3 sp = p + n * 0.004 - gCo;
        sh = min(sh, couchShadow(vec3(dot(sp, gCright), sp.y, dot(sp, gCfwd)),
                                 vec3(dot(ld, gCright), ld.y, dot(ld, gCfwd)), dist));
    }

    float ao = 1.;
    if(id == 0){
        ao = mix(SHADOW_CORNER, 1., smoothstep(0., 0.6, SHADOW_WALL_Z - SHADOW_SKIRT_D - p.z))
           * mix(SHADOW_CORNER, 1., smoothstep(0., 0.6, p.x - SHADOW_SIDE_X - SHADOW_SKIRT_D));
        vec3 fl = p - gCo;
        vec2 fxz = vec2(dot(fl, gCright), dot(fl, gCfwd));
        for(int i = 0; i < 4; i++)
            ao *= mix(0.3, 1., smoothstep(SHADOW_LEG_TOE * 0.6, SHADOW_LEG_TOE * 3.5, length(fxz - couchFoot(i).xz)));
        vec2 fb = abs(fxz - vec2(-SHADOW_COUCH_W * 0.5, SHADOW_COUCH_L * 0.5)) - vec2(SHADOW_COUCH_W, SHADOW_COUCH_L) * 0.5;
        float fd = length(max(fb, 0.)) + min(max(fb.x, fb.y), 0.);
        ao *= mix(SHADOW_COUCH_UNDER, 1., smoothstep(-0.1, SHADOW_COUCH_SPREAD, fd));
        if(!onCable) ao *= mix(0.45, 1., smoothstep(SHADOW_CABLE_R, SHADOW_CABLE_R * 3., cf.x));
    }
    if(id == 1) ao = mix(SHADOW_CORNER, 1., smoothstep(0., 0.125, p.y - SHADOW_SKIRT_H)) * mix(SHADOW_CORNER, 1., smoothstep(0., 0.4, p.x - SHADOW_SIDE_X));
    if(id == 22) ao = mix(SHADOW_CORNER, 1., smoothstep(0., 0.125, p.y - SHADOW_SKIRT_H)) * mix(SHADOW_CORNER, 1., smoothstep(0., 0.4, SHADOW_WALL_Z - p.z));
    if(id == 2){
        ao = mix(SHADOW_CORNER, 1., smoothstep(0., 0.03, p.y));
        float gy = SHADOW_SKIRT_H - SHADOW_SKIRT_D * SHADOW_SKIRT_BEAD * 2.6;
        float gw = SHADOW_SKIRT_D * 0.12 + gPx;
        ao *= 1. - 0.55 * (1. - smoothstep(0., gw, abs(p.y - gy)));
    }
    float emit = 0.;
    vec3 albedo = id == 0 ? (onCable ? SHADOW_CABLE_COL : SHADOW_FLOOR * floorBoards(p.xz))
                : id == 20 ? SHADOW_PHONE_COL
                : (id == 1 || id == 22) ? SHADOW_WALL * mix(1. - SHADOW_WALL_TONE, 1. + SHADOW_WALL_TONE, rauh)
                : id == 5 ? SHADOW_COUCH * felt(clp, cln) + SHADOW_FELT_SHEEN * pow(1. - max(dot(n, -rd), 0.), 4.)
                : id == 6 ? SHADOW_WOOD * mix(0.75, 1.25, texture(iChannel1, fract(vec2((clp.x + clp.z) * 1.7, clp.y * 0.08))).r)
                : id == 7 ? SHADOW_BRASS
                : id >= 15 ? outletAlbedo(clp, id, emit) : SHADOW_SKIRT;
    float gain = SHADOW_GAIN * (id == 0 ? SHADOW_FLOOR_GAIN : 1.);
    float amb = (id >= 5 && id <= 7) ? SHADOW_COUCH_AMB : SHADOW_AMB;
    float sp = pow(max(dot(reflect(-ld, n), -rd), 0.), id == 7 ? 60. : 24.);
    vec3 spec = id == 6 ? vec3(SHADOW_WOOD_SHEEN) * sp
              : id == 7 ? vec3(SHADOW_BRASS_SHINE) * sp
              : id == 18 ? vec3(SHADOW_CLIP_SHINE) * pow(max(dot(reflect(-ld, n), -rd), 0.), 70.)
              : id == 20 ? vec3(0.)
              : (id >= 15 || onCable) ? vec3(SHADOW_OUTLET_GLOSS) * pow(max(dot(reflect(-ld, n), -rd), 0.), 32.) : vec3(0.);
    vec2 pd = abs(vec2(dot(p.xz - gPhoneC.xz, gPhoneR), dot(p.xz - gPhoneC.xz, gPhoneU))) - SHADOW_PHONE_SIZE.xy * 0.5;
    float glow = id == 0 ? exp(-length(max(pd, 0.)) * 12.) * SHADOW_PHONE_GLOW : 0.;
    return albedo * (amb + gain * dif * sh) * ao + spec * sh * float(dif > 0.) + SHADOW_OUTLET_ACCENT * 3. * emit + GRAD_TOP * glow + grain;
}

vec2 floorAt(vec3 ro, vec3 f, vec3 r, vec3 u, mat3 yaw, vec2 frac){
    vec2 q = vec2((frac.x - 0.5) * iResolution.x / iResolution.y, 0.5 - frac.y);
    vec3 rd = yaw * normalize(f * SHADOW_FOCAL + r * q.x + u * q.y);
    return (ro + rd * (-ro.y / min(rd.y, -1e-3))).xz;
}

vec3 shadowPlayRaw(vec2 q, vec2 tp){
    vec3 ro = SHADOW_CAM;
    vec3 f = normalize(SHADOW_TARGET - ro);
    vec3 r = normalize(cross(vec3(0., 1., 0.), f));
    vec3 u = cross(f, r);
    vec3 rd = normalize(f * SHADOW_FOCAL + r * q.x + u * q.y);
    mat3 yaw = mat3(cos(SHADOW_YAW), 0., -sin(SHADOW_YAW), 0., 1., 0., sin(SHADOW_YAW), 0., cos(SHADOW_YAW));
    vec3 pivot = vec3(0., 0., SHADOW_WALL_Z);
    ro = pivot + yaw * (ro - pivot);
    rd = yaw * rd;

    gCfwd = normalize(yaw * vec3(f.x, 0., f.z));
    gCright = vec3(gCfwd.z, 0., -gCfwd.x);
    gCo = vec3(ro.x, 0., ro.z) + gCfwd * SHADOW_COUCH_FWD - gCright * SHADOW_COUCH_LEFT;
    mat3 rig = mat3(cos(SHADOW_RIG_YAW), 0., -sin(SHADOW_RIG_YAW), 0., 1., 0., sin(SHADOW_RIG_YAW), 0., cos(SHADOW_RIG_YAW));
    vec3 rp = vec3(ro.x, 0., ro.z);
    gLight = rp + rig * (SHADOW_LIGHT - rp);
    gAmpPos = rp + rig * (SHADOW_AMP_POS - rp);
    float a = SHADOW_FACE + SHADOW_RIG_YAW + SHADOW_SWAY * sin(iTime * SHADOW_SWAY_RATE);
    gAmpMi = transpose(mat3(cos(a), 0., -sin(a), 0., 1., 0., sin(a), 0., cos(a)));
    {
        float qx = (SHADOW_OUTLET_SCREEN_X - 0.5) * iResolution.x / iResolution.y;
        float qy = 0.;
        vec3 hit;
        for(int i = 0; i < 4; i++){
            vec3 d0 = yaw * (f * SHADOW_FOCAL + r * qx + u * qy);
            vec3 d1 = yaw * (f * SHADOW_FOCAL + r * qx + u * (qy + 0.01));
            vec3 h0 = ro + d0 * (SHADOW_WALL_Z - ro.z) / d0.z;
            vec3 h1 = ro + d1 * (SHADOW_WALL_Z - ro.z) / d1.z;
            qy += (SHADOW_OUTLET_Y - h0.y) * 0.01 / (h1.y - h0.y);
            hit = h0;
        }
        gOutletPos = vec2(hit.x, SHADOW_OUTLET_Y);
        gOutletQ = vec2(qx, qy);
    }
    {
        vec2 cfw = normalize((yaw * vec3(f.x, 0., f.z)).xz), crt = vec2(cfw.y, -cfw.x);
        vec2 c = floorAt(ro, f, r, u, yaw, SHADOW_PHONE_SCREEN);
        gPhoneC = vec3(c.x, SHADOW_PHONE_SIZE.z * 0.5, c.y);
        float pa = SHADOW_PHONE_YAW;
        gPhoneU = vec2(cos(pa) * cfw.x - sin(pa) * cfw.y, sin(pa) * cfw.x + cos(pa) * cfw.y);
        gPhoneR = vec2(gPhoneU.y, -gPhoneU.x);
        float lx = SHADOW_OUTLET_SIZE.x * 0.25 * SHADOW_OUTLET_SCALE + SHADOW_CABLE_DROP.x;
        gPath[0] = vec2(gOutletPos.x + lx, SHADOW_WALL_Z - SHADOW_CABLE_DROP.y);
        gPath[4] = c - gPhoneU * SHADOW_PHONE_SIZE.y * 0.5;
        gPath[3] = gPath[4] - gPhoneU * SHADOW_CABLE_LEAD;
        gPath[1] = floorAt(ro, f, r, u, yaw, SHADOW_CABLE_OUT1);
        gPath[2] = floorAt(ro, f, r, u, yaw, SHADOW_CABLE_OUT2);
        vec2 dw = normalize(gPath[1] - gPath[0]);
        gCableDir = vec2(dw.x, -dw.y);
    }

    vec3 grain = vec3(mix(NOISE_LO, NOISE_HI, texture(iChannel1, fract(tp)).r));
    int id;
    vec3 n, clp, cln;
    vec2 dq = q - gOutletQ;
    bool ss = abs(dq.x) < SHADOW_OUTLET_SS.x && dq.y > -SHADOW_OUTLET_SS.y && dq.y < SHADOW_OUTLET_SS.z;
    if(rd.z > 0.){
        float yw = ro.y + rd.y * (SHADOW_WALL_Z - ro.z) / rd.z;
        ss = ss || (yw > -SHADOW_SKIRT_SS.x && yw < SHADOW_SKIRT_H + SHADOW_SKIRT_SS.y);
    }
    ss = ss || phoneBox(ro, rd);
    if(!ss){
        float t = sceneTrace(ro, rd, id, n, clp, cln);
        return shadeScene(ro, rd, t, id, n, clp, cln, grain);
    }
    vec3 col = vec3(0.);
    float px = 1. / iResolution.y;
    for(int i = 0; i < 2; i++)
        for(int j = 0; j < 2; j++){
            vec2 qq = q + (vec2(i, j) - 0.5) * 0.5 * px;
            vec3 rs = yaw * normalize(f * SHADOW_FOCAL + r * qq.x + u * qq.y);
            float t = sceneTrace(ro, rs, id, n, clp, cln);
            col += shadeScene(ro, rs, t, id, n, clp, cln, grain);
        }
    return col * 0.25;
}

uint pcg(uint v){
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

float pcgHash(uvec3 v){
    return float(pcg(v.x + pcg(v.y + pcg(v.z)))) / 4294967295.;
}

vec3 shadowPlay(vec2 q, vec2 tp){
    vec3 col = shadowPlayRaw(q, tp);
    uvec2 px = uvec2(ivec2(floor(gl_FragCoord.xy)));
    uint fr = uint(iTime * SHADOW_FILM_FPS);
    float g = pcgHash(uvec3(px, fr)) + pcgHash(uvec3(px, fr + 7919u)) - 1.;
    float l = dot(col, vec3(0.299, 0.587, 0.114));
    return max(col + g * SHADOW_FILM_GRAIN * (0.3 + 0.7 * 4. * l * (1. - l)), 0.);
}

// --- key indicator -----------------------------------------------------------
vec3 keyIndicator(vec3 col, vec2 q){
    // the circle leads the amp by IND_LAG both ways: max of the live and the
    // delayed envelope rises first and falls last, min does the opposite
    float e0 = sk_attention_envelope();
    float e1 = sk_attention_envelope_at(iTime - IND_LAG);
    float cpres = max(e0, e1);
    float pres = min(e0, e1);
    if(cpres < 0.001) return col;

    // black circle growing from the center to past the corners
    float maxR = length(iResolution.xy) / iResolution.y * 0.51;
    col = mix(col, vec3(0.), S(length(q) - maxR * cubicInOut(cpres)));

    // the amp zooms in behind the circle; each key bumps size and brightness
    float pulse = sk_keypulse_envelope();
    float fail = sk_fail_envelope();
    float sc = IND_AMP * cubicInOut(pres) * (1. + pulse * IND_BUMP);
    if(sc < 1e-3) return col;
    vec2 ap = q / sc;
    float dj = sdJ(ap);
    float dp = max(sdP(ap), PAD - dj);
    vec3 ac = mix(ampGradient(ap), vec3(1.), pulse * IND_BRIGHT);
    ac = mix(ac, sk_fail_color, fail);
    return mix(col, ac, S(min(dj, dp) * sc));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    gSeed = 100. * vec2(sk_seed(0), sk_seed(1));
    vec2 p = (fragCoord-0.5*iResolution.xy)/iResolution.y;
    vec2 q = p;
    sequenceModes(q);
    gCoast = COASTF_AMT * P.terra;

    // global zoom-out (offset half a period) plus the wham zoom, centered
    // on a target orbiting off-screen so each zoom lands somewhere new
    float zo = flipflop(iTime + ZOOM_PERIOD*0.5, ZOOM_PERIOD);
    float ang = 6.2831853 * iTime / ZOOM_DRIFT;
    vec2 zc = ZOOM_ECC * vec2(cos(ang), sin(ang));
    gZoom = (1. + ZOOM_OUT*zo) * (1. + P.wham);
    p *= 1. + P.wham;                        // wham zooms about the screen center
    p = zc + (p - zc) * (1. + ZOOM_OUT*zo);  // cyclical zoom about its drifting target

    // sun direction, drifting slowly around the top
    float sa = 6.2831853 * iTime / SUN_PERIOD;
    SUN = normalize(vec3(sin(sa)*SUN_SWING, SUN_HEIGHT, SUN_Z));

    // noise coords, counter-scrolling slowly against the grid
    vec2 tp = vec2(p.x, p.y + iTime*SCROLL*BG_SPEED) * NOISE_SCALE;

    vec3 col = vec3(0.);
    if(P.field + P.drop + P.solid + P.halftone + P.shadow < 0.999) col = render(p, tp);
    if(P.field > 0.001) col = mix(col, field(p, q, tp), P.field);
    if(P.drop > 0.001) col = mix(col, drop(q, tp), P.drop);
    if(P.solid > 0.001) col = mix(col, solid(q, tp), P.solid);
    if(P.halftone > 0.001) col = mix(col, halftone(q, tp), P.halftone);
    if(P.shadow > 0.001) col = mix(col, shadowPlay(q, tp), P.shadow);
    gCoast = 0.;   // the key indicator keeps clean brand glyphs
    fragColor = vec4(keyIndicator(col, q), 1.0);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
