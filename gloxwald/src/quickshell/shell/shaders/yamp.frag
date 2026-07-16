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

// mode transitions ease over TRANS_DUR; the global zoom flips on ZOOM_PERIOD,
// offset by half — tuned so with the default two-mode playlist the four
// quarters run 2d-in, 2d-out, 3d-out, 3d-in
const float TRANS_DUR   = 1.2;   // mode/zoom flip transition duration
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
// wipe becomes a pulse with a gradient tail — transparent toward the seed,
// solid at the wavefront. normal = black bg, amps printed in the color,
// pulsing to black; inverted = color bg, black amps, pulsing to
// color*WARHOL_FILL. colors are oklch-matched to the andamp blue (same
// lightness/chroma, rotated hue)
const vec3 WARHOL_COLS[4] = vec3[4](
    vec3(0.138, 0.633, 0.717),   // andamp blue
    vec3(0.768, 0.456, 0.581),   // pink
    vec3(0.482, 0.619, 0.336),   // lime
    vec3(0.764, 0.495, 0.304));  // orange
const float WARHOL_INV  = 0.5;   // chance a square is inverted
const float WARHOL_FILL = 1.2;   // pulse brightness x the base color (inverted)
const float PULSE_W     = 0.35;  // pulse gradient tail width (glyph units)

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

// --- modes -------------------------------------------------------------------
// a mode is one ModeParams entry in the playlist below; the sequencer
// (20_modes) walks it, easing between neighbours over TRANS_DUR
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
};

// each step grows the pad and zooms in (wham) — visual complexity goes up,
// so fewer but bigger planets. the event horizon dies out within the pad,
// so cells of different levels stay continuous
const int MODE_COUNT = 5;
const ModeParams MODES[MODE_COUNT] = ModeParams[MODE_COUNT](
    //         pad   bg  light dark  ring distort wham   spec cloud aur  warm terra neb  star squir warhol big
    // 2d base: flat — border ring, no noise/stars/shade/distortion
    ModeParams(0.01, 0., 0.,   0.,   1.,  0.,     0.,    0.,  0.,   0.,  0.,  0.,   0.,  0.,   0.,  0.,  0.15),
    // 3d mono: sparse starfield, white horizon (the old aurora), white sun
    ModeParams(0.25, 1., 0.25, 0.75, 0.,  0.12,   -0.3,  0.6, 0.,   0.,  0.,  0.,   0.,  0.25, 0.,  0.,  0.15),
    // 3d full: colored aurora, warm sun, clouds, ocean + terrain, nebula
    ModeParams(0.45, 1., 0.25, 0.75, 0.,  0.12,   -0.65, 0.6, 1.,   1.,  1.,  1.,   1.,  3.,   0.,  0.,  0.15),
    // back to base before the pop hits
    ModeParams(0.01, 0., 0.,   0.,   1.,  0.,     0.,    0.,  0.,   0.,  0.,  0.,   0.,  0.,   0.,  0.,  0.15),
    // warhol: flat pop-color squares, normal/inverted per tile, more bigs
    ModeParams(0.,   0., 0.,   0.,   0.,  0.,     0.,    0.,  0.,   0.,  0.,  0.,   0.,  0.,   1.,  1.,  0.85)
);

const float D = 480.;
const float MODE_DUR[MODE_COUNT] = float[MODE_COUNT](D, D, D, D, D);

// two super-modes, each opening on the circles base block: the planets arc
// is blocks 0-2 (circles -> 3d balls -> planets), the warhol arc blocks 3-4
// (circles -> squares); sk_seed(2) decides which arc a session opens on
const int   WARHOL_START = 3;    // playlist index of the warhol arc's circles block
const float WARHOL_FIRST = 0.5;  // chance a session opens on the warhol arc

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
// sequencer walks the playlist and eases the global P between neighbours
// over TRANS_DUR at each boundary — so any mode expressible as parameters
// transitions for free. Structural modes (different traversal/tile content)
// branch on modeFrom/modeTo/modeBlend instead; keep those branches rare.

ModeParams P;          // active params, filled per frame by sequenceModes()
int   modeFrom  = 0;   // structural hooks branch on these
int   modeTo    = 0;
float modeBlend = 1.;  // eased from->to progress, 1 once settled
float modeTime  = 0.;  // seconds into the current playlist block

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
        mix(a.big, b.big, t));
}

