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

// Inspired by https://pin.it/58rSwdSFd
const float SPEED = 0.3;
const vec3 BLACK = vec3(0.);
const vec3 TURQUOISE = vec3(3, 229, 243) / 255.;
const vec3 BLUE = vec3(35, 125, 195) / 255.;
const vec3 GREEN = vec3(0, 79, 83) / 255.;

const float PI = acos(-1.);

mat2 rotate(float r) {
  return mat2(cos(r), sin(r), -sin(r), cos(r));
}

// https://www.shadertoy.com/view/4djSRW
vec2 hash21(float p)
{
  vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

vec3 hash32(vec2 p)
{
  vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
  p3 += dot(p3, p3.yxz + 33.33);
  return fract((p3.xxy + p3.yzz) * p3.zyx);
}

vec3 layer(float zoom) {
  vec2 h21 = hash21(zoom);
  float t = iTime * SPEED;
  vec2 uv = zoom * (2. * gl_FragCoord.xy - iResolution.xy) / iResolution.y;

  uv.x -= t + h21.x * 999.;

  vec2 s = vec2(2.);
  vec2 id = round(uv / s);
  vec3 h32 = hash32(id);

  if (h32.x >= 0.7) {
    vec2 phase = h32.yz * 100. + t + h21 * 100.;
    vec2 tv = uv + vec2(cos(phase.x), sin(phase.y)) * .5;
    id = round(tv / s);
    vec2 p = tv - s * id;

    float presence = sin(id.x + t * 2.) * .5 + .5;

    float r = .4 + h21.y * .2 - .1;
    float r2 = r * (smoothstep(.2, 10. + sin(t * .2) * 8., zoom * .5) * .6 + .2);
    float m = smoothstep(r, r2, length(p));

    vec3 col = vec3(0.);
    if (h32.y < 0.2) {
      col = TURQUOISE;
    } else if (h32.y < 0.7) {
      col = BLUE;
    } else {
      col = GREEN;
    }

    return col * m * presence;
  }

  return vec3(0.);
}

float line(float offset) {
  float t = iTime * SPEED;
  vec2 uv = (2. * gl_FragCoord.xy - iResolution.xy) / iResolution.y;

  uv *= rotate(-PI * .2);
  uv.y += sin(uv.x * 2. + t * .05) * .1;

  float tubeSpread = .3 * (1.0 + sk_attention_envelope() * 0.5);
  uv.y += sin((uv.x * .5 + offset) * .9 + t * .1) * tubeSpread;

  float thickness = .02 * (1.0 + sk_keypulse_envelope() * 0.1);
  return thickness / (abs(uv.y) + 5. * smoothstep(0., 30., abs(uv.x)));
}

vec3 background_color() {
  float t = iTime * SPEED * .5;
  vec3 col = vec3(0.);
  vec2 uv = (2. * gl_FragCoord.xy - iResolution.xy) / iResolution.y;

  uv *= rotate(PI * .25);

  uv.y *= .5;
  col += mix(GREEN, BLACK, sin(uv.y + t) * .5 + .5);
  col += mix(BLUE * .5, BLACK, sin(uv.y + t + PI) * .5 + .5);

  return col * .5;
}
void mainImage(out vec4 fragColor, vec2 fragCoord) {
  float t = iTime * SPEED;
  float rel_x = gl_FragCoord.x / iResolution.x;
  float fade_in = max(smoothstep(-.5, .5, rel_x), .1);
  float fade_out = max(smoothstep(1.5, .5, rel_x), .1);

  vec3 base_color = background_color();
  vec3 col = base_color;

  float zoom = 2.;
  const int amount_layers = 5;
  for (int i = 0; i < amount_layers; i++) {
    col += layer(zoom);

    zoom *= 2.;
  }

  vec3 line_color = mix(base_color, sk_fail_color, sk_fail_envelope());
  for (int i = 0; i < 8; ++i) {
    col += line(PI * (2. / 8.) * float(i)) * line_color;
  }

  col *= fade_in * fade_out;

  fragColor = vec4(col, 1.);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
