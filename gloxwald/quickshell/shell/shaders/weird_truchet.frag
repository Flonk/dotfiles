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
/**

    License: Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License

    Corne Keyboard Test Shader
    11/26/2024  @byt3_m3chanic

    Got this tiny Corne knock-off type keyboard from Amazon - 36 key
    So this is me trying to code a shader, and memorize the key
    combos for the special/math chars.

    see keyboard here:
    https://bsky.app/profile/byt3m3chanic.bsky.social/post/3lbsqbatwjc2q

*/

#define R           iResolution
const float SPEED = 0.2;
#define T           (iTime * SPEED)
#define M           iMouse

#define PI         3.14159265359
#define PI2        6.28318530718

mat2 rot(float a) {
  return mat2(cos(a), sin(a), -sin(a), cos(a));
}
vec3 palette(float t) {
  t = fract(t);
  vec3 c0 = vec3(0.020, 0.098, 0.216); // #051937
  vec3 c1 = vec3(0.000, 0.302, 0.478); // #004d7a
  vec3 c2 = vec3(0.000, 0.529, 0.576); // #008793
  vec3 c3 = vec3(0.000, 0.749, 0.447); // #00bf72
  vec3 c4 = vec3(0.659, 0.922, 0.071); // #a8eb12
  float s = t * 5.0;
  float f = fract(s);
  int i = int(s);
  if (i == 0) return mix(c0, c1, f);
  if (i == 1) return mix(c1, c2, f);
  if (i == 2) return mix(c2, c3, f);
  if (i == 3) return mix(c3, c4, f);
  return mix(c4, c0, f);
}
float hash21(vec2 a) {
  return fract(sin(dot(a, vec2(27.69, 32.58))) * 43758.53);
}
float box(vec2 p, vec2 b) {
  vec2 d = abs(p) - b;
  return length(max(d, 0.)) + min(max(d.x, d.y), 0.);
}
mat2 r90;
vec2 pattern(vec2 p, float sc) {
  vec2 uv = p;
  vec2 id = floor(p * sc);
  p = fract(p * sc) - .5;

  float rnd = hash21(id);

  // turn tiles
  if (rnd > .5) p *= r90;
  rnd = fract(rnd * 32.54);
  if (rnd > .4) p *= r90;
  if (rnd > .8) p *= r90;

  // randomize hash for type
  rnd = fract(rnd * 47.13);

  float tk = .075;
  // kind of messy and long winded
  float d = box(p - vec2(.6, .7), vec2(.25, .75)) - .15;
  float l = box(p - vec2(.7, .5), vec2(.75, .15)) - .15;
  float b = box(p + vec2(0, .7), vec2(.05, .25)) - .15;
  float r = box(p + vec2(.6, 0), vec2(.15, .05)) - .15;
  d = abs(d) - tk;

  if (rnd > .92) {
    d = box(p - vec2(-.6, .5), vec2(.25, .15)) - .15;
    l = box(p - vec2(.6, .6), vec2(.25)) - .15;
    b = box(p + vec2(.6, .6), vec2(.25)) - .15;
    r = box(p - vec2(.6, -.6), vec2(.25)) - .15;
    d = abs(d) - tk;
  } else if (rnd > .6) {
    d = length(p.x - .2) - tk;
    l = box(p - vec2(-.6, .5), vec2(.25, .15)) - .15;
    b = box(p + vec2(.6, .6), vec2(.25)) - .15;
    r = box(p - vec2(.3, 0), vec2(.25, .05)) - .15;
  }

  l = abs(l) - tk;
  b = abs(b) - tk;
  r = abs(r) - tk;

  float e = min(d, min(l, min(b, r)));

  if (rnd > .6) {
    r = max(r, -box(p - vec2(.2, .2), vec2(tk * 1.3)));
    d = max(d, -box(p + vec2(-.2, .2), vec2(tk * 1.3)));
  } else {
    l = max(l, -box(p - vec2(.2, .2), vec2(tk * 1.3)));
  }

  d = min(d, min(l, min(b, r)));

  return vec2(d, e);
}
void mainImage(out vec4 O, in vec2 F)
{
  vec3 C = vec3(.0);
  vec2 uv = (2. * F - R.xy) / max(R.x, R.y);
  r90 = rot(1.5707);

  uv *= rot(T * .095);
  //@Shane
  uv = vec2(log(length(uv)), atan(uv.y, uv.x) * 6. / PI2);
  // Original.
  //uv = vec2(log(length(uv)), atan(uv.y, uv.x))*8./6.2831853;

  float scale = 8.;
  for (float i = 0.; i < 4.; i++) {
    float ff = (i * .05) + .2;

    uv.x += T * ff;

    float px = fwidth(uv.x * scale);
    vec2 d = pattern(uv, scale);
    vec3 clr = palette(sin(uv.x + (i * 8.)) * .5 + .5);
    C = mix(C, vec3(.001), smoothstep(px, -px, d.y - .04));
    C = mix(C, clr, smoothstep(px, -px, d.x));
    scale *= .5;
  }

  // Output to screen
  C = pow(C, vec3(.4545));
  O = vec4(C, 1.0);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
