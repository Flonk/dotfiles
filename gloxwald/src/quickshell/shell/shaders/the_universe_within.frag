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
// The Universe Within - by Martijn Steinrucken aka BigWings 2018
// Email:countfrolic@gmail.com Twitter:@The_ArtOfCode
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.

// After listening to an interview with Michael Pollan on the Joe Rogan
// podcast I got interested in mystic experiences that people seem to
// have when using certain psycoactive substances.
//
// For best results, watch fullscreen, with music, in a dark room.
//
// I had an unused 'blockchain effect' lying around and used it as
// a base for this effect. Uncomment the SIMPLE define to see where
// this came from.
//
// Use the mouse to get some 3d parallax.

// Music - Terrence McKenna Mashup - Jason Burruss Remixes
// https://soundcloud.com/jason-burruss-remixes/terrence-mckenna-mashup
//
// YouTube video of this effect:
// https://youtu.be/GAhu4ngQa48
//
// YouTube Tutorial for this effect:
// https://youtu.be/3CycKKJiwis

const float SPEED = 0.5;

#define S(a, b, t) smoothstep(a, b, t)
#define NUM_LAYERS 4.

//#define SIMPLE

float N21(vec2 p) {
  vec3 a = fract(vec3(p.xyx) * vec3(213.897, 653.453, 253.098));
  a += dot(a, a.yzx + 79.76);
  return fract((a.x + a.y) * a.z);
}

vec2 GetPos(vec2 id, vec2 offs, float t) {
  float n = N21(id + offs);
  float n1 = fract(n * 10.);
  float n2 = fract(n * 100.);
  float a = t + n;
  return offs + vec2(sin(a * n1), cos(a * n2)) * .4;
}

float GetT(vec2 ro, vec2 rd, vec2 p) {
  return dot(p - ro, rd);
}

float LineDist(vec3 a, vec3 b, vec3 p) {
  return length(cross(b - a, p - a)) / length(p - a);
}

float df_line(in vec2 a, in vec2 b, in vec2 p)
{
  vec2 pa = p - a, ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0., 1.);
  return length(pa - ba * h);
}

float line(vec2 a, vec2 b, vec2 uv) {
  float r1 = .04;
  float r2 = .01;

  float d = df_line(a, b, uv);
  float d2 = length(a - b);
  float fade = S(1.5, .5, d2);

  fade += S(.05, .02, abs(d2 - .75));
  return S(r1, r2, d) * fade;
}

float NetLayer(vec2 st, float n, float t) {
  vec2 id = floor(st) + n;

  st = fract(st) - .5;

  vec2 p[9];
  int i = 0;
  for (float y = -1.; y <= 1.; y++) {
    for (float x = -1.; x <= 1.; x++) {
      p[i++] = GetPos(id, vec2(x, y), t);
    }
  }

  float m = 0.;
  float sparkle = 0.;

  for (int i = 0; i < 9; i++) {
    m += line(p[4], p[i], st);

    float d = length(st - p[i]);

    float s = (.005 / (d * d));
    s *= S(1., .7, d);
    float pulse = sin((fract(p[i].x) + fract(p[i].y) + t) * 5.) * .4 + .6;
    pulse = pow(pulse, 20.);

    s *= pulse;
    sparkle += s;
  }

  m += line(p[1], p[3], st);
  m += line(p[1], p[5], st);
  m += line(p[7], p[5], st);
  m += line(p[7], p[3], st);

  float sPhase = (sin(t + n) + sin(t * .1)) * .25 + .5;
  sPhase += pow(sin(t * .1) * .5 + .5, 50.) * 5.;
  m += sparkle * sPhase; //(*.5+.5);

  return m;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  vec2 uv = (fragCoord - iResolution.xy * .5) / iResolution.y;
  vec2 M = iMouse.xy / iResolution.xy - .5;

  float t = iTime * SPEED * .1;

  float s = sin(t);
  float c = cos(t);
  mat2 rot = mat2(c, -s, s, c);
  vec2 st = uv * rot;
  M *= rot * 2.;

  float m = 0.;
  for (float i = 0.; i < 1.; i += 1. / NUM_LAYERS) {
    float z = fract(t + i);
    float size = mix(15., 1., z);
    float fade = S(0., .6, z) * S(1., .8, z);

    m += fade * NetLayer(st * size - M * z, i, iTime * SPEED);
  }

  float fft = texelFetch(iChannel0, ivec2(.7, 0), 0).x;
  float glow = -uv.y * fft * 2.;

  vec3 baseCol = vec3(s, cos(t * .4), -sin(t * .24)) * .4 + .6;
  vec3 col = baseCol * m;
  col += baseCol * glow;

  #ifdef SIMPLE
  uv *= 10.;
  col = vec3(1) * NetLayer(uv, 0., iTime * SPEED);
  uv = fract(uv);
  //if(uv.x>.98 || uv.y>.98) col += 1.;
  #else
  col *= 1. - dot(uv, uv);
  t = mod(iTime * SPEED, 230.);
  col *= S(0., 20., t) * S(224., 200., t);
  #endif

  fragColor = vec4(col, 1);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
