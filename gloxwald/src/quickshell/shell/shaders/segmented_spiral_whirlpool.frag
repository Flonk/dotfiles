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
#define T (iTime*.5)

float gWavinessScale = 1.0; // driven by attention envelope in mainImage
#define A(v) mat2(cos(m.v*3.1416 + vec4(0, -1.5708, 1.5708, 0)))       // rotate
#define H(v) (cos(((v)+.5)*6.2832 + radians(vec3(60, 0, -60)))*.5+.5)  // hue

float sdRoundBox(vec3 p, vec3 b, float r)
{
  vec3 q = abs(p) - b + r;
  return length(max(q, 0.)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float map(vec3 u)
{
  float t = T, // speed
  l = 5., // loop to reduce clipping
  w = 40., // z warp size
  s = .4, // object size (max)
  f = 1e20, i = 0., y, z;

  u.yz = -u.zy;
  u.xy = vec2(atan(u.x, u.y), length(u.xy)); // polar transform
  u.x += t / 6.; // counter rotation

  vec3 p;
  for (; i++ < l; )
  {
    p = u;
    y = round(max(p.y - i, 0.) / l) * l + i; // segment y & skip rows
    p.x *= y; // scale x with rounded y
    p.x -= sqrt(y * t * t * 2.); // move x
    p.x -= round(p.x / 6.2832) * 6.2832; // segment x
    p.y -= y; // move y
    p.z += sqrt(y / w) * w; // curve inner z down
    z = cos(y * t / 50.) * .5 + .5; // radial wave
    p.z += z * 2. * gWavinessScale; // wave z
    p = abs(p);
    //f = min(f, max(p.x, max(p.y, p.z)) - s*z);  // cubes
    f = min(f, sdRoundBox(p, vec3(s * z), .1)); // a bit nicer
  }

  return f;
}

void mainImage(out vec4 C, in vec2 U)
{
  float l = 50., // loop
  i = 0., d = i, s, r;

  vec2 R = iResolution.xy,
  m = iMouse.z > 0. ? // clicking?
    (iMouse.xy - R / 2.) / R.y : // mouse coords
    vec2(0, -.17); // default (noclick)

  // Attention: increase waviness by up to 60%.
  gWavinessScale = 1.0 + 0.6 * sk_attention_envelope();

  vec3 o = vec3(0, 20, -120), // camera
  u = normalize(vec3(U - R / 2., R.y)), // 3d coords
  c = vec3(0), p;

  mat2 v = A(y), // pitch
  h = A(x); // yaw

  for (; i++ < l; ) // raymarch
  {
    p = u * d + o;
    p.yz *= v;
    p.xz *= h;

    s = map(p);
    r = (cos(round(length(p.xz)) * T / 50.) * .7 - 1.8) / 2.; // color gradient
    c += min(s, exp(-s / .08)) // black & white
        * H(r + .5) * (r + 2.4); // color

    if (s < 1e-3 || d > 1e3) break;
    d += s * .7;
  }

  // Keypulse: boost cube brightness by 8%.
  c *= 1.0 + 0.08 * sk_keypulse_envelope();
  // Fail: tint cubes toward fail hue.
  c = mix(c, c * sk_fail_color, sk_fail_envelope());

  C = vec4(exp(log(c) / 2.2), 1);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
