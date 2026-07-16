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
const float PI = acos(-1.);
const float LAYER_DISTANCE = 5.;
const float SPEED = 0.15;

const vec3 BLUE = vec3(47, 75, 162) / 255.;
const vec3 PINK = vec3(233, 71, 245) / 255.;
const vec3 PURPLE = vec3(128, 63, 224) / 255.;
const vec3 CYAN = vec3(61, 199, 220) / 255.;
const vec3 MAGENTA = vec3(222, 51, 150) / 255.;
const vec3 LIME = vec3(160, 220, 70) / 255.;
const vec3 ORANGE = vec3(245, 140, 60) / 255.;
const vec3 TEAL = vec3(38, 178, 133) / 255.;
const vec3 RED = vec3(220, 50, 50) / 255.;
const vec3 YELLOW = vec3(240, 220, 80) / 255.;
const vec3 VIOLET = vec3(180, 90, 240) / 255.;
const vec3 AQUA = vec3(80, 210, 255) / 255.;
const vec3 FUCHSIA = vec3(245, 80, 220) / 255.;
const vec3 GREEN = vec3(70, 200, 100) / 255.;

const int NUM_COLORS = 14;
const vec3 COLS[NUM_COLORS] = vec3[](
    BLUE,
    PINK,
    PURPLE,
    CYAN,
    MAGENTA,
    LIME,
    ORANGE,
    TEAL,
    RED,
    YELLOW,
    VIOLET,
    AQUA,
    FUCHSIA,
    GREEN
  );

// t within the range [0, 1]
vec3 get_color(float t) {
  float scaledT = t * float(NUM_COLORS - 1);

  float curr = floor(scaledT);
  float next = min(curr + 1., float(NUM_COLORS) - 1.);

  float localT = scaledT - curr;
  return mix(COLS[int(curr)], COLS[int(next)], localT);
}

// https://www.shadertoy.com/view/4djSRW
vec4 hash41(float p)
{
  vec4 p4 = fract(vec4(p) * vec4(.1031, .1030, .0973, .1099));
  p4 += dot(p4, p4.wzxy + 33.33);
  return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

float get_height(vec2 id, float layer) {
  float t = iTime * SPEED;

  vec4 h = hash41(layer) * 1000.;

  float o = 0.;
  o += sin((id.x + h.x) * .2 + t) * .3;
  o += sin((id.y + h.y) * .2 + t) * .3;
  o += sin((-id.x + id.y + h.z) * .3 + t) * .3;
  o += sin((id.x + id.y + h.z) * .3 + t) * .4;
  o += sin((id.x - id.y + h.w) * .8 + t) * .1;

  return o;
}

mat2x2 rotate(float r) {
  return mat2x2(cos(r), -sin(r), sin(r), cos(r));
}

float sdSphere(vec3 p, float r) {
  return length(p) - r;
}

float map(vec3 p) {
  float t = iTime * SPEED;
  const float xz = .3;
  vec3 s = vec3(xz, LAYER_DISTANCE, xz);
  vec3 id = round(p / s);

  float ho = get_height(id.xz, id.y);
  p.y += ho;
  p -= s * id;
  return sdSphere(p, smoothstep(1.3, -1.3, ho) * .03 + .0001);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  float seed = 42.0;
  float t = iTime * SPEED;
  vec3 col = vec3(0.);
  vec2 uv = (2. * gl_FragCoord.xy - iResolution.xy) / iResolution.y;
  uv.y *= -1.;

  float phase = t * .2;
  float y = sin(phase);
  float ny = smoothstep(-1., 1., y);
  vec3 c = get_color(mod((t + seed) / float(NUM_COLORS), 5. * 2. * PI) / (5. * 2. * PI));

  vec3 ro = vec3(0., y * LAYER_DISTANCE * .5, -t);
  vec3 rd = normalize(vec3(uv, -1.));

  rd.xy *= rotate(-ny * PI);
  rd.xz *= rotate(sin(t * .5) * .4);

  float d = 0.;
  for (int i = 0; i < 30; ++i) {
    vec3 p = ro + rd * d;

    float dt = map(p);
    dt = max(dt * (cos(ny * PI * 2.) * .3 + .5), 1e-3);

    col += (.1 / dt) * c;
    d += dt * .8;
  }

  col = tanh(col * .01);

  fragColor = vec4(col, 1.);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
