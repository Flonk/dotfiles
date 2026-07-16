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
// CCO: Colorful underwater bubbles II
//  Recoloring of earlier shader + spherical shading

#define TIME        iTime * .2
#define RESOLUTION  iResolution
#define PI          3.141592654
#define TAU         (2.0*PI)
const float MaxIter = 12.0;

// License: Unknown, author: Unknown, found: don't remember
float hash(float co) {
  return fract(sin(co * 12.9898) * 13758.5453);
}

// License: Unknown, author: Unknown, found: don't remember
float hash(vec2 co) {
  return fract(sin(dot(co.xy, vec2(12.9898, 58.233))) * 13758.5453);
}

// License: MIT OR CC-BY-NC-4.0, author: mercury, found: https://mercury.sexy/hg_sdf/
vec2 mod2(inout vec2 p, vec2 size) {
  vec2 c = floor((p + size * 0.5) / size);
  p = mod(p + size * 0.5, size) - size * 0.5;
  return c;
}

vec4 plane(vec2 p, float i, float zf, float z, vec3 bgcol) {
  float sz = 0.5 * zf;
  vec2 cp = p;
  vec2 cn = mod2(cp, vec2(2.0 * sz, sz));
  float h0 = hash(cn + i + 123.4);
  float h1 = fract(4483.0 * h0);
  float h2 = fract(8677.0 * h0);
  float h3 = fract(9677.0 * h0);
  float h4 = fract(7877.0 * h0);
  float h5 = fract(9967.0 * h0);
  if (h4 < 0.5) {
    return vec4(0.0);
  }
  float fi = exp(-0.25 * max(z - 2.0, 0.0));
  float aa = mix(0.0125, 2.0 / RESOLUTION.y, fi);
  float r = sz * mix(0.1, 0.475, h0 * h0);
  float amp = mix(0.5, 0.5, h3) * r;
  cp.x -= amp * sin(mix(3.0, 0.25, h0) * TIME + TAU * h2);
  cp.x += 0.95 * (sz - r - amp) * sign(h3 - 0.5) * h3;
  cp.y += 0.475 * (sz - 2.0 * r) * sign(h5 - 0.5) * h5;
  float d = length(cp) - r;
  if (d > aa) {
    return vec4(0.0);
  }
  vec3 ocol = (0.5 + 0.5 * sin(vec3(0.0, 1.0, 2.0) + h1 * TAU));
  vec3 icol = sqrt(ocol);
  ocol *= 1.5;
  icol *= 2.0;
  const vec3 lightDir = normalize(vec3(1.0, 1.5, 2.0));
  float z2 = (r * r - dot(cp, cp));
  vec3 col = ocol;
  float t = smoothstep(aa, -aa, d);
  if (z2 > 0.0) {
    float z = sqrt(z2);
    t *= mix(1.0, 0.8, z / r);
    vec3 pp = vec3(cp, z);
    vec3 nn = normalize(pp);
    float dd = max(dot(lightDir, nn), 0.0);

    col = mix(ocol, icol, dd * dd * dd);
  }
  col *= mix(0.8, 1.0, h0);
  col = mix(bgcol, col, fi);
  return vec4(col, t);
}

// License: Unknown, author: Claude Brezinski, found: https://mathr.co.uk/blog/2017-09-06_approximating_hyperbolic_tangent.html
float tanh_approx(float x) {
  //  Found this somewhere on the interwebs
  //  return tanh(x);
  float x2 = x * x;
  return clamp(x * (27.0 + x2) / (27.0 + 9.0 * x2), -1.0, 1.0);
}

vec3 effect(vec2 p, vec2 pp) {
  const vec3 bgcol0 = vec3(0.1, 0.0, 1.0) * 0.1;
  const vec3 bgcol1 = vec3(0.0, 0.4, 1.0) * 0.6;
  vec3 bgcol = mix(bgcol1, bgcol0, tanh_approx(1.5 * length(p)));
  bgcol *= 1.0 + 0.1 * clamp(sk_keypulse_envelope() + sk_load_envelope(), 0.0, 1.0);
  bgcol = mix(bgcol, sk_fail_color, sk_fail_envelope() * 0.5);
  vec3 col = bgcol;

  for (float i = 0.0; i < MaxIter; ++i) {
    const float Near = 4.0;
    float z = MaxIter - i;
    float zf = Near / (Near + MaxIter - i);
    vec2 sp = p;
    float h = hash(i + 1234.5);
    sp.y += -mix(0.2, 0.3, h * h) * TIME * zf;
    sp += h;
    vec4 pcol = plane(sp, i, zf, z, bgcol);
    col = mix(col, pcol.xyz, pcol.w);
  }
  col *= smoothstep(1.5, 0.5, length(pp));
  col = clamp(col, 0.0, 1.0);
  col = sqrt(col);
  return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 q = fragCoord / RESOLUTION.xy;
  vec2 p = -1. + 2. * q;
  vec2 pp = p;
  p.x *= RESOLUTION.x / RESOLUTION.y;
  vec3 col = effect(p, pp);
  fragColor = vec4(col, 1.0);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
