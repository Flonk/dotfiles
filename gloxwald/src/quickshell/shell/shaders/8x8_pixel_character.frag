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
#define Rot(a) mat2(cos(a),-sin(a),sin(a),cos(a))
#define antialiasing(n) n/min(iResolution.y,iResolution.x)
#define S(d) 1.-smoothstep(-1.3,1.3, (d)*iResolution.y )
#define B(p,s) max(abs(p).x-s.x,abs(p).y-s.y)

int pacman[16] = int[](
    1360, 5460, 21824, 21760, 21824, 21909, 5460, 1360,
    1360, 5460, 21844, 21840, 21844, 21909, 5460, 1360
  );

int cat[16] = int[](
    34952, 17476, 21844, 21844, 26997, 33041, 341, 514,
    34976, 17488, 21844, 21844, 26997, 33041, 341, 514
  );

int explosion[24] = int[](
    0, 320, 2000, 7540, 7540, 2000, 320, 0,
    320, 5060, 19825, 63455, 63455, 19825, 5060, 320,
    16385, 12300, 1040, 960, 960, 1040, 12300, 16385
  );

int heart[16] = int[](
    0, 320, 2000, 7540, 30045, 30045, 23925, 5140,
    0, 320, 2000, 7540, 30045, 23925, 5140, 0
  );

float random(vec2 p) {
  return fract(sin(dot(p.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float plus(vec2 p) {
  float d = B(p, vec2(0.15, 0.4));
  float d2 = B(p, vec2(0.4, 0.15));
  return min(d, d2);
}

float animationCircle(vec2 p, float n) {
  float d = abs(length(p) - 0.35) - 0.05;
  float d2 = length(p) - 0.2;
  p *= Rot(radians(30. * iTime * (n * 2.) * ((n < 0.5) ? -1. : 1.)));
  d = max(-(abs(p.x) - 0.1), d);
  d = min(d, d2);
  return d;
}

float animationPlane(vec2 p, float n) {
  float a = radians(30. * iTime * (n * 2.) * ((n < 0.5) ? -1. : 1.));
  float d = dot(p, vec2(cos(a), sin(a)));
  return d;
}

vec3 renderPixels(vec2 p, vec3 col) {
  vec2 cell = p * 30.0;
  vec2 id = floor(cell);
  vec2 gr = fract(cell) - 0.5;

  float gridNum = 9.0;
  float column = mod(id.x, gridNum);
  float row = mod(id.y, gridNum);

  if (column == 8.0 || row == 8.0) {
    if (random(id) < 0.5) {
      gr *= Rot(radians(45.));
    } else {
      gr *= Rot(radians(-45.));
    }
    gr.x = abs(gr.x) - 0.35;
    float d = B(gr, vec2(0.1, 1.));

    return col = mix(col, vec3(0.2), S(d));
  }

  vec2 charCell = id - vec2(column, row);
  float n = random(charCell);
  int charaIndex = int(n * 4.);
  int charIndex = int(mod(iTime * 2., 2.0));
  int irow = int(row);
  int icol = int(column);
  int rowBits = pacman[charIndex * 8 + irow];
  if (charaIndex == 1) {
    rowBits = cat[charIndex * 8 + irow];
  } else if (charaIndex == 2) {
    charIndex = int(mod(iTime * 3., 3.0));
    rowBits = explosion[charIndex * 8 + irow];
  } else if (charaIndex == 3) {
    rowBits = heart[charIndex * 8 + irow];
  }

  int v = (rowBits >> (icol * 2)) & 3;

  vec3 colors[4];
  colors[0] = vec3(0.0);
  colors[1] = vec3(1.0);
  colors[2] = vec3(0.3);
  colors[3] = vec3(0.6);

  n = random(id);

  float d = B(gr, vec2(0.4));
  if (n >= 0.3 && n < 0.6) {
    d = animationCircle(gr, n);
  } else if (n >= 0.6 && n < 0.8) {
    d = plus(gr);
  } else if (n >= 0.8) {
    d = animationPlane(gr, n);
  }

  float d2 = abs(B(gr, vec2(0.47))) - 0.03;

  if (v > 0) {
    if (v == 2) d = B(gr, vec2(0.4));
    d = min(d, d2);
    col = mix(col, colors[v], S(d));
  } else {
    d2 = length(gr) - 0.03;
    col = mix(col, vec3(1.0), S(d2));
  }
  return col;
}

float cubicInOut(float t) {
  return t < 0.5
  ? 4.0 * t * t * t : 0.5 * pow(2.0 * t - 2.0, 3.0) + 1.0;
}

float getTime(float t, float duration) {
  return clamp(t, 0.0, duration) / duration;
}

float getAnimationValue() {
  float easeValue = 0.;
  float frame = mod(iTime, 12.0);
  float time = frame;

  float duration = 1.;
  if (frame >= 5. && frame < 6.) {
    time = getTime(time - 5., duration);
    easeValue = cubicInOut(time);
  } else if (frame >= 6. && frame < 11.) {
    easeValue = 1.;
  } else if (frame >= 11. && frame < 12.) {
    time = getTime(time - 11., duration);
    easeValue = 1.0 - cubicInOut(time);
  }

  return easeValue;
}

float getRotDir() {
  float dir = 1.;
  float frame = mod(iTime, 24.0);
  if (frame >= 12.) dir = -1.;
  return dir;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
  float ease = getAnimationValue();
  p *= 1. - (ease * 0.3);
  p *= Rot(sin(ease) * 0.5 * getRotDir());
  vec3 col = vec3(0.);
  p.y -= iTime * 0.1;
  col = renderPixels(p, col);
  fragColor = vec4(col, 1.0);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
