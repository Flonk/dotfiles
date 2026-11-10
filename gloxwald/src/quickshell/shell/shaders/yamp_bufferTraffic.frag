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
    float u_aspect;
    vec4 u_seq;
    vec4 u_seq2;
    int u_traffic_map;
    int u_traffic_cars;
    int u_traffic_debug;
    vec4 u_clock_prev;
    float u_clock_at;
    float u_lst;
    mat4 u_planets;
    float u_algol;
    mat4 u_bodies;

    vec3 iResolution;
    vec3 u_indicator_color;

    vec4 iMouse;
    vec4 iClock;

    // 32 random floats in [0,1), rerolled by the host each time the shader
    // pass is created — read them via sk_seed(i) to vary scenes per session
    mat4 iSeed0;
    mat4 iSeed1;
};

// Up to sixteen input textures, resolved from QML properties.
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
layout(binding = 11) uniform sampler2D iChannel10;
layout(binding = 12) uniform sampler2D iChannel11;
layout(binding = 13) uniform sampler2D iChannel12;
layout(binding = 14) uniform sampler2D iChannel13;
layout(binding = 15) uniform sampler2D iChannel14;
layout(binding = 16) uniform sampler2D iChannel15;
layout(binding = 17) uniform sampler2D iChannel16;
layout(binding = 18) uniform sampler2D iChannel17;
layout(binding = 19) uniform sampler2D iChannel18;
layout(binding = 20) uniform sampler2D iChannel19;
layout(binding = 21) uniform sampler2D iChannel20;
layout(binding = 22) uniform sampler2D iChannel21;
layout(binding = 23) uniform sampler2D iChannel22;

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

// the global zoom flips on ZOOM_PERIOD, offset by half
const float TRANS_DUR   = 1.2;   // zoom flip duration
const float ZOOM_PERIOD = 60. * 8.; // seconds per zoom flip
const float ZOOM_OUT    = 0.30;  // global zoom-out amount

// during a scene a bar PROGRESS_H px tall along the bottom edge shrinks towards
// the next transition
const float PROGRESS_H  = 2.;
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
// modes are scenes (MODE_DUR D) or transitions (flap, shatter: short, one
// cycle each, on their own clock, carrying the handover from the scene
// before to the scene after; see the sequencer (20_modes)
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
const int MODE_GASKET   = 10;
const int MODE_GRAVITY  = 11;
const int MODE_FLUID    = 12;
const int MODE_FLAP     = 13;
const int MODE_GRID     = 14;
const int MODE_STARS    = 15;
const int MODE_SHATTER  = 16;
const int MODE_TITLE    = 17;
const int MODE_IRIS   = 18;
const int MODE_INK    = 19;
const int MODE_TYPE   = 20;
const int MODE_PEEL   = 21;
const int MODE_GLITCH = 22;
const int MODE_BLINDS = 23;
const int MODE_STAMP  = 24;
const int MODE_FISH     = 25;
const int MODE_TRAFFIC  = 26;
const int MODE_CONVEYOR = 27;
const int MODE_COUNT    = 28;

const float MODE_AA[MODE_COUNT]    = float[MODE_COUNT](0., 0., 0., 1., 1., 1., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0.);
const float MODE_GRAIN[MODE_COUNT] = float[MODE_COUNT](0., 0., 0., 0., 0., 1., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0.);

const float D = 180.;
const float T_FLAP = 10.5;
const float T_SHATTER = 9.5;
const float T_TITLE = 6.;
const float T_IRIS = 6.5;
const float T_INK = 7.0;
const float T_TYPE = 7.0;
const float T_PEEL = 7.0;
const float T_GLITCH = 6.0;
const float T_BLINDS = 7.0;
const float T_STAMP = 6.5;
// transitions all show the amp this tall, centred, and the tagline
const float TRANS_AMP = 0.546;

const float MODE_DUR[MODE_COUNT] = float[MODE_COUNT](D, D, D, D, D, D, D, D, D, D, D, D, D, T_FLAP, D, D, T_SHATTER, T_TITLE, T_IRIS, T_INK, T_TYPE, T_PEEL, T_GLITCH, T_BLINDS, T_STAMP, D, D, D);

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
// The playlist (scenes with a transition after each) is walked once a frame
// in LockContext (seqInfo), which hands over the slot playing as u_seq (mode,
// seconds into it, a number unique to this showing, the mode before) and
// u_seq2 (the mode after, how long this slot runs, how long the one before
// ran; scene lengths live in LockContext's sceneTable). Scenes cut
// straight into transitions and out of them; each transition draws the
// scene before it and the one after it (gPrevCol, gNextCol) into its own
// handover.

float W[MODE_COUNT];
// each mode's own clock (seconds since its slot began) and a number unique
// to that showing, for the transitions
float gModeT[MODE_COUNT];
float gModeK[MODE_COUNT];
float gDropStart = 0.;

// the slot playing at time (dev jumps restart the playlist at the chosen
// mode): a scene (gScene), or a transition (gTrans) between gPrev and gNext;
// every mode it touches gets its own clock in gModeT and a number unique to
// this showing in gModeK
int gScene = 0, gTrans = -1, gPrev = 0, gNext = 0;
vec3 gPrevCol = vec3(0.), gNextCol = vec3(0.);

bool isTransition(int m){ return m == MODE_FLAP || (m >= MODE_SHATTER && m <= MODE_STAMP); }

void sequenceModes(vec2 q){
    int m = int(u_seq.x + 0.5);
    float modeTime = u_seq.y, lap = u_seq.z;
    for(int i = 0; i < MODE_COUNT; i++) W[i] = 0.;
    W[m] = 1.;
    gModeT[m] = modeTime;
    gModeK[m] = lap;
    gTrans = -1;
    gScene = m;
    if(isTransition(m)){
        gTrans = m;
        gPrev = int(u_seq.w + 0.5);
        gNext = int(u_seq2.x + 0.5);
        W[gPrev] = 1.;
        W[gNext] = 1.;
        if(gPrev == MODE_DROP) gDropStart = iTime - modeTime - u_seq2.z;
        if(gNext == MODE_DROP) gDropStart = iTime - modeTime + MODE_DUR[m];
    } else if(m == MODE_DROP) gDropStart = iTime - modeTime;
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
// jitter; u_prism_beam (x = height, y = tilt) offsets it from the preview panel.
// bufferPrismState traces PRISM_RAYS wavelengths through the
// glyph SDF (Snell at every edge, total internal reflection where it happens)
// into iChannel8 (prismTexel(ray, j) = j-th path point in glyph space, xy),
// w = 1 while the path goes on. bufferPrismLight sums the spectral rays
// additively (where they overlap they add back up to white) into a linear
// light buffer, PRISM_CHUNK rays per update (u_prism_chunk, driven by
// scene.qml) accumulated over its own previous output in iChannel9, only
// when the beam moves; the main pass tonemaps it from iChannel8.
const int   PRISM_RAYS     = 4000;
const int   PRISM_ROW      = 125;
const int   PRISM_CHUNK    = 10;
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

// a single ray's line profile at signed distance s (beam width w), and its
// antiderivative in s
float prismProfile(float s, float w){
    float x = s / w;
    return sqrt(PRISM_BEAM_W / w) * (exp(-x * x) + PRISM_GLOW * exp(-abs(s) / (6. * w)));
}

float prismErf(float x){
    float x2 = x * x;
    return sign(x) * sqrt(1. - exp(-x2 * (1.2732395 + 0.147 * x2) / (1. + 0.147 * x2)));
}

float prismCum(float s, float w){
    return sqrt(PRISM_BEAM_W / w) * (0.8862269 * w * prismErf(s / w)
        + PRISM_GLOW * sign(s) * 6. * w * (1. - exp(-abs(s) / (6. * w))));
}

vec2 prismPt(vec4 p){ return p.xy * PRISM_SCALE + PRISM_CENTER; }

// linear light of rays [i0, i0 + PRISM_CHUNK). Each neighbouring pair of rays
// that takes the same route is a ribbon: the continuum of rays between them,
// i.e. the line profile averaged across the ribbon. Pairs that part ways
// (different bounces, far apart) fall back to drawing the ray as a line.
vec3 prismLight(vec2 q, int i0){
    vec3 norm = vec3(0.);
    for(int i = 0; i < 96; i++) norm += prismSpectral(mix(400., 700., (float(i) + 0.5) / 96.));
    norm *= float(PRISM_RAYS) / 96.;

    vec4 A[PRISM_PTS], B[PRISM_PTS];
    for(int j = 0; j < PRISM_PTS; j++) A[j] = texelFetch(iChannel8, prismTexel(i0, j), 0);
    vec3 light = vec3(0.);
    for(int i = i0; i < i0 + PRISM_CHUNK; i++){
        if(i >= PRISM_RAYS) break;
        bool pair = i + 1 < PRISM_RAYS;
        for(int j = 0; j < PRISM_PTS; j++) B[j] = pair ? texelFetch(iChannel8, prismTexel(i + 1, j), 0) : vec4(0.);
        vec3 cA = prismSpectral(prismLambda(i)) / norm;
        vec3 cB = pair ? prismSpectral(prismLambda(i + 1)) / norm : cA;
        for(int j = 1; j < PRISM_PTS; j++){
            if(A[j].w < 0.5) break;
            bool lastA = j == PRISM_PTS - 1 || A[j + 1].w < 0.5;
            bool lastB = j == PRISM_PTS - 1 || B[j + 1].w < 0.5;
            vec2 a0 = prismPt(A[j - 1]), a1 = prismPt(A[j]);
            vec2 b0 = prismPt(B[j - 1]), b1 = prismPt(B[j]);
            vec2 ab = a1 - a0;
            float h = clamp(dot(q - a0, ab) / dot(ab, ab), 0., 1.);
            vec2 da = q - a0 - ab * h;
            vec2 n = normalize(vec2(-ab.y, ab.x));
            float sA = length(da) * (dot(da, n) < 0. ? -1. : 1.);
            float w = PRISM_BEAM_W + (lastA && j > 1 ? h * length(ab) * PRISM_SPREAD : 0.);
            bool same = B[j].w > 0.5 && lastA == lastB && A[j - 1].z == B[j - 1].z
                && length(a0 - b0) < 0.02 && length(a1 - b1) < (lastA ? 0.3 : 0.02);
            if(!same){
                light += cA * prismProfile(sA, w);
                continue;
            }
            vec2 bb = b1 - b0;
            vec2 db = q - b0 - bb * clamp(dot(q - b0, bb) / dot(bb, bb), 0., 1.);
            float sB = length(db) * (dot(db, n) < 0. ? -1. : 1.);
            float d = sB - sA;
            float e = abs(d) < 1e-6 ? prismProfile(sA, w) : (prismCum(sB, w) - prismCum(sA, w)) / d;
            light += 0.5 * (cA + cB) * e;
        }
        for(int j = 0; j < PRISM_PTS; j++) A[j] = B[j];
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
// --- gasket: endless zoom into an inverted Apollonian gasket of amps ----------
// The gasket is a lattice of tangent circles (centres on half-integers) whose
// square gaps hold, inverted about the gap centre (p -> 0.25 p / |p|^2), the
// whole lattice again. The screen is inverted onto it too (u -> 0.1 / conj u
// + GASK_O), and GASK_O is chosen so that one level down is an exact
// anti-similar copy of the level above about the fixed point GASK_FIX: two
// levels down is the same picture scaled by GASK_ZOOM. Zooming that far into
// GASK_FIX over GASK_PERIOD and wrapping is seamless, and every circle keeps
// its screen size and place, so animation clocks keyed on those (see below)
// carry on across the wrap.
const float GASK_PERIOD = 40.;
const float GASK_INV    = 0.1;
const float GASK_O      = -0.20710678;   // (1 - sqrt 2) / 2
const float GASK_FIX    = 0.07071068;    // 0.1 / sqrt 2
const float GASK_ZOOM   = 33.970563;     // (3 + 2 sqrt 2)^2
const float GASK_VIEW   = 0.04;
const int   GASK_LEVELS = 20;
const float GASK_AMP    = 0.68;
const float GASK_PAD    = 0.;
const float GASK_RING   = 0.0025;
const vec3  GASK_RING_COL = mix(GRAD_BOT, GRAD_TOP, 0.5) * 0.5;
const vec2  GASK_FADE   = vec2(3., 200.);
const float GASK_FADE_A = 0.5;
const float GASK_CYCLES = 3.;            // amp loops per zoom period, integer
const float GASK_OFF    = 0.15;
const vec3  GASK_DEEP   = vec3(0.3);
const vec2  GASK_TINT   = vec2(4., 250.);
const vec3  GASK_LIGHT  = vec3(-0.45, 0.55, 0.7);
const float GASK_BEVEL  = 0.08;
const float GASK_BEVEL_K = 1.6;
const float GASK_SPEC   = 0.25;
const float GASK_EMBOSS = 0.6;
const float GASK_EMBOSS_D = 0.025;
const float GASK_SHADOW = 0.6;
const float GASK_SHADOW_OFF = 0.08;
const float GASK_SHADOW_SOFT = 0.06;

// circle (xy centre, z radius) inverted about the origin with factor f
vec3 gaskInvert(vec3 c, float f){
    float k = dot(c.xy, c.xy) - c.z * c.z;
    return vec3(f * c.xy / k, f * c.z / abs(k));
}

// circle (centre, radius) of level i, in level-i coordinates, mapped back up
// through every level onto the screen
vec3 gaskScreen(vec3 c, int i, vec2 gap[GASK_LEVELS], float z){
    for(int k = i - 1; k >= 0; k--){
        c = gaskInvert(c, 0.25);
        c.xy += gap[k];
    }
    c.xy -= vec2(GASK_O, 0.);
    c = gaskInvert(c, GASK_INV);
    return vec3((c.xy - vec2(GASK_FIX, 0.)) / z, c.z / z);
}

vec3 gasket(vec2 q, vec2 tp){
    float lt = iTime / GASK_PERIOD;
    float z = GASK_VIEW * pow(GASK_ZOOM, -fract(lt));
    vec2 u = vec2(GASK_FIX, 0.) + q * z;
    float uu = max(dot(u, u), 1e-12);
    vec2 p = GASK_INV * u / uu + vec2(GASK_O, 0.);
    float px = z / iResolution.y * GASK_INV / uu;
    vec3 L = normalize(GASK_LIGHT);
    vec2 sdir = -normalize(L.xy);

    vec2 gap[GASK_LEVELS];
    vec3 col = bgNoise(tp);
    float shadow = 0.;
    for(int i = 0; i < GASK_LEVELS; i++){
        vec2 cell = floor(p);
        float sqd = length(p - cell - 0.5) - 0.5 * (1. - GASK_PAD);
        // below level 0 the four circles round the origin are the parent
        // gap's bounding circles mapped onto themselves: already drawn
        bool parent = i > 0 && abs(cell.x + 0.5) < 1. && abs(cell.y + 0.5) < 1.;
        if(!parent && sqd < px * 1.3){
            vec3 c = gaskScreen(vec3(cell + 0.5, 0.5 * (1. - GASK_PAD)), i, gap, z);

            // the amp clock runs on the circle's screen size, which grows in
            // step with the zoom, and its angle round the zoom centre: the
            // same circle after a loop is in the same state
            float ang = atan(c.y, c.x);
            float ph = GASK_CYCLES * log(c.z) / log(GASK_ZOOM) + 0.5 * sin(3. * ang);
            float frame = LOOP_LEN * fract(ph);
            float shade = 1. - GASK_FADE_A * (1. - smoothstep(log(GASK_FADE.x), log(GASK_FADE.y), log(c.z * iResolution.y)));
            float deep = 1. - smoothstep(log(GASK_TINT.x), log(GASK_TINT.y), log(c.z * iResolution.y));

            vec2 rel = q - c.xy;
            float sd = length(rel) - c.z;
            float sc = c.z / (0.5 * (1. - GASK_PAD)) * GASK_AMP;
            vec2 gp = rel / sc;
            float dir = sin(5. * ang) < 0. ? -1. : 1.;
            vec2 pJ, pP;
            ampSpin(gp, frame, dir, pJ, pP);
            vec2 d = ampPieces(pJ, pP);
            vec3 inner = mix(vec3(0.), vec3(GASK_OFF), S(max(sd, min(d.x, d.y) * sc)));
            inner = mix(inner, mix(ampGradient(gp), GASK_DEEP, deep), S(max(sd, ampFill(pJ, pP, d, frame) * sc)));
            inner = mix(inner, mix(GASK_RING_COL, GASK_DEEP * 0.5, deep), S(abs(sd + GASK_RING) - GASK_RING));

            // embossed amp: compare the glyph with itself nudged towards the
            // light, lit where its edge faces the light, shaded opposite
            vec2 qJ, qP;
            ampSpin(gp + L.xy * GASK_EMBOSS_D, frame, dir, qJ, qP);
            vec2 d2 = ampPieces(qJ, qP);
            float w = max(1.5 / (iResolution.y * sc), 0.004);
            float m0 = smoothstep(w, -w, min(d.x, d.y)), m1 = smoothstep(w, -w, min(d2.x, d2.y));
            inner *= 1. + GASK_EMBOSS * (m0 - m1);

            // bevelled rim: the face tilts outwards over the last stretch
            float t = clamp(-sd / (c.z * GASK_BEVEL), 0., 1.);
            vec3 n = normalize(vec3(normalize(rel) * GASK_BEVEL_K * (1. - t) * (1. - t), 1.));
            inner *= dot(n, L) / L.z;
            inner += GASK_SPEC * pow(max(dot(reflect(-L, n), vec3(0., 0., 1.)), 0.), 16.) * (1. - t);

            col = mix(col, inner * shade, S(sd));
            if(sqd < -px * 1.3) break;
        }
        if(px > 0.25) break;
        vec2 l = fract(p - 0.5) - 0.5;
        gap[i] = p - l;

        // drop shadows of this gap's four bounding circles on everything
        // behind them (the parents' were cast a level up)
        bool home = i > 0 && gap[i] == vec2(0.);
        if(!home && length(l) < 0.42){
            for(int k = 0; k < 4; k++){
                vec2 o = vec2(k & 1, k >> 1) - 0.5;
                vec3 c = gaskScreen(vec3(gap[i] + o, 0.5 * (1. - GASK_PAD)), i, gap, z);
                float ds = length(q - c.xy - sdir * c.z * GASK_SHADOW_OFF) - c.z;
                shadow = max(shadow, 1. - smoothstep(-c.z * GASK_SHADOW_SOFT, c.z * GASK_SHADOW_SOFT, ds));
            }
        }

        float ll = max(dot(l, l), 1e-12);
        p = 0.25 * l / ll;
        px *= 0.25 / ll;
    }
    return col * (1. - GASK_SHADOW * shadow);
}
// --- gravity: amps fired into a sun and three planets -------------------------
// the planets run on exact circular Kepler orbits (pure functions of time);
// the amps are test particles. bufferGravState integrates them (leapfrog,
// adaptive substeps) over its own previous output in iChannel9, one row per
// amp: x=0 pos.xy vel.xy, x=1 status (0 dead, 1 flying, 2 crashed,
// 3 parked round a planet), time of the last launch/release/crash/capture,
// position before the last step, x=2 last integration time, x=3 this
// frame's path segment for the trail pass, x=4 parking orbit (planet,
// radius, phase at capture, angular velocity), x=5 the capture's start
// radius and angular velocity, eased into the parking orbit over GRAV_RETRO. Texels from x=GRAV_GRID_X on are a coarse screen grid, one
// GRAV_CELL square per texel, each a 96-bit mask (24 per channel) of the
// amps near it, so the full-screen passes only look at those.
// bufferGravTrail is a decaying phosphor of the segments.
// Each amp relaunches every GRAV_CYCLE, the slots evenly staggered, from a
// fresh random spot just off screen with its own aim and speed.
// Planets can't capture on gravity alone (nothing sheds the energy, and the
// rails aren't Kepler), so amps do it with their rockets: swinging through
// periapsis of a planet close and slow enough, some fire a retro burn into a
// circular parking orbit, ride along for a while, then burn out again.
// Some do the same round the sun at their first periapsis.
const float GRAV_GM      = 1.35e-3;
const vec2  GRAV_ORBIT[3] = vec2[3](vec2(0.14, 0.3), vec2(0.26, 2.4), vec2(0.40, 4.4));
const float GRAV_RAD[4]  = float[4](0.06, 0.018, 0.03, 0.024);
const float GRAV_SOFT    = 0.004;
const float GRAV_ORBIT_SPEED = 0.3;
const int   GRAV_N       = 34;
const float GRAV_CYCLE   = 84.;
const float GRAV_BURN    = 1.6;
const float GRAV_V0      = 0.25;
const vec2  GRAV_SPEED   = vec2(0.028, 0.062);
const vec2  GRAV_PERI    = vec2(0.09, 0.5);
const float GRAV_DIVE    = 0.12;
const int   GRAV_STEPS   = 96;
const float GRAV_AMP     = 0.016;
const float GRAV_TRAIL_W = 0.0009;
const float GRAV_TRAIL_T = 1.;
const float GRAV_TRAIL_GAIN = 0.9;
const vec3  GRAV_SUN_COL = vec3(1., 0.85, 0.55);
const vec3  GRAV_PLANET_COL = vec3(0.75, 0.55, 0.4);
const vec3  GRAV_ORBIT_COL = vec3(0.7);
const float GRAV_ORBIT_A = 0.12;
const float GRAV_ORBIT_W = 0.0006;
const float GRAV_BOOM_T  = 0.8;
const float GRAV_CELL    = 1. / 14.;
const ivec2 GRAV_GRID    = ivec2(32, 14);
const int   GRAV_GRID_X  = 6;
const float GRAV_REACH   = 0.075;
const float GRAV_CAPTURE_R = 3.5;
const float GRAV_CAPTURE_V = 3.;
const float GRAV_CAPTURE_P = 0.7;
const float GRAV_CAPTURE_COOL = 3.;
const vec2  GRAV_PARK    = vec2(8., 25.);
const vec2  GRAV_SUN_PARK = vec2(20., 50.);
const float GRAV_SUN_P   = 0.25;
const float GRAV_ESCAPE  = 1.7;
const float GRAV_RETRO   = 0.8;

ivec2 gravCell(vec2 q, float asp){
    return ivec2(floor((q + vec2(0.5 * asp, 0.5)) / GRAV_CELL));
}

uvec4 gravNear(sampler2D st, vec2 q, float asp){
    ivec2 c = gravCell(q, asp);
    if(any(lessThan(c, ivec2(0))) || any(greaterThanEqual(c, GRAV_GRID))) return uvec4(0u);
    return uvec4(texelFetch(st, ivec2(GRAV_GRID_X, 0) + c, 0));
}

int gravPop(inout uvec4 m){
    for(int c = 0; c < 4; c++){
        if(m[c] == 0u) continue;
        int b = findLSB(m[c]);
        m[c] &= m[c] - 1u;
        return c * 24 + b;
    }
    return -1;
}

vec4 gravGrid(ivec2 c){
    if(c.x >= GRAV_GRID.x || c.y >= GRAV_GRID.y) return vec4(0.);
    vec2 bc = (vec2(c) + 0.5) * GRAV_CELL - vec2(0.5 * u_aspect, 0.5);
    float h = 0.5 * GRAV_CELL + GRAV_REACH;
    uvec4 m = uvec4(0u);
    for(int i = 0; i < GRAV_N; i++){
        vec2 p = texelFetch(iChannel9, ivec2(0, i), 0).xy;
        if(all(lessThan(abs(p - bc), vec2(h)))) m[i / 24] |= 1u << uint(i % 24);
    }
    return vec4(m);
}

vec3 gravBody(int k, float t){
    if(k == 0) return vec3(0., 0., GRAV_GM);
    vec2 o = GRAV_ORBIT[k - 1];
    float period = 6.2831853 * sqrt(o.x * o.x * o.x / GRAV_GM);
    float a = o.y + 6.2831853 * fract(t * GRAV_ORBIT_SPEED / period);
    return vec3(o.x * cos(a), o.x * sin(a), GRAV_GM * pow(GRAV_RAD[k] / GRAV_RAD[0], 3.));
}

vec2 gravBodyVel(int k, float t){
    if(k == 0) return vec2(0.);
    vec2 o = GRAV_ORBIT[k - 1];
    float period = 6.2831853 * sqrt(o.x * o.x * o.x / GRAV_GM);
    float a = o.y + 6.2831853 * fract(t * GRAV_ORBIT_SPEED / period);
    return o.x * 6.2831853 * GRAV_ORBIT_SPEED / period * vec2(-sin(a), cos(a));
}

vec4 gravPark(vec4 o, vec2 o2, float tc, float t){
    int k = int(o.x);
    float T = GRAV_RETRO, tau = t - tc;
    float u = clamp(tau / T, 0., 1.);
    float sm = u * u * (3. - 2. * u);
    float I = T * (u * u * u - 0.5 * u * u * u * u) + max(tau - T, 0.);
    float a = o.z + o2.y * tau + (o.w - o2.y) * I;
    float rr = mix(o2.x, o.y, sm);
    float dr = (o.y - o2.x) * 6. * u * (1. - u) / T;
    vec2 e = vec2(cos(a), sin(a));
    return vec4(gravBody(k, t).xy + rr * e, gravBodyVel(k, t) + rr * mix(o2.y, o.w, sm) * vec2(-e.y, e.x) + dr * e);
}

float gravHash(int id, uint salt){
    return pcgHash(uvec3(uint(id + 1000000), salt, uint(sk_seed(2) * 4e9)));
}

vec2 gravAccel(vec2 p, float t, out float rd, out int hit){
    vec2 a = vec2(0.);
    rd = 1e9;
    hit = -1;
    for(int k = 0; k < 4; k++){
        vec3 b = gravBody(k, t);
        vec2 d = b.xy - p;
        float r2 = dot(d, d) + GRAV_SOFT * GRAV_SOFT;
        a += b.z * d / (r2 * sqrt(r2));
        float s = length(d) - GRAV_RAD[k];
        if(s < 0.) hit = k;
        rd = min(rd, s);
    }
    return a;
}

float gravLaunch(int i, float t, out int id){
    float off = float(i) * GRAV_CYCLE / float(GRAV_N);
    float n = floor((t - off) / GRAV_CYCLE);
    id = int(n) * GRAV_N + i;
    return n * GRAV_CYCLE + off;
}

vec4 gravSpawn(int id, out float v){
    uint s = uint(sk_seed(2) * 4e9), u = uint(id + 1000000);
    float h1 = pcgHash(uvec3(u, 1u, s)), h2 = pcgHash(uvec3(u, 2u, s)), h3 = pcgHash(uvec3(u, 3u, s));
    float h5 = pcgHash(uvec3(u, 5u, s));
    float th = 6.2831853 * h1;
    vec2 dir = vec2(cos(th), sin(th));
    vec2 E = vec2(0.5 * u_aspect + 0.03, 0.53);
    vec2 p = dir * min(E.x / max(abs(dir.x), 1e-4), E.y / max(abs(dir.y), 1e-4));
    v = mix(GRAV_SPEED.x, GRAV_SPEED.y, h5);
    float rp = h2 < GRAV_DIVE ? GRAV_RAD[0] * h2 / GRAV_DIVE : mix(GRAV_PERI.x, GRAV_PERI.y, (h2 - GRAV_DIVE) / (1. - GRAV_DIVE));
    float r0 = length(p);
    float vp = sqrt(max(v * v + 2. * GRAV_GM / rp - 2. * GRAV_GM / r0, 0.));
    float a = asin(clamp(rp * vp / (r0 * v), 0., 1.)) * (h3 < 0.5 ? -1. : 1.);
    vec2 d = -p / r0;
    d = vec2(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a));
    return vec4(p, d * v * GRAV_V0);
}

float gravRadial(vec4 s, int j, float t){
    return dot(s.xy - gravBody(j, t).xy, s.zw - gravBodyVel(j, t));
}

void gravFly(inout vec4 s, inout vec2 st, inout vec4 park, inout vec2 park2, float t0, float t1, float L, float v, int id){
    float t = t0;
    float thrust = v * (1. - GRAV_V0) / GRAV_BURN;
    vec4 rad0 = vec4(gravRadial(s, 0, t), gravRadial(s, 1, t), gravRadial(s, 2, t), gravRadial(s, 3, t));
    int pj = int(park.x);
    float esc = st.y > L + 0.5 ? abs(park.w) * park.y * (GRAV_ESCAPE - 1.) / GRAV_RETRO : 0.;
    for(int k = 0; k < GRAV_STEPS; k++){
        if(t >= t1) break;
        float rd;
        int hit;
        vec2 a = gravAccel(s.xy, t, rd, hit);
        float sp = max(length(s.zw), 0.02);
        float h = k == GRAV_STEPS - 1 ? t1 - t : min(clamp(0.03 * max(rd, 0.002) / sp, 2e-4, 0.01), t1 - t);
        vec2 th = t - L < GRAV_BURN ? normalize(s.zw) * thrust : vec2(0.);
        if(esc > 0. && t - st.y < GRAV_RETRO) th += normalize(s.zw - gravBodyVel(pj, t)) * esc;
        s.zw += (a + th) * h * 0.5;
        s.xy += s.zw * h;
        t += h;
        a = gravAccel(s.xy, t, rd, hit);
        th = t - L < GRAV_BURN ? normalize(s.zw) * thrust : vec2(0.);
        if(esc > 0. && t - st.y < GRAV_RETRO) th += normalize(s.zw - gravBodyVel(pj, t)) * esc;
        s.zw += (a + th) * h * 0.5;
        if(hit >= 0){ st = vec2(2., t); return; }
        if(length(s.xy) > 3.){ st = vec2(0.); return; }
        for(int j = 0; j < 4; j++){
            float r1 = gravRadial(s, j, t);
            bool peri = rad0[j] <= 0. && r1 > 0.;
            rad0[j] = r1;
            if(!peri || t - st.y < GRAV_CAPTURE_COOL) continue;
            vec3 b = gravBody(j, t);
            vec2 rel = s.xy - b.xy, vr = s.zw - gravBodyVel(j, t);
            float d = length(rel);
            if(j == 0){
                if(st.y > L + 0.5 || gravHash(id, 10u) > GRAV_SUN_P) continue;
            } else {
                if(d > GRAV_RAD[j] * GRAV_CAPTURE_R || length(vr) > GRAV_CAPTURE_V * sqrt(b.z / d)) continue;
                if(gravHash(id, uint(10 + j)) > GRAV_CAPTURE_P) continue;
            }
            float pr = max(d, GRAV_RAD[j] * 1.5);
            float sg = rel.x * vr.y - rel.y * vr.x < 0. ? -1. : 1.;
            park = vec4(float(j), pr, atan(rel.y, rel.x), sg * sqrt(b.z / (pr * pr * pr)));
            park2 = vec2(d, sg * length(vr) / d);
            st = vec2(3., t);
            s = gravPark(park, park2, t, t);
            return;
        }
    }
}

vec4 gravState(int x, int i){
    if(x >= GRAV_GRID_X) return gravGrid(ivec2(x - GRAV_GRID_X, i));
    if(i >= GRAV_N) return vec4(0.);
    vec4 s = texelFetch(iChannel9, ivec2(0, i), 0);
    vec4 s1 = texelFetch(iChannel9, ivec2(1, i), 0);
    vec2 st = s1.xy, a0 = s1.zw;
    vec4 park = texelFetch(iChannel9, ivec2(4, i), 0);
    vec2 park2 = texelFetch(iChannel9, ivec2(5, i), 0).xy;
    float t0 = texelFetch(iChannel9, ivec2(2, 0), 0).x, t1 = iTime;
    if(t1 < t0 || t1 - t0 > 0.5){ st = vec2(0.); t0 = t1; }
    if(x == 2) return vec4(t1, 0., 0., 0.);
    vec2 a = s.xy;
    bool was = st.x == 1. || st.x == 3.;
    int id;
    float L = gravLaunch(i, t1, id), v;
    if(L > t0){
        s = gravSpawn(id, v);
        st = vec2(1., L);
        a = s.xy;
        a0 = a;
        was = true;
        t0 = L;
    } else gravSpawn(id, v);
    if(st.x == 3.){
        vec2 hold = park.x < 0.5 ? GRAV_SUN_PARK : GRAV_PARK;
        float rel = st.y + mix(hold.x, hold.y, gravHash(id, 20u));
        if(t1 < rel){
            s = gravPark(park, park2, st.y, t1);
            for(int k = 0; k < 4; k++)
                if(k != int(park.x) && length(s.xy - gravBody(k, t1).xy) < GRAV_RAD[k]) st = vec2(2., t1);
        }
        else {
            s = gravPark(park, park2, st.y, rel);
            st = vec2(1., rel);
            t0 = rel;
        }
    }
    if(st.x == 1.){
        gravFly(s, st, park, park2, t0, t1, L, v, id);
        if(st.x == 3.) s = gravPark(park, park2, st.y, t1);
    }
    if(x == 4) return park;
    if(x == 5) return vec4(park2, 0., 0.);
    if(x == 0) return st.x == 0. || st.x == 2. && t1 - st.y > GRAV_BOOM_T ? vec4(1e4) : s;
    if(x == 1) return vec4(st, a);
    return was ? vec4(a0, s.xy) : vec4(1e4);
}

vec4 gravTrail(vec2 q, vec4 prev){
    float T = texelFetch(iChannel8, ivec2(2, 0), 0).x;
    if(T == prev.a) return prev;
    float e = T < prev.a || T - prev.a > 0.5 ? 0. : prev.r * exp(-(T - prev.a) / GRAV_TRAIL_T);
    uvec4 m = gravNear(iChannel8, q, iResolution.x / iResolution.y);
    for(int k = 0; k < GRAV_N; k++){
        int i = gravPop(m);
        if(i < 0) break;
        vec4 g = texelFetch(iChannel8, ivec2(3, i), 0);
        if(g.x > 1e3) continue;
        float d = sdSegment(q, g.xy, g.zw);
        e = max(e, exp(-0.5 * d * d / (GRAV_TRAIL_W * GRAV_TRAIL_W)));
    }
    return vec4(e, 0., 0., T);
}

vec3 gravity(vec2 q, vec2 tp){
    vec3 col = bgNoise(tp);
    float e = texture(iChannel11, roomUV(q)).r;
    col += (1. - exp(-e * GRAV_TRAIL_GAIN)) * mix(GRAD_BOT, GRAD_TOP, 0.5) * 0.8;

    for(int k = 0; k < 3; k++)
        col = mix(col, GRAV_ORBIT_COL, S(abs(length(q) - GRAV_ORBIT[k].x) - GRAV_ORBIT_W) * GRAV_ORBIT_A);

    float ds = length(q);
    col += GRAV_SUN_COL * (0.25 * exp(-max(ds - GRAV_RAD[0], 0.) / 0.025) + 0.08 * exp(-ds / 0.15));
    col = mix(col, mix(GRAV_SUN_COL, vec3(1.), 0.6 * (1. - ds / GRAV_RAD[0])), S(ds - GRAV_RAD[0]));

    for(int k = 1; k < 4; k++){
        vec3 b = gravBody(k, iTime);
        vec2 rel = (q - b.xy) / GRAV_RAD[k];
        float r2 = dot(rel, rel);
        if(r2 > 4.) continue;
        vec3 n = vec3(rel, sqrt(max(1. - r2, 0.)));
        vec3 L = normalize(vec3(-normalize(b.xy), 0.25));
        float lit = max(dot(n, L), 0.) * 0.95 + 0.05;
        col = mix(col, GRAV_PLANET_COL * lit, S((sqrt(r2) - 1.) * GRAV_RAD[k]));
    }

    uvec4 m = gravNear(iChannel10, q, iResolution.x / iResolution.y);
    for(int k = 0; k < GRAV_N; k++){
        int i = gravPop(m);
        if(i < 0) break;
        vec4 s = texelFetch(iChannel10, ivec2(0, i), 0);
        if(length(q - s.xy) > 0.07) continue;
        vec2 st = texelFetch(iChannel10, ivec2(1, i), 0).xy;
        if(st.x == 0.) continue;
        if(st.x == 2.){
            float age = iTime - st.y;
            if(age < 0. || age > GRAV_BOOM_T) continue;
            float f = age / GRAV_BOOM_T;
            float r = length(q - s.xy);
            float ring = S(abs(r - 0.045 * sqrt(f)) - 0.0015 * (1. - f));
            col += PEN_FLAME_COL * ring * (1. - f) + PEN_FLAME_HOT * exp(-r / (0.012 * (1. - f) + 1e-3)) * (1. - f) * (1. - f);
            continue;
        }
        int id;
        float L = gravLaunch(i, iTime, id);
        float age = iTime - L, ev = iTime - st.y;
        float vis = smoothstep(0., 0.3, age) * (1. - smoothstep(GRAV_CYCLE - 3., GRAV_CYCLE - 0.5, age));
        vec2 dir = normalize(s.zw);
        vec2 gp = (q - s.xy) / GRAV_AMP;
        gp = vec2(dot(gp, vec2(dir.y, -dir.x)), dot(gp, dir));
        float burn = smoothstep(0., 0.1, age) * smoothstep(GRAV_BURN, GRAV_BURN - 0.3, age);
        if(st.x == 1. && st.y > L + 0.5) burn = max(burn, smoothstep(0., 0.1, ev) * smoothstep(GRAV_RETRO, GRAV_RETRO - 0.3, ev));
        if(burn > 0.) col = penExhaust(col, gp, float(i), vis * burn);
        if(st.x == 3. && ev < GRAV_RETRO) col = penExhaust(col, -gp, float(i), vis * smoothstep(0., 0.1, ev) * smoothstep(GRAV_RETRO, GRAV_RETRO - 0.3, ev));
        col = mix(col, ampGradient(gp), S(glyphDist(gp) * GRAV_AMP) * vis);
    }
    return col;
}
// --- fluid: a stirred incompressible fluid, amps tinted by its shear stress ----
// bufferFluid is a W x H grid over the screen (row 0 at the top, cell units)
// plus one extra row holding the time of the last step, run over its own
// previous output in iChannel9: xy velocity (cells/s), z pressure, w the
// strain rate, low-passed and carried with the flow. Each step advects
// (semi-Lagrangian), relaxes the pressure one Jacobi sweep (warm-started from
// the last frame) and projects, adds vorticity confinement, and drags the
// fluid along with FLUID_STIRS invisible spoons and the odd jet kick.
// The main pass reads it from iChannel12: amps sit on a lattice, pushed off
// their spot and twisted by the local flow, and turn blue with the stress.
const int   FLUID_STIRS     = 3;
const float FLUID_STIR_R    = 14.;
const float FLUID_STIR_GRIP = 10.;
const vec2  FLUID_STIR_BOX  = vec2(0.38, 0.36);
const float FLUID_STIR_RATE = 0.22;
const float FLUID_STIR_CALM = 0.07;
const float FLUID_KICK_P    = 4.;
const float FLUID_KICK_T    = 0.35;
const float FLUID_KICK_V    = 220.;
const float FLUID_KICK_R    = 12.;
const float FLUID_VORT      = 0.7;
const float FLUID_VISC      = 0.6;
const float FLUID_DAMP      = 0.12;
const float FLUID_STRESS_T  = 0.5;
const float FLUID_ROWS      = 50.;
const float FLUID_AMP       = 0.42;
const float FLUID_DISP      = 0.2;
const float FLUID_DISP_MAX  = 0.4;
const float FLUID_TWIST     = 0.12;
const float FLUID_STRESS_REF = 2.5;
const vec3  FLUID_IDLE      = vec3(0.28);
const vec3  FLUID_HOT       = vec3(0.75, 0.95, 1.);
const float FLUID_GLOW      = 0.12;

ivec2 fluidSize(sampler2D s){ return textureSize(s, 0) - ivec2(0, 1); }

vec4 fluidAt(sampler2D s, ivec2 c, ivec2 R){
    vec4 v = texelFetch(s, clamp(c, ivec2(0), R - 1), 0);
    return any(isnan(v)) || any(isinf(v)) ? vec4(0.) : v;
}

vec4 fluidLerp(sampler2D s, vec2 f, ivec2 R){
    f = clamp(f, vec2(0.5), vec2(R) - 0.5) - 0.5;
    ivec2 i = ivec2(floor(f));
    vec2 t = f - vec2(i);
    return mix(mix(fluidAt(s, i, R), fluidAt(s, i + ivec2(1, 0), R), t.x),
               mix(fluidAt(s, i + ivec2(0, 1), R), fluidAt(s, i + ivec2(1, 1), R), t.x), t.y);
}

float fluidCurl(sampler2D s, ivec2 c, ivec2 R){
    return 0.5 * (fluidAt(s, c + ivec2(1, 0), R).y - fluidAt(s, c - ivec2(1, 0), R).y
                - fluidAt(s, c + ivec2(0, 1), R).x + fluidAt(s, c - ivec2(0, 1), R).x);
}

vec2 fluidStir(int k, float t, vec2 R){
    vec2 f = vec2(0.31, 0.23) * (1. + 0.37 * float(k)) * FLUID_STIR_RATE;
    vec2 ph = 6.2831853 * vec2(sk_seed(2 * k), sk_seed(2 * k + 1));
    return R * (0.5 + FLUID_STIR_BOX * vec2(sin(t * f.x + ph.x), sin(t * f.y + ph.y + 0.7 * sin(t * f.x * 0.6))));
}

float fluidStirOn(int k, float t){
    return smoothstep(0.25, 0.75, 0.5 + 0.5 * sin(t * FLUID_STIR_CALM * (1. + 0.41 * float(k)) + 6.2831853 * sk_seed(10 + k)));
}

vec4 fluidStep(ivec2 c){
    ivec2 R = fluidSize(iChannel9);
    if(c.y >= R.y) return vec4(iTime, 0., 0., 0.);
    float T0 = texelFetch(iChannel9, ivec2(0, R.y), 0).x;
    float dt = isnan(T0) || T0 > iTime ? 0. : min(iTime - T0, 1. / 30.);
    vec4 s = fluidAt(iChannel9, c, R);
    if(dt <= 0.) return s;

    vec2 pos = vec2(c) + 0.5;
    vec4 a = fluidLerp(iChannel9, pos - dt * s.xy, R);
    vec4 e = fluidAt(iChannel9, c + ivec2(1, 0), R), w = fluidAt(iChannel9, c - ivec2(1, 0), R);
    vec4 n = fluidAt(iChannel9, c + ivec2(0, 1), R), so = fluidAt(iChannel9, c - ivec2(0, 1), R);

    float div = 0.5 * (e.x - w.x + n.y - so.y);
    float p = 0.25 * (e.z + w.z + n.z + so.z - div);
    vec2 v = a.xy - 0.5 * vec2(e.z - w.z, n.z - so.z);
    v = mix(v, 0.25 * (e.xy + w.xy + n.xy + so.xy), clamp(FLUID_VISC * dt * 10., 0., 0.5));

    float cE = abs(fluidCurl(iChannel9, c + ivec2(1, 0), R)), cW = abs(fluidCurl(iChannel9, c - ivec2(1, 0), R));
    float cN = abs(fluidCurl(iChannel9, c + ivec2(0, 1), R)), cS = abs(fluidCurl(iChannel9, c - ivec2(0, 1), R));
    vec2 gw = 0.5 * vec2(cE - cW, cN - cS);
    float om = fluidCurl(iChannel9, c, R);
    if(dot(gw, gw) > 1e-8) v += dt * FLUID_VORT * om * vec2(gw.y, -gw.x) / length(gw) * 4.;

    vec2 Rf = vec2(R);
    for(int k = 0; k < FLUID_STIRS; k++){
        vec2 sp = fluidStir(k, iTime, Rf);
        vec2 sv = (fluidStir(k, iTime + 0.05, Rf) - fluidStir(k, iTime - 0.05, Rf)) * 10.;
        vec2 d = pos - sp;
        float g = exp(-dot(d, d) / (FLUID_STIR_R * FLUID_STIR_R)) * fluidStirOn(k, iTime);
        v = mix(v, sv * 1.6, clamp(g * FLUID_STIR_GRIP * dt, 0., 1.));
    }

    float kn = floor(iTime / FLUID_KICK_P);
    float k0 = kn * FLUID_KICK_P + random(vec2(kn, 1.3)) * (FLUID_KICK_P - FLUID_KICK_T);
    if(iTime > k0 && iTime < k0 + FLUID_KICK_T){
        vec2 kp = Rf * (0.15 + 0.7 * vec2(random(vec2(kn, 2.7)), random(vec2(kn, 4.1))));
        float ka = 6.2831853 * random(vec2(kn, 8.9));
        vec2 d = pos - kp;
        float g = exp(-dot(d, d) / (FLUID_KICK_R * FLUID_KICK_R));
        v = mix(v, FLUID_KICK_V * vec2(cos(ka), sin(ka)), clamp(g * 12. * dt, 0., 1.));
    }

    v *= exp(-dt * FLUID_DAMP);
    if(c.x == 0 || c.x == R.x - 1) v.x = 0.;
    if(c.y == 0 || c.y == R.y - 1) v.y = 0.;
    float lv = length(v);
    if(lv > 240.) v *= 240. / lv;

    float ux = 0.5 * (e.x - w.x), uy = 0.5 * (n.x - so.x);
    float vx = 0.5 * (e.y - w.y), vy = 0.5 * (n.y - so.y);
    float rate = sqrt((ux - vy) * (ux - vy) + (uy + vx) * (uy + vx));
    float st = mix(rate, a.w, exp(-dt / FLUID_STRESS_T));
    return vec4(v, p, st);
}

vec2 fluidCell(vec2 q, ivec2 R){
    float asp = iResolution.x / iResolution.y;
    return vec2(q.x / asp + 0.5, 0.5 - q.y) * vec2(R);
}

vec3 fluid(vec2 q, vec2 tp){
    ivec2 R = fluidSize(iChannel12);
    vec3 col = bgNoise(tp);
    float field = fluidLerp(iChannel12, fluidCell(q, R), R).w;
    col += GRAD_BOT * FLUID_GLOW * (1. - exp(-field / FLUID_STRESS_REF));

    float h = 1. / FLUID_ROWS;
    vec2 id = floor(q / h);
    float best = 1e9;
    vec3 ac = FLUID_IDLE;
    float scale = FLUID_AMP * h;
    for(int j = -1; j <= 1; j++) for(int i = -1; i <= 1; i++){
        vec2 cc = (id + vec2(i, j) + 0.5) * h;
        vec4 f = fluidLerp(iChannel12, fluidCell(cc, R), R);
        vec2 vel = vec2(f.x, -f.y) / float(R.y);
        vec2 off = vel * FLUID_DISP;
        float lo = length(off);
        if(lo > FLUID_DISP_MAX * h) off *= FLUID_DISP_MAX * h / lo;
        vec2 fc = fluidCell(cc, R);
        ivec2 ic = ivec2(fc);
        float om = -fluidCurl(iChannel12, ic, R);
        float tw = clamp(om * FLUID_TWIST, -1.2, 1.2);
        vec2 gp = Rot(tw) * (q - cc - off) / scale;
        float sd = glyphDist(gp) * scale;
        if(sd < best){
            best = sd;
            float sx = 1. - exp(-f.w / FLUID_STRESS_REF);
            vec3 blue = ampGradient(gp) * mix(0.75, 1.15, sx);
            ac = mix(FLUID_IDLE, blue, smoothstep(0., 0.6, sx));
            ac = mix(ac, FLUID_HOT, smoothstep(0.7, 1., sx) * 0.6);
        }
    }
    return mix(col, ac, S(best));
}
// --- flap: a split-flap board (transition) -----------------------------------
// FLAP_ROWS rows of tiles, each split at a hinge. On its own clock the board
// flips over the old scene to the amp (TRANS_AMP tall) from FLAP_IN_AT, the
// tagline flaps in along the bottom, and from FLAP_OUT_AT it flips on to
// the new scene; a tile showing a scene and not flipping is just the scene.
// A change of picture: a sweep from a random direction sets each tile off, which
// clatters through a few random cards (FLAP_T per flip) before landing on its
// piece of the new picture. A flip drops the top half of the old card over
// the hinge: on the way down it shows the old card's top, past vertical the
// new card's bottom (its back), foreshortened and widened towards the free
// edge. Pictures are sampled in screen space, so big ones run across tiles.
// Some tiles carry characters (black card, white
// Montserrat from the flap_font.png atlas in iChannel13, gen_flapfont.py):
// the small-amp picture shows the clock top right, whose digits roll forward when
// iClock changes (u_clock_prev, u_clock_at), and FLAP_TEXT_AT into the blue
// amp picture FLAP_TEXT flaps in below it on two lines, letter by letter,
// and into the inverted one FLAP_URL along the top right. Text slots are
// j < 32 for FLAP_TEXT, 32 + i for FLAP_URL.
// A card is ivec2(kind, value): 0 picture, 1 scramble, 2 character (-1
// blank) on black, 3 character + 1 + 128 * picture over that picture.
const float FLAP_ROWS   = 12.;
const float FLAP_ASPECT = 0.72;
const float FLAP_IN_AT  = 0.;
const float FLAP_OUT_AT = 7.6;
const float FLAP_PREV_END = 3.;
const float FLAP_SWEEP  = 1.6;
const float FLAP_JITTER = 0.25;
const float FLAP_T      = 0.085;
const vec2  FLAP_FLIPS  = vec2(3., 10.);
const float FLAP_FACE   = 0.45;
const float FLAP_RAD    = 0.06;
const float FLAP_GAP    = 0.012;
const float FLAP_WIDEN  = 0.12;
const float FLAP_BIG    = 0.82;
const float FLAP_SMALL  = 0.62;
const int   FLAP_PICS   = 4;
const int   FLAP_CLOCK_PIC = 2;
const int   FLAP_TEXT_PIC  = 0;
const float FLAP_HERO   = 0.5 * TRANS_AMP;
const int   FLAP_PREV   = 5;
const int   FLAP_NEXT   = 6;
const float FLAP_TEXT_AT   = 2.6;
const float FLAP_TEXT_STAGGER = 0.07;
const vec2  FLAP_TEXT_FLIPS   = vec2(4., 9.);
const float FLAP_CLOCK_STAGGER = 0.06;
const float FLAP_TEXT_SHADOW = 0.55;
const int   FLAP_TEXT_LEN = 19;
const int   FLAP_LINE     = 9;
const int   FLAP_TEXT_ROW = -3;
const int   FLAP_TEXT[FLAP_TEXT_LEN] = int[FLAP_TEXT_LEN](19, 56, 63, 55, -1, 56, 45, 49, 41, -1, 56, 51, -1, 38, 57, 45, 48, 40, 64);
const int   FLAP_URL_PIC = 1;
const int   FLAP_URL_LEN = 9;
const int   FLAP_URL[FLAP_URL_LEN] = int[FLAP_URL_LEN](37, 50, 40, 37, 49, 52, 64, 45, 51);
const vec2  FLAP_FONT_GRID = vec2(8., 9.);
const float FLAP_FONT_ASPECT = 0.75;
const float FLAP_FONT_RANGE  = 0.25;
const vec3  FLAP_CARD   = vec3(0.075);
const vec3  FLAP_HOUSING = vec3(0.012);
const vec3  FLAP_INK    = vec3(0.86);
const vec3  FLAP_BLACK  = vec3(0.025);
const vec3  FLAP_WHITE  = vec3(0.92);

float flapAmp(vec2 g, float sc){ return glyphDist(g / sc) * sc; }

float flapGlyph(int ch, vec2 l){
    if(ch < 0) return 1.;
    vec2 uv = vec2(l.x / FLAP_FONT_ASPECT + 0.5, 0.5 - l.y);
    if(any(lessThan(uv, vec2(0.))) || any(greaterThan(uv, vec2(1.)))) return 1.;
    vec2 cell = vec2(ch % 8, ch / 8);
    return (texture(iChannel13, (cell + uv) / FLAP_FONT_GRID).r - 0.5) * FLAP_FONT_RANGE;
}

// board states come in threes: the old scene, the amp with the tagline, the
// new scene; the board flips old -> amp at FLAP_IN_AT and amp -> new at
// FLAP_OUT_AT
int flapState(float n){ return int(mod(n, 3.) + .5); }

int flapPic(float n){ int s = flapState(n); return s == 0 ? FLAP_PREV : s == 1 ? 0 : FLAP_NEXT; }

float flapStart(float n){ return flapState(n) == 1 ? FLAP_IN_AT : FLAP_OUT_AT; }

int flapSlot(vec2 id, int pic, out int j){
    float asp = iResolution.x / iResolution.y;
    int xr = int(floor(0.5 * asp / (FLAP_ASPECT / FLAP_ROWS))) - 1;
    int x = int(id.x), y = int(id.y), top = int(FLAP_ROWS * 0.5) - 2;
    j = 0;
    if(pic == FLAP_CLOCK_PIC && y == top && x >= xr - 5 && x < xr){ j = x - (xr - 5); return 1; }
    int x0 = -(FLAP_LINE - 1) / 2, ln = FLAP_TEXT_ROW - y;
    if(pic == FLAP_TEXT_PIC && (ln == 0 || ln == 1) && x >= x0 && x < x0 + FLAP_LINE){ j = x - x0 + ln * (FLAP_LINE + 1); return 2; }
    if(pic == FLAP_URL_PIC && y == top && x >= xr - FLAP_URL_LEN && x < xr){ j = 32 + x - (xr - FLAP_URL_LEN); return 2; }
    return 0;
}

int flapDigit(vec4 c, int j){
    return int((j == 0 ? c.x : j == 1 ? c.y : j == 3 ? c.z : c.w) + 0.5);
}

int flapClockChar(int j){ return j == 2 ? 10 : flapDigit(iClock, j); }

float flapTextAt(float n, int j){
    return flapStart(n) + FLAP_TEXT_AT + float(j % 32) * FLAP_TEXT_STAGGER;
}

ivec2 flapTextCard(int j, int ch){ return ivec2(3, ch + 1 + 128 * (j < 32 ? FLAP_TEXT_PIC : FLAP_URL_PIC)); }

int flapTextChar(int j){ return j < 32 ? FLAP_TEXT[j] : FLAP_URL[j - 32]; }

ivec2 flapFace(float n, vec2 id, float t){
    int pic = flapPic(n), j;
    int sl = flapSlot(id, pic, j);
    if(sl == 1) return ivec2(2, flapClockChar(j));
    if(sl == 2 && t >= flapTextAt(n, j)) return flapTextCard(j, flapTextChar(j));
    return ivec2(0, pic);
}

vec3 flapPicture(int pic, vec2 g, vec2 l, vec2 id, float th){
    if(pic == FLAP_PREV) return gPrevCol;
    if(pic == FLAP_NEXT) return gNextCol;
    if(pic == 0){
        float d = flapAmp(g, FLAP_HERO);
        return mix(FLAP_CARD, ampGradient(g / FLAP_HERO), S(d));
    }
    if(pic == 1){
        float d = flapAmp(g, FLAP_BIG);
        return mix(ampGradient(g / FLAP_BIG) * 0.9, FLAP_CARD, S(d));
    }
    if(pic == 2){
        float d = flapAmp(l * th, FLAP_SMALL * th);
        bool lit = random(id + 0.37) < 0.18;
        return mix(FLAP_CARD, lit ? ampGradient(l / FLAP_SMALL) : vec3(0.32), S(d));
    }
    vec2 cell = vec2(FLAP_ASPECT, 1.) * th;
    vec2 b = floor(id / 2.);
    vec2 bc = (b * 2. + 1.) * cell;
    float sc = FLAP_SMALL * 2. * th;
    float d = flapAmp(g - bc, sc);
    vec3 ink = random(b + 0.71) < 0.25 ? ampGradient((g - bc) / sc) : vec3(0.32);
    return mix(FLAP_CARD, ink, S(d));
}

vec3 flapScramble(vec2 id, float n, int k, vec2 l, float th){
    vec2 r = vec2(random(id + vec2(n * 1.3, float(k) * 7.1)), random(id + vec2(float(k) * 3.7, n * 0.9)));
    vec3 c = r.x < 0.55 ? FLAP_CARD : r.x < 0.8 ? vec3(0.3) : r.x < 0.93 ? ampGradient(l) : FLAP_INK * 0.9;
    if(r.y < 0.5){
        vec3 ink = c == FLAP_CARD ? vec3(0.5) : FLAP_CARD;
        c = mix(c, ink, S(flapAmp(l * th, FLAP_SMALL * th)));
    }
    return c;
}

vec3 flapRender(ivec2 c, float n, vec2 id, vec2 g, vec2 l, float th){
    if(c.x == 0) return flapPicture(c.y, g, l, id, th);
    if(c.x == 1) return flapScramble(id, n, c.y, l, th);
    if(c.x == 3){
        int ch = c.y % 128 - 1;
        vec3 bg = flapPicture(c.y / 128, g, l, id, th);
        bg *= 1. - FLAP_TEXT_SHADOW * smoothstep(0.05, -0.02, flapGlyph(ch, l + vec2(-0.02, 0.03)));
        return mix(bg, FLAP_WHITE, S(flapGlyph(ch, l) * th));
    }
    return mix(FLAP_BLACK, FLAP_WHITE, S(flapGlyph(c.y, l) * th));
}

// card k of a flip run: ev 0 board change, 1 text, 2 clock digit
ivec2 flapCard(int ev, int k, int m, float n, vec2 id, float st, int j, int prv, int base){
    if(ev == 0){
        if(k <= 0) return flapFace(n - 1., id, 1e4);
        if(k >= m) return flapFace(n, id, st);
        return ivec2(1, k);
    }
    if(ev == 1){
        if(k <= 0) return ivec2(0, j < 32 ? FLAP_TEXT_PIC : FLAP_URL_PIC);
        if(k >= m) return flapTextCard(j, flapTextChar(j));
        return flapTextCard(j, 37 + int(random(id + vec2(float(k) * 2.3, n)) * 26.));
    }
    return ivec2(2, (prv + k) % base);
}

vec3 flap(vec2 q, vec2 tp){
    float th = 1. / FLAP_ROWS;
    vec2 cell = vec2(FLAP_ASPECT * th, th);
    vec2 id = floor(q / cell);
    vec2 cc = (id + 0.5) * cell;
    vec2 l = (q - cc) / th;

    float lt = gModeT[MODE_FLAP];
    float n = 3. * gModeK[MODE_FLAP] + (lt < FLAP_OUT_AT ? 1. : 2.);
    float ang = 6.2831853 * random(vec2(n, 4.4));
    vec2 dir = vec2(cos(ang), sin(ang));
    float span = 0.5 * (abs(dir.x) * iResolution.x / iResolution.y + abs(dir.y));
    float delay = (dot(cc, dir) / span * 0.5 + 0.5) * FLAP_SWEEP + random(id + vec2(n, 2.2)) * FLAP_JITTER;

    int ev = 0, j, prv = 0, base = 10;
    float st = flapStart(n) + delay;
    int m = int(mix(FLAP_FLIPS.x, FLAP_FLIPS.y + 1., random(id + vec2(5.5, n))));
    int sl = flapSlot(id, flapPic(n), j);
    if(sl == 2){
        float e0 = flapTextAt(n, j);
        if(lt >= e0){
            ev = 1; st = e0;
            m = int(mix(FLAP_TEXT_FLIPS.x, FLAP_TEXT_FLIPS.y + 1., random(id + vec2(n, 8.1))));
        }
    }
    if(sl == 1 && j != 2){
        base = j == 0 ? 3 : j == 3 ? 6 : 10;
        prv = flapDigit(u_clock_prev, j);
        int cm = (flapDigit(iClock, j) - prv + base) % base;
        float c0 = u_clock_at + float(j) * FLAP_CLOCK_STAGGER;
        if(cm > 0 && c0 > st && lt >= c0){ ev = 2; st = c0; m = cm; }
    }

    float s = (lt - st) / FLAP_T;
    int k = int(floor(clamp(s, 0., float(m))));
    float p = s >= 0. && k < m ? fract(s) : 0.;

    ivec2 c0 = flapCard(ev, k, m, n, id, st, j, prv, base);
    if(p <= 0. && c0.x == 0 && (c0.y == FLAP_PREV || c0.y == FLAP_NEXT)) return c0.y == FLAP_PREV ? gPrevCol : gNextCol;
    vec2 face = vec2(FLAP_FACE * FLAP_ASPECT, FLAP_FACE);
    vec2 bq = abs(l) - face + FLAP_RAD;
    float box = (length(max(bq, 0.)) + min(max(bq.x, bq.y), 0.) - FLAP_RAD) * th;
    vec3 col = FLAP_HOUSING;

    ivec2 cA = flapCard(ev, k, m, n, id, st, j, prv, base);
    ivec2 cB = p > 0. ? flapCard(ev, k + 1, m, n, id, st, j, prv, base) : cA;
    vec3 under;
    float shade = 1.;
    if(p <= 0.){
        under = flapRender(cA, n, id, q, l, th);
    } else {
        under = flapRender(l.y > 0. ? cB : cA, n, id, q, l, th);
        if(l.y < 0.) shade = 1. - 0.35 * sin(3.1415927 * min(p * 2., 1.)) * (1. - smoothstep(0., 0.25, -l.y));
    }
    under *= (l.y > 0. ? 1.06 : 0.94) * shade;
    col = mix(col, under, S(box));

    if(p > 0.){
        float a = 3.1415927 * pow(p, 1.5);
        float ca = cos(a);
        float h = FLAP_FACE * abs(ca);
        bool top = ca > 0.;
        bool hit = top ? (l.y > 0. && l.y < h) : (l.y < 0. && l.y > -h);
        if(hit && abs(ca) > 0.02){
            float ys = l.y / abs(ca);
            float w = 1. + FLAP_WIDEN * sin(a) * abs(ys) / FLAP_FACE;
            vec2 ls = vec2(l.x / w, ys);
            vec2 gs = cc + ls * th;
            vec2 fq = abs(ls) - face + FLAP_RAD;
            float fbox = (length(max(fq, 0.)) + min(max(fq.x, fq.y), 0.) - FLAP_RAD) * th * min(abs(ca) * 4., 1.);
            vec3 fc = flapRender(top ? cA : cB, n, id, gs, ls, th);
            fc *= top ? mix(1.06, 0.55, sin(a)) : mix(0.94, 0.6, sin(a));
            col = mix(col, fc, S(fbox));
        }
    }
    col = mix(col, FLAP_HOUSING, S(abs(l.y * th) - FLAP_GAP * 0.5 * th) * S(box));
    return col;
}
// --- grid: flying through an endless lattice of flat amps ---------------------
// Flat amps face the camera on planes z = (k + 0.5) GRID_S, each plane a grid
// of amps GRID_S apart, so together they fill space. Nothing is marched: for
// each pixel the ray is intersected with the planes ahead, front to back,
// and at each crossing only the amp of that cell is tested (one glyph lookup,
// skipped outside its bounding circle), composited with coverage-based AA
// until opaque. The camera glides down the corridor along x = y = 0 with a
// gentle sway and roll, so the amps stream past on all sides. Each amp runs
// the usual clock (counter-spin, fill wipes) on its own phase and speed, and
// distance fog fades the far planes into a haze that runs from the brand
// gradient up close to pale cyan far off (GRID_DEPTH_K), with a slowly
// pulsing light at the end of the tunnel, round the forward axis. The
// fog factors step by a constant ratio per plane. Amps past GRID_LOD don't
// animate: a plain glyph, lit (blue) with the share of the loop an amp
// spends filled (GRID_LOD_LIT), else black.
const float GRID_S      = 1.6;
const float GRID_AMP    = 0.432;
const float GRID_BOUND  = 0.325;
const int   GRID_LAYERS = 64;
const float GRID_SPEED  = 0.7;
const vec2  GRID_SWAY   = vec2(0.12, 0.1);
const float GRID_ROLL   = 0.18;
const float GRID_FOCAL  = 1.3;
const vec2  GRID_CLOCK  = vec2(0.3, 1.);
const vec3  GRID_OFF    = vec3(0.);
const float GRID_FOG_K  = 0.018;
const float GRID_DEPTH_K = 0.03;
const vec3  GRID_FAR_COL = vec3(0.55, 0.88, 0.95);
const vec3  GRID_GLOW_COL = vec3(1., 1., 0.95);
const vec2  GRID_GLOW   = vec2(0.9, 0.35);
const vec2  GRID_GLOW_P = vec2(400., 30.);
const float GRID_PULSE  = 0.15;
const float GRID_LOD    = 24.;
const float GRID_LOD_LIT = 0.28;

vec3 grid(vec2 q, vec2 tp){
    float ct = iTime * GRID_SPEED;
    vec3 ro = vec3(GRID_SWAY.x * sin(ct * 0.37), GRID_SWAY.y * sin(ct * 0.29 + 1.), ct);
    vec3 fw = normalize(vec3(0.12 * sin(ct * 0.23), 0.08 * sin(ct * 0.19 + 2.), 1.));
    float rl = GRID_ROLL * sin(ct * 0.11);
    vec3 rt = normalize(cross(vec3(sin(rl), cos(rl), 0.), fw));
    vec3 up = cross(fw, rt);
    vec3 rd = normalize(q.x * rt + q.y * up + GRID_FOCAL * fw);

    vec3 near = mix(GRAD_BOT, GRAD_TOP, clamp(q.y + 0.5, 0., 1.));
    float ax = max(rd.z, 0.);
    float pulse = 1. + GRID_PULSE * sin(iTime * 0.6);
    vec3 far = GRID_FAR_COL + GRID_GLOW_COL * pulse * (GRID_GLOW.x * pow(ax, GRID_GLOW_P.x) + GRID_GLOW.y * pow(ax, GRID_GLOW_P.y));
    vec3 col = vec3(0.);
    float a = 0.;
    float k0 = floor(ro.z / GRID_S - 0.5) + 1.;
    float dtz = GRID_S / rd.z;
    float t = ((k0 + 0.5) * GRID_S - ro.z) / rd.z;
    vec2 pc = (ro.xy + rd.xy * t) / GRID_S;
    vec2 dpc = rd.xy * dtz / GRID_S;
    const float bound = (GRID_BOUND / GRID_S) * (GRID_BOUND / GRID_S);
    float pxk = 1. / (GRID_FOCAL * iResolution.y);
    float vis = exp(-t * GRID_FOG_K), visStep = exp(-dtz * GRID_FOG_K);
    float tint = exp(-t * GRID_DEPTH_K), tintStep = exp(-dtz * GRID_DEPTH_K);
    for(int i = 0; i < GRID_LAYERS; i++){
        vec2 l = fract(pc) - 0.5;
        if(dot(l, l) < bound){
            vec2 c = floor(pc);
            float n = random(c + (k0 + float(i)) * 7.31);
            vec2 gp = l * (GRID_S / GRID_AMP);
            float px = t * pxk;
            float cov, fill;
            if(t < GRID_LOD){
                float frame = mod(iTime * mix(GRID_CLOCK.x, GRID_CLOCK.y, n) * 2. * SPEED + n * LOOP_LEN, LOOP_LEN);
                vec2 pJ, pP;
                ampSpin(gp, frame, fract(n * 7.3) < 0.5 ? -1. : 1., pJ, pP);
                vec2 d = ampPieces(pJ, pP);
                cov = smoothstep(px, -px, min(d.x, d.y) * GRID_AMP);
                fill = cov > 0.001 ? smoothstep(px, -px, ampFill(pJ, pP, d, frame) * GRID_AMP) : 0.;
            } else {
                cov = smoothstep(px, -px, glyphDist(gp) * GRID_AMP);
                fill = fract(n * 13.7) < GRID_LOD_LIT ? 1. : 0.;
            }
            if(cov > 0.001){
                vec3 c3 = mix(GRID_OFF, ampGradient(gp), fill);
                c3 = mix(mix(near, far, 1. - tint), c3, vis);
                col += (1. - a) * cov * c3;
                a += (1. - a) * cov;
                if(a > 0.995) break;
            }
        }
        t += dtz;
        pc += dpc;
        vis *= visStep;
        tint *= tintStep;
    }
    return col + (1. - a) * far + bgNoise(tp) * 0.3;
}
// --- stars: the real night sky over Vienna, every star an amp -----------------
// The sky comes from sky.png in iChannel14 (gen_sky.py: Hipparcos stars to
// mag 5 with a sky-cell index, and the tour targets: constellations,
// asterisms, deep-sky objects, named stars and planets, with figures and
// names). u_lst is the local sidereal time when the pass was created; the sky
// turns from there at SKY_RATE, the real sidereal rate. u_planets holds Venus,
// Mars, Jupiter and Saturn for the day (unit vector, magnitude), worked out
// in scene.qml from orbital elements; u_algol is Algol's magnitude now,
// from its eclipse ephemeris. u_bodies (scene.qml, updated live) holds the
// Moon (direction, illuminated fraction), the Sun, and the ISS now and a few
// seconds ago (direction; 0 not up or no orbit, 1 in Earth's shadow, 2
// sunlit), propagated from its Celestrak TLE. The sky turns at the real
// sidereal rate, so all of it matches the real sky. The ecliptic (gold) and
// celestial equator (teal) are drawn as faint great circles, with a small
// ring round the north celestial pole; the Moon is a disc lit on the
// side facing the Sun (a real crescent or gibbous), mottled from the noise
// texture, the ISS the satellite emoji (baked into
// sky.png) with its trail.
// Every SKY_PERIOD a target that is well up is picked and the camera swings
// over to it (ease in-out over SKY_MOVE), holds it SKY_HOLD, takes it down
// again over SKY_OFF (lines retracting, stars shrinking) and rests until the
// next; its figure draws itself in line
// by line over SKY_DRAW (teal for constellations, gold for asterisms,
// dashed for star-hopping guides) or a
// marker ring opens round it, its stars swell (SKY_GROW) and glow in their
// own colour, and its name is set under it in the flap font (iChannel13). bufferStars works the
// target and camera out once per frame (SKY_FIG_W texels, iChannel15 in the
// main pass): x = 0 (target, envelope, label position), x = 1 the figure's
// screen bounding box, x = 2 (segments, name length, name width, type),
// x = 3 the camera axis, x = 4 (marker radius, draw-in progress, fade
// out), x = 5.. the deep-sky
// objects' screen circles (centre, radius, in front), then one texel per
// segment.
// Each pixel's ray is turned into RA/Dec and only the stars listed in its sky
// cell are drawn: an upright amp sized and brightened by magnitude, tinted by
// B-V, twinkling. Under them lie the Milky Way (a band about the galactic
// plane, a bulge towards the centre, the Great Rift, mottled by noise) and
// the deep-sky objects' glows; over them the planets, the odd meteor and a
// satellite now and then, all moving on great circles; a dark ridge cuts the
// horizon, and a horizon gizmo (skyGizmo) is drawn over everything.
const float SKY_LAT     = 0.84142;
const float SKY_RATE    = 7.2921159e-5;
const float SKY_FOCAL   = 1.;
const vec2  SKY_SIZE    = vec2(0.005, 0.028);
const vec2  SKY_BRIGHT  = vec2(0.45, 1.15);
const float SKY_MARGIN  = 0.02269;
const int   SKY_CELLS_RA = 48;
const int   SKY_CELLS_DEC = 24;
const int   SKY_TARGETS = 137;
const int   SKY_PLANET_FIRST = 131;
const int   SKY_DSO_FIRST = 103;
const int   SKY_DSO_N   = 10;
const int   SKY_SEGS    = 48;
const int   SKY_FIG_SEG = 5 + SKY_DSO_N;
const int   SKY_FIG_STAR = SKY_FIG_SEG + SKY_SEGS;
const int   SKY_FIG_W   = SKY_FIG_STAR + SKY_SEGS;
const int   SKY_NAME    = 25;
const float SKY_PERIOD  = 30.;
const float SKY_HOLD    = 20.;
const float SKY_OFF     = 2.;
const float SKY_MOVE    = 3.5;
const float SKY_DRAW    = 1.6;
const float SKY_STAGGER = 1.2;
const float SKY_GROW    = 0.8;
const float SKY_GROW_MAX = 0.034;
const float SKY_MIN_ALT = 0.3;
const float SKY_AIM_DROP = 0.06;
const vec2  SKY_ALT_RANGE = vec2(0.32, 1.15);
const vec3  SKY_TEAL    = vec3(0.25, 0.75, 0.82);
const vec3  SKY_GOLD    = vec3(0.95, 0.78, 0.45);
const vec3  SKY_GUIDE   = vec3(0.85, 0.9, 0.95);
const float SKY_DASH    = 0.014;
const vec3  SKY_ALGOL   = vec3(0.51468, 0.55267, 0.65536);
const vec3  SKY_ECLIPTIC = vec3(0., -0.39777, 0.91748);
const float SKY_CIRCLE  = 0.12;
const float SKY_MOON_R  = 0.035;
const vec3  SKY_MOON_LIT = vec3(0.95, 0.93, 0.86);
const vec3  SKY_MOON_DARK = vec3(0.09, 0.1, 0.13);
const float SKY_ISS_H   = 0.032;
const float SKY_ISS_DT  = 6.;
const float SKY_ISS_TRAIL = 5.;
const float SKY_TEXT_H  = 0.024;
const vec3  SKY_ZENITH  = vec3(0.003, 0.006, 0.02);
const vec3  SKY_HORIZON = vec3(0.03, 0.07, 0.11);
const vec3  SKY_GROUND  = vec3(0.004, 0.006, 0.01);
const float SKY_MW      = 0.075;
const vec3  SKY_NGP     = vec3(-0.86766, -0.19808, 0.45598);
const vec3  SKY_GC      = vec3(-0.05488, -0.87344, -0.48384);
const float SKY_DSO     = 0.35;
const vec3  SKY_PLANET_COL[4] = vec3[4](vec3(1., 0.98, 0.92), vec3(1., 0.6, 0.42), vec3(1., 0.93, 0.8), vec3(0.98, 0.88, 0.62));
const vec2  SKY_METEOR  = vec2(6., 0.5);
const float SKY_METEOR_T = 0.8;
const vec2  SKY_SAT     = vec2(40., 0.6);
const float SKY_SAT_T   = 30.;
const vec3  SKY_GIZMO   = vec3(0.45, 0.75, 0.8);
const vec3  SKY_GIZMO_A = vec3(0.07, 0.16, 0.3);
const float SKY_GIZMO_STEP = 0.261799;
const float SKY_GIZMO_H = 0.028;
const float SKY_COMPASS_EDGE = 0.035;
const int   SKY_COMPASS[16] = int[16](24, -1, 24, 15, 15, -1, 29, 15, 29, -1, 29, 33, 33, -1, 24, 33);

vec3 skyRGB(int i){ return floor(texelFetch(iChannel14, ivec2(i % 1024, i / 1024), 0).rgb * 255. + 0.5); }

vec3 skyVec(int i){
    vec3 a = skyRGB(i), b = skyRGB(i + 1);
    return vec3(a.x * 256. + a.y, a.z * 256. + b.x, b.y * 256. + b.z) / 65535. * 2. - 1.;
}

float skyNoise(float x){
    float i = floor(x), f = fract(x);
    return mix(random(vec2(i, 9.1)), random(vec2(i + 1., 9.1)), f * f * (3. - 2. * f));
}

float skyNoise3(vec3 p){
    vec3 i = floor(p), f = fract(p);
    f = f * f * (3. - 2. * f);
    float n = dot(i, vec3(1., 57., 113.));
    vec4 a = fract(sin(vec4(n, n + 1., n + 57., n + 58.)) * 43758.5453);
    vec4 b = fract(sin(vec4(n + 113., n + 114., n + 170., n + 171.)) * 43758.5453);
    vec4 m = mix(a, b, f.z);
    return mix(mix(m.x, m.y, f.x), mix(m.z, m.w, f.x), f.y);
}

// equatorial frame of the local horizon at time t: columns E, N, U
mat3 skyHorizon(float t){
    float lst = u_lst + t * SKY_RATE;
    vec3 U = vec3(cos(SKY_LAT) * cos(lst), cos(SKY_LAT) * sin(lst), sin(SKY_LAT));
    vec3 N = vec3(-sin(SKY_LAT) * cos(lst), -sin(SKY_LAT) * sin(lst), cos(SKY_LAT));
    return mat3(cross(N, U), N, U);
}

void skyCamera(vec3 fw, out vec3 rt, out vec3 up){
    rt = normalize(cross(fw, vec3(0., 0., 1.)));
    up = cross(rt, fw);
}

// screen position of a local (E, N, U) direction
vec2 skyScreen(vec3 l, vec3 fw, vec3 rt, vec3 up, out float z){
    z = dot(l, fw);
    return SKY_FOCAL * vec2(dot(l, rt), dot(l, up)) / max(z, 1e-4);
}

vec2 skyProject(vec3 s, mat3 H, vec3 fw, vec3 rt, vec3 up, out float z){
    return skyScreen(s * H, fw, rt, up, z);
}

int skyRec(int c){ return 36 * 1024 + 32 * c; }

// the ISS now: its position at the last update moved on along its motion over
// the SKY_ISS_DT before it, so it glides between updates
vec3 skyIss(out vec3 vel){
    vel = (u_bodies[2].xyz - u_bodies[3].xyz) / SKY_ISS_DT;
    return normalize(u_bodies[2].xyz + vel * (iTime - u_bodies[3].w));
}

// the emoji at x0 of sky.png's emoji rows (0 the satellite, 128 the shark)
// at uv (0..1, y down), premultiplied, bilinear
vec4 skyEmojiAt(vec2 uv, int x0){
    vec2 f = clamp(uv * 64. - 0.5, 0., 63.);
    ivec2 i = ivec2(floor(f));
    vec2 t = f - vec2(i);
    vec4 c[4];
    for(int k = 0; k < 4; k++){
        ivec2 o = min(i + ivec2(k & 1, k >> 1), ivec2(63));
        c[k] = vec4(texelFetch(iChannel14, ivec2(x0 + o.x, 56 + o.y), 0).rgb, texelFetch(iChannel14, ivec2(x0 + 64 + o.x, 56 + o.y), 0).r);
    }
    return mix(mix(c[0], c[1], t.x), mix(c[2], c[3], t.x), t.y);
}

vec4 skyEmoji(vec2 uv){ return skyEmojiAt(uv, 0); }

vec3 skyTarget(int c){
    vec3 t = skyRGB(skyRec(c) + 1);
    if(t.y == 4.) return u_planets[int(t.z)].xyz;
    if(t.y == 6.) return u_bodies[0].xyz;
    vec3 vel;
    if(t.y == 7.) return u_bodies[2].w > 0. ? skyIss(vel) : vec3(0.);
    return skyVec(skyRec(c) + 2);
}

// the target of period k: the first, from a hashed start, that is well up
// at the period's start
int skyPick(float k){
    mat3 H = skyHorizon(k * SKY_PERIOD);
    int base = int(random(vec2(k, 0.37)) * float(SKY_TARGETS));
    for(int j = 0; j < SKY_TARGETS; j++){
        int c = (base + j * 37) % SKY_TARGETS;
        if((skyTarget(c) * H).z > SKY_MIN_ALT) return c;
    }
    return base;
}

// camera axis looking at target c, kept within SKY_ALT_RANGE of altitude
vec3 skyAim(int c, mat3 H){
    vec3 l = skyTarget(c) * H;
    float az = atan(l.x, l.y), alt = clamp(asin(clamp(l.z, -1., 1.)) - SKY_AIM_DROP, SKY_ALT_RANGE.x, SKY_ALT_RANGE.y);
    return vec3(sin(az) * cos(alt), cos(az) * cos(alt), sin(alt));
}

vec4 skyFigure(int x){
    mat3 H = skyHorizon(iTime);
    float k = floor(iTime / SKY_PERIOD), ph = iTime - k * SKY_PERIOD;
    int act = skyPick(k);
    vec3 a0 = skyAim(skyPick(k - 1.), H), a1 = skyAim(act, H);
    float e = cubicInOut(clamp(ph / SKY_MOVE, 0., 1.));
    vec3 fw = normalize(mix(a0, a1, e) + 1e-4 * vec3(0., 0., 1.));
    vec3 rt, up;
    skyCamera(fw, rt, up);
    float off = SKY_MOVE + SKY_HOLD;
    float env = smoothstep(SKY_MOVE, SKY_MOVE + 1.5, ph) * (1. - smoothstep(off, off + SKY_OFF, ph));
    float z;
    vec2 lp = skyProject(skyTarget(act), H, fw, rt, up, z);
    if(x == 0) return vec4(float(act), env, lp);
    if(x == 3) return vec4(fw, 0.);
    int rec = skyRec(act);
    vec3 h0 = skyRGB(rec), h1 = skyRGB(rec + 1);
    int sf = int(h0.x * 256. + h0.y), sn = min(int(h0.z), SKY_SEGS);
    float ring = h1.y == 2. ? SKY_FOCAL * tan(radians(skyRGB(rec + 29).x / 40.) * 0.5) + 0.012 : h1.y == 6. ? SKY_MOON_R * 1.6 : h1.y == 7. ? SKY_ISS_H * 0.9 : 0.022;
    if(x == 4) return vec4(sn > 0 ? 0. : ring, min(clamp((ph - SKY_MOVE) / SKY_DRAW, 0., 1.), 1. - clamp((ph - off) / SKY_OFF, 0., 1.)), step(ph, off + SKY_OFF), 0.);
    if(x >= 5 && x < SKY_FIG_SEG){
        int r = skyRec(SKY_DSO_FIRST + x - 5);
        vec2 sp = skyProject(skyVec(r + 2), H, fw, rt, up, z);
        float rad = SKY_FOCAL * tan(radians(skyRGB(r + 29).x / 40.) * 1.5) / max(z, 0.05);
        return z > 0.05 ? vec4(sp, rad, 1.) : vec4(0.);
    }
    if(x == 1){
        if(sn == 0) return vec4(lp - ring, lp + ring);
        vec4 bb = vec4(1e9, 1e9, -1e9, -1e9);
        for(int i = 0; i < SKY_SEGS; i++){
            if(i >= sn) break;
            int o = 42 * 1024 + 6 * (sf + i);
            vec2 pa = skyProject(skyVec(o), H, fw, rt, up, z);
            vec2 pb = skyProject(skyVec(o + 2), H, fw, rt, up, z);
            bb = vec4(min(bb.xy, min(pa, pb)), max(bb.zw, max(pa, pb)));
        }
        return bb;
    }
    if(x == 2){
        int nl = int(h1.x);
        float w = 0.;
        for(int i = 0; i < SKY_NAME; i++){ if(i >= nl) break; w += skyRGB(rec + 4 + i).y / 255.; }
        return vec4(float(sn), float(nl), w, h1.y);
    }
    if(x >= SKY_FIG_STAR){
        int i = x - SKY_FIG_STAR;
        if(i >= sn) return vec4(0.);
        int o = 42 * 1024 + 6 * (sf + i);
        return vec4(skyRGB(o + 4).xy, skyRGB(o + 5).xy) / 255.;
    }
    int i = x - SKY_FIG_SEG;
    if(i >= sn) return vec4(0.);
    int o = 42 * 1024 + 6 * (sf + i);
    float za, zb;
    vec2 pa = skyProject(skyVec(o), H, fw, rt, up, za);
    vec2 pb = skyProject(skyVec(o + 2), H, fw, rt, up, zb);
    return za > 0.05 && zb > 0.05 ? vec4(pa, pb) : vec4(1e4);
}

vec3 skyMilkyWay(vec3 d){
    float b = asin(clamp(dot(d, SKY_NGP), -1., 1.));
    float l = atan(dot(d, cross(SKY_NGP, SKY_GC)), dot(d, SKY_GC));
    float band = exp(-b * b / 0.026);
    float bulge = exp(-l * l / 0.6) * exp(-b * b / 0.06);
    if(band + bulge < 0.01) return vec3(0.);
    vec2 gl = vec2(l * 0.6, b * 2.);
    float n = texture(iChannel1, fract(gl * 1.3)).r * 0.6 + texture(iChannel1, fract(gl * 4.1 + 0.37)).r * 0.4;
    float rift = 1. - 0.65 * exp(-(b - 0.03) * (b - 0.03) / 0.0012) * smoothstep(-0.9, -0.2, l) * smoothstep(1.7, 0.8, l);
    float mw = (band * (0.45 + 0.55 * n) + bulge * 0.8 * (0.7 + 0.3 * n)) * rift;
    return mix(vec3(0.5, 0.58, 0.75), vec3(0.85, 0.75, 0.6), bulge) * mw * SKY_MW;
}

vec3 skyDeep(vec3 d, vec2 q, int act){
    vec3 col = vec3(0.);
    for(int i = 0; i < SKY_DSO_N; i++){
        vec4 sb4 = texelFetch(iChannel15, ivec2(5 + i, 0), 0);
        if(sb4.w < 0.5 || length(q - sb4.xy) > sb4.z) continue;
        int c = SKY_DSO_FIRST + i, rec = skyRec(c);
        vec3 sh = skyRGB(rec + 29);
        float sa = radians(sh.x / 40.) * 0.5, sb = radians(sh.y / 40.) * 0.5;
        vec3 o = skyVec(rec + 2);
        vec3 ea = normalize(cross(vec3(0., 0., 1.), o)), no = cross(o, ea);
        vec2 p = vec2(dot(d, ea), dot(d, no));
        float pa = sh.z / 255. * 3.1415927;
        p = vec2(p.x * cos(pa) - p.y * sin(pa), p.x * sin(pa) + p.y * cos(pa));
        float r = length(vec2(p.x / sb, p.y / sa));
        float kind = skyRGB(rec + 1).z, g;
        if(kind == 0.) g = exp(-r * r * 6.) + 0.35 * exp(-r * 2.5);
        else if(kind == 1.) g = 0.35 * exp(-r * r * 2.) + 0.6 * step(0.985, random(floor(p / (sa * 0.08)))) * step(r, 1.);
        else if(kind == 2.) g = exp(-r * r * 1.6) * (0.4 + 0.6 * skyNoise3(vec3(p / sa * 3., 1.)));
        else g = exp(-(r - 0.7) * (r - 0.7) / 0.03) + 0.2 * exp(-r * r * 4.);
        col += skyRGB(rec + 30) / 255. * g * SKY_DSO * (c == act ? 1.8 : 1.);
    }
    return col;
}

// distance to a label of up to two characters (flap font indices, -1 none)
// centred at p, h tall
float skyLabel(vec2 q, vec2 p, int c0, int c1, float h){
    vec2 t = (q - p) / h;
    float n = c1 < 0 ? 1. : 2.;
    if(abs(t.y) > 0.5 || abs(t.x) > 0.25 * n + 0.3) return 1e9;
    float d = flapGlyph(c0, vec2(t.x + (n - 1.) * 0.24, t.y));
    if(c1 >= 0) d = min(d, flapGlyph(c1, vec2(t.x - 0.24, t.y)));
    return d * h;
}

// the horizon gizmo: altitude rings and meridians every SKY_GIZMO_STEP (the
// horizon and every third meridian stronger, meridians fading out at the
// zenith), compass points on the horizon (slid up their meridian to stay
// SKY_COMPASS_EDGE above the bottom of the screen) and altitudes up the meridian
// nearest the view; the compass points come back in over, to go on top of
// the ridge, the rest lies behind it
vec3 skyGizmo(vec2 q, vec3 rl, vec3 fw, vec3 rt, vec3 up, out vec3 over){
    float px = 1. / (SKY_FOCAL * iResolution.y);
    float alt = asin(clamp(rl.z, -1., 1.)), az = atan(rl.x, rl.y);
    float da = abs(alt - SKY_GIZMO_STEP * round(alt / SKY_GIZMO_STEP));
    float k = round(az / SKY_GIZMO_STEP), mz = k * SKY_GIZMO_STEP;
    float dm = abs(dot(rl, vec3(cos(mz), -sin(mz), 0.)));
    float major = mod(k, 3.) == 0. ? 1. : 0.;
    float ring = smoothstep(1.5 * px, 0.5 * px, da);
    float mer = smoothstep(1.5 * px, 0.5 * px, dm) * (1. - smoothstep(1.2, 1.45, alt));
    float hor = smoothstep(2. * px, 0.7 * px, abs(alt));
    float g = SKY_GIZMO_A.x * ring + SKY_GIZMO_A.x * mix(1., 1.6, major) * mer + SKY_GIZMO_A.z * hor;
    float dt = 1e9, dc = 1e9;
    float z;
    {
        float a = 0.785398 * round(az / 0.785398);
        int j = int(mod(round(az / 0.785398), 8.));
        vec3 h = vec3(sin(a), cos(a), 0.);
        float floorY = SKY_COMPASS_EDGE - 0.5;
        float lo = 0.035, hi = 1.2;
        vec2 sp = skyScreen(h * cos(lo) + vec3(0., 0., sin(lo)), fw, rt, up, z);
        if(z > 0.1 && sp.y < floorY){
            for(int k = 0; k < 12; k++){
                float m = 0.5 * (lo + hi);
                vec2 t = skyScreen(h * cos(m) + vec3(0., 0., sin(m)), fw, rt, up, z);
                if(t.y < floorY) lo = m; else hi = m;
            }
            sp = skyScreen(h * cos(hi) + vec3(0., 0., sin(hi)), fw, rt, up, z);
        }
        if(z > 0.1 && sp.y >= floorY - 0.001) dc = skyLabel(q, sp, SKY_COMPASS[2 * j], SKY_COMPASS[2 * j + 1], SKY_GIZMO_H);
    }
    int j = int(round(alt / SKY_GIZMO_STEP));
    if(j >= 1 && j <= 5){
        float am = 0.785398 * round(atan(fw.x, fw.y) / 0.785398), al = float(j) * SKY_GIZMO_STEP;
        vec2 sp = skyScreen(vec3(sin(am) * cos(al), cos(am) * cos(al), sin(al)), fw, rt, up, z);
        int v = j * 15;
        if(z > 0.1) dt = min(dt, skyLabel(q, sp + vec2(0.022, 0.012), v / 10, v % 10, SKY_GIZMO_H * 0.8));
    }
    over = SKY_GIZMO * SKY_GIZMO_A.y * 4. * S(dc);
    return SKY_GIZMO * (g + SKY_GIZMO_A.y * 4. * S(dt));
}

// how far segment i of n has drawn in at progress p (segments start one
// after another, each growing from its first star)
float skyReveal(float p, int i, int n){
    return clamp(p * (1. + SKY_STAGGER) - SKY_STAGGER * float(i) / float(max(n, 1)), 0., 1.);
}

// how much the star at screen position sp is highlighted as a point target
// (figure stars are drawn over by the figure pass)
float skyLit(vec2 sp, vec4 f0, vec4 f2, vec4 f4){
    if(f0.y <= 0. && f4.y <= 0.) return 0.;
    float g = 0.;
    int sn = int(f2.x);
    if(sn == 0) return length(sp - f0.zw) < 0.004 ? cubicInOut(f4.y) * f4.z : 0.;
    return 0.;
}

// a point moving on a great circle in local (E, N, U), seeded by h
vec3 skyTrack(float h, float ang){
    float az = 6.2831853 * random(vec2(h, 1.1)), alt = 0.35 + 0.6 * random(vec2(h, 2.3));
    vec3 s = vec3(sin(az) * cos(alt), cos(az) * cos(alt), sin(alt));
    float th = 6.2831853 * random(vec2(h, 3.7));
    vec3 a = normalize(cross(s, vec3(0., 0., 1.)));
    vec3 t = a * cos(th) + cross(s, a) * sin(th);
    return normalize(s * cos(ang) + t * sin(ang));
}

vec3 stars(vec2 q, vec2 tp){
    mat3 H = skyHorizon(iTime);
    vec3 fw = texelFetch(iChannel15, ivec2(3, 0), 0).xyz, rt, up;
    if(dot(fw, fw) < 0.5) fw = vec3(0., -cos(0.4), sin(0.4));
    fw = normalize(fw);
    skyCamera(fw, rt, up);
    vec3 rl = normalize(q.x * rt + q.y * up + SKY_FOCAL * fw);
    vec4 f0 = texelFetch(iChannel15, ivec2(0, 0), 0);
    vec4 f4 = texelFetch(iChannel15, ivec2(4, 0), 0);
    int act = f4.z > 0. ? int(f0.x) : -1;
    vec4 f2 = texelFetch(iChannel15, ivec2(2, 0), 0);
    vec4 bb = texelFetch(iChannel15, ivec2(1, 0), 0);
    vec2 lab = abs(q - vec2(f0.z, bb.y - 0.045)) - vec2((0.5 * f2.z + 0.5) * SKY_TEXT_H, SKY_TEXT_H);
    bool nearFig = act >= 0 && ((all(greaterThan(q, bb.xy - 0.08)) && all(lessThan(q, bb.zw + 0.08))) || max(lab.x, lab.y) < 0.);

    vec3 col = mix(SKY_HORIZON, SKY_ZENITH, smoothstep(0., 0.7, rl.z));
    float raz = atan(rl.x, rl.y);
    float ridge = 0.012 + 0.025 * skyNoise(raz * 7.) + 0.01 * skyNoise(raz * 31.);
    float ground = smoothstep(0.0015, -0.0015, rl.z - ridge);

    if(ground < 1.){
        vec3 d = H * rl;
        col += skyMilkyWay(d) + skyDeep(d, q, act);
        float pxa = 1. / (SKY_FOCAL * iResolution.y);
        col += SKY_GOLD * SKY_CIRCLE * smoothstep(1.5 * pxa, 0.5 * pxa, abs(dot(d, SKY_ECLIPTIC)));
        col += SKY_TEAL * SKY_CIRCLE * smoothstep(1.5 * pxa, 0.5 * pxa, abs(d.z));
        col += SKY_TEAL * 0.5 * smoothstep(1.5 * pxa, 0.5 * pxa, abs(acos(clamp(d.z, -1., 1.)) - 0.014));

        float ra = mod(atan(d.y, d.x), 6.2831853);
        float dec = asin(clamp(d.z, -1., 1.));
        int rb = min(int(ra / 6.2831853 * float(SKY_CELLS_RA)), SKY_CELLS_RA - 1);
        int db = clamp(int((dec / 3.1415927 + 0.5) * float(SKY_CELLS_DEC)), 0, SKY_CELLS_DEC - 1);
        vec3 cl = skyRGB(32 * 1024 + db * SKY_CELLS_RA + rb);
        int first = int(cl.x * 256. + cl.y), count = int(cl.z);
        float cm = cos(SKY_MARGIN);
        int sn = nearFig ? int(f2.x) : 0;
        float dl = 1e9, dpt = 1e9, along = 0.;
        vec2 fsp = vec2(1e4), mb = vec2(0.);
        for(int i = 0; i < SKY_SEGS; i++){
            if(i >= sn) break;
            float r = skyReveal(f4.y, i, sn);
            if(r <= 0.) continue;
            vec4 sg = texelFetch(iChannel15, ivec2(SKY_FIG_SEG + i, 0), 0);
            vec2 e = mix(sg.xy, sg.zw, r), ab = e - sg.xy;
            float hh = clamp(dot(q - sg.xy, ab) / max(dot(ab, ab), 1e-8), 0., 1.);
            float dd = length(q - sg.xy - ab * hh);
            if(dd < dl){ dl = dd; along = hh * length(ab); }
            float da = length(q - sg.xy), db = r >= 1. ? length(q - sg.zw) : 1e9;
            if(min(da, db) < dpt){
                vec4 st = texelFetch(iChannel15, ivec2(SKY_FIG_STAR + i, 0), 0);
                dpt = min(da, db);
                fsp = da < db ? sg.xy : sg.zw;
                mb = da < db ? st.xy : st.zw;
            }
        }
        for(int i = 0; i < 64; i++){
            if(i >= count) break;
            int r = 3 * (first + i);
            vec3 s = skyVec(r);
            if(dot(d, s) < cm) continue;
            vec3 m = skyRGB(r + 2);
            float mag = m.x / 255. * 8. - 2., bv = m.y / 255. * 2.4 - 0.4;
            if(dot(s, SKY_ALGOL) > 0.99999) mag = u_algol;
            float z;
            vec2 sp = skyProject(s, H, fw, rt, up, z);
            if(z <= 0. || length(sp - fsp) < 0.003) continue;
            float b = clamp((5. - mag) / 6.5, 0., 1.);
            float lit = nearFig ? skyLit(sp, f0, f2, f4) : 0.;
            float h0 = mix(SKY_SIZE.x, SKY_SIZE.y, b * b);
            float h = mix(h0, max(min(h0 * (1. + SKY_GROW), SKY_GROW_MAX), h0), lit);
            float rr = length(q - sp);
            float hs = random(vec2(float(first + i), 4.2) + s.xy);
            vec3 tint = mix(vec3(0.72, 0.84, 1.), vec3(1., 0.84, 0.62), clamp(bv / 1.6, 0., 1.));
            float tw = 1. + 0.3 * (1. - b) * (1. - lit) * sin(iTime * (2. + 6. * hs) + hs * 40.);
            col += tint * b * b * 0.15 * exp(-rr / (h * 0.7));
            col += tint * lit * 0.4 * exp(-rr * rr / (h * h * 0.2));
            if(rr < h){
                float cov = S(glyphDist((q - sp) / h) * h);
                col = mix(col, tint * mix(mix(SKY_BRIGHT.x, SKY_BRIGHT.y, b), 1.3, lit) * tw, cov);
            }
        }

        for(int i = 0; i < 4; i++){
            vec4 pl = u_planets[i];
            if(dot(pl.xyz, pl.xyz) < 0.5) continue;
            float z;
            vec2 sp = skyProject(pl.xyz, H, fw, rt, up, z);
            if(z <= 0.) continue;
            float b = clamp((2. - pl.w) / 6.5, 0.3, 1.);
            float lit = act == SKY_PLANET_FIRST + i ? cubicInOut(f4.y) * f4.z : 0.;
            float h = SKY_SIZE.y * mix(1., 1.4, b) * (1. + SKY_GROW * lit);
            float rr = length(q - sp);
            col += SKY_PLANET_COL[i] * (0.25 * b * exp(-rr / (h * 0.8)) + 0.5 * lit * exp(-rr * rr / (h * h * 0.2)));
            if(rr < h) col = mix(col, SKY_PLANET_COL[i] * 1.2, S(glyphDist((q - sp) / h) * h));
        }

        vec4 mo = u_bodies[0];
        if(dot(mo.xyz, mo.xyz) > 0.5){
            float z;
            vec2 sp = skyProject(mo.xyz, H, fw, rt, up, z);
            if(z > 0.){
                float rr = length(q - sp);
                col += vec3(0.55, 0.6, 0.7) * 0.2 * mo.w * exp(-rr / 0.12);
                if(rr < SKY_MOON_R * 1.1){
                    vec2 dk = (q - sp) / SKY_MOON_R;
                    vec3 sl = u_bodies[1].xyz * H, ml = mo.xyz * H;
                    vec3 sc = normalize(vec3(dot(sl, rt), dot(sl, up), -dot(sl, ml)));
                    vec3 n = vec3(dk, sqrt(max(1. - dot(dk, dk), 0.)));
                    float alb = 0.75 + 0.25 * texture(iChannel1, fract(dk * 0.35 + 0.5)).r - 0.18 * smoothstep(0.55, 0.75, texture(iChannel1, fract(dk * 0.12 + 0.23)).r);
                    vec3 mc = mix(SKY_MOON_DARK, SKY_MOON_LIT * alb, smoothstep(-0.03, 0.05, dot(n, sc)));
                    col = mix(col, mc, S(rr - SKY_MOON_R));
                }
            }
        }
        if(u_bodies[2].w > 0.){
            vec3 vel;
            vec3 id = skyIss(vel);
            float z, zp;
            vec2 sp = skyProject(id, H, fw, rt, up, z);
            vec2 pp = skyProject(normalize(id - vel * SKY_ISS_TRAIL), H, fw, rt, up, zp);
            if(z > 0. && zp > 0.){
                bool lit = u_bodies[2].w > 1.5;
                vec3 ic = lit ? vec3(1.) : vec3(0.55, 0.3, 0.25);
                vec2 ab = sp - pp;
                float u = clamp(dot(q - pp, ab) / max(dot(ab, ab), 1e-8), 0., 1.);
                float dt = length(q - pp - ab * u);
                col += ic * 0.5 * u * (S(dt - 0.0005) + 0.3 * exp(-dt / 0.003));
                col += ic * 0.25 * exp(-length(q - sp) / 0.015);
                vec2 uv = vec2(q.x - sp.x, sp.y - q.y) / SKY_ISS_H + 0.5;
                if(all(greaterThanEqual(uv, vec2(0.))) && all(lessThanEqual(uv, vec2(1.)))){
                    vec4 e = skyEmoji(uv);
                    col = col * (1. - e.a) + e.rgb * (lit ? 1. : 0.45) * (lit ? vec3(1.) : vec3(1., 0.7, 0.65));
                }
            }
        }

        float mk = floor(iTime / SKY_METEOR.x);
        float mt = iTime - mk * SKY_METEOR.x - random(vec2(mk, 5.5)) * (SKY_METEOR.x - SKY_METEOR_T);
        if(random(vec2(mk, 6.6)) < SKY_METEOR.y && mt > 0. && mt < SKY_METEOR_T){
            float th = mt * 0.7;
            vec3 hd = skyTrack(mk, th), tl = skyTrack(mk, max(th - 0.12 * min(mt * 4., 1.), 0.));
            float za, zb;
            vec2 pa = skyScreen(hd, fw, rt, up, za), pb = skyScreen(tl, fw, rt, up, zb);
            if(za > 0.1 && zb > 0.1){
                vec2 ab = pa - pb;
                float u = clamp(dot(q - pb, ab) / max(dot(ab, ab), 1e-8), 0., 1.);
                float dm = length(q - pb - ab * u);
                col += vec3(0.85, 0.93, 1.) * u * u * (1. - mt / SKY_METEOR_T) * (S(dm - 0.0006) + 0.4 * exp(-dm / 0.003));
            }
        }
        float sk = floor(iTime / SKY_SAT.x), st = iTime - sk * SKY_SAT.x;
        if(random(vec2(sk, 7.7)) < SKY_SAT.y && st < SKY_SAT_T){
            float z;
            vec2 sp = skyScreen(skyTrack(sk + 100., (st - SKY_SAT_T * 0.5) * 0.035), fw, rt, up, z);
            if(z > 0.1) col += vec3(0.9) * smoothstep(1., 0.4, st / SKY_SAT_T) * smoothstep(0., 2., st) * exp(-length(q - sp) / 0.0015);
        }

        if(nearFig){
            vec3 ink = f2.w == 1. ? SKY_GOLD : f2.w == 5. ? SKY_GUIDE : SKY_TEAL;
            float env = f0.y;
            if(sn > 0){
                float dash = f2.w == 5. ? step(0.45, fract(along / SKY_DASH)) : 1.;
                col += ink * f4.z * dash * (0.85 * S(dl - 0.0007) + 0.15 * exp(-dl / 0.004)) * smoothstep(0.012, 0.022, dpt);
                float mag = mb.x * 8. - 2., bv = mb.y * 2.4 - 0.4;
                float b = clamp((5. - mag) / 6.5, 0., 1.);
                float h0 = mix(SKY_SIZE.x, SKY_SIZE.y, b * b);
                float h = mix(h0, max(min(h0 * (1. + SKY_GROW), SKY_GROW_MAX), h0), f4.z);
                vec3 tint = mix(vec3(0.72, 0.84, 1.), vec3(1., 0.84, 0.62), clamp(bv / 1.6, 0., 1.));
                col += tint * f4.z * 0.4 * exp(-dpt * dpt / (h * h * 0.2));
                if(dpt < h) col = mix(col, tint * mix(mix(SKY_BRIGHT.x, SKY_BRIGHT.y, b), 1.3, f4.z), S(glyphDist((q - fsp) / h) * h));
            } else {
                float dr = abs(length(q - f0.zw) - f4.x * cubicInOut(f4.y));
                col += ink * f4.z * step(0.001, f4.y) * (0.8 * S(dr - 0.0006) + 0.15 * exp(-dr / 0.003));
            }

            int rec = skyRec(act);
            int nl = int(f2.y);
            float w = f2.z;
            vec2 tq = (q - vec2(f0.z, bb.y - 0.045)) / SKY_TEXT_H;
            if(abs(tq.y) < 0.5 && abs(tq.x) < 0.5 * w + 0.5){
                float x = -0.5 * w, dt = 1e9;
                for(int i = 0; i < SKY_NAME; i++){
                    if(i >= nl) break;
                    vec3 ch = skyRGB(rec + 4 + i);
                    float adv = ch.y / 255.;
                    float cx = x + 0.5 * adv;
                    if(ch.x < 255. && abs(tq.x - cx) < 0.4) dt = min(dt, flapGlyph(int(ch.x), vec2(tq.x - cx, tq.y)));
                    x += adv;
                }
                col = mix(col, ink, S(dt * SKY_TEXT_H) * env);
            }
        }
    }
    vec3 over;
    col += skyGizmo(q, rl, fw, rt, up, over);
    col = mix(col, SKY_GROUND, ground) + over;
    return col + bgNoise(tp) * 0.2;
}
// --- shatter: a glass amp shot three times, bursting and rewinding ----------
// A transition, SH_PERIOD long on its own clock: the old scene dims away
// (SH_DIM) as a glass amp (SH_SCALE tall) takes bullets at SH_HITS
// times, each at one of the SH_SPOTS points inside the glyph: a flash, a hole,
// and a web of cracks round it. The cracks and shards come from a Voronoi
// in log-polar space round the impact (SH_SECTORS round, rings growing
// outwards), so pieces are small at the hole and large far from it. The
// last hit bursts it along that impact's pattern: every piece flies off away
// from the hole (faster the closer it was), tumbling and falling out of the
// frame. SH_TEXT_AT after the burst FLAP_TEXT pops in on an ease-out-back
// in Montserrat (the flap font atlas, SH_ADV advances in cell heights) and
// holds until it shrinks away as the period ends, when a new amp flies in, growing out
// of the distance on a fast ease-out-back (SH_IN). A
// pixel finds its piece by undoing each nearby piece's motion and checking
// that the point it lands on belongs to that piece; as every piece flies
// straight out from the hole (plus the shared lift and fall), only the
// SH_REACH sectors either side of the pixel's own direction are tried.
const float SH_PERIOD   = T_SHATTER;
const float SH_SCALE    = TRANS_AMP;
const vec3  SH_HITS     = vec3(2.2, 3., 3.8);
const float SH_IN       = 0.55;
const float SH_SECTORS  = 13.;
const float SH_RING     = 2.6;
const int   SH_RINGS    = 10;
const float SH_SPEED    = 0.16;
const float SH_GRAVITY  = 0.8;
const float SH_SPIN     = 3.;
const float SH_CRACK    = 0.045;
const int   SH_REACH    = 2;
const float SH_TEXT_AT  = 1.;
const float SH_DIM      = 0.45;
const float SH_TEXT_IN  = 0.5;
const float SH_TEXT_OUT = 0.35;
const float SH_TEXT_H   = 0.08;
const float SH_TEXT_W   = 6.188;
const float SH_ADV[FLAP_TEXT_LEN] = float[FLAP_TEXT_LEN](0.228, 0.303, 0.174, 0.368, 0.197, 0.303, 0.206, 0.752, 0.444, 0.197,
                                                         0.303, 0.461, 0.197, 0.490, 0.486, 0.206, 0.206, 0.491, 0.174);
const int   SH_N_SPOTS  = 16;
const vec2  SH_SPOTS[SH_N_SPOTS] = vec2[SH_N_SPOTS](
    vec2(0.111, -0.353), vec2(0.056, 0.389), vec2(-0.194, 0.325), vec2(-0.272, -0.347),
    vec2(0.272, -0.383), vec2(0.259, -0.169), vec2(-0.103, 0.420), vec2(-0.155, 0.071),
    vec2(-0.266, -0.068), vec2(-0.210, 0.197), vec2(0.178, 0.342), vec2(0.039, -0.081),
    vec2(0.011, -0.427), vec2(-0.316, -0.227), vec2(-0.156, -0.422), vec2(0.136, -0.213));

vec2 shSpot(float k, int h){
    return SH_SPOTS[int(random(vec2(k, float(h) * 3.7 + 0.4)) * float(SH_N_SPOTS)) % SH_N_SPOTS];
}

vec2 shSeed(vec2 cell, float key){
    return cell + 0.15 + 0.7 * vec2(random(cell + key), random(cell.yx + key + 7.3));
}

// log-polar coordinates of glyph point g round impact c
vec2 shPolar(vec2 g, vec2 c){
    vec2 v = g - c;
    return vec2(atan(v.y, v.x) / 6.2831853 * SH_SECTORS, log(length(v) + 0.02) * SH_RING);
}

// nearest Voronoi seed's cell (x) and F2 - F1 (y, crack distance) at log-polar u
vec3 shVoronoi(vec2 u, float key, out vec2 nrm){
    vec2 iu = floor(u);
    float d1 = 1e9, d2 = 1e9;
    vec2 best = vec2(0.), s1 = vec2(0.), s2 = vec2(0.);
    for(int j = -1; j <= 1; j++) for(int i = -1; i <= 1; i++){
        vec2 c = iu + vec2(i, j);
        vec2 cw = vec2(mod(c.x, SH_SECTORS), c.y);
        vec2 sp = c + (shSeed(cw, key) - cw);
        float d = length(u - sp);
        if(d < d1){ d2 = d1; s2 = s1; d1 = d; s1 = sp; best = cw; } else if(d < d2){ d2 = d; s2 = sp; }
    }
    nrm = normalize(s2 - s1 + 1e-6);
    return vec3(best, d2 - d1);
}

// colour of a crack through glyph point g round impact c whose Voronoi edge
// has log-polar normal n: the edge's direction on the glass, carried back
// from log-polar space, decides how much of the light it catches, from deep
// amp blue to a bright teal glint
vec3 shCrackColour(vec2 g, vec2 c, vec2 n){
    vec2 er = normalize(g - c + 1e-6), et = vec2(-er.y, er.x);
    vec2 en = normalize(et * n.x * SH_SECTORS / 6.2831853 + er * n.y * SH_RING);
    float lit = abs(dot(en, normalize(vec2(-0.6, 0.8))));
    return mix(GRAD_BOT * 0.45, mix(GRAD_TOP, vec3(1.), 0.45) * 1.25, lit * lit);
}

// a piece's centre in glyph space
vec2 shCentre(vec2 cell, vec2 c, float key){
    vec2 s = shSeed(cell, key);
    float a = s.x / SH_SECTORS * 6.2831853, r = exp(s.y / SH_RING) - 0.02;
    return c + r * vec2(cos(a), sin(a));
}

vec3 shGlass(vec2 g, float lit){
    return ampGradient(g) * (0.85 + 0.3 * lit) + vec3(0.25) * pow(max(lit, 0.), 6.);
}

vec3 shatter(vec2 q, vec2 tp){
    float k = gModeK[MODE_SHATTER], ph = gModeT[MODE_SHATTER];
    vec3 col = mix(gPrevCol, bgNoise(tp), smoothstep(0., SH_DIM, ph));
    vec2 g = q / SH_SCALE;
    float px = 1. / (iResolution.y * SH_SCALE);
    float arrive = clamp(ph / SH_IN, 0., 1.);
    float back = arrive - 1., grow = 1. + 2.70158 * back * back * back + 1.70158 * back * back;
    vec2 gi = g / max(grow, 1e-3);
    vec2 c3 = shSpot(k, 2);
    float key = k * 1.37;

    float fly = max(ph - SH_HITS.z, 0.);

    if(fly <= 0.){
        g = gi;
        float d = glyphDist(g);
        if(d < 4. * px){
            float lit = 0.5 + 0.5 * dot(normalize(vec2(glyphDist(g + vec2(.01, 0.)) - glyphDist(g - vec2(.01, 0.)), glyphDist(g + vec2(0., .01)) - glyphDist(g - vec2(0., .01))) + 1e-6), normalize(vec2(-0.6, 0.8)));
            vec3 gc = shGlass(g, smoothstep(-0.03, 0., d) * lit);
            for(int h = 0; h < 3; h++){
                if(ph < SH_HITS[h]) continue;
                vec2 c = shSpot(k, h);
                vec2 cn;
                vec3 v = shVoronoi(shPolar(g, c), key + float(h) * 11., cn);
                float r = length(g - c);
                float crack = smoothstep(SH_CRACK * (0.4 + r), 0., v.z) * smoothstep(0.55, 0.05, r) * smoothstep(0., 0.15, ph - SH_HITS[h]);
                gc = mix(gc, shCrackColour(g, c, cn), crack * 0.9);
                gc = mix(gc, vec3(0.02), smoothstep(0.018, 0.01, r));
            }
            col = mix(col, gc, S(d * SH_SCALE * grow) * step(0.001, grow));
        }
    } else {
        float f = fly;
        vec2 rq = g - c3 - vec2(0., 0.15 * f - 0.5 * SH_GRAVITY * f * f);
        int s0 = int(floor(atan(rq.y, rq.x) / 6.2831853 * SH_SECTORS));
        for(int j = 0; j < SH_RINGS; j++){
            for(int di = -SH_REACH; di <= SH_REACH; di++){
                int i = (s0 + di + 4 * int(SH_SECTORS)) % int(SH_SECTORS);
                vec2 cell = vec2(float(i), float(j - SH_RINGS));
                vec2 cs = shCentre(cell, c3, key);
                vec2 dir = cs - c3;
                float dl = length(dir);
                vec2 vel = dir / max(dl, 1e-3) * SH_SPEED * (0.6 + 0.8 * random(cell + key + 2.2)) / (dl + 0.15) + vec2(0., 0.15);
                vec2 off = vel * f + vec2(0., -0.5 * SH_GRAVITY * f * f);
                float th = SH_SPIN * (random(cell + key + 5.1) - 0.5) * f;
                vec2 rel = g - cs - off;
                float rad = dl * 0.8 + 0.04;
                if(dot(rel, rel) > rad * rad) continue;
                vec2 g0 = cs + mat2(cos(th), -sin(th), sin(th), cos(th)) * rel;
                if(glyphDist(g0) > 0.) continue;
                vec2 cn;
                vec3 v = shVoronoi(shPolar(g0, c3), key + 22., cn);
                if(any(notEqual(v.xy, cell))) continue;
                float lit = 0.5 + 0.5 * cos(th * 1.7 + float(i));
                vec3 pc = shGlass(g0, lit) * mix(0.7, 1.1, lit);
                pc = mix(pc, shCrackColour(g0, c3, cn), smoothstep(0.06, 0.0, v.z) * 0.7);
                float edge = min(glyphDist(g0) * -1., v.z * 0.05);
                col = mix(col, pc, smoothstep(0., 2. * px, edge));
            }
        }
    }

    for(int h = 0; h < 3; h++){
        float dt = ph - SH_HITS[h];
        if(dt < 0. || dt > 0.6) continue;
        vec2 c = shSpot(k, h);
        float r = length(g - c);
        col += vec3(1., 0.95, 0.85) * exp(-dt * 10.) * (exp(-r / 0.04) + 0.6 * exp(-r / 0.2));
        col += vec3(0.9) * smoothstep(0.012, 0., abs(r - dt * 0.9)) * (1. - dt / 0.6) * 0.5;
    }

    col = mix(col, gNextCol, smoothstep(SH_PERIOD - SH_TEXT_OUT, SH_PERIOD, ph));
    float tin = clamp((ph - SH_HITS.z - SH_TEXT_AT) / SH_TEXT_IN, 0., 1.);
    float tout = clamp((ph - SH_PERIOD + SH_TEXT_OUT) / SH_TEXT_OUT, 0., 1.);
    float tb = tin - 1., ts = (1. + 2.70158 * tb * tb * tb + 1.70158 * tb * tb) * (1. - tout * tout * tout);
    if(ts > 0.001){
        float h = SH_TEXT_H * ts;
        vec2 tq = q / h;
        if(abs(tq.y) < 0.5 && abs(tq.x) < 0.5 * SH_TEXT_W + 0.5){
            float x = -0.5 * SH_TEXT_W, dt = 1e9;
            for(int i = 0; i < FLAP_TEXT_LEN; i++){
                float cx = x + 0.5 * SH_ADV[i];
                if(abs(tq.x - cx) < 0.4) dt = min(dt, flapGlyph(FLAP_TEXT[i], vec2(tq.x - cx, tq.y)));
                x += SH_ADV[i];
            }
            col = mix(col, vec3(0.95), S(dt * h));
        }
    }
    return col;
}
// --- title: the amp and the tagline -----------------------------------------
// A transition, T_TITLE long on its own clock: the old scene dims away over
// TI_FADE, then the amp (TI_AMP tall) and FLAP_TEXT pop in one
// after the other on an ease-out-back (TI_AT, TI_IN), hold, shrink away in
// turn (TI_OUT) and the new scene comes up over the last TI_FADE. Text is
// Montserrat from the flap font atlas, TI_TAG_ADV advances in cell heights.
const float TI_FADE   = 0.45;
const vec2  TI_AT     = vec2(0.35, 0.6);
const float TI_IN     = 0.6;
const float TI_OUT    = 0.35;
const float TI_LEAVE  = 0.08;
const float TI_AMP    = 0.35 * TRANS_AMP;
const float TI_AMP_Y  = 0.05;
const float TI_TAG_Y  = -0.1;
const float TI_TAG_H  = 0.08;
const float TI_TAG_W  = 6.193;
const float TI_TAG_ADV[FLAP_TEXT_LEN] = float[FLAP_TEXT_LEN](0.228, 0.303, 0.174, 0.368, 0.197, 0.303, 0.207, 0.753, 0.445, 0.197,
                                                             0.303, 0.461, 0.197, 0.490, 0.487, 0.207, 0.207, 0.491, 0.174);

float tiScale(float ph, int i){
    float a = clamp((ph - TI_AT[i]) / TI_IN, 0., 1.), b = a - 1.;
    float o = clamp((ph - (T_TITLE - TI_FADE - TI_OUT - float(1 - i) * TI_LEAVE)) / TI_OUT, 0., 1.);
    return (1. + 2.70158 * b * b * b + 1.70158 * b * b) * (1. - o * o * o);
}

float tiTag(vec2 tq){
    float x = -0.5 * TI_TAG_W, d = 1e9;
    for(int i = 0; i < FLAP_TEXT_LEN; i++){
        float cx = x + 0.5 * TI_TAG_ADV[i];
        if(abs(tq.x - cx) < 0.4) d = min(d, flapGlyph(FLAP_TEXT[i], vec2(tq.x - cx, tq.y)));
        x += TI_TAG_ADV[i];
    }
    return d;
}

vec3 title(vec2 q, vec2 tp){
    float ph = gModeT[MODE_TITLE];
    vec3 col = mix(gPrevCol, bgNoise(tp), smoothstep(0., TI_FADE, ph));
    col = mix(col, gNextCol, smoothstep(T_TITLE - TI_FADE, T_TITLE, ph));

    float s = tiScale(ph, 0) * TI_AMP;
    if(s > 0.001){
        vec2 g = (q - vec2(0., TI_AMP_Y)) / s;
        if(abs(g.y) < 0.6 && abs(g.x) < 0.6) col = mix(col, ampGradient(g), S(glyphDist(g) * s));
    }
    float h = tiScale(ph, 1) * TI_TAG_H;
    if(h > 0.001){
        vec2 tq = (q - vec2(0., TI_TAG_Y)) / h;
        if(abs(tq.y) < 0.5 && abs(tq.x) < 0.5 * TI_TAG_W + 0.5) col = mix(col, vec3(0.95), S(tiTag(tq) * h));
    }
    return col;
}

// --- shared by the transitions after this one --------------------------------
// tcCard draws the amp (TC_AMP tall) and the tagline under it round c, each
// scaled about its own centre (as, ts); tcBack is the ease-out-back the cards
// pop in on, tcPop one in at `at` and out from `leave`; tcFbm is value noise
const float TC_AMP     = 0.5 * TRANS_AMP;
const vec2  TC_AMP_OFF = vec2(0., 0.07);
const vec2  TC_TAG_OFF = vec2(0., -0.125);

float tcBack(float x){
    x = clamp(x, 0., 1.);
    float b = x - 1.;
    return 1. + 2.70158 * b * b * b + 1.70158 * b * b;
}

float tcPop(float t, float at, float leave){
    float o = clamp((t - leave) / TI_OUT, 0., 1.);
    return tcBack((t - at) / TI_IN) * (1. - o * o * o);
}

float tcAmpD(vec2 q, vec2 c, float s){
    if(s < 1e-3) return 1.;
    vec2 g = (q - c - TC_AMP_OFF) / (TC_AMP * s);
    float box = max(abs(g.x), abs(g.y));
    return (box < 0.8 ? glyphDist(g) : box - 0.5) * TC_AMP * s;
}

float tcTagD(vec2 q, vec2 c, float s){
    if(s < 1e-3) return 1.;
    float h = TI_TAG_H * s;
    vec2 tq = (q - c - TC_TAG_OFF) / h;
    if(abs(tq.y) > 0.5 || abs(tq.x) > 0.5 * TI_TAG_W + 0.5) return h;
    return min(tiTag(tq), 1.) * h;
}

vec3 tcCard(vec3 col, vec2 q, vec2 c, float as, float ts){
    if(as > 1e-3){
        vec2 g = (q - c - TC_AMP_OFF) / (TC_AMP * as);
        if(abs(g.x) < 0.6 && abs(g.y) < 0.6) col = mix(col, ampGradient(g), S(glyphDist(g) * TC_AMP * as));
    }
    if(ts > 1e-3) col = mix(col, vec3(0.95), S(tcTagD(q, c, ts)));
    return col;
}

float tcNoise(vec2 p){
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3. - 2. * f);
    return mix(mix(random(i), random(i + vec2(1., 0.)), f.x), mix(random(i + vec2(0., 1.)), random(i + 1.), f.x), f.y);
}

float tcFbm(vec2 p){
    float a = 0.5, s = 0.;
    for(int i = 0; i < 4; i++){
        s += a * tcNoise(p);
        p = p * 2.03 + 17.1;
        a *= 0.5;
    }
    return s;
}
// --- iris: the old scene shrinks into an amp-shaped window -------------------
// A transition, T_IRIS long. The amp starts IR_ZOOM times too big, held so
// IR_ANCHOR (a point well inside the stroke) sits mid-screen, and shrinks
// to TC_AMP over IR_SHRINK: the old scene shows only through it, black
// round it. It fills with the brand gradient, the tagline pops in under it,
// and from IR_GROW_AT the window opens on the new scene and grows until it
// covers the screen. irWindow is the window's distance at zoom z.
const float IR_ZOOM    = 60.;
const vec2  IR_ANCHOR  = vec2(0.111, -0.353);
const float IR_SHRINK  = 1.6;
const float IR_FILL    = 0.5;
const float IR_GROW_AT = 4.9;

float irWindow(vec2 q, float z, out vec2 g){
    float s = TC_AMP * z, w = 1. / z;
    g = (q - TC_AMP_OFF * w) / s + IR_ANCHOR * (1. - w);
    float box = max(abs(g.x), abs(g.y));
    return (box < 0.8 ? glyphDist(g) : box - 0.5) * s;
}

vec3 iris(vec2 q, vec2 tp){
    float ph = gModeT[MODE_IRIS];
    float x = clamp(ph / IR_SHRINK, 0., 1.), y = clamp((ph - IR_GROW_AT) / (T_IRIS - IR_GROW_AT), 0., 1.);
    float e = 1. - (1. - x) * (1. - x) * (1. - x);
    float z = exp(log(IR_ZOOM) * (ph < IR_GROW_AT ? 1. - e : y * y * y));
    vec2 g;
    float inside = S(irWindow(q, z, g));
    inside = max(inside, max(1. - smoothstep(0., 0.08, x), smoothstep(0.85, 1., y)));
    float fill = smoothstep(IR_SHRINK, IR_SHRINK + IR_FILL, ph) * (1. - smoothstep(IR_GROW_AT - 0.4, IR_GROW_AT, ph));
    vec3 win = mix(ph < 3. ? gPrevCol : gNextCol, ampGradient(g), fill);
    vec3 col = mix(bgNoise(tp), win, inside);
    return tcCard(col, q, vec2(0.), 0., tcPop(ph, IR_SHRINK + 0.2, IR_GROW_AT - 0.75));
}
// --- ink: the amp drops into the old scene like ink into water ---------------
// A transition, T_INK long. The amp falls onto the old scene and lands at
// INK_DROP, then bleeds out as swirling deep-teal ink, its edge torn up by
// noise, until the screen is ink (INK_SPREAD). The amp and the tagline
// surface out of it, sink again, and from INK_CLEAR_AT a second noisy front
// clears the ink from the middle outwards onto the new scene.
const float INK_DROP     = 0.6;
const float INK_SPREAD   = 2.;
const float INK_CLEAR_AT = 4.9;
const float INK_CLEAR    = 1.8;
const float INK_REACH    = 1.9;

float inkFront(vec2 q, float r, float seed, float t){
    float d = length(q - TC_AMP_OFF);
    float a = atan(q.y - TC_AMP_OFF.y, q.x);
    float w = tcFbm(q * 3. + vec2(seed, t * 0.2)) - 0.5;
    float tend = tcFbm(vec2(a * 2.5 + seed, d * 3. - t * 0.6)) - 0.5;
    return d + (0.35 * w + 0.25 * tend) * (0.25 + d) - r;
}

vec3 ink(vec2 q, vec2 tp){
    float ph = gModeT[MODE_INK];
    vec3 col = gPrevCol;

    float u = clamp((ph - INK_DROP) / INK_SPREAD, 0., 1.);
    float r = INK_REACH * (1. - (1. - u) * (1. - u)) * step(INK_DROP, ph);
    float f = inkFront(q, r, 0., ph);
    float m = smoothstep(0.02, -0.02, f) * step(1e-4, r);
    vec2 sw = q * 4. + 0.3 * vec2(sin(ph * 0.4), cos(ph * 0.3));
    float v = tcFbm(sw + 2. * tcFbm(q * 2. + ph * 0.1));
    vec3 inkc = mix(GRAD_BOT * 0.08, GRAD_BOT * 0.6, v * v);
    inkc += GRAD_TOP * 0.5 * smoothstep(0.05, 0., abs(f)) * (1. - u);
    col = mix(col, inkc, m);

    float fall = clamp(ph / INK_DROP, 0., 1.);
    vec2 c = vec2(0., 0.9 * (1. - fall * fall));
    float melt = 1. - smoothstep(0., 0.6, ph - INK_DROP);
    vec2 g = (q - c - TC_AMP_OFF) / TC_AMP;
    if(melt > 0. && abs(g.x) < 0.6 && abs(g.y) < 0.6) col = mix(col, ampGradient(g), S(glyphDist(g) * TC_AMP) * melt);

    col = tcCard(col, q, vec2(0.), tcPop(ph, 2.5, INK_CLEAR_AT - 0.45), tcPop(ph, 2.75, INK_CLEAR_AT - 0.37));

    float u2 = clamp((ph - INK_CLEAR_AT) / INK_CLEAR, 0., 1.);
    float r2 = INK_REACH * cubicInOut(u2) * step(INK_CLEAR_AT, ph);
    float f2 = inkFront(q, r2, 7.3, ph);
    float m2 = smoothstep(0.02, -0.02, f2) * step(1e-4, r2);
    col = mix(col, gNextCol, m2);
    col += GRAD_TOP * 0.4 * smoothstep(0.04, 0., abs(f2)) * step(1e-4, r2) * (1. - u2);
    return col;
}
// --- typewriter: the tagline typed out, then selected and deleted ------------
// A transition, T_TYPE long. The old scene fades to black (TY_FADE) and a
// cursor types FLAP_TEXT one letter per TY_STEP from TY_AT, a small amp as
// the last character, then blinks. At TY_SEL_AT the line is selected left
// to right over TY_SEL, at TY_DEL_AT it is deleted, and the cursor blinks
// alone while the new scene comes up behind it. TY_H is the text cell height.
const float TY_FADE   = 0.4;
const float TY_AT     = 0.6;
const float TY_STEP   = 0.075;
const float TY_H      = 0.09;
const float TY_GAP    = 0.25;
const float TY_AMP    = 0.62;
const float TY_SEL_AT = 4.4;
const float TY_SEL    = 0.45;
const float TY_DEL_AT = 5.2;

vec3 typewriter(vec2 q, vec2 tp){
    float ph = gModeT[MODE_TYPE];
    vec3 col = mix(gPrevCol, bgNoise(tp) * 0.6, smoothstep(0., TY_FADE, ph));
    col = mix(col, gNextCol, smoothstep(TY_DEL_AT + 0.4, T_TYPE - 0.1, ph));

    float w = TI_TAG_W + TY_GAP + TY_AMP;
    float x0 = -0.5 * w;
    bool gone = ph >= TY_DEL_AT;
    int n = gone ? 0 : int(clamp(floor((ph - TY_AT) / TY_STEP) + 1., 0., float(FLAP_TEXT_LEN + 1)));
    vec2 tq = q / TY_H;

    float sel = gone ? 0. : cubicInOut(clamp((ph - TY_SEL_AT) / TY_SEL, 0., 1.)) * w;
    if(sel > 0. && abs(tq.y) < 0.42 && tq.x > x0 - 0.03 && tq.x < x0 + sel) col = mix(GRAD_BOT, GRAD_TOP, 0.3) * 0.75;

    float x = x0, d = 1e9, cur = x0;
    for(int i = 0; i < FLAP_TEXT_LEN; i++){
        if(i >= n) break;
        float cx = x + 0.5 * TI_TAG_ADV[i];
        if(abs(tq.x - cx) < 0.4) d = min(d, flapGlyph(FLAP_TEXT[i], vec2(tq.x - cx, tq.y)));
        x += TI_TAG_ADV[i];
        cur = x;
    }
    if(n > 0 && abs(tq.y) < 0.5) col = mix(col, vec3(0.95), S(d * TY_H));
    if(n > FLAP_TEXT_LEN){
        vec2 g = (tq - vec2(x0 + TI_TAG_W + TY_GAP + 0.5 * TY_AMP, 0.)) / TY_AMP;
        if(abs(g.x) < 0.6 && abs(g.y) < 0.6) col = mix(col, ampGradient(g), S(glyphDist(g) * TY_AMP * TY_H));
        cur = x0 + w;
    }

    float typing = TY_AT + float(FLAP_TEXT_LEN + 1) * TY_STEP;
    bool blink = (ph > TY_AT - 0.3 && ph < typing + 0.2) || fract(ph * 1.6) < 0.55;
    if(ph > T_TYPE - 0.5 || ph < TY_FADE) blink = false;
    float cx = cur + 0.06;
    float bar = max(abs(tq.x - cx) - 0.035, abs(tq.y) - 0.38) * TY_H;
    if(blink) col = mix(col, vec3(0.95), S(bar));
    return col;
}
// --- peel: the old scene peeled off like a sticker ---------------------------
// A transition, T_PEEL long, in three layers: the old scene on top, the amp
// with the tagline under it, the new scene at the bottom. From PE_AT.x the
// top layer is peeled from the bottom right corner, folding back flat along
// a line sweeping to the far corner over PE_DUR, its pale back showing and
// a soft shadow along the fold; from PE_AT.y the card is peeled the same
// way from the bottom left.
const vec2  PE_AT  = vec2(0.2, 4.6);
const float PE_DUR = 1.7;
const vec3  PE_BACK = vec3(0.80, 0.85, 0.86);

vec3 pePeel(vec2 q, vec3 top, vec3 below, float t, bool right){
    float asp = iResolution.x / iResolution.y;
    vec2 k = vec2((right ? 0.5 : -0.5) * asp, -0.5);
    vec2 dir = normalize(vec2(right ? -asp : asp, 1.));
    float smax = length(vec2(asp, 1.));
    float f = smax * 1.03 * cubicInOut(clamp(t / PE_DUR, 0., 1.));
    if(t <= 0.) return top;
    float s = dot(q - k, dir);
    if(s < f) return below * (1. - 0.5 * exp(-(f - s) / 0.03));
    vec2 src = q - 2. * (s - f) * dir;
    float on = S(sdBox(src, vec2(0.5 * asp, 0.5)));
    float u = s - f;
    vec3 back = PE_BACK * (0.62 + 0.38 * (1. - exp(-u / 0.06))) + 0.15 * exp(-u / 0.01);
    vec3 col = top;
    float shadow = (1. - on) * S(sdBox(q - 2. * (s - f + 0.012) * dir, vec2(0.5 * asp, 0.5)));
    col *= 1. - 0.35 * shadow;
    return mix(col, back, on);
}

vec3 peel(vec2 q, vec2 tp){
    float ph = gModeT[MODE_PEEL];
    vec3 card = tcCard(bgNoise(tp), q, vec2(0.), 1., 1.);
    if(ph < PE_AT.y) return pePeel(q, gPrevCol, card, ph - PE_AT.x, true);
    return pePeel(q, card, gNextCol, ph - PE_AT.y, false);
}
// --- glitch: the old scene breaks up into the card and on into the new ------
// A transition, T_GLITCH long. Over GL_OUT the old scene tears into
// horizontal bands that flip one by one to the card (the amp and the
// tagline, RGB-split and shoved sideways while it lasts), some bands
// corrupted to posterized, channel-swapped colour and stray blocks; the
// card holds with a twitch every so often, and over GL_IN it breaks the
// same way into the new scene. The bands reroll GL_FPS times a second.
const vec2  GL_OUT = vec2(0.2, 1.3);
const vec2  GL_IN  = vec2(4.5, 5.8);
const float GL_FPS = 24.;

vec3 glCard(vec2 q, vec2 tp, float dx){
    vec3 bg = bgNoise(tp);
    if(dx < 1e-4) return tcCard(bg, q, vec2(0.), 1., 1.);
    return vec3(tcCard(bg, q + vec2(dx, 0.), vec2(0.), 1., 1.).r,
                tcCard(bg, q, vec2(0.), 1., 1.).g,
                tcCard(bg, q - vec2(dx, 0.), vec2(0.), 1., 1.).b);
}

vec3 glitch(vec2 q, vec2 tp){
    float ph = gModeT[MODE_GLITCH];
    bool first = ph < 0.5 * (GL_OUT.y + GL_IN.x);
    vec2 win = first ? GL_OUT : GL_IN;
    float p = (ph - win.x) / (win.y - win.x);
    float k = p > 0. && p < 1. ? sin(3.1415927 * p) : 0.;
    float fr = floor(ph * GL_FPS);
    if(k == 0. && !first && ph < GL_IN.x && fract(ph * 0.8) < 0.06) k = 0.3;
    if(k == 0. && first && ph > GL_OUT.y && fract(ph * 0.8 + 0.5) < 0.06) k = 0.3;

    float bands = 8. + floor(random(vec2(fr, 1.3)) * 30.);
    float band = floor((q.y + 0.5) * bands);
    float th = 0.7 * random(vec2(band + 0.5 * bands, 7.1)) + 0.3 * random(vec2(band, fr));
    bool b = p * 1.2 - 0.1 > th;
    float hit = random(vec2(band, fr + 3.3));
    float dx = 0.012 * k;
    vec2 qs = q + vec2((random(vec2(band, fr + 11.)) - 0.5) * 0.2 * k * step(0.55, hit), 0.);

    vec3 a = first ? gPrevCol : glCard(qs, tp, dx);
    vec3 c = first ? glCard(qs, tp, dx) : gNextCol;
    if(first && p >= 1.) a = c;
    if(!first && p <= 0.) c = a;
    vec3 col = b ? c : a;
    if(k > 0.){
        if(hit < 0.22 * k) col = floor(col.gbr * 4. + 0.5) / 4. * vec3(0.7, 1.1, 1.2);
        vec2 blk = floor(q * vec2(28., 18.) + vec2(fr * 3.1, fr));
        if(random(blk) < 0.025 * k) col = random(blk + 1.) < 0.5 ? GRAD_TOP * 1.2 : vec3(0.9);
        col *= 0.9 + 0.1 * sin(q.y * iResolution.y * 3.1415927);
    }
    return col;
}
// --- blinds: three-sided slats turning old scene -> card -> new scene --------
// A transition, T_BLINDS long. The screen is cut into vertical slats
// BL_W wide, each a triangular prism seen side on: one face the old scene,
// the next the card (the amp and the tagline), the third the new scene. At
// BL_AT.x and again at BL_AT.y the slats turn a third of the way round on
// an ease-out-back over BL_TURN, in a sweep left to right (BL_SWEEP), each
// face shaded by how far it faces away. The slats fade in out of the old
// scene over BL_FADE and out into the new one over the last BL_FADE.
const float BL_W     = 1. / 7.;
const vec2  BL_AT    = vec2(0.6, 4.4);
const float BL_FADE  = 0.5;
const float BL_TURN  = 0.9;
const float BL_SWEEP = 0.8;

vec3 blinds(vec2 q, vec2 tp){
    float ph = gModeT[MODE_BLINDS];
    float asp = iResolution.x / iResolution.y;
    float i = floor(q.x / BL_W);
    float sx = (i + 0.5) * BL_W, u = q.x - sx;
    float delay = clamp((sx + 0.5 * asp) / asp, 0., 1.) * BL_SWEEP;
    float third = 2.0943951;
    float a = third * (tcBack((ph - BL_AT.x - delay) / BL_TURN) + tcBack((ph - BL_AT.y - delay) / BL_TURN));
    float r = BL_W / (2. * sqrt(3.));
    vec3 col = vec3(0.02);
    for(int k = 0; k < 3; k++){
        float th = a - float(k) * third;
        float c = cos(th);
        if(c <= 0.01) continue;
        float hw = 0.5 * BL_W * c;
        float t = (u - r * sin(th)) / hw;
        if(abs(t) > 1.) continue;
        vec2 fq = vec2(sx + t * 0.5 * BL_W, q.y);
        vec3 face = k == 0 ? gPrevCol : k == 1 ? tcCard(bgNoise(tp), fq, vec2(0.), 1., 1.) : gNextCol;
        face *= 0.3 + 0.7 * c;
        face += 0.06 * pow(c, 24.) * smoothstep(1., 0.6, abs(t));
        col = mix(vec3(0.02), face, smoothstep(1., 1. - 3. / (iResolution.y * hw + 1e-3), abs(t)));
        break;
    }
    col = mix(gPrevCol, col, smoothstep(0., BL_FADE, ph));
    return mix(col, gNextCol, smoothstep(T_BLINDS - BL_FADE, T_BLINDS, ph));
}
// --- stamp: the amp slammed onto the old scene -------------------------------
// A transition, T_STAMP long. The amp drops onto the old scene from ST_DROP
// times its size, its shadow tightening under it, and slams down at ST_HIT
// with a shake and a soft shockwave running out from its edge (stWave);
// the tagline stamps down the same way at ST_TAG. At ST_LIFT both lift off and fade, and where the
// amp stood its imprint is a window onto the new scene, which opens out
// (irWindow) until it covers the screen.
const float ST_DROP = 2.6;
const float ST_FALL = 0.45;
const float ST_HIT  = 0.65;
const float ST_TAG  = 1.45;
const float ST_LIFT = 4.2;
const float ST_OPEN = 4.8;

float stWave(float d, float t, float reach){
    if(t < 0. || t > 0.9 || d < 0.) return 0.;
    float r = reach * (1. - (1. - t / 0.9) * (1. - t / 0.9) * (1. - t / 0.9));
    return exp(-abs(d - r) / (0.006 + 0.03 * t)) * (1. - t / 0.9) * smoothstep(0., 0.05, t);
}

vec3 stamp(vec2 q, vec2 tp){
    float ph = gModeT[MODE_STAMP];
    float lift = smoothstep(ST_LIFT, ST_LIFT + 0.5, ph);
    vec3 col = gPrevCol * (1. - 0.25 * smoothstep(ST_HIT, ST_HIT + 0.2, ph) * (1. - lift));

    float sh = ph - ST_HIT;
    vec2 shake = vec2(sin(ph * 70.), cos(ph * 53.)) * 0.012 * exp(-max(sh, 0.) * 8.) * step(0., sh);
    shake += vec2(sin(ph * 67.), cos(ph * 49.)) * 0.006 * exp(-max(ph - ST_TAG, 0.) * 8.) * step(ST_TAG, ph);

    float fa = clamp((ph - (ST_HIT - ST_FALL)) / ST_FALL, 0., 1.);
    float sa = mix(ST_DROP, 1., fa * fa) + lift * lift * 1.4;
    float aa = smoothstep(0., 0.3, fa) * (1. - lift);
    float ft = clamp((ph - (ST_TAG - ST_FALL)) / ST_FALL, 0., 1.);
    float stg = mix(ST_DROP, 1., ft * ft) + lift * lift * 1.4;
    float at = smoothstep(0., 0.3, ft) * (1. - lift);

    float d0 = glyphDist((q - TC_AMP_OFF) / TC_AMP) * TC_AMP;
    if(ph > ST_LIFT){
        float y = clamp((ph - ST_OPEN) / (T_STAMP - ST_OPEN), 0., 1.);
        vec2 g;
        float w = irWindow(q, exp(log(IR_ZOOM) * y * y * y), g);
        float win = max(S(w), smoothstep(0.85, 1., y));
        col = mix(col, gNextCol, win * smoothstep(ST_LIFT, ST_LIFT + 0.3, ph));
        col *= 1. - 0.6 * exp(-max(w, 0.) / 0.006) * (1. - y);
    }

    if(aa > 0.){
        float dsh = tcAmpD(q - vec2(0.012, -0.02) * sa, vec2(0.), sa * 0.98);
        col *= 1. - 0.45 * aa * exp(-max(dsh, 0.) / (0.01 + 0.04 * (sa - 1.)));
    }
    col += mix(GRAD_TOP, vec3(1.), 0.5) * 0.35 * stWave(d0, sh, 0.35);
    col = mix(col, tcCard(col, q + shake, vec2(0.), sa, 0.), aa);
    col = mix(col, tcCard(col, q + shake, vec2(0.), 0., stg), at);
    col += vec3(1.) * 0.15 * exp(-max(sh, 0.) * 12.) * step(0., sh) * (1. - smoothstep(0., 0.3, d0));
    return col;
}
// --- agents: shared engine for the scenes of small moving amps ---------------
// Each such scene owns an AG_W x AG_H RGBA32F buffer pass that steps over its
// own previous frame. Row 0 and row 1 hold up to AG_W agents (scene-defined,
// usually pos.xy vel.xy and extra state), the AG_META texel the last step's
// time (a gap of over AG_GAP, as when the scene was not live, starts the
// scene afresh). Rows from AG_BIN0 are a screen grid of AG_CELL cells, AG_TEX
// texels (AG_SLOTS agent slots, index + 1) per cell, listing the agents within
// a reach of it as of the previous frame, so the main pass only draws those.
// Rows from AG_FIELD0 are a free AG_FW x AG_FH screen field for scenes that
// need one. Positions are in main-pass q units (height 1, centred).
const int   AG_W      = 1024;
const float AG_CELL   = 1. / 40.;
const int   AG_GY     = 40;
const int   AG_GX     = 108;
const int   AG_TEX    = 8;
const int   AG_SLOTS  = 4 * AG_TEX;
const int   AG_BIN0   = 2;
const int   AG_FIELD0 = AG_BIN0 + AG_GY;
const int   AG_FW     = 160;
const int   AG_FH     = 90;
const int   AG_H      = AG_FIELD0 + AG_FH;
const ivec2 AG_META   = ivec2(AG_W - 1, 1);
const float AG_GAP    = 1.;

vec4 agGet(sampler2D ch, int i, int row){ return texelFetch(ch, ivec2(i, row), 0); }

// time step for this frame, 0 when starting afresh
float agDt(sampler2D ch, out bool fresh){
    float last = texelFetch(ch, AG_META, 0).x;
    fresh = last <= 0. || iTime < last || iTime - last > AG_GAP;
    return fresh ? 0. : min(iTime - last, 0.05);
}

ivec2 agCellOf(vec2 q, float asp){ return ivec2(floor((q + vec2(0.5 * asp, 0.5)) / AG_CELL)); }

// the bin texel (bx, by) of the grid: agents 0..n-1 whose row-0 xy lies
// within reach of the cell, four per texel
vec4 agBin(sampler2D ch, int bx, int by, int n, float reach, float asp){
    int cx = bx / AG_TEX, skip = (bx % AG_TEX) * 4;
    if(cx >= AG_GX || by >= AG_GY) return vec4(0.);
    vec2 lo = vec2(float(cx), float(by)) * AG_CELL - vec2(0.5 * asp, 0.5) - reach;
    vec2 hi = lo + AG_CELL + 2. * reach;
    vec4 o = vec4(0.);
    int c = 0;
    for(int j = 0; j < AG_W; j++){
        if(j >= n) break;
        vec2 p = agGet(ch, j, 0).xy;
        if(any(lessThan(p, lo)) || any(greaterThan(p, hi))) continue;
        if(c >= skip && c < skip + 4) o[c - skip] = float(j + 1);
        c++;
        if(c >= skip + 4) break;
    }
    return o;
}

// the AG_SLOTS agent slots of q's cell (index + 1, 0 empty), fetched only
// as far as they are filled
void agSlots(sampler2D ch, vec2 q, float asp, out vec4 s[AG_TEX]){
    ivec2 c = agCellOf(q, asp);
    bool out_ = c.x < 0 || c.y < 0 || c.x >= AG_GX || c.y >= AG_GY;
    for(int k = 0; k < AG_TEX; k++){
        s[k] = out_ ? vec4(0.) : texelFetch(ch, ivec2(AG_TEX * c.x + k, AG_BIN0 + c.y), 0);
        out_ = out_ || s[k].w == 0.;
    }
}

// the field texel nearest q, bilinear
vec4 agField(sampler2D ch, vec2 q, float asp){
    vec2 f = (q / vec2(asp, 1.) + 0.5) * vec2(AG_FW, AG_FH) - 0.5;
    ivec2 i = ivec2(floor(f));
    vec2 w = fract(f);
    ivec2 m = ivec2(AG_FW - 1, AG_FH - 1);
    vec4 a = texelFetch(ch, ivec2(clamp(i, ivec2(0), m)) + ivec2(0, AG_FIELD0), 0);
    vec4 b = texelFetch(ch, ivec2(clamp(i + ivec2(1, 0), ivec2(0), m)) + ivec2(0, AG_FIELD0), 0);
    vec4 c = texelFetch(ch, ivec2(clamp(i + ivec2(0, 1), ivec2(0), m)) + ivec2(0, AG_FIELD0), 0);
    vec4 d = texelFetch(ch, ivec2(clamp(i + ivec2(1, 1), ivec2(0), m)) + ivec2(0, AG_FIELD0), 0);
    return mix(mix(a, b, w.x), mix(c, d, w.x), w.y);
}

// screen position of field texel (x, y)
vec2 agFieldPos(int x, int y, float asp){ return ((vec2(x, y) + 0.5) / vec2(AG_FW, AG_FH) - 0.5) * vec2(asp, 1.); }

// distance to an amp `size` tall at pos, its up axis along `up`
float agAmp(vec2 q, vec2 pos, vec2 up, float size){
    vec2 d = q - pos;
    if(dot(d, d) > size * size) return size;
    vec2 g = vec2(dot(d, vec2(up.y, -up.x)), dot(d, up)) / size;
    return glyphDist(g) * size;
}

vec2 agRand2(float i, float k){ return vec2(random(vec2(i, k)), random(vec2(k + 3.1, i * 1.7))); }

vec2 agLimit(vec2 v, float lo, float hi){
    float l = length(v);
    return l < 1e-6 ? vec2(lo, 0.) : v / l * clamp(l, lo, hi);
}

// a steer back from beyond `margin` inside the screen edges
vec2 agWalls(vec2 p, float asp, float margin){
    vec2 e = vec2(0.5 * asp, 0.5) - margin;
    return -sign(p) * max(abs(p) - e, 0.) / margin;
}
// --- fish: a school of small amps and a shark hunting it ---------------------
// FI_N - 1 small amps school as boids (bufferFish) and scatter from the
// predator, agent 0: a shark emoji (FI_BIG across, from sky.png, facing the
// way it swims and pitching with it) that cruises toward the school and
// lunges at the nearest fish it sees within FI_HUNT. Fish within FI_FEAR of
// it flee at a burst of speed, through deep water lit from the surface
// (fiWater).
const int   FI_N     = 160;
const float FI_SIZE  = 0.013;
const float FI_BIG   = 0.1;
const vec2  FI_SPEED = vec2(0.1, 0.22);
const float FI_BURST = 0.42;
const float FI_SEP   = 0.022;
const float FI_SEE   = 0.07;
const float FI_FEAR  = 0.17;
const float FI_HUNT  = 0.3;
const vec2  FI_PRED_SPEED = vec2(0.07, 0.24);
const float FI_FLOW   = 0.6;
const float FI_RAY_TILT = 0.35;

void fiStep(sampler2D ch, int i, float dt, bool fresh, float asp, out vec4 r0, out vec4 r1){
    r1 = vec4(0.);
    if(fresh){
        vec2 p = i == 0 ? vec2(-0.45 * asp, 0.3) : (agRand2(float(i), 2.1) - 0.5) * vec2(0.5, 0.35);
        float a = random(vec2(i, 5.5)) * 6.2831853;
        r0 = vec4(p, vec2(cos(a), sin(a)) * FI_SPEED.x);
        return;
    }
    vec4 s = agGet(ch, i, 0);
    vec2 p = s.xy, v = s.zw;
    vec2 pred = agGet(ch, 0, 0).xy;
    vec2 acc = vec2(0.);
    if(i == 0){
        vec2 cen = vec2(0.), near = p;
        float best = 1e9, n = 0.;
        for(int j = 1; j < FI_N; j++){
            vec2 o = agGet(ch, j, 0).xy;
            cen += o; n += 1.;
            float l = length(o - p);
            if(l < best){ best = l; near = o; }
        }
        bool hunt = best < FI_HUNT;
        acc = normalize((hunt ? near : cen / n) - p + 1e-5) * (hunt ? 0.9 : 0.25) + agWalls(p, asp, 0.1) * 1.5;
        float lim = hunt ? FI_PRED_SPEED.y : FI_PRED_SPEED.x + 0.05;
        v = agLimit(v + acc * dt, FI_PRED_SPEED.x, lim);
        r0 = vec4(p + v * dt, v);
        return;
    }
    vec2 sep = vec2(0.), ali = vec2(0.), coh = vec2(0.);
    float n = 0.;
    for(int j = 1; j < FI_N; j++){
        if(j == i) continue;
        vec4 o = agGet(ch, j, 0);
        vec2 d = o.xy - p;
        float l = length(d);
        if(l > FI_SEE) continue;
        if(l < FI_SEP) sep -= d / max(l * l, 1e-4) * FI_SEP;
        ali += o.zw; coh += o.xy; n += 1.;
    }
    acc = sep;
    if(n > 0.) acc += (ali / n - v) * 1.8 + (coh / n - p) * 1.6;
    float w = tcNoise(vec2(float(i) * 0.53, iTime * 0.4)) * 12.566;
    acc += vec2(cos(w), sin(w)) * 0.1 + agWalls(p, asp, 0.1) * 1.5;
    vec2 fd = p - pred;
    float fl = length(fd);
    float fear = 1. - smoothstep(FI_FEAR * 0.4, FI_FEAR, fl);
    acc += fd / max(fl, 1e-4) * fear * 3.;
    v = agLimit(v + acc * dt, FI_SPEED.x, mix(FI_SPEED.y, FI_BURST, fear));
    r0 = vec4(p + v * dt, v);
}

// deep water: brighter towards the surface, shafts of light slanting down
// from it (FI_RAY_TILT) and swaying, and motes drifting in the light
vec3 fiWater(vec2 q, vec2 tp){
    float depth = 0.5 - q.y;
    vec3 col = mix(GRAD_BOT * 0.32, GRAD_BOT * 0.025, smoothstep(0., 1., depth)) * (0.85 + 0.3 * tcFbm(q * 3. + iTime * 0.02));
    float t = iTime * FI_FLOW;
    float x = q.x + depth * FI_RAY_TILT + 0.03 * sin(t * 0.7 + depth * 2.);
    float rays = 0.;
    for(int k = 0; k < 3; k++){
        float f = 3. + float(k) * 4.3;
        float n = tcNoise(vec2(x * f + float(k) * 7.1, t * (0.25 + 0.1 * float(k))));
        rays += pow(n, 4.) * (1. - 0.25 * float(k));
    }
    col += mix(GRAD_TOP, vec3(0.85, 1., 1.), 0.3) * 0.22 * rays * exp(-depth * 1.6);
    col += vec3(0.8, 1., 1.) * 0.1 * smoothstep(0.06, 0., depth) * (0.6 + 0.4 * sin(q.x * 40. + t * 3.));
    vec2 mp = q * 55. + vec2(0., iTime * 0.6);
    vec2 mc = floor(mp), mf = fract(mp) - 0.5;
    vec2 jit = vec2(random(mc), random(mc + 7.3)) - 0.5;
    float mote = step(0.86, random(mc + 3.1)) * smoothstep(0.08, 0., length(mf - jit * 0.7));
    col += vec3(0.6, 0.85, 0.9) * 0.18 * mote * (0.4 + rays) * exp(-depth * 1.2);
    return col;
}

vec3 fish(vec2 q, vec2 tp){
    float asp = iResolution.x / iResolution.y;
    vec3 col = fiWater(q, tp);
    vec4 sl[AG_TEX];
    agSlots(iChannel16, q, asp, sl);
    vec4 ps = agGet(iChannel16, 0, 0);
    for(int k = 0; k < AG_SLOTS; k++){
        int i = int(sl[k >> 2][k & 3] + 0.5) - 1;
        if(i < 0) break;
        if(i == 0) continue;
        vec4 s = agGet(iChannel16, i, 0);
        float bank = clamp(-s.z / max(length(s.zw), 1e-4), -1., 1.) * 0.4;
        float d = agAmp(q, s.xy, vec2(sin(-bank), cos(bank)), FI_SIZE);
        vec3 c = mix(vec3(0.6, 0.72, 0.75), GRAD_TOP, random(vec2(i, 1.9)) * 0.6);
        col = mix(col, c, S(d));
    }
    vec2 d = (q - ps.xy) / FI_BIG;
    if(dot(d, d) < 0.6){
        bool right = ps.z > 0.;
        float a = clamp(atan(ps.w, abs(ps.z)), -0.6, 0.6) * (right ? -1. : 1.);
        d = mat2(cos(a), sin(a), -sin(a), cos(a)) * d;
        if(right) d.x = -d.x;
        vec2 uv = vec2(d.x + 0.5, 0.5 - d.y);
        if(all(greaterThan(uv, vec2(0.))) && all(lessThan(uv, vec2(1.)))){
            vec4 e = skyEmojiAt(uv, 128);
            col = col * (1. - e.a) + e.rgb;
        }
    }
    return col;
}
// --- map: the traffic scene on real road networks -----------------------------
// The traffic scene drives map u_traffic_map from maps.png in
// iChannel20 (gen_maps.py: OpenStreetMap roads baked into a lane graph; see
// there for the layout, read here as 24-bit words). Cars (bufferTraffic;
// row 0: position, speed, heading; row 1: edge, distance along it, the
// edge after it, time stopped) follow their lane, keep MP_GAP car lengths
// behind the car ahead (on their edge or the next two), slow for the
// curves of the connectors through junctions, and at a give-way connector
// wait at the end of their lane while any car with right of way is inside a
// conflicting connector or about to take one: within MP_LOOK and either
// MP_CLOSE metres or MP_ACCEPT seconds away at its speed (gap acceptance:
// a slow or queued main road still lets the ramp in; a car below MP_CRAWL
// is not coming at all). A car stopped
// (below MP_CRAWL, creeping counts) for MP_PATIENCE stops waiting. At each junction a car picks a random
// turn (the whole simulation runs MP_TIME times real time). Roads are
// drawn layer by layer (OSM layer + MP_GROUND, from the bridge / tunnel
// tags): decks MP_DECK metres up per layer, lighter, with parapets,
// casting shadows along MP_SHADOW on what is under them; cars under a deck
// are hidden, cars on one are a touch bigger (by height: a car hides only
// under a surface well above it, so it never blinks crossing joints).
// Tunnels show faintly. A car that leaves the map waits off it (MP_AWAY)
// for a gate at the edge of the screen to clear and comes in there.
// The map sets how many cars drive (by its lane length); the rest stay
// parked off it.
const int   MP_W        = 1024;
const int   MP_N        = 1023;
const float MP_LABEL    = 0.03;
const float MP_LABEL_PAD = 0.012;
const float MP_LABEL_PX = 64.;
const float MP_LABEL_RANGE = 0.25;
const float MP_SPEEDUP  = 0.7;
const float MP_TIME     = 4.;
const float MP_GAP      = 1.6;
const float MP_LOOK     = 32.;
const float MP_APPROACH = 22.;
const float MP_REACH    = 90.;
const float MP_ACC      = 3.;
const float MP_BRAKE    = 7.;
const float MP_PATIENCE = 8.;
const float MP_COURTESY = 3.;
const float MP_JAMMED = 120.;
const float MP_JUNCTION_PAD = 1.;
const int MP_CONG_ROW = AG_FIELD0;
const int MP_CONG_ROWS = 4;
const float MP_CONG = 0.5;
const float MP_CONG_NEAR = 2.;
const float MP_FULL = 0.05;
const int MP_CAR_ROW = MP_CONG_ROW + MP_CONG_ROWS;
const int MP_GATE_ROW = MP_CAR_ROW + 1;
const int MP_GATE_ROWS = 4;
const int MP_SENSE_ROW = MP_GATE_ROW + MP_GATE_ROWS;
const float MP_ROAM = 45.;
const float MP_ROAM_RAMP = 45.;
const float MP_HOME_M = 40.;
const float MP_COMING = 20.;
const int MP_GATE_STEPS = 48;
const float MP_GATE_BACK = 6.;
const float MP_GATE_GAP = 4.3;
const int MP_SCATTER_EVERY = 32;
const float MP_BIN_MOVE = 12.;
const float MP_LIFT_TOP = 6.;
const float MP_RING_SEE = 6.;
const float MP_RING_FREER = 2.;
const float MP_SHIFT_ROOM = 1.5;
const float MP_SHIFT_CREEP = 6.;
const float MP_HILL_EXAG = 1.5;
const float MP_HILL = 0.35;
const float MP_HILL_LIGHT = 0.08;
const float MP_TERRAIN_EXAG = 1.;
const float MP_TERRAIN_LMAX = 0.6;
const int MP_TERRAIN_STEPS = 96;
const float MP_LIFT_Q = 4000.;
const float MP_SHIFT    = 0.25;
const float MP_STEER    = 9.;
const float MP_TURN_R   = 3.;
const float MP_SEE      = 4.;
const float MP_ACCEPT   = 2.5;
const float MP_CLOSE    = 8.;
const float MP_CRAWL    = 2.;
const float MP_BODY     = 0.55;
const int   MP_MAX_PTS  = 24;
const int   MP_MAX_GIVE = 12;
const float MP_AWAY     = 9.;
const float MP_CAR_DRAW = 0.75;
const int   MP_LAYERS   = 8;
const int   MP_GROUND   = 2;
const vec2  MP_SHADOW   = vec2(0.6, -0.8);
const float MP_DECK     = 5.;
const float MP_SHADE_MIN = 0.3;
const float MP_DASH     = 2.;
const float MP_LINE     = 0.45;
const float MP_OFF      = 0.04;
const float MP_LANE_CHOOSE = 80.;
const float MP_LANE_LOCK = 50.;
const float MP_BLD_VIEW = 0.55;
const float MP_BLD_SUN  = 0.7;
const int   MP_BLD_MAX_V = 20;
const int   MP_BLD_CELL = 48;
const int   MP_BLD_WALL = 8;
const int   MP_GREEN_MAX_V = 48;
const int   MP_GREEN_CELL = 24;
const int   MP_PARK_CELL = 48;
const int   MP_SIG_CELL = 16;
const float MP_SIG_AMBER = 3.;
const float MP_SIG_CLEAR = 2.;
const int   MP_SEG_CELL = 448;
const float MP_PATH_GREY = 0.105;
const float MP_WALL_GREY = 0.155;
const float MP_SNOW_GREY = 0.42;
const float MP_LINE_BAND = 40.;
const float MP_LINE_RAG = 250.;
const float MP_TREE_R = 5.;
const vec3  MP_GREEN_TINT = vec3(0.55, 1.4, 0.75);
const vec3  MP_WATER_TINT = vec3(0.6, 0.85, 1.3);

int mpWord(int i){
    ivec3 c = ivec3(texelFetch(iChannel20, ivec2(i % MP_W, i / MP_W), 0).rgb * 255. + 0.5);
    return c.r << 16 | c.g << 8 | c.b;
}

float mpFx(int i){ return float(mpWord(i)) / 16777216. * 8. - 4.; }

// the map's header, read once per pixel / agent
int gMpBase, gMpLanes, gMpEdge, gMpPts, gMpSucc, gMpGive, gMpEntry, gMpEntries, gMpCars;
float gMpCar, gMpU;

int gMpIdx = 0;

void mpLoad(){
    gMpIdx = u_traffic_map < mpWord(0) ? u_traffic_map : 0;
    gMpBase = mpWord(1 + gMpIdx);
    gMpLanes = mpWord(gMpBase);
    gMpEdge = gMpBase + mpWord(gMpBase + 2);
    gMpPts = gMpBase + mpWord(gMpBase + 3);
    gMpSucc = gMpBase + mpWord(gMpBase + 4);
    gMpGive = gMpBase + mpWord(gMpBase + 5);
    gMpEntry = gMpBase + mpWord(gMpBase + 6);
    gMpEntries = mpWord(gMpBase + 7);
    gMpCars = u_traffic_cars > 0 ? min(u_traffic_cars, MP_N) : mpWord(gMpBase + 22);
    gMpCar = mpFx(gMpBase + 17);
    float km = mpFx(gMpBase + 18);
    gMpU = 1. / (km < 0. ? -km * 10000. : km * 1000.);
}

const int MP_EDGE_WORDS = 14;

int mpE(int e, int k){ return mpWord(gMpEdge + MP_EDGE_WORDS * e + k); }

float mpLen(int e){ return mpFx(gMpEdge + MP_EDGE_WORDS * e + 2); }

// traffic lights (gen_maps: an edge's lights + 1, bits 0-15 the junction's
// lights, 16 the phase): the two phases take turns on the simulation
// clock, each green as long as gen_maps gave it (by the traffic coming in
// on it), amber MP_SIG_AMBER, then red for both for MP_SIG_CLEAR, every
// junction at its own offset; 0 green, 1 amber, 2 red, -1 no light
int mpLight(int sig){
    if(sig <= 0) return -1;
    int g = (sig - 1) & 65535, ph = (sig - 1) >> 16;
    int gt = gMpBase + mpWord(gMpBase + 44) + 2 * g;
    float g0 = float(mpWord(gt)) * 0.1, g1 = float(mpWord(gt + 1)) * 0.1;
    float cycle = g0 + g1 + 2. * (MP_SIG_AMBER + MP_SIG_CLEAR);
    float t = mod(iTime * MP_TIME + random(vec2(float(g), 3.3)) * cycle, cycle);
    if(ph == 1) t -= g0 + MP_SIG_AMBER + MP_SIG_CLEAR;
    float green = ph == 1 ? g1 : g0;
    return t >= 0. && t < green ? 0 : t >= 0. && t < green + MP_SIG_AMBER ? 1 : 2;
}

int mpSig(int e){ return mpLight(mpE(e, 12) & 1048575); }

float mpOff(int e, bool far){ return mpFx(gMpEdge + MP_EDGE_WORDS * e + (far ? 11 : 10)); }

vec3 mpPoint(int k){ return vec3(mpFx(gMpPts + 3 * k), mpFx(gMpPts + 3 * k + 1), mpFx(gMpPts + 3 * k + 2) * 4.); }

// a car's heading and height (deck levels) share row 0's w
float mpPack(float heading, float h){ return heading + 8. * floor(h * 32. + 0.5); }
float mpHeight(float w){ return floor((w + 4.) / 8.) / 32.; }
float mpHeading(float w){ return w - 8. * floor((w + 4.) / 8.); }

int mpSucc(int e, float pick){
    int n = mpE(e, 4);
    if(n == 0) return -1;
    return mpWord(gMpSucc + mpE(e, 3) + min(int(pick * float(n)), n - 1));
}

int mpLanes(int e, bool far){ return max(mpE(e, 7) >> (far ? 20 : 16) & 15, 1); }

// the lane a connector comes out of (-1 for a lane)
int mpPred(int e){ return mpE(e, 13) - 1; }

// the connector out of e starting nearest lat (ring: 1 only those going
// on round, 0 only those leaving it, else any)
int mpNearest(int e, float lat, int ring){
    int n = mpE(e, 4), st = gMpSucc + mpE(e, 3), best = -1;
    float bd = 1e9;
    for(int k = 0; k < 64; k++){
        if(k >= n) break;
        int c = mpWord(st + k);
        if(ring >= 0 && (mpE(c, 7) >> 1 & 1) != ring) continue;
        float d = abs(lat - mpFx(gMpEdge + MP_EDGE_WORDS * c + 10));
        if(d < bd){ bd = d; best = c; }
    }
    return best;
}

// on a ring of MP_RING_LANES lanes or more a car knows which exit it takes (on a
// narrower ring it picks at each junction as anywhere else): k, counted
// from where it is, kept with its next edge (nx + MP_NX_SPAN * k). It
// drives in the k-th lane from the outside (as far as there are lanes),
// moves out one lane each exit it passes, and takes the road off at k == 1
const float MP_NX_SPAN = 16384.;
const int MP_RING_LANES = 3;
bool mpRing(int e){ return (mpE(e, 7) & 2) != 0; }

// top speed on e: MP_SPEEDUP of its baked one, but a ring keeps its own
// (already slow), as does a connector onto it, so cars join at its pace
float mpSpeedOf(int e){ return float(mpE(e, 7) >> 8 & 255) * 0.001; }
float mpSpeed(int e){
    if(mpRing(e)) return mpSpeedOf(e);
    if((mpE(e, 7) & 1) == 1 && mpRing(mpSucc(e, 0.))) return mpSpeedOf(mpSucc(e, 0.));
    return mpSpeedOf(e) * MP_SPEEDUP;
}

int mpNx(float z){ return z < -0.5 ? -1 : int(mod(z + 0.5, MP_NX_SPAN)); }
float mpExitsLeft(float z){ return z < -0.5 ? 0. : floor((z + 0.5) / MP_NX_SPAN); }
float mpPackNx(int nx, float k){ return nx < 0 ? -1. : float(nx) + MP_NX_SPAN * k; }

// whether ring lane e has a road off it, and the ring edge after it
bool mpRingExit(int e, out int on){
    int n = mpE(e, 4), st = gMpSucc + mpE(e, 3);
    bool off = false;
    on = -1;
    for(int j = 0; j < 64; j++){
        if(j >= n) break;
        int s = mpWord(st + j);
        if(mpRing(s)) on = s; else off = true;
    }
    return off && (mpE(e, 7) & 1) == 0;
}

// the exit a car joining the ring at e takes: any but the one back the way
// it came (the roads off it once round)
float mpPickExit(int i, int e){
    int exits = 0, x = e, on;
    for(int j = 0; j < 64; j++){
        if(mpRingExit(x, on)) exits++;
        if((mpE(x, 7) & 1) == 1) on = mpSucc(x, 0.);
        if(on < 0 || !mpRing(on)) break;
        x = on;
        if(x == e) break;
    }
    return 1. + floor(random(vec2(i, iTime * 0.37)) * float(max(exits - 1, 1)));
}

// where on ring edge e at s a car with k exits to go drives
float mpRingLat(int e, float s, float k){
    float f = clamp(s / max(mpLen(e), 1e-6), 0., 1.);
    float n = mix(float(mpLanes(e, false)), float(mpLanes(e, true)), f);
    float w = mix(mpFx(gMpEdge + MP_EDGE_WORDS * e + 8), mpFx(gMpEdge + MP_EDGE_WORDS * e + 9), f);
    float d = clamp(k, 1., floor(n + 0.5)) - 1.;
    return ((mpWord(gMpBase + 21) & 1) == 1 ? -1. : 1.) * (0.5 * w - (d + 0.5) * w / n);
}

// how backed up each edge is (counted in the traffic buffer from row
// MP_CONG_ROW, AG_W edges a row): its stopped cars, and whether one is
// stopped within MP_CONG_NEAR cars of its start (full to the junction)
vec4 mpCong(sampler2D ch, int e){ return texelFetch(ch, ivec2(e % AG_W, MP_CONG_ROW + e / AG_W), 0); }

vec4 mpCongest(sampler2D ch, int e){
    float stopped = 0., full = 0.;
    for(int j = 0; j < MP_N; j++){
        if(j >= gMpCars) break;
        vec4 o = agGet(ch, j, 1);
        if(o.x < -0.5 || int(o.x + 0.5) != e || agGet(ch, j, 0).z > MP_CRAWL * gMpU) continue;
        stopped += 1.;
        if(o.y < MP_CONG_NEAR * gMpCar) full = 1.;
    }
    return vec4(stopped, full, 0., 0.);
}

// a turn's share: its flow weight, less for every car stopped on it and the
// road it leads to, next to nothing (MP_FULL) where that road is full
float mpRoom(sampler2D ch, int c){
    int r = (mpE(c, 7) & 1) == 1 ? mpSucc(c, 0.) : c;
    vec4 a = mpCong(ch, c), b = mpCong(ch, r);
    return (b.y > 0.5 ? MP_FULL : 1.) / (1. + MP_CONG * (a.x + b.x));
}

// what row MP_CAR_ROW keeps of car i: the edge it came onto the map by (or
// first stood on), when, and the edge it was on last frame
vec4 mpCarMem(sampler2D ch, int i){ return texelFetch(ch, ivec2(i, MP_CAR_ROW), 0); }

// metres from the start of e to the nearest way off the map
float mpAway(int e){ return float(mpWord(gMpBase + mpWord(gMpBase + 45) + e)); }

// how much a car that has roamed past MP_ROAM wants to leave (0 to 1)
float mpHome(sampler2D ch, int i){ return clamp((iTime - mpCarMem(ch, i).y - MP_ROAM) / MP_ROAM_RAMP, 0., 1.); }

// the edge after e at random, by flow and by how backed up each way is,
// and, as much as home, against ways that lead further from leaving
float mpTurnWeight(sampler2D ch, int e, int c, float home){
    float extra = max(mpAway(c) - mpAway(e) + mpLen(e) / gMpU, 0.);
    return mpRoom(ch, c) * exp(-home * extra / MP_HOME_M);
}

int mpPickTurn(sampler2D ch, int e, float pick, float home){
    int n = mpE(e, 4), st = gMpSucc + mpE(e, 3);
    if(n == 0) return -1;
    float total = 0.;
    for(int j = 0; j < 64; j++){
        if(j >= n) break;
        total += mpTurnWeight(ch, e, mpWord(st + j), home);
    }
    float want = pick * total, acc = 0.;
    for(int j = 0; j < 64; j++){
        if(j >= n) break;
        acc += mpTurnWeight(ch, e, mpWord(st + j), home);
        if(acc >= want) return mpWord(st + j);
    }
    return mpWord(st + min(n, 64) - 1);
}

// the freest connector out of e (-1 if none)
int mpFreest(sampler2D ch, int e, out float room){
    int n = mpE(e, 4), st = gMpSucc + mpE(e, 3), best = -1;
    room = 0.;
    for(int j = 0; j < 64; j++){
        if(j >= n) break;
        int x = mpWord(st + j);
        if((mpE(x, 7) & 1) == 0) continue;
        float r = mpRoom(ch, x);
        if(r > room){ room = r; best = x; }
    }
    return best;
}

// the edge after e for a car with k exits to go; one heading onto a ring
// picks its exit now, and the lane onto the ring that leads to its lane
int mpChoose(sampler2D ch, int i, int e, float pick, float home, inout float k){
    int on;
    int c = mpPickTurn(ch, e, pick, home), r = c >= 0 && (mpE(c, 7) & 1) == 1 ? mpSucc(c, 0.) : -1;
    if(!mpRing(e) && c >= 0 && !mpRing(c) && r >= 0 && mpRing(r) && mpLanes(r, false) >= MP_RING_LANES){
        if(k < 0.5) k = mpPickExit(i, r);
        float want = mpRingLat(r, 0., k), bd = 1e9;
        int n = mpE(e, 4), st = gMpSucc + mpE(e, 3);
        for(int j = 0; j < 64; j++){
            if(j >= n) break;
            int x = mpWord(st + j);
            if(mpSucc(x, 0.) != r) continue;
            float d = abs(mpOff(x, true) - want);
            if(d < bd){ bd = d; c = x; }
        }
        return c;
    }
    if(!mpRing(e) || mpLanes(e, false) < MP_RING_LANES || !mpRingExit(e, on) || on < 0) return c;
    if(k > 1.5) return mpNearest(e, mpRingLat(e, mpLen(e), k), 1);
    int n = mpE(e, 4), st = gMpSucc + mpE(e, 3), offs = 0;
    for(int j = 0; j < 64; j++){
        if(j >= n) break;
        if(!mpRing(mpWord(st + j))) offs++;
    }
    int want = min(int(pick * float(offs)), offs - 1), seen = 0;
    for(int j = 0; j < 64; j++){
        if(j >= n) break;
        int s = mpWord(st + j);
        if(mpRing(s)) continue;
        if(seen == want) return s;
        seen++;
    }
    return on;
}

// position and direction at distance s along edge e
void mpAt(int e, float s, out vec2 pos, out vec2 dir, out float h){
    int ps = mpE(e, 0), pc = mpE(e, 1);
    vec3 a = mpPoint(ps);
    pos = a.xy;
    h = a.z;
    dir = vec2(1., 0.);
    float acc = 0.;
    for(int k = 1; k < MP_MAX_PTS; k++){
        if(k >= pc) break;
        vec3 b = mpPoint(ps + k);
        float l = length(b.xy - a.xy);
        if(l > 1e-6) dir = (b.xy - a.xy) / l;
        if(acc + l >= s || k == pc - 1){
            vec3 m = mix(a, b, clamp((s - acc) / max(l, 1e-6), 0., 1.));
            pos = m.xy;
            h = m.z;
            return;
        }
        acc += l;
        a = b;
    }
}

// lanes: a car keeps one place across the road (mpPick), its lane on an
// edge of n lanes floor(pick * n); edges are whole carriageways (lanes
// share out its width), so a car's place is offset from the centre line
// into its lane, a connector moving it across from its lane at one end to
// its lane at the other. A car drifts toward its place at no more than
// MP_SHIFT sideways per distance driven, and turns toward the road's
// heading at MP_STEER but no faster than a car of MP_TURN_R turning
// circle could at its speed, so it never jumps, snaps or spins. Besides
// the cars ahead in its lane, any car within MP_BODY car lengths of its
// path and MP_SEE ahead (not oncoming, and at its height: not on a deck
// above or a road beneath) holds it back too, so cars never
// drive through each other; one stuck for MP_PATIENCE only still minds
// cars going its way
float mpPick(int i){ return random(vec2(float(i), 4.2)); }

int mpLaneOf(float pick, int e){ return int(pick * float(mpLanes(e, true))); }

float mpLat(int i, int e, float s){
    float f = mpPick(i);
    float n0 = float(mpLanes(e, false)), n1 = float(mpLanes(e, true));
    float w0 = mpFx(gMpEdge + MP_EDGE_WORDS * e + 8) / n0, w1 = mpFx(gMpEdge + MP_EDGE_WORDS * e + 9) / n1;
    float a = (floor(f * n0) + 0.5 - 0.5 * n0) * w0, b = (floor(f * n1) + 0.5 - 0.5 * n1) * w1;
    return mix(a, b, clamp(s / max(mpLen(e), 1e-6), 0., 1.));
}

// the connector out of e whose start lanes take in lat (nx if its do)
int mpBranchAt(int e, float lat, int nx){
    if(abs(lat - mpOff(nx, false)) <= 0.5 * mpFx(gMpEdge + MP_EDGE_WORDS * nx + 8)) return nx;
    int best = mpNearest(e, lat, -1);
    return best < 0 ? nx : best;
}

// row 0 for car i at s along e
// row 0 for a car at s along e, lat across from the centre line (square
// to the car's own heading, which turns toward the road's by follow, 1 at
// once, so kinks where pieces join never throw it sideways)
vec4 mpPlace(int e, float s, float v, float lat, float heading, float follow, float maxTurn){
    vec2 p, d;
    float h;
    mpAt(e, s, p, d, h);
    float want = atan(d.y, d.x);
    float turn = mod(want - heading + 3.1415927, 6.2831853) - 3.1415927;
    float hd = mod(heading + clamp(turn * follow, -maxTurn, maxTurn) + 3.1415927, 6.2831853) - 3.1415927;
    return vec4(p + vec2(sin(hd), -cos(hd)) * lat, v, mpPack(hd, h));
}

// row 1's w holds both how long a car has been stopped and where across
// the road it is (decimetres)
float mpPackWait(float wait, float lat){ return (floor(clamp(lat / gMpU * 10., -900., 900.) + 0.5) + 1000.) * 256. + min(wait, 255.); }
float mpWait(float w){ return w - 256. * floor(w / 256.); }
float mpLatOf(float w){ return (floor(w / 256.) - 1000.) * 0.1 * gMpU; }

// which lane of e a car lat across from its centre line at s is in
int mpLaneAt(int e, float s, float lat){
    float f = clamp(s / max(mpLen(e), 1e-6), 0., 1.);
    float n = f < 0.5 ? float(mpLanes(e, false)) : float(mpLanes(e, true));
    float w = mix(mpFx(gMpEdge + MP_EDGE_WORDS * e + 8), mpFx(gMpEdge + MP_EDGE_WORDS * e + 9), f);
    return int(clamp(floor((lat / max(w, 1e-6) + 0.5) * n), 0., n - 1.));
}

// off the screen (by MP_OFF): where cars appear and vanish, and where one
// stopped twice MP_PATIENCE gives up and enters again, so a jam nobody
// sees never holds cars back
bool mpOffscreen(vec2 p){ return abs(p.x) > 0.5 * u_aspect + MP_OFF || abs(p.y) > 0.5 + MP_OFF; }

// the screen's gates (rows from MP_GATE_ROW, AG_W edges a row): where edge e
// first comes in across the edge of the screen, the place on it
// MP_GATE_BACK short of that (-1 if it never does; the start of a lane
// nothing leads into that starts on it), its lanes times its baked spawn
// weight, and how many cars on the map came in by it; worked
// out once, the count every frame
vec4 mpGate(sampler2D ch, int e){ return texelFetch(ch, ivec2(e % AG_W, MP_GATE_ROW + e / AG_W), 0); }

bool mpInView(vec2 p){ return abs(p.x) < 0.5 * u_aspect + MP_OFF && abs(p.y) < 0.5 + MP_OFF; }

vec4 mpGateRow(sampler2D ch, int e){
    if(e >= mpWord(gMpBase + 1)) return vec4(-1., 0., 0., 1.);
    vec4 g = mpGate(ch, e);
    if(g.w < 0.5){
        int sw = mpWord(gMpBase + mpWord(gMpBase + 46) + e);
        g = vec4(-1., float(mpLanes(e, false)) * float(sw & 1048575) / 16., 0., 1.);
        float L = mpLen(e);
        vec2 p, d;
        float h;
        mpAt(e, 0., p, d, h);
        bool was = mpInView(p);
        for(int j = 1; j <= MP_GATE_STEPS; j++){
            float s = L * float(j) / float(MP_GATE_STEPS);
            mpAt(e, s, p, d, h);
            bool now = mpInView(p);
            if(now && !was){ g.x = max(s - MP_GATE_BACK * gMpU, 0.); break; }
            was = now;
        }
        mpAt(e, 0., p, d, h);
        if(g.x < 0. && (sw >> 20 & 1) == 1 && mpInView(p)) g.x = 0.;
    }
    g.z = 0.;
    if(g.x >= 0.){
        for(int j = 0; j < MP_N; j++){
            if(j >= gMpCars) break;
            if(agGet(ch, j, 1).x > -0.5 && abs(mpCarMem(ch, j).x - float(e)) < 0.5) g.z += 1.;
        }
    }
    return g;
}

// on a map whose roads all lie on the screen (header 21 bit 1, the map's
// scatter) a car comes in anywhere on them instead of at a gate: on a lane
// of the spawn list at random, on the screen, once no car is within
// MP_GATE_GAP cars of it there; one car in MP_SCATTER_EVERY a frame tries, so
// cars placed in one frame (which cannot see each other) are few
void mpScatter(sampler2D ch, int i, out vec4 r0, out vec4 r1){
    r0 = vec4(MP_AWAY, MP_AWAY, 0., 0.);
    r1 = vec4(-1., 0., -1., 0.);
    int ns = mpWord(gMpBase + 41), st = gMpBase + mpWord(gMpBase + 42), f = int(floor(iTime * 60.));
    if(ns == 0 || (f + i) % MP_SCATTER_EVERY != 0) return;
    float t = mod(float(f), 997.);
    int e = mpWord(st + int(random(vec2(float(i), t + 0.5)) * float(ns)) % ns);
    float s = random(vec2(float(i) + 0.3, t)) * mpLen(e);
    for(int j = 0; j < MP_N; j++){
        if(j >= gMpCars) break;
        vec4 o = agGet(ch, j, 1);
        if(j != i && o.x > -0.5 && int(o.x + 0.5) == e && abs(o.y - s) < MP_GATE_GAP * gMpCar) return;
    }
    float lat = mpLat(i, e, s);
    vec4 p = mpPlace(e, s, 0., lat, 0., 1., 9.);
    if(mpOffscreen(p.xy)) return;
    r0 = p;
    float ex = mpRing(e) ? mpPickExit(i, e) : 0.;
    int nx = mpChoose(ch, i, e, random(vec2(i, iTime)), 0., ex);
    r1 = vec4(float(e), s, mpPackNx(nx, ex), mpPackWait(0., lat));
}

// a car that left the map (or the screen) waits off it (edge -1) for a
// gate with fewer of the cars on the map that came in by it than its share
// (by lanes): it takes one of those at random, by lanes, once the car before
// it there is MP_GATE_GAP cars on
void mpEnter(sampler2D ch, int i, out vec4 r0, out vec4 r1){
    if((mpWord(gMpBase + 21) & 2) != 0){ mpScatter(ch, i, r0, r1); return; }
    r0 = vec4(MP_AWAY, MP_AWAY, 0., 0.);
    r1 = vec4(-1., 0., -1., 0.);
    float total = 0., open = 0.;
    for(int e = 0; e < 4096; e++){
        if(e >= mpWord(gMpBase + 1)) break;
        vec4 g = mpGate(ch, e);
        if(g.x >= 0.) total += g.y;
    }
    if(total <= 0.) return;
    for(int e = 0; e < 4096; e++){
        if(e >= mpWord(gMpBase + 1)) break;
        vec4 g = mpGate(ch, e);
        if(g.x >= 0. && g.z < ceil(float(gMpCars) * g.y / total)) open += g.y;
    }
    if(open <= 0.) return;
    float want = random(vec2(float(i), floor(iTime * 4.))) * open, acc = 0.;
    int e = -1;
    float s = 0.;
    for(int x = 0; x < 4096; x++){
        if(x >= mpWord(gMpBase + 1)) break;
        vec4 g = mpGate(ch, x);
        if(g.x < 0. || g.z >= ceil(float(gMpCars) * g.y / total)) continue;
        acc += g.y;
        if(acc >= want){ e = x; s = g.x; break; }
    }
    if(e < 0) return;
    for(int j = 0; j < MP_N; j++){
        vec4 o = agGet(ch, j, 1);
        if(j != i && o.x > -0.5 && int(o.x + 0.5) == e && abs(o.y - s) < MP_GATE_GAP * gMpCar) return;
    }
    float lat = mpLat(i, e, s);
    r0 = mpPlace(e, s, 0., lat, 0., 1., 9.);
    float ex = mpRing(e) ? mpPickExit(i, e) : 0.;
    int nx = mpChoose(ch, i, e, random(vec2(i, iTime)), 0., ex);
    r1 = vec4(float(e), s, mpPackNx(nx, ex), mpPackWait(0., lat));
}

// whether b is a, or one or two edges on from it
bool mpFollows(int a, int b){
    if(a == b) return true;
    int n = mpE(a, 4), st = gMpSucc + mpE(a, 3);
    for(int j = 0; j < 64; j++){
        if(j >= n) break;
        int x = mpWord(st + j);
        if(x == b) return true;
        int m = mpE(x, 4), s2 = gMpSucc + mpE(x, 3);
        for(int k = 0; k < 64; k++){
            if(k >= m) break;
            if(mpWord(s2 + k) == b) return true;
        }
    }
    return false;
}

// row MP_CAR_ROW for car i, a frame behind its step: a car on an edge it
// could not have driven to from last frame's came onto the map there now;
// w is set once it has been on the screen
vec4 mpRemember(sampler2D ch, int i, bool fresh){
    if(fresh || i >= gMpCars) return vec4(-1., iTime, -1., 0.);
    vec4 m = mpCarMem(ch, i);
    vec2 p = agGet(ch, i, 0).xy;
    float e = agGet(ch, i, 1).x;
    bool came = e > -0.5 && (m.z < -0.5 || !mpFollows(int(m.z + 0.5), int(e + 0.5)));
    float seen = abs(p.x) < 0.5 * u_aspect && abs(p.y) < 0.5 ? 1. : 0.;
    return came ? vec4(e, iTime, e, seen) : vec4(m.xy, e, max(m.w, seen));
}

// what holds car i back: the nearest car ahead in its lane (on its edge or
// the next two), the nearest car in its path, and whether it must give way
void mpSense(sampler2D ch, int i, vec4 s0, vec4 s1, out float laneGap, out float nearGap, out bool yield){
    int e = int(s1.x + 0.5), nx = mpNx(s1.z);
    float s = s1.y, v = s0.z, wait = mpWait(s1.w), lat = mpLatOf(s1.w);
    float L = mpLen(e);
    int nn = nx >= 0 && (mpE(nx, 7) & 1) == 1 ? mpSucc(nx, 0.) : -1;
    float Ln = nx >= 0 ? mpLen(nx) : 0.;
    int give[MP_MAX_GIVE];
    int ng = 0;
    float left = L - s;
    if(nx >= 0 && left < MP_APPROACH * gMpU && wait < MP_PATIENCE){
        ng = min(mpE(nx, 6), MP_MAX_GIVE);
        int g0 = mpE(nx, 5);
        for(int k = 0; k < MP_MAX_GIVE; k++){ if(k >= ng) break; give[k] = mpWord(gMpGive + g0 + k); }
    }
    laneGap = 1e9; nearGap = 1e9;
    float latx = nx >= 0 ? lat + mpOff(e, true) - mpOff(nx, false) : 0.;
    int le = mpLaneAt(e, s, lat), lx = nx >= 0 ? mpLaneAt(nx, 0., latx) : -1;
    int ln = nn >= 0 ? mpLaneAt(nn, 0., latx + mpOff(nx, true) - mpOff(nn, false)) : -1;
    yield = false;
    float hd = mpHeading(s0.w);
    vec2 fw = vec2(cos(hd), sin(hd));
    bool stuck = wait > MP_PATIENCE;
    // the lane this car merges into and how far it has to go to its start
    bool onConn = (mpE(e, 7) & 1) == 1, nxConn = nx >= 0 && (mpE(nx, 7) & 1) == 1;
    int tgt = onConn ? nx : nxConn ? mpSucc(nx, 0.) : -1;
    float toTgt = onConn ? left : left + Ln;
    // nothing it minds lies further than MP_REACH metres off (along the
    // road is never shorter than straight), so cars beyond it are passed over
    // before anything else is read of them
    float reach = MP_REACH * gMpU;
    for(int j = 0; j < MP_N; j++){
        if(j >= gMpCars) break;
        if(j == i) continue;
        vec4 op = agGet(ch, j, 0);
        vec2 rel = op.xy - s0.xy;
        if(dot(rel, rel) > reach * reach) continue;
        vec4 o = agGet(ch, j, 1);
        if(o.x < -0.5) continue;
        int oe = int(o.x + 0.5);
        float ahead = dot(rel, fw), side = abs(dot(rel, vec2(-fw.y, fw.x)));
        bool level = abs(mpHeight(op.w) - mpHeight(s0.w)) < 0.5;
        // two cars on top of each other: the one behind waits (on a tie, or
        // when each has the other ahead as where two roads meet, the higher
        // index), so they part
        if(level && dot(rel, rel) < 0.25 * gMpCar * gMpCar){
            float oh = mpHeading(op.w);
            bool mutual = ahead > 1e-6 && dot(-rel, vec2(cos(oh), sin(oh))) > 1e-6;
            if(mutual ? j < i : ahead > 1e-6 || ahead > -1e-6 && j < i) nearGap = 0.;
        }
        // a car known to be in another lane (of this road, the next ones,
        // or the one both are about to take) is never in the way
        int ol = oe == e || oe == nx || oe == nn ? mpLaneAt(oe, o.y, mpLatOf(o.w)) : -1;
        int on = mpNx(o.z);
        // nor one on (or about to take) another lane's connector out of the
        // same road, or one into another lane of the same road from another
        // lane
        int mc = onConn ? e : nxConn ? nx : -1;
        int oc = (mpE(oe, 7) & 1) == 1 ? oe : on >= 0 && (mpE(on, 7) & 1) == 1 ? on : -1;
        bool sameIn = mc >= 0 && oc >= 0 && mc != oc && mpPred(mc) == mpPred(oc);
        bool sameOut = mc >= 0 && oc >= 0 && mc != oc && mpSucc(mc, 0.) == mpSucc(oc, 0.);
        bool intoLane = sameOut && abs(mpOff(mc, true) - mpOff(oc, true)) < 1e-4;
        // two cars on one road making for the same lane past the junction
        // queue as one lane already (so they reach it one by one)
        bool oNx = on >= 0 && (mpE(on, 7) & 1) == 1;
        bool sameLane = oe == e && nxConn && oNx && mpSucc(on, 0.) == mpSucc(nx, 0.) && abs(mpOff(on, true) - mpOff(nx, true)) < 1e-4;
        bool apart = oe == e && ol != le && !sameLane || oe == nx && ol != lx || oe == nn && ol != ln
                  || nx >= 0 && on == nx && oe != e && mpLaneAt(nx, 0., mpLatOf(o.w) + mpOff(oe, true) - mpOff(nx, false)) != lx
                  || sameIn && abs(mpOff(mc, false) - mpOff(oc, false)) > 1e-4 && !intoLane
                  || sameOut && !intoLane && !(sameIn && abs(mpOff(mc, false) - mpOff(oc, false)) < 1e-4);
        // two cars about to merge into one lane from different roads: the
        // one further from the merge follows the nearer one (a zipper)
        bool oConn = (mpE(oe, 7) & 1) == 1, oNxConn = on >= 0 && (mpE(on, 7) & 1) == 1;
        int otgt = oConn ? on : oNxConn ? mpSucc(on, 0.) : -1;
        bool partner = tgt >= 0 && otgt == tgt && oe != e && (on != nx || onConn && oConn) && level && (mc < 0 || oc < 0 || intoLane);
        if(partner && !apart && wait < 2. * MP_PATIENCE){
            float oTo = mpLen(oe) - o.y + (oConn ? 0. : mpLen(on));
            if(oTo < toTgt || oTo == toTgt && j < i) laneGap = min(laneGap, toTgt - oTo);
        }
        if(!apart && !partner && ahead > 0. && ahead < MP_SEE * gMpCar && side < MP_BODY * gMpCar && level){
            float oh = mpHeading(op.w);
            vec2 ofw = vec2(cos(oh), sin(oh));
            // two cars each seeing the other in front (lanes merging): the
            // lower index goes first; one stuck past its patience minds only
            // cars that are moving
            bool mutual = dot(-rel, ofw) > 0. && abs(dot(rel, vec2(-ofw.y, ofw.x))) < MP_BODY * gMpCar;
            bool still = op.z < MP_CRAWL * gMpU;
            if(dot(ofw, fw) > (stuck ? 0.7 : -0.3) && !(mutual && j > i) && !(stuck && still)) nearGap = min(nearGap, ahead);
        }
        if(oe == e && (o.y > s || (o.y == s && j < i)) && (ol == le || sameLane)) laneGap = min(laneGap, o.y - s);
        else if(oe == nx && ol == lx) laneGap = min(laneGap, left + o.y);
        else if(oe == nn && ol == ln) laneGap = min(laneGap, left + Ln + o.y);
        // courtesy at a merge: one waiting at its line to give way into the
        // connector this car is about to take is let in
        if(!yield && nx >= 0 && on >= 0 && left < MP_APPROACH * gMpU && wait < MP_PATIENCE && mpWait(o.w) > MP_COURTESY
           && op.z < MP_CRAWL * gMpU && mpLen(oe) - o.y < 2. * gMpCar){
            int g0 = mpE(on, 5), gn = min(mpE(on, 6), MP_MAX_GIVE);
            for(int k = 0; k < MP_MAX_GIVE; k++){
                if(k >= gn) break;
                if(mpWord(gMpGive + g0 + k) == nx){ yield = true; break; }
            }
        }
        // giving way (to a car within MP_LOOK on a connector it gives way to)
        // into the road it joins, only to a car that ends up in
        // the same lane of it
        if(ng > 0 && !yield){
            for(int k = 0; k < MP_MAX_GIVE; k++){
                if(k >= ng) break;
                int gc = give[k], gt = mpSucc(gc, 0.);
                float glat = mpLatOf(o.w) + (oe == gc ? 0. : mpOff(oe, true) - mpOff(gc, false)) + mpOff(gc, true) - mpOff(gt, false);
                bool beside = nn >= 0 && gt == nn && mpLaneAt(gt, 0., glat) != ln;
                if(oe == gc && !beside && length(rel) < MP_LOOK * gMpU){ yield = true; break; }
                float to = mpLen(oe) - o.y;
                bool moving = op.z > MP_CRAWL * gMpU;
                if(on == gc && !beside && (mpE(oe, 7) & 1) == 0 && moving && to < MP_LOOK * gMpU && (to < MP_CLOSE * gMpU || to < op.z * MP_ACCEPT)){ yield = true; break; }
            }
        }
    }
    // stopped for twice its patience a car minds only its lane: whatever
    // standoff held it, it drives out of it
    if(wait > 2. * MP_PATIENCE) nearGap = 1e9;
}

// whether a car at s on e has another in the lane of e at lat beside it
bool mpBeside(sampler2D ch, int i, int e, float s, float lat){
    int want = mpLaneAt(e, s, lat);
    for(int j = 0; j < MP_N; j++){
        if(j >= gMpCars) break;
        if(j == i) continue;
        vec4 o = agGet(ch, j, 1);
        if(o.x < -0.5 || int(o.x + 0.5) != e || abs(o.y - s) > MP_SHIFT_ROOM * gMpCar) continue;
        if(mpLaneAt(e, o.y, mpLatOf(o.w)) == want) return true;
    }
    return false;
}

// on a big ring a car makes for the lane for the exits it has left (k): of
// its own lane and the two beside it it takes the one with the most room
// ahead (cars on the ring up to MP_RING_SEE cars on, sorted into lanes by
// how far across they are), a lane nearer that lane counting
// 1.5 MP_RING_FREER cars more and staying put MP_RING_FREER, where there is
// room beside; for its own exit (k 1) always the outer lane
float mpRingTarget(sampler2D ch, int i, int e, float s, float lat, float k, vec2 pos, float hd){
    float want = mpRingLat(e, s, k);
    if(k < 1.5) return want;
    float f = clamp(s / max(mpLen(e), 1e-6), 0., 1.);
    int n = mpLanes(e, f > 0.5), d = int(clamp(k, 1., float(n))) - 1, cur = mpLaneAt(e, s, lat);
    float lw = mix(mpFx(gMpEdge + MP_EDGE_WORDS * e + 8), mpFx(gMpEdge + MP_EDGE_WORDS * e + 9), f) / float(n);
    float sgn = (mpWord(gMpBase + 21) & 1) == 1 ? -1. : 1., see = MP_RING_SEE * gMpCar;
    vec2 fw = vec2(cos(hd), sin(hd)), rt = vec2(sin(hd), -cos(hd));
    vec3 gap = vec3(see);
    for(int j = 0; j < MP_N; j++){
        if(j >= gMpCars) break;
        if(j == i) continue;
        vec4 o = agGet(ch, j, 1);
        if(o.x < -0.5 || !mpRing(int(o.x + 0.5))) continue;
        vec2 rel = agGet(ch, j, 0).xy - pos;
        float ahead = dot(rel, fw);
        if(ahead <= 0. || ahead > see) continue;
        float dl = floor(-dot(rel, rt) * sgn / lw + 0.5);
        if(dl == -1.) gap.x = min(gap.x, ahead);
        else if(dl == 0.) gap.y = min(gap.y, ahead);
        else if(dl == 1.) gap.z = min(gap.z, ahead);
    }
    float freer = MP_RING_FREER * gMpCar, score = -1e9;
    int best = cur;
    for(int t = -1; t <= 1; t++){
        int l = cur + t;
        if(l < 0 || l >= n) continue;
        float sc = (t == -1 ? gap.x : t == 0 ? gap.y : gap.z) + (abs(l - d) < abs(cur - d) ? 1.5 * freer : 0.) + (t == 0 ? freer : 0.);
        if(sc > score){ score = sc; best = l; }
    }
    float to = mpRingLat(e, s, float(best + 1));
    return best != cur && mpBeside(ch, i, e, s, to) ? lat : to;
}

// how far round a screen cell the bins list cars: as far as one is drawn
// (its headlights, on the highest deck) and drives between two rescans of
// that cell (MP_BIN_MOVE metres)
float mpBinReach(){ return 1.8 * max(gMpCar * MP_CAR_DRAW, 0.008) * (1. + 0.08 * MP_LIFT_TOP) + MP_BIN_MOVE * gMpU; }

// row MP_SENSE_ROW for car i: what holds it back (mpSense), worked out once a
// frame for both its rows to read the next (a frame late)
vec4 mpSensed(sampler2D ch, int i, bool fresh){
    vec4 s0 = agGet(ch, i, 0), s1 = agGet(ch, i, 1);
    if(fresh || i >= gMpCars || s1.x < -0.5) return vec4(1e9, 1e9, 0., 0.);
    float laneGap, nearGap;
    bool yield;
    mpSense(ch, i, s0, s1, laneGap, nearGap, yield);
    return vec4(laneGap, nearGap, yield ? 1. : 0., 0.);
}

void mpStep(sampler2D ch, int i, float dt, bool fresh, out vec4 r0, out vec4 r1){
    mpLoad();
    dt *= MP_TIME;
    if(i >= gMpCars){ r0 = vec4(MP_AWAY, MP_AWAY, 0., 0.); r1 = vec4(-2., 0., -1., 0.); return; }
    if(fresh){ r0 = vec4(MP_AWAY, MP_AWAY, 0., 0.); r1 = vec4(-1., 0., -1., 0.); return; }
    vec4 s0 = agGet(ch, i, 0), s1 = agGet(ch, i, 1);
    if(s1.x < -0.5){ mpEnter(ch, i, r0, r1); return; }
    int e = int(s1.x + 0.5), nx = mpNx(s1.z);
    float s = s1.y, v = s0.z, wait = mpWait(s1.w), lat = mpLatOf(s1.w), exits = mpExitsLeft(s1.z);
    if(wait > 2. * MP_PATIENCE && mpOffscreen(s0.xy)){ mpEnter(ch, i, r0, r1); return; }
    float L = mpLen(e), left = L - s;
    vec4 sensed = texelFetch(ch, ivec2(i, MP_SENSE_ROW), 0);
    float laneGap = sensed.x, nearGap = sensed.y;
    bool yield = sensed.z > 0.5;
    float gap = min(laneGap, nearGap);
    float vmax = mpSpeed(e) * (0.85 + 0.15 * random(vec2(i, 6.6)));
    float want = vmax * clamp((gap - MP_GAP * gMpCar) / (3. * gMpCar), 0., 1.);
    if(nx >= 0) want = min(want, mix(mpSpeed(nx), vmax, clamp(left / (15. * gMpU), 0., 1.)));
    int light = nx >= 0 ? mpSig(nx) : -1;
    bool stopLight = light == 2 || light == 1 && left > v * v / (2. * MP_BRAKE * gMpU) + 2. * gMpU;
    if(yield || stopLight) want = min(want, vmax * clamp((left - 0.6 * gMpU) / (10. * gMpU), 0., 1.));
    v += clamp(want - v, -MP_BRAKE * gMpU * dt, MP_ACC * gMpU * dt);
    v = max(v, 0.);
    s += v * dt;
    wait = v < MP_CRAWL * gMpU ? wait + dt : 0.;
    for(int k = 0; k < 2; k++){
        if(s < L) break;
        if(nx < 0){ mpEnter(ch, i, r0, r1); return; }
        s -= L;
        lat += mpOff(e, true) - mpOff(nx, false);
        int on;
        if(!mpRing(e) && mpRing(nx)){ if(exits < 0.5) exits = mpPickExit(i, nx); }
        else if(mpRing(nx) && mpRingExit(e, on)) exits = max(exits - 1., 1.);
        else if(mpRing(e) && !mpRing(nx)) exits = 0.;
        e = nx;
        L = mpLen(e);
        nx = mpChoose(ch, i, e, random(vec2(float(i) + floor(iTime * 7.), float(e) * 0.37)), mpHome(ch, i), exits);
    }
    s = min(s, L);
    // a car near a junction making for a connector whose road is backed up
    // takes a clearly freer one out of the same road, changing lanes for it
    // (even late, even from a standstill) where there is room beside
    bool shift = false;
    if(nx >= 0 && !mpRing(e) && (mpE(nx, 7) & 1) == 1 && L - s < MP_LANE_CHOOSE * gMpU){
        float room;
        int alt = mpFreest(ch, e, room);
        float cur = mpRoom(ch, nx);
        if(alt >= 0 && alt != nx && cur < 2. * MP_FULL && room > 2. * cur){ nx = alt; if(!mpRing(mpSucc(alt, 0.))) exits = 0.; }
        int own = mpBranchAt(e, lat, nx);
        float ownRoom = mpRoom(ch, own);
        shift = own != nx && ownRoom < 2. * MP_FULL && mpRoom(ch, nx) > 2. * ownRoom;
    }
    // before a junction a car moves into the lane that feeds the connector
    // it takes (a split's own lanes, an exit's side) over MP_LANE_CHOOSE;
    // over the last MP_LANE_LOCK it keeps its lane, and if that lane feeds
    // another branch it takes that one instead
    float target = mpLat(i, e, s), step = MP_SHIFT * v * dt;
    // and over the first MP_LANE_LOCK after a junction it keeps it too, as
    // far as the road it is on has lanes there
    if((mpE(e, 7) & 1) == 0 && (mpE(e, 12) >> 20 & 1) == 0 && s < MP_LANE_LOCK * gMpU) target = lat;
    if(shift){
        target = mpBeside(ch, i, e, s, mpOff(nx, false)) ? lat : mpOff(nx, false);
        step = MP_SHIFT * max(v, MP_SHIFT_CREEP * gMpU) * dt;
    }
    else if(nx >= 0 && (mpE(nx, 7) & 1) == 1){
        float lock = MP_LANE_LOCK * gMpU;
        if(L - s > lock)
            target = mix(target, mpOff(nx, false) + mpLat(i, nx, 0.), clamp(1. - (L - s - lock) / (MP_LANE_CHOOSE * gMpU), 0., 1.));
        else {
            target = lat;
            nx = mpBranchAt(e, lat, nx);
        }
    }
    // and an exit whose road is backed up to the ring it passes, going
    // round again to take the next one
    int again;
    if(mpRing(e) && nx >= 0 && !mpRing(nx) && mpRingExit(e, again) && again >= 0 && L - s < MP_LANE_CHOOSE * gMpU){
        int after = mpSucc(nx, 0.);
        for(int j = 0; j < MP_N; j++){
            if(j >= gMpCars) break;
            vec4 o = agGet(ch, j, 1);
            int oe = int(o.x + 0.5);
            if(o.x > -0.5 && (oe == nx || oe == after && o.y < 3. * gMpCar) && agGet(ch, j, 0).z < MP_CRAWL * gMpU){ nx = mpNearest(e, lat, 1); break; }
        }
    }
    if(mpRing(e) && mpLanes(e, false) >= MP_RING_LANES){
        target = mpRingTarget(ch, i, e, s, lat, exits, s0.xy, mpHeading(s0.w));
        step = MP_SHIFT * max(v, MP_SHIFT_CREEP * gMpU) * dt;
    }
    lat += clamp(target - lat, -step, step);
    if((mpE(e, 7) & 1) == 0){
        float f = clamp(s / max(L, 1e-6), 0., 1.);
        float n = mix(float(mpLanes(e, false)), float(mpLanes(e, true)), f);
        float w = mix(mpFx(gMpEdge + MP_EDGE_WORDS * e + 8), mpFx(gMpEdge + MP_EDGE_WORDS * e + 9), f);
        float lim = 0.5 * w * (1. - 1. / n);
        lat = clamp(lat, -lim, lim);
    }
    r0 = mpPlace(e, s, v, lat, mpHeading(s0.w), 1. - exp(-dt * MP_STEER), (v / (MP_TURN_R * gMpU) + 0.3) * dt);
    r1 = vec4(float(e), s, mpPackNx(nx, exits), mpPackWait(wait, lat));
    float hd = mpHeading(r0.w);
    // off the screen a car is no use: one that has been on it goes at once,
    // one still coming in after MP_COMING
    vec4 mem = mpCarMem(ch, i);
    bool known = mem.z > -0.5 && mpFollows(int(mem.z + 0.5), e);
    if(mpOffscreen(r0.xy) && (dot(r0.xy, vec2(cos(hd), sin(hd))) > 0. || known && (mem.w > 0.5 || iTime - mem.y > MP_COMING))) mpEnter(ch, i, r0, r1);
}

// signed distance from p to a footprint (corners v[0..n), negative inside)
float mpPoly(vec2 v[MP_BLD_MAX_V], int n, vec2 p){
    vec2 a = v[n - 1];
    float d = 1e9;
    bool inside = false;
    for(int k = 0; k < MP_BLD_MAX_V; k++){
        if(k >= n) break;
        vec2 b = v[k], e = b - a, w = p - a;
        vec2 r = w - e * clamp(dot(w, e) / max(dot(e, e), 1e-12), 0., 1.);
        d = min(d, dot(r, r));
        if((a.y > p.y) != (b.y > p.y) && p.x < e.x * (p.y - a.y) / (b.y - a.y) + a.x) inside = !inside;
        a = b;
    }
    return (inside ? -1. : 1.) * sqrt(d);
}

// the buildings at q: how much shadow they cast on the ground there, and
// their walls and roofs (grey, lit window, -, coverage) to lay over the
// rest. A
// building of height h (screen units) rises MP_BLD_VIEW * h up the screen,
// its walls the footprint swept up there (MP_BLD_WALL samples), lit
// windows at random; its shadow falls MP_BLD_SUN * h along MP_SHADOW.
// Footprints in front (lower on screen) cover those behind.
vec4 mpBuildings(vec2 q, int ci, out float shade){
    shade = 0.;
    vec4 o = vec4(0.);
    int n = mpWord(ci + 1), st = gMpBase + mpWord(gMpBase + 27) + mpWord(ci);
    int tb = gMpBase + mpWord(gMpBase + 24), tv = gMpBase + mpWord(gMpBase + 25);
    float front = -1e9;
    for(int k = 0; k < MP_BLD_CELL; k++){
        if(k >= n) break;
        int bi = mpWord(st + k), r = tb + 7 * bi;
        float h = mpFx(r + 2);
        vec2 lo = vec2(mpFx(r + 3), mpFx(r + 4)), hi = vec2(mpFx(r + 5), mpFx(r + 6));
        vec2 sv = MP_SHADOW * MP_BLD_SUN * h, up = vec2(0., MP_BLD_VIEW * h);
        vec2 elo = min(lo, lo + sv) - 0.003, ehi = max(hi + up, hi + sv) + 0.003;
        if(any(lessThan(q, elo)) || any(greaterThan(q, ehi))) continue;
        int vs = mpWord(r), vc = min(mpWord(r + 1), MP_BLD_MAX_V);
        vec2 v[MP_BLD_MAX_V];
        for(int j = 0; j < MP_BLD_MAX_V; j++){
            if(j >= vc) break;
            v[j] = vec2(mpFx(tv + 2 * (vs + j)), mpFx(tv + 2 * (vs + j) + 1));
        }
        shade = max(shade, smoothstep(0.003, -0.002, mpPoly(v, vc, q - sv)));
        if(q.y < lo.y - 0.002 || q.y > hi.y + up.y + 0.002) continue;
        float roof = mpPoly(v, vc, q - up);
        float wall = 1e9, wt = 0.;
        int ns = clamp(int(up.y / 0.0025) + 1, 1, MP_BLD_WALL);
        for(int j = 0; j < MP_BLD_WALL; j++){
            if(j >= ns) break;
            float t = float(j) / float(ns);
            float d = mpPoly(v, vc, q - up * t);
            if(d < wall){ wall = d; wt = t; }
        }
        float a = max(S(roof), S(wall));
        if(a < 0.01 || -lo.y < front - 1e-4) continue;
        front = -lo.y;
        float rnd = random(vec2(float(bi), 3.3));
        float rc = 0.085 + 0.03 * rnd + 0.015 * smoothstep(0., 0.05, h);
        rc = mix(rc, 0.2, S(abs(roof + 0.0007) - 0.0006) * 0.7);
        float hm = h / gMpU;
        vec2 win = vec2(q.x / (2.6 * gMpU), wt * hm / 3.2);
        vec2 wc = floor(win), wf = fract(win);
        float lit = step(0.78, random(wc + float(bi))) * step(0.25, wf.x) * step(wf.x, 0.75) * step(0.3, wf.y) * step(wf.y, 0.75);
        bool onRoof = roof < 0. || S(roof) > S(wall);
        vec2 c = onRoof ? vec2(rc, 0.) : vec2(0.045 + 0.03 * wt, lit * step(0.08, wt));
        o = vec4(mix(o.rg, c, a), 0., max(o.a, a));
    }
    return o;
}

// the map's static layer, baked once per map into bufferMapStatic: r the
// ground and roads (grey) + 2 * how green there, + 32 * how much water
// and + 512 * how much parked car (all in 15ths), g the height of the top
// surface / 4 + 4 * the parked car's shade (15ths), b the
// buildings' grey (+ 2 on a lit window), a their coverage
float mpPolyG(vec2 v[MP_GREEN_MAX_V], int n, vec2 p){
    vec2 a = v[n - 1];
    float d = 1e9;
    bool inside = false;
    for(int k = 0; k < MP_GREEN_MAX_V; k++){
        if(k >= n) break;
        vec2 b = v[k], e = b - a, w = p - a;
        vec2 r = w - e * clamp(dot(w, e) / max(dot(e, e), 1e-12), 0., 1.);
        d = min(d, dot(r, r));
        if((a.y > p.y) != (b.y > p.y) && p.x < e.x * (p.y - a.y) / (b.y - a.y) + a.x) inside = !inside;
        a = b;
    }
    return (inside ? -1. : 1.) * sqrt(d);
}

// green areas at q (gen_maps GREEN: lawns, parks, woods): how green, and
// the ground there as grey (water first, then grass texture, then tree
// crowns lit from the top left, overhanging banks, their shadows along
// MP_SHADOW). Trees stand on a jittered grid,
// sparse in parks and dense in woods; one is kept if its trunk is inside
// the nearest green area, and its crown may overhang the edge. The crowns
// and their shadows come back apart (crown: coverage, grey; shadow) so
// they can go over the footpaths
float mpGreen(vec2 q, int ci, inout float grey, inout float water, out vec2 crown, out float shadow){
    int n = mpWord(ci + 1), st = gMpBase + mpWord(gMpBase + 32) + mpWord(ci);
    int tg = gMpBase + mpWord(gMpBase + 29), tv = gMpBase + mpWord(gMpBase + 30);
    crown = vec2(0.);
    shadow = 0.;
    float reach = MP_TREE_R * gMpU;
    float near = 1e9, kind = -1.;
    vec2 bv[MP_GREEN_MAX_V];
    int bn = 0;
    for(int k = 0; k < MP_GREEN_CELL; k++){
        if(k >= n) break;
        int gi = mpWord(st + k), r = tg + 7 * gi;
        vec2 lo = vec2(mpFx(r + 3), mpFx(r + 4)) - reach, hi = vec2(mpFx(r + 5), mpFx(r + 6)) + reach;
        if(any(lessThan(q, lo)) || any(greaterThan(q, hi))) continue;
        int vs = mpWord(r), vc = min(mpWord(r + 1), MP_GREEN_MAX_V);
        vec2 v[MP_GREEN_MAX_V];
        for(int j = 0; j < MP_GREEN_MAX_V; j++){
            if(j >= vc) break;
            v[j] = vec2(mpFx(tv + 2 * (vs + j)), mpFx(tv + 2 * (vs + j) + 1));
        }
        float d = mpPolyG(v, vc, q);
        if(mpWord(r + 2) == 3){ water = max(water, S(d)); continue; }
        if(d < near){ near = d; kind = float(mpWord(r + 2)); bv = v; bn = vc; }
    }
    float ripple = 0.045 + 0.015 * tcFbm(vec2(q.x * 0.6, q.y * 1.6) / (5. * gMpU)) + 0.007 * tcNoise(q / (1.5 * gMpU));
    grey = mix(grey, ripple, water);
    if(near > reach) return 0.;
    float g = S(near) * (1. - water);
    float lawn = 0.045 + 0.02 * tcFbm(q / (6. * gMpU)) + 0.01 * tcNoise(q / (1.2 * gMpU));
    float ground = mix(grey, lawn, g);
    if(kind >= 1.){
        float sp = (kind >= 2. ? 6.5 : 12.) * gMpU, dens = kind >= 2. ? 0.9 : 0.45;
        vec2 ci2 = floor(q / sp);
        float cr = 1e9, shade = 0., sh = 1e9;
        for(int y = -1; y <= 1; y++) for(int x = -1; x <= 1; x++){
            vec2 c = ci2 + vec2(x, y);
            if(random(c + 0.37) > dens) continue;
            vec2 ctr = (c + 0.2 + 0.6 * vec2(random(c), random(c + 7.1))) * sp;
            if(mpPolyG(bv, bn, ctr) > 0.) continue;
            float rad = (2.2 + 2.2 * random(c + 3.3)) * gMpU;
            float d = length(q - ctr) - rad;
            if(d < cr){ cr = d; shade = dot(normalize(q - ctr + 1e-6), normalize(-MP_SHADOW)) * clamp(1. + d / rad, 0., 1.); }
            sh = min(sh, length(q - ctr - MP_SHADOW * rad * 1.4) - rad);
        }
        shadow = 0.45 * smoothstep(0.002, -0.002, sh);
        crown = vec2(S(cr), 0.075 + 0.035 * shade + 0.02 * tcNoise(q / (0.8 * gMpU)));
        water *= 1. - crown.x;
    }
    grey = ground;
    return g;
}

// parked cars at q (gen_maps parked): amps in their bays, each its own
// shade of the car colours (shade out), with a small shadow; returns how
// much of q they cover
float mpParked(vec2 q, int ci, inout vec3 col, out float shade){
    int n = mpWord(ci + 1), st = gMpBase + mpWord(gMpBase + 36) + mpWord(ci);
    int tb = gMpBase + mpWord(gMpBase + 34);
    float sz = max(gMpCar * MP_CAR_DRAW, 0.008), cov = 0.;
    shade = 0.;
    for(int k = 0; k < MP_PARK_CELL; k++){
        if(k >= n) break;
        int pi = mpWord(st + k), r = tb + 3 * pi;
        vec2 p = vec2(mpFx(r), mpFx(r + 1));
        if(length(q - p) > sz * 1.2) continue;
        float a = float(mpWord(r + 2)) / 4096. * 6.2831853;
        vec2 f = vec2(cos(a), sin(a));
        col *= 1. - 0.35 * S(agAmp(q, p + MP_SHADOW * sz * 0.12, f, sz) - sz * 0.05);
        float c = S(agAmp(q, p, f, sz));
        if(c > cov){ cov = c; shade = random(vec2(float(pi), 5.5)); }
    }
    return cov;
}

// signed distance from p to triangle abc (negative inside)
float mpTri(vec2 p, vec2 a, vec2 b, vec2 c){
    vec2 e0 = b - a, e1 = c - b, e2 = a - c, v0 = p - a, v1 = p - b, v2 = p - c;
    vec2 p0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0., 1.);
    vec2 p1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0., 1.);
    vec2 p2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0., 1.);
    float sg = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(p0, p0), sg * (v0.x * e0.y - v0.y * e0.x)), vec2(dot(p1, p1), sg * (v1.x * e1.y - v1.y * e1.x))),
                 vec2(dot(p2, p2), sg * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}

// the ground's height at q (screen units), across the terrain grid
float mpTerrain(vec2 q){
    int nx = mpWord(gMpBase + 12), ny = mpWord(gMpBase + 13);
    vec2 g = clamp((q - vec2(mpFx(gMpBase + 14), mpFx(gMpBase + 15))) / mpFx(gMpBase + 16), vec2(0.), vec2(nx, ny) - 0.001);
    ivec2 c = ivec2(floor(g));
    vec2 f = g - vec2(c);
    int t = gMpBase + mpWord(gMpBase + 43) + c.y * (nx + 1) + c.x;
    return mix(mix(mpFx(t), mpFx(t + 1), f.x), mix(mpFx(t + nx + 1), mpFx(t + nx + 2), f.x), f.y);
}

// hillshade: the ground lit from the sun (against MP_SHADOW), its slopes
// MP_HILL_EXAG times as steep, 1 on the flat; worked out at the corners of
// the terrain grid (from their neighbours' heights) and blended across it
float mpHillAt(int t0, int nx, int ny, int x, int y, float cs){
    x = clamp(x, 1, nx - 1); y = clamp(y, 1, ny - 1);
    int t = t0 + y * (nx + 1) + x;
    vec2 d = vec2(mpFx(t + 1) - mpFx(t - 1), mpFx(t + nx + 1) - mpFx(t - nx - 1)) / (2. * cs) * MP_HILL_EXAG;
    vec3 n = normalize(vec3(-d, 1.)), sun = normalize(vec3(-MP_SHADOW, 1.));
    return clamp(dot(n, sun) / sun.z, 1. - MP_HILL, 1. + MP_HILL);
}

float mpHill(vec2 q){
    int nx = mpWord(gMpBase + 12), ny = mpWord(gMpBase + 13), t0 = gMpBase + mpWord(gMpBase + 43);
    float cs = mpFx(gMpBase + 16);
    vec2 g = clamp((q - vec2(mpFx(gMpBase + 14), mpFx(gMpBase + 15))) / cs, vec2(0.), vec2(nx, ny) - 0.001);
    ivec2 c = ivec2(floor(g));
    vec2 f = smoothstep(0., 1., g - vec2(c));
    return mix(mix(mpHillAt(t0, nx, ny, c.x, c.y, cs), mpHillAt(t0, nx, ny, c.x + 1, c.y, cs), f.x),
               mix(mpHillAt(t0, nx, ny, c.x, c.y + 1, cs), mpHillAt(t0, nx, ny, c.x + 1, c.y + 1, cs), f.x), f.y);
}

// the terrain stands up the screen as buildings do (MP_BLD_VIEW of its
// height, MP_TERRAIN_EXAG times as high): the ground a pixel shows is the
// one nearest the viewer (lowest on the screen) whose lifted place is it,
// found by marching up from MP_TERRAIN_LMAX below and halving in on it
vec2 mpGround(vec2 q, out float lift){
    float k = MP_BLD_VIEW * MP_TERRAIN_EXAG, lo = q.y - MP_TERRAIN_LMAX, dy = MP_TERRAIN_LMAX / float(MP_TERRAIN_STEPS);
    float y0 = lo, y1 = q.y;
    bool hit = false;
    for(int i = 0; i <= MP_TERRAIN_STEPS; i++){
        float y = lo + float(i) * dy;
        if(y + k * mpTerrain(vec2(q.x, y)) >= q.y){ y1 = y; y0 = y - dy; hit = true; break; }
    }
    if(!hit){ lift = 0.; return q; }
    for(int i = 0; i < 6; i++){
        float y = 0.5 * (y0 + y1);
        if(y + k * mpTerrain(vec2(q.x, y)) >= q.y) y1 = y; else y0 = y;
    }
    lift = q.y - y1;
    return vec2(q.x, y1);
}

vec4 mpStatic(vec2 q){
    mpLoad();
    float lift;
    q = mpGround(q, lift);
    vec3 col = vec3(0.03) + bgNoise(q * NOISE_SCALE) * 0.15;
    int nx = mpWord(gMpBase + 12), ny = mpWord(gMpBase + 13);
    vec2 mn = vec2(mpFx(gMpBase + 14), mpFx(gMpBase + 15));
    float cs = mpFx(gMpBase + 16);
    ivec2 c = ivec2(floor((q - mn) / cs));
    vec2 sh = MP_SHADOW * MP_DECK * gMpU;
    float road[MP_LAYERS], line[MP_LAYERS], sdw[MP_LAYERS], hgt[MP_LAYERS];
    for(int l = 0; l < MP_LAYERS; l++){ road[l] = 1e9; line[l] = 1e9; sdw[l] = 1e9; hgt[l] = 0.; }
    float bare = 1e9, path = 1e9, pathHi = 1e9, river = 1e9, water = 0., parked = 0., pshade = 0.;
    float wall = 1e9, wallShade = 1e9;
    if(c.x >= 0 && c.y >= 0 && c.x < nx && c.y < ny){
        int ci = gMpBase + mpWord(gMpBase + 10) + 2 * (c.y * nx + c.x);
        int st = gMpBase + mpWord(gMpBase + 11) + mpWord(ci), n = mpWord(ci + 1);
        int seg = gMpBase + mpWord(gMpBase + 8);
        for(int k = 0; k < MP_SEG_CELL; k++){
            if(k >= n) break;
            int o = seg + 9 * mpWord(st + k);
            vec2 a = vec2(mpFx(o), mpFx(o + 1)), b = vec2(mpFx(o + 2), mpFx(o + 3));
            float hw = mpFx(o + 4);
            int kind = mpWord(o + 6), l = clamp((kind >> 4 & 15), 0, MP_LAYERS - 1);
            vec2 ab = b - a;
            float ab2 = max(dot(ab, ab), 1e-12);
            float t = clamp(dot(q - a, ab) / ab2, 0., 1.);
            float d = length(q - a - ab * t);
            if((kind & 15) == 2){
                float arc = mpFx(o + 5) + t * length(ab);
                if(fract(arc / (MP_DASH * gMpCar)) < 0.5) line[l] = min(line[l], d);
                continue;
            }
            if((kind & 15) == 5){ river = min(river, d - hw); continue; }
            if((kind & 15) == 7){
                wall = min(wall, d - hw);
                vec2 qs = q - sh * mpFx(o + 7) * 4.;
                float ts = clamp(dot(qs - a, ab) / ab2, 0., 1.);
                wallShade = min(wallShade, length(qs - a - ab * ts) - hw);
                continue;
            }
            if((kind & 15) == 6){
                vec2 c3 = vec2(hw, mpFx(o + 5));
                float dt = mpTri(q, a, b, c3) - MP_JUNCTION_PAD * gMpU;
                if(dt < road[l]){
                    vec2 e0 = b - a, e1 = c3 - a, pq = q - a;
                    float den = e0.x * e1.y - e0.y * e1.x;
                    vec2 w = abs(den) > 1e-12 ? clamp(vec2(pq.x * e1.y - pq.y * e1.x, e0.x * pq.y - e0.y * pq.x) / den, 0., 1.) : vec2(0.);
                    road[l] = dt;
                    hgt[l] = mpFx(o + 7) * 4. * (1. - w.x - w.y) + mpFx(o + 8) * 4. * w.x + float(kind >> 12) / 256. * w.y;
                }
                continue;
            }
            if((kind & 15) == 4){
                float pd = d - max(hw, 0.0007);
                if(l > MP_GROUND) pathHi = min(pathHi, pd); else path = min(path, pd);
                continue;
            }
            float ha = mpFx(o + 7) * 4., hb = mpFx(o + 8) * 4.;
            if(d - hw < road[l]){ road[l] = d - hw; hgt[l] = mix(ha, hb, t); }
            if(max(ha, hb) < 0.02) continue;
            float hc = mix(ha, hb, t);
            vec2 qs = q - sh * hc;
            float ts = clamp(dot(qs - a, ab) / ab2, 0., 1.);
            hc = mix(ha, hb, ts);
            qs = q - sh * hc;
            ts = clamp(dot(qs - a, ab) / ab2, 0., 1.);
            bare = min(bare, length(qs - a - ab * ts) - hw);
        }
        // decks shade the surfaces of the layers under them by how far
        // above those surfaces (where they are here) they stand
        for(int k = 0; k < MP_SEG_CELL; k++){
            if(k >= n) break;
            int o = seg + 9 * mpWord(st + k);
            int kind = mpWord(o + 6), l = clamp((kind >> 4 & 15), 0, MP_LAYERS - 1);
            if((kind & 15) != 0 || l <= MP_GROUND) continue;
            float ha = mpFx(o + 7) * 4., hb = mpFx(o + 8) * 4.;
            if(max(ha, hb) < 0.02) continue;
            vec2 a = vec2(mpFx(o), mpFx(o + 1)), b = vec2(mpFx(o + 2), mpFx(o + 3));
            float hw = mpFx(o + 4);
            vec2 ab = b - a;
            float ab2 = max(dot(ab, ab), 1e-12);
            for(int u = MP_GROUND; u < MP_LAYERS; u++){
                if(u >= l) break;
                float base = road[u] < 0.01 ? hgt[u] : float(u - MP_GROUND);
                vec2 qu = q;
                float dh = 0.;
                for(int it = 0; it < 2; it++){
                    float tu = clamp(dot(qu - a, ab) / ab2, 0., 1.);
                    dh = mix(ha, hb, tu) - base;
                    qu = q - sh * max(dh, 0.);
                }
                if(dh < MP_SHADE_MIN) continue;
                float tu = clamp(dot(qu - a, ab) / ab2, 0., 1.);
                sdw[u] = min(sdw[u], length(qu - a - ab * tu) - hw);
            }
        }
    }
    // ground, then each layer up: a layer's surface in the shadow of the
    // decks above it, bridge decks lighter with parapets, tunnels faint
    float topH = 0.;
    float green = 0., tshadow = 0.;
    vec2 crown = vec2(0.);
    water = max(water, S(river));
    if(c.x >= 0 && c.y >= 0 && c.x < nx && c.y < ny){
        float grey = col.r;
        green = mpGreen(q, gMpBase + mpWord(gMpBase + 31) + 2 * (c.y * nx + c.x), grey, water, crown, tshadow);
        col = vec3(grey);
    }
    green *= 1. - water;
    // on a map with a treeline and snowline (header 21 bit 2, the two after
    // its terrain) no green or trees above the one and snow above the other,
    // their edges ragged by MP_LINE_RAG metres
    float snow = 0.;
    if((mpWord(gMpBase + 21) & 4) != 0){
        int tl = gMpBase + mpWord(gMpBase + 43) + (nx + 1) * (ny + 1);
        float h = mpTerrain(q) + (bgNoise(q / (MP_LINE_RAG * gMpU)).r - 0.5) * MP_LINE_RAG * gMpU;
        float above = smoothstep(-MP_LINE_BAND, MP_LINE_BAND, (h - mpFx(tl)) / gMpU);
        snow = smoothstep(-MP_LINE_BAND, MP_LINE_BAND, (h - mpFx(tl + 1)) / gMpU);
        green *= 1. - above;
        crown.x *= 1. - above;
        tshadow *= 1. - above;
    }
    col = mix(col, vec3(0.04), S(path - 0.0006) * 0.6);
    col = mix(col, vec3(MP_PATH_GREY), S(path));
    green *= 1. - S(path - 0.0014);
    water *= 1. - S(path - 0.0014);
    // walls: a pale stone ridge with a lit rim, its shadow cast like a deck's
    col *= 1. - 0.45 * S(wallShade) * (1. - S(wall));
    col = mix(col, vec3(MP_WALL_GREY), S(wall));
    col = mix(col, vec3(MP_WALL_GREY + 0.045), S(abs(wall + 0.0005) - 0.0003) * S(wall + 0.0002));
    green *= 1. - S(wall - 0.0006);
    water *= 1. - S(wall - 0.0006);
    col *= 1. - tshadow;
    col = mix(col, vec3(crown.y), crown.x);
    green = max(green, crown.x);
    col = mix(col, vec3(MP_SNOW_GREY), snow);
    green *= 1. - snow;
    col *= 1. - 0.5 * smoothstep(0.004, -0.002, bare);
    if(c.x >= 0 && c.y >= 0 && c.x < nx && c.y < ny && mpWord(gMpBase + 33) > 0){
        parked = mpParked(q, gMpBase + mpWord(gMpBase + 35) + 2 * (c.y * nx + c.x), col, pshade);
        green *= 1. - parked;
        water *= 1. - parked;
    }
    for(int l = 0; l < MP_LAYERS; l++){
        if(road[l] > 0.01) continue;
        float cov = S(road[l]);
        float lift = hgt[l], dk = smoothstep(0.08, 0.6, lift);
        // where a deck runs on into road of about its height on any other
        // layer (the ramp it joins, the deck it splits from), its end and
        // edges are not drawn: one surface
        float edge = 1.;
        for(int m = MP_GROUND; m < MP_LAYERS; m++)
            if(m != l) edge = min(edge, 1. - S(road[m] + 0.002) * (1. - smoothstep(0.15, 0.45, abs(hgt[m] - lift))));
        vec3 rc = vec3(0.075 + 0.018 * lift) * (1. - 0.5 * smoothstep(0.004, -0.002, sdw[l]));
        float a = l < MP_GROUND ? 0.3 : 1.;
        col = mix(col, vec3(0.16 + (0.04 + 0.02 * lift) * dk), S(road[l] - mix(0.0012, 0.0016, dk)) * a * edge);
        col = mix(col, rc, cov * a);
        float under = S(road[l] - mix(0.0012, 0.0016, dk)) * a;
        green *= 1. - under;
        water *= 1. - under;
        parked *= 1. - under * dk;
        col = mix(col, vec3(0.28 + 0.03 * lift), S(abs(road[l] + 0.0006) - 0.0005) * a * dk * edge);
        col = mix(col, vec3(0.3), S(line[l] - 0.0006) * cov * a * MP_LINE);
        if(cov > 0.5 && l >= MP_GROUND) topH = lift;
    }
    col = mix(col, vec3(0.04), S(pathHi - 0.0008) * 0.6);
    col = mix(col, vec3(MP_PATH_GREY + 0.04), S(pathHi));
    green *= 1. - S(pathHi - 0.0016);
    water *= 1. - S(pathHi - 0.0016);

    col = max(col + vec3(MP_HILL_LIGHT * (mpHill(q) - 1.)), vec3(0.));

    vec4 bld = vec4(0.);
    if(c.x >= 0 && c.y >= 0 && c.x < nx && c.y < ny && mpWord(gMpBase + 23) > 0){
        float shade;
        bld = mpBuildings(q, gMpBase + mpWord(gMpBase + 26) + 2 * (c.y * nx + c.x), shade);
        col *= 1. - 0.45 * shade;
    }

    return vec4(col.r + 2. * floor(green * 15. + 0.5) + 32. * floor(water * 15. + 0.5) + 512. * floor(parked * 15. + 0.5),
                topH / 4. + 4. * floor(pshade * 15. + 0.5) + 256. * floor(lift * MP_LIFT_Q + 0.5), bld.r + 2. * step(0.5, bld.g), bld.a);
}

// traffic light heads at q: a dark housing with the lit lamp glowing red,
// amber or green; hidden, like cars, under a surface well above them
// (topH)
vec3 mpHeads(vec2 q, vec3 col, float topH){
    int nx = mpWord(gMpBase + 12), ny = mpWord(gMpBase + 13);
    ivec2 c = ivec2(floor((q - vec2(mpFx(gMpBase + 14), mpFx(gMpBase + 15))) / mpFx(gMpBase + 16)));
    if(c.x < 0 || c.y < 0 || c.x >= nx || c.y >= ny || mpWord(gMpBase + 37) == 0) return col;
    int ci = gMpBase + mpWord(gMpBase + 39) + 2 * (c.y * nx + c.x);
    int n = mpWord(ci + 1), st = gMpBase + mpWord(gMpBase + 40) + mpWord(ci), tb = gMpBase + mpWord(gMpBase + 38);
    float r = max(0.8 * gMpU, 0.0016);
    for(int k = 0; k < MP_SIG_CELL; k++){
        if(k >= n) break;
        int o = tb + 4 * mpWord(st + k);
        float d = length(q - vec2(mpFx(o), mpFx(o + 1)));
        if(d > r * 6. || topH > mpFx(o + 3) * 4. + 0.5) continue;
        int s = mpLight(mpWord(o + 2));
        vec3 lamp = s == 0 ? vec3(0.2, 1., 0.45) : s == 1 ? vec3(1., 0.7, 0.1) : vec3(1., 0.12, 0.08);
        col = mix(col, vec3(0.02), S(d - r * 1.3));
        col = mix(col, lamp, S(d - r * 0.8));
        col += lamp * 0.25 * exp(-d / (r * 1.5));
    }
    return col;
}

// with a dev car count set, a bar along the top: of the cars on the map,
// those stopped over MP_JAMMED (white: jammed, longer than any light),
// stopped (red), moving (green), and waiting off it (blue)
// every car on a small map of the screen and around it (the preview's
// minimap button): green moving, red stopped, magenta jammed
vec3 mpMinimap(vec2 q, vec3 col){
    vec2 mc = vec2(0.5 * u_aspect - 0.12, 0.36), mq = (q - mc) / 0.1 * 1.4;
    if(abs(mq.x) < 1.4 && abs(mq.y) < 1.4){
        vec3 c = vec3(0.05);
        if(abs(abs(mq.x) - 0.5 * u_aspect) < 0.006 && abs(mq.y) < 0.5 || abs(abs(mq.y) - 0.5) < 0.006 && abs(mq.x) < 0.5 * u_aspect) c = vec3(0.5);
        for(int i = 0; i < MP_N; i++){
            if(i >= gMpCars) break;
            vec4 a1 = agGet(iChannel19, i, 1);
            if(a1.x < -0.5) continue;
            vec4 a0 = agGet(iChannel19, i, 0);
            if(length(a0.xy - mq) < 0.02) c = mpWait(a1.w) > MP_JAMMED ? vec3(1., 0., 1.) : a0.z < MP_CRAWL * gMpU ? vec3(1., 0.2, 0.1) : vec3(0.2, 1., 0.3);
        }
        return c;
    }
    return col;
}

vec3 mpMeter(vec2 q, vec3 col){
    if(q.y >= 0.43 && q.y < 0.46 && q.x >= -0.44 && q.x <= 0.){
        float on = 0., off = 0.;
        for(int i = 0; i < MP_N; i++){
            if(i >= gMpCars) break;
            vec4 a0 = agGet(iChannel19, i, 0), a1 = agGet(iChannel19, i, 1);
            if(a1.x < -0.5) continue;
            if(abs(a0.x) > 0.5 * u_aspect || abs(a0.y) > 0.5) off += 1.; else on += 1.;
        }
        float x = (q.x + 0.44) / 0.44 * float(gMpCars);
        return x < on ? vec3(0., 1., 0.) : x < on + off ? vec3(1., 0., 0.) : vec3(0., 0., 1.);
    }
    if(q.y < 0.47 || q.x < -0.44 || q.x > 0.) return col;
    float stk = 0., stp = 0., mov = 0., away = 0.;
    for(int i = 0; i < MP_N; i++){
        if(i >= gMpCars) break;
        vec4 a0 = agGet(iChannel19, i, 0), a1 = agGet(iChannel19, i, 1);
        if(a1.x < -0.5) away += 1.;
        else if(mpWait(a1.w) > MP_JAMMED) stk += 1.;
        else if(a0.z < MP_CRAWL * gMpU) stp += 1.;
        else mov += 1.;
    }
    float x = (q.x + 0.44) / 0.44 * float(gMpCars);
    return x < stk ? vec3(1.) : x < stk + stp ? vec3(1., 0., 0.) : x < stk + stp + mov ? vec3(0., 1., 0.) : vec3(0., 0., 1.);
}

// the map's name in the bottom left corner (gen_maps labels: a strip of
// LABEL_W x LABEL_H per map in iChannel22), MP_LABEL tall a strip, over a
// soft shadow
vec3 mpLabel(vec2 q, vec3 col){
    vec2 ts = vec2(textureSize(iChannel22, 0));
    float rows = floor(ts.y / MP_LABEL_PX + 0.5), w = ts.x / MP_LABEL_PX;
    vec2 uv = (q - vec2(-0.5 * iResolution.x / iResolution.y + MP_LABEL_PAD, -0.5 + MP_LABEL_PAD)) / MP_LABEL;
    if(rows < 1. || uv.x < 0. || uv.y < 0. || uv.x > w || uv.y > 1.) return col;
    float d = (texture(iChannel22, vec2(uv.x / w, (float(gMpIdx) + 1. - clamp(uv.y, 0.02, 0.98)) / rows)).r - 0.5) * MP_LABEL_RANGE * MP_LABEL;
    col *= 1. - 0.6 * smoothstep(MP_LABEL * 0.08, 0., d);
    return mix(col, vec3(0.88), S(d));
}

// the lane graph over the map (the preview's lanes button): each lane's
// centre line dim, connectors through junctions green, orange where they
// give way, blue on a ring, over each junction's area tinted; a road with
// stopped cars washed amber, red where it is backed up to its start
vec3 mpLanes(sampler2D ch, vec2 q, vec3 col){
    int nx = mpWord(gMpBase + 12), ny = mpWord(gMpBase + 13);
    ivec2 c = ivec2(floor((q - vec2(mpFx(gMpBase + 14), mpFx(gMpBase + 15))) / mpFx(gMpBase + 16)));
    if(c.x < 0 || c.y < 0 || c.x >= nx || c.y >= ny) return col;
    int ci = gMpBase + mpWord(gMpBase + 10) + 2 * (c.y * nx + c.x);
    int st = gMpBase + mpWord(gMpBase + 11) + mpWord(ci), n = mpWord(ci + 1);
    int seg = gMpBase + mpWord(gMpBase + 8);
    float px = 0.6 / iResolution.y;
    bool area = false;
    vec4 jam = vec4(0.);
    for(int k = 0; k < MP_SEG_CELL; k++){
        if(k >= n) break;
        int o = seg + 9 * mpWord(st + k);
        int kind = mpWord(o + 6);
        vec2 a = vec2(mpFx(o), mpFx(o + 1)), b = vec2(mpFx(o + 2), mpFx(o + 3)), ab = b - a;
        if((kind & 15) == 6 && mpTri(q, a, b, vec2(mpFx(o + 4), mpFx(o + 5))) - MP_JUNCTION_PAD * gMpU < 0.) area = true;
        if((kind & 15) != 0) continue;
        float d = length(q - a - ab * clamp(dot(q - a, ab) / max(dot(ab, ab), 1e-12), 0., 1.));
        int eid = (kind >> 12) - 1;
        if(eid >= 0 && d < mpFx(o + 4)){ vec4 g = mpCong(ch, eid); if(g.x > jam.x || g.y > jam.y) jam = g; }
        bool conn = (kind >> 9 & 1) == 1;
        vec3 lc = !conn ? vec3(0.45) : (kind >> 11 & 1) == 1 ? vec3(0.3, 0.6, 1.) : (kind >> 10 & 1) == 1 ? vec3(1., 0.55, 0.1) : vec3(0.2, 1., 0.35);
        col = mix(col, lc, smoothstep(px, 0., d - (conn ? px : 0.)));
    }
    if(area) col = mix(col, vec3(1., 0.3, 0.8), 0.25);
    return jam.x > 0.5 ? mix(col, mix(vec3(1., 0.75, 0.1), vec3(1., 0.1, 0.1), jam.y), min(0.15 + 0.06 * jam.x, 0.55)) : col;
}

vec3 mpRender(vec2 q, vec2 tp){
    mpLoad();
    float asp = iResolution.x / iResolution.y;
    vec4 st = texture(iChannel21, roomUV(q));
    float lq = floor(st.g / 256.);
    st.g -= 256. * lq;
    vec2 qs = q;
    q.y -= lq / MP_LIFT_Q;
    float ck = floor(st.r / 512.), rr = st.r - 512. * ck;
    float wk = floor(rr / 32.), gk = floor((rr - 32. * wk) / 2.), grey = rr - 32. * wk - 2. * gk;
    vec3 col = mix(vec3(grey), grey * MP_GREEN_TINT, gk / 15.);
    col = mix(col, grey * MP_WATER_TINT, wk / 15.);
    float sk = floor(st.g / 4.);
    col = mix(col, mix(GRAD_BOT, GRAD_TOP, sk / 15.), ck / 15.);
    float topH = (st.g - 4. * sk) * 4.;
    float sz = max(gMpCar * MP_CAR_DRAW, 0.008);
    vec4 sl[AG_TEX];
    agSlots(iChannel19, q, asp, sl);
    for(int k = 0; k < AG_SLOTS; k++){
        int i = int(sl[k >> 2][k & 3] + 0.5) - 1;
        if(i < 0) break;
        vec4 s = agGet(iChannel19, i, 0);
        float lift = mpHeight(s.w), hd = mpHeading(s.w);
        if(topH > lift + 0.5) continue;
        float csz = sz * (1. + 0.08 * lift);
        vec2 p = s.xy, f = vec2(cos(hd), sin(hd));
        float near = csz * 1.8;
        if(dot(q - p, q - p) > near * near) continue;
        vec2 d = q - p;
        float ahead = dot(d, f), side = dot(d, vec2(-f.y, f.x));
        float beam = smoothstep(csz * 1.6, 0., ahead) * step(csz * 0.3, ahead) * smoothstep(csz * 0.2 + ahead * 0.35, 0., abs(side));
        col += vec3(1., 0.92, 0.7) * 0.18 * beam;
        float brake = s.z < 2. * gMpU ? 1. : 0.35;
        col += vec3(1., 0.1, 0.05) * brake * 0.5 * exp(-length(d + f * csz * 0.45) / (csz * 0.18));
        vec3 body = mix(GRAD_BOT, GRAD_TOP, random(vec2(i, 8.8)));
        vec4 dbg = (u_traffic_debug & 8) != 0 ? agGet(iChannel19, i, 1) : vec4(0.);
        if((u_traffic_debug & 8) != 0 && mpWait(dbg.w) > MP_JAMMED) body = (mpE(int(dbg.x + 0.5), 7) & 1) == 1 ? vec3(1., 0., 1.) : vec3(1., 1., 0.);
        col = mix(col, body, S(agAmp(q, p, f, csz)));
    }
    col = mpHeads(q, col, topH);
    bool lit = st.b > 1.;
    vec3 ov = vec3(st.b - (lit ? 2. : 0.)) + (lit ? vec3(1., 0.8, 0.5) * 0.35 : vec3(0.));
    if((u_traffic_debug & 1) != 0) col = mpLanes(iChannel19, q, col);
    col = mpLabel(qs, mix(col, ov, st.a));
    if((u_traffic_debug & 4) != 0) col = mpMeter(qs, col);
    if((u_traffic_debug & 2) != 0) col = mpMinimap(qs, col);
    return col;
}
// --- traffic: amp cars on real road networks ----------------------------------
// The scene is one of the maps (96_map.glsl), u_traffic_map picking which.
// the bins are rescanned a slice of rows a frame
const int   MP_BIN_SLICES = 8;

vec3 traffic(vec2 q, vec2 tp){ return mpRender(q, tp); }
// --- conveyor: a rube goldberg amp factory cut into a slab ---------------------
// bufferConveyor runs CV_N items through tunnels cut into one grey slab. The
// amp is cast in three pieces (J, the P bowl and the P's detached tail "."),
// each on its own line: poured four at a time from lava veins in the slab,
// cooled in a wind tunnel, knocked out of its mould by a drop hammer. A floor
// arm welds the "." onto the J, a ceiling arm then the P. The amp drops down
// the right edge into a water basin, rides a conveyor and a bucket elevator up
// to the heater, spirals down to four airbrush passes, tumbles down to
// quality control (stamp, scale, scanner; rejects melt), slides down to be
// boxed, taped and labelled, and falls off screen through a chute. Item rows:
// row 0 pos.xy, spin; row 1 track, arc length, timer, mask (bit k station k,
// and row 0 w the piece plus 4 if rejected). Row CV_ROW holds the stations
// (progress, holder, since done, extra), the jam, the sorter, the sim clock
// and the splash.
const int   CV_N       = 400;
const int   CV_NFRAME  = 56;
const float CV_K       = 0.8;
const float CV_M       = 0.78 * CV_K;
const float CV_DSIZE   = 0.04;
const float CV_SIZE    = CV_DSIZE * CV_M;
const float CV_GAP     = 0.047 * CV_M;
const float CV_BELT_V  = 0.09;
const float CV_RAMP_V  = 0.2;
const float CV_PAINT_V = 0.06;
const float CV_LIFT_V  = 0.11;
const float CV_WATER_V = 0.07;
const float CV_REJECT  = 0.14;
const float CV_JAM_LEN = 6.5;
const float CV_FIX_AT  = 4.2;
const float CV_WARM    = 0.;
const float CV_WARP    = 6.;
const float CV_HIT     = 0.3;
const int   CV_ROW     = AG_FIELD0;

// the layout is a grid of CV_CELL squares, one mould slot each: cell (i, j)
// spans [i, i + 1] x [j, j + 1] cells. Things sit centred in a cell (CVX),
// a row's tunnel is two cells tall from floor line j (CVR is where a piece
// standing on its belt is centred), rooms have their walls on grid lines
const float CV_CELL    = CV_GAP;
const float CV_ROWOFF  = 0.0165;
#define CVX(i) (((i) + 0.5) * CV_CELL)
#define CVR(j) ((j) * CV_CELL + CV_ROWOFF)
#define CVG(j) ((j) * CV_CELL)

const float CV_HALF_W  = 1.07;
const float CV_HALF_H  = 0.5;
const float CV_CX      = -0.05;
const float CV_CY      = 0.06;
const float CV_TANK_Y  = CVG(-12.);
const float CV_PLK1    = CVG(24.);
const float CV_DIVE    = CVR(15.) - CVG(-12.);
const float CV_TOPY    = CVR(15.);
const vec2  CV_HUB     = vec2(CVG(24.5), CVG(-6.));
const float CV_HUBR    = CVG(2.);
const float CV_SPIN_W  = 26.;
const float CV_GAL_V   = 0.18;
const float CV_DRUM_V  = 0.0088;
const vec2  CV_DRUM    = vec2(CVG(23.), CVG(10.));
const float CV_DRUMR   = CVG(3.);
const float CV_DRUM_W  = 1.0472;
const float CV_DRIP_V  = 0.03;
const float CV_FLAW    = 0.12;

const int CT_FREE = -1, CT_P = 0, CT_J = 1, CT_DROP = 2, CT_MAIN = 3, CT_REJ = 4, CT_SLIDE = 5, CT_PACK = 6, CT_D = 7, CT_FIN = 8, CT_FRAME = 9, CT_ARM1 = 10, CT_ARM2 = 11;
const int CV_NT = 10;
const int CV_KFRAME = 3;
const int CV_MAXP = 22;
const int CS_WELD1 = 6, CS_WELD2 = 7, CS_PRIME = 8, CS_CLEAR = 11, CS_STAMP = 12, CS_WEIGH = 13, CS_SCAN = 14, CS_BOX = 15, CS_TAPE = 16, CS_LABEL = 17;
const int CS_PRESS = 18, CS_CAUSTIC = 21, CS_SQUEEZE = 22, CS_STRETCH = 23, CS_GRIND = 24, CS_XRAY = 25, CS_BOOT = 26, CS_FLICK = 27, CS_POLISH = 28, CS_HAT = 29, CS_CLASS = 30;
const int CV_NS = 31;
const int CX_JAM = 31, CX_SORT = 32, CX_CLOCK = 33, CX_SPLASH = 34, CX_PUSH = 35, CX_FEED = 38, CX_QK = 41, CX_HATFLY = 46;
const int   CV_QC_K[5] = int[](CS_STAMP, CS_SQUEEZE, CS_WEIGH, CS_STRETCH, CS_SCAN);
const float CV_QREJ[5] = float[](0.03, 0.04, 0.04, 0.04, 0.05);

const vec2 CV_PTS[58] = vec2[](
    vec2(CVX(-35.), CVR(12.)), vec2(CVX(2.), CVR(12.)),
    vec2(CVX(-35.), CVR(15.)), vec2(CVX(28.2), CVR(15.)),
    vec2(CVX(28.2), CVR(15.)), vec2(CVX(28.2), CVR(-15.)),
    vec2(CVX(32.), CVR(-15.)), vec2(CVX(4.), CVR(-15.)), vec2(CVX(2.), CVR(-12.)), vec2(CVX(3.), CVR(-10.)), vec2(CVX(9.), CVR(-10.)), vec2(CVX(9.), CVR(-7.)), vec2(CVX(4.), CVR(-7.)), vec2(CVX(4.), CVR(-4.)),
    vec2(CVX(18.), CVR(-4.)), vec2(CVX(26.), CVG(-6.)), vec2(CVX(26.), CVR(9.)), vec2(CVX(9.), CVR(9.)),
    vec2(CVX(9.), CVR(7.)), vec2(CVX(19.), CVR(7.)),
    vec2(CVX(-29.), CVR(3.)), vec2(CVX(-29.), CVR(3.)), vec2(CVX(-29.), CVR(3.)),
    vec2(CVX(-29.), CVR(3.)), vec2(CVX(-29.), CVR(-1.)),
    vec2(CVX(-29.), CVR(-1.)), vec2(CVG(-21.08), CVR(-1.)), vec2(CVX(-11.), CVR(-4.)), vec2(CVX(-8.), CVR(-4.)), vec2(CVX(-8.), CVR(-15.)), vec2(CVG(-9.4), CVR(-15.)), vec2(CVG(-10.1), CVR(-14.4)), vec2(CVG(-11.9), CVR(-14.4)), vec2(CVG(-12.6), CVR(-15.)), vec2(CVX(-17.), CVR(-15.)), vec2(CVX(-19.), CVR(-11.)),
    vec2(CVX(-28.), CVR(-11.)), vec2(CVX(-28.5), CVR(-12.)), vec2(CVX(-28.5), -1.3),
    vec2(CVX(-35.), CVR(9.)), vec2(CVX(-5.), CVR(9.)), vec2(CVX(-5.), CVR(9.)), vec2(CVX(-5.), CVR(9.)),
    vec2(CVX(19.), CVR(7.)), vec2(CVG(20.42), CVG(7.17)), vec2(CVG(22.42), CVG(1.17)), vec2(CVX(22.), CVR(-1.)), vec2(CVG(0.), CVR(-1.)), vec2(CVG(0.), CVR(-15.)),
    vec2(CVG(-5.), CVR(-15.)), vec2(CVG(-5.), CVR(3.)), vec2(CVX(-29.), CVR(3.)),
    vec2(CVX(-10.), CVR(15.)), vec2(CVX(-10.), CVR(6.)), vec2(CVX(-37.), CVR(6.)), vec2(CVX(-37.), CVR(-13.6)), vec2(CVX(-35.), CVR(-13.6)), vec2(CVX(-35.), CVR(15.))
);
const int CV_T0[10] = int[](0, 2, 4, 6, 20, 23, 25, 39, 43, 52);
const int CV_TN[10] = int[](2, 2, 2, 14, 3, 2, 14, 2, 9, 6);

const int   CV_ST_T[31]  = int[](0, 1, 7, 0, 1, 7, 1, 1, 3, 8, 8, 8, 8, 8, 8, 6, 6, 6, 0, 1, 7, 3, 8, 8, 1, 1, 1, 3, 8, 6, 6);
const float CV_ST_X[31]  = float[](CVX(-24.), CVX(-24.), CVX(-24.), CVX(-10.), CVX(-10.), CVX(-10.), CVX(-1.), CVX(5.),
    CVG(18.), CVG(18.), CVG(13.), CVG(8.), CVG(-5.), CVG(-5.), CVG(-5.), CVX(-19.), CVX(-24.), CVX(-27.),
    CVX(-33.), CVX(-33.), CVX(-33.), CVX(18.), CVG(-5.), CVG(-5.), CVX(9.), CVX(12.), CVX(15.), CVG(18.), CVG(2.), CVG(-11.), CVX(-11.));
const float CV_ST_Y[31]  = float[](CVR(12.), CVR(15.), CVR(9.), CVR(12.), CVR(15.), CVR(9.), CVR(15.), CVR(15.),
    CVR(9.), CVR(-1.), CVR(-1.), CVR(-1.), CVR(-11.5), CVR(-5.), CVR(1.5), CVR(-11.), CVR(-11.), CVR(-11.),
    CVR(12.), CVR(15.), CVR(9.), CVR(-4.), CVR(-8.25), CVR(-1.75), CVR(15.), CVR(15.), CVR(15.), CVR(9.), CVR(-1.), CVR(-14.4), CVR(-4.));
const int   CV_BATCH[3]  = int[](8, 8, 1);
const int   CV_FILLN     = 1;
const float CV_ST_DW[31] = float[](3.5, 3.5, 1., 1., 1., 1., 1.25, 1.25, 1.1, 1.5, 1.5, 1.75, 0.5, 0.75, 0.75, 0.5, 0.5, 0.5, 0.75, 0.75, 0.75, 10.4, 1., 1., 1., 0.75, 0.5, 1.5, 1.25, 1., 9.);
const float CV_TAKT = 2.;
const float CV_BEAT = 0.25;
const float CV_WAITCAP[3] = float[](5., 99., 4.);
// pieces, in glyph units: kind 0 J, 1 the P bowl, 2 the "." tail. A lone
// piece on its line is drawn at g = gp + CV_PO[kind] so it sits bottom-centred
// on the belt; every line casts in the same standard flask (CV_MCEN, CV_MHALF,
// in gp), only the pattern pressed into its sand differs; an arm
// grips it at CV_GRIP from its glyph origin
const vec2 CV_PO[3]    = vec2[](vec2(0.), vec2(-0.0185, 0.284), vec2(0.294, 0.02));
const vec2 CV_MCEN[3]  = vec2[](vec2(0., -0.02), vec2(0., -0.02), vec2(0., -0.02));
const vec2 CV_MHALF[3] = vec2[](vec2(0.42, 0.56), vec2(0.42, 0.56), vec2(0.42, 0.56));
const vec2 CV_GRIP[3]  = vec2[](vec2(0., 0.55), vec2(-0.02, 0.53), vec2(0.294, -0.27));
const float CV_PSPLIT  = -0.26;

// the weld room (cells -7..7 x 8..17) and its two arms: 0 sets the "." on
// the J (floor mounted), 1 the P (ceiling mounted)
const vec4  CV_WELDROOM = vec4(-7., 6., 7., 17.);
const vec2  CV_PICK[2] = vec2[](vec2(CVX(-5.), CVR(9.)), vec2(CVX(2.), CVR(12.)));
const vec2  CV_JOIN[2] = vec2[](vec2(CVX(-1.), CVR(15.)), vec2(CVX(5.), CVR(15.)));
const vec2  CV_ARMB[2] = vec2[](vec2(CVX(-3.), CVG(8.)), vec2(CVX(4.), CVG(17.)));
const float CV_ARML[2] = float[](0.115, 0.075);
const int   CV_ARMK[2] = int[](2, 1);
const vec2  CV_SEAM[2] = vec2[](vec2(0.22, -0.33), vec2(0.05, -0.05));

#define CVZ min(iFrame, 0)

// the mask bit of station k: masks are floats, exact to 2^24, so the stations
// past 23 reuse foundry bits of the lines a finished amp never ran on
int cvBit(int k){ return k < 24 ? k : k == CS_GRIND ? 0 : k == CS_XRAY ? 2 : k == CS_BOOT ? 3 : k == CS_FLICK ? 5 : k == CS_POLISH ? 18 : k == CS_HAT ? 4 : 1; }

int cvI(float x){ return int(round(x)); }

float cvLen(int t){
    t = clamp(t, 0, CV_NT - 1);
    float l = 0.;
    for(int k = 1; k < CV_MAXP + CVZ; k++){
        if(k >= CV_TN[t]) break;
        l += length(CV_PTS[CV_T0[t] + k] - CV_PTS[CV_T0[t] + k - 1]);
    }
    return l;
}

vec2 cvAt(int t, float s){
    t = clamp(t, 0, CV_NT - 1);
    vec2 p = CV_PTS[CV_T0[t]];
    for(int k = 1; k < CV_MAXP + CVZ; k++){
        if(k >= CV_TN[t]) break;
        vec2 b = CV_PTS[CV_T0[t] + k];
        float l = length(b - p);
        if(s <= l || k == CV_TN[t] - 1) return p + (b - p) * clamp(s / max(l, 1e-6), 0., 1.);
        s -= l;
        p = b;
    }
    return p;
}

vec2 cvDirAt(int t, float s){
    t = clamp(t, 0, CV_NT - 1);
    vec2 p = CV_PTS[CV_T0[t]];
    for(int k = 1; k < CV_MAXP + CVZ; k++){
        if(k >= CV_TN[t]) break;
        vec2 b = CV_PTS[CV_T0[t] + k];
        float l = length(b - p);
        if(l > 1e-6 && (s <= l || k == CV_TN[t] - 1)) return (b - p) / l;
        s -= l;
        p = b;
    }
    return vec2(1., 0.);
}

// arc length of the point of track t nearest q
float cvSAtP(int t, vec2 q){
    t = clamp(t, 0, CV_NT - 1);
    float best = 1e9, sb = 0., acc = 0.;
    for(int k = 1; k < CV_MAXP + CVZ; k++){
        if(k >= CV_TN[t]) break;
        vec2 a = CV_PTS[CV_T0[t] + k - 1], b = CV_PTS[CV_T0[t] + k];
        float l = length(b - a);
        float h = clamp(dot(q - a, b - a) / max(l * l, 1e-6), 0., 1.);
        float d = length(q - a - (b - a) * h);
        if(d < best){ best = d; sb = acc + h * l; }
        acc += l;
    }
    return sb;
}

vec2 cvStPos(int k){ return vec2(CV_ST_X[k], CV_ST_Y[k]); }

float cvSAtSt(int k){ return cvSAtP(CV_ST_T[k], cvStPos(k)); }
float cvPackEnd(){ return cvSAtP(CT_PACK, vec2(CVX(-28.), CVR(-11.))); }
float cvBounceS(){ return cvSAtP(CT_PACK, vec2(CVX(-17.), CVR(-15.))); }

// the foundry line (0 P, 1 J, 2 ".") of a track or a piece, -1 if none
int cvLineOfTrack(int t){ return t == CT_P ? 0 : t == CT_J ? 1 : t == CT_D ? 2 : -1; }
int cvLineOfKind(int kind){ return kind == 0 ? 1 : kind == 1 ? 0 : 2; }

// how many moulds station k works on at once, 0 if it is not a batch station
int cvBatchN(int k){ return k < 3 ? CV_BATCH[k] : k == CS_CAUSTIC ? 8 : k == CS_CLASS ? 12 : 0; }

int cvBatchSlot(int k, float s){
    float b = (cvSAtSt(k) - s) / CV_GAP;
    float r = floor(b + 0.5);
    return abs(b - r) < 0.05 && r >= 0. && r < float(cvBatchN(k)) - 0.5 ? int(r) : -1;
}

// on the main run: drying on the heater belt, hanging from the rail over the
// caustic pit, flung up the shaft by the centrifuge, along the gallery over the
// paint hall and tumbling down the zigzag to the airbrush row
bool cvHeatAt(vec2 p){ return p.x > CVG(2.) && p.x < CVG(10.) && p.y > CVG(-10.) && p.y < CVG(-2.); }
bool cvLaunchAt(vec2 p){ return abs(p.x - CVX(26.)) < 0.001 && p.y > CV_HUB.y + 0.001 && p.y < CVR(9.) - 0.001; }
bool cvRailAt(vec2 p){ return abs(p.y - CVR(-4.)) < 0.001 && p.x > CVX(9.) + 0.0005 && p.x < CVX(18.) + 0.001; }
bool cvGalleryAt(vec2 p){ return abs(p.y - CVR(9.)) < 0.001 && p.x > CVX(9.) + 0.0005; }
bool cvDripAt(vec2 p){ return abs(p.y - CVR(7.)) < 0.001 && p.x > CVX(9.) - 0.0005 && p.x < CVX(19.) - 0.0005; }
bool cvMainZig(vec2 p){ return false; }

bool cvRampAt(vec2 p){ return p.y > CVG(1.17) + 0.001 && p.x > CVX(19.) + 0.0005 && p.x < CVG(22.42) - 0.0005; }

// the batch on the rail, T seconds into its cycle: 0..3 dipped in the pit,
// 3..4.2 swung onto the centrifuge, spun up, each amp let go as its arm
// points right so it flies straight up the shaft, then spun down
float cvSpin(float T){
    if(T < 4.2) return 0.;
    if(T < 5.4) return CV_SPIN_W * (T - 4.2) * (T - 4.2) / 2.4;
    if(T < 9.6) return CV_SPIN_W * (0.6 + T - 5.4);
    float x = min(T - 9.6, 0.8);
    return CV_SPIN_W * (4.8 + x - x * x / 1.6);
}
float cvSpinW(float T){ return T < 4.2 ? 0. : T < 5.4 ? CV_SPIN_W * (T - 4.2) / 1.2 : T < 9.6 ? CV_SPIN_W : CV_SPIN_W * max(1. - (T - 9.6) / 0.8, 0.); }
float cvRelTheta(int r){
    float a = float(r) * 0.785398;
    return 6.283185 * (ceil((cvSpin(5.6) + a) / 6.283185) + 2. * float(r)) - a;
}
float cvShaftS(){ return cvSAtP(CT_MAIN, vec2(CVX(26.), CV_HUB.y)); }

float cvSpeed(int t, float s, vec2 p){
    if(t == CT_DROP) return s < CV_PLK1 ? 0.14 : s < CV_DIVE ? min(0.25 + 3.2 * (s - CV_PLK1), 1.3) : CV_WATER_V;
    if(t == CT_MAIN){
        if(p.y < CV_TANK_Y - 0.01) return CV_WATER_V;
        if(cvRailAt(p)) return 0.6;
        if(cvHeatAt(p)) return CV_BELT_V * 0.5;
        if(cvLaunchAt(p)){
            float h = CVR(9.) - CV_HUB.y, g = 0.5 * CV_SPIN_W * CV_SPIN_W * CV_HUBR * CV_HUBR / h;
            return max(sqrt(max(2. * g * h + 0.0144 - 2. * g * (p.y - CV_HUB.y), 0.)), 0.12);
        }
        if(cvGalleryAt(p)) return p.x < CVG(24.) && p.x > CVG(18.) ? CV_DRUM_V : CV_GAL_V;
        if(cvDripAt(p)) return CV_DRIP_V;
        if(cvMainZig(p)) return CV_RAMP_V * 0.6;
        if(abs(p.y - CVR(3.)) < 0.001) return CV_BELT_V;
        return CV_BELT_V * 0.25;
    }
    if(t == CT_FIN){
        float sw = CVG(7.3248);
        if(cvRampAt(p)) return sqrt(0.0064 + 2.8 * s);
        if(abs(p.y - CVR(-1.)) < 0.001 && p.x > CVG(16.) && p.x < CVX(22.) + 0.001) return 0.2;
        if(p.x > CVX(21.)) return p.y > CVR(-1.) + 0.001 ? sqrt(0.004 + 3. * max(s - sw, 0.)) : CV_PAINT_V;
        if(abs(p.x - CVG(0.)) < 0.001 && p.y < CVR(-1.) - 0.001) return min(0.2 + 3. * (CVR(-1.) - p.y), 1.2);
        if(abs(p.x - CVG(-5.)) < 0.001 && p.y > CVR(-15.) + 0.001 && p.y < CVR(3.) - 0.001) return 0.12;
        return CV_PAINT_V;
    }
    if(t == CT_SLIDE) return min(0.2 + 3. * s, 1.);
    if(t == CT_REJ) return CV_LIFT_V;
    if(t == CT_PACK){
        float pe = cvPackEnd();
        if(abs(p.x - CVX(-8.)) < 0.001 && p.y < CVR(-4.) - 0.001 && p.y > CVR(-15.) + 0.001) return min(0.2 + 3. * (CVR(-4.) - p.y), 1.2);
        if(p.y < CVR(-14.) && p.x > CVX(-17.) + 0.001 && p.x < CVX(-8.)) return 0.12;
        float sb = cvBounceS();
        if(s > sb - 1e-4 && s < sb + CVG(4.4721)) return 0.3;
        if(abs(p.y - CVR(-11.)) < 0.001 && s < pe) return 0.12;
        return s > pe ? min(0.25 + 3. * (s - pe), 1.3) : CV_BELT_V * 0.25;
    }
    if(t == CT_FRAME) return p.y < CVR(-13.) && p.x > CVX(-37.) + 0.001 ? 0.05 : (abs(p.x - CVX(-10.)) < 0.001 && p.y > CVR(6.) + 0.001) || (abs(p.x - CVX(-37.)) < 0.001 && p.y < CVR(6.) - 0.001) ? 0.6 : 0.12;
    return CV_BELT_V;
}

// the plinko chute the welded amps fall down into the water: off the end of
// the top belt and down twenty staggered rows of brass pegs, each bounce
// left or right, the chute walls turning them back
const float CV_PLK_X = CVX(30.);
const float CV_PLK_H = CVG(1.2);
const float CV_PLK_W = CVG(0.6);
const int   CV_PLK_N = 20;
float cvPlkDir(int i, int k){ return random(vec2(float(i) * 1.37 + 0.5, float(k) * 7.1 + 3.3)) < 0.5 ? -1. : 1.; }
vec2 cvPlkPos(int i, float s, inout float ang){
    float off = -3. * CV_PLK_W, a = 0.;
    int kk = s < CV_PLK1 ? int(floor(s / CV_PLK_H)) : CV_PLK_N;
    float d = 0.;
    for(int k = 0; k < CV_PLK_N + CVZ; k++){
        d = cvPlkDir(i, k);
        if(abs(off + CV_PLK_W * d) > 3. * CV_PLK_W + 1e-4) d = -d;
        if(k >= kk) break;
        off += CV_PLK_W * d;
        a -= 1.3 * d;
    }
    if(s < CV_PLK1){
        float fr = s / CV_PLK_H - float(kk), hop = kk == 0 ? 0. : 0.5;
        ang = a - 1.3 * d * fr;
        return vec2(CV_PLK_X + off + CV_PLK_W * d * fr, CVR(15.) - CV_PLK_H * float(kk) + CV_PLK_H * (hop * fr - (1. + hop) * fr * fr));
    }
    return vec2(CV_PLK_X + off, cvAt(CT_DROP, s).y);
}

// an amp v of the way through the tumbler: carried up the rising wall by a
// lifter, dropped back to the bottom, again and again on its own beat
vec2 cvDrumLift(float ph, float rin, float tw){
    vec2 d = vec2(cos(ph), sin(ph));
    return CV_DRUM + (CV_DRUMR - CVG(0.5) - rin) * d + tw * vec2(-d.y, d.x);
}
vec2 cvDrumPos(int i, float v, float tt, inout float ang){
    vec4 hr = vec4(random(vec2(float(i) * 3.1, 1.7)), random(vec2(float(i) * 1.9, 4.3)), random(vec2(float(i) * 2.7, 8.1)), random(vec2(float(i) * 5.3, 2.9)));
    float h = fract(0.5 + floor(hr.x * 3.) / 3.);
    float rin = CVG(0.9) * hr.y, tw = CVG(0.4 + 0.35 * hr.z), rel = 0.05 + 0.7 * hr.w;
    float f = fract(tt * CV_DRUM_W / 3.14159 + h), fr = (rel + 1.5708) / 3.14159, a;
    vec2 p;
    if(f < fr){
        float ph = -1.5708 + 3.14159 * f;
        p = cvDrumLift(ph, rin, tw);
        a = ph + 1.5708 + 0.3 * (hr.z - 0.5);
    } else {
        float tc = 3.14159 / CV_DRUM_W, tau = (f - fr) * tc, rest = (1. - fr) * tc, gr = 1.2;
        vec2 p1 = cvDrumLift(rel, rin, tw), p0 = cvDrumLift(-1.5708, rin, tw);
        vec2 v0 = CV_DRUM_W * (CV_DRUMR - CVG(0.5) - rin) * vec2(-sin(rel), cos(rel));
        float tl = min((v0.y + sqrt(v0.y * v0.y + 2. * gr * max(p1.y - p0.y, 0.))) / gr, rest * 0.8);
        float tf = min(tau, tl);
        p = p1 + v0 * tf - vec2(0., 0.5 * gr * tf * tf);
        a = rel + 1.5708 + (8. + 12. * hr.w) * tf;
        if(tau > tl){
            float u = smoothstep(0., 1., (tau - tl) / max(rest - tl, 1e-3));
            float tilt = 0.3 * (hr.z - 0.5);
            p = mix(p, p0, u);
            a = mix(a, tilt + 6.28318 * floor((a - tilt) / 6.28318 + 0.5), u);
        }
    }
    float e0 = smoothstep(0., 0.12, v);
    ang = a * e0;
    return mix(CV_DRUM + vec2(CV_DRUMR - CVG(0.55), 0.), p, e0);
}

// the flick arm over the drum's left edge: reaches in for an amp that has
// tumbled its time, lifts it clear and flings it out onto the exit belt
const vec2 CV_FLK_P = vec2(CVG(19.), CVG(14.) - 0.002);
const vec2 CV_FLK_H = vec2(CVG(22.), CVG(11.));
vec2 cvFlickPos(int i, float x, float tt, inout float ang){
    if(x < 0.3) return cvDrumPos(i, 0.99, tt, ang);
    float a0 = 0.;
    vec2 g = cvDrumPos(i, 0.99, tt - (x - 0.3) * CV_ST_DW[CS_FLICK], a0);
    if(x < 0.55){
        float u = smoothstep(0.3, 0.55, x);
        ang = mix(mod(a0 + 3.14159, 6.28318) - 3.14159, 0., u);
        return mix(g, CV_FLK_H, u);
    }
    float u = (x - 0.55) / 0.45;
    vec2 w = vec2(CVG(8.) + CV_SIZE * 0.42, CVG(10.5));
    if(u < 0.62){
        float a = u / 0.62;
        ang = 9. * a;
        return mix(CV_FLK_H, w, a) + vec2(0., CVG(2.) * a * (1. - a));
    }
    float b = (u - 0.62) / 0.38;
    ang = mix(9., 12.566, smoothstep(0., 1., b));
    return vec2(mix(w.x, CVX(9.), b), mix(w.y, CVR(7.), b * b));
}

const float CV_HOLD[3] = float[](0.6, 0.72, 0.55);
const vec2  CV_PA = vec2(CVG(18.), CVR(-1.));
const vec2  CV_PB = vec2(CVG(13.), CVR(2.));
const vec2  CV_PC = vec2(CVG(8.), CVR(-1.));
const float CV_CATL = CVG(1.6);
const vec2  CV_CATH = vec2(CVG(16.4), CVG(-1.));
const vec2  CV_TABLE = vec2(CVG(13.), CVG(2.));
const float CV_TABLEW = CVG(1.7);
const float CV_GOOP_FIRE = 0.58;
const float CV_GOOP_HIT = 0.6;
const vec2  CV_GUN_T = vec2(CVG(10.2), CVG(0.2));
const float CV_GUN_A = 0.32;
const float CV_GUN_LM = CVG(1.05);
const float CV_GUN_LB = CVG(0.5);

float cvPaintHold(int k){ return k > CS_PRIME && k <= CS_CLEAR ? CV_HOLD[k - CS_PRIME - 1] : -1.; }

float cvCoatP(int k, float x){
    if(k == CS_PRIME + 1) return clamp((x - 0.08) / 0.42, 0., 1.);
    if(k == CS_PRIME + 2) return clamp((x - 0.1) / 0.55, 0., 1.);
    if(k == CS_PRIME + 3) return clamp((x - CV_GOOP_HIT) / 0.05, 0., 1.);
    return x;
}

float cvCatAng(float x){
    float u = clamp((x - CV_HOLD[0]) / 0.05, 0., 1.);
    return 1.75 * (1. - (1. - u) * (1. - u) * (1. - u)) * (1. - smoothstep(0.78, 1., x));
}
vec2 cvCatCup(float th){ return CV_CATH + CV_CATL * vec2(cos(th), sin(th)); }
vec2 cvOnCup(float th){ return cvCatCup(th) + vec2(-sin(th), cos(th)) * (CV_SIZE * 0.5 + 0.003); }

float cvTilt(float x){ return 0.26 * smoothstep(CV_HOLD[1], CV_HOLD[1] + 0.07, x) * (1. - smoothstep(0.86, 1., x)); }
vec2 cvOnTable(float lx, float tl){ return CV_TABLE + Rot(-tl) * vec2(lx, CVR(2.) - CVG(2.)); }

float cvGunRecoil(float x){
    if(x < CV_GOOP_FIRE) return 0.;
    return CVG(0.45) * (1. - exp(-(x - CV_GOOP_FIRE) * CV_ST_DW[CS_CLEAR] * 150.)) * (1. - smoothstep(CV_GOOP_FIRE + 0.08, 0.97, x));
}
vec2 cvGunU(){ return vec2(cos(CV_GUN_A), sin(CV_GUN_A)); }
vec2 cvGunMuzzle(float x){ return CV_GUN_T - cvGunU() * (CV_GUN_LM - cvGunRecoil(x)); }
vec2 cvGoopImpact(){ return CV_PC + vec2(CV_SIZE * 0.4, CVG(0.12)); }

vec2 cvPaintPos(int k, float x, inout float ang){
    if(k == CS_PRIME + 1){
        float h = CV_HOLD[0], x0 = h + 0.03;
        if(x < h){ ang = 0.; return CV_PA; }
        if(x < x0){ float th = cvCatAng(x); ang = th; return cvOnCup(th); }
        float th0 = cvCatAng(x0), u = (x - x0) / (1. - x0);
        ang = mix(th0, 6.28318, u);
        return mix(cvOnCup(th0), CV_PB, u) + vec2(0., CVG(2.6) * 4. * u * (1. - u));
    }
    if(k == CS_PRIME + 2){
        float tl = cvTilt(x);
        if(x < 0.84){
            float v = clamp((x - CV_HOLD[1] - 0.04) / 0.08, 0., 1.);
            ang = tl;
            return cvOnTable(-CV_TABLEW * v * v, tl);
        }
        float t0 = cvTilt(0.84), u = (x - 0.84) / 0.16;
        vec2 pe = cvOnTable(-CV_TABLEW, t0);
        ang = mix(t0, 6.28318, smoothstep(0., 1., u));
        return vec2(mix(pe.x, CV_PC.x, u), mix(pe.y, CV_PC.y, u * u));
    }
    if(x < CV_GOOP_HIT){ ang = 0.; return CV_PC; }
    vec2 pp = cvStPos(CS_POLISH);
    if(x < 0.85){
        float u = (x - CV_GOOP_HIT) / (0.85 - CV_GOOP_HIT);
        ang = 18.84956 * u;
        return mix(CV_PC, pp, u) + vec2(0., CVG(0.9) * 4. * u * (1. - u));
    }
    float v = (x - 0.85) / 0.15, b = sin(v * 3.14159) * (1. - v);
    ang = -0.35 * b;
    return pp + vec2(CVG(0.14) * b, 0.);
}

// glyph origin of the piece in arm a, `ph` through its weld
vec2 cvArmP(int a, float ph){
    float u = smoothstep(0.08, 0.42, ph);
    vec2 st = CV_PICK[a] - CV_PO[CV_ARMK[a]] * CV_SIZE;
    return mix(st, CV_JOIN[a], u) + vec2(0., 0.012 * sin(3.14159 * u));
}

vec2 cvArmTip(int a, float ph, bool busy){
    vec2 grip = CV_GRIP[CV_ARMK[a]] * CV_SIZE;
    vec2 st = CV_PICK[a] - CV_PO[CV_ARMK[a]] * CV_SIZE + grip;
    vec2 home = st + vec2(0., a == 0 ? -0.025 : 0.02);
    if(!busy) return home;
    if(ph < 0.08) return mix(home, st, smoothstep(0., 0.08, ph));
    if(ph < 0.78) return cvArmP(a, ph) + grip;
    return mix(CV_JOIN[a] + grip, home, smoothstep(0.78, 1., ph));
}

float cvFit(float asp){ return min(0.5 * asp / CV_HALF_W, 0.5 / CV_HALF_H); }

// ---- drawing ------------------------------------------------------------------

vec4 cvState(int x, int y){ return texelFetch(iChannel17, ivec2(x, y), 0); }

float cvHash(float n){ return fract(sin(n * 127.1) * 43758.5453); }

vec3 cvLavaRamp(float t){
    vec3 c = mix(vec3(0.05, 0.008, 0.004), vec3(0.45, 0.04, 0.01), smoothstep(0., 0.3, t));
    c = mix(c, vec3(1.2, 0.3, 0.03), smoothstep(0.25, 0.6, t));
    c = mix(c, vec3(1.7, 0.95, 0.25), smoothstep(0.55, 0.85, t));
    return mix(c, vec3(1.9, 1.7, 1.1), smoothstep(0.85, 1., t));
}

// molten metal: a dark crust broken by bright cracks that drift and churn;
// `heat` 1 is all liquid, 0 a cold crust
vec3 cvLava(vec2 p, float heat){
    vec2 w = p * 70. + vec2(iTime * 0.35, -iTime * 0.2);
    vec2 warp = vec2(tcNoise(w * 0.6 + iTime * 0.4), tcNoise(w * 0.6 - iTime * 0.3 + 5.2));
    float n = tcNoise(w + 1.8 * warp);
    float crack = pow(1. - abs(2. * n - 1.), 5.);
    float body = tcNoise(w * 0.35 - iTime * 0.15);
    float t = mix(0.12 + 0.55 * crack, 0.55 + 0.25 * body + 0.3 * crack, smoothstep(0.55, 1., heat));
    return cvLavaRamp(t * smoothstep(0., 0.35, heat + 0.1 * crack));
}

vec3 cvSparks(vec3 col, vec2 q, vec2 o, vec2 dir, float on, float seed, float spread){
    if(on <= 0. || length(q - o) > 0.16) return col;
    for(int k = 0; k < 14 + CVZ; k++){
        float fk = float(k) + seed;
        float life = 0.35 + 0.3 * cvHash(fk);
        float t = mod(iTime + cvHash(fk + 3.1) * life, life);
        float a = (cvHash(fk + 7.7) - 0.5) * spread;
        vec2 v = Rot(a) * dir * (0.25 + 0.35 * cvHash(fk + 1.3));
        vec2 p = o + v * t + vec2(0., -0.9) * t * t;
        vec2 tail = p - v * 0.03;
        float d = sdSegment(q, p, tail) - 0.0012;
        float fade = 1. - t / life;
        col += vec3(1., 0.7, 0.25) * 1.3 * fade * on * S(d);
    }
    col += vec3(1., 0.6, 0.2) * 0.25 * on * exp(-length(q - o) / 0.012);
    return col;
}

float cvSeg7(vec2 p, int dg){
    const int M[10] = int[](0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F);
    int m = M[clamp(dg, 0, 9)];
    float on = 1e9, off = 1e9;
    vec2 a[7] = vec2[](vec2(0., 0.5), vec2(0.3, 0.25), vec2(0.3, -0.25), vec2(0., -0.5), vec2(-0.3, -0.25), vec2(-0.3, 0.25), vec2(0., 0.));
    for(int k = 0; k < 7 + CVZ; k++){
        bool hz = k == 0 || k == 3 || k == 6;
        float d = sdSegment(p, a[k] - (hz ? vec2(0.22, 0.) : vec2(0., 0.19)), a[k] + (hz ? vec2(0.22, 0.) : vec2(0., 0.19))) - 0.065;
        if(((m >> k) & 1) == 1) on = min(on, d); else off = min(off, d);
    }
    return on < off ? on : off + 10.;
}

// n digits of v, cell h tall, left edge at o
vec3 cvDigits(vec3 col, vec2 q, vec2 o, float h, int n, float v, vec3 lit){
    vec2 p = (q - o) / h;
    float w = 0.8;
    if(p.y < -0.6 || p.y > 0.6 || p.x < -0.1 || p.x > w * float(n)) return col;
    int c = int(floor(p.x / w));
    float dv = floor(v / pow(10., float(n - 1 - c)));
    int dg = int(mod(dv, 10.));
    float d = cvSeg7(vec2(p.x - (float(c) + 0.5) * w, p.y), dg);
    if(d < 5.) col = mix(col, lit, S(d * h));
    else col = mix(col, lit * 0.12, S((d - 10.) * h));
    if(d < 5.) col += lit * 0.25 * exp(-max(d, 0.) * h / 0.006);
    return col;
}


float cvTrapezoid(vec2 p, float r1, float r2, float he){
    vec2 k1 = vec2(r2, he), k2 = vec2(r2 - r1, 2. * he);
    p.x = abs(p.x);
    vec2 ca = vec2(p.x - min(p.x, p.y < 0. ? r1 : r2), abs(p.y) - he);
    vec2 cb = p - k1 + k2 * clamp(dot(k1 - p, k2) / dot(k2, k2), 0., 1.);
    float s = (cb.x < 0. && ca.y < 0.) ? -1. : 1.;
    return s * sqrt(min(dot(ca, ca), dot(cb, cb)));
}

const vec3  CV_SLAB   = vec3(0.165, 0.17, 0.175);
const vec3  CV_HOLE   = vec3(0.042, 0.044, 0.048);
const vec3  CV_MC     = vec3(0.3, 0.31, 0.32);
const vec3  CV_SAND   = vec3(0.46, 0.39, 0.28);
const float CV_TUN    = CV_CELL;
const float CV_TUN_UP = CV_CELL - CV_ROWOFF;
const float CV_RISER  = CVX(-32.);
const vec2  CV_MELT   = vec2(CVX(-26.), CVG(-2.));

float cvCeil(int k){ return CV_ST_Y[k] + CV_TUN + CV_TUN_UP; }

float cvShaft(vec2 q, int k, float w, float h){
    w = CVG(0.5); h *= CV_K;
    return sdBox(q - vec2(CV_ST_X[k], cvCeil(k) + h * 0.5 - 0.003), vec2(w, h * 0.5));
}

vec3 cvMach(vec3 col, float d, float shade){
    col = mix(col, CV_MC * shade, S(d));
    return mix(col, CV_MC * shade * 0.55, S(abs(d) - 0.0006) * 0.7);
}

// the P carved by the J's design gap falls apart into the bowl and the tail
float cvPcut(vec2 g){ return max(sdP(g), PAD - sdJ(g)); }
float cvPmain(vec2 g){ return max(cvPcut(g), CV_PSPLIT - g.y); }
float cvPdot(vec2 g){ return max(cvPcut(g), g.y - CV_PSPLIT); }

float cvMouldD(vec2 g, int kind){ return sdRoundBox(g - CV_MCEN[kind], CV_MHALF[kind], 0.06); }

// ---- moulds: one standard steel flask for every line. The hammer smashes the
// sand and drops the flask through a hatch into the return tunnel; flasks
// and sand ride left and fall down the tower shaft into the blast pit, where
// air jets strip the sand off. A paternoster lifts the flasks through a wash,
// a dryer and the one sand filler into the head of each line; a bucket
// elevator carries the sand from the pit back up to the hopper
const float CV_RET_X   = CVX(-10.);
const float CV_RET_Y   = CVG(7.);
const float CV_DROP_X  = CVX(-37.);
const float CV_PAT_X   = CVX(-35.);
const vec2  CV_PIT     = vec2(CVG(-35.5), CVG(-12.5));
const vec2  CV_PIT_H   = vec2(CVG(1.5), CVG(1.5));
const vec2  CV_HOPPER  = vec2(CVX(-33.), CVG(3.5));
const float CV_SELEV_X = CVX(-31.);
const float CV_FRAME_V = 0.12;
const vec2  CV_WASHY   = vec2(CVG(-9.), CVG(-5.));
const vec2  CV_DRYY    = vec2(CVG(-4.), CVG(0.));
const vec2  CV_FILLY   = vec2(CVG(1.), CVG(2.5));

// an empty flask, open at the top, around glyph point g of a piece's mould
float cvFlask(vec2 g, int kind){
    float md = cvMouldD(g, kind);
    return max(max(md, -(md + 0.1)), g.y - CV_MCEN[kind].y - CV_MHALF[kind].y + 0.04) * CV_DSIZE;
}

float cvCarveReturn(vec2 q){
    float d = sdBox(q - vec2((CV_RET_X + CV_DROP_X) * 0.5, CV_RET_Y), vec2((CV_RET_X - CV_DROP_X) * 0.5 + CVG(0.5), CV_CELL));
    d = min(d, sdBox(q - vec2(CV_RET_X, (CV_TOPY + CV_RET_Y) * 0.5), vec2(CVG(0.5), (CV_TOPY - CV_RET_Y) * 0.5)));
    d = min(d, sdBox(q - vec2(CV_DROP_X, (CV_RET_Y + CV_PIT.y) * 0.5), vec2(CVG(0.5), (CV_RET_Y - CV_PIT.y) * 0.5)));
    d = min(d, sdBox(q - CV_PIT, CV_PIT_H));
    return min(d, sdBox(q - vec2(CV_PAT_X, (CV_TOPY + CV_PIT.y) * 0.5 + 0.01), vec2(CVG(0.5), (CV_TOPY - CV_PIT.y) * 0.5 + 0.01)));
}

// the mould knocked off a piece `f` seconds after the hammer hit its top:
// the shatter transition's log-polar Voronoi round the impact, every shard
// flying out from it, tumbling and falling
vec3 cvShards(vec3 col, vec2 g, float f, float key, int kind){
    vec2 c = vec2(0., CV_MCEN[kind].y + CV_MHALF[kind].y);
    float px = 1. / (iResolution.y * CV_SIZE);
    vec2 rq = g - c - vec2(0., 0.6 * f - 3. * f * f);
    int s0 = int(floor(atan(rq.y, rq.x) / 6.2831853 * SH_SECTORS));
    col += vec3(1., 0.9, 0.7) * 0.5 * exp(-f * 14.) * exp(-length(g - c) / 0.3);
    for(int j = 0; j < SH_RINGS + 2 + CVZ; j++){
        for(int di = -SH_REACH; di <= SH_REACH; di++){
            int i = (s0 + di + 4 * int(SH_SECTORS)) % int(SH_SECTORS);
            vec2 cell = vec2(float(i), float(j - SH_RINGS));
            vec2 cs = shCentre(cell, c, key);
            vec2 dir = cs - c;
            float dl = length(dir);
            vec2 vel = dir / max(dl, 1e-3) * 1.3 * (0.6 + 0.8 * random(cell + key + 2.2)) / (dl + 0.5) + vec2(0., 0.5);
            vec2 off = vel * f + vec2(0., -3.5 * f * f);
            float th = 9. * (random(cell + key + 5.1) - 0.5) * f;
            vec2 rel = g - cs - off;
            float rad = dl * 0.8 + 0.08;
            if(dot(rel, rel) > rad * rad) continue;
            vec2 g0 = cs + mat2(cos(th), -sin(th), sin(th), cos(th)) * rel;
            float md = cvMouldD(g0, kind);
            if(md > 0.) continue;
            vec2 cn;
            vec3 v = shVoronoi(shPolar(g0, c), key + 22., cn);
            if(any(notEqual(v.xy, cell))) continue;
            float lit = 0.5 + 0.5 * cos(th * 1.7 + float(i));
            vec3 pc = CV_SAND * (0.5 + 0.6 * lit);
            float edge = min(-md, v.z * 0.05);
            col = mix(col, pc, smoothstep(0., 2. * px, edge) * (1. - smoothstep(0.45, 0.6, f)));
        }
    }
    return col;
}

// the finish after `stage` airbrush passes: bare metal, primer, base coat,
// the brand gradient, then clear coat with a travelling glint
vec3 cvPaint(int stage, vec2 g, float fi){
    if(stage <= 0) return vec3(0.4, 0.41, 0.43);
    if(stage == 1) return vec3(0.9, 0.9, 0.88);
    if(stage == 2) return GRAD_BOT * 0.85;
    vec3 c = ampGradient(g);
    if(stage >= 4){
        float ph = fract(iTime * 0.35 + fi * 0.37) * 5. - 2.;
        c = c * 1.08 + vec3(0.55) * exp(-pow((g.x + g.y - ph) * 6., 2.));
    }
    return c;
}

vec3 cvGoop(vec2 g, float fi){
    float n = tcNoise(g * 9. + fi);
    return vec3(0.36, 0.21, 0.1) * (0.75 + 0.45 * n) + vec3(0.3, 0.2, 0.1) * 0.6 * exp(-pow((g.x - g.y * 0.3 - 0.1) * 4., 2.));
}

// a mortarboard with a gold tassel, in glyph units of the amp wearing it
vec3 cvCap(vec3 col, vec2 gp){
    gp = (gp - vec2(0., 0.52)) / 1.3 + vec2(0., 0.52);
    float cap = min(sdBox(gp - vec2(0., 0.6), vec2(0.22, 0.08)), sdBox(gp - vec2(0., 0.7), vec2(0.46, 0.03))) * CV_DSIZE * 1.3;
    col = mix(col, vec3(0.01), S(cap - 0.0012) * 0.4);
    col = mix(col, vec3(0.06, 0.06, 0.07) + 0.08 * smoothstep(0.66, 0.73, gp.y), S(cap));
    float tl = min(sdSegment(gp, vec2(0., 0.73), vec2(0.36, 0.71)), sdSegment(gp, vec2(0.36, 0.71), vec2(0.4, 0.45))) * CV_DSIZE * 1.3;
    col = mix(col, vec3(0.85, 0.66, 0.2), S(tl - 0.0006));
    return mix(col, vec3(0.92, 0.72, 0.22), S(length(gp - vec2(0.4, 0.42)) * CV_DSIZE * 1.3 - 0.0016));
}

vec3 cvBox(vec3 col, vec2 bd, int m, float tp, float seed){
    float b = sdRoundBox(bd, vec2(0.0245, 0.0215), 0.002);
    if(b > 0.004) return col;
    col = mix(col, vec3(0.02), S(b - 0.002) * 0.5);
    vec3 cb = vec3(0.5, 0.36, 0.21) * (0.92 + 0.08 * tcNoise(bd * 400.));
    cb *= 1. - 0.25 * S(abs(bd.y - 0.012) - 0.0006);
    if(tp > 0.){
        float grow = smoothstep(0.15, 0.75, tp);
        float cx = (cvHash(seed + 1.) - 0.5) * 0.004 + (cvHash(seed) - 0.5) * 0.25 * bd.y;
        float y0 = 0.0225, y1 = y0 - 0.045 * grow;
        float tape = max(abs(bd.x - cx) - 0.0046 - 0.0005 * sin(bd.y * 1300. + seed * 7.), max(bd.y - y0, y1 - bd.y + 0.0006 * sin(bd.x * 1500. + seed)));
        cb = mix(cb, vec3(0.7, 0.58, 0.38) * (0.9 + 0.12 * tcNoise(bd * 700.)), S(tape) * 0.95);
        cb = mix(cb, vec3(0.84, 0.74, 0.54), S(abs(bd.x - cx - 0.002) - 0.0005) * S(tape) * 0.5);
    }
    if(((m >> CS_LABEL) & 1) == 1){
        vec2 lp = bd - vec2(0., -0.007);
        cb = mix(cb, vec3(0.88), S(sdRoundBox(lp, vec2(0.0115, 0.008), 0.001)));
        cb = mix(cb, GRAD_TOP * 0.9, S(glyphDist(lp / 0.012) * 0.012));
    }
    col = mix(col, cb, S(b));
    return mix(col, vec3(0.28, 0.19, 0.1), S(abs(b) - 0.0008));
}

float cvStressK(vec4 st){ return st.x >= 0. ? smoothstep(0.1, 0.4, st.x) * (1. - smoothstep(0.7, 0.95, st.x)) : 0.; }

vec3 cvTowerFlask(vec3 col, vec2 q, vec2 c, float id, float dirt, float wet, float fill);

// a returning flask at p: caked in sand until the blast pit, then on the
// paternoster wet from the wash, drying, filling with fresh sand
vec3 cvFrameItem(vec3 col, vec2 q, vec2 p, float id){
    vec3 st = vec3(1., 0., 0.);
    bool pat = abs(p.x - CV_PAT_X) < 0.001 && p.y > CVR(-13.6) + 0.001;
    if(pat) st = vec3(0.15 * (1. - smoothstep(CV_PIT.y, CV_WASHY.x, p.y)),
                      smoothstep(CV_WASHY.x, CV_WASHY.x + 0.03, p.y) * (1. - smoothstep(CV_DRYY.x, CV_DRYY.y, p.y)),
                      smoothstep(CV_FILLY.x, CV_FILLY.y, p.y));
    else if(p.y < CVR(-13.)) st.x = 1. - 0.85 * smoothstep(0.05, 0.9, (p.x - CV_DROP_X) / (CV_PAT_X - CV_DROP_X));
    vec2 c = p + vec2(0., (CV_MCEN[0].y - CV_MHALF[0].y) * CV_SIZE);
    if(pat) col = cvMach(col, sdBox(q - c + vec2(0., 0.002), vec2(0.014, 0.0015)), 0.7);
    return cvTowerFlask(col, q, c, id, st.x, st.y, st.z);
}

// one item: a molten, rough, knocked-out piece, the J as the others are welded
// on, painted pass by pass, then a box, taped and labelled
vec3 cvItem(vec3 col, vec2 q, int i){
    vec4 r0 = cvState(i, 0), r1 = cvState(i, 1);
    int t = cvI(r1.x);
    if(t < 0) return col;
    vec2 d = (q - r0.xy) / CV_M;
    if(dot(d, d) > 0.0056) return col;
    int m = cvI(r1.w);
    float s = r1.y, fi = float(i);
    int kind = cvI(r0.w) & 3;
    if(kind == CV_KFRAME) return cvFrameItem(col, q, r0.xy, fi);
    bool rej = ((cvI(r0.w) >> 2) & 1) == 1;
    int li = cvLineOfKind(kind);
    bool line = cvLineOfTrack(t) >= 0;
    bool arm = t == CT_ARM1 || t == CT_ARM2;
    bool ground = ((m >> (3 + li)) & 1) == 1;
    if(((m >> CS_BOX) & 1) == 1){
        vec4 tst = cvState(CS_TAPE, CV_ROW);
        float tp = ((m >> CS_TAPE) & 1) == 1 ? 1. : cvI(tst.y) == i && tst.x >= 0. ? tst.x : 0.;
        return cvBox(col, Rot(r0.z) * d - vec2(0., -0.0015), m, tp, fi);
    }

    float hp = -1.;
    if(line && !ground){
        vec4 hs = cvState(3 + li, CV_ROW);
        if(cvI(hs.y) == i && hs.x >= 0.) hp = hs.x;
    }
    bool shat = hp >= CV_HIT;
    float pour = 1.;
    if(line && ((m >> li) & 1) == 0){
        vec4 ps = cvState(li, CV_ROW);
        pour = ps.w > float(cvBatchN(li)) - 0.5 && cvBatchSlot(li, s) >= 0 ? clamp(ps.x * 1.25 - 0.1, 0., 1.) : 0.;
    }
    vec2 gp = Rot(r0.z) * d / CV_DSIZE;
    if(t == CT_FIN){
        vec4 sq = cvState(CS_SQUEEZE, CV_ROW), sr = cvState(CS_STRETCH, CV_ROW);
        if(cvI(sq.y) == i) gp = (gp + vec2(0., 0.55)) * vec2(1. + 0.6 * cvStressK(sq), 1. - 0.15 * cvStressK(sq)) - vec2(0., 0.55);
        if(cvI(sr.y) == i) gp = (gp - vec2(0., 0.55)) * vec2(1. + 0.2 * cvStressK(sr), 1. / (1. + 0.4 * cvStressK(sr))) + vec2(0., 0.55);
    }
    vec2 g = arm ? gp : gp + CV_PO[kind];
    float dd;
    if(kind == 0){
        bool w1 = ((m >> CS_WELD1) & 1) == 1, w2 = ((m >> CS_WELD2) & 1) == 1;
        dd = w2 ? glyphDist(g) : w1 ? min(sdJ(g), cvPdot(g)) : sdJ(g);
    }
    else if(kind == 1) dd = cvPmain(g);
    else dd = cvPdot(g);
    if(line && !ground && !shat) dd += (tcNoise(g * 16. + fi * 3.7) - 0.5) * 0.06;
    dd *= CV_DSIZE;

    float heat = line ? clamp(1. - (s - cvSAtSt(li)) / 0.45, 0., 1.) * pour : 0.;
    int stage = 0;
    for(int k = CS_PRIME; k <= CS_CLEAR + CVZ; k++) stage += (m >> k) & 1;
    vec3 c = cvPaint(stage, g, fi);
    float blk = 0.;
    if(kind == 0 && ((m >> CS_WELD2) & 1) == 1 && stage == 0 && (t == CT_J || t == CT_DROP || t == CT_MAIN)){
        float soot = 0.;
        if(t == CT_MAIN){
            float h0 = cvSAtP(CT_MAIN, vec2(CVX(3.), CVR(-10.))), h1 = cvSAtP(CT_MAIN, vec2(CVG(10.), CVR(-4.)));
            soot = 0.85 * clamp((s - h0) / (h1 - h0), 0., 1.);
            vec4 cs = cvState(CS_CAUSTIC, CV_ROW);
            float dk = ((m >> CS_CAUSTIC) & 1) == 1 ? 1. : cs.x >= 0. && cvBatchSlot(CS_CAUSTIC, s) >= 0 ? smoothstep(0.3, 0.75, cs.x * CV_ST_DW[CS_CAUSTIC] / 3.) : 0.;
            soot = mix(soot, 0.97, dk);
        }
        blk = smoothstep(0.85, 0.97, soot);
        vec3 tg = mix(vec3(0.13, 0.12, 0.11), vec3(0.06, 0.058, 0.056), blk);
        c = mix(c, tg * (0.8 + 0.4 * tcNoise(g * 12. + fi)), soot);
    }
    if(t == CT_MAIN){
        vec2 np = cvAt(t, s);
        float cov = 0., dry = 0.;
        if(abs(np.y - CVR(9.)) < 0.001 && np.x < CVG(24.)) cov = clamp((CVG(24.) - np.x) / CVG(0.3), 0., 1.);
        if(cvDripAt(np)){
            cov = 1.;
            dry = clamp((np.x - CVX(9.)) / CVG(10.), 0., 1.);
        }
        vec3 wet = vec3(0.8, 0.8, 0.79) + 0.18 * exp(-pow((g.x + g.y - 0.3) * 5., 2.));
        c = mix(c, mix(wet, cvPaint(1, g, fi), dry), cov);
    }
    if(line && !ground && !shat) c = vec3(0.36, 0.37, 0.39) * (0.8 + 0.25 * tcNoise(g * 30.));
    if(stage < 4){
        vec4 sp = cvState(CS_PRIME + stage, CV_ROW);
        if(cvI(sp.y) == i && sp.x >= 0.){
            float cp = cvCoatP(CS_PRIME + stage, sp.x);
            float cov = stage == 3 ? smoothstep(0.08, -0.08, length(gp - vec2(0.5, 0.15)) + 0.3 * (tcNoise(gp * 6. + fi) - 0.5) - 2.4 * cp) : smoothstep(-0.04, 0.04, gp.y - (0.6 - 1.25 * cp));
            c = mix(c, stage == 3 ? cvGoop(g, fi) : cvPaint(stage + 1, g, fi), cov);
        }
    }
    if(stage >= 4 && ((m >> cvBit(CS_POLISH)) & 1) == 0){
        vec4 ps = cvState(CS_POLISH, CV_ROW);
        float rev = cvI(ps.y) == i && ps.x >= 0. ? smoothstep(-0.05, 0.05, -0.6 + 1.25 * smoothstep(0.15, 0.85, ps.x) - gp.y) : 0.;
        c = mix(cvGoop(g, fi), c, rev);
    }
    if(((m >> CS_STAMP) & 1) == 1) c = mix(c, vec3(0.95), S(length(g - vec2(0.17, 0.12)) * CV_DSIZE - 0.0028) * 0.9);
    if(rej && ((m >> CS_SCAN) & 1) == 1) c = mix(c, vec3(0.8, 0.12, 0.08), 0.55);
    vec3 hot = cvLavaRamp(0.35 + 0.55 * heat);
    c = mix(c * (1. - 0.5 * smoothstep(0., 0.3, heat)), cvLava(g * CV_SIZE * 1.4 + fi * 0.37, heat * 1.1), smoothstep(0.02, 0.35, heat));

    if(shat) col = cvShards(col, gp, (hp - CV_HIT) * CV_ST_DW[3 + li], fi * 1.37 + floor(s * 10.), kind);
    if(shat) col = cvTowerFlask(col, q, r0.xy + vec2(0., (CV_MCEN[0].y - CV_MHALF[0].y) * CV_SIZE), fi, 1., 0., 0.);
    if(line && !ground && !shat){
        float mould = cvMouldD(gp, kind) * CV_DSIZE;
        vec2 mc = CV_MCEN[kind], mh = CV_MHALF[kind];
        float sandTop = mc.y + mh.y, cav = 1.;
        if(((m >> (CS_PRESS + li)) & 1) == 0){
            vec4 pr = cvState(CS_PRESS + li, CV_ROW);
            cav = cvI(pr.y) == i && pr.x >= 0. ? smoothstep(0.3, 0.55, pr.x) : 0.;
        }
        float inner = mould + 0.004;
        col = mix(col, CV_HOLE * 1.4, S(mould));
        col = mix(col, CV_SAND * (0.62 + 0.12 * tcNoise(gp * 40. + fi)), S(max(inner, (gp.y - sandTop) * CV_DSIZE)));
        float wall = max(max(mould, -inner), (gp.y - mc.y - mh.y + 0.04) * CV_DSIZE);
        col = mix(col, CV_MC * 0.85, S(wall));
        float fill = mix(CV_MCEN[kind].y - CV_MHALF[kind].y, CV_MCEN[kind].y + CV_MHALF[kind].y, pour);
        if(gp.y > fill) return mix(col, vec3(0.06, 0.05, 0.04), S(dd) * 0.85 * cav);
    }
    vec4 xr = cvState(CS_XRAY, CV_ROW);
    if(t == CT_J && cvI(xr.y) == i && xr.x >= 0.){
        float on = smoothstep(0., 0.15, xr.x) * (1. - smoothstep(0.85, 1., xr.x));
        col = mix(col, mix(c, vec3(0.04, 0.1, 0.13), on), S(dd));
        col += vec3(0.35, 0.9, 1.) * on * (S(abs(dd) - 0.0006) + 0.25 * exp(-abs(dd) / 0.003));
        for(int w = 0; w < 2 + CVZ; w++) col += vec3(0.7, 1., 1.) * on * 0.8 * exp(-length(g - CV_SEAM[w]) / 0.07) * S(dd - 0.002);
        return col;
    }
    col += hot * 0.35 * heat * exp(-max(dd, 0.) / 0.008);
    col = mix(col, vec3(0.01), S(dd - 0.0015) * 0.35);
    col = mix(col, c, S(dd));
    col += vec3(0.24, 0.25, 0.27) * blk * S(abs(dd + 0.0005) - 0.00045);

    if(t == CT_PACK && kind == 0 && ((m >> cvBit(CS_HAT)) & 1) == 1) col = cvCap(col, gp);
    vec4 bx = cvState(CS_BOX, CV_ROW);
    if(cvI(bx.y) == i && bx.x >= 0.){
        float p = bx.x;
        vec2 bd = d - vec2(0., -0.0015);
        float b = sdRoundBox(bd, vec2(0.0245, 0.0215), 0.002);
        col = mix(col, vec3(0.5, 0.36, 0.21) * (0.92 + 0.08 * tcNoise(bd * 400.)), S(b));
        col = mix(col, vec3(0.28, 0.19, 0.1), S(abs(b) - 0.0008));
        float fl = smoothstep(0.1, 0.8, p);
        for(int sd = -1; sd <= 1 + CVZ; sd += 2){
            vec2 hinge = vec2(0.0245 * float(sd), 0.02);
            vec2 tip = hinge + Rot(float(sd) * (1. - fl) * 1.4) * vec2(-0.024 * float(sd), 0.);
            col = mix(col, vec3(0.42, 0.3, 0.17), S(sdSegment(d, hinge, tip) - 0.0016));
        }
    }
    return col;
}

// ---- the slab: one grey block with the tunnels cut out of it -------------------

float cvCarve(vec2 q){
    float d = 1e9;
    for(int t = 0; t < CV_NT + CVZ; t++){
        for(int k = 1; k < CV_MAXP + CVZ; k++){
            if(k >= CV_TN[t]) break;
            vec2 a = CV_PTS[CV_T0[t] + k - 1], b = CV_PTS[CV_T0[t] + k];
            vec2 lo = floor((min(a, b) - vec2(CVG(0.5), CV_ROWOFF)) / CV_CELL + 0.02) * CV_CELL;
            vec2 hi = ceil((max(a, b) + vec2(CVG(0.5), CVG(2.) - CV_ROWOFF)) / CV_CELL - 0.02) * CV_CELL;
            if(abs(a.y - b.y) > CVG(1.)) hi.y = ceil((max(a.y, b.y) - CV_ROWOFF) / CV_CELL + 0.98) * CV_CELL;
            if((t == CT_MAIN && k == 9) || (t == CT_FIN && k < 3)) continue;
            d = min(d, sdBox(q - (lo + hi) * 0.5, (hi - lo) * 0.5));
        }
    }
    d = min(d, sdBox(q - CVG(0.5) * (CV_WELDROOM.xy + CV_WELDROOM.zw), CVG(0.5) * (CV_WELDROOM.zw - CV_WELDROOM.xy)));
    d = min(d, sdBox(q - vec2(CVG(17.5), CVG(-13.)), vec2(CVG(15.5), CVG(2.))));
    d = min(d, sdBox(q - vec2(CVG(15.), CVG(-7.)), vec2(CVG(4.), CVG(3.))));
    d = min(d, sdBox(q - vec2(CVG(23.5), CVG(-6.)), vec2(CVG(3.5), CVG(4.))));
    d = min(d, sdBox(q - vec2(CVG(19.5), CVG(-3.)), vec2(CVG(1.5), CVG(1.))));
    d = min(d, sdBox(q - vec2(CVG(30.5), CVG(2.5)), vec2(CVG(2.5), CVG(14.5))));
    d = min(d, cvShaft(q, CS_GRIND, 0.016, 0.035));
    for(int j = 0; j < 5 + CVZ; j++) d = min(d, sdBox(q - vec2(CVG(-3.), CV_ST_Y[CV_QC_K[j]]), vec2(CVG(1.), CVG(1.))));
    d = min(d, cvShaft(q, 3, 0.017, 0.02));
    d = min(d, cvShaft(q, 4, 0.017, 0.03));
    d = min(d, cvShaft(q, 5, 0.017, 0.02));
    d = min(d, cvShaft(q, CS_TAPE, 0.016, 0.03));
    d = min(d, cvShaft(q, CS_LABEL, 0.013, 0.04));
    d = min(d, sdBox(q - vec2(CVG(-18.), CVG(-1.)), vec2(CVG(11.), CVG(3.))));
    d = min(d, sdBox(q - vec2(CVG(-11.), CVG(-10.)), vec2(CVG(4.), CVG(5.))));
    d = min(d, sdBox(q - vec2(CVG(-17.5), CVG(-10.)), vec2(CVG(1.5), CVG(5.))));
    d = min(d, sdBox(q - vec2(CVG(11.), CVG(2.)), vec2(CVG(12.), CVG(3.))));
    d = min(d, sdBox(q - vec2(CVG(21.5), CVG(6.)), vec2(CVG(1.5), CVG(1.))));
    d = min(d, sdBox(q - vec2(CVG(25.5), CVG(2.)), vec2(CVG(1.5), CVG(4.))));
    d = min(d, sdBox(q - vec2(CVG(17.5), CVG(10.)), vec2(CVG(9.5), CVG(4.))));
    for(int j = 0; j < 3 + CVZ; j++) d = min(d, sdBox(q - vec2(CVG(6.), CVG(-9. + 3. * float(j))), vec2(CVG(4.), CVG(1.))));
    d = min(d, cvCarveReturn(q));
    for(int li = 0; li < 3 + CVZ; li++) d = min(d, cvShaft(q, CS_PRESS + li, 0.016, li == 1 ? 0.03 : 0.02));
    float xr = CVG(20.) + (CVG(7.) - q.y) / 3.;
    d = max(d, -max(max((q.x - xr) * 0.949, CVG(20.) - q.x), max(CVG(1.) - q.y, q.y - CVG(7.))));
    d = max(d, -sdBox(q - vec2(CVG(-18.5), CVG(-11.5)), vec2(CVG(0.5), CVG(0.5))));
    d = max(d, -max(sdBox(q - vec2(CVG(5.5), CVG(2.)), vec2(CVG(0.5), CVG(3.))), -sdBox(q - vec2(CVG(5.5), CVG(0.5)), vec2(CVG(0.6), CVG(0.5)))));
    d = max(d, -max(sdBox(q - vec2(CVG(10.5), CVG(2.)), vec2(CVG(0.5), CVG(3.))), -sdBox(q - vec2(CVG(10.5), CVG(2.)), vec2(CVG(0.6), CVG(1.)))));
    d = max(d, -max(sdBox(q - vec2(CVG(15.5), CVG(2.)), vec2(CVG(0.5), CVG(3.))), -sdBox(q - vec2(CVG(15.5), CVG(2.)), vec2(CVG(0.6), CVG(2.)))));
    return max(d, -sdBox(q - vec2(CVG(19.5), CVG(6.5)), vec2(CVG(0.5), CVG(0.5))));
}

vec3 cvSlab(vec2 q, vec2 tp, float carve);

vec3 cvWallHoles(vec3 col, vec2 q, vec2 tp){
    if(q.x < CVG(5.) || q.x > CVG(16.) || q.y < CVG(0.) || q.y > CVG(4.)) return col;
    float h = min(min(sdBox(q - vec2(CVG(5.5), CVG(0.5)), vec2(CVG(0.5), CVG(0.5))), sdBox(q - vec2(CVG(10.5), CVG(2.)), vec2(CVG(0.5), CVG(1.)))), sdBox(q - vec2(CVG(15.5), CVG(2.)), vec2(CVG(0.5), CVG(2.))));
    if(h > 0.) return col;
    vec3 back = cvSlab(q, tp, 1.) * vec3(0.42, 0.42, 0.48) * mix(0.55, 1., smoothstep(0., CVG(0.35), -h));
    return mix(col, back, S(h));
}

vec3 cvSlab(vec2 q, vec2 tp, float carve){
    float pp = CVG(1.) / 10.;
    vec2 pix = floor(q / pp), ip = mod(pix, 10.), id = floor(pix / 10.);
    float h = cvHash(id.x * 17.3 + id.y * 91.7), h2 = cvHash(id.x * 5.1 + id.y * 33.3 + 7.);
    float r = cvHash(pix.x * 1.37 + pix.y * 91.13);
    float brush = 0.82 + 0.3 * tcNoise(vec2(q.x * 30. + id.y * 7.3, pix.y * 1.7)) + 0.08 * (cvHash(pix.y * 3.1 + id.x * 1.7) - 0.5);
    float sheen = 0.88 + 0.24 * (1. - (ip.x + 9. - ip.y) / 18.);
    vec3 base = vec3(0.13, 0.135, 0.145) * (0.92 + 0.16 * h) * mix(vec3(1.), vec3(0.97, 1., 1.03), h2) * brush * sheen;
    bool inner = ip.x > 0.5 && ip.x < 8.5 && ip.y > 0.5 && ip.y < 8.5;
    if(h2 > 0.82 && inner && mod(ip.x + ip.y, 3.) < 0.5) base *= 1.3;
    else if(h2 > 0.72 && h2 <= 0.82 && ip.x > 1.5 && ip.x < 7.5 && ip.y > 1.5 && ip.y < 7.5 && mod(ip.y, 2.) > 0.5) base *= 0.35;
    if(ip.x < 0.5 || ip.y > 8.5) base *= 1.35;
    if(ip.x > 8.5 || ip.y < 0.5) base *= 0.55;
    if((abs(ip.x - 1.) < 0.5 || abs(ip.x - 8.) < 0.5) && (abs(ip.y - 1.) < 0.5 || abs(ip.y - 8.) < 0.5)) base = vec3(0.23, 0.24, 0.26);
    if(r < 0.04) base *= 0.85;
    if(tcNoise(id * 0.7 + 3.) > 0.7 && r < 0.25) base = mix(base, vec3(0.19, 0.1, 0.05), 0.35);
    vec3 col = floor(base * 64. + 0.5) / 64.;
    if(carve >= 0. && carve < pp) col = vec3(0.19, 0.195, 0.21);
    float hb = 1. + 0.18 * float(ip.x < 0.5 || ip.y > 8.5) - 0.22 * float(ip.x > 8.5 || ip.y < 0.5);
    float hg = 0.9 + 0.2 * tcNoise(vec2(q.x * 30. + id.y * 7.3, pix.y * 1.7));
    float ao = 0.55 + 0.45 * floor(smoothstep(0., 0.02, -carve) * 4.) / 4.;
    vec3 hole = floor(vec3(0.034, 0.036, 0.04) * (0.9 + 0.2 * h) * hb * hg * ao * 160. + 0.5) / 160.;
    return carve < 0. ? hole : col;
}

vec3 cvBelts(vec3 col, vec2 q){
    for(int t = 0; t < CV_NT + CVZ; t++){
        if(t == CT_DROP || t == CT_REJ || t == CT_SLIDE) continue;
        for(int k = 1; k < CV_MAXP + CVZ; k++){
            if(k >= CV_TN[t]) break;
            vec2 a = CV_PTS[CV_T0[t] + k - 1], b = CV_PTS[CV_T0[t] + k];
            if(abs(a.y - b.y) > 1e-3 || abs(a.x - b.x) < 0.1) continue;
            float y = a.y - CV_SIZE * 0.5 - 0.002;
            float d = sdSegment(q, vec2(a.x, y), vec2(b.x, y)) - 0.002;
            if(d > 0.004) continue;
            if(t == CT_MAIN && abs(a.y - CVR(-4.)) < 0.001 && q.x > CVG(10.)) continue;
            if(t == CT_PACK && a.y < CVR(-14.) && q.x > CVG(-15.) && q.x < CVG(-7.)) continue;
            if(t == CT_FIN && abs(a.y - CVR(-1.)) < 0.001 && q.x > CVG(5.) && q.x < CVG(16.)) continue;
            float bv = t == CT_FIN ? CV_PAINT_V : t == CT_MAIN && cvHeatAt(q) ? CV_BELT_V * 0.5 : (t == CT_MAIN && abs(a.y - CVR(3.)) > 0.001) || t == CT_PACK ? CV_BELT_V * 0.25 : CV_BELT_V;
            if(t == CT_PACK && abs(a.y - CVR(-11.)) < 0.001) bv = 0.12;
            if(t == CT_MAIN && (abs(a.y - CVR(9.)) < 0.001 || abs(a.y - CVR(7.)) < 0.001)) continue;
            float tick = step(0.7, fract((q.x - iTime * bv * sign(b.x - a.x)) / 0.012));
            col = mix(col, CV_MC * (0.55 + 0.15 * tick), S(d));
        }
    }
    return col;
}

// lava veins in the slab: a riser from above feeding a channel over each
// foundry, four nozzles down to its batch of moulds
vec3 cvVeins(vec3 col, vec2 q, float carve){
    if(q.x > CVG(-23.) || q.y < CVG(10.)) return col;
    float fl = 0.85 + 0.15 * tcNoise(vec2(iTime * 5., 3.));
    float ch = 1e9;
    for(int li = 0; li < 3 + CVZ; li++){
        float c = cvCeil(li), y = c + 0.012;
        ch = min(ch, sdSegment(q, vec2(CV_RISER, y), vec2(CV_ST_X[li], y)));
        for(int k = 0; k < 8 + CVZ; k++){
            if(k >= cvBatchN(li)) break;
            float x = CV_ST_X[li] - CV_GAP * float(k);
            ch = min(ch, sdSegment(q, vec2(x, y), vec2(x, c)) - 0.001);
        }
    }
    ch -= 0.003;
    float riser = sdSegment(q, vec2(CV_RISER, 0.8), vec2(CV_RISER, cvCeil(2) + 0.012));
    float inTun = S(carve);
    col = mix(col, CV_MC * 0.7, S(riser - 0.005) * inTun);
    ch = min(ch, max(riser - 0.0035, -carve));
    col += vec3(1., 0.33, 0.06) * 0.1 * fl * exp(-max(ch, 0.) / 0.015) * (1. - inTun);
    col = mix(col, vec3(0.02), S(ch - 0.0015));
    col = mix(col, cvLava(q * 0.8, 0.95) * fl, S(ch));
    return mix(col, cvLava(q * 0.8 + 2., 0.9) * fl, S(riser - 0.002) * inTun * 0.85);
}

vec3 cvStream(vec3 col, vec2 q, vec2 a, vec2 b, float on, float seed){
    if(on <= 0.) return col;
    float d = sdSegment(q, a, b);
    if(d > 0.03) return col;
    float w = 0.0018 * on * (0.85 + 0.15 * sin(q.y * 400. - iTime * 50. + seed));
    vec3 c = cvLavaRamp(0.7 + 0.25 * tcNoise(vec2(q.y * 180. + iTime * 22., seed)) + 0.12 * (1. - smoothstep(0., w, d)));
    col = mix(col, c, S(d - w));
    col += vec3(1., 0.42, 0.1) * 0.2 * on * exp(-max(d - w, 0.) / 0.006);
    return col + vec3(1., 0.5, 0.15) * 0.3 * on * exp(-length(q - b) / 0.01);
}

vec3 cvPours(vec3 col, vec2 q, vec4 st[31]){
    if(q.x > CVG(-23.) || q.y < CVG(9.) || q.y > CVG(18.)) return col;
    for(int li = 0; li < 3 + CVZ; li++){
        vec4 ps = st[li];
        float on = ps.w > float(cvBatchN(li)) - 0.5 ? smoothstep(0.06, 0.12, ps.x) * (1. - smoothstep(0.8, 0.86, ps.x)) : 0.;
        int kind = li == 0 ? 1 : li == 1 ? 0 : 2;
        float bot = CV_ST_Y[li] + (CV_MCEN[kind].y + CV_MHALF[kind].y) * CV_SIZE - 0.004;
        for(int k = 0; k < 8 + CVZ; k++){
            if(k >= cvBatchN(li)) break;
            float x = CV_ST_X[li] - CV_GAP * float(k);
            col = cvStream(col, q, vec2(x, cvCeil(li)), vec2(x, bot), on, float(k + li * 5));
        }
    }
    return col;
}

const vec2 CV_WIND = vec2(CVG(-23.), CVG(-11.));

// a fan at the downstream end of each wind tunnel, behind the moulds,
// blowing back against them
vec3 cvFans(vec3 col, vec2 q){
    if(q.x < CV_WIND.y - 0.06 || q.x > CV_WIND.y + 0.03 || q.y < CVG(9.) || q.y > CVG(18.)) return col;
    for(int li = 0; li < 3 + CVZ; li++){
        vec2 c = vec2(CV_WIND.y - CVG(0.5), CV_ST_Y[li] + CV_TUN_UP);
        vec2 l = q - c;
        float r = length(l), R = CV_TUN * 0.85;
        if(r > R + 0.004) continue;
        float a = atan(l.y, l.x) - iTime * 22.;
        float blades = abs(sin(a * 2.5)) * R;
        col = mix(col, CV_HOLE * 0.6, S(r - R));
        col = mix(col, CV_MC * 0.45, S(max(r - blades, r - R * 0.92)) * 0.6);
        col = mix(col, CV_MC * 0.6, S(abs(r - R) - 0.0012));
        col = mix(col, CV_MC * 0.7, S(r - 0.004));
    }
    return col;
}

// streaks of air blowing back through each wind tunnel, over the moulds
vec3 cvWind(vec3 col, vec2 q){
    if(q.x < CV_WIND.x || q.x > CV_WIND.y || q.y < CVG(9.) || q.y > CVG(18.)) return col;
    float fade = smoothstep(CV_WIND.x, CV_WIND.x + 0.08, q.x) * smoothstep(CV_WIND.y, CV_WIND.y - 0.03, q.x);
    for(int li = 0; li < 3 + CVZ; li++){
        float y0 = CV_ST_Y[li] - CV_SIZE * 0.5, y1 = cvCeil(li) - 0.004;
        if(q.y < y0 - 0.004 || q.y > y1 + 0.004) continue;
        for(int k = 0; k < 7 + CVZ; k++){
            float fk = float(k + li * 7);
            float y = mix(y0, y1, (float(k) + 0.5) / 7.) + 0.003 * sin(q.x * 45. + iTime * 4. + fk * 1.7);
            float u = (q.x + iTime * (0.55 + 0.25 * cvHash(fk))) / (0.07 + 0.05 * cvHash(fk + 3.));
            float f = fract(u + cvHash(fk + 7.));
            float dash = smoothstep(0., 0.15, f) * (1. - smoothstep(0.4, 0.75, f)) * step(0.35, cvHash(floor(u) + fk * 13.));
            col += vec3(0.75, 0.9, 1.) * 0.22 * fade * dash * S(abs(q.y - y) - 0.0006);
        }
        vec2 mp = vec2((q.x + iTime * 0.7) * 180., (q.y - y0) * 180.);
        vec2 mc = floor(mp), mf = fract(mp) - 0.5;
        float mote = step(0.93, random(mc + float(li) * 9.1)) * S(length(mf) / 180. - 0.0007);
        col += vec3(0.8, 0.9, 1.) * 0.25 * fade * mote * step(q.y, y1);
    }
    return col;
}

// the heater room: three storeys of slow belt between glowing heater walls,
// steam lifting off the wet amps
vec3 cvHeater(vec3 col, vec2 q, float carve){
    if(q.x < CVG(2.) || q.x > CVG(10.) || q.y < CVG(-10.) || q.y > CVG(-2.)) return col;
    float fl = 0.85 + 0.15 * sin(iTime * 2. + q.y * 30.);
    col += vec3(1., 0.35, 0.06) * 0.14 * fl * S(carve);
    for(int s = 0; s < 2 + CVZ; s++){
        float x = s == 0 ? CVG(2.) + 0.003 : CVG(10.) - 0.003;
        col = mix(col, vec3(1.3, 0.4, 0.06) * fl, S(sdBox(q - vec2(x, CVG(-6.)), vec2(0.0016, CVG(3.8)))) * S(carve));
        col += vec3(1., 0.35, 0.06) * 0.15 * fl * exp(-abs(q.x - x) / 0.01);
    }
    for(int j = 0; j < 8 + CVZ; j++){
        float a = fract(iTime * 0.5 + float(j) / 8.);
        vec2 sc = vec2(CVG(3.) + CVG(6.) * fract(float(j) * 0.37 + iTime * 0.03), CVG(-9.5) + a * CVG(7.));
        col = mix(col, vec3(0.75), S(length(q - sc) - 0.003 - a * 0.004) * 0.1 * (1. - a) * S(carve));
    }
    return col;
}

// the stress test on the quality-control run: two plates drop beside each
// amp and squeeze it thin, then a gripper takes its head and pulls it tall
// while the belt holds its feet; a gauge by each rig reads the load
vec3 cvStress(vec3 col, vec2 q, vec4 sq, vec4 sr){
    for(int g = 0; g < 2 + CVZ; g++){
        int k = g == 0 ? CS_SQUEEZE : CS_STRETCH;
        vec4 st = g == 0 ? sq : sr;
        vec2 a = cvStPos(k);
        if(abs(q.x - a.x) > 0.06 || abs(q.y - a.y) > 0.07) continue;
        float c = cvCeil(k);
        float x = st.x >= 0. ? st.x : 0.;
        float kk = cvStressK(st);
        float drop = smoothstep(0., 0.12, x) * (1. - smoothstep(0.92, 1., x));
        float foot = a.y - CV_SIZE * 0.55;
        if(g == 0){
            float w = CV_SIZE * 0.4 / (1. + 0.6 * kk) + 0.0018;
            float py = mix(c + 0.006, a.y + 0.002, drop);
            col = cvMach(col, sdBox(q - vec2(a.x, c + 0.004), vec2(w + 0.003, 0.0018)), 0.7);
            for(int s = -1; s <= 1 + CVZ; s += 2){
                float px = a.x + float(s) * w;
                col = cvMach(col, sdBox(q - vec2(px, (py + c + 0.004) * 0.5), vec2(0.0007, (c + 0.004 - py) * 0.5)), 0.75);
                col = cvMach(col, sdBox(q - vec2(px + float(s) * 0.0008, py), vec2(0.0013, 0.0105)), 1.05);
            }
        } else {
            float top = foot + CV_SIZE * 1.1 * (1. + 0.4 * kk);
            float hy = mix(c + 0.004, top + 0.002, drop);
            col = cvMach(col, sdBox(q - vec2(a.x, (hy + c + 0.01) * 0.5), vec2(0.0016, (c + 0.01 - hy) * 0.5)), 0.75);
            col = cvMach(col, sdBox(q - vec2(a.x, hy + 0.002), vec2(0.008, 0.0022)), 1.05);
            for(int s = -1; s <= 1 + CVZ; s += 2)
                col = cvMach(col, sdSegment(q, vec2(a.x + float(s) * 0.0065, hy), vec2(a.x + float(s) * (0.0045 - 0.0015 * drop), hy - 0.006)) - 0.0008, 0.9);
            for(int s = -1; s <= 1 + CVZ; s += 2)
                col = cvMach(col, sdBox(q - vec2(a.x + float(s) * 0.0085, foot + 0.0015), vec2(0.0035, 0.0015 + 0.0008 * drop)), 0.9);
        }
        vec2 gc = vec2(a.x + CV_CELL, c + 0.0115);
        float d = length(q - gc);
        col = mix(col, vec3(0.85, 0.83, 0.75), S(d - 0.0095));
        col = mix(col, CV_MC * 0.5, S(abs(d - 0.0095) - 0.0011));
        float na = -1.4 + 2.8 * kk + 0.08 * sin(iTime * 30.) * kk;
        col = mix(col, vec3(0.85, 0.15, 0.08), S(sdSegment(q, gc, gc + vec2(sin(na), cos(na)) * 0.0078) - 0.0008));
        col = mix(col, vec3(0.1), S(d - 0.0016));
        col = mix(col, vec3(0.85, 0.15, 0.08), S(length(q - gc - vec2(0.0068, 0.006)) - 0.0016) * step(0.8, kk));
    }
    return col;
}

vec3 cvBasin(vec3 col, vec2 q, vec2 spl){
    float sp = spl.x;
    vec2 c = vec2(CVG(17.5), CVG(-13.));
    if(abs(q.x - c.x) > 0.5 || q.y < c.y - 0.07 || q.y > c.y + 0.2) return col;
    float pit = sdBox(q - c, vec2(CVG(15.5), CVG(2.)));
    float wave = 0.0015 * sin(q.x * 120. + iTime * 3.) + 0.001 * sin(q.x * 230. - iTime * 5.);
    float liquid = max(pit, q.y - CV_TANK_Y - wave);
    vec3 lc = mix(vec3(0.05, 0.12, 0.16), vec3(0.12, 0.28, 0.34), smoothstep(CVG(-15.), CV_TANK_Y, q.y));
    vec2 bc = floor(q * vec2(90., 1.));
    float rise = fract(iTime * (0.3 + 0.3 * random(bc.xx)) + random(bc.xx + 2.));
    vec2 bp = vec2((bc.x + 0.5) / 90. + 0.004 * sin(rise * 9.), mix(CVG(-15.), CV_TANK_Y, rise));
    float bub = step(0.75, random(bc.xx + 5.)) * S(length(q - bp) - 0.0016);
    col = mix(col, lc, S(liquid) * 0.85);
    col += vec3(0.4, 0.7, 0.8) * 0.3 * bub * step(liquid, 0.);
    col += vec3(0.4, 0.75, 0.85) * 0.35 * S(abs(q.y - CV_TANK_Y - wave) - 0.0008) * step(pit, 0.);
    if(sp < 1.6){
        vec2 o = vec2(spl.y, CV_TANK_Y);
        float fade = 1. - sp / 0.8;
        if(fade > 0.){
            float r = length((q - o) * vec2(1., 5.));
            col += vec3(0.6, 0.85, 0.9) * 0.4 * fade * smoothstep(0.003, 0., abs(r - 0.01 - sp * 0.07)) * step(abs(q.y - o.y), 0.01);
            for(int k = 0; k < 10 + CVZ; k++){
                float fk = float(k);
                float a = (cvHash(fk + 0.3) - 0.5) * 2.;
                vec2 v = vec2(sin(a), cos(a)) * (0.14 + 0.16 * cvHash(fk + 4.1));
                vec2 p = o + v * sp + vec2(0., -1.1) * sp * sp;
                if(p.y < o.y - 0.002) continue;
                col = mix(col, vec3(0.65, 0.85, 0.9), S(length(q - p) - 0.0018 * (1. - 0.5 * sp)) * fade);
            }
        }
        for(int k = 0; k < 5 + CVZ; k++){
            float a = sp - float(k) * 0.12;
            if(a < 0. || a > 1.4) continue;
            vec2 sc = o + vec2(0.006 * sin(a * 5. + float(k)), 0.01 + a * 0.12);
            col = mix(col, vec3(0.75), S(length(q - sc) - 0.006 - a * 0.01) * 0.25 * (1. - a / 1.4));
        }
    }
    return col;
}

// the caustic bath under the rail past the heater: a square pit of sickly
// green lye, bubbling and fuming, boiling up while a batch is dipped
vec3 cvCaustic(vec3 col, vec2 q, vec4 cs){
    vec2 c = vec2(CVG(15.), CVG(-7.)), h = vec2(CVG(4.), CVG(3.));
    if(abs(q.x - c.x) > h.x + 0.01 || q.y < c.y - h.y - 0.01 || q.y > c.y + h.y + 0.06) return col;
    float pit = sdBox(q - c, h);
    float lvl = CVG(-5.4) + 0.0012 * sin(q.x * 140. + iTime * 2.5);
    float liquid = max(pit, q.y - lvl);
    vec3 lc = mix(vec3(0.16, 0.22, 0.04), vec3(0.42, 0.52, 0.1), smoothstep(CVG(-10.), lvl, q.y));
    col = mix(col, lc, S(liquid) * 0.8);
    col += vec3(0.6, 0.75, 0.2) * 0.35 * S(abs(q.y - lvl) - 0.0008) * step(pit, 0.);
    vec2 bc = floor(q * vec2(110., 1.));
    float rise = fract(iTime * (0.4 + 0.4 * random(bc.xx)) + random(bc.xx + 2.));
    vec2 bp = vec2((bc.x + 0.5) / 110. + 0.003 * sin(rise * 9.), mix(CVG(-10.), lvl, rise));
    col += vec3(0.7, 0.85, 0.3) * 0.35 * step(0.6, random(bc.xx + 5.)) * S(length(q - bp) - 0.0016) * step(liquid, 0.);
    float u = cs.x >= 0. ? cs.x * CV_ST_DW[CS_CAUSTIC] / 3. : -1.;
    float boil = u >= 0. ? smoothstep(0.15, 0.25, u) * (1. - smoothstep(0.75, 0.85, u)) : 0.;
    if(boil > 0.){
        col += vec3(0.7, 0.85, 0.3) * 0.4 * boil * step(0.2, random(bc.xx + 9.)) * S(length(q - bp) - 0.0022) * step(liquid, 0.);
        col += vec3(0.75, 0.9, 0.35) * 0.25 * boil * S(abs(q.y - lvl) - 0.002) * step(pit, 0.);
        for(int j = 0; j < 18 + CVZ; j++){
            float fj = float(j);
            float a = fract(iTime * 2.2 + cvHash(fj + 0.4));
            vec2 o = vec2(c.x - h.x + 2. * h.x * cvHash(fj + 3.3 + floor(iTime * 2.2 + cvHash(fj + 0.4))), lvl);
            vec2 p = o + vec2((cvHash(fj + 7.) - 0.5) * 0.03 * a, 0.05 * a - 0.09 * a * a);
            col = mix(col, vec3(0.75, 0.9, 0.35), S(length(q - p) - 0.0012) * boil * (1. - a * 0.5));
        }
    }
    for(int j = 0; j < 6 + CVZ; j++){
        float a = fract(iTime * 0.35 + float(j) / 6.);
        vec2 fc = vec2(c.x - h.x + 2. * h.x * fract(float(j) * 0.41 + 0.2), lvl + 0.004 + a * 0.05);
        fc.x += 0.01 * sin(a * 5. + float(j));
        col = mix(col, vec3(0.55, 0.65, 0.3), S(length(q - fc) - 0.004 - a * 0.008) * 0.14 * (1. - a));
    }
    return col;
}

vec3 cvHangRod(vec3 col, vec2 q, vec2 top, float c){
    if(abs(q.x - top.x) > 0.008) return col;
    col = cvMach(col, sdBox(q - vec2(top.x, (top.y + c) * 0.5), vec2(0.0012, (c - top.y) * 0.5)), 0.8);
    col = cvMach(col, sdBox(q - vec2(top.x, c - 0.002), vec2(0.004, 0.002)), 0.7);
    for(int s = -1; s <= 1 + CVZ; s += 2){
        vec2 f0 = vec2(top.x + 0.003 * float(s), top.y);
        col = cvMach(col, sdSegment(q, f0, f0 + vec2(0.002 * float(s), -0.006)) - 0.0009, 0.9);
    }
    return col;
}

// the gripper arms on the rail out of the heater: one drops from the ceiling
// to take each amp off the top heater belt and runs it along to the pit;
// eight at a time dip their amps into the lye, then swing them over onto the
// centrifuge and let go
vec3 cvHangers(vec3 col, vec2 q, float asp){
    if(q.x < CVG(8.) || q.x > CVG(27.) || q.y < CVG(-10.) || q.y > CVG(-2.)) return col;
    vec4 cs = cvState(CS_CAUSTIC, CV_ROW);
    float T = cs.x >= 0. ? cs.x * CV_ST_DW[CS_CAUSTIC] : -1.;
    float c = CVG(-2.);
    col = cvMach(col, sdBox(q - vec2(CVG(14.), c - 0.001), vec2(CVG(5.), 0.001)), 0.6);
    if(q.x < CVG(19.5)){
        for(int pass = 0; pass < 2 + CVZ; pass++){
            vec4 sl[AG_TEX];
            agSlots(iChannel17, vec2(q.x, pass == 0 ? CVR(-4.) : CVR(-6.8)), asp, sl);
            for(int k = 0; k < AG_SLOTS + CVZ; k++){
                int i = int(sl[k >> 2][k & 3] + 0.5) - 1;
                if(i < 0) break;
                vec4 r0 = cvState(i, 0), r1 = cvState(i, 1);
                if(cvI(r1.x) != CT_MAIN || ((cvI(r1.w) >> CS_CAUSTIC) & 1) == 1) continue;
                vec2 p = r0.xy;
                if(p.x < CVX(9.) + 0.0005 || p.x > CVX(18.) + 0.001 || p.y < CVR(-7.)) continue;
                if(T >= 3. && cvBatchSlot(CS_CAUSTIC, r1.y) >= 0) continue;
                col = cvHangRod(col, q, p + CV_SIZE * 0.55 * vec2(-sin(r0.z), cos(r0.z)), c);
            }
        }
    }
    if(T >= 3. && T < 4.6){
        float e = smoothstep(3., 4.2, T);
        for(int r = 0; r < 8 + CVZ; r++){
            float ph = float(r) * 0.785398;
            vec2 P = mix(vec2(CV_ST_X[CS_CAUSTIC] - float(r) * CV_GAP, CVR(-4.)), CV_HUB + CV_HUBR * vec2(cos(ph), sin(ph)), e);
            float a = e * (mod(ph + 1.5708 + 3.14159, 6.28318) - 3.14159);
            vec2 top = P + CV_SIZE * 0.55 * vec2(-sin(a), cos(a));
            top.y = mix(top.y, c - 0.004, smoothstep(4.2, 4.6, T));
            col = cvHangRod(col, q, top, c);
        }
    }
    return col;
}

// the centrifuge: eight arms on a hub that take the dipped batch, whirl it
// round and fling each amp off as it points right, straight up the shaft
vec3 cvRotor(vec3 col, vec2 q, vec4 cs){
    vec2 h = CV_HUB;
    if(abs(q.x - h.x) > CVG(4.) || q.y < CVG(-10.) || q.y > CVG(-2.)) return col;
    float T = cs.x >= 0. ? cs.x * CV_ST_DW[CS_CAUSTIC] : -1.;
    float th = cvSpin(T), blur = smoothstep(8., CV_SPIN_W, cvSpinW(T));
    col = cvMach(col, sdBox(q - vec2(h.x, (h.y + CVG(-10.)) * 0.5), vec2(0.0045, (h.y - CVG(-10.)) * 0.5)), 0.55);
    col = cvMach(col, sdBox(q - vec2(h.x, CVG(-10.) + 0.0025), vec2(0.018, 0.0025)), 0.6);
    float rr = length(q - h);
    float L = (CV_HUBR - CV_SIZE * 0.55) * (T < 0. ? 0.25 : mix(0.25, 1., smoothstep(3.6, 4.2, T) * (1. - smoothstep(9.7, 10.3, T))));
    col = mix(col, CV_MC * 0.8, 0.3 * blur * S(rr - L));
    for(int r = 0; r < 8 + CVZ; r++){
        float ph = th + float(r) * 0.785398;
        vec2 dir = vec2(cos(ph), sin(ph)), nrm = vec2(-dir.y, dir.x);
        vec2 tip = h + dir * L;
        float sh = 0.95 - 0.35 * blur;
        col = cvMach(col, sdSegment(q, h, tip) - 0.0013, sh);
        float f = T >= 3.6 && T < 9.6 && th < cvRelTheta(r) ? 0.003 : 0.0045;
        col = cvMach(col, sdSegment(q, tip + nrm * f, tip + nrm * f + dir * 0.005) - 0.0008, sh);
        col = cvMach(col, sdSegment(q, tip - nrm * f, tip - nrm * f + dir * 0.005) - 0.0008, sh);
    }
    col = cvMach(col, rr - 0.0075, 1.1);
    return mix(col, vec3(0.08), S(rr - 0.0022));
}

vec3 cvPlinko(vec3 col, vec2 q){
    if(abs(q.x - CV_PLK_X) > CVG(2.5) || q.y < CVG(-11.) || q.y > CVG(16.)) return col;
    float kf = clamp(floor((CVR(15.) - 0.0132 - q.y) / CV_PLK_H + 0.5), 1., float(CV_PLK_N));
    for(int dk = -1; dk <= 1 + CVZ; dk++){
        float k = kf + float(dk);
        if(k < 1. || k > float(CV_PLK_N)) continue;
        float y = CVR(15.) - CV_PLK_H * k - 0.0107 - 0.0025;
        bool odd = mod(k, 2.) > 0.5;
        float x0 = CV_PLK_X + (odd ? 0. : CV_PLK_W);
        float j = clamp(floor((q.x - x0) / (2. * CV_PLK_W) + 0.5), odd ? -1. : -2., 1.);
        vec2 pc = vec2(x0 + j * 2. * CV_PLK_W, y);
        float dd = length(q - pc) - 0.0024;
        col = mix(col, vec3(0.02), S(dd - 0.001) * 0.4);
        col = mix(col, vec3(0.72, 0.56, 0.26), S(dd));
        col = mix(col, vec3(1., 0.92, 0.7), S(length(q - pc - vec2(-0.0007, 0.0008)) - 0.0008));
    }
    return col;
}

// the x-ray booth: a dark lead-lined cell where a beam sweeps each amp and
// shows its welds glowing through; the lamp on top gives the verdict
vec3 cvXray(vec3 col, vec2 q, vec4 st, bool front){
    vec2 c = vec2(CV_ST_X[CS_XRAY], CVG(16.));
    if(abs(q.x - c.x) > CVG(0.8) || abs(q.y - c.y) > CVG(1.)) return col;
    float on = st.x >= 0. ? smoothstep(0., 0.15, st.x) * (1. - smoothstep(0.85, 1., st.x)) : 0.;
    if(!front){
        col = mix(col, vec3(0.01, 0.025, 0.035), 0.75 * S(sdBox(q - c, vec2(CVG(0.6), CVG(1.)))));
        float yb = mix(CVG(16.8), CVG(15.1), fract(max(st.x, 0.) * 2.));
        return col + vec3(0.3, 0.85, 1.) * on * (S(abs(q.y - yb) - 0.0005) * 0.8 + 0.15 * exp(-abs(q.y - yb) / 0.004)) * S(abs(q.x - c.x) - CVG(0.55));
    }
    for(int s = -1; s <= 1 + CVZ; s += 2)
        col = cvMach(col, sdBox(q - vec2(c.x + float(s) * CVG(0.62), c.y), vec2(0.0012, CVG(1.))), 0.6);
    col = cvMach(col, sdBox(q - vec2(c.x, CVG(17.) - 0.0025), vec2(CVG(0.62), 0.0025)), 0.7);
    vec2 lp = vec2(c.x + CVG(0.35), CVG(17.) - 0.0025);
    bool lit = on > 0. || st.z < 2.;
    vec3 lc = on > 0. ? vec3(1., 0.7, 0.2) : st.w > 0.5 ? vec3(1., 0.15, 0.1) : vec3(0.2, 1., 0.35);
    lc = lit ? lc : vec3(0.15);
    col = mix(col, lc, S(length(q - lp) - 0.0016));
    return col + (lit ? lc * 0.3 * exp(-length(q - lp) / 0.004) : vec3(0.));
}

// the grinder: a wheel on a ceiling ram drops onto the seam where the P was
// welded on and grinds it flush in a fan of sparks
vec3 cvGrinder(vec3 col, vec2 q, vec4 st){
    vec2 a = cvStPos(CS_GRIND);
    if(abs(q.x - a.x) > 0.17 || abs(q.y - a.y) > 0.17) return col;
    float x = st.x >= 0. ? st.x : 0.;
    float drop = smoothstep(0., 0.15, x) * (1. - smoothstep(0.85, 1., x));
    float grind = smoothstep(0.12, 0.2, x) * (1. - smoothstep(0.8, 0.88, x));
    float rw = 0.0075, c = cvCeil(CS_GRIND);
    vec2 wc = mix(vec2(a.x + 0.004, c + 0.012), vec2(a.x + 0.004, a.y + CV_SIZE * 0.55 + rw - 0.0015), drop);
    col = cvMach(col, sdBox(q - vec2(wc.x, (wc.y + c + 0.025) * 0.5), vec2(0.0015, (c + 0.025 - wc.y) * 0.5)), 0.7);
    vec2 l = Rot(iTime * (4. + 40. * grind)) * (q - wc);
    float rr = length(q - wc), d = rr - rw;
    col = mix(col, vec3(0.02), S(d - 0.001) * 0.4);
    col = mix(col, vec3(0.42, 0.4, 0.38) * (0.85 + 0.15 * sin(atan(l.y, l.x) * 10.)), S(d));
    col = mix(col, vec3(0.65), S(abs(d + 0.0015) - 0.0004));
    col = cvMach(col, max(abs(rr - rw - 0.0022) - 0.0011, wc.y - 0.002 - q.y), 0.75);
    col = cvMach(col, rr - 0.002, 1.1);
    return cvSparks(col, q, wc - vec2(-0.002, rw), normalize(vec2(1., 0.35)), grind, 57., 0.9);
}

// the reject boot: hangs cocked back under the ceiling right of the amp,
// and when the x-ray has marked one it winds up and punts it back left, clean
// out of the factory (drawn mirrored about the station)
vec3 cvBootAt(vec3 col, vec2 q, vec2 sa, float ceil, float x, float since){
    q.x = 2. * sa.x - q.x;
    vec2 P = vec2(sa.x - CVG(0.9), ceil - 0.002);
    if(abs(q.x - P.x) > 0.065 || q.y < P.y - 0.07 || q.y > P.y + 0.006) return col;
    float a = x >= 0. ? (x < 0.75 ? mix(-1.4, -1.65, smoothstep(0., 0.7, x)) : mix(-1.65, 0.95, smoothstep(0.75, 1., x)))
                      : mix(0.95, -1.4, smoothstep(0.03, 0.6, since));
    vec2 A = P + 0.03 * vec2(sin(a), -cos(a));
    col = cvMach(col, sdBox(q - vec2(P.x, P.y + 0.001), vec2(0.004, 0.002)), 0.7);
    col = cvMach(col, sdSegment(q, P, A) - 0.0026, 0.85);
    col = cvMach(col, length(q - P) - 0.0036, 1.05);
    vec2 r = q - A, l = vec2(dot(r, vec2(cos(a), sin(a))), dot(r, vec2(-sin(a), cos(a))));
    float b = min(min(sdRoundBox(l - vec2(0., -0.004), vec2(0.0065, 0.008), 0.0025), sdRoundBox(l - vec2(0.006, -0.0145), vec2(0.0105, 0.0045), 0.004)), length(l - vec2(0.0135, -0.0135)) - 0.0062);
    float sole = sdRoundBox(l - vec2(0.0062, -0.0192), vec2(0.0128, 0.0019), 0.0015);
    col = mix(col, vec3(0.02), S(min(b, sole) - 0.0018) * 0.45);
    col = mix(col, vec3(0.42, 0.22, 0.1) * (0.85 + 0.15 * tcNoise(l * 500.)) * (0.8 + 0.25 * smoothstep(-0.02, 0.004, l.x)), S(b));
    col = mix(col, vec3(0.58, 0.34, 0.16), S(sdRoundBox(l - vec2(0., 0.0035), vec2(0.0075, 0.0018), 0.0012)));
    col = mix(col, vec3(0.08, 0.06, 0.05), S(sole));
    col = mix(col, vec3(0.08, 0.06, 0.05), S(sdRoundBox(l - vec2(-0.0035, -0.0215), vec2(0.0035, 0.0018), 0.001)));
    col = mix(col, vec3(1.), S(length((l - vec2(0.0148, -0.0112)) * vec2(1., 1.7)) - 0.0018) * 0.55);
    for(int k = 0; k < 4 + CVZ; k++){
        vec2 lc = l - vec2(0.0042, 0.0005 - 0.0028 * float(k));
        col = mix(col, vec3(0.9, 0.86, 0.76), S(min(sdSegment(lc, vec2(-0.0012, -0.0009), vec2(0.0012, 0.0009)), sdSegment(lc, vec2(-0.0012, 0.0009), vec2(0.0012, -0.0009))) - 0.00045));
    }
    return col;
}

// a punted amp: up in a big arc, then right across the screen at the
// camera, tumbling and swelling, a smear of ghosts behind it
vec3 cvKickedAt(vec3 col, vec2 q, vec2 s0, float since, float asp, float fit, bool fin){
    float T = since / 1.8;
    if(T >= 1.) return col;
    vec2 e = vec2(CV_CX - asp * 0.5 - 0.15, CV_CY - 0.5 / fit + 0.2);
    col += vec3(1., 0.85, 0.5) * exp(-since * 10.) * exp(-length(q - s0) / 0.012) * 0.9;
    float pw = 1. - smoothstep(0.08, 0.35, since);
    if(pw > 0.){
        vec2 r = q - s0 - vec2(-0.004, 0.006);
        float an = atan(r.y, r.x) + 0.3;
        float rr = (0.009 + 0.008 * smoothstep(0., 0.08, since)) * (0.5 + 0.5 * pow(abs(cos(an * 4.)), 3.));
        float d = length(r) - rr;
        col = mix(col, vec3(0.6, 0.15, 0.05), S(d - 0.0012) * pw);
        col = mix(col, vec3(1., 0.8, 0.15), S(d) * pw);
        col = mix(col, vec3(1., 1., 0.85), S(d + 0.003) * pw);
    }
    for(int k = 4; k >= 0 + CVZ; k--){
        float u = T - float(k) * 0.012;
        if(u < 0.) continue;
        vec2 p = mix(s0, e, u) + vec2(0., 1.6 * u * (1. - u));
        float sc = 1. + 9. * u * u;
        vec2 g = Rot(-u * 16.) * (q - p) / (CV_SIZE * sc);
        if(dot(g, g) > 2.) continue;
        float dd = glyphDist(g) * CV_SIZE * sc;
        float al = k == 0 ? 1. : 0.3 * (1. - float(k) / 5.);
        vec3 c = fin ? ampGradient(g) * 1.05 : mix(vec3(0.4, 0.41, 0.43), vec3(0.13, 0.12, 0.11), 0.65) * (0.8 + 0.3 * smoothstep(-0.3, 0.5, g.y));
        col = mix(col, vec3(0.01), S(dd - 0.0015 * sc) * 0.4 * al);
        col = mix(col, c, S(dd) * al);
    }
    return col;
}

// the tumbler: a big drum turning in the primer room, seen end on through
// its cut-away face; lifters carry the amps up the rising wall and drop them
// back through the grey slurry pooled in its bottom
vec3 cvDrum(vec3 col, vec2 q){
    vec2 r = q - CV_DRUM;
    float rr = length(r);
    if(rr > CV_DRUMR + 0.01) return col;
    float rot = iTime * CV_DRUM_W, inner = rr - CV_DRUMR;
    col = mix(col, vec3(0.045, 0.045, 0.05), S(inner));
    vec2 rs = Rot(0.35) * r;
    float lvl = -CVG(1.6) + 0.0012 * sin(rs.x * 160. - iTime * 4.);
    vec3 sc = vec3(0.82, 0.82, 0.8) * (0.85 + 0.2 * tcNoise(q * 90. + vec2(iTime * 0.5, 0.)));
    col = mix(col, sc, S(max(inner, rs.y - lvl)));
    col += vec3(0.6) * 0.25 * S(abs(rs.y - lvl) - 0.0006) * S(inner);
    for(int k = 0; k < 6 + CVZ; k++){
        float a = rot + float(k) * 1.0472, an = mod(a + 3.14159, 6.28318) - 3.14159;
        float load = smoothstep(-2.3, -1.7, an) * (1. - smoothstep(-0.3, 0.9, an));
        if(load <= 0.) continue;
        vec2 dir = vec2(cos(a), sin(a)), td = vec2(-dir.y, dir.x);
        vec2 p0 = CV_DRUM + dir * (CV_DRUMR - CVG(0.6));
        float along = clamp(dot(q - p0, dir) / CVG(0.6), 0., 1.);
        float heap = max(max(sdSegment(q, p0, CV_DRUM + dir * CV_DRUMR) - 0.008 * load * (0.35 + 0.65 * along), -dot(q - p0, td)), inner);
        col = mix(col, sc * 0.92, S(heap));
        float pour = smoothstep(-0.5, -0.1, an) * (1. - smoothstep(0.6, 1., an));
        if(pour <= 0.) continue;
        vec2 tip = p0 + td * 0.004;
        float py = CV_DRUM.y - CVG(1.6);
        if(tip.y <= py) continue;
        col = mix(col, sc, S(sdSegment(q, tip, vec2(tip.x - 0.003, py)) - 0.001 * pour) * 0.6 * pour);
        for(int n = 0; n < 6 + CVZ; n++){
            float u = fract(iTime * 2.3 + float(n) / 6. + float(k) * 0.13);
            col = mix(col, sc, S(length(q - tip - vec2(-0.003 * u, -(tip.y - py) * u * u)) - 0.0017) * pour);
        }
    }
    for(int k = 0; k < 6 + CVZ; k++){
        vec2 dir = vec2(cos(rot + float(k) * 1.0472), sin(rot + float(k) * 1.0472));
        col = cvMach(col, sdSegment(q, CV_DRUM + dir * (CV_DRUMR - CVG(0.6)), CV_DRUM + dir * CV_DRUMR) - 0.002, 0.75);
    }
    col = cvMach(col, abs(inner - 0.002) - 0.0025, 0.9);
    for(int k = 0; k < 12 + CVZ; k++){
        float a = rot + float(k) * 0.5236;
        col = mix(col, CV_MC * 1.3, S(length(r - (CV_DRUMR + 0.002) * vec2(cos(a), sin(a))) - 0.001));
    }
    return col;
}

vec3 cvFlickArm(vec3 col, vec2 q, vec4 st){
    if(q.x < CVG(16.) || q.x > CVG(27.) || q.y < CVG(6.) || q.y > CVG(14.)) return col;
    vec2 P = CV_FLK_P, rest = P + vec2(0.006, -0.014), away = P + vec2(-0.03, -0.012), tip = rest;
    bool hold = false;
    if(st.x >= 0.){
        vec4 r0 = cvState(cvI(st.y), 0);
        vec2 top = r0.xy + CV_SIZE * 0.55 * vec2(-sin(r0.z), cos(r0.z));
        if(st.x < 0.55){
            tip = mix(rest, top, smoothstep(0., 0.28, st.x));
            hold = st.x > 0.28;
        } else {
            tip = mix(top, away, smoothstep(0.55, 0.68, st.x));
            hold = st.x < 0.57;
        }
    } else tip = mix(away, rest, smoothstep(0., 0.6, st.z));
    vec2 dv = tip - P;
    float L = max(length(dv), 1e-4);
    vec2 dir = dv / L, nrm = vec2(-dir.y, dir.x);
    col = cvMach(col, sdSegment(q, P, P + dir * min(L, 0.022)) - 0.003, 0.7);
    col = cvMach(col, sdSegment(q, P, tip) - 0.0014, 0.95);
    float f = hold ? 0.0028 : 0.0045;
    for(int s = -1; s <= 1 + CVZ; s += 2)
        col = cvMach(col, sdSegment(q, tip + nrm * float(s) * f, tip + nrm * float(s) * f + dir * 0.005) - 0.0008, 0.95);
    col = cvMach(col, length(q - P) - 0.004, 1.1);
    return col;
}

// the drip rack after the drum: rollers with gaps under the wet amps, white
// slurry dripping off them into a tray on the floor, less as they dry
vec3 cvDripBack(vec3 col, vec2 q){
    if(q.x < CVG(8.) || q.x > CVG(21.) || q.y < CVG(6.) || q.y > CVG(7.5)) return col;
    float ty = CVG(6.6) + 0.0007 * sin(q.x * 300. + iTime * 3.);
    float pool = max(sdBox(q - vec2(CVG(13.5), CVG(6.3)), vec2(CVG(5.5), CVG(0.3))), q.y - ty);
    col = mix(col, vec3(0.82, 0.82, 0.8) * (0.85 + 0.15 * smoothstep(CVG(6.), ty, q.y)) * (0.92 + 0.08 * tcNoise(q * 120.)), S(pool));
    col += vec3(0.25) * S(abs(q.y - ty) - 0.0006) * step(pool, 0.002);
    float by = CVR(7.) - CV_SIZE * 0.5 - 0.002;
    if(q.x > CVG(19.)) return col;
    float rx = (fract(q.x / CVG(0.5)) - 0.5) * CVG(0.5);
    vec2 rp = vec2(rx, q.y - by);
    float rr = length(rp) - 0.0024;
    col = mix(col, vec3(0.02), S(rr - 0.0008) * 0.4);
    col = mix(col, CV_MC * (0.7 + 0.3 * step(0., sin(atan(rp.y, rp.x) * 3. + iTime * CV_DRIP_V / 0.0024))), S(rr));
    return col;
}

vec3 cvDripFront(vec3 col, vec2 q, float asp){
    if(q.x < CVG(8.5) || q.x > CVG(21.) || q.y < CVG(6.) || q.y > CVG(8.)) return col;
    vec4 sl[AG_TEX];
    agSlots(iChannel17, vec2(q.x, CVR(7.)), asp, sl);
    float ty = CVG(6.6);
    for(int k = 0; k < AG_SLOTS + CVZ; k++){
        int i = int(sl[k >> 2][k & 3] + 0.5) - 1;
        if(i < 0) break;
        vec4 r0 = cvState(i, 0), r1 = cvState(i, 1);
        if(cvI(r1.x) != CT_MAIN || abs(r0.y - CVR(7.)) > 0.002 || r0.x < CVG(9.) || r0.x > CVG(20.)) continue;
        float wet = 1. - clamp((r0.x - CVG(9.5)) / CVG(10.5), 0., 1.);
        for(int j = 0; j < 3 + CVZ; j++){
            float fj = float(j) + float(i) * 3.7;
            float u = fract(iTime * (0.9 + 0.5 * cvHash(fj)) + cvHash(fj + 2.));
            if(cvHash(fj + floor(iTime * (0.9 + 0.5 * cvHash(fj)) + cvHash(fj + 2.)) * 1.3) > wet) continue;
            vec2 o = vec2(r0.x + (cvHash(fj + 5.) - 0.5) * 0.012, r0.y - CV_SIZE * 0.45);
            if(o.x > CVG(19.) - 0.0015) continue;
            vec2 p = vec2(o.x, mix(o.y, ty, u * u));
            col = mix(col, vec3(0.88, 0.88, 0.86), S(sdSegment(q, p, p + vec2(0., 0.0025 * u)) - 0.0011));
        }
    }
    return col;
}

// the splat on the primer room's left wall where the flick arm throws the
// amps: a white blot with runs down the rock, fresh spray on every hit
vec3 cvSplat(vec3 col, vec2 q, vec4 st){
    vec2 w = vec2(CVG(8.), CVG(10.5));
    if(abs(q.x - w.x) > 0.04 || abs(q.y - w.y) > 0.06) return col;
    vec2 r = q - w;
    float an = atan(r.y, r.x);
    float blot = length(r * vec2(1.4, 1.)) - 0.011 * (0.75 + 0.45 * tcNoise(vec2(an * 2.5, 3.1)));
    float runs = 1e9;
    for(int k = 0; k < 4 + CVZ; k++){
        float x = w.x - 0.0015 - 0.0035 * float(k);
        float len = 0.012 + 0.018 * cvHash(float(k) * 7.3);
        runs = min(runs, sdSegment(q, vec2(x, w.y - 0.004), vec2(x, w.y - len)) - 0.0012 * (1. - 0.4 * float(k & 1)));
    }
    float d = max(min(blot, runs), q.x - w.x - 0.0008);
    col = mix(col, vec3(0.86, 0.86, 0.84) * (0.92 + 0.1 * tcNoise(q * 300.)), S(d));
    if(st.x >= 0.){
        float t = (st.x - 0.829) * CV_ST_DW[CS_FLICK];
        if(t > 0. && t < 0.5){
            for(int k = 0; k < 10 + CVZ; k++){
                float fk = float(k);
                vec2 v = vec2(0.15 + 0.25 * cvHash(fk + 1.), (cvHash(fk + 2.) - 0.3) * 0.5);
                vec2 p = w + vec2(0.004, 0.) + v * t + vec2(0., -1.5) * t * t;
                col = mix(col, vec3(0.9), S(length(q - p) - 0.0014) * (1. - t * 2.));
            }
        }
    }
    return col;
}

vec3 cvMelt(vec3 col, vec2 q){
    float d = max(length(q - CV_MELT) - 0.024, q.y - CV_MELT.y - 0.008);
    if(d > 0.04) return col;
    float fl = 0.85 + 0.15 * tcNoise(vec2(iTime * 4., 8.));
    col += vec3(1., 0.33, 0.06) * 0.1 * fl * exp(-max(d, 0.) / 0.015);
    col = mix(col, vec3(0.02), S(d - 0.0015));
    return mix(col, cvLava(q * 0.9 + 5., 0.9) * fl, S(d));
}

// a head hanging in the ceiling shaft (h tall) of station k: `drop` 0 up in
// it, 1 down on `bot`
vec3 cvHead(vec3 col, vec2 q, int k, float drop, vec2 size, float shade, float h, float bot){
    size *= CV_K; h *= CV_K;
    float top = cvCeil(k) + h - 0.004;
    float y = mix(top - size.y, bot + size.y, drop);
    float x = CV_ST_X[k];
    col = cvMach(col, sdBox(q - vec2(x, (top + y) * 0.5), vec2(0.0025 * CV_K, max((top - y) * 0.5, 0.))), 0.8);
    return cvMach(col, sdRoundBox(q - vec2(x, y), size, 0.002), shade);
}

vec3 cvHammer(vec3 col, vec2 q, int k, vec4 st, vec4 jam){
    vec2 sp = cvStPos(k);
    if(abs(q.x - sp.x) > 0.05 || q.y < sp.y - 0.03 || q.y > sp.y + 0.07) return col;
    int li = k - 3, kind = li == 0 ? 1 : li == 1 ? 0 : 2;
    bool jammed = jam.x == float(k) && jam.y < CV_FIX_AT;
    float p = st.x >= 0. && !jammed ? st.x : 0.;
    float fall = p < CV_HIT ? pow(p / CV_HIT, 2.2) : 1. - smoothstep(CV_HIT + 0.08, 0.95, p);
    float top = sp.y + (CV_MCEN[kind].y + CV_MHALF[kind].y) * CV_SIZE;
    col = cvHead(col, q, k, fall, vec2(0.015, 0.006), 1., li == 1 ? 0.03 : 0.02, top);
    float since = (p - CV_HIT) * CV_ST_DW[k];
    if(p > CV_HIT && since < 0.25) col += vec3(1., 0.85, 0.6) * 0.5 * exp(-since * 25.) * exp(-length(q - vec2(sp.x, top)) / 0.01);
    return col;
}

vec3 cvArm(vec3 col, vec2 q, int a, vec4 st){
    vec2 b = CV_ARMB[a], j = CV_JOIN[a], pk = CV_PICK[a];
    vec2 lo = min(min(b, j), pk) - 0.06, hi = max(max(b, j), pk) + 0.06;
    if(any(lessThan(q, lo)) || any(greaterThan(q, hi))) return col;
    bool busy = st.x >= 0. && st.w >= 0.;
    float ph = busy ? st.x : 0.;
    vec2 tip = cvArmTip(a, ph, busy);
    float L = CV_ARML[a];
    vec2 v = tip - b;
    float l = min(length(v), 2. * L - 1e-3);
    float an = atan(v.y, v.x), al = acos(clamp(l / (2. * L), -1., 1.)) * (a == 0 ? -1. : 1.);
    vec2 el = b + L * vec2(cos(an + al), sin(an + al));
    float mount = a == 0 ? -1. : 1.;
    if(a == 0) col = cvMach(col, sdBox(q - vec2(b.x, (b.y + CVG(CV_WELDROOM.y)) * 0.5), vec2(0.0045, (b.y - CVG(CV_WELDROOM.y)) * 0.5)), 0.7);
    col = cvMach(col, sdRoundBox(q - b - vec2(0., 0.006 * mount), vec2(0.018, 0.007) * CV_K, 0.003), 0.8);
    col = cvMach(col, sdSegment(q, b, el) - 0.0045 * CV_K, 1.);
    col = cvMach(col, sdSegment(q, el, tip) - 0.0035 * CV_K, 1.);
    col = cvMach(col, length(q - b) - 0.0065 * CV_K, 0.7);
    col = cvMach(col, length(q - el) - 0.005 * CV_K, 0.7);
    float open = busy && ph > 0.06 && ph < 0.42 ? 0.3 : 1.;
    for(int s = -1; s <= 1 + CVZ; s += 2){
        vec2 f0 = tip + vec2(0.004 * float(s), 0.) * CV_K;
        vec2 f1 = f0 + Rot(float(s) * -0.4 * open) * vec2(0.0025 * float(s), -0.009) * CV_K;
        col = cvMach(col, sdSegment(q, f0, f1) - 0.0014 * CV_K, 0.8);
    }
    float weld = busy ? smoothstep(0.42, 0.45, ph) * (1. - smoothstep(0.75, 0.78, ph)) : 0.;
    vec2 seam = j + CV_SEAM[a] * CV_SIZE;
    if(weld > 0.){
        float fl = 0.6 + 0.4 * random(vec2(floor(iTime * 30.), 2. + float(a)));
        col += vec3(0.7, 0.9, 1.2) * weld * fl * (S(length(q - seam) - 0.0035) + 0.5 * exp(-length(q - seam) / 0.013));
        col = cvSparks(col, q, seam, vec2(0., 1.), weld, 91. + float(a) * 13., 2.6);
    }
    return col;
}

// ---- the paint hall: four booths, each a gilded alcove with a turntable
// spinning the amp under a spotlight while two gold arms spray it ----------
const vec3 CV_GOLD = vec3(0.72, 0.56, 0.24);

vec3 cvMistColour(int k){
    return k == CS_PRIME ? vec3(0.78) : k == CS_PRIME + 1 ? GRAD_BOT : k == CS_PRIME + 2 ? GRAD_TOP : vec3(0.45, 0.25, 0.11);
}

float cvBoothOn(vec4 st){ return st.x >= 0. ? smoothstep(0., 0.08, st.x) * (1. - smoothstep(0.88, 1., st.x)) : 0.; }

vec3 cvBoothBack(vec3 col, vec2 q, int k, vec4 st){
    vec2 sp = cvStPos(k);
    float fl = sp.y - CV_ROWOFF;
    if(abs(q.x - sp.x) > CVG(2.) || q.y < fl - 0.01 || q.y > fl + CVG(6.)) return col;
    float panel = sdBox(q - vec2(sp.x, fl + CVG(3.)), vec2(CVG(2.), CVG(3.)));
    col = mix(col, CV_HOLE * 1.6, S(panel));
    return col + cvMistColour(k) * (0.08 + 0.25 * cvBoothOn(st)) * exp(-length((q - sp) * vec2(0.8, 1.)) / 0.035) * S(panel);
}

vec3 cvCatapult(vec3 col, vec2 q, float x){
    if(abs(q.x - CVG(17.5)) > CVG(2.5) || q.y > CVG(2.) || q.y < CVG(-1.) - 0.01) return col;
    float th = x >= 0. ? cvCatAng(x) : 0.;
    vec2 tip = cvCatCup(th), tg = vec2(cos(th), sin(th)), n = vec2(-tg.y, tg.x);
    col = mix(col, CV_GOLD * 0.85, S(sdSegment(q, CV_CATH + n * 0.0012, tip + n * 0.0012) - 0.0016));
    vec2 lq = vec2(dot(q - tip, tg), dot(q - tip, n));
    col = mix(col, CV_GOLD, S(max(abs(length(lq - vec2(0., 0.009)) - 0.009) - 0.0011, lq.y - 0.004)));
    return cvMach(col, length(q - CV_CATH - vec2(0., 0.003)) - 0.0035, 1.);
}

vec3 cvCoatRing(vec3 col, vec2 q, float x){
    vec2 sp = CV_PA;
    float fl = CVG(-1.), top = fl + CVG(5.3);
    if(abs(q.x - sp.x) > CVG(2.3) || q.y < fl || q.y > fl + CVG(6.)) return col;
    float y = top, on = 0.;
    if(x >= 0.){
        float yl = sp.y + (0.6 - 1.25 * cvCoatP(CS_PRIME + 1, x)) * CV_SIZE + 0.004;
        y = x < 0.08 ? mix(top, yl, smoothstep(0., 0.08, x)) : x < 0.5 ? yl : mix(yl, top, smoothstep(0.5, 0.6, x));
        on = smoothstep(0.07, 0.1, x) * (1. - smoothstep(0.47, 0.5, x));
    }
    vec2 v = q - vec2(sp.x, y);
    float sheet = step(abs(v.x), CVG(1.6)) * smoothstep(-CVG(0.8), 0., v.y) * step(v.y, 0.);
    col = mix(col, GRAD_BOT * 1.15, sheet * on * (0.2 + 0.25 * tcNoise(vec2(v.x * 400., v.y * 60. + iTime * 25.))));
    float bar = sdBox(v - vec2(0., 0.0055), vec2(CVG(2.), 0.0055));
    col = mix(col, vec3(0.01), S(bar - 0.0015) * 0.4);
    col = mix(col, CV_GOLD * (0.75 + 0.35 * smoothstep(0., 0.011, v.y)), S(bar));
    col = mix(col, CV_MC * 0.5, S(sdBox(v - vec2(0., 0.0012), vec2(CVG(1.7), 0.0012))));
    for(int s = -1; s <= 1 + CVZ; s += 2) col = cvMach(col, sdBox(v - vec2(float(s) * CVG(1.85), 0.0055), vec2(CVG(0.15), 0.009)), 0.8);
    return col;
}

vec3 cvTiltTable(vec3 col, vec2 q, float x){
    if(abs(q.x - CV_TABLE.x) > CVG(2.2) || q.y > CV_TABLE.y + CVG(1.) || q.y < CVG(-1.) - 0.01) return col;
    float tl = x >= 0. ? cvTilt(x) : 0., fl = CVG(-1.);
    col = cvMach(col, sdBox(q - vec2(CV_TABLE.x, fl + 0.002), vec2(0.009, 0.002)), 0.7);
    col = cvMach(col, sdBox(q - vec2(CV_TABLE.x, (fl + CV_TABLE.y) * 0.5 - 0.003), vec2(0.0028, (CV_TABLE.y - fl) * 0.5 - 0.003)), 0.85);
    col = mix(col, CV_GOLD * 0.8, S(sdBox(q - vec2(CV_TABLE.x, fl + CVG(1.2)), vec2(0.0034, 0.0012))));
    vec2 lq = Rot(tl) * (q - CV_TABLE);
    float top = sdBox(lq - vec2(0., -0.0028), vec2(CV_TABLEW, 0.0028));
    col = mix(col, vec3(0.01), S(top - 0.0015) * 0.4);
    col = mix(col, vec3(0.11, 0.08, 0.06) * (0.85 + 0.15 * sin(lq.x * 900.)), S(top));
    col = mix(col, vec3(0.08, 0.22, 0.14), S(sdBox(lq - vec2(0., -0.0005), vec2(CV_TABLEW - 0.0015, 0.0005))));
    col = mix(col, CV_GOLD, S(abs(top) - 0.0006));
    col = cvMach(col, length(q - CV_TABLE + vec2(0., 0.004)) - 0.0026, 1.15);
    return col;
}

vec3 cvPlotter(vec3 col, vec2 q, float x){
    vec2 sp = CV_PB;
    float park = CVG(4.3), w = CVG(0.7);
    if(abs(q.x - sp.x) > CVG(2.3) || q.y > CVG(5.) || q.y < sp.y - CVG(1.)) return col;
    float p = x >= 0. ? cvCoatP(CS_PRIME + 2, x) : 1.;
    float yl = sp.y + (0.6 - 1.25 * p) * CV_SIZE + CVG(0.85);
    float y = x < 0. ? park : x < 0.1 ? mix(park, yl, smoothstep(0., 0.1, x)) : x < 0.65 ? yl : mix(yl, park, smoothstep(0.65, 0.78, x));
    float cx = sp.x + w * (2. * abs(fract(p * 3.5) - 0.5) * 2. - 1.);
    if(x >= 0. && x < 0.1) cx = mix(sp.x - w, sp.x + w, smoothstep(0., 0.1, x));
    float on = x >= 0. ? smoothstep(0.09, 0.11, x) * (1. - smoothstep(0.63, 0.66, x)) : 0.;
    vec3 mc = mix(GRAD_TOP, GRAD_BOT, p) * 1.25;
    col = mix(col, CV_GOLD, S(sdBox(q - vec2(sp.x, y), vec2(CVG(2.), 0.0009))));
    vec2 tip = vec2(cx, y - CVG(0.72));
    col = mix(col, CV_GOLD * 1.1, S(sdSegment(q, vec2(cx, y), tip) - 0.0006));
    col += mc * on * 0.9 * exp(-length(q - tip) / 0.0015);
    return col;
}

vec2 cvGoopShake(float x){
    return x > CV_GOOP_FIRE ? 0.007 * exp(-(x - CV_GOOP_FIRE) * CV_ST_DW[CS_CLEAR] * 8.) * vec2(sin(iTime * 93.), cos(iTime * 71.)) : vec2(0.);
}

vec3 cvGoopStains(vec3 col, vec2 q, float x){
    if(x < CV_GOOP_HIT || q.x < CVG(6.) || q.x > CVG(10.) || q.y > CVG(5.) || q.y < CVG(-1.) - 0.01) return col;
    float a = smoothstep(CV_GOOP_HIT, CV_GOOP_HIT + 0.02, x) * (1. - smoothstep(0.75, 1., x));
    float tt = (x - CV_GOOP_HIT) * CV_ST_DW[CS_CLEAR];
    vec2 imp = cvGoopImpact();
    for(int j = 0; j < 14 + CVZ; j++){
        float fj = float(j), h = cvHash(fj * 3.1 + 0.4);
        vec2 c = imp + vec2(-h * h * CVG(5.), (cvHash(fj * 5.7 + 1.9) - 0.35) * CVG(3.4) * (0.4 + h));
        float r = (0.002 + 0.006 * cvHash(fj + 7.3) * (1. - 0.6 * h)) * smoothstep(0., 0.03 + 0.1 * h, tt);
        float dl = min(tt * 0.016 * cvHash(fj + 2.2), 0.016);
        float d = min(length((q - c) * vec2(0.8 + 0.6 * h, 1.2)) - r + 0.0018 * tcNoise((q - c) * 900.), sdSegment(q, c, c - vec2(0., dl)) - r * 0.25);
        col = mix(col, vec3(0.3, 0.17, 0.08) * (0.8 + 0.3 * tcNoise(q * 500.)), S(d) * a * 0.92);
    }
    vec2 pd = q - vec2(CV_PC.x - CVG(0.3), CVG(-1.) + 0.0006);
    col = mix(col, vec3(0.26, 0.15, 0.07), S(length(pd * vec2(0.8, 5.)) - CVG(1.) * smoothstep(0., 0.3, tt)) * a);
    vec2 sc = q - cvGunMuzzle(CV_GOOP_FIRE);
    col *= 1. - 0.5 * a * exp(-length(sc * vec2(0.7, 1.)) / 0.02);
    return col;
}

vec3 cvGoopCannon(vec3 col, vec2 q, float x){
    float fl = CVG(-1.);
    if(q.x < CVG(1.) || q.x > CVG(13.1) || q.y < fl - 0.01 || q.y > CVG(4.6)) return col;
    vec2 u = cvGunU(), n = vec2(-u.y, u.x);
    float rec = cvGunRecoil(x);
    vec2 qj = q;
    float bed = cvTrapezoid(qj - vec2(CV_GUN_T.x + CVG(0.2), (fl + CV_GUN_T.y) * 0.5 - 0.002), CVG(1.1), CVG(0.6), (CV_GUN_T.y - fl) * 0.5 - 0.002);
    col = mix(col, vec3(0.01), S(bed - 0.002) * 0.5);
    col = mix(col, vec3(0.42, 0.4, 0.38) * (0.8 + 0.3 * smoothstep(fl, CV_GUN_T.y, qj.y)), S(bed));
    col = mix(col, vec3(0.25, 0.24, 0.23), S(abs(bed) - 0.0007));
    vec2 b0 = CV_GUN_T + u * rec;
    vec2 v = qj - b0, lv = vec2(dot(v, u), dot(v, n));
    float body = length(lv - vec2(CVG(0.05), 0.)) - CVG(0.62);
    body = min(body, max(abs(lv.y) - CVG(0.5), max(-CV_GUN_LM + CVG(0.3) - lv.x, lv.x - CVG(0.1))));
    body = min(body, max(abs(lv.y) - mix(CVG(0.85), CVG(0.5), clamp((lv.x + CV_GUN_LM) / CVG(0.4), 0., 1.)), max(-CV_GUN_LM - lv.x, lv.x + CV_GUN_LM - CVG(0.4))));
    body = min(body, length(lv - vec2(CV_GUN_LB + CVG(0.2), 0.)) - CVG(0.18));
    vec3 brz = vec3(0.78, 0.52, 0.24);
    col = mix(col, vec3(0.01), S(body - 0.0025) * 0.55);
    col = mix(col, brz * (0.65 + 0.6 * smoothstep(-CVG(0.6), CVG(0.6), lv.y + CVG(0.2))) + vec3(1., 0.9, 0.7) * 0.35 * exp(-abs(lv.y - CVG(0.3)) / 0.002), S(body));
    for(int j = 0; j < 2 + CVZ; j++){
        float bx = j == 0 ? -CV_GUN_LM + CVG(0.42) : CVG(0.1);
        col = mix(col, brz * 0.55, S(max(abs(lv.x - bx) - 0.0016, abs(lv.y) - CVG(j == 0 ? 0.52 : 0.62))));
    }
    col = mix(col, vec3(0.04, 0.03, 0.02), S(max(abs(lv.x + CV_GUN_LM) - 0.0018, abs(lv.y) - CVG(0.66))));
    col = mix(col, vec3(0.26, 0.14, 0.05), S(max(abs(lv.x + CV_GUN_LM) - 0.001, abs(lv.y) - CVG(0.56))));
    col = mix(col, brz * 1.2, S(length(qj - CV_GUN_T) - 0.0045));
    col = mix(col, brz * 0.5, S(length(qj - CV_GUN_T) - 0.002));
    if(x < CV_GOOP_FIRE) return col;

    float tf = (x - CV_GOOP_FIRE) * CV_ST_DW[CS_CLEAR];
    vec2 m0 = cvGunMuzzle(CV_GOOP_FIRE), dir = -u, imp = cvGoopImpact();
    vec2 mv = q - m0;
    float along = dot(mv, dir), side = dot(mv, n);
    for(int j = 0; j < 8 + CVZ; j++){
        float fj = float(j), h = cvHash(fj * 1.9 + 0.3);
        vec2 c = m0 + dir * (0.006 + 0.035 * h) * (1. - exp(-tf * 5.)) + n * (cvHash(fj + 4.4) - 0.4) * 0.03 * (1. - exp(-tf * 3.)) + vec2(0., 0.012 * tf);
        float rr = 0.004 + 0.018 * (1. - exp(-tf * 3.)) * (0.5 + h);
        float sm = smoothstep(0., -rr, length(q - c) - rr + 0.004 * tcNoise((q - c) * 300. + fj));
        col = mix(col, vec3(0.17, 0.14, 0.11), sm * 0.75 * exp(-tf * 1.3));
    }
    float fe = exp(-tf * 16.);
    float cone = step(0., along) * smoothstep(0.75, 0.15, abs(side) / max(along, 1e-4)) * exp(-along / 0.035);
    col += vec3(1., 0.78, 0.4) * fe * (2.5 * exp(-length(mv) / 0.008) + 1.6 * cone);
    col += vec3(1.) * fe * 1.5 * exp(-length(mv) / 0.003);
    float rad = 0.22 * pow(tf, 0.65);
    col += vec3(1., 0.9, 0.7) * 0.7 * exp(-abs(length(mv) - rad) / 0.0016) * exp(-tf * 7.);
    if(x < CV_GOOP_HIT){
        float k = (x - CV_GOOP_FIRE) / (CV_GOOP_HIT - CV_GOOP_FIRE);
        vec2 c = mix(m0, imp, k), sv = q - c;
        float slug = length(vec2(dot(sv, dir) * 0.6, dot(sv, n) * 0.9)) - CVG(0.5);
        col = mix(col, cvGoop(sv * 60., 5.), S(slug));
        col = mix(col, vec3(0.3, 0.17, 0.08), S(sdSegment(q, c, m0) - CVG(0.12) * (1. - k)) * 0.8);
        return col;
    }
    float th = (x - CV_GOOP_HIT) * CV_ST_DW[CS_CLEAR];
    vec2 iv = q - imp;
    col += vec3(1., 0.75, 0.45) * exp(-th * 14.) * 2.2 * exp(-length(iv) / 0.012);
    float br = 0.006 + 0.035 * (1. - exp(-th * 12.));
    float burst = length(iv) - br + 0.01 * (tcNoise(iv * 200. + 7.) - 0.5) * (1. + 4. * th);
    col = mix(col, cvGoop(iv * 60., 9.), S(burst) * (1. - smoothstep(0.05, 0.3, th)) * 0.9);
    if(th < 0.9){
        for(int j = 0; j < 30 + CVZ; j++){
            float fj = float(j), h = cvHash(fj * 2.3 + 0.7);
            float a = atan(dir.y, dir.x) + (h - 0.5) * (j < 22 ? 2.6 : 6.28);
            float sp = 0.25 + 0.5 * cvHash(fj * 4.1 + 2.3);
            vec2 p = imp + sp * th * vec2(cos(a), sin(a)) - vec2(0., 0.9 * th * th);
            float rr = (0.0014 + 0.003 * cvHash(fj + 9.1)) * (1. - th / 0.9);
            col = mix(col, vec3(0.33, 0.18, 0.08), S(length((q - p) * vec2(1., 1.3)) - rr));
        }
        for(int j = 0; j < 12 + CVZ; j++){
            float fj = float(j), a = cvHash(fj * 7.7 + 1.1) * 6.28318, sp = 0.6 + 0.6 * cvHash(fj * 3.3);
            vec2 vel = sp * vec2(cos(a), sin(a)) - vec2(0., 1.5 * th);
            vec2 p = imp + sp * th * vec2(cos(a), sin(a)) - vec2(0., 0.75 * th * th);
            col += vec3(1., 0.6, 0.2) * exp(-th * 9.) * S(sdSegment(q, p, p - vel * 0.012) - 0.0005);
        }
    }
    float dummy = 0.;
    for(int j = 1; j < 9 + CVZ; j++){
        float xs = x - float(j) * 0.015;
        if(xs < CV_GOOP_HIT || xs > 0.85) continue;
        vec2 p = cvPaintPos(CS_CLEAR, xs, dummy) + (vec2(cvHash(float(j) + floor(x * 40.)), cvHash(float(j) * 1.7)) - 0.5) * 0.006;
        col = mix(col, vec3(0.32, 0.18, 0.08), S(length(q - p) - 0.003 * (1. - float(j) / 9.)));
    }
    return col;
}


vec3 cvAirbrush(vec3 col, vec2 q, int k, vec4 st){
    vec2 sp = cvStPos(k);
    if(abs(q.x - sp.x) > 0.05 || q.y < sp.y - 0.03 || q.y > sp.y + 0.045) return col;
    float c = cvCeil(k);
    vec2 tip = vec2(sp.x, c - 0.004);
    col = cvMach(col, sdBox(q - vec2(sp.x, c + 0.003), vec2(0.0055, 0.006) * CV_K), 0.9);
    col = cvMach(col, cvTrapezoid(q - tip - vec2(0., 0.0015), 0.0015 * CV_K, 0.0035 * CV_K, 0.0025 * CV_K), 1.1);
    if(st.x < 0.) return col;
    vec3 mist = k == CS_PRIME ? vec3(0.7) : k == CS_PRIME + 1 ? GRAD_BOT : k == CS_PRIME + 2 ? GRAD_TOP : vec3(0.9, 0.95, 1.);
    vec2 v = q - tip;
    float on = smoothstep(0., 0.08, st.x) * (1. - smoothstep(0.85, 1., st.x));
    float cone = step(v.y, 0.) * smoothstep(0.65, 0.4, abs(v.x) / max(-v.y, 1e-3)) * smoothstep(-0.032, -0.004, v.y);
    float grain = tcNoise(v * 300. + vec2(0., iTime * 30.));
    col = mix(col, mist, cone * on * (0.18 + 0.25 * grain));
    for(int j = 0; j < 8 + CVZ; j++){
        float fj = float(j);
        float a = fract(iTime * 1.6 + cvHash(fj + float(k)));
        vec2 p = tip + vec2((cvHash(fj + 1.7) - 0.5) * 0.04 * a, -0.03 * a);
        col = mix(col, mist, S(length(q - p) - 0.0012) * on * (1. - a));
    }
    return col;
}

// the polishing shrine after the goop booth: crimson velvet in a gold arch,
// a spotlight fades up, two cloth wheels on gold arms swing in from the
// sides and buff the goop away, then withdraw and the amp is unveiled in a
// flash of sparkles
float cvPolishOn(vec4 st){ return st.x >= 0. ? smoothstep(0., 0.12, st.x) * (1. - smoothstep(0.88, 1., st.x)) : 0.; }

vec3 cvPolishBack(vec3 col, vec2 q, vec4 st){
    vec2 sp = cvStPos(CS_POLISH);
    float fl = sp.y - CV_ROWOFF;
    if(abs(q.x - sp.x) > CVG(3.) || q.y < fl - 0.01 || q.y > fl + CVG(6.)) return col;
    float on = cvPolishOn(st);
    float room = sdBox(q - vec2(sp.x, fl + CVG(3.)), vec2(CVG(3.), CVG(3.)));
    float arch = max(sdBox(q - vec2(sp.x, fl + CVG(3.)), vec2(CVG(2.4), CVG(3.))), length((q - vec2(sp.x, fl + CVG(3.4))) * vec2(1., 1.2)) - CVG(2.4) - (q.y < fl + CVG(3.4) ? 1. : 0.));
    float fold = 0.75 + 0.25 * sin((q.x - sp.x) * 900. + 0.6 * sin(q.y * 200.));
    vec3 vel = vec3(0.3, 0.035, 0.06) * fold;
    float beam = smoothstep(0.5, 0.15, abs(q.x - sp.x) / max(fl + CVG(5.4) - q.y, 1e-3)) * step(q.y, fl + CVG(5.4));
    col = mix(col, vel * 0.45, S(room));
    col = mix(col, vel * (0.55 + 0.6 * on * beam) + vec3(1., 0.9, 0.7) * 0.18 * on * beam, S(arch));
    col = mix(col, CV_GOLD * 1.1, S(abs(arch) - 0.0018));
    for(int s = -1; s <= 1 + CVZ; s += 2){
        vec2 cnd = vec2(sp.x + float(s) * CVG(2.7), fl + CVG(3.6));
        col = mix(col, CV_GOLD, S(sdBox(q - cnd + vec2(0., 0.005), vec2(0.004, 0.0012))));
        col = mix(col, vec3(0.92, 0.88, 0.78), S(sdBox(q - cnd, vec2(0.0018, 0.004))));
        float fl2 = 0.8 + 0.2 * sin(iTime * 13. + float(s) * 2.);
        col += vec3(1., 0.75, 0.35) * 0.6 * fl2 * exp(-length((q - cnd - vec2(0., 0.006)) * vec2(1.6, 1.)) / 0.0025);
        col += vec3(1., 0.7, 0.3) * 0.08 * fl2 * exp(-length(q - cnd) / 0.02);
    }
    col = mix(col, vec3(1., 0.95, 0.8), S(length(q - vec2(sp.x, fl + CVG(5.5))) - 0.004) * (0.4 + 0.6 * on));
    return col;
}

vec3 cvPolishFront(vec3 col, vec2 q, vec4 st){
    vec2 sp = cvStPos(CS_POLISH);
    float fl = sp.y - CV_ROWOFF;
    if(abs(q.x - sp.x) > CVG(3.) || q.y < fl - 0.01 || q.y > fl + CVG(6.)) return col;
    float x = st.x >= 0. ? st.x : 1.;
    float reach = smoothstep(0.05, 0.18, x) * (1. - smoothstep(0.8, 0.92, x));
    float buff = smoothstep(0.15, 0.2, x) * (1. - smoothstep(0.78, 0.82, x));
    for(int s = -1; s <= 1 + CVZ; s += 2){
        float fs = float(s);
        vec2 sh = vec2(sp.x + fs * CVG(2.2), fl + CVG(3.8));
        vec2 rest = vec2(sp.x + fs * CVG(1.9), fl + CVG(2.4));
        vec2 tgt = vec2(sp.x + fs * (0.012 + 0.002 * sin(iTime * 9.) * buff), sp.y + 0.002 * cos(iTime * 9.) * buff);
        vec2 wc = mix(rest, tgt, reach);
        vec2 el = mix(sh, wc, 0.5) + vec2(fs * 0.008, 0.01);
        col = mix(col, CV_GOLD, S(sdSegment(q, sh, el) - 0.0022));
        col = mix(col, CV_GOLD * 1.15, S(sdSegment(q, el, wc) - 0.0018));
        col = cvMach(col, length(q - el) - 0.003, 0.9);
        col = cvMach(col, length(q - sh) - 0.004, 0.8);
        float rw = 0.0065;
        vec2 l = Rot(iTime * (2. + 40. * buff) * fs) * (q - wc);
        float rr = length(q - wc), d = rr - rw;
        col = mix(col, vec3(0.02), S(d - 0.001) * 0.4);
        col = mix(col, vec3(0.88, 0.84, 0.76) * (0.85 + 0.15 * sin(atan(l.y, l.x) * 20.)), S(d));
        col = mix(col, vec3(0.45, 0.28, 0.14), S(d) * smoothstep(rw * 0.5, rw, rr) * 0.5 * buff);
        col = cvMach(col, rr - 0.0018, 1.1);
        if(buff > 0.){
            for(int k = 0; k < 6 + CVZ; k++){
                float fk = float(k) + fs * 5.;
                float u = fract(iTime * 2.4 + cvHash(fk + 0.3));
                vec2 p = wc + vec2(fs * (0.008 + 0.014 * cvHash(fk + 1.7)) * u, 0.012 * u - 0.03 * u * u);
                col = mix(col, vec3(0.4, 0.24, 0.11), S(length(q - p) - 0.0011) * buff * (1. - u));
            }
        }
    }
    float rev = st.x >= 0. ? smoothstep(0.82, 0.9, st.x) : 1. - smoothstep(0.1, 0.7, st.z);
    if(rev > 0.){
        float t = st.x >= 0. ? 0. : st.z;
        col += vec3(1., 0.95, 0.85) * 0.5 * rev * exp(-length(q - sp) / 0.02) * (st.x >= 0. ? 1. : exp(-t * 4.));
        col += vec3(1., 0.95, 0.8) * 0.6 * rev * S(abs(length(q - sp) - 0.012 - t * 0.06) - 0.0008);
        for(int k = 0; k < 8 + CVZ; k++){
            float fk = float(k);
            float a = fk * 0.785 + 0.3 * cvHash(fk);
            vec2 p = sp + vec2(cos(a), sin(a)) * (0.015 + 0.01 * cvHash(fk + 2.)) * (1. + t * 2.);
            vec2 r = abs(q - p);
            float tw = 0.5 + 0.5 * sin(iTime * 12. + fk * 2.);
            float star = max(1. - (r.x * r.y) * 4e5 - (r.x + r.y) * 60., 0.);
            col += vec3(1., 0.95, 0.8) * star * rev * tw;
        }
    }
    return col;
}

// the classroom the finished amps sit a lecture in before packing: twelve
// seats on wooden steps rising from the teacher, who taps the chalk amp on
// the board with a long pointer until the class files out
vec3 cvClassBack(vec3 col, vec2 q, vec4 st){
    if(q.x < CVG(-29.) || q.x > CVG(-7.) || q.y < CVG(-4.) || q.y > CVG(2.)) return col;
    float on = st.x >= 0. ? 1. : 0.;
    float room = sdBox(q - vec2(CVG(-18.), CVG(-1.)), vec2(CVG(11.), CVG(3.)));
    vec3 paper = q.y > CVG(-3.) ? vec3(0.3, 0.33, 0.26) * (0.9 + 0.1 * step(0.5, fract(q.x / CVG(0.5)))) : vec3(0.26, 0.16, 0.09) * (0.85 + 0.15 * tcNoise(q * 150.));
    col = mix(col, paper, S(room));
    col = mix(col, vec3(0.38, 0.25, 0.13), S(abs(q.y - CVG(-3.)) - 0.0008) * S(room));
    vec2 bc = vec2(CVG(-10.9), CVG(0.15));
    float bd = sdBox(q - bc, vec2(CVG(1.4), CVG(1.1)));
    col = mix(col, vec3(0.3, 0.19, 0.1), S(bd - 0.003));
    col = mix(col, vec3(0.07, 0.17, 0.12) * (0.9 + 0.15 * tcNoise(q * 80.)), S(bd));
    vec2 ac = bc - vec2(CVG(0.45), 0.);
    float ch = abs(glyphDist((q - ac) / 0.022)) * 0.022 - 0.0005;
    for(int k = 0; k < 4 + CVZ; k++){
        float y = bc.y + CVG(0.6) - float(k) * CVG(0.35), x0 = bc.x + CVG(0.3);
        float x1 = x0 + CVG(0.35 + 0.45 * cvHash(float(k) + 3.));
        ch = min(ch, max(abs(q.y - y - 0.001 * sin(q.x * 900. + float(k) * 3.)) - 0.0004, max(x0 - q.x, q.x - x1)));
    }
    col = mix(col, vec3(0.85, 0.88, 0.84), S(ch) * step(bd, 0.));
    col = mix(col, vec3(0.3, 0.19, 0.1), S(sdBox(q - vec2(bc.x, bc.y - CVG(1.1) - 0.002), vec2(CVG(1.4), 0.0015))));
    vec2 sf = vec2(CVX(-11.), CVR(-4.)), sb = vec2(CVG(-21.08), CVR(-1.)), dir = normalize(sb - sf);
    vec3 wood = vec3(0.3, 0.19, 0.11) * (0.85 + 0.15 * tcNoise(q * 200.));
    for(int r = 1; r < 12 + CVZ; r++){
        vec2 p = sf + dir * CV_GAP * float(r);
        float yb = p.y - CV_SIZE * 0.5;
        float stp = sdBox(q - vec2(p.x, (yb + CVG(-4.)) * 0.5), vec2(CVG(0.5), (yb - CVG(-4.)) * 0.5));
        col = mix(col, wood, S(stp));
        col = mix(col, vec3(0.48, 0.32, 0.18), S(abs(q.y - yb) - 0.0008) * S(stp - 0.0008));
    }
    float pb = sb.y - CV_SIZE * 0.5;
    float plat = sdBox(q - vec2((CVG(-29.) + sb.x) * 0.5, (pb + CVG(-4.)) * 0.5), vec2((sb.x - CVG(-29.)) * 0.5, (pb - CVG(-4.)) * 0.5));
    col = mix(col, wood, S(plat));
    col = mix(col, vec3(0.48, 0.32, 0.18), S(abs(q.y - pb) - 0.0008) * S(plat - 0.0008));
    vec2 tp = vec2(CVG(-8.9), CVR(-4.) + 0.004 + 0.0012 * sin(iTime * 6.) * on);
    float ts = CV_SIZE * 1.25;
    vec2 tg = (q - tp) / ts;
    tg.x = -tg.x;
    float td = glyphDist(tg) * ts;
    col = mix(col, vec3(0.01), S(td - 0.0015) * 0.4);
    col = mix(col, ampGradient(tg) * 0.95, S(td));
    for(int e = 0; e < 2 + CVZ; e++){
        vec2 gc = tp + vec2(-0.0055 + 0.0048 * float(e), 0.0045);
        col = mix(col, vec3(0.05), S(abs(length(q - gc) - 0.0017) - 0.00045));
    }
    vec2 h = tp + vec2(-0.0085, 0.003);
    vec2 tgt = ac + vec2(0.006, 0.004) + 0.0015 * vec2(sin(iTime * 5.), cos(iTime * 7.)) * on;
    col = mix(col, vec3(0.5, 0.32, 0.15), S(sdSegment(q, h, tgt) - 0.0008));
    return col;
}

// the coronation room under the classroom: purple banners and a spotlight;
// each graduate lands on the floor and a mortarboard tumbles down out of the
// dark onto its head
vec3 cvCoronBack(vec3 col, vec2 q, vec4 st){
    vec2 a = cvStPos(CS_HAT);
    if(q.x < CVG(-15.) || q.x > CVG(-7.) || q.y < CVG(-15.) || q.y > CVG(-5.)) return col;
    float on = st.x >= 0. ? smoothstep(0., 0.15, st.x) * (1. - smoothstep(0.9, 1., st.x)) : 0.;
    float rm = sdBox(q - vec2(CVG(-11.), CVG(-10.)), vec2(CVG(4.), CVG(5.)));
    vec3 wall = vec3(0.3, 0.05, 0.08) * (0.8 + 0.25 * smoothstep(CVG(-15.), CVG(-5.), q.y)) * (0.85 + 0.35 * exp(-abs(q.x - a.x) / 0.04));
    col = mix(col, wall, S(rm));
    vec3 gold = CV_GOLD * 1.15;
    col = mix(col, vec3(0.22, 0.11, 0.05), S(max(rm, q.y - CVG(-14.))));
    col = mix(col, gold, S(abs(q.y - CVG(-14.)) - 0.001) * S(rm));
    col = mix(col, gold, S(max(rm, CVG(-5.4) - q.y)));
    col = mix(col, gold * 0.6, S(abs(q.y - CVG(-5.4)) - 0.0006) * S(rm));
    for(int b = 0; b < 2 + CVZ; b++){
        float bx = CVG(-11.) + (b == 0 ? -1. : 1.) * CVG(2.5);
        float bd = max(sdBox(q - vec2(bx, CVG(-7.6)), vec2(CVG(0.6), CVG(2.2))), CVG(-9.8) + (CVG(0.6) - abs(q.x - bx)) * 0.9 - q.y);
        col = mix(col, vec3(0.28, 0.08, 0.36) * (0.85 + 0.15 * sin((q.x - bx) * 600.)), S(bd));
        col = mix(col, gold, S(abs(bd) - 0.0009));
        col = mix(col, gold * 1.1, S(abs(length((q - vec2(bx, CVG(-6.9))) * vec2(1., 1.2)) - 0.005) - 0.0008));
    }
    float py = CVR(-14.4) - CV_SIZE * 0.5;
    vec3 marble = vec3(0.86, 0.84, 0.8) * (0.9 + 0.1 * tcNoise(q * 140.)) - vec3(0.12) * smoothstep(0.85, 0.95, abs(sin(q.x * 600. + q.y * 300. + 3. * tcNoise(q * 60.))));
    for(int k = 0; k < 2 + CVZ; k++){
        float hw = k == 0 ? CVG(1.45) : CVG(1.05), ty = k == 0 ? mix(CVG(-15.), py, 0.5) : py;
        float st2 = sdBox(q - vec2(CVG(-11.), (ty + CVG(-15.)) * 0.5), vec2(hw, (ty - CVG(-15.)) * 0.5));
        col = mix(col, vec3(0.02), S(st2 - 0.0015) * 0.4);
        col = mix(col, marble * (k == 0 ? 0.85 : 1.), S(st2));
        col = mix(col, gold, S(abs(q.y - ty) - 0.0009) * S(st2 - 0.0009));
    }
    float beam = smoothstep(0.4, 0.12, abs(q.x - a.x) / max(CVG(-5.6) - q.y, 1e-3)) * step(q.y, CVG(-5.6));
    col += vec3(1., 0.92, 0.7) * (0.05 + 0.14 * on) * beam;
    col = mix(col, vec3(1., 0.95, 0.8), S(length(q - vec2(a.x, CVG(-5.7))) - 0.0035) * (0.5 + 0.5 * on));
    return col;
}

vec3 cvHatRig(vec3 col, vec2 q, vec4 st){
    vec2 a = cvStPos(CS_HAT);
    if(q.x < CVG(-15.) || q.x > CVG(-7.) || q.y < CVG(-15.) || q.y > CVG(-5.)) return col;
    float x = st.x >= 0. ? st.x : 0.;
    float u = smoothstep(0., 0.6, x);
    float top = CVG(-5.4) - 0.006 - 0.73 * CV_SIZE;
    vec2 o = vec2(a.x + 0.004 * sin(x * 17.) * (1. - u), mix(top, a.y, u * u));
    float ang = 0.6 * sin(x * 21.) * (1. - u);
    col = cvMach(col, sdBox(q - vec2(a.x, CVG(-5.4) - 0.0015), vec2(0.006, 0.0015)), 0.7);
    if(st.x >= 0. && x > 0.6 && x < 0.85){
        float t = (x - 0.6) / 0.25;
        for(int k = 0; k < 8 + CVZ; k++){
            float fk = float(k), an = fk * 0.785 + 0.4;
            vec2 p = a + vec2(0., CV_SIZE * 0.7) + vec2(cos(an), sin(an)) * (0.006 + 0.014 * t);
            col += vec3(1., 0.85, 0.4) * S(length(q - p) - 0.0012) * (1. - t);
        }
    }
    if(st.x < 0.) return cvCap(col, (q - o) / CV_SIZE);
    return cvCap(col, Rot(ang) * (q - o) / CV_SIZE);
}

// the cap knocked off at the top of the bounce: it flips up and away and
// tumbles down the shaft
vec3 cvBounceRoom(vec3 col, vec2 q, float t){
    if(q.x < CVG(-19.) || q.x > CVG(-16.) || q.y < CVG(-15.) || q.y > CVG(-5.)) return col;
    float rm = sdBox(q - vec2(CVG(-17.5), CVG(-10.)), vec2(CVG(1.5), CVG(5.)));
    rm = max(rm, -sdBox(q - vec2(CVG(-18.5), CVG(-11.5)), vec2(CVG(0.5), CVG(0.5))));
    col = mix(col, vec3(0.3, 0.31, 0.34) * (0.92 + 0.08 * tcNoise(q * 120.)), S(rm));
    float hz = step(0.5, fract((q.x + q.y) / 0.008));
    col = mix(col, mix(vec3(0.08), vec3(0.85, 0.65, 0.1), hz), S(max(rm, q.y - CVG(-14.6))));
    vec2 b = vec2(CVX(-17.), CVG(-15.));
    float since = t;
    float kick = exp(-since * 14.) * sin(min(since * 30., 3.14159));
    float top = b.y + 0.004 + 0.008 * kick;
    float spring = abs(fract((q.y - b.y) / max(top - b.y, 0.002) * 4.) - 0.5) * 2.;
    col = cvMach(col, max(abs(q.x - b.x - (spring - 0.5) * CVG(0.6)) - 0.0014, max(b.y - q.y, q.y - top)), 0.8);
    return cvMach(col, sdBox(q - vec2(b.x, top + 0.0015), vec2(CVG(0.45), 0.0018)), 1.15);
}

vec3 cvHatFly(vec3 col, vec2 q, float t){
    t -= 0.22;
    if(t < 0. || t > 1.2) return col;
    vec2 pad = vec2(CVX(-17.), CVR(-15.)), land = vec2(CVX(-19.), CVR(-11.));
    vec2 ap = mix(pad, land, 0.5) + vec2(0., CVG(5.));
    vec2 o = ap + vec2(0.04 * t, 0.07 * t - 0.45 * t * t);
    if(length(q - o) > 0.04) return col;
    vec3 c = cvCap(col, Rot(-7. * t) * (q - o) / CV_SIZE);
    return mix(col, c, 1. - smoothstep(0.9, 1.2, t));
}

// the QC column: amps hauled up a pure vertical shaft, each by its own arm
// running on a rail up the left wall, stopping at every step: a stamp, a
// squeeze, a scale, a stretch and a scanner, each in a niche in the right
// wall beside a boot for the ones that fail
vec3 cvColumn(vec3 col, vec2 q, vec4 st[31], float asp){
    if(q.x < CVG(-6.5) || q.x > CVG(-1.8) || q.y < CVG(-15.5) || q.y > CVG(4.)) return col;
    col = cvMach(col, sdBox(q - vec2(CVG(-6.) + 0.003, CVG(-5.75)), vec2(0.003, CVG(9.25))), 0.6);
    vec4 sl[AG_TEX];
    agSlots(iChannel17, vec2(CVG(-5.), q.y), asp, sl);
    for(int k = 0; k < AG_SLOTS + CVZ; k++){
        int i = int(sl[k >> 2][k & 3] + 0.5) - 1;
        if(i < 0) break;
        vec4 r0 = cvState(i, 0), r1 = cvState(i, 1);
        if(cvI(r1.x) != CT_FIN || abs(r0.x - CVG(-5.)) > 0.004 || r0.y < CVR(-15.) + 0.001 || r0.y > CVR(3.) - 0.001) continue;
        vec2 p = r0.xy;
        float top = p.y + CV_SIZE * 0.55;
        col = cvMach(col, sdBox(q - vec2(CVG(-6.) + 0.006, top + 0.001), vec2(0.0055, 0.0055)), 0.75);
        col = cvMach(col, sdSegment(q, vec2(CVG(-6.) + 0.006, top + 0.001), vec2(p.x, top + 0.001)) - 0.0022, 0.9);
        col = cvMach(col, sdBox(q - vec2(p.x, top + 0.002), vec2(0.005, 0.002)), 1.);
        for(int s = -1; s <= 1 + CVZ; s += 2)
            col = cvMach(col, sdSegment(q, vec2(p.x + float(s) * 0.0045, top + 0.001), vec2(p.x + float(s) * 0.0055, top - 0.005)) - 0.0015, 0.95);
    }
    float wx = CVG(-2.);
    for(int j = 0; j < 5 + CVZ; j++){
        int k = CV_QC_K[j];
        vec2 a = cvStPos(k);
        if(abs(q.y - a.y) > CVG(1.2)) continue;
        vec4 s = st[k];
        float x = s.x >= 0. ? s.x : 0.;
        if(j == 0){
            float press = s.x >= 0. ? smoothstep(0.2, 0.45, x) * (1. - smoothstep(0.6, 0.85, x)) : 0.;
            float hx = mix(CVG(-2.7), a.x + CV_SIZE * 0.42 + 0.003, press);
            col = cvMach(col, sdBox(q - vec2(CVG(-2.35), a.y), vec2(CVG(0.35), 0.013)), 0.6);
            col = cvMach(col, sdBox(q - vec2((hx + wx) * 0.5, a.y), vec2((wx - hx) * 0.5, 0.0038)), 0.75);
            col = cvMach(col, sdBox(q - vec2(hx + 0.005, a.y), vec2(0.005, 0.011)), 1.1);
            col += GRAD_TOP * 0.4 * press * press * exp(-length(q - vec2(hx, a.y)) / 0.01);
        } else if(j == 1){
            float kk = cvStressK(s);
            float w = CV_SIZE * 0.4 / (1. + 0.6 * kk) + 0.0018;
            float drop = s.x >= 0. ? smoothstep(0., 0.12, x) * (1. - smoothstep(0.92, 1., x)) : 0.;
            for(int sd = -1; sd <= 1 + CVZ; sd += 2){
                float fs = float(sd), base = fs > 0. ? wx : CVG(-6.) + 0.003;
                float px = mix(base - fs * 0.003, a.x + fs * w, drop);
                col = cvMach(col, sdBox(q - vec2(base + fs * 0.002, a.y - 0.004), vec2(0.004, 0.008)), 0.6);
                col = cvMach(col, sdBox(q - vec2((px + base) * 0.5, a.y - 0.004), vec2(abs(base - px) * 0.5, 0.0028)), 0.75);
                col = cvMach(col, sdBox(q - vec2(px, a.y), vec2(0.0028, 0.012)), 1.05);
            }
        } else if(j == 2){
            vec2 c = vec2(CVG(-2.9), a.y);
            col = cvMach(col, sdBox(q - c, vec2(0.016, 0.016)), 0.6);
            float d = length(q - c);
            col = mix(col, vec3(0.85, 0.83, 0.75), S(d - 0.0125));
            col = mix(col, CV_MC * 0.45, S(abs(d - 0.0125) - 0.002));
            float na = s.x < 0. ? -1.6 : -1.6 + 2.6 * (1. - exp(-x * 6.) * cos(x * 22.));
            col = mix(col, vec3(1., 0.4, 0.15), S(sdSegment(q, c, c + vec2(sin(na), cos(na)) * 0.0105) - 0.0014));
            col = mix(col, vec3(0.1), S(d - 0.0025));
        } else if(j == 3){
            float kk = cvStressK(s);
            float drop = s.x >= 0. ? smoothstep(0., 0.12, x) * (1. - smoothstep(0.92, 1., x)) : 0.;
            float fy = a.y - CV_SIZE * 0.55 * (1. + 0.4 * kk) - 0.001;
            float cx = mix(wx - 0.003, a.x + 0.004, drop);
            col = cvMach(col, sdBox(q - vec2(CVG(-2.3), fy - 0.003), vec2(CVG(0.3), 0.008)), 0.6);
            col = cvMach(col, sdBox(q - vec2((cx + wx) * 0.5, fy - 0.003), vec2((wx - cx) * 0.5, 0.003)), 0.75);
            col = cvMach(col, max(sdBox(q - vec2(cx - 0.004, fy - 0.002), vec2(0.0105, 0.005)), -sdBox(q - vec2(cx - 0.004, fy + 0.0005), vec2(0.0075, 0.004))), 1.05);
        } else {
            col = cvMach(col, sdBox(q - vec2(CVG(-2.4), a.y), vec2(0.006, CVG(0.9))), 0.85);
            col = cvMach(col, sdBox(q - vec2(CVG(-2.4) - 0.006, a.y), vec2(0.0012, CVG(0.8))), 1.2);
            if(s.x >= 0.){
                float y = a.y - CV_SIZE * 0.5 + CV_SIZE * (0.5 - 0.5 * cos(x * 9.42));
                col += vec3(1., 0.15, 0.1) * 0.8 * S(abs(q.y - y) - 0.0006) * step(a.x - 0.012, q.x) * step(q.x, CVG(-2.4));
            }
            vec4 kt = cvState(CX_QK + j, CV_ROW);
            bool bad = s.x >= 0. && cvI(kt.y) == cvI(s.y) && kt.z > 0.5 && x > 0.6;
            vec2 lp = vec2(CVG(-2.4), a.y + CVG(0.9));
            vec3 lc = s.x < 0. ? CV_SLAB * 0.6 : bad ? vec3(1., 0.15, 0.1) : vec3(0.25, 1., 0.5);
            col = mix(col, lc, S(length(q - lp) - 0.0045));
            if(s.x >= 0.) col += lc * 0.15 * exp(-length(q - lp) / 0.01);
        }
    }
    return col;
}

vec3 cvQC(vec3 col, vec2 q, vec4 st[31], vec4 jam, vec4 so){
    if(q.y < CVG(-7.) || q.y > CVG(6.)) return col;
    vec2 sp = cvStPos(CS_STAMP);
    if(abs(q.x - sp.x) < 0.05){
        bool jm = jam.x == float(CS_STAMP) && jam.y < CV_FIX_AT;
        float p = st[CS_STAMP].x >= 0. && !jm ? st[CS_STAMP].x : 0.;
        float press = smoothstep(0.2, 0.45, p) * (1. - smoothstep(0.6, 0.85, p));
        col = cvHead(col, q, CS_STAMP, press, vec2(0.012, 0.006), 1.1, 0.045, sp.y + CV_SIZE * 0.5);
        col += GRAD_TOP * 0.4 * press * press * exp(-length(q - sp - vec2(0., CV_SIZE * 0.5)) / 0.012);
    }
    sp = cvStPos(CS_WEIGH);
    if(abs(q.x - sp.x) < 0.05){
        float p = st[CS_WEIGH].x;
        float sink = p >= 0. ? 0.002 * (1. - exp(-p * 6.) * cos(p * 22.)) : 0.;
        col = cvMach(col, sdBox(q - vec2(sp.x, sp.y - CV_SIZE * 0.5 - 0.002 - sink), vec2(0.02, 0.0022) * CV_K), 1.2);
        vec2 c = vec2(sp.x, sp.y - 0.046);
        col = mix(col, CV_HOLE, S(length(q - c) - 0.011 * CV_K));
        float na = p < 0. ? -1.6 : -1.6 + 2.6 * (1. - exp(-p * 6.) * cos(p * 22.));
        col = mix(col, vec3(1., 0.4, 0.15), S(sdSegment(q, c, c + vec2(sin(na), cos(na)) * 0.008 * CV_K) - 0.0009));
    }
    sp = cvStPos(CS_SCAN);
    if(abs(q.x - sp.x) < 0.05){
        float c = cvCeil(CS_SCAN);
        col = cvMach(col, sdBox(q - vec2(sp.x, c - 0.001), vec2(0.016, 0.0025) * CV_K), 1.);
        if(st[CS_SCAN].x >= 0.){
            float y = sp.y - CV_SIZE * 0.5 + CV_SIZE * (0.5 - 0.5 * cos(st[CS_SCAN].x * 9.42));
            col += vec3(1., 0.15, 0.1) * 0.8 * S(abs(q.y - y) - 0.0006) * step(abs(q.x - sp.x), 0.015 * CV_K);
        }
        bool lit = st[CS_SCAN].z < 1.2;
        vec3 lc = st[CS_SCAN].w > 0.5 ? vec3(1., 0.15, 0.1) : vec3(0.25, 1., 0.5);
        vec2 lp = vec2(sp.x, c + 0.016);
        col = mix(col, lit ? lc : CV_SLAB * 0.6, S(length(q - lp) - 0.0035 * CV_K));
        if(lit) col += lc * 0.15 * exp(-length(q - lp) / 0.01);
    }
    return col;
}

vec3 cvPack(vec3 col, vec2 q, vec4 st[31], vec4 jam){
    if(q.y < CVG(-12.) || q.y > CVG(-4.)) return col;
    vec2 sp = cvStPos(CS_BOX);
    if(abs(q.x - sp.x) < 0.05){
        float tl = cvState(CX_HATFLY, CV_ROW).x;
        if(st[CS_BOX].x < 0. && tl < 0.46){
            float u = clamp(tl / 0.34, 0., 1.);
            vec2 bp = vec2(sp.x, mix(CVG(-5.6), sp.y, u * u));
            vec2 d = (q - bp) / CV_M, bd = d - vec2(0., -0.0015);
            float b = sdRoundBox(bd, vec2(0.0245, 0.0215), 0.002);
            col = mix(col, vec3(0.02), S(b - 0.002) * 0.5);
            col = mix(col, vec3(0.5, 0.36, 0.21) * (0.92 + 0.08 * tcNoise(bd * 400.)), S(b));
            col = mix(col, vec3(0.28, 0.19, 0.1), S(abs(b) - 0.0008));
            for(int sd = -1; sd <= 1 + CVZ; sd += 2){
                vec2 hinge = vec2(0.0245 * float(sd), 0.02);
                col = mix(col, vec3(0.42, 0.3, 0.17), S(sdSegment(d, hinge, hinge + Rot(float(sd) * 1.4) * vec2(-0.024 * float(sd), 0.)) - 0.0016));
            }
        }
        vec2 hc = vec2(sp.x, CVG(-5.6));
        float hb = sdBox(q - hc, vec2(CVG(0.75), CVG(0.6)));
        col = cvMach(col, hb, 0.75);
        float win = sdBox(q - hc - vec2(0., 0.002), vec2(CVG(0.5), CVG(0.3)));
        col = mix(col, vec3(0.5, 0.36, 0.21) * (0.75 + 0.25 * step(0.5, fract((q.y - hc.y) / 0.0025))), S(win));
        col = mix(col, CV_MC * 0.45, S(abs(win) - 0.0008));
        float op = tl < 0.3 ? sin(clamp(tl / 0.3, 0., 1.) * 3.14159) : 0.;
        for(int sd = -1; sd <= 1 + CVZ; sd += 2){
            vec2 hg = vec2(hc.x + float(sd) * CVG(0.7), CVG(-6.2));
            col = cvMach(col, sdSegment(q, hg, hg + Rot(-float(sd) * op * 1.4) * vec2(-float(sd) * CVG(0.68), 0.)) - 0.0013, 0.9);
        }
    }
    sp = cvStPos(CS_TAPE);
    if(abs(q.x - sp.x) < 0.05){
        bool jm = jam.x == float(CS_TAPE) && jam.y < CV_FIX_AT;
        float p = st[CS_TAPE].x >= 0. && !jm ? st[CS_TAPE].x : 0.;
        float c = cvCeil(CS_TAPE), top = sp.y + 0.02 * CV_M;
        float grow = smoothstep(0.15, 0.75, p), reach = smoothstep(0., 0.15, p) * (1. - smoothstep(0.8, 1., p));
        float hy = mix(c + 0.008, top - 0.045 * CV_M * grow + 0.004, reach);
        vec2 h = vec2(sp.x + 0.0055, hy);
        col = cvMach(col, sdBox(q - vec2(h.x, (hy + c + 0.02) * 0.5), vec2(0.0012, (c + 0.02 - hy) * 0.5)), 0.75);
        col = cvMach(col, sdBox(q - h, vec2(0.0025, 0.004)), 0.9);
        vec2 rc = h + vec2(0.005, 0.002);
        float rd = length(q - rc);
        col = mix(col, vec3(0.02), S(rd - 0.0055) * 0.4);
        col = mix(col, vec3(0.62, 0.5, 0.33), S(rd - 0.0045));
        col = cvMach(col, rd - 0.0016, 0.8);
        col = mix(col, CV_MC * 0.4, S(sdSegment(q, rc, rc + 0.0035 * vec2(cos(grow * 20.), sin(grow * 20.))) - 0.0005));
    }
    sp = cvStPos(CS_LABEL);
    if(abs(q.x - sp.x) < 0.05){
        float p = st[CS_LABEL].x >= 0. ? st[CS_LABEL].x : 0.;
        float down = smoothstep(0.3, 0.55, p) * (1. - smoothstep(0.65, 0.9, p));
        col = cvHead(col, q, CS_LABEL, down, vec2(0.011, 0.005), 1., 0.04, sp.y + 0.02 * CV_M);
    }
    return col;
}

vec3 cvJamLamp(vec3 col, vec2 q, vec4 jam){
    if(jam.x < 0. || jam.y >= CV_FIX_AT) return col;
    int js = clamp(cvI(jam.x), 0, CV_NS - 1);
    vec2 lp = vec2(CV_ST_X[js] + 0.03, cvCeil(js) + 0.014);
    float fl = step(0.5, fract(iTime * 3.));
    col = mix(col, mix(vec3(0.3, 0.05, 0.03), vec3(1., 0.15, 0.08), fl), S(length(q - lp) - 0.0035 * CV_K));
    return col + vec3(1., 0.1, 0.05) * 0.2 * fl * exp(-length(q - lp) / 0.015);
}

vec3 cvPanel(vec3 col, vec2 q, float shipped){
    if(abs(q.x) > 0.11 || abs(q.y) > 0.085) return col;
    float b = sdBox(q, vec2(0.1, 0.075));
    col = mix(col, CV_HOLE, S(b));
    col = mix(col, CV_SLAB * 0.55, S(abs(b) - 0.0007) * 0.8);
    col = cvDigits(col, q, vec2(-0.086, 0.035), 0.035, 6, 104217. + shipped, GRAD_TOP * 0.9);
    float h = iClock.x * 10. + iClock.y, mi = iClock.z * 10. + iClock.w;
    col = cvDigits(col, q, vec2(-0.064, -0.035), 0.035, 2, h, CV_MC * 1.6);
    col = cvDigits(col, q, vec2(0.006, -0.035), 0.035, 2, mi, CV_MC * 1.6);
    float blink = step(0.5, fract(iTime));
    for(int s = -1; s <= 1 + CVZ; s += 2) col = mix(col, CV_MC * 1.6 * (0.3 + 0.7 * blink), S(length(q - vec2(-0.002, -0.035 + 0.007 * float(s))) - 0.0025));
    return col;
}

// sand running through a pipe from a to b; crossing a tunnel it runs in a
// casing
vec3 cvSandSeg(vec3 col, vec2 q, vec2 a, vec2 b, float carve, float speed){
    float d = sdSegment(q, a, b) - 0.0032;
    if(d > 0.006) return col;
    vec2 dir = normalize(b - a);
    float inTun = S(carve);
    col = mix(col, CV_MC * 0.6, S(d - 0.0016) * inTun);
    col = mix(col, CV_SLAB * 0.45, S(d - 0.0012) * (1. - inTun));
    vec2 u = vec2(dot(q - a, dir), dot(q - a, vec2(-dir.y, dir.x)));
    float g = tcNoise(vec2((u.x - iTime * speed) * 500., u.y * 500.));
    return mix(col, CV_SAND * (0.5 + 0.55 * g), S(d));
}

// a flask standing at (c.x, bottom c.y): `dirt` caked in sand, `wet` from the
// wash, `fill` how full of fresh sand
vec3 cvTowerFlask(vec3 col, vec2 q, vec2 c, float id, float dirt, float wet, float fill){
    vec2 g = (q - c) / CV_SIZE + vec2(0., CV_MCEN[0].y - CV_MHALF[0].y);
    float fl = cvFlask(g, 0);
    float md = cvMouldD(g, 0);
    if(md * CV_DSIZE > 0.006) return col;
    float bot = CV_MCEN[0].y - CV_MHALF[0].y, top = CV_MCEN[0].y + CV_MHALF[0].y;
    if(dirt > 0.){
        float lvl = bot + (0.25 + 0.55 * tcNoise(vec2(g.x * 5., id))) * dirt;
        col = mix(col, CV_SAND * (0.5 + 0.3 * tcNoise(g * 14. + id)), S(max(md + 0.1, g.y - lvl) * CV_DSIZE));
    }
    if(fill > 0.) col = mix(col, CV_SAND * (0.62 + 0.12 * tcNoise(g * 40. + id)), S(max(md + 0.1, g.y - mix(bot, top, fill)) * CV_DSIZE));
    vec3 fc = mix(CV_MC * 0.85, CV_SAND * (0.5 + 0.25 * tcNoise(g * 9. + id)), dirt * 0.85);
    fc = fc * (1. - 0.2 * wet) + vec3(0.1, 0.15, 0.2) * wet + vec3(0.35) * wet * smoothstep(0.3, 0.5, g.y - g.x * 0.3) * 0.3;
    col = mix(col, fc, S(fl));
    if(wet > 0.05){
        for(int k = 0; k < 2 + CVZ; k++){
            float a = fract(iTime * 1.6 + cvHash(id + float(k) * 3.));
            vec2 dp = vec2(c.x + (cvHash(id + float(k)) - 0.5) * 0.02, c.y - 0.002 - a * 0.012);
            col = mix(col, vec3(0.55, 0.75, 0.85), S(length(q - dp) - 0.0009) * wet * (1. - a));
        }
    }
    return col;
}

const float CV_FDT    = 0.5;
const float CV_FALL_V = 0.6;

float cvBeltY(){ return CV_RET_Y - CV_CELL + 0.002; }
float cvPitY(){ return CV_PIT.y - CV_PIT_H.y + 0.012; }

// flask `id` on its round: out of the hatch and left along the return tunnel,
// down the shaft, blasted in the pit and over to the paternoster, up through
// wash, dryer and filler, off into the head of line id % 3. Bottom centre at
// p, false once it has left; dirt, wet, fill its state
bool cvFlaskPath(float id, out vec2 p, out vec3 st, out bool carried){
    float TA = (CV_RET_X - CV_DROP_X) / CV_FRAME_V;
    float TB = (cvBeltY() - cvPitY()) / CV_FALL_V;
    float TC = CV_FDT * 0.9;
    float tt = iTime - id * CV_FDT;
    carried = false;
    st = vec3(1., 0., 0.);
    if(tt < 0.) return false;
    if(tt < TA){
        p = vec2(CV_RET_X - tt * CV_FRAME_V, cvBeltY() + CVG(2.) * (1. - smoothstep(0., 0.35, tt)));
        return true;
    }
    tt -= TA;
    if(tt < TB){
        p = vec2(CV_DROP_X, cvBeltY() - tt * CV_FALL_V);
        return true;
    }
    tt -= TB;
    if(tt < TC){
        float u = tt / TC;
        p = vec2(mix(CV_DROP_X, CV_PAT_X, smoothstep(0.6, 1., u)), cvPitY() + 0.001 * sin(iTime * 60.) * (1. - u));
        st.x = 1. - 0.85 * smoothstep(0.05, 0.6, u);
        return true;
    }
    tt -= TC;
    int row = int(mod(id, 3.));
    p = vec2(CV_PAT_X, cvPitY() + tt * CV_FRAME_V);
    carried = true;
    if(p.y > CV_ST_Y[row] - CV_SIZE * 0.5) return false;
    st = vec3(0.15 * (1. - smoothstep(CV_PIT.y, CV_WASHY.x, p.y)),
              smoothstep(CV_WASHY.x, CV_WASHY.x + 0.03, p.y) * (1. - smoothstep(CV_DRYY.x, CV_DRYY.y, p.y)),
              smoothstep(CV_FILLY.x, CV_FILLY.y, p.y));
    return true;
}

vec3 cvFlaskDraw(vec3 col, vec2 q, float id){
    vec2 p;
    vec3 st;
    bool carried;
    if(!cvFlaskPath(id, p, st, carried)) return col;
    if(abs(q.x - p.x) > 0.03 || abs(q.y - p.y - 0.014) > 0.03) return col;
    if(carried) col = cvMach(col, sdBox(q - p + vec2(0., 0.002), vec2(0.014, 0.0015)), 0.7);
    return cvTowerFlask(col, q, p, id, st.x, st.y, st.z);
}

vec3 cvFlasks(vec3 col, vec2 q){
    float y0 = cvBeltY();
    float TA = (CV_RET_X - CV_DROP_X) / CV_FRAME_V;
    float TB = (y0 - cvPitY()) / CV_FALL_V;
    float TC = CV_FDT * 0.9;
    if(q.x < CVG(-32.) && q.x > CVG(-39.)){
        if(abs(q.x - CV_DROP_X) < CV_CELL && q.y < CV_RET_Y && q.y > CV_PIT.y){
            col = mix(col, CV_SAND * (0.5 + 0.5 * tcNoise(vec2(q.x * 500., (q.y + iTime * 0.4) * 500.))), S(abs(q.x - CV_DROP_X - 0.011) - 0.0012) * 0.8);
        }
        vec2 pq = q - CV_PIT;
        if(all(lessThan(abs(pq), CV_PIT_H + 0.02))){
            float floorY = CV_PIT.y - CV_PIT_H.y;
            float dune = floorY + 0.012 + 0.006 * sin(pq.x * 90. + 1.) + 0.003 * tcNoise(vec2(pq.x * 200., iTime * 0.2));
            col = mix(col, CV_SAND * (0.5 + 0.4 * tcNoise(q * 400.)), S(max(sdBox(pq, CV_PIT_H), q.y - dune)));
            col += CV_SAND * 0.08 * step(sdBox(pq, CV_PIT_H), 0.) * (0.6 + 0.4 * tcNoise(q * 120. + vec2(iTime * 6., 0.)));
            for(int s = -1; s <= 1 + CVZ; s += 2){
                vec2 nz = vec2(CV_PIT.x + float(s) * (CV_PIT_H.x - 0.003), dune + 0.02);
                col = cvMach(col, sdBox(q - nz, vec2(0.0025, 0.003)), 0.9);
                for(int j = 0; j < 4 + CVZ; j++){
                    float a = fract(iTime * 4. + cvHash(float(j) + float(s) * 7.));
                    vec2 a0 = nz + vec2(-float(s) * 0.003, 0.002 * float(j - 2));
                    vec2 a1 = a0 + vec2(-float(s) * 0.035, -0.008) * (0.3 + a);
                    col += vec3(0.85, 0.9, 1.) * 0.18 * S(sdSegment(q, mix(a0, a1, a * 0.6), a1) - 0.0005) * (1. - a);
                }
            }
            for(int j = 0; j < 10 + CVZ; j++){
                float fj = float(j);
                float a = fract(iTime * 1.8 + cvHash(fj + 0.7));
                vec2 o = vec2(CV_DROP_X + (cvHash(fj + 2.1) - 0.5) * 0.02, dune + 0.01);
                vec2 p = o + vec2(0.05 * a * (cvHash(fj + 5.) - 0.5), 0.03 * a - 0.05 * a * a);
                col = mix(col, CV_SAND * 0.9, S(length(q - p) - 0.0008) * (1. - a));
            }
        }
        if(abs(q.x - CV_PAT_X) < 0.03 && q.y > CV_PIT.y - 0.05 && q.y < CV_TOPY + 0.03){
            col = mix(col, CV_MC * 0.5, S(abs(q.x - CV_PAT_X + 0.015) - 0.0008));
            float dryK = smoothstep(0.03, 0., max(CV_DRYY.x - q.y, q.y - CV_DRYY.y));
            col += vec3(1., 0.35, 0.06) * 0.1 * dryK * step(abs(q.x - CV_PAT_X), 0.017);
            col = mix(col, vec3(1.3, 0.4, 0.06) * (0.8 + 0.2 * sin(iTime * 3. + q.y * 40.)), S(sdBox(q - vec2(CV_PAT_X - 0.0155, (CV_DRYY.x + CV_DRYY.y) * 0.5), vec2(0.0015, (CV_DRYY.y - CV_DRYY.x) * 0.5))));
            if(q.y > CV_WASHY.x - 0.02 && q.y < CV_WASHY.y + 0.02){
                for(int k = 0; k < 3 + CVZ; k++){
                    vec2 nz = vec2(CV_PAT_X + 0.0155, mix(CV_WASHY.x, CV_WASHY.y, (float(k) + 0.5) / 3.));
                    col = cvMach(col, sdBox(q - nz, vec2(0.0022, 0.003)), 0.9);
                    for(int j = 0; j < 5 + CVZ; j++){
                        float a = fract(iTime * 2.5 + cvHash(float(j + k * 5) + 0.3));
                        vec2 p = nz + vec2(-0.03 * a, (cvHash(float(j + k * 5)) - 0.5) * 0.02 * a - 0.008 * a * a);
                        col = mix(col, vec3(0.6, 0.8, 0.9), S(length(q - p) - 0.0008) * (1. - a * 0.6));
                    }
                }
            }
            if(q.y > CV_DRYY.x && q.y < CV_DRYY.y + 0.04){
                for(int j = 0; j < 4 + CVZ; j++){
                    float a = fract(iTime * 0.6 + float(j) * 0.25);
                    vec2 sc = vec2(CV_PAT_X + 0.006 * sin(a * 6. + float(j)), CV_DRYY.x + 0.02 + a * 0.11);
                    col = mix(col, vec3(0.75), S(length(q - sc) - 0.004 - a * 0.006) * 0.15 * (1. - a));
                }
            }
            float nzY = CV_FILLY.y + 0.022;
            col = cvMach(col, sdBox(q - vec2(CV_PAT_X, nzY), vec2(0.004, 0.003)), 0.9);
            float stream = sdSegment(q, vec2(CV_PAT_X, nzY - 0.003), vec2(CV_PAT_X, CV_FILLY.x)) - 0.0012;
            col = mix(col, CV_SAND * (0.6 + 0.5 * tcNoise(vec2(q.x * 600., (q.y + iTime * 0.3) * 600.))), S(stream));
        }
    }
    return col;
}

vec3 cvSand(vec3 col, vec2 q, float carve){
    if(q.x > CVG(-30.) && q.x < CV_RET_X - 0.02 && abs(q.y - CV_RET_Y) > CVG(1.5)) return col;
    if(q.x > CV_RET_X + 0.03) return col;
    col = cvSandSeg(col, q, vec2(CV_RET_X + 0.009, CV_TOPY - CV_SIZE * 0.5 - 0.003), vec2(CV_RET_X + 0.009, CV_RET_Y - CV_CELL - 0.003), carve, 0.25);
    col = cvSandSeg(col, q, vec2(CV_RET_X + 0.009, CV_RET_Y - CV_CELL - 0.003), vec2(CV_DROP_X + 0.011, CV_RET_Y - CV_CELL - 0.003), carve, 0.12);
    float pitB = CV_PIT.y - CV_PIT_H.y + 0.004;
    col = cvSandSeg(col, q, vec2(CV_PIT.x + CV_PIT_H.x, pitB), vec2(CV_SELEV_X, pitB), carve, 0.1);
    float topY = CV_HOPPER.y + 0.045;
    if(abs(q.x - CV_SELEV_X) < 0.015 && q.y > pitB - 0.01 && q.y < topY + 0.01){
        float sh = sdBox(q - vec2(CV_SELEV_X, (pitB + topY) * 0.5), vec2(0.008, (topY - pitB) * 0.5));
        col = mix(col, CV_HOLE, S(sh));
        col = mix(col, CV_SLAB * 0.55, S(abs(sh) - 0.0007) * 0.8);
        col = mix(col, CV_MC * 0.5, S(abs(q.x - CV_SELEV_X + 0.004) - 0.0007) * step(sh, 0.));
        float v = q.y - iTime * 0.06;
        float cell = fract(v / 0.022) * 0.022 - 0.011;
        float bk = max(sdBox(vec2(q.x - CV_SELEV_X - 0.001, cell), vec2(0.0045, 0.004)), -sdBox(vec2(q.x - CV_SELEV_X - 0.001, cell - 0.002), vec2(0.0032, 0.004)));
        col = mix(col, CV_MC * 0.8, S(bk) * step(sh, 0.));
        col = mix(col, CV_SAND * 0.8, S(sdBox(vec2(q.x - CV_SELEV_X - 0.001, cell - 0.0005), vec2(0.0032, 0.0022))) * step(sh, 0.));
    }
    col = cvSandSeg(col, q, vec2(CV_SELEV_X, topY), vec2(CV_HOPPER.x + 0.02, topY), carve, 0.1);
    col = cvSandSeg(col, q, vec2(CV_HOPPER.x, CV_HOPPER.y - 0.03), vec2(CV_HOPPER.x, CV_FILLY.y + 0.022), carve, 0.2);
    col = cvSandSeg(col, q, vec2(CV_HOPPER.x, CV_FILLY.y + 0.022), vec2(CV_PAT_X + 0.004, CV_FILLY.y + 0.022), carve, 0.2);
    vec2 hq = q - CV_HOPPER;
    float hop = cvTrapezoid(hq, 0.01, 0.035, 0.03);
    if(hop < 0.01){
        col = mix(col, vec3(0.), (1. - smoothstep(0., 0.006, hop)) * 0.3);
        float lvl = 0.01 + 0.002 * sin(iTime * 0.7);
        vec3 inner = mix(CV_HOLE, CV_SAND * (0.5 + 0.45 * tcNoise(q * 500. + vec2(0., iTime * 0.3))), step(hq.y, lvl));
        col = mix(col, inner, S(hop));
        col = mix(col, CV_SLAB * 0.55, S(abs(hop) - 0.0007) * 0.8);
    }
    for(int li = 0; li < 3 + CVZ; li++){
        float y = CV_ST_Y[li] - CV_SIZE * 0.5 - 0.002;
        float gr = sdBox(q - vec2(CV_RET_X, y), vec2(0.014, 0.0025));
        if(gr > 0.003) continue;
        col = mix(col, CV_HOLE * 0.6, S(gr));
        col = mix(col, CV_MC * 0.6, S(gr) * step(0.5, fract(q.x / 0.004)));
    }
    return col;
}

// the mould press at the head of foundry line k - CS_PRESS: its head
// stamps the piece into a fresh block of sand
vec3 cvMouldPress(vec3 col, vec2 q, int k, vec4 st, vec4 jam){
    vec2 sp = cvStPos(k);
    if(abs(q.x - sp.x) > 0.04 || q.y < sp.y - 0.02 || q.y > sp.y + 0.07) return col;
    int li = k - CS_PRESS, kind = li == 0 ? 1 : li == 1 ? 0 : 2;
    bool jm = jam.x == float(k) && jam.y < CV_FIX_AT;
    float p = st.x >= 0. && !jm ? st.x : 0.;
    float down = smoothstep(0.1, 0.35, p) * (1. - smoothstep(0.6, 0.9, p));
    float top = sp.y + (CV_MCEN[kind].y + CV_MHALF[kind].y) * CV_SIZE;
    col = cvHead(col, q, k, down, vec2(0.014, 0.005), 1., li == 1 ? 0.03 : 0.02, top);
    float since = (p - 0.35) * CV_ST_DW[k];
    if(p > 0.35 && since < 0.3){
        vec2 c = vec2(sp.x, top);
        for(int j = 0; j < 6 + CVZ; j++){
            float fj = float(j);
            vec2 v = vec2((cvHash(fj + float(k)) - 0.5) * 0.12, 0.03 + 0.03 * cvHash(fj + 3.));
            vec2 pp = c + v * since + vec2(0., -0.3) * since * since;
            col = mix(col, CV_SAND, S(length(q - pp) - 0.0012) * (1. - since / 0.3));
        }
    }
    return col;
}

// the paternoster's pistons, one in the wall by the head of each line, out
// when they have just pushed a flask across
vec3 cvPistons(vec3 col, vec2 q){
    if(q.x < CVG(-36.) || q.x > CVG(-34.) || q.y < CVG(8.) || q.y > CVG(17.)) return col;
    for(int li = 0; li < 3 + CVZ; li++){
        float since = cvState(CX_PUSH + li, CV_ROW).x;
        float ext = 1. - smoothstep(0.12, 0.45, since);
        float y = CV_ST_Y[li];
        float wall = CVG(-35.);
        col = cvMach(col, sdBox(q - vec2(wall - CVG(0.45), y), vec2(CVG(0.4), 0.006)), 0.75);
        float hx = wall + ext * CVG(0.35);
        col = cvMach(col, sdBox(q - vec2((wall + hx) * 0.5, y), vec2(max((hx - wall) * 0.5, 0.0005), 0.0018)), 1.1);
        col = cvMach(col, sdBox(q - vec2(hx, y), vec2(0.0015, 0.009)), 0.9);
    }
    return col;
}

vec3 cvScene(vec2 q, vec2 tp){
    float fit = cvFit(iResolution.x / iResolution.y);
    float asp = iResolution.x / iResolution.y / fit;
    q = q / fit + vec2(CV_CX, CV_CY);
    vec4 st[31];
    for(int k = 0; k < CV_NS + CVZ; k++) st[k] = cvState(k, CV_ROW);
    vec4 jam = cvState(CX_JAM, CV_ROW), so = cvState(CX_SORT, CV_ROW);
    float carve = cvCarve(q);
    vec3 col = cvSlab(q, tp, carve);
    col = cvWallHoles(col, q, tp);
    col = cvVeins(col, q, carve);
    col = cvHeater(col, q, carve);
    col = cvDrum(col, q);
    col = cvDripBack(col, q);
    col = cvSplat(col, q, st[CS_FLICK]);
    col = cvSand(col, q, carve);
    col = cvFlasks(col, q);
    col = cvFans(col, q);
    col = cvPanel(col, (q - vec2(CVG(-23.5), CVG(-13.6))) / 0.6, st[CS_LABEL].w);
    col = cvBelts(col, q);
    col = cvPlinko(col, q);
    col = cvXray(col, q, st[CS_XRAY], false);
    vec2 gs = cvGoopShake(st[CS_CLEAR].x);
    for(int k = CS_PRIME + 1; k <= CS_CLEAR + CVZ; k++) col = cvBoothBack(col, k == CS_CLEAR ? q + gs : q, k, st[k]);
    col = cvGoopStains(col, q + gs, st[CS_CLEAR].x);
    col = cvCatapult(col, q, st[CS_PRIME + 1].x);
    col = cvTiltTable(col, q, st[CS_PRIME + 2].x);
    col = cvPolishBack(col, q, st[CS_POLISH]);
    col = cvClassBack(col, q, st[CS_CLASS]);
    col = cvBounceRoom(col, q, cvState(CX_HATFLY, CV_ROW).x);
    col = cvCoronBack(col, q, st[CS_HAT]);

    vec4 sl[AG_TEX];
    agSlots(iChannel17, q, max(asp, 2.3), sl);
    for(int k = 0; k < AG_SLOTS + CVZ; k++){
        int i = int(sl[k >> 2][k & 3] + 0.5) - 1;
        if(i < 0) break;
        col = cvItem(col, q, i);
    }

    col = cvWind(col, q);
    col = cvPistons(col, q);
    col = cvCaustic(col, q, st[CS_CAUSTIC]);
    col = cvHangers(col, q, max(asp, 2.3));
    col = cvFlickArm(col, q, st[CS_FLICK]);
    col = cvDripFront(col, q, max(asp, 2.3));
    col = cvRotor(col, q, st[CS_CAUSTIC]);
    col = cvPours(col, q, st);
    col = cvBasin(col, q, cvState(CX_SPLASH, CV_ROW).xy);
    for(int k = 3; k < 6 + CVZ; k++) col = cvHammer(col, q, k, st[k], jam);
    for(int k = CS_PRESS; k < CS_PRESS + 3 + CVZ; k++) col = cvMouldPress(col, q, k, st[k], jam);
    col = cvArm(col, q, 0, st[CS_WELD1]);
    col = cvArm(col, q, 1, st[CS_WELD2]);
    col = cvXray(col, q, st[CS_XRAY], true);
    col = cvGrinder(col, q, st[CS_GRIND]);
    col = cvBootAt(col, q, cvStPos(CS_BOOT), CVG(17.), st[CS_BOOT].x, st[CS_BOOT].z);
    for(int j = 0; j < 5 + CVZ; j++){
        int k = CV_QC_K[j];
        vec4 kt = cvState(CX_QK + j, CV_ROW);
        float bx = st[k].x >= 0. && cvI(kt.y) == cvI(st[k].y) && kt.z > 0.5 ? st[k].x : -1.;
        col = cvBootAt(col, q, cvStPos(k), cvStPos(k).y + CVG(0.95), bx, kt.x);
    }
    col = cvCoatRing(col, q, st[CS_PRIME + 1].x);
    col = cvPlotter(col, q, st[CS_PRIME + 2].x);
    col = cvGoopCannon(col, q + gs, st[CS_CLEAR].x);
    col = cvColumn(col, q, st, max(asp, 2.3));
    col = cvPolishFront(col, q, st[CS_POLISH]);
    col = cvHatRig(col, q, st[CS_HAT]);
    col = cvHatFly(col, q, cvState(CX_HATFLY, CV_ROW).x);
    col = cvPack(col, q, st, jam);
    col = cvJamLamp(col, q, jam);
    col *= 1. - 0.2 * smoothstep(0.65, 1.3, length((q - vec2(CV_CX, CV_CY)) * vec2(0.8, 1.)));
    col = cvKickedAt(col, q, cvStPos(CS_BOOT), st[CS_BOOT].z, asp, fit, false);
    for(int j = 0; j < 5 + CVZ; j++) col = cvKickedAt(col, q, cvStPos(CV_QC_K[j]), cvState(CX_QK + j, CV_ROW).x, asp, fit, true);
    if((u_traffic_debug & 16) != 0){
        vec2 gc = q / CV_CELL;
        vec2 gd = abs(gc - floor(gc + 0.5)) * CV_CELL;
        vec2 g5 = abs(gc / 5. - floor(gc / 5. + 0.5)) * 5. * CV_CELL;
        float px = 1. / iResolution.y;
        col = mix(col, vec3(0.45, 0.8, 1.), 0.18 * (1. - smoothstep(0., px, min(gd.x, gd.y))));
        col = mix(col, vec3(0.45, 0.8, 1.), 0.35 * (1. - smoothstep(0., 1.5 * px, min(g5.x, g5.y))));
        col = mix(col, vec3(1., 0.5, 0.3), 0.6 * (1. - smoothstep(0., 1.5 * px, min(abs(q.x), abs(q.y)))));
    }
    return col;
}

vec3 conveyor(vec2 q, vec2 tp){ return texture(iChannel18, roomUV(q)).rgb; }
void mainImage(out vec4 fragColor, in vec2 fragCoord){
    int x = int(fragCoord.x), y = int(iResolution.y - fragCoord.y);
    bool fresh;
    float dt = agDt(iChannel9, fresh);
    mpLoad();
    vec4 meta = texelFetch(iChannel9, AG_META, 0);
    float stamp = float(mpWord(gMpBase + 1)) + float(mpWord(gMpBase + 9)) * 0.001 + float(gMpCars) * 10000.;
    if(meta.y != float(u_traffic_map) || meta.z != stamp){ fresh = true; dt = 0.; }
    if(ivec2(x, y) == AG_META){ fragColor = vec4(iTime, float(u_traffic_map), stamp, fresh ? 0. : mod(meta.w + 1., 1024.)); return; }
    if(y < 2){
        if(x >= MP_N){ fragColor = vec4(0.); return; }
        vec4 r0, r1;
        mpStep(iChannel9, x, dt, fresh, r0, r1);
        fragColor = y == 0 ? r0 : r1;
        return;
    }
    if(y == MP_SENSE_ROW){
        fragColor = x < MP_N ? mpSensed(iChannel9, x, fresh) : vec4(0.);
        return;
    }
    if(y >= MP_GATE_ROW && y < MP_GATE_ROW + MP_GATE_ROWS){
        fragColor = fresh ? vec4(0.) : mpGateRow(iChannel9, x + (y - MP_GATE_ROW) * AG_W);
        return;
    }
    if(y == MP_CAR_ROW){
        fragColor = x < MP_N ? mpRemember(iChannel9, x, fresh) : vec4(0.);
        return;
    }
    if(y >= MP_CONG_ROW && y < MP_CONG_ROW + MP_CONG_ROWS){
        int e = x + (y - MP_CONG_ROW) * AG_W;
        fragColor = e >= mpWord(gMpBase + 1) || fresh ? vec4(0.)
                  : (y - MP_CONG_ROW) != int(meta.w) % MP_CONG_ROWS ? texelFetch(iChannel9, ivec2(x, y), 0) : mpCongest(iChannel9, e);
        return;
    }
    if(y < AG_FIELD0){
        fragColor = !fresh && (y - AG_BIN0) % MP_BIN_SLICES != int(meta.w) % MP_BIN_SLICES ? texelFetch(iChannel9, ivec2(x, y), 0)
                  : agBin(iChannel9, x, y - AG_BIN0, gMpCars, mpBinReach(), u_aspect);
        return;
    }

    fragColor = vec4(0.);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
