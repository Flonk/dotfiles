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
    vec2 u_prism_beam;
    vec4 u_prism_ray;
    float u_prism_chunk;

    vec3 iResolution;
    vec3 u_indicator_color;

    vec4 iMouse;
    vec4 iClock;

    // 32 random floats in [0,1), rerolled by the host each time the shader
    // pass is created — read them via sk_seed(i) to vary scenes per session
    mat4 iSeed0;
    mat4 iSeed1;
};

// Up to ten input textures, resolved from QML properties.
layout(binding = 1) uniform sampler2D iChannel0;
layout(binding = 2) uniform sampler2D iChannel1;
layout(binding = 3) uniform sampler2D iChannel2;
layout(binding = 4) uniform sampler2D iChannel3;
layout(binding = 5) uniform sampler2D iChannel4;
layout(binding = 6) uniform sampler2D iChannel5;
layout(binding = 7) uniform sampler2D iChannel6;
layout(binding = 8) uniform sampler2D iChannel7;
layout(binding = 9) uniform sampler2D iChannel8;
layout(binding = 10) uniform sampler2D iChannel9;

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
// yamp: and& ampersand lockscreen, cycling through a playlist of modes.
// The build (convert-shaders.sh) concatenates NN_*.glsl in order, then
// shader.glsl:
//   00_knobs   — shared tuning constants, the mode table and playlist
//   10_lib     — generic helpers (rng, easing, sdf primitives, ray/box, grain)
//   20_modes   — mode sequencer machinery
//   30_amp     — glyph SDF and the per-amp spin/fill clock
//   40..42     — 2d modes: tiles (quadtree), field, drop
//   50_solid   — raymarched 3d amp, 3d amp mode and halftone
//   60..63     — shadow room: structure, outlet, phone, render
//   shader     — key indicator, mainImage
// Mode-specific knobs live at the top of their mode's file.
//
// Per amp, on its own clock (speed n*2*SPEED), the loop runs:
//   off (long) -> rotate (J/P counter-spin 360) -> off (short)
//   -> fill J (gradient wipe) -> fill P (offset wipe) -> on -> unfill -> loop
// sdJ/sdP sample a baked SDF texture (gen_sdf.py); the design gap (PAD) of
// the J is carved out of the P, so the pieces stay separated even mid-spin.

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

const float NOISE_LO    = 0.0;   // background noise brightness range
const float NOISE_HI    = 0.05;
const float NOISE_SCALE = 3.0;   // background noise texture frequency
const float BG_SPEED    = 0.3;   // background scroll, fraction of SCROLL
const float SCROLL      = 0.03;  // vertical scroll speed

// mode transitions circle-wipe over WIPE_DUR; the global zoom flips on
// ZOOM_PERIOD, offset by half
const float TRANS_DUR   = 1.2;   // zoom flip duration
const float WIPE_DUR    = 0.4;
const float ZOOM_PERIOD = 60. * 8.; // seconds per zoom flip
const float ZOOM_OUT    = 0.30;  // global zoom-out amount
const float ZOOM_ECC    = 5.7;   // zoom target distance from screen center
const float ZOOM_DRIFT  = 2300.7;  // zoom target orbit period (s) — offbeat
                                 // vs ZOOM_PERIOD so the spot always differs

const float FILM_GRAIN = 0.15;
const float FILM_FPS   = 24.;

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
// the playlist runs the modes in order, MODE_DUR each; the sequencer
// (20_modes) circle-wipes between neighbours over WIPE_DUR
const int MODE_TILES    = 0;
const int MODE_FIELD    = 1;
const int MODE_DROP     = 2;
const int MODE_SOLID    = 3;
const int MODE_HALFTONE = 4;
const int MODE_SHADOW   = 5;
const int MODE_PENROSE  = 6;
const int MODE_SCOPE    = 7;
const int MODE_SPECTRUM = 8;
const int MODE_PRISM    = 9;
const int MODE_COUNT    = 10;

const float MODE_AA[MODE_COUNT]    = float[MODE_COUNT](0., 0., 0., 1., 1., 1., 0., 0., 0., 0.);
const float MODE_GRAIN[MODE_COUNT] = float[MODE_COUNT](0., 0., 0., 0., 0., 1., 0., 0., 0., 0.);

const float D = 480.;
const float MODE_DUR[MODE_COUNT] = float[MODE_COUNT](D, D, D, D, D, D, D, D, D, D);

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
#define SDF_NORMAL(F, p, e) normalize(vec3( \
    F((p) + vec3(e, 0., 0.)) - F((p) - vec3(e, 0., 0.)), \
    F((p) + vec3(0., e, 0.)) - F((p) - vec3(0., e, 0.)), \
    F((p) + vec3(0., 0., e)) - F((p) - vec3(0., 0., e))))

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

vec2 gSeed = vec2(0.);   // session hash offset (sk_seed), set in mainImage —
                         // reshuffles every random() draw, so the quadtree
                         // pattern differs each session

float random (vec2 p) {
    return fract(sin(dot(p.xy + gSeed, vec2(12.9898,78.233)))* 43758.5453123);
}

uint pcg(uint v){
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

float pcgHash(uvec3 v){
    return float(pcg(v.x + pcg(v.y + pcg(v.z)))) / 4294967295.;
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

mat3 rotY(float a){ return mat3(cos(a), 0., -sin(a), 0., 1., 0., sin(a), 0., cos(a)); }
mat3 rotX(float a){ return mat3(1., 0., 0., 0., cos(a), sin(a), 0., -sin(a), cos(a)); }

vec2 ssOffset(int i, int n){
    return (vec2(i % n, i / n) + 0.5) / float(n) - 0.5;
}

vec3 bgNoise(vec2 tp){
    return vec3(mix(NOISE_LO, NOISE_HI, texture(iChannel1, fract(tp)).r));
}

vec3 filmGrain(vec3 col, float amt){
    uvec2 px = uvec2(ivec2(floor(gl_FragCoord.xy)));
    uint fr = uint(iTime * FILM_FPS);
    float g = pcgHash(uvec3(px, fr)) + pcgHash(uvec3(px, fr + 7919u)) - 1.;
    float l = dot(col, LUMA);
    return max(col + g * amt * (0.3 + 0.7 * 4. * l * (1. - l)), 0.);
}

vec3 acesApprox(vec3 v){
    v = max(v, 0.) * 0.6;
    return clamp((v * (2.51 * v + 0.03)) / (v * (2.43 * v + 0.59) + 0.14), 0., 1.);
}

vec3 srgbEncode(vec3 c){
    return mix(1.055 * pow(c, vec3(1. / 2.4)) - 0.055, 12.92 * c, step(c, vec3(0.0031308)));
}

float sdBox(vec2 p, vec2 b){
    vec2 q = abs(p) - b;
    return length(max(q, 0.)) + min(max(q.x, q.y), 0.);
}
float sdBox(vec3 p, vec3 b){
    vec3 q = abs(p) - b;
    return length(max(q, 0.)) + min(max(q.x, max(q.y, q.z)), 0.);
}
float sdRoundBox(vec2 p, vec2 b, float r){ return sdBox(p, b - r) - r; }
float sdRoundBox(vec3 p, vec3 b, float r){ return sdBox(p, b - r) - r; }

float sdExtrude(float d2, float z, float h, float r){
    vec2 w = vec2(d2 + r, abs(z) - h + r);
    return min(max(w.x, w.y), 0.) + length(max(w, 0.)) - r;
}

float sdSegment(vec2 p, vec2 a, vec2 b){
    vec2 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0., 1.));
}
float sdSegment(vec3 p, vec3 a, vec3 b){
    vec3 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0., 1.));
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

vec2 boxHit(vec3 ro, vec3 rd, vec3 bmin, vec3 bmax){
    vec3 inv = 1. / (rd + vec3(1e-7));
    vec3 ta = (bmin - ro) * inv, tb = (bmax - ro) * inv;
    vec3 t0 = min(ta, tb), t1 = max(ta, tb);
    return vec2(max(max(t0.x, t0.y), t0.z), min(min(t1.x, t1.y), t1.z));
}

vec3 bez3(vec3 a, vec3 b, vec3 c, vec3 d, float t){
    float s = 1. - t;
    return s * s * s * a + 3. * s * s * t * b + 3. * s * t * t * c + t * t * t * d;
}

vec2 catmull(vec2 a, vec2 b, vec2 c, vec2 d, float t){
    return 0.5 * (2. * b + (c - a) * t + (2. * a - 5. * b + 4. * c - d) * t * t + (3. * b - a - 3. * c + d) * t * t * t);
}
// --- mode sequencer ------------------------------------------------------------
// Walks the playlist and fills W, the per-pixel weight of each mode: 1 on
// the active mode, split between neighbours behind a circle wipe (WIPE_DUR)

float W[MODE_COUNT];
float gDropStart = 0.;

float wipe(vec2 q, float t){
    float x = clamp(t / WIPE_DUR, 0., 1.);
    if(x >= 1.) return 1.;
    float r = (1. - pow(1. - x, 3.)) * (0.5 * length(iResolution.xy) / iResolution.y + 0.01);
    return S(length(q) - r);
}

void addModes(vec2 q, float time, int devMode, float devAt, float k){
    float skip = 0.;
    float since = time;
    if(devMode >= 0){
        for(int i = 0; i < devMode % MODE_COUNT; i++) skip += MODE_DUR[i];
        since = time - devAt;
    }
    float total = 0.;
    for(int i = 0; i < MODE_COUNT; i++) total += MODE_DUR[i];
    float c = mod(since + skip, total);
    float acc = 0.;
    int to = 0;
    float modeTime = 0.;
    for(int i = 0; i < MODE_COUNT; i++){
        if(c < acc + MODE_DUR[i]){
            to = i;
            modeTime = c - acc;
            break;
        }
        acc += MODE_DUR[i];
    }
    int from = (to + MODE_COUNT - 1) % MODE_COUNT;
    // very first block (already active at iTime 0, wherever the skip landed
    // it): no wipe-in from the notional previous mode
    if(since <= modeTime + 0.001) from = to;
    if(to == MODE_DROP) gDropStart = time - modeTime;
    else if(from == MODE_DROP) gDropStart = time - modeTime - MODE_DUR[from];
    float b = wipe(q, modeTime);
    W[from] += k * (1. - b);
    W[to] += k * b;
}

void sequenceModes(vec2 q){
    for(int i = 0; i < MODE_COUNT; i++) W[i] = 0.;
    float sw = iTime - u_dev_switch_at;
    float b = (sw >= 0. && sw < WIPE_DUR) ? wipe(q, sw) : 1.;
    if(b < 1.) addModes(q, u_dev_switch_at, u_dev_prev_mode, u_dev_prev_at, 1. - b);
    addModes(q, iTime, u_dev_mode, u_dev_mode_at, b);
}
// --- and& ampersand: baked SDF texture (gen_sdf.py) -------------------------
// iChannel0: R = J piece, G = P piece, glyph space [-SDF_BOX,SDF_BOX]^2
// (v flipped), distances clamped to +-SDF_RANGE/2
const float PAD = 0.0464;      // design gap, measured from the artwork
const float SDF_BOX   = 0.75;
const float SDF_RANGE = 0.25;
float gFarPad = SDF_RANGE;

vec2 glyphUV(vec2 p){ return vec2(p.x, -p.y) / (2.0 * SDF_BOX) + 0.5; }

// the early-out branches return far + SDF_RANGE in 2d; the max() keeps the
// field growing past the texture's clamp plateau
float sdJ(vec2 p) {
    float far = length(p) - 0.57;   // J fits in radius 0.554
    if (far > (gFarPad > 0. ? 0.05 : SDF_RANGE * 0.5)) return far + gFarPad;
    return max((texture(iChannel0, glyphUV(p)).r - 0.5) * SDF_RANGE, far);
}
float sdP(vec2 p) {
    float far = length(p) - 0.66;   // P fits in radius 0.646
    if (far > (gFarPad > 0. ? 0.09 : SDF_RANGE * 0.5)) return far + gFarPad;
    return max((texture(iChannel0, glyphUV(p)).g - 0.5) * SDF_RANGE, far);
}

