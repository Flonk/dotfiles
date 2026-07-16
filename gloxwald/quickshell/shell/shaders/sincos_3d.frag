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
#define A(v) mat2(cos(m.v+radians(vec4(0, -90, 90, 0))))  // rotate
#define W(v) length(vec3(p.yz-v(p.x+vec2(0, pi_2)+t), 0))-lt  // wave
//#define W(v) length(p-vec3(round(p.x*pi)/pi, v(t+p.x), v(t+pi_2+p.x)))-lt  // alt wave
#define P(v) length(p-vec3(0, v(t), v(t+pi_2)))-pt  // point

void mainImage(out vec4 C, in vec2 U)
{
  float lt = .1 * (1.0 - 0.2 * sk_attention_envelope()), // line thickness
  pt = .4, // point thickness
  pi = 3.1416,
  pi2 = pi * 2.,
  pi_2 = pi / 2.,
  t = iTime * pi * 0.2,
  s = 1., d = 0., i = d;

  vec2 R = iResolution.xy,
  m = (iMouse.xy - .5 * R) / R.y * 4.;

  vec3 o = vec3(0, 0, -7), // cam
  u = normalize(vec3((U - .5 * R) / R.y, 1)),
  c = vec3(0), k = c, p;

  if (iMouse.z < 1.) m = -vec2(t / 20. - pi_2, 0); // move when not clicking
  mat2 v = A(y), h = A(x); // pitch & yaw

  for (; i++ < 50.; ) // raymarch
  {
    p = o + u * d;
    p.yz *= v;
    p.xz *= h;
    p.x -= 3.; // slide objects to the right a bit
    if (p.y < -1.5) p.y = 2. / p.y; // reflect into neg y
    k.x = min(max(p.x + lt, W(sin)), P(sin)); // sine wave
    k.y = min(max(p.x + lt, W(cos)), P(cos)); // cosine wave
    s = min(s, min(k.x, k.y)); // blend
    if (s < .001 || d > 100.) break; // limits
    d += s * .5;
  }

  // add and color scene
  c = max(cos(d * pi2) - s * sqrt(d) - k, 0.);
  // Pink-trail mask: c.r (sine) dominates over c.g (cosine) in pink regions.
  float pinkMask = smoothstep(0.0, 0.1, c.r - c.g);
  c.gb += .1;
  // Keypulse: boost blue trail (cosine/c.g drives the B output channel) by 10%.
  c.g *= 1.0 + 0.1 * sk_keypulse_envelope();
  vec3 finalColor = c * .4 + c.brg * .6 + c * c;
  // Fail: suppress G and B in pink-trail pixels to shift pink → red.
  float failE = sk_fail_envelope();
  finalColor.g = mix(finalColor.g, finalColor.g * (1.0 - pinkMask * 0.85), failE);
  finalColor.b = mix(finalColor.b, finalColor.b * (1.0 - pinkMask * 0.5), failE);
  C = vec4(finalColor, 1);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
