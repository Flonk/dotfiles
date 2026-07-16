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
// SPDX-License-Identifier: CC-BY-NC-SA-4.0
// Copyright (c) 2026 @WorkingClassHacker
//[LICENSE] https://creativecommons.org/licenses/by-nc-sa/4.0/

// SPDX-License-Identifier: CC-BY-NC-SA-4.0
// Based on Abstract Shine by @Frosbyte
// Copyright (c) 2026 @Frostbyte

// Rotation matrix using cosine phase offsets.
// cos(a+33) ≈ -sin(a)
// cos(a+11) ≈  sin(a)
// compact 2D rotation without sin().
// Approximates sin within an invisible margin for animated graphics

#define R(a) mat2(cos(a+vec4(0, 33, 11, 0)))

// IQ`s continuous cosine palette (MIT)
// produces smooth, periodic color gradients
// https://www.shadertoy.com/view/ll2GD3

vec3 palette(float i) {
  const vec3 a = vec3(0.50, 0.38, 0.26); // base tone (warm midtone)
  const vec3 b = vec3(0.50, 0.35, 0.25); // amplitude (vibrance)
  const vec3 c = vec3(1.00); // frequency (cyclic complexity)
  const vec3 d = vec3(0.00, 0.12, 0.25); // phase offsets (hue shift)
  return a + b * cos(6.2831853 * (c * i + d));
}

vec3 palette2(float i) {
  const vec3 a = vec3(0.742702f, 0.908877f, 0.959831f);
  const vec3 b = vec3(-0.711000f, 0.275000f, -0.052000f);
  const vec3 c = vec3(1.000000f, 1.855000f, 1.000000f);
  const vec3 d = vec3(0.180000f, 0.091000f, 0.380000f);
  return a + b * cos(6.2831853f * (c * i + d));
}

const float SPEED = 0.2;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  // pixel coordinate
  vec2 u = fragCoord.xy;

  // normalized screen space centered at origin
  // (useful for screen-space modulation later)
  vec2 uv = (u - 0.5 * iResolution.xy + 0.5) / iResolution.y;

  float i, s;
  float t = mod(iTime * SPEED, 6.283185);

  vec3 p;

  // ray direction through pixel (camera ray)
  vec3 d = normalize(vec3(
        2.0 * u - iResolution.xy,
        iResolution.y
      ));

  // starting depth → creates forward motion
  p.z = t;

  // raymarch loop
  for (fragColor *= i; i < 20.0; i++)
  {
    // depth-dependent rotation
    // produces corkscrew tunnel motion
    p.xy *= R(-p.z * 0.01 - t * 0.05);

    // base step size
    s = 0.6;

    // cylindrical confinement
    // creates tunnel boundary at radius ≈ 10
    s = max(s, 4.0 * (-length(p.xy) + 10.0));

    // organic deformation field
    // adds flow & energy patterns
    s += abs(
        p.y * 0.004 + // slight tilt
          sin(t - p.x * 0.5) * 0.9 + // traveling wave
          1.0 // baseline thickness
      );

    // march ray forward
    p += d * s;

    // volumetric glow accumulation
    fragColor += 1.0 / (s * 0.2);
  }

  // apply palette based on final ray distance
  // length(p) approximates depth travelled
  // gives depth-dependent coloration
  // divisor controls the palette scaling - try messing with it!
  // try swapping to palette2 here!
  fragColor *= vec4(palette(length(p) / (abs(sin(iTime * SPEED * 0.02) * 50.) + 6.0)), 1.0);

  // time-gated screen-space shimmer / interference layer
  float dotPulse = 1.0 + 0.3 * clamp(sk_keypulse_envelope() + sk_load_envelope(), 0.0, 1.0);
  fragColor -= 20.0 *
      smoothstep(
        .001,
        abs(sin(iTime * SPEED * 5.0)), // pulsating dots, in a demo I would sync this to beat
        .7 - length(sin(uv * 200.0 / dotPulse) / 1.5) - abs(uv.y) + .2 // high-frequency pattern
      );

  // brightness normalization
  fragColor /= 0.5e2;

  // radial gradient
  float l = length(uv);

  // vignette
  fragColor *= 1.2 - l;

  // center glow

  fragColor = mix(fragColor, palette(l - .23).rgbr, 1.0 - smoothstep(.01, .95, l));

  // soft highlight compression
  fragColor = tanh(fragColor + fragColor);
  fragColor.rgb = mix(fragColor.rgb, sk_fail_color, sk_fail_envelope() * 0.5);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