vec2 ampPieces(vec2 pJ, vec2 pP){
    float dj = sdJ(pJ);
    return vec2(dj, max(sdP(pP), PAD - dj));
}

float glyphDist(vec2 p){
    vec2 d = ampPieces(p, p);
    return min(d.x, d.y);
}

// brand gradient across the glyph (glyph space spans y in [-0.5,0.5])
vec3 ampGradient(vec2 p){
    return mix(GRAD_BOT, GRAD_TOP, clamp(p.y + 0.5, 0., 1.));
}

// --- ampersand animation ------------------------------------------------------
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

// rotate state: J and P counter-spin a full turn
void ampSpin(vec2 p, float frame, float dir, out vec2 pJ, out vec2 pP){
    pJ = p;
    pP = p;
    if(frame >= ROT_START && frame < ROT_START+T_ROTATE){
        float a = cubicInOut((frame-ROT_START)/T_ROTATE)*6.28318530718;
        pJ = rotAround(p, CJ, dir*a);
        pP = rotAround(p, CP, -dir*a);
    }
}

// fill states: brand-gradient wipes clipped inside each piece
float ampFill(vec2 pJ, vec2 pP, vec2 d, float frame){
    float fj = fillAnim(frame, FILLJ_START);
    float fp = fillAnim(frame, FILLP_START);
    float wj = max(d.x, length(pJ-SEED_J) - (fj*(RJ+0.02)-0.02));
    float wp = max(d.y, length(pP-SEED_P) - (fp*(RP+0.02)-0.02));
    return min(wj, wp);
}
const float AMP_SCALE  = 0.94;  // glyph size within its tile
const float TILE_PAD   = 0.01;  // circle padding to its cell edge
const float PAD_ZOOM   = 1.;   // how much tile content zooms out with the
                               // pad (1 = match the circle's shrink, 0 = off)
const float BIG_CHANCE = 0.15;  // chance a cell promotes to one huge amp
const float DARKEN = 0.25;        // off-amp darkening per subdivision level
const float SCROLL_MIN = 0.045;  // tile content scroll speed, random per tile
const float SCROLL_MAX = 0.09;
const float RING_BRIGHT = 0.3;    // border ring brightness
const float RING_WIDTH  = 0.0025; // border ring half-width, screen-height
                                  // units — same thickness at every level

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

vec3 drawAmp(vec2 p, float n, float sqd, float depth, float tileDepth){
    float tshade = pow(1. - DARKEN, tileDepth);

    // tile distance in screen-height units: undo the zoom, the two fixed
    // x2 grid scales and the tile's subdivision levels
    float sqs = sqd / (4. * exp2(tileDepth) * gZoom);
    if (sqs * iResolution.y > 1.5) return vec3(0.);

    // content clip at the rim: fades out fully AT the rim so nothing leaks
    // through the border ring's outer AA
    float rim = S(sqs + 1.3/iResolution.y);

    float frame = mod(iTime*n*2.*SPEED, LOOP_LEN);
    p /= AMP_SCALE;
    vec2 pJ, pP;
    ampSpin(p, frame, (fract(n)<0.5)? -1. : 1., pJ, pP);
    vec2 d = ampPieces(pJ, pP);

    // grey base, darker per subdivision level, then the gradient fill
    float dAmp = max(sqd, min(d.x, d.y) * AMP_SCALE);
    vec3 col = mix(vec3(0.), vec3(0.3) * pow(1. - DARKEN, depth), S(dAmp) * rim);
    float dw = max(sqd, ampFill(pJ, pP, d, frame) * AMP_SCALE);
    col = mix(col, ampGradient(p), S(dw) * rim);

    // hard border ring on the rim, drawn on the screen-space distance so
    // every level gets the same thickness
    float dring = abs(sqs + RING_WIDTH) - RING_WIDTH;
    return mix(col, vec3(RING_BRIGHT) * tshade, S(dring));
}

vec3 quadTree(vec2 p, float nn, float depth){
    p*=2.;
    float sqd = max(length(p), 1e-6) - (1. - TILE_PAD);

    // with a large pad the circle shrinks — zoom the content out to match
    p *= 1. + TILE_PAD / (1. - TILE_PAD) * PAD_ZOOM;

    // extra-large level: sometimes the whole cell is one huge ampersand
    if(fract(nn*57.31) < BIG_CHANCE){
        return drawAmp(p*0.5, nn+0.3, sqd, depth, depth);
    }

    if(nn<0.5){
        p.y-=iTime*mix(SCROLL_MIN, SCROLL_MAX, nn*2.)+nn;
        p*=1.2;
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

    return drawAmp(gr, n2+nn, sqd, ad, depth);
}

vec3 tiles(vec2 p){
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

    return quadTree(gr, n2, depth);
}
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
    vec2 pJ, pP;
    ampSpin(gp, frame, (fract(n*7.3) < 0.5) ? -1. : 1., pJ, pP);
    vec2 d = ampPieces(pJ, pP);
    float k = amp / (FIELD_ROWS * gZoom);

    vec3 col = bgNoise(tp) + GOLD_BOT * GOLD_GLOW * gb;
    float da = min(d.x, d.y);
    col = mix(col, vec3(0.3), S(da * k));
    col = mix(col, ampGradient(gp), S(ampFill(pJ, pP, d, frame) * k));
    vec3 gold = mix(GOLD_BOT, GOLD_TOP, clamp(gp.y + 0.5, 0., 1.));
    return mix(col, gold, g * S(da * k));
}
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

    vec3 col = bgNoise(tp);
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
        vec3 ac = random(cid + k * 5.1) < DROP_FILL ? ampGradient(gp) : vec3(0.3);
        col = mix(col, ac, S(glyphDist(gp) * kscr));
    }
    return col;
}
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

const float SQ_ROOM   = 5.;
const vec3  SQ_LIGHT  = vec3(1., -2., -1.);
const float SQ_OFFSET = 1.1;
const vec3  SQ_BASE   = vec3(3.9, 0.6, 0.9);
const float SQ_GAIN   = 11.;

const float HALF_ROWS   = 64.;
const float HALF_ANGLE  = 0.785398;
const float HALF_MAX    = 0.85;
const float HALF_BG     = 0.;
const float HALF_AMBIENT = 0.08;
const float HALF_ORBIT  = 0.25;
const float HALF_LIGHT_Z = 0.6;
const float HALF_SHINE  = 24.;
const float HALF_GLINT  = 0.6;
const float HALF_CONTRAST = 1.6;
const vec3  HALF_GREY   = vec3(0.3);
const float HALF_TINT_LO = 0.2;
const float HALF_TINT_HI = 0.8;

