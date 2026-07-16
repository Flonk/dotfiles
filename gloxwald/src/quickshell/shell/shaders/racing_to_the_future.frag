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
#define SCROLL 2.8
#define SPEED 3.4
const float TIME_SCALE = 0.2;

float ncos(float x)
{
  return cos(x) / (.5 + .4 * abs(cos(x)));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  vec2 s = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
  float T = iTime * TIME_SCALE;
  float v = (s.y + 1.0) * (s.y + 1.0) * 0.25;
  s.y -= 1.2;
  float per = 2.0 / abs(s.y);

  // Pre-compute envelopes outside the loop.
  float keypulseE = sk_keypulse_envelope();
  float attentionE = sk_attention_envelope();

  vec3 col = vec3(0);
  for (float z = 0.0; z < 1.0; z += 0.08)
  {
    float d = 1.0 + 0.4 * z;
    vec2 p = vec2(s.x * d, s.y + d) * per;
    vec2 s = p;
    s.y += SCROLL * T;
    vec2 c = s - 0.05 * T + sin(s * 5.3 + 0.03 * T);

    // Attention: widen highway by up to 30% by spreading lane offsets.
    float shift = cos(z / 0.08) * (1.0 + 0.3 * attentionE);
    float wave = ncos(s.y * 1.4) + ncos(s.y * 0.9 + 0.3 * T);
    s.x += shift + (wave) / (1.0 + 0.01 * per * per);

    float w = s.x;
    float l = sin(s.y * 0.7 + z / 0.08 + SPEED * T * sign(shift));
    float intensity = exp(min(l, -l / 0.3 / (1.0 + 4.0 * w * w)));

    // Cold palette: deep blue -> cyan/ice-white
    vec3 coldA = vec3(0.05, 0.12, 0.45); // deep navy blue
    vec3 coldB = vec3(0.55, 0.85, 1.0); // ice cyan
    vec3 tint = mix(coldA, coldB, tanh(shift / 0.1) * 0.5 + 0.5);

    // Subtle purple shimmer on some strands
    tint += vec3(0.15, 0.0, 0.25) * smoothstep(0.3, 0.7, sin(z * 30.0 + T * 0.7));

    // Keypulse: thicken lines ~10% by shrinking the width denominator.
    col += intensity * tint / (abs(w) * (1.0 - 0.1 * keypulseE) + 0.01 * per) * per;
  }
  col = tanh(col / 2e1);
  // Fail: tint toward fail hue.
  col = mix(col, col * sk_fail_color, sk_fail_envelope());
  fragColor = vec4(col * col, 1);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
