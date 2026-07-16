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
float InPattern(vec2 coord)
{
  float repeatOnY = 5.;

  // We expand the space along y axis from 0..1 to 0..repeatOnY (increase density)
  // then fract abstracts away the point's relation to the origin
  // now two points (0.5,2.5) and (1.5,3.5) are the same (0.5, 0.5)
  vec2 local = fract(coord * repeatOnY);

  vec2 d = local - .5; // 0.5 being the local center
  float loadZoom = max(0.0, iTime - u_auth_started_time) * 1.5 * sk_load_envelope();
  float dist = length(d) / (1.0 + sk_keypulse_envelope() * 0.3 + loadZoom);
  float time = iTime * 0.3;
  float speed = 1.2;
  float maxRingCount = 3.;
  float thickness = 1.; // More like thin-ness
  float padding = thickness;

  // Multiplying the input of the sin function by a scaler increases the frequency of the wave
  // Then we add one to offset the range from -1..1 to 0..2 to avoid negatives
  // Then we multiply this by a scaler that increases the density of local space (or dist specifically)
  // In the end we add some padding to offset threshold range so discs don't cover the entire screen
  float threshold = (maxRingCount * (1. + sin(time * speed))) + padding;

  // Multiplying threshold scales dist over a larger range
  // Which we then normalize/abstract to get multiple bands
  // of value in range 0..1
  float ringPattern = sin(dist * threshold * 6.2831) + 1.;

  // Values between 0..thickness are made negative,
  // now we have signed distances
  return ringPattern - thickness;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  // The coordinate range
  // along y axis is shrunk to range 0..1
  // along x axis is shrunk to range 0..some multiple of iRes.y
  // basically preserving aspect ratio by using y as reference
  vec2 uv = fragCoord / iResolution.y;

  // Get the signed distance
  float d = InPattern(uv);

  // Get a value in range 0..1 based on
  // how far d is from the edge (as a factor of derivative of d)
  // i.e. input to smoothstep is closer to 0 near the edge
  // and smoothstep smoothly clamps that into 0..1 range
  float t = smoothstep(-1., 1., d / fwidth(d));

  // Mix the two color based on the factor
  vec3 color1 = vec3(1.0, 0.7, 0.2);
  vec3 color2 = vec3(1.0, 1.0, 1.0);

  vec3 finalColor = mix(color1, color2, t);
  finalColor = mix(finalColor, sk_fail_color, sk_fail_envelope() * 0.8);

  fragColor = vec4(finalColor, 1.0);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