float solidMap(vec3 p){
    return sdExtrude(glyphDist(p.xy), p.z, SOLID_DEPTH, SOLID_BEVEL);
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

mat3 solidSpin(){
    return rotY(iTime * SOLID_SPIN) * rotX(SOLID_TILT * sin(iTime * SOLID_TILT_RATE));
}

float solidMarch(vec3 ro, vec3 rd, int steps, out float dmin, out float tmin){
    dmin = 1e9;
    tmin = 0.;
    vec3 bx = vec3(0.7, 0.7, SOLID_DEPTH + 0.01);
    vec2 h = boxHit(ro, rd, -bx, bx);
    if(h.x > h.y || h.y < 0.) return -1.;
    float t = max(h.x, 0.);
    tmin = t;
    for(int i = 0; i < steps; i++){
        float d = solidMap(ro + rd * t);
        if(d < dmin){ dmin = d; tmin = t; }
        if(d < max(0.0002, t * SOLID_HIT_PX / (SOLID_FOCAL * iResolution.y))) return t;
        t += d * 0.9;
        if(t > h.y) break;
    }
    return -1.;
}

float solidShadow(vec3 ro, vec3 rd, float tmax, float k, int steps){
    vec3 bx = vec3(0.85, 0.85, SOLID_DEPTH + 0.15);
    vec2 h = boxHit(ro, rd, -bx, bx);
    if(h.x > h.y || h.y < 0. || h.x > tmax) return 1.;
    float res = 1.;
    float t = max(h.x, 0.);
    for(int i = 0; i < steps; i++){
        float d = solidMap(ro + rd * t);
        if(d < 0.0005) return 0.;
        if(d < 0.1) res = min(res, k * d / t);
        t += clamp(d, 0.002, 0.1);
        if(t > h.y) break;
    }
    res = clamp(res, 0., 1.);
    return res * res * (3. - 2. * res);
}

float solidLight(vec3 n, vec3 L, vec3 F, vec3 up, float amb){
    return amb * mix(SOLID_GROUND, 1., dot(n, up) * 0.5 + 0.5)
         + (1. - amb) * max(dot(n, L), 0.)
         + SOLID_FILL * max(dot(n, F), 0.);
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
    return srgbEncode(acesApprox(o * SQ_GAIN));
}

vec3 solidShade(vec3 po, vec3 no, vec3 dir, vec3 L, vec3 Fo, vec3 up, float amb, float kd, float shine, float spec){
    vec3 base = ampGradient(po.xy) * mix(1., 0.5, 1. - abs(no.z));
    float s = pow(max(dot(no, normalize(L - dir)), 0.), shine);
    return base * solidLight(no, L, Fo, up, amb) * kd + vec3(s) * spec;
}

vec3 solidSample(vec2 q, vec3 bg, mat3 M){
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
    vec3 p0 = oro + ord * t;
    vec3 matte = solidShade(p0, solidNormal(p0), ord, L, Fo, up, MATTE_AMBIENT, 1., MATTE_SHINE, MATTE_SPEC);
    if(u_solid_matte > 0.999) return mix(bg, matte, cov);

    vec3 col = vec3(0.);
    float A = 1.;
    vec3 ro = oro, dir = ord;
    for(int bnc = 0; bnc <= SOLID_BOUNCES; bnc++){
        vec3 po = ro + dir * t;
        vec3 no = solidNormal(po);
        col += A * solidShade(po, no, dir, L, Fo, up, 0.12, SOLID_KD, SOLID_SHINE, SOLID_SPEC);
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

vec3 solidBg(vec2 q, vec2 tp){
    return mix(GRAD_BOT, GRAD_TOP, 0.5) * SOLID_GLOW * (1. - smoothstep(0., SOLID_GLOW_R, length(q)))
         + bgNoise(tp);
}

vec3 solid(vec2 q, vec2 tp){
    vec3 bg = solidBg(q, tp);
    mat3 M = solidSpin();
    gFarPad = 0.;
    {
        mat3 Mi = transpose(M);
        float dmin, tmin;
        float t = solidMarch(Mi * vec3(0., 0., -SOLID_DIST), Mi * normalize(vec3(q, SOLID_FOCAL)), SOLID_STEPS, dmin, tmin);
        if(t < 0. && dmin * SOLID_FOCAL * iResolution.y > 3. * max(tmin, 1.)){
            gFarPad = SDF_RANGE;
            return bg;
        }
    }
    vec3 c = vec3(0.);
    for(int i = 0; i < SOLID_SS * SOLID_SS; i++)
        c += solidSample(q + ssOffset(i, SOLID_SS) / iResolution.y, bg, M);
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

    mat3 M = solidSpin();
    mat3 Mi = transpose(M);
    vec3 rd = normalize(vec3(qc, SOLID_FOCAL));
    vec3 oro = Mi * vec3(0., 0., -SOLID_DIST);
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

    vec3 col = bgNoise(tp);
    float s = HALF_MAX * sqrt(clamp(lum, 0., 1.));
    if(s < 0.01) return col;
    vec2 gp = l / s;
    vec3 tint = mix(HALF_GREY, ampGradient(vec2(0., gy)), smoothstep(HALF_TINT_LO, HALF_TINT_HI, lum));
    vec3 ink = mix(tint, vec3(1.), glint);
    return mix(col, ink, S(glyphDist(gp) * s / HALF_ROWS));
}
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

const int ID_NONE    = -1;
const int ID_FLOOR   = 0;
const int ID_WALL    = 1;
const int ID_SIDE    = 2;
const int ID_SKIRT   = 3;
const int ID_FELT    = 4;
const int ID_LEG     = 5;
const int ID_CAP     = 6;
const int ID_FRAME   = 7;
const int ID_CHARGER = 8;
const int ID_CABLE   = 9;
const int ID_CLIP    = 10;
const int ID_INSERT  = 11;
const int ID_PHONE   = 12;
const int ID_SCREEN  = 13;

bool isWall(int id){ return id == ID_WALL || id == ID_SIDE; }
bool isHocker(int id){ return id >= ID_FELT && id <= ID_CAP; }
bool isOutlet(int id){ return id >= ID_FRAME && id <= ID_INSERT; }

float gPx = 0.001;
vec3 gRo, gF, gR, gU;
mat3 gYaw;
vec3 gCo, gCright, gCfwd, gLight, gAmpPos;
mat3 gAmpMi;

vec3 camRay(vec2 q){
    return gYaw * normalize(gF * SHADOW_FOCAL + gR * q.x + gU * q.y);
}

vec2 floorAt(vec2 frac){
    vec3 rd = camRay(vec2((frac.x - 0.5) * iResolution.x / iResolution.y, 0.5 - frac.y));
    return (gRo + rd * (-gRo.y / min(rd.y, -1e-3))).xz;
}

vec3 toHocker(vec3 v){ return vec3(dot(v, gCright), v.y, dot(v, gCfwd)); }
vec3 fromHocker(vec3 v){ return v.x * gCright + vec3(0., v.y, 0.) + v.z * gCfwd; }

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

float raufaser(vec2 w){
    vec2 u = w / (SHADOW_WALL_GRAIN * 512.);
    float h = texture(iChannel1, fract(u)).r * 0.6 + texture(iChannel1, fract(u * 2.3 + 0.37)).r * 0.4;
    return h * h;
}

float skirtProfile(vec2 p){
    float D = SHADOW_SKIRT_D, H = SHADOW_SKIRT_H;
    float R = D * SHADOW_SKIRT_BEAD;
    float hb = H - R;
    float board = sdBox(p - vec2(D * 0.5, hb * 0.5), vec2(D * 0.5, hb * 0.5));
    float bead = length(p - vec2(D * 0.55, hb)) - R;
    float k = R * 0.8;
    float h = clamp(0.5 + 0.5 * (bead - board) / k, 0., 1.);
    return mix(bead, board, h) - k * h * (1. - h);
}

float skirtUnion(vec3 p){
    return min(skirtProfile(vec2(SHADOW_WALL_Z - p.z, p.y)), skirtProfile(vec2(p.x - SHADOW_SIDE_X, p.y)));
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
    float body = sdRoundBox(p - vec3(-b.x, SHADOW_COUCH_LEG + b.y, b.z), b, 0.08);
    float leg = 1e9, mat = 1.;
    for(int i = 0; i < 4; i++){
        vec3 lo = couchFoot(i);
        vec3 hi = couchTop(i);
        float d = sdRoundCone(p, lo, hi, SHADOW_LEG_TOE, SHADOW_LEG_TOP);
        float plate = sdBox(p - vec3(hi.x, SHADOW_COUCH_LEG, hi.z), vec3(0.07, 0.012, 0.07));
        if(d < leg){
            leg = d;
            mat = (p.y - lo.y + SHADOW_LEG_TOE) < SHADOW_LEG_FERRULE ? 2. : 1.;
        }
        if(plate < leg){ leg = plate; mat = 1.; }
    }
    foot = leg < body ? mat : 0.;
    return min(body, leg);
}

float couchDist(vec3 p){
    float f;
    return couchSdf(p, f);
}

float couchShadow(vec3 ro, vec3 rd, float tmax){
    vec2 h = boxHit(ro, rd, vec3(-SHADOW_COUCH_W - 0.1, 0., -0.2), vec3(0.15, SHADOW_COUCH_TOP + 0.1, SHADOW_COUCH_L + 0.2));
    float tF = min(h.y, tmax);
    if(h.x > tF || tF < 0.) return 1.;
    float res = 1., t = max(h.x, 0.01);
    for(int i = 0; i < 64; i++){
        float d = couchDist(ro + rd * t);
        if(d < 0.001) return 0.;
        res = min(res, SHADOW_K * 0.25 * d / t);
        t += clamp(d, 0.01, 0.4);
        if(t > tF) break;
    }
    return clamp(res, 0., 1.);
}

float couchMarch(vec3 ro, vec3 rd, float tmax){
    float t = 0.;
    for(int i = 0; i < 80; i++){
        float d = couchDist(ro + rd * t);
        if(d < 0.0005 * (1. + t)) return t < tmax ? t : -1.;
        t += d;
        if(t > tmax) break;
    }
    return -1.;
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
const vec3  SHADOW_CABLE_COL     = vec3(0.03, 0.045, 0.05);

vec2 gOutletPos, gOutletQ;
vec2 gCableDir;
vec2 gPath[5];

float cableSdf(vec3 q){
    float S = SHADOW_OUTLET_SCALE;
    vec2 hs = SHADOW_OUTLET_SIZE * 0.5;
    float r = SHADOW_CABLE_R;
    float z0 = SHADOW_OUTLET_T * 0.27 + SHADOW_OUTLET_PLUG;
    float plug = sdRoundBox(q / S - vec3(hs.x * 0.5, -0.005, z0 + 0.0175), vec3(0.026, 0.01, 0.0175), 0.004) * S;
    vec3 p0 = vec3(hs.x * 0.5, -0.005, z0 + 0.035) * S;
    vec3 p3 = vec3(p0.x + SHADOW_CABLE_DROP.x, -gOutletPos.y + r, SHADOW_CABLE_DROP.y);
    vec3 df = vec3(gCableDir.x, 0., gCableDir.y);
    vec3 c1 = p0 + vec3(0., 0., 0.12);
    vec3 c2 = p3 - df * 0.18 + vec3(0., 0.02, 0.);
    float d = 1e9;
    vec3 prev = p0;
    for(int i = 1; i <= 10; i++){
        vec3 cur = bez3(p0, c1, c2, p3, float(i) / 10.);
        d = min(d, sdSegment(q, prev, cur));
        prev = cur;
    }
    return min(plug, d - r);
}

float outletSdf(vec3 q, out float mat){
    float S = SHADOW_OUTLET_SCALE;
    vec3 qs = q / S;
    vec2 hs = SHADOW_OUTLET_SIZE * 0.5;
    float th = SHADOW_OUTLET_T;
    float plate = sdExtrude(sdRoundBox(qs.xy, hs, 0.035), qs.z - th * 0.5, th * 0.5, 0.006);
    float insert = 1e9, clips = 1e9;
    float ih = SHADOW_OUTLET_INSERT;
    float itop = th + SHADOW_OUTLET_PROUD;
    for(int i = 0; i < 2; i++){
        vec2 c = vec2(i == 0 ? -hs.x * 0.5 : hs.x * 0.5, 0.);
        float hole = sdRoundBox(qs.xy - c, vec2(ih + SHADOW_OUTLET_GROOVE), 0.02);
        plate = max(plate, -max(hole, th * 0.15 - qs.z));
        float ins = sdExtrude(sdRoundBox(qs.xy - c, vec2(ih), 0.018), qs.z - itop * 0.5, itop * 0.5, 0.007);
        float cyl = length(qs.xy - c) - SHADOW_OUTLET_SOCKET;
        ins = max(ins, -max(cyl, th * 0.27 - qs.z));
        insert = min(insert, ins);
        vec3 kq = vec3(qs.x - c.x, abs(qs.y) - SHADOW_OUTLET_SOCKET + 0.004, qs.z - th * 0.6);
        clips = min(clips, sdRoundBox(kq, vec3(0.017, 0.006, th * 0.32), 0.002));
    }
    float charger = sdRoundBox(qs - vec3(hs.x * 0.5, 0., th * 0.27 + SHADOW_OUTLET_PLUG * 0.5), vec3(0.068, 0.068, SHADOW_OUTLET_PLUG * 0.5), 0.018);
    plate *= S;
    insert *= S;
    clips *= S;
    charger *= S;
    float cable = cableSdf(q);
    float d = min(min(min(plate, insert), charger), min(cable, clips));
    mat = d == cable ? 2. : d == charger ? 1. : d == clips ? 3. : d == insert ? 4. : 0.;
    return d;
}

float outletDist(vec3 q){
    float m;
    return outletSdf(q, m);
}

vec3 outletLocal(vec3 p){
    return vec3(p.x - gOutletPos.x, p.y - gOutletPos.y, SHADOW_WALL_Z - p.z);
}

float outletMarch(vec3 ro, vec3 rd, float tmax){
    vec3 lo = outletLocal(ro), ld = vec3(rd.x, rd.y, -rd.z);
    vec3 bmin = vec3(-SHADOW_OUTLET_SIZE.x * 0.5 * SHADOW_OUTLET_SCALE - 0.01, -gOutletPos.y - 0.01, -0.01);
    vec3 bmax = vec3(SHADOW_OUTLET_SIZE.x * 0.5 * SHADOW_OUTLET_SCALE + SHADOW_CABLE_DROP.x + 0.1, SHADOW_OUTLET_SIZE.y * 0.5 * SHADOW_OUTLET_SCALE + 0.01, max(SHADOW_CABLE_DROP.y, SHADOW_OUTLET_T + SHADOW_OUTLET_PLUG + 0.2) + 0.05);
    vec2 h = boxHit(lo, ld, bmin, bmax);
    float tF = min(h.y, tmax);
    if(h.x > tF || tF < 0.) return -1.;
    float t = max(h.x, 0.);
    for(int i = 0; i < 64; i++){
        float d = outletDist(lo + ld * t);
        if(d < 0.0002) return t;
        t += d;
        if(t > tF) break;
    }
    return -1.;
}

vec3 outletAlbedo(vec3 qw, int id, out float emit){
    vec3 q = qw / SHADOW_OUTLET_SCALE;
    vec2 hs = SHADOW_OUTLET_SIZE * 0.5;
    float floorZ = SHADOW_OUTLET_T * 0.27 + 0.002;
    float px = gPx / SHADOW_OUTLET_SCALE + 1e-5;
    emit = 0.;
    if(id == ID_CABLE) return SHADOW_CABLE_COL;
    if(id == ID_CLIP) return SHADOW_CLIP_COL;
    if(id == ID_CHARGER){
        vec2 c = vec2(hs.x * 0.5, -0.005);
        if(q.z < SHADOW_OUTLET_T * 0.27 + SHADOW_OUTLET_PLUG - 0.004) return SHADOW_OUTLET_COL * 0.95;
        vec2 d = abs(q.xy - c);
        float port = 1. - smoothstep(-px, px, max(d.x - 0.03, d.y - 0.011));
        float tongue = 1. - smoothstep(-px, px, max(d.x - 0.024, d.y - 0.004));
        emit = 1. - smoothstep(-px, px, length(q.xy - vec2(c.x, 0.044)) - 0.006);
        return mix(mix(SHADOW_OUTLET_COL * 0.95, vec3(0.02), port), SHADOW_OUTLET_ACCENT, tongue);
    }
    if(id == ID_FRAME) return SHADOW_OUTLET_COL;
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

void placeOutlet(){
    float qx = (SHADOW_OUTLET_SCREEN_X - 0.5) * iResolution.x / iResolution.y;
    float qy = 0.;
    vec3 hit;
    for(int i = 0; i < 4; i++){
        vec3 d0 = camRay(vec2(qx, qy));
        vec3 d1 = camRay(vec2(qx, qy + 0.01));
        vec3 h0 = gRo + d0 * (SHADOW_WALL_Z - gRo.z) / d0.z;
        vec3 h1 = gRo + d1 * (SHADOW_WALL_Z - gRo.z) / d1.z;
        qy += (SHADOW_OUTLET_Y - h0.y) * 0.01 / (h1.y - h0.y);
        hit = h0;
    }
    gOutletPos = vec2(hit.x, SHADOW_OUTLET_Y);
    gOutletQ = vec2(qx, qy);
}

bool outletSS(vec2 q){
    vec2 dq = q - gOutletQ;
    return abs(dq.x) < SHADOW_OUTLET_SS.x && dq.y > -SHADOW_OUTLET_SS.y && dq.y < SHADOW_OUTLET_SS.z;
}
const vec2  SHADOW_PHONE_SCREEN  = vec2(0.82, 0.74);
const float SHADOW_PHONE_YAW     = 0.7;
const vec3  SHADOW_PHONE_SIZE    = vec3(0.238, 0.493, 0.0255);
const vec3  SHADOW_PHONE_COL     = vec3(0.02, 0.025, 0.03);
const float SHADOW_PHONE_BRIGHT  = 1.6;
const float SHADOW_PHONE_GLOW    = 0.;
const float SHADOW_PHONE_DIGIT   = 0.038;
const float SHADOW_PHONE_TIME_Y  = 0.;

vec3 gPhoneC;
vec2 gPhoneU, gPhoneR;

vec3 phoneHalf(){
    return vec3(SHADOW_PHONE_SIZE.x, SHADOW_PHONE_SIZE.z, SHADOW_PHONE_SIZE.y) * 0.5;
}

vec3 phoneLocal(vec3 p){
    vec2 d = p.xz - gPhoneC.xz;
    return vec3(dot(d, gPhoneR), p.y - SHADOW_PHONE_SIZE.z * 0.5, dot(d, gPhoneU));
}

vec3 phoneLocalDir(vec3 rd){
    return vec3(dot(rd.xz, gPhoneR), rd.y, dot(rd.xz, gPhoneU));
}

vec3 phoneWorldDir(vec3 g){
    return vec3(g.x * gPhoneR.x + g.z * gPhoneU.x, g.y, g.x * gPhoneR.y + g.z * gPhoneU.y);
}

float phoneSdfM(vec3 q, out float mat){
    vec3 b = phoneHalf();
    float body = sdExtrude(sdRoundBox(q.xz, b.xz, 0.04), q.y, b.y, 0.008);
    float r = SHADOW_CABLE_R;
    float plug = sdRoundBox(q - vec3(0., 0., -b.z - 0.018), vec3(0.016, 0.007, 0.02), 0.003);
    vec3 a0 = vec3(0., 0., -b.z - 0.036), a1 = vec3(0., -b.y + r, -b.z - SHADOW_CABLE_LEAD * 0.6);
    vec3 h = a0 + vec3(0., 0., -0.03);
    float stub = min(sdSegment(q, a0, h), sdSegment(q, h, a1)) - r;
    float acc = min(plug, stub);
    mat = acc < body ? 1. : 0.;
    return min(body, acc);
}

float phoneSdf(vec3 q){
    float m;
    return phoneSdfM(q, m);
}

vec2 phoneBoxHit(vec3 ro, vec3 rd, float pad){
    vec3 hb = phoneHalf() + pad;
    vec3 lb = -hb - vec3(0., 0., SHADOW_CABLE_LEAD * 0.6 + 0.05);
    return boxHit(phoneLocal(ro), phoneLocalDir(rd), lb, hb);
}

bool phoneSS(vec3 ro, vec3 rd){
    vec2 h = phoneBoxHit(ro, rd, 0.02);
    return h.x < h.y;
}

float phoneMarch(vec3 ro, vec3 rd, float tmax){
    vec2 h = phoneBoxHit(ro, rd, 0.01);
    float tF = min(h.y, tmax);
    if(h.x > tF || tF < 0.) return -1.;
    vec3 lo = phoneLocal(ro), ld = phoneLocalDir(rd);
    float t = max(h.x, 0.);
    for(int i = 0; i < 40; i++){
        float d = phoneSdf(lo + ld * t);
        if(d < 0.0002) return t;
        t += d;
        if(t > tF) break;
    }
    return -1.;
}

float digitDist(vec2 p, int n){
    int masks[10] = int[10](0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F);
    int m = masks[clamp(n, 0, 9)];
    float w = 0.5, h = 1.;
    vec2 A[7] = vec2[7](vec2(-w, h), vec2(w, h), vec2(w, 0.), vec2(-w, -h), vec2(-w, 0.), vec2(-w, h), vec2(-w, 0.));
    vec2 B[7] = vec2[7](vec2(w, h), vec2(w, 0.), vec2(w, -h), vec2(w, -h), vec2(-w, -h), vec2(-w, 0.), vec2(w, 0.));
    float d = 1e9;
    for(int s = 0; s < 7; s++)
        if(((m >> s) & 1) == 1) d = min(d, sdSegment(p, A[s], B[s]));
    return d - 0.13;
}

vec3 phoneScreen(vec2 s){
    float px = gPx + 1e-5;
    vec4 c = iClock;
    float ch = SHADOW_PHONE_DIGIT;
    vec2 tp = (vec2(-s.y, s.x) - vec2(0., SHADOW_PHONE_TIME_Y)) / ch;
    float d = min(min(digitDist(tp - vec2(-3.3, 0.), int(c.x)), digitDist(tp - vec2(-1.3, 0.), int(c.y))),
                  min(digitDist(tp - vec2(1.3, 0.), int(c.z)), digitDist(tp - vec2(3.3, 0.), int(c.w))));
    d = min(d, min(length(tp - vec2(0., 0.45)), length(tp - vec2(0., -0.45))) - 0.15);
    return GRAD_TOP * (1. - smoothstep(-px, px, d * ch));
}

float phoneGlow(vec3 p){
    vec2 d = p.xz - gPhoneC.xz;
    vec2 pd = abs(vec2(dot(d, gPhoneR), dot(d, gPhoneU))) - SHADOW_PHONE_SIZE.xy * 0.5;
    return exp(-length(max(pd, 0.)) * 12.) * SHADOW_PHONE_GLOW;
}

void placePhone(){
    vec2 c = floorAt(SHADOW_PHONE_SCREEN);
    gPhoneC = vec3(c.x, SHADOW_PHONE_SIZE.z * 0.5, c.y);
    vec2 cfw = gCfwd.xz;
    float pa = SHADOW_PHONE_YAW;
    gPhoneU = vec2(cos(pa) * cfw.x - sin(pa) * cfw.y, sin(pa) * cfw.x + cos(pa) * cfw.y);
    gPhoneR = vec2(gPhoneU.y, -gPhoneU.x);
}
void placeCable(){
    float lx = SHADOW_OUTLET_SIZE.x * 0.25 * SHADOW_OUTLET_SCALE + SHADOW_CABLE_DROP.x;
    gPath[0] = vec2(gOutletPos.x + lx, SHADOW_WALL_Z - SHADOW_CABLE_DROP.y);
    gPath[4] = gPhoneC.xz - gPhoneU * SHADOW_PHONE_SIZE.y * 0.5;
    gPath[3] = gPath[4] - gPhoneU * SHADOW_CABLE_LEAD;
    gPath[1] = floorAt(SHADOW_CABLE_OUT1);
    gPath[2] = floorAt(SHADOW_CABLE_OUT2);
    vec2 dw = normalize(gPath[1] - gPath[0]);
    gCableDir = vec2(dw.x, -dw.y);
}

void setupCamera(){
    vec3 ro = SHADOW_CAM;
    gF = normalize(SHADOW_TARGET - ro);
    gR = normalize(cross(vec3(0., 1., 0.), gF));
    gU = cross(gF, gR);
    gYaw = rotY(SHADOW_YAW);
    vec3 pivot = vec3(0., 0., SHADOW_WALL_Z);
    gRo = pivot + gYaw * (ro - pivot);

    gCfwd = normalize(gYaw * vec3(gF.x, 0., gF.z));
    gCright = vec3(gCfwd.z, 0., -gCfwd.x);
    gCo = vec3(gRo.x, 0., gRo.z) + gCfwd * SHADOW_COUCH_FWD - gCright * SHADOW_COUCH_LEFT;
    mat3 rig = rotY(SHADOW_RIG_YAW);
    vec3 rp = vec3(gRo.x, 0., gRo.z);
    gLight = rp + rig * (SHADOW_LIGHT - rp);
    gAmpPos = rp + rig * (SHADOW_AMP_POS - rp);
    gAmpMi = transpose(rotY(SHADOW_FACE + SHADOW_RIG_YAW + SHADOW_SWAY * sin(iTime * SHADOW_SWAY_RATE)));

}

void setupRoom(){
    setupCamera();
    placeOutlet();
    placePhone();
    placeCable();
}

struct Hit {
    float t;
    int id;
    vec3 n;
    vec3 lp;
    vec3 ln;
};

Hit sceneTrace(vec3 ro, vec3 rd){
    Hit h = Hit(1e9, ID_NONE, vec3(0., 1., 0.), vec3(0.), vec3(0., 1., 0.));
    if(rd.y < 0.){ h.t = -ro.y / rd.y; h.id = ID_FLOOR; }
    if(rd.z > 0.){
        float tt = (SHADOW_WALL_Z - ro.z) / rd.z;
        if(tt < h.t){ h.t = tt; h.id = ID_WALL; h.n = vec3(0., 0., -1.); }
    }
    if(rd.x < 0.){
        float tt = (SHADOW_SIDE_X - ro.x) / rd.x;
        if(tt < h.t){ h.t = tt; h.id = ID_SIDE; h.n = vec3(1., 0., 0.); }
    }
    {
        float ys = SHADOW_SKIRT_H * 1.05;
        float ts = ro.y <= ys ? 0. : (rd.y < 0. ? (ys - ro.y) / rd.y : 1e9);
        if(ts < h.t){
            for(int i = 0; i < 64; i++){
                float ds = skirtUnion(ro + rd * ts);
                if(ds < 0.0002){
                    h.t = ts;
                    h.id = ID_SKIRT;
                    h.n = SDF_NORMAL(skirtUnion, ro + rd * ts, 0.0005);
                    break;
                }
                ts += ds * 0.9;
                if(ts > h.t) break;
            }
        }
    }
    {
        float to = outletMarch(ro, rd, h.t);
        if(to > 0. && to < h.t){
            h.t = to;
            vec3 lp = outletLocal(ro + rd * to);
            float m;
            outletSdf(lp, m);
            h.id = ID_FRAME + int(m + 0.5);
            h.lp = lp;
            vec3 g = SDF_NORMAL(outletDist, lp, 0.0005);
            h.n = vec3(g.x, g.y, -g.z);
        }
    }
    {
        float tp = phoneMarch(ro, rd, h.t);
        if(tp > 0. && tp < h.t){
            h.t = tp;
            vec3 lp = phoneLocal(ro + rd * tp);
            h.lp = lp;
            vec3 g = SDF_NORMAL(phoneSdf, lp, 0.0005);
            h.n = phoneWorldDir(g);
            float pm;
            phoneSdfM(lp, pm);
            h.id = pm > 0.5 ? ID_CABLE : g.y > 0.9 ? ID_SCREEN : ID_PHONE;
        }
    }
    {
        vec3 lro = toHocker(ro - gCo), lrd = toHocker(rd);
        float tc = couchMarch(lro, lrd, h.t);
        if(tc >= 0.){
            h.t = tc;
            vec3 lp = lro + lrd * tc;
            float foot;
            couchSdf(lp, foot);
            h.id = ID_FELT + int(foot + 0.5);
            h.lp = lp;
            h.ln = SDF_NORMAL(couchDist, lp, 0.002);
            h.n = fromHocker(h.ln);
        }
    }
    return h;
}

float roomAO(vec3 p, int id, float cable){
    if(id == ID_FLOOR){
        float ao = mix(SHADOW_CORNER, 1., smoothstep(0., 0.6, SHADOW_WALL_Z - SHADOW_SKIRT_D - p.z))
                 * mix(SHADOW_CORNER, 1., smoothstep(0., 0.6, p.x - SHADOW_SIDE_X - SHADOW_SKIRT_D));
        vec2 fxz = toHocker(p - gCo).xz;
        for(int i = 0; i < 4; i++)
            ao *= mix(0.3, 1., smoothstep(SHADOW_LEG_TOE * 0.6, SHADOW_LEG_TOE * 3.5, length(fxz - couchFoot(i).xz)));
        float fd = sdBox(fxz - vec2(-SHADOW_COUCH_W * 0.5, SHADOW_COUCH_L * 0.5), vec2(SHADOW_COUCH_W, SHADOW_COUCH_L) * 0.5);
        ao *= mix(SHADOW_COUCH_UNDER, 1., smoothstep(-0.1, SHADOW_COUCH_SPREAD, fd));
        if(cable >= SHADOW_CABLE_R) ao *= mix(0.45, 1., smoothstep(SHADOW_CABLE_R, SHADOW_CABLE_R * 3., cable));
        return ao;
    }
    float skirtTop = mix(SHADOW_CORNER, 1., smoothstep(0., 0.125, p.y - SHADOW_SKIRT_H));
    if(id == ID_WALL) return skirtTop * mix(SHADOW_CORNER, 1., smoothstep(0., 0.4, p.x - SHADOW_SIDE_X));
    if(id == ID_SIDE) return skirtTop * mix(SHADOW_CORNER, 1., smoothstep(0., 0.4, SHADOW_WALL_Z - p.z));
    if(id == ID_SKIRT){
        float gy = SHADOW_SKIRT_H - SHADOW_SKIRT_D * SHADOW_SKIRT_BEAD * 2.6;
        float gw = SHADOW_SKIRT_D * 0.12 + gPx;
        return mix(SHADOW_CORNER, 1., smoothstep(0., 0.03, p.y))
             * (1. - 0.55 * (1. - smoothstep(0., gw, abs(p.y - gy))));
    }
    return 1.;
}

float staticShadow(vec3 p, vec3 n, vec3 ld, float dist, int id){
    if(outletMarch(p + n * 0.002, ld, dist) > 0.) return 0.;
    if(id == ID_FLOOR || id == ID_WALL || id == ID_SKIRT)
        return couchShadow(toHocker(p + n * 0.004 - gCo), toHocker(ld), dist);
    return 1.;
}

struct Shade {
    vec3 base;
    vec3 light;
};

Shade shadeScene(vec3 ro, vec3 rd, Hit h){
    if(h.id == ID_NONE) return Shade(vec3(0.), vec3(0.));
    int id = h.id;
    vec3 n = h.n;
    vec3 p = ro + rd * h.t;
    gPx = h.t / (SHADOW_FOCAL * iResolution.y) / sqrt(max(abs(dot(n, rd)), 0.3));
    if(id == ID_SCREEN) return Shade(phoneScreen(h.lp.xz) * SHADOW_PHONE_BRIGHT, vec3(0.));
    vec3 cf = id == ID_FLOOR ? cableFloor(p.xz) : vec3(1e9, 0., 0.);
    bool onCable = cf.x < SHADOW_CABLE_R;
    if(onCable){
        float a = cf.x / SHADOW_CABLE_R;
        n = normalize(vec3(cf.y * a, sqrt(max(1. - a * a, 0.)), cf.z * a));
    }
    float rauh = 0.5;
    if(isWall(id)){
        vec2 wv = id == ID_WALL ? p.xy : p.zy;
        vec3 T = id == ID_WALL ? vec3(1., 0., 0.) : vec3(0., 0., 1.);
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
    float sh = dif > 0. ? staticShadow(p, n, ld, dist, id) : 0.;
    float ao = roomAO(p, id, cf.x);

    float emit = 0.;
    vec3 albedo = id == ID_FLOOR ? (onCable ? SHADOW_CABLE_COL : SHADOW_FLOOR * floorBoards(p.xz))
                : id == ID_PHONE ? SHADOW_PHONE_COL
                : isWall(id) ? SHADOW_WALL * mix(1. - SHADOW_WALL_TONE, 1. + SHADOW_WALL_TONE, rauh)
                : id == ID_FELT ? SHADOW_COUCH * felt(h.lp, h.ln) + SHADOW_FELT_SHEEN * pow(1. - max(dot(n, -rd), 0.), 4.)
                : id == ID_LEG ? SHADOW_WOOD * mix(0.75, 1.25, texture(iChannel1, fract(vec2((h.lp.x + h.lp.z) * 1.7, h.lp.y * 0.08))).r)
                : id == ID_CAP ? SHADOW_BRASS
                : isOutlet(id) ? outletAlbedo(h.lp, id, emit) : SHADOW_SKIRT;
    float gain = SHADOW_GAIN * (id == ID_FLOOR ? SHADOW_FLOOR_GAIN : 1.);
    float amb = isHocker(id) ? SHADOW_COUCH_AMB : SHADOW_AMB;
    float rv = max(dot(reflect(-ld, n), -rd), 0.);
    vec3 spec = id == ID_LEG ? vec3(SHADOW_WOOD_SHEEN) * pow(rv, 24.)
              : id == ID_CAP ? vec3(SHADOW_BRASS_SHINE) * pow(rv, 60.)
              : id == ID_CLIP ? vec3(SHADOW_CLIP_SHINE) * pow(rv, 70.)
              : (isOutlet(id) || id == ID_SIDE || onCable) ? vec3(SHADOW_OUTLET_GLOSS) * pow(rv, 32.) : vec3(0.);
    float glow = id == ID_FLOOR ? phoneGlow(p) : 0.;
    return Shade(albedo * amb * ao + SHADOW_OUTLET_ACCENT * 3. * emit + GRAD_TOP * glow,
                 (albedo * gain * dif * ao + spec) * sh);
}

Shade roomBake(vec2 q){
    setupRoom();
    vec3 rd = camRay(q);
    bool ss = outletSS(q) || phoneSS(gRo, rd);
    if(rd.z > 0.){
        float yw = gRo.y + rd.y * (SHADOW_WALL_Z - gRo.z) / rd.z;
        ss = ss || (yw > -SHADOW_SKIRT_SS.x && yw < SHADOW_SKIRT_H + SHADOW_SKIRT_SS.y);
    }
    if(!ss) return shadeScene(gRo, rd, sceneTrace(gRo, rd));
    Shade acc = Shade(vec3(0.), vec3(0.));
    for(int i = 0; i < 4; i++){
        vec3 rs = camRay(q + ssOffset(i, 2) / iResolution.y);
        Shade s = shadeScene(gRo, rs, sceneTrace(gRo, rs));
        acc.base += s.base * 0.25;
        acc.light += s.light * 0.25;
    }
    return acc;
}

float roomDepth(vec2 q){
    setupRoom();
    return sceneTrace(gRo, camRay(q)).t;
}

vec2 roomUV(vec2 q){
    vec2 fc = q * iResolution.y + 0.5 * iResolution.xy;
    return vec2(fc.x, iResolution.y - fc.y) / iResolution.xy;
}

vec3 shadowPlay(vec2 q, vec2 tp){
    vec2 uv = roomUV(q);
    vec4 st = texture(iChannel3, uv);
    vec3 li = texture(iChannel4, uv).rgb;
    vec3 col = st.rgb + bgNoise(tp);
    if(max(li.r, max(li.g, li.b)) < 1e-4) return col;
    setupCamera();
    vec3 p = gRo + camRay(q) * st.a;
    vec3 tl = gLight - p;
    float dist = length(tl);
    vec3 ld = tl / dist;
    gFarPad = 0.;
    float sh = solidShadow(gAmpMi * (p + ld * 0.004 - gAmpPos), gAmpMi * ld, dist, SHADOW_K, SHADOW_STEPS);
    gFarPad = SDF_RANGE;
    return col + li * sh;
}
const float PEN_FILL      = 0.82;
const float PEN_LINE      = 0.0011;
const vec3  PEN_LINE_COL  = vec3(0.7);
const vec3  PEN_HOR_COL   = vec3(0.7);
const vec3  PEN_SING_COL  = vec3(0.7);
const vec3  PEN_GRID_COL  = vec3(0.7);
const float PEN_GRID_A    = 0.22;
const float PEN_GRID_W    = 0.0005;
const float PEN_GRID_R    = 0.5;
const float PEN_GRID_T    = 0.5;
const vec2  PEN_GRID_FADE = vec2(1., 3.);
const vec3  PEN_EXT_FILL  = vec3(0.012);
const vec3  PEN_BH_FILL   = vec3(0.);
const vec3  PEN_WH_FILL   = vec3(0.006);
const float PEN_ZIG       = 0.045;
const float PEN_ZIG_N     = 22.;
const int   PEN_AMPS      = 15;
const float PEN_SWEEP     = 100.;
const float PEN_AMP       = 0.026;
const float PEN_SPAGHETTI = 1.5;
const float PEN_PATH      = 0.0009;
const float PEN_TRAIL_A   = 0.6;
const float PEN_TRAIL_T   = 0.25;
const int   PEN_TRAIL_N   = 16;
const float PEN_EDGE_FADE = 0.08;
const float PEN_FLAME_LEN = 0.9;
const float PEN_FLAME_W   = 0.2;
const vec3  PEN_FLAME_HOT = vec3(1., 0.95, 0.8);
const vec3  PEN_FLAME_COL = vec3(1., 0.55, 0.15);
const vec3  PEN_FLAME_TIP = vec3(0.7, 0.15, 0.05);
const float PEN_SMOKE_LEN = 2.5;
const float PEN_SMOKE_W   = 0.5;
const vec3  PEN_SMOKE_COL = vec3(0.35);
const float PEN_SMOKE_A   = 0.5;
const vec3  PEN_PHOTON_COL = vec3(1.7, 1.2, 0.45);
const float PEN_PHOTON_W  = 0.0009;
const float PEN_WAVE_LEN  = 0.035;
const float PEN_WAVE_A    = 0.0035;
const float PEN_WAVE_L    = 0.011;
const float PEN_WAVE_SPEED = 4.;
const float PEN_GAMMA     = 0.03;
const float PEN_GAMMA_GAP = 0.009;

const vec3  PEN_LABEL_COL = vec3(0.7);
const float PEN_LABEL     = 0.055;
const float PEN_LABEL_GAP = 0.035;
const float PEN_LABEL_RANGE = 0.25;
const float PEN_MARGIN    = 0.13;
const float PEN_ER_R      = 0.009;

const float PEN_PI = 3.14159265;
const float PEN_H  = 1.5707963;

vec3 penHover(float R, float t){
    float a = sqrt(R - 1.);
    return vec3(atan(-a * exp((R - t) * 0.5)), atan(a * exp((R + t) * 0.5)), R);
}

vec3 penCycloid(float R, float e){
    float a = sqrt(R - 1.);
    float r = 0.5 * R * (1. + cos(e));
    float B = a * (e + 0.5 * R * (e + sin(e)));
    float U = (sin(e * 0.5) - a * cos(e * 0.5)) * exp((r - B) * 0.5);
    float V = (sin(e * 0.5) + a * cos(e * 0.5)) * exp((r + B) * 0.5);
    return vec3(atan(U), atan(V), r);
}

vec3 penDive(float t){
    float rs = -2.6 + 0.85 * sqrt(1. + t * t);
    return vec3(atan(-exp((rs - t) * 0.5)), atan(exp((rs + t) * 0.5)), 2.);
}

vec3 penHyperbolic(float E, float s, float u0){
    float k = E * E - 1.;
    float u = u0, ds = s / 16.;
    for(int i = 0; i < 16; i++){
        float x = (float(i) + 0.5) * ds;
        float rd = sqrt(k + 1. / max(x * x, 1e-6));
        u += 2. * x / (rd * (E + rd)) * ds;
    }
    float r = s * s;
    float U = -exp(-u * 0.5);
    return vec3(atan(U), atan((1. - r) * exp(r) / U), r);
}

vec3 penThroat(float p){
    float w = tan(p) * tan(p);
    float r = 1. - w;
    for(int i = 0; i < 6; i++) r = clamp(r + ((1. - r) - w * exp(-r)) / max(r, 1e-3), 1e-3, 1.);
    return vec3(p, p, r);
}

vec3 penParabolic(float s, float t0){
    float r = s * s, c = 2. / 3. * r * s + 2. * s;
    float U = -(s - 1.) * exp((r + c - t0) * 0.5);
    float V = (s + 1.) * exp((r - c + t0) * 0.5);
    return vec3(atan(U), atan(V), r);
}

bool penPhoton(int i){ return i >= 12; }
vec2 penPhotonDir(int i){ return i == 14 ? vec2(-0.7071, 0.7071) : vec2(0.7071); }

bool penRocket(int i){ return i == 0 || i == 4 || i == 6; }

vec3 penExhaust(vec3 col, vec2 p, float seed, float vis){
    float y = -0.5 - p.y;
    if(y < 0. || y > PEN_FLAME_LEN + PEN_SMOKE_LEN || abs(p.x) > PEN_SMOKE_W * 1.5) return col;
    float n = texture(iChannel1, fract(vec2(p.x * 0.35 + seed * 0.37, y * 0.25 - iTime * 1.7))).r;
    float n2 = texture(iChannel1, fract(vec2(p.x * 0.2 + seed * 0.71, y * 0.12 - iTime * 0.35))).r;
    float L = PEN_FLAME_LEN * (0.85 + 0.3 * n);
    float f = clamp(y / L, 0., 1.);
    float w = PEN_FLAME_W * pow(1. - f, 0.6) * smoothstep(0., 0.08, y);
    float flame = (1. - smoothstep(w * 0.4, w, abs(p.x))) * (1. - f);
    vec3 fc = mix(PEN_FLAME_HOT, PEN_FLAME_COL, smoothstep(0., 0.5, f + abs(p.x) / max(w, 1e-3) * 0.4));
    fc = mix(fc, PEN_FLAME_TIP, smoothstep(0.5, 1., f));
    float sy = y - PEN_FLAME_LEN * 0.6;
    float sw = PEN_SMOKE_W * (0.3 + sy / PEN_SMOKE_LEN);
    float smoke = sy > 0. ? (1. - smoothstep(sw * 0.3, sw, abs(p.x + (n2 - 0.5) * 0.3 * sy)))
                          * (1. - smoothstep(0., PEN_SMOKE_LEN, sy)) * smoothstep(0.35, 0.75, n2) : 0.;
    col = mix(col, PEN_SMOKE_COL, smoke * PEN_SMOKE_A * vis);
    return col + fc * flame * vis;
}

vec3 penPath(int i, float u){
    vec3 w;
    if(i == 0) w = penHover(1.6, 2. * atanh(clamp(2. * u - 1., -0.99999, 0.99999)));
    else if(i == 1) w = penCycloid(2.4, mix(-PEN_PI, PEN_PI, u));
    else if(i == 2){ w = penParabolic(3.8 * pow(u, 1.5), -0.6); w.xy = -w.yx; }
    else if(i == 3){ w = penParabolic(3.8 * pow(1. - u, 1.5), 0.4); w.xy = w.yx; }
    else if(i == 4){ w = penHover(2.6, 2. * atanh(clamp(2. * u - 1., -0.99999, 0.99999))); w.xy = w.yx; }
    else if(i == 5){ w = penCycloid(1.7, mix(-PEN_PI, PEN_PI, u)); w.xy = w.yx; }
    else if(i == 6){ w = penDive(2.5 * atanh(clamp(2. * u - 1., -0.99999, 0.99999))); w.xy = w.yx; }
    else if(i == 7){ w = penHyperbolic(1.4, 5.5 * pow(u, 1.3), 0.); w.xy = w.yx; }
    else if(i == 8){ w = penHyperbolic(1.4, 5.5 * pow(1. - u, 1.3), 0.); w.xy = -w.yx; }
    else if(i == 9) w = penThroat(mix(-0.249, 0.249, u) * PEN_PI);
    else if(i == 10) w = penHyperbolic(3., 3. * u, 0.8);
    else if(i == 11){ w = penHyperbolic(8., 3. * u, -0.6); w.xy = w.yx; }
    else if(i == 12) w = vec3(-0.5, mix(-PEN_H + 0.5, PEN_H, u), 2.);
    else if(i == 13) w = vec3(0.6, mix(-PEN_H, PEN_H - 0.6, u), 2.);
    else w = vec3(mix(-PEN_H, PEN_H - 0.4, u), 0.4, 2.);
    return w;
}

vec2 penXT(vec2 pq){ return vec2(pq.y - pq.x, pq.y + pq.x); }

float penLabel(vec2 q, vec2 at, int i, float size){
    vec2 p = (q - at) / size;
    if(abs(p.x) > 1. || abs(p.y) > 0.5) return 1e9;
    vec2 uv = (vec2(i % 4, i / 4) + vec2(p.x * 0.5 + 0.5, 0.5 - p.y)) / vec2(4., 2.);
    return (texture(iChannel5, uv).r - 0.5) * PEN_LABEL_RANGE * size;
}

float penLabels(vec2 q, float k){
    float g = PEN_LABEL_GAP, s = 0.7071;
    float d = 1e9;
    for(int side = 0; side < 2; side++){
        float sx = side == 0 ? 1. : -1.;
        d = min(d, penLabel(q, vec2(sx * 0.75 * PEN_PI, 0.25 * PEN_PI) * k + vec2(sx, 1.) * s * g * 1.3, 0, PEN_LABEL));
        d = min(d, penLabel(q, vec2(sx * 0.75 * PEN_PI, -0.25 * PEN_PI) * k + vec2(sx, -1.) * s * g * 1.3, 1, PEN_LABEL));
        d = min(d, penLabel(q, vec2(sx * PEN_H, PEN_H) * k + vec2(sx * 1.1, 0.7) * g, 2, PEN_LABEL));
        d = min(d, penLabel(q, vec2(sx * PEN_H, -PEN_H) * k + vec2(sx * 1.1, -0.7) * g, 3, PEN_LABEL));
        d = min(d, penLabel(q, vec2(sx * PEN_PI, 0.) * k + vec2(sx * 1.4, 0.) * g, 4, PEN_LABEL));
        d = min(d, penLabel(q, vec2(0., sx * PEN_H) * k + vec2(0., sx * 1.1) * g, 5, PEN_LABEL));
    }
    return d;
}

float penZigzag(vec2 d, float y0){
    float w = PEN_PI / PEN_ZIG_N;
    float i = floor((d.x + PEN_H) / w);
    float best = 1e9;
    for(int k = -1; k <= 1; k++){
        float j = clamp(i + float(k), 0., PEN_ZIG_N - 1.);
        float x0 = -PEN_H + j * w;
        float sg = mod(j, 2.) < 0.5 ? 1. : -1.;
        vec2 a = vec2(x0, y0), m = vec2(x0 + 0.5 * w, y0 + sg * PEN_ZIG * 0.5), b = vec2(x0 + w, y0);
        best = min(best, min(sdSegment(d, a, m), sdSegment(d, m, b)));
    }
    return best;
}

float penGrid(vec2 d, float k){
    vec2 pq = 0.5 * vec2(d.y - d.x, d.y + d.x);
    vec2 lu = log(abs(tan(pq)) + 1e-9);
    vec2 f = vec2((lu.x + lu.y) / PEN_GRID_R, (lu.y - lu.x) / PEN_GRID_T);
    vec2 s = sin(2. * pq);
    float gl = sqrt(2. * (1. / (s.x * s.x) + 1. / (s.y * s.y)));
    vec2 g = gl / vec2(PEN_GRID_R, PEN_GRID_T);
    vec2 dist = abs(fract(f + 0.5) - 0.5) / g * k;
    vec2 fade = smoothstep(PEN_GRID_FADE.x, PEN_GRID_FADE.y, k * iResolution.y / g);
    return max(S(dist.x - PEN_GRID_W) * fade.x, S(dist.y - PEN_GRID_W) * fade.y);
}

float penSolve(int i, float T){
    float lo = 0., hi = 1.;
    for(int j = 0; j < 24; j++){
        float m = 0.5 * (lo + hi);
        if(penXT(penPath(i, m).xy).y < T) lo = m; else hi = m;
    }
    return 0.5 * (lo + hi);
}

float penScale(){
    return min(PEN_FILL / PEN_PI, (iResolution.x / iResolution.y - 2. * PEN_MARGIN) / (2. * PEN_PI));
}

vec4 penroseStatic(vec2 q){
    float k = penScale();
    vec2 d = q / k;
    vec3 col = vec3(0.);
    float a = 0.;
    if(abs(d.y) < PEN_H && abs(d.x) + abs(d.y) < PEN_PI){
        col += d.y > abs(d.x) ? PEN_BH_FILL : d.y < -abs(d.x) ? PEN_WH_FILL : PEN_EXT_FILL;
        float g = penGrid(d, k) * PEN_GRID_A;
        col = mix(col, PEN_GRID_COL, g);
        a = g;
    }
    vec2 H = vec2(PEN_H);
    float outer = min(min(sdSegment(d, H, vec2(PEN_PI, 0.)), sdSegment(d, vec2(PEN_PI, 0.), H * vec2(1., -1.))),
                      min(sdSegment(d, H * vec2(-1., 1.), vec2(-PEN_PI, 0.)), sdSegment(d, vec2(-PEN_PI, 0.), -H)));
    float hor = min(sdSegment(d, -H, H), sdSegment(d, H * vec2(-1., 1.), H * vec2(1., -1.)));
    float sing = min(penZigzag(d, PEN_H), penZigzag(d, -PEN_H));
    float lo = S(outer * k - PEN_LINE), lh = S(hor * k - PEN_LINE), ls = S(sing * k - PEN_LINE), ll = S(penLabels(q, k));
    col = mix(col, PEN_LINE_COL, lo);
    col = mix(col, PEN_HOR_COL, lh);
    col = mix(col, PEN_SING_COL, ls);
    col = mix(col, PEN_LABEL_COL, ll);
    float er = length(q) - PEN_ER_R;
    float ein = S(er), ering = S(abs(er) - PEN_LINE);
    col = mix(mix(col, vec3(0.), ein), PEN_LINE_COL, ering);
    ll = max(ll, ering);
    a *= 1. - ein;
    lo *= 1. - ein;
    lh *= 1. - ein;
    ls *= 1. - ein;
    return vec4(col, max(a, max(max(lo, lh), max(ls, ll))));
}

vec4 penState(int i, int j){
    if(i >= PEN_AMPS || j > PEN_TRAIL_N) return vec4(0., 0., 0., -1.);
    vec2 a = penXT(penPath(i, 0.).xy), b = penXT(penPath(i, 1.).xy);
    float Tn = mix(-PEN_H, PEN_H, fract(iTime / PEN_SWEEP + fract(float(i) * 0.618034)));
    if(Tn <= a.y || Tn >= b.y) return vec4(0., 0., 0., -1.);
    vec3 w = penPath(i, penSolve(i, max(Tn - float(j) / float(PEN_TRAIL_N) * PEN_TRAIL_T, a.y)));
    vec2 c = penXT(w.xy);
    return vec4(w, smoothstep(0., PEN_EDGE_FADE, length(c - a)) * smoothstep(0., PEN_EDGE_FADE, length(c - b)));
}

vec3 penrose(vec2 q, vec2 tp){
    float k = penScale();
    vec4 st = texture(iChannel6, roomUV(q));
    vec3 col = bgNoise(tp) * (1. - st.a) + st.rgb;
    vec2 d = q / k;
    for(int i = 0; i < PEN_AMPS; i++){
        vec4 h = texelFetch(iChannel7, ivec2(0, i), 0);
        if(h.w < 0.) continue;
        vec3 w = h.xyz;
        vec2 c = penXT(w.xy);
        float vis = h.w;
        if(length(d - c) * k > 0.15) continue;
        if(penPhoton(i)){
            vec2 dir = penPhotonDir(i), nrm = vec2(-dir.y, dir.x);
            vec2 rel = q - c * k;
            float a = -dot(rel, dir), b = dot(rel, nrm);
            bool inside = abs(d.y) < PEN_H + 0.01 && abs(d.x) + abs(d.y) < PEN_PI + 0.01;
            if(inside && a > -0.01 && a < PEN_GAMMA_GAP + PEN_WAVE_LEN + 0.01){
                float env = smoothstep(PEN_GAMMA_GAP, PEN_GAMMA_GAP + 0.004, a) * smoothstep(PEN_GAMMA_GAP + PEN_WAVE_LEN, PEN_GAMMA_GAP + PEN_WAVE_LEN * 0.6, a);
                float ph = 6.2831853 * a / PEN_WAVE_L + iTime * PEN_WAVE_SPEED;
                float y = PEN_WAVE_A * env * sin(ph);
                float dy = PEN_WAVE_A * env * cos(ph) * 6.2831853 / PEN_WAVE_L;
                col = mix(col, PEN_PHOTON_COL, S(abs(b - y) / sqrt(1. + dy * dy) - PEN_PHOTON_W) * env * vis);
            }
            vec2 ga = c * k;
            col = mix(col, PEN_PHOTON_COL, S(penLabel(q, ga, 6, PEN_GAMMA)) * vis);
            continue;
        }
        float tr = 1e9, ta = 0.;
        vec2 prev = c;
        for(int j = 1; j <= PEN_TRAIL_N; j++){
            float f = float(j) / float(PEN_TRAIL_N);
            vec2 cur = penXT(texelFetch(iChannel7, ivec2(j, i), 0).xy);
            float sd = sdSegment(d, prev, cur);
            if(sd < tr){ tr = sd; ta = 1. - f; }
            prev = cur;
        }
        col = mix(col, ampGradient(vec2(0., 0.5)), S(tr * k - PEN_PATH * 1.4) * PEN_TRAIL_A * ta * vis);
        vec2 gp = (q - c * k) / PEN_AMP;
        if(penRocket(i)){
            vec2 sp = sin(2. * w.xy);
            vec2 dir = normalize(vec2(sp.y - sp.x, sp.y + sp.x));
            gp = vec2(dot(gp, vec2(dir.y, -dir.x)), dot(gp, dir));
            col = penExhaust(col, gp, float(i), vis);
        }
        float s = w.z < 1. ? (1. - w.z) * (1. - w.z) * PEN_SPAGHETTI : 0.;
        gp *= vec2(1. + s, 1. / (1. + s));
        col = mix(col, ampGradient(gp), S(glyphDist(gp) * PEN_AMP / (1. + s)) * vis);
    }
    return col;
}
// --- scope: XY oscilloscope tracing the amp outline ---------------------------
// iChannel8: beam path (gen_scope.py), iChannel9: phosphor feedback buffer
// (bufferScope: R = fast decay, G = slow decay, A = time of the last frame)
const vec3  SCOPE_HOT      = vec3(0.85, 0.97, 1.);
const float SCOPE_H        = 0.84;
const vec3  SCOPE_GRID_COL = vec3(0.7);
const float SCOPE_GRID_A   = 0.15;
const float SCOPE_GRID_W   = 0.0006;
const float SCOPE_TICK     = 0.008;
const float SCOPE_AMP      = 0.7;
const vec2  SCOPE_CENTER   = vec2(-0.02, 0.01);
const float SCOPE_LOOP     = 6.;
const float SCOPE_BEAM_W   = 0.0011;
const float SCOPE_GAIN     = 1.4;
const float SCOPE_FAST_T   = 0.15;
const float SCOPE_SLOW_T   = 2.2;
const float SCOPE_FAST_A   = 1.;
const float SCOPE_SLOW_A   = 0.7;
const float SCOPE_GLOW     = 1.5;
const float SCOPE_RETRACE  = 0.05;
const float SCOPE_NOISE    = 0.0004;
const float SCOPE_CYCLE    = 60.;
const float SCOPE_LISS_AT  = 36.;
const float SCOPE_MORPH    = 4.;
const vec2  SCOPE_LISS     = vec2(3., 2.);
const vec2  SCOPE_LISS_A   = vec2(0.36, 0.3);
const float SCOPE_LISS_DRIFT = 0.15;
const int   SCOPE_N        = 1024;
const int   SCOPE_STEPS    = 32;

vec3 scopeVertex(int i){
    i = i % SCOPE_N;
    vec3 a = round(texelFetch(iChannel8, ivec2(i, 0), 0).rgb * 255.);
    vec3 b = round(texelFetch(iChannel8, ivec2(i, 1), 0).rgb * 255.);
    vec2 v = vec2(a.r * 256. + a.g, b.r * 256. + b.g) / 65535. * 2. * SDF_BOX - SDF_BOX;
    return vec3(v, a.b > 127. ? 1. : 0.);
}

// beam position (screen space) and lit flag at time t
vec3 scopeBeam(float t){
    float s = mod(t, SCOPE_LOOP) / SCOPE_LOOP;
    float fi = s * float(SCOPE_N);
    int i = int(fi);
    vec3 a = scopeVertex(i), b = scopeVertex(i + 1);
    vec2 amp = (mix(a.xy, b.xy, fi - float(i)) - SCOPE_CENTER) * SCOPE_AMP;
    float ph = 6.2831853 * s;
    vec2 liss = SCOPE_LISS_A * sin(SCOPE_LISS * ph + vec2(t * SCOPE_LISS_DRIFT, 0.));
    float c = mod(t, SCOPE_CYCLE);
    float m = smoothstep(SCOPE_LISS_AT, SCOPE_LISS_AT + SCOPE_MORPH, c)
            * (1. - smoothstep(SCOPE_CYCLE - SCOPE_MORPH, SCOPE_CYCLE, c));
    m = cubicInOut(m);
    vec2 n = SCOPE_NOISE * vec2(sin(t * 23.1 + 2. * sin(t * 7.3)), cos(t * 19.7 + 2. * sin(t * 5.9)));
    vec2 p = mix(amp, liss, m) + n;
    return vec3(p, mix(mix(SCOPE_RETRACE, 1., a.z), 1., m));
}

// phosphor energy deposited at q by the beam between t0 and t1; segment
// bodies only (no caps) so consecutive segments tile without beading
vec2 scopeDeposit(vec2 q, float t0, float t1){
    float dt = t1 - t0;
    if(dt <= 0.) return vec2(0.);
    int n = clamp(int(ceil(dt / SCOPE_LOOP * float(SCOPE_N) * 1.5)) + 1, 1, SCOPE_STEPS);
    float h = dt / float(n);
    vec3 a = scopeBeam(t0);
    float speed = 5.8 * SCOPE_AMP / SCOPE_LOOP;
    float e = 0.;
    for(int k = 1; k <= SCOPE_STEPS; k++){
        if(k > n) break;
        vec3 b = scopeBeam(t0 + h * float(k));
        vec2 ab = b.xy - a.xy, aq = q - a.xy;
        float L2 = dot(ab, ab);
        float u = L2 > 0. ? dot(aq, ab) / L2 : 0.;
        if(u >= 0. && u < 1.){
            float d = length(aq - ab * u);
            float L = max(sqrt(L2), SCOPE_BEAM_W);
            float age = t1 - (t0 + h * (float(k) - 1. + u));
            e += a.z * h * speed / L * exp(-0.5 * d * d / (SCOPE_BEAM_W * SCOPE_BEAM_W)) * exp(-age / SCOPE_FAST_T);
        }
        a = b;
    }
    return SCOPE_GAIN * vec2(e);
}

vec4 scopePhosphor(vec2 q, vec4 prev){
    float t1 = iTime;
    if(abs(t1 - prev.a) > 0.5) prev.rg = vec2(0.);
    float dt = clamp(t1 - prev.a, 0., 0.1);
    vec2 e = prev.rg * exp(-dt / vec2(SCOPE_FAST_T, SCOPE_SLOW_T));
    e += scopeDeposit(q, t1 - dt, t1);
    return vec4(e, 0., t1);
}

vec2 scopeGlow(vec2 uv, float lod){
    vec2 px = exp2(lod) / vec2(textureSize(iChannel9, 0));
    vec2 g = vec2(0.);
    for(int i = 0; i < 6; i++){
        float a = float(i) * 1.0471976;
        g += textureLod(iChannel9, uv + px * 0.9 * vec2(cos(a), sin(a)), lod).rg;
    }
    return g / 6.;
}

float scopeGrid(vec2 q){
    float div = SCOPE_H / 8.;
    vec2 g = abs(fract(q / div + 0.5) - 0.5) * div;
    float d = min(g.x, g.y);
    vec2 m = abs(fract(q / (div * 0.2) + 0.5) - 0.5) * div * 0.2;
    float ax = min(max(abs(q.y) - SCOPE_TICK, m.x), max(abs(q.x) - SCOPE_TICK, m.y));
    d = min(d, ax);
    return S(d - SCOPE_GRID_W);
}

vec3 scope(vec2 q, vec2 tp){
    vec3 col = solidBg(q, tp);
    col = mix(col, SCOPE_GRID_COL, scopeGrid(q) * SCOPE_GRID_A);

    vec2 uv = roomUV(q);
    vec2 e = textureLod(iChannel9, uv, 0.).rg;
    vec2 g = 0.6 * scopeGlow(uv, 2.5) + 0.4 * scopeGlow(uv, 4.5);
    vec2 wa = vec2(SCOPE_FAST_A, SCOPE_SLOW_A);
    float I = dot(e, wa);
    float G = dot(g, wa) * SCOPE_GLOW;
    vec3 light = (1. - exp(-(I + G) * ampGradient(q / SCOPE_AMP + SCOPE_CENTER) * 1.6));
    light = mix(light, SCOPE_HOT, smoothstep(0.8, 2.5, I));
    return col + light;
}
// --- spectrum: spectrogram waterfall with the amp hidden in the signal ---------
// frequency runs left to right, time scrolls down from the live spectrum strip
// at the top; every cell is a pure function of (bin, frame), so rows scroll
// without a feedback buffer. Every SPEC_PERIOD the amp is transmitted, one
// glyph row per frame, so it builds up under the strip and scrolls away.
const int   SPEC_BINS      = 320;
const float SPEC_SPEED     = 0.03;
const float SPEC_ROW       = 0.004;
const float SPEC_STRIP     = 0.16;
const float SPEC_STRIP_H   = 0.11;
const float SPEC_LO        = -1.5;
const float SPEC_HI        = 5.;
const float SPEC_TILT      = 2.;
const float SPEC_CARRIER   = 25.;
const float SPEC_VOICE     = 60.;
const float SPEC_CHIRP     = 30.;
const float SPEC_CLICK     = 8.;
const float SPEC_GLYPH     = 45.;
const float SPEC_LEAK      = 0.005;
const float SPEC_PERIOD    = 50.;
const float SPEC_GLYPH_AT  = 4.;
const float SPEC_GLYPH_DUR = 18.;
const vec3  SPEC_GRID_COL  = vec3(0.7);

float specFps(){ return SPEC_SPEED / SPEC_ROW; }

float specLine(float f, float fc, float w){
    float x = (f - fc) * float(SPEC_BINS) / w;
    return exp(-x * x);
}

float specPower(int bin, int frame){
    float f = (float(bin) + 0.5) / float(SPEC_BINS);
    float t = (float(frame) + 0.5) / specFps();
    uint ub = uint(bin), uf = uint(frame);
    float P = -log(max(pcgHash(uvec3(ub, uf, 7u)), 1e-4)) * (1. + SPEC_TILT * exp(-f * 6.));

    for(int k = 0; k < 4; k++){
        float fk = 0.18 + 0.21 * float(k) + 0.004 * sin(t * (0.13 + 0.05 * float(k)) + float(k) * 2.1);
        float on = smoothstep(-0.2, 0.2, sin(t * (0.021 + 0.013 * float(k)) + float(k) * 1.7));
        P += SPEC_CARRIER * on * (0.5 + 0.5 * float(k & 1)) * specLine(f, fk, 0.9);
    }

    float f0 = 0.022 + 0.003 * sin(t * 0.7) + 0.0015 * sin(t * 1.9);
    float syl = smoothstep(0., 0.3, sin(t * 0.9) * sin(t * 0.23 + 1.)) * smoothstep(0.3, 0.6, sin(t * 0.05));
    if(syl > 0.) for(int h = 1; h <= 12; h++)
        P += syl * SPEC_VOICE / float(h) * specLine(f, f0 * float(h), 1.);

    float tc = mod(t, 29.);
    if(tc < 8.) P += SPEC_CHIRP * smoothstep(0., 1., tc) * smoothstep(8., 7., tc) * specLine(f, 0.52 + 0.012 * tc + 0.0035 * tc * tc, 1.6);

    float ck = pcgHash(uvec3(uf, 3u, 9u));
    if(ck < 0.012) P += SPEC_CLICK * (0.5 + 50. * ck) * exp(-f * 2.5);

    float occ = floor(t / SPEC_PERIOD);
    float tl = t - occ * SPEC_PERIOD - SPEC_GLYPH_AT;
    if(tl > 0. && tl < SPEC_GLYPH_DUR){
        float sc = SPEC_SPEED * SPEC_GLYPH_DUR;
        float fc = 0.5 + 0.3 * (pcgHash(uvec3(uint(int(occ)), 5u, 11u)) - 0.5);
        float asp = iResolution.x / iResolution.y;
        vec2 g = vec2((f - fc) * asp / sc, tl / SPEC_GLYPH_DUR - 0.5);
        float d = glyphDist(g);
        float tex = 0.6 + 0.8 * pcgHash(uvec3(ub, uf, 13u));
        P += SPEC_GLYPH * tex * (d < 0. ? 1. : exp(-d / SPEC_LEAK));
    }
    return P;
}

float specLevel(float P){ return clamp((log(P) - SPEC_LO) / (SPEC_HI - SPEC_LO), 0., 1.); }

// bilinear between the four (bin, frame) cells around (fb, ff)
float specAt(float fb, float ff){
    vec2 c = vec2(fb, ff) - 0.5;
    ivec2 i = ivec2(floor(c));
    vec2 w = c - vec2(i);
    float a = specLevel(specPower(i.x, i.y)), b = specLevel(specPower(i.x + 1, i.y));
    float e = specLevel(specPower(i.x, i.y + 1)), d = specLevel(specPower(i.x + 1, i.y + 1));
    return mix(mix(a, b, w.x), mix(e, d, w.x), w.y);
}

vec3 specMap(float v){
    vec3 c = mix(vec3(0.004, 0.008, 0.012), GRAD_BOT * 0.18, smoothstep(0., 0.4, v));
    c = mix(c, GRAD_BOT * 0.8, smoothstep(0.35, 0.7, v));
    c = mix(c, GRAD_TOP * 1.15, smoothstep(0.62, 0.85, v));
    return mix(c, vec3(0.92, 1., 1.), smoothstep(0.82, 1., v));
}

vec3 spectrum(vec2 q, vec2 tp){
    float asp = iResolution.x / iResolution.y;
    float fb = (q.x / asp + 0.5) * float(SPEC_BINS);
    float top = 0.5 - SPEC_STRIP;
    float now = iTime * specFps();
    if(q.y < top){
        float ff = now - (top - q.y) / SPEC_ROW;
        return specMap(specAt(fb, ff));
    }

    vec3 col = specMap(0.);
    float px = 1. / iResolution.y;
    float dfb = float(SPEC_BINS) / asp * px;
    float base = top + 0.012;
    float v0 = specAt(fb, now), v1 = specAt(fb + dfb, now);
    float y = base + v0 * SPEC_STRIP_H;
    float slope = (v1 - v0) * SPEC_STRIP_H / px;
    float d = (q.y - y) / sqrt(1. + slope * slope);
    col = mix(col, GRAD_BOT * 0.25, step(q.y, y) * step(base, q.y));
    col = mix(col, GRAD_TOP, S(abs(d) - 0.0008));

    float tick = abs(fract(fb / float(SPEC_BINS) * 20. + 0.5) - 0.5) * asp / 20.;
    float major = abs(fract(fb / float(SPEC_BINS) * 4. + 0.5) - 0.5) * asp / 4.;
    float tk = max(S(tick - 0.0005) * step(q.y, top + 0.006), S(major - 0.0005) * step(q.y, top + 0.012));
    col = mix(col, SPEC_GRID_COL, 0.35 * max(tk, S(abs(q.y - top) - 0.0005)));
    return col;
}
// --- prism: white light dispersed through an amp-shaped glass prism -----------
// the beam is rolled per session by scene.qml (u_prism_ray: glyph-space start
// xy, angle z), from the left half of the screen through the centre with some
// jitter; u_prism_beam (x = height, y = tilt) offsets it from the preview panel. bufferPrismState traces PRISM_RAYS wavelengths through the
// glyph SDF (Snell at every edge, total internal reflection where it happens)
// into iChannel8 (prismTexel(ray, j) = j-th path point in glyph space, xy),
// w = 1 while the path goes on. bufferPrismLight sums the spectral rays
// additively (where they overlap they add back up to white) into a linear
// light buffer, PRISM_CHUNK rays per update (u_prism_chunk, driven by
// scene.qml) accumulated over its own previous output in iChannel9, only
// when the beam moves; the main pass tonemaps it from iChannel8.
const int   PRISM_RAYS     = 20000;
const int   PRISM_ROW      = 125;
const int   PRISM_CHUNK    = 48;
const int   PRISM_PTS      = 10;

// state texel of path point j of ray i: PRISM_ROW rays side by side per row
ivec2 prismTexel(int i, int j){ return ivec2((i % PRISM_ROW) * PRISM_PTS + j, i / PRISM_ROW); }
const float PRISM_SCALE    = 0.5;
const vec2  PRISM_CENTER   = vec2(0.05, 0.);
const float PRISM_N        = 1.5;
const float PRISM_DISP     = 0.12;
const float PRISM_BEAM_W   = 0.0018;
const float PRISM_SPREAD   = 0.02;
const float PRISM_GLOW     = 0.35;
const float PRISM_GAIN     = 3.2;
const vec3  PRISM_LINE_COL = vec3(0.7);
const float PRISM_LINE_W   = 0.0024;
const float PRISM_EDGE_W   = 0.014;
const float PRISM_EDGE_A   = 0.55;

float prismLambda(int i){ return mix(400., 700., (float(i) + 0.5) / float(PRISM_RAYS)); }

vec3 prismBump(vec3 x, vec3 y){ return clamp(1. - x * x - y, 0., 1.); }

// Zucconi's 6-bump fit of the visible spectrum
vec3 prismSpectral(float w){
    float x = clamp((w - 400.) / 300., 0., 1.);
    return prismBump(vec3(3.54585104, 2.93225262, 2.41593945) * (x - vec3(0.69549072, 0.49228336, 0.27699880)), vec3(0.02312639, 0.15225084, 0.52607955))
         + prismBump(vec3(3.90307140, 3.21182957, 3.96587128) * (x - vec3(0.11748627, 0.86755042, 0.66077860)), vec3(0.84897130, 0.88445281, 0.73949448));
}

vec2 prismNormal(vec2 p){
    vec2 e = vec2(0.002, 0.);
    return normalize(vec2(glyphDist(p + e.xy) - glyphDist(p - e.xy), glyphDist(p + e.yx) - glyphDist(p - e.yx)));
}

vec4 prismState(int i, int j){
    if(i >= PRISM_RAYS || j >= PRISM_PTS) return vec4(0.);
    gFarPad = 0.;
    float ang = u_prism_ray.z + u_prism_beam.y;
    vec2 p = u_prism_ray.xy + vec2(0., u_prism_beam.x), d = vec2(cos(ang), sin(ang));
    if(j == 0) return vec4(p, 0., 1.);
    float n = PRISM_N + PRISM_DISP * (pow(550. / prismLambda(i), 2.) - 1.);
    bool inside = false;
    for(int k = 1; k < PRISM_PTS; k++){
        bool hit = false;
        for(int s = 0; s < 128; s++){
            float g = glyphDist(p);
            float dist = inside ? -g : g;
            if(dist < 0.0004){ hit = true; break; }
            if(length(p) > 3.) break;
            p += d * max(dist * 0.9, 0.0008);
        }
        if(!hit) return k == j ? vec4(p + d * 3., 0., 1.) : vec4(0.);
        vec2 nrm = prismNormal(p);
        vec2 nf = dot(d, nrm) < 0. ? nrm : -nrm;
        vec2 r = refract(d, nf, inside ? n : 1. / n);
        if(dot(r, r) < 1e-6) d = reflect(d, nf);
        else { d = r; inside = !inside; }
        if(k == j) return vec4(p, inside ? 1. : 0., 1.);
        p += d * 0.004;
    }
    return vec4(0.);
}

// linear light of rays [i0, i0 + PRISM_CHUNK)
vec3 prismLight(vec2 q, int i0){
    vec3 norm = vec3(0.);
    for(int i = 0; i < 96; i++) norm += prismSpectral(mix(400., 700., (float(i) + 0.5) / 96.));
    norm *= float(PRISM_RAYS) / 96.;

    vec3 light = vec3(0.);
    for(int i = i0; i < i0 + PRISM_CHUNK; i++){
        if(i >= PRISM_RAYS) break;
        vec3 c = prismSpectral(prismLambda(i)) / norm;
        vec2 a = texelFetch(iChannel8, prismTexel(i, 0), 0).xy * PRISM_SCALE + PRISM_CENTER;
        float e = 0.;
        for(int j = 1; j < PRISM_PTS; j++){
            vec4 b4 = texelFetch(iChannel8, prismTexel(i, j), 0);
            if(b4.w < 0.5) break;
            vec2 b = b4.xy * PRISM_SCALE + PRISM_CENTER;
            bool last = j == PRISM_PTS - 1 || texelFetch(iChannel8, prismTexel(i, j + 1), 0).w < 0.5;
            vec2 ab = b - a;
            float h = clamp(dot(q - a, ab) / dot(ab, ab), 0., 1.);
            float dist = length(q - a - ab * h);
            float s = h * length(ab);
            float w = PRISM_BEAM_W + (last && j > 1 ? s * PRISM_SPREAD : 0.);
            float x = dist / w;
            e += sqrt(PRISM_BEAM_W / w) * (exp(-x * x) + PRISM_GLOW * exp(-dist / (w * 6.)));
            a = b;
        }
        light += c * e;
    }
    return light;
}

vec3 prism(vec2 q, vec2 tp){
    vec3 col = bgNoise(tp);
    vec2 g = (q - PRISM_CENTER) / PRISM_SCALE;
    float gd = glyphDist(g) * PRISM_SCALE;
    float band = clamp(-gd / PRISM_EDGE_W, 0., 1.);
    float fade = (1. - band) * (1. - band) * S(gd);
    float shade = mix(0.55, 1., clamp(g.y + 0.5, 0., 1.));
    col = mix(col, PRISM_LINE_COL * shade, max(fade * PRISM_EDGE_A, S(abs(gd) - PRISM_LINE_W) * 0.9));
    return col + 1. - exp(-texture(iChannel8, roomUV(q)).rgb * PRISM_GAIN);
}
void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = vec2(fragCoord.x, iResolution.y - fragCoord.y) / iResolution.xy;
    vec4 prev = textureLod(iChannel9, uv, 0.);
    vec2 q = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    sequenceModes(q);
    if(W[MODE_SCOPE] < 0.001){
        fragColor = vec4(0., 0., 0., iTime);
        return;
    }
    fragColor = scopePhosphor(q, prev);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