void sequenceModes(){
    // super-mode order: sk_seed(2) may open the session on the warhol arc
    // by skipping the clock past the planets arc, onto its circles block
    float skip = 0.;
    if(sk_seed(2) < WARHOL_FIRST)
        for(int i = 0; i < WARHOL_START; i++) skip += MODE_DUR[i];
    float t = iTime + skip;
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
            modeBlend = smoothstep(0., TRANS_DUR, modeTime);
            break;
        }
        acc += d;
    }
    // very first block (already active at iTime 0, wherever the skip landed
    // it): no flip-in from the notional previous mode
    if(iTime <= modeTime + 0.001) modeFrom = modeTo;
    P = mixParams(MODES[modeFrom], MODES[modeTo], modeBlend);

    // clouds don't blend through transitions — the pad/zoom retune makes
    // them slide. instead they fade in for TRANS_DUR after the transition
    // lands, and fade out over the last TRANS_DUR before the next one
    float d = MODE_DUR[modeTo];
    P.cloud = MODES[modeTo].cloud
            * smoothstep(TRANS_DUR, 2.*TRANS_DUR, modeTime)
            * (1. - smoothstep(d - TRANS_DUR, d, modeTime));
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

// the early-out branches return far + SDF_RANGE — clear of every coast
// band, so the switch never re-enters shelf/relief range (it used to sit
// at ~0.05, painting a phantom circular coastline around each amp). the
// max() keeps the field growing past the texture's clamp plateau
float sdJ(vec2 p) {
    float far = length(p) - 0.57;   // J fits in radius 0.554
    if (far > 0.05) return far + SDF_RANGE;
    vec2 uv = vec2(p.x, -p.y)/(2.0*SDF_BOX) + 0.5;
    vec4 t = texture(iChannel0, uv);
    return max((t.r - 0.5) * SDF_RANGE + (t.b - 0.5) * gCoast, far);
}
float sdP(vec2 p) {
    float far = length(p) - 0.66;   // P fits in radius 0.646
    if (far > 0.09) return far + SDF_RANGE;
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

// wipe progress for the warhol pulse: parked negative before the wipe (the
// annulus is imaginary), eased across, then parked past the glyph — so the
// on/unfill phases read as settled black with no retiming
float pulseWipe(float frame, float start){
    if(frame < start) return -1.;
    return cubicInOut(min((frame - start)/T_FILL, 1.));
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
    // warhol — the pulse below takes over
    vec3 fillCol = mix(ampGradient(p),
                       mix(HIGH_BOT, HIGH_TOP, smoothstep(0., -SNOW_D, dw))
                       * mix(1., dmod, SNOW_DETAIL),
                       P.terra);
    col = mix(col, fillCol, S(dw) * rim * (1. - P.warhol));

    // warhol: the fill wipe becomes a pulse with a gradient tail —
    // transparent toward the seed, solid at the wavefront — sweeping across
    // the glyph and out past its rim, so the on/unfill phases read as
    // settled. inverted tiles pulse brightened color over black amps;
    // normal tiles pulse black over the printed color
    if(P.warhol > 0.001){
        float rj = pulseWipe(frame, FILLJ_START) * (RJ + 1.5*PULSE_W);
        float rp = pulseWipe(frame, FILLP_START) * (RP + 1.5*PULSE_W);
        float lj = length(pJ - SEED_J), lp = length(pP - SEED_P);
        float aj = S(max(sq.x, max(dj, lj - rj) * ampScale))
                 * smoothstep(rj - PULSE_W, rj, lj);
        float ap = S(max(sq.x, max(dp, lp - rp) * ampScale))
                 * smoothstep(rp - PULSE_W, rp, lp);
        col = mix(col, mix(vec3(0.), gPop * WARHOL_FILL * tshade, gInv),
                  max(aj, ap) * rim * P.warhol);
    }

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
    sequenceModes();
    gCoast = COASTF_AMT * P.terra;

    vec2 p = (fragCoord-0.5*iResolution.xy)/iResolution.y;
    vec2 q = p;

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

    vec3 col = render(p, tp);
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
