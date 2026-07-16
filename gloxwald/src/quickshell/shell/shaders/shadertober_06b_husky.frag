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
#define MAX_DIST 50.0
#define PI 3.1415927

const float SPEED = 0.2;

//as always, thanks to IQ for sharing this knowledge :)

vec2 rotate(vec2 a, float d) {
  float s = sin(d);
  float c = cos(d);

  return vec2(
    a.x * c - a.y * s,
    a.x * s + a.y * c);
}

float box(vec3 p, vec3 b)
{
  vec3 d = abs(p) - b;
  return length(max(d, 0.0));
}

float husk(vec3 bp, vec3 p)
{
  return box(bp - vec3(0., -2., -4), vec3(10, 3. + cos(p.x + p.z + p.y) / 4. + bp.x / 2., .1));
}

vec2 map(vec3 p)
{
  p.x -= .5;
  vec3 bp = p + vec3(-4., 0., 0);

  bp.yz = rotate(bp.yz, PI * iTime * SPEED / 2.);

  bp.x += ((bp.y * bp.y) + (bp.z * bp.z)) / 8.;
  float b = box(bp, vec3(.1, 2, 2));

  bp.yz = rotate(bp.yz, PI / 4.);

  b = min(b, box(bp, vec3(.1, 2, 2)));

  float stem = box(bp + vec3(.5, 0, 0), vec3(1., .5, .5));

  vec2 st = vec2(atan(p.z, p.y), length(p));

  float x = clamp(.5 + (p.x + 4.5) / 10., 0.0, 1.0);
  float c = length(p / vec3(2.5 - p.x / 10., 1., 1.)) - 2. + (smoothstep(1., -1., abs(cos(iTime * SPEED * 10. + p.x * 10. + .6))) / 10. * x) +
      (smoothstep(1., -1., abs(cos(st.x * 10.))) / 10.) * x;

  float r = min(c, b);
  r = min(r, stem);

  float m = 0.0;

  if (r == c) m = 1.;
  else if (r == b || r == stem) m = 2.;

  return vec2(r, m);
}

vec3 normal(vec3 p)
{
  vec2 e = vec2(0.0001, 0.);
  return normalize(vec3(
      map(p + e.xyy).x - map(p - e.xyy).x,
      map(p + e.yxy).x - map(p - e.yxy).x,
      map(p + e.yyx).x - map(p - e.yyx).x
    ));
}

vec2 ray(vec3 ro, vec3 rd)
{
  float t = 0.0;
  float m = 0.0;

  for (int i = 0; i < 128; i++)
  {
    vec3 p = ro + rd * t;
    vec2 h = map(p);
    m = h.y;
    if (h.x < 0.00001) break;
    t += h.x;
    if (t > MAX_DIST) break;
  }

  if (t > MAX_DIST) t = -1.;

  return vec2(t, m);
}

vec3 color(vec3 p, vec3 n, vec2 t)
{
  vec3 c = vec3(0.);
  vec3 mate = vec3(1.32, 1, 0);
  if (t.y > 1.5)
  {
    mate = vec3(0., .125, 0.);
  }
  vec3 sun = normalize(vec3(0.2, 0.5, -0.5));
  float dif = clamp(dot(n, sun), 0.0, 1.0);
  float sha = step(ray(p + n * .001, sun).x, 0.0);
  float sky = clamp(0.5 + 0.5 * dot(n, vec3(0, 1, 0)), 0., 1.);
  float bou = clamp(0.5 + 0.5 * dot(n, vec3(0, 1, 0)), 0., 1.);

  c = mate * vec3(0.5, 0.6, 0.5) * dif * sha;
  c += mate * vec3(0.2, 0.3, .8) * sky;
  c += mate * vec3(0.2, 0.1, 0.1) * bou;

  return c;
}

vec3 render(vec3 ro, vec3 rd)
{
  vec2 st = vec2(atan(rd.y, rd.x), length(ro));

  vec3 c = vec3(0., .1, 0.) * (.5 + smoothstep(-0., 1., cos(st.x * 40. + iTime * SPEED * 3.)));

  // Background effects: keypulse and attention each add 10% brightness; fail tints to failhue.
  c *= 1.0 + 0.1 * (sk_keypulse_envelope() + sk_attention_envelope());
  c = mix(c, c * sk_fail_color, sk_fail_envelope());

  vec2 t = ray(ro, rd);

  if (t.x > 0.)
  {
    vec3 p = ro + rd * t.x;
    vec3 n = normal(p);

    c = color(p, n, t);
  }
  c = pow(c, vec3(0.454545));

  return c;
}

void mainImage(out vec4 c, in vec2 f)
{
  vec2 uv = (2. * f - iResolution.xy) / iResolution.y;

  float d = 10.;
  vec3 ro = vec3(sin(PI) * d, 0, cos(PI) * d);
  vec3 ta = vec3(0., 0, 0.);
  vec3 camF = normalize(ta - ro);
  vec3 camU = normalize(cross(camF, vec3(0, 1, 0)));
  vec3 camR = normalize(cross(camU, camF));

  vec3 rd = normalize(uv.x * camU + uv.y * camR + 2. * camF);

  c.rgb = render(ro, rd);
  c.a = 1.0;
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
