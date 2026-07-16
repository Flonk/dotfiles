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
const float SPEED = 0.1;

float sdSphere(vec3 pos, float size)
{
  return length(pos) - size;
}

float sdBox(vec3 pos, vec3 size)
{
  pos = abs(pos) - vec3(size);
  return max(max(pos.x, pos.y), pos.z);
}

float sdOctahedron(vec3 p, float s)
{
  p = abs(p);
  float m = p.x + p.y + p.z - s;
  vec3 q;
  if (3.0 * p.x < m) q = p.xyz;
  else if (3.0 * p.y < m) q = p.yzx;
  else if (3.0 * p.z < m) q = p.zxy;
  else return m * 0.57735027;

  float k = clamp(0.5 * (q.z - q.y + s), 0.0, s);
  return length(vec3(q.x, q.y - s + k, q.z - k));
}

float sdPlane(vec3 pos)
{
  return pos.y;
}

mat2 rotate(float a)
{
  float s = sin(a);
  float c = cos(a);
  return mat2(c, s, -s, c);
}

vec3 repeat(vec3 pos, vec3 span)
{
  return abs(mod(pos, span)) - span * 0.5;
}

float getDistance(vec3 pos, vec2 uv, float objScale)
{
  vec3 originalPos = pos;

  for (int i = 0; i < 3; i++)
  {
    pos = abs(pos) - 4.5;
    pos.xz *= rotate(1.0);
    pos.yz *= rotate(1.0);
  }

  pos = repeat(pos, vec3(4.0));

  float d0 = abs(originalPos.x) - 0.1;
  float d1 = sdBox(pos, vec3(0.8 * objScale));

  pos.xy *= rotate(mix(1.0, 2.0, abs(sin(iTime * SPEED))));
  float size = mix(1.1, 1.3, (abs(uv.y) * abs(uv.x))) * objScale;
  float d2 = sdSphere(pos, size);
  float dd2 = sdOctahedron(pos, 1.8 * objScale);
  float ddd2 = mix(d2, dd2, abs(sin(iTime * SPEED)));

  return max(max(d1, -ddd2), -d0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  vec2 p = (fragCoord.xy * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);

  // camera
  vec3 cameraOrigin = vec3(0.0, 0.0, -10.0 + iTime * SPEED * 4.0);
  vec3 cameraTarget = vec3(cos(iTime * SPEED) + sin(iTime * SPEED / 2.0) * 10.0, exp(sin(iTime * SPEED)) * 2.0, 3.0 + iTime * SPEED * 4.0);
  vec3 upDirection = vec3(0.0, 1.0, 0.0);
  vec3 cameraDir = normalize(cameraTarget - cameraOrigin);
  vec3 cameraRight = normalize(cross(upDirection, cameraOrigin));
  vec3 cameraUp = cross(cameraDir, cameraRight);
  vec3 rayDirection = normalize(cameraRight * p.x + cameraUp * p.y + cameraDir);

  float depth = 0.0;
  float ac = 0.0;
  vec3 rayPos = vec3(0.0);
  float d = 0.0;

  for (int i = 0; i < 80; i++)
  {
    rayPos = cameraOrigin + rayDirection * depth;
    d = getDistance(rayPos, p, 1.0 + 0.1 * sk_attention_envelope());

    if (abs(d) < 0.0001)
    {
      break;
    }

    ac += exp(-d * mix(5.0, 10.0, abs(sin(iTime * SPEED))));
    depth += d;
  }

  vec3 col = vec3(0.0, 0.3, 0.7);
  col = mix(col, sk_fail_color, sk_fail_envelope() * 0.5);
  col *= 1.0 + 0.1 * clamp(sk_keypulse_envelope() + sk_load_envelope(), 0.0, 1.0);
  ac *= 1.2 * (iResolution.x / iResolution.y - abs(p.x));
  vec3 finalCol = col * ac * 0.06;
  fragColor = vec4(finalCol, 1.0);
  fragColor.w = 1.0 - depth * 0.1;
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
