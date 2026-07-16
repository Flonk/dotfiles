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
vec4 extractAlpha(vec3 colorIn)
{
  vec4 colorOut;
  float maxValue = min(max(max(colorIn.r, colorIn.g), colorIn.b), 1.0);
  if (maxValue > 1e-5)
  {
    colorOut.rgb = colorIn.rgb * (1.0 / maxValue);
    colorOut.a = maxValue;
  }
  else
  {
    colorOut = vec4(0.0);
  }
  return colorOut;
}

#define BG_COLOR (vec3(sin(iTime)*0.5+0.5) * 0.0 + vec3(0.0))
#define time iTime
const vec3 color1 = vec3(0.611765, 0.262745, 0.996078);
const vec3 color2 = vec3(0.298039, 0.760784, 0.913725);
const vec3 color3 = vec3(0.062745, 0.078431, 0.600000);
const float innerRadius = 0.6;
const float noiseScale = 0.65;

float light1(float intensity, float attenuation, float dist)
{
  return intensity / (1.0 + dist * attenuation);
}
float light2(float intensity, float attenuation, float dist)
{
  return intensity / (1.0 + dist * dist * attenuation);
}

void draw(out vec4 _FragColor, in vec2 vUv)
{
  vec2 uv = vUv * 1.7;
  float ang = atan(uv.y, uv.x);
  float len = length(uv);
  float v0, v1, v2, v3, cl;
  float r0, d0, n0;
  float r, d;

  float flash = sk_keypulse_envelope();
  float failPulse = sk_fail_envelope();
  float authDelay = max((iTime - u_auth_started_time) - 0.08, 0.0);
  float authSpin = sk_load_envelope();

  float radiusPulse = 1.0 + sk_attention_envelope() * 0.3;

  float brightPulse = 1.0 + flash * 1.4 + sk_attention_envelope() * 0.15;

  // scale UVs so the ring expands outward uniformly
  uv /= radiusPulse;
  len = length(uv);

  // ring
  vec2 noiseUv = fract(uv * noiseScale * 0.08 + vec2(time * 0.015, -time * 0.02));
  vec4 noiseTex = texture(iChannel0, noiseUv);
  n0 = noiseTex.r;
  r0 = mix(mix(innerRadius, 1.0, 0.4), mix(innerRadius, 1.0, 0.6), n0);
  d0 = distance(uv, r0 / len * uv);
  v0 = light1(1.0, 10.0, d0) * brightPulse;
  v0 *= smoothstep(r0 * 1.05, r0, len);
  cl = cos(ang + time * 2.0) * 0.5 + 0.5;

  // high light
  float a = -time * mix(1.0, 8.0, authSpin);
  vec2 pos = vec2(cos(a), sin(a)) * r0;
  d = distance(uv, pos);
  v1 = light2(1.5, 5.0, d);
  v1 *= light1(1.0, 50.0, d0);
  float loadingSweep = authSpin * pow(max(cos(ang - authDelay * 6.0), 0.0), 18.0);
  v1 += loadingSweep * (0.18);

  // back decay
  v2 = smoothstep(1.0, mix(innerRadius, 1.0, n0 * 0.5), len);

  // hole
  v3 = smoothstep(innerRadius, mix(innerRadius, 1.0, 0.5), len);

  // color
  vec3 failColor = vec3(1.0, 0.08, 0.08);
  vec3 authColor = vec3(0.95, 0.98, 1.0);
  vec3 ringColor = mix(mix(color1, color2, cl), failColor, failPulse * 0.85);
  vec3 baseColor = mix(color3, failColor * 0.45, failPulse * 0.75);
  vec3 col = mix(baseColor, ringColor, v0);
  col = mix(col, failColor, failPulse * 0.25);
  col = mix(col, authColor, loadingSweep * 0.3);
  col = (col + v1) * v2 * v3;
  col.rgb = clamp(col.rgb, 0.0, 1.0);

  _FragColor = extractAlpha(col);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  vec2 uv = (fragCoord * 2. - iResolution.xy) / iResolution.y;

  vec4 col;
  draw(col, uv);

  vec3 bg = BG_COLOR;

  fragColor.rgb = mix(bg, col.rgb, col.a);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
