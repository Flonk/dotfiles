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
// view distance
//   determines how far a ray can travel from the camera
#define FAR 50.0

// grid scale
//   inverse of the voxel size
//   controls the density of stars
#define SCALE 0.3

// brightness falloff; prevents stars from instantly popping
// into existence at the far distance
//   FALLOFF < 0 : sharp falloff near camera
//   FALLOFF > 0 : relatively constant until near far distance
#define FALLOFF 0.01

// star radius
//   used for distance sampling
//   should be <= (1 / SCALE) / 2 to ensure 1 star per voxel
#define RADIUS 1e-2

// star pixel radius
//   used for rendering
//   maximum screen-space star radius (in pixels)
#define MAX_RADIUS 5.0

// star jitter
//   the magnitude of the random offset for each star in their
//   respective voxels
//   JITTER <= 0.5 - RADIUS : guaranteed to render all stars
//   JITTER >  0.5 - RADIUS : more variation; some stars not rendered
#define JITTER (1.0 - RADIUS)

// camera speed
//   how fast the camera traverses its path
#define SPEED 0.2

// camera focal length
//   controls the field of view of the camera
#define FOCAL_LENGTH 1.5

// screen height (in px) that diffraction spike parameters are
// relative to
//   effectively decouples diffraction spike parameters from
//   the screen resolution
//   (default value of 1013px is arbitrary)
#define REFERENCE_HEIGHT 1013.0

// diffraction spike strength
//   multiplier for diffraction spike brightness
#define DIFFRACTION_STRENGTH 1.2

// diffraction spike spread
//   effectively scales the diffraction spikes
#define DIFFRACTION_SPREAD 3.0

// number of diffraction spike samples
//   larger values make longer spikes
#define DIFFRACTION_SAMPLES 12

// diffraction spike attenuation
//   determines how quickly diffraction spikes fade with distance
//   should be in the range [0, 1]
#define DIFFRACTION_ATTENUATION 0.4

// minimum & maximum temperatures for calculating blackbody emission
#define BLACKBODY_MIN 5000.0
#define BLACKBODY_MAX 15000.0

// dust color
//   accumulated over voxels for volumetric variation
const vec3 DUST_COLOR = vec3(0.1, 0.2, 0.4) * 1e-4;

// optimizing constants
const float E_BD = exp(FALLOFF * FAR);
const float IRE_BD = 1.0 / (1.0 - E_BD);
const float IS = 1.0 / SCALE;
const int MAX_STEPS = int(ceil(FAR * SCALE)) * 3; // worst-case diagonal ray
const float IDSF = 1.0 / float(DIFFRACTION_SAMPLES);

float hash31(in vec3 p)
{
  p = fract(p * 0.1031);
  p += dot(p, p.yzx + 33.33);
  return fract((p.x + p.y) * p.z);
}

vec3 hash33(in vec3 p)
{
  p = fract(p * vec3(443.897, 441.423, 437.195));
  p += dot(p, p.yzx + 19.19);
  return fract((p.xxy + p.yyz) * p.zyx);
}

vec4 hash34(in vec3 p)
{
  vec4 q = fract(p.xyzx * vec4(0.1031, 0.1030, 0.0973, 0.1099));
  q += dot(q, q.wzxy + 33.33);
  return fract((q.xxyz + q.yzzw) * q.zywx);
}

vec3 star(in vec3 i, float jitter)
{
  vec3 offset = (hash33(i) - 0.5) * jitter;
  return i + 0.5 + offset;
}

vec3 perspective(in vec2 s, in vec3 ro, in vec3 t, in vec3 up) {
  vec3 w = normalize(t - ro);
  vec3 u = normalize(cross(w, up));
  vec3 v = normalize(cross(u, w));
  return normalize(s.x * u + s.y * v + FOCAL_LENGTH * w);
}

vec3 blackbody(in float t) {
  float _t = t * (BLACKBODY_MAX - BLACKBODY_MIN) + BLACKBODY_MIN;
  float u = (0.860117757 + 1.54118254e-4 * _t + 1.28641212e-7 * _t * _t)
      / (1.0 + 8.42420235e-4 * _t + 7.08145163e-7 * _t * _t);

  float v = (0.317398726 + 4.22806245e-5 * _t + 4.20481691e-8 * _t * _t)
      / (1.0 - 2.89741816e-5 * _t + 1.61456053e-7 * _t * _t);

  float x = 3.0 * u / (2.0 * u - 8.0 * v + 4.0);
  float y = 2.0 * v / (2.0 * u - 8.0 * v + 4.0);
  float z = 1.0 - x - y;

  float Y = 1.0;
  float X = (Y / y) * x;
  float Z = (Y / y) * z;

  mat3 XYZtosRGB = mat3(
      3.2404542, -1.5371385, -0.4985314,
      -0.9692660, 1.8760108, 0.0415560,
      0.0556434, -0.2040259, 1.0572252
    );

  vec3 RGB = vec3(X, Y, Z) * XYZtosRGB;
  return RGB * pow(0.0004 * _t, 4.0);
}

vec3 postprocess(in vec3 color)
{
  // aces
  const float A = 2.51;
  const float B = 0.03;
  const float C = 2.43;
  const float D = 0.59;
  const float E = 0.14;
  vec3 c = clamp((color * (A * color + B)) / (color * (C * color + D) + E), vec3(0.0), vec3(1.0));

  // gamma
  c = pow(c, vec3(0.4545));
  return c;
}

vec3 starcolor(in vec3 rcell)
{
  return blackbody(pow(hash31(rcell), 4.0));
}

float vnoise(in vec3 i, in vec3 f)
{
  vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

  vec4 h0 = hash34(i);
  vec4 h1 = hash34(i + vec3(0, 0, 1));

  vec2 a = mix(h0.xz, h0.yw, u.x);
  vec2 b = mix(h1.xz, h1.yw, u.x);
  vec2 c = mix(a, b, u.z);

  return mix(c.x, c.y, u.y);
}

// "Star Field"
// nethe550
// Distributed under the CC BY-NC-SA 4.0 license.
//
// voxel traversal from
//     http://www.cse.yorku.ca/~amana/research/grid.pdf

// vertical diffraction spike & composite
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  vec2 uv = fragCoord / iResolution.xy;
  float texelSize = 1.0 / iResolution.y;
  float scale = iResolution.y / REFERENCE_HEIGHT;

  float jitter = hash31(vec3(fragCoord.yx, iTime + 0.13)) - 0.5;

  vec3 vertical = vec3(0.0);

  for (int i = 0; i < DIFFRACTION_SAMPLES; ++i)
  {
    float j = float(i) + jitter;
    float f = pow(DIFFRACTION_ATTENUATION, max(0.0, j));
    vec2 o = vec2(0.0, texelSize * j * DIFFRACTION_SPREAD * scale);
    vertical += texture(iChannel1, uv + o).rgb * f;
    vertical += texture(iChannel1, uv - o).rgb * f;
  }
  vertical *= IDSF;

  vec3 horizontal = texture(iChannel0, uv).rgb;

  vec3 sharp = texture(iChannel1, uv).rgb;

  vec3 spikes = (vertical + horizontal) * DIFFRACTION_STRENGTH;

  vec3 f = sharp + spikes;

  fragColor = vec4(postprocess(f), 1.0);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
