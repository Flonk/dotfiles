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
// CC0: Superquadric reflections
//  Everyone likes cool reflections, and a key part I find is having a cool
//  "skybox". I experimented with using a reflective inner superquadric
//  (4th degree) and felt it turned out quite nice.
//  Sharing this in the hope it helps someone.

// This is a multipart shader:
//  Buffer A - The main effect
//  Image   - FXAA post-processing to remove some aliasing artifacts

const float SPEED = 0.3;

// For a slight variant in geometry and reflections: https://www.shadertoy.com/view/ffSGzy

#define ROT(a)      mat2(cos(a), sin(a), -sin(a), cos(a))

#define NEW_THEME

#ifdef NEW_THEME
const float
MaxDistance = 9., MinA = .05, ColorOffset = 2.;

const vec3
LightDir = normalize(vec3(1, -2, -1)), ColorBase = 9. + vec3(3, 1, 0);
#else
const float
MaxDistance = 9., ColorOffset = 1.1, MinA = .05;

const vec3
LightDir = normalize(vec3(1, -2, -1)), ColorBase = .5 + vec3(0, 1, 2);
#endif

// License: Unknown, author: Matt Taylor (https://github.com/64), found: https://64.github.io/tonemapping/
vec3 aces_approx(vec3 v) {
  const float
  a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
  v = max(v, 0.);
  v *= .6;
  return clamp((v * (a * v + b)) / (v * (c * v + d) + e), 0., 1.);
}

// License: Unknown, author: nmz (twitter: @stormoid), found: https://www.shadertoy.com/view/NdfyRM
vec3 sRGB(vec3 t) {
  return mix(1.055 * pow(t, vec3(1. / 2.4)) - 0.055, 12.92 * t, step(t, vec3(0.0031308)));
}

// License: MIT, author: Inigo Quilez, found: https://www.iquilezles.org/www/articles/smin/smin.htm
float pmin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

float pmax(float a, float b, float k) {
  return -pmin(-a, -b, k);
}

float L4(vec3 p) {
  return sqrt(length(p * p));
}

float L8(vec3 p) {
  p *= p;
  return sqrt(sqrt(length(p * p)));
}

// License: MIT, author: Inigo Quilez, https://iquilezles.org/articles/intersectors/
float ray_issphere4(vec3 ro, vec3 rd, float ra) {
  // Tweaked to return the inner surface
  float
  r2 = ra * ra;

  vec3
  d2 = rd * rd, d3 = d2 * rd, o2 = ro * ro, o3 = o2 * ro;

  float
  ka = 1. / dot(d2, d2), k3 = ka * dot(ro, d3), k2 = ka * dot(o2, d2), k1 = ka * dot(o3, rd), k0 = ka * (dot(o2, o2) - r2 * r2), c2 = k2 - k3 * k3, c1 = k1 + 2. * k3 * k3 * k3 - 3. * k3 * k2, c0 = k0 - 3. * k3 * k3 * k3 * k3 + 6. * k3 * k3 * k2 - 4. * k3 * k1, p = c2 * c2 + c0 / 3., q = c2 * c2 * c2 - c2 * c0 + c1 * c1, h = q * q - p * p * p;

  if (h < 0.) return -1.;

  float
  sh = sqrt(h), s = sign(q + sh) * pow(abs(q + sh), 1. / 3.), t = sign(q - sh) * pow(abs(q - sh), 1. / 3.);

  vec2
  w = vec2(s + t, s - t), v = vec2(w.x + c2 * 4.0, w.y * sqrt(3.0)) * 0.5;

  float
  r = length(v);

  return abs(v.y) / sqrt(r + v.x) - c1 / r - k3;
}

mat2 g_R0;
mat2 g_R1;

float df(vec3 p) {
  p.xy *= g_R1;
  p.xz *= g_R0;
  p.yz *= g_R1;
  vec3
  s = sin(39. * p);
  float
  d = L8(p) - 1.0, d1 = L4(abs(p) - .7) - .45, S;
  S = .5 + .5 * s.x * s.y * s.z;
  S *= S;
  S *= S;
  S *= S;
  S *= S;
  d += 3e-3 * S;
  d = pmax(d, .05 - d1, .05);
  return d;
}

vec3 normal(vec3 p) {
  vec2 e = vec2(1e-3, -1e-3);
  return normalize(
    e.xyy * df(p + e.xyy)
      + e.yyx * df(p + e.yyx)
      + e.yxy * df(p + e.yxy)
      + e.xxx * df(p + e.xxx)
  );
}

float march(vec3 P, vec3 I) {
  const int max_iter = 77;
  float
  d, z = 0., nz = 0., nd = 1e3;

  int i;

  for (i = 0; i < max_iter; ++i) {
    d = df(z * I + P);
    if (d < 1e-3 || z > MaxDistance) break;
    if (d < nd) {
      nd = d;
      nz = z;
    }
    z += d;
  }

  if (i == max_iter) {
    z = nz;
  }

  return z;
}

vec3 render_inner_reflections(float A, vec3 RO, vec3 RI) {
  float
  f, i, z;

  vec3
  n, p, r, O = vec3(0);

  for (i = 0.; i < 3. && A > MinA; ++i) {
    z = ray_issphere4(RO, RI, 5.);
    p = z * RI + RO;
    n = -normalize(p * p * p);
    r = reflect(RI, n);
    f = 1. + dot(n, RI);
    f *= f;
    if (z > 0.) {
      O += A * pow(max(0., dot(n, LightDir)), 9.) * (ColorOffset + sin(-f + ColorBase));
    } else {
      break;
    }
    A *= mix(.3, .7, f);
    RI = r;
    RO = p + 2e-3 * n;
  }

  return O;
}

vec3 render(vec2 p2, vec3 RO, vec3 RI) {
  float
  i, f, z, A = 1.;

  vec3
  o = vec3(0), p, n, r, P = RO;

  const float
  max_bounce = 4.;

  for (i = 0.; i < max_bounce && A > MinA; ++i) {
    z = march(P, RI);
    p = z * RI + P;
    n = normal(p);
    r = reflect(RI, n);
    f = 1. + dot(n, RI);
    f *= f;
    if (z >= MaxDistance) break;
    A *= mix(.3, .7, f);
    RI = r;
    P = p + .015 * (n);
  }

  if (i > 0. && i < max_bounce && A > MinA)
    o += render_inner_reflections(A, P, RI);
  #ifdef NEW_THEME
  else if (i == 0.)
    o += 1e-3 / dot(p2, p2) * (ColorOffset - 1. + sin(ColorBase));
  #endif

  return o;
}

void mainImage(out vec4 O, vec2 C) {
  float
  T = iTime * SPEED;

  vec2
  R = iResolution.xy, p2 = (-R + 2. * C) / R.y;

  vec3
  o, RO = vec3(0, 0, -4), RI = normalize(vec3(p2, 2));

  g_R0 = ROT(.123 * T);
  g_R1 = ROT(.234 * T);

  o = render(p2, RO, RI);

  o *= 11.;

  o = aces_approx(o);
  o = sRGB(o);

  O = vec4(o, 1);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
