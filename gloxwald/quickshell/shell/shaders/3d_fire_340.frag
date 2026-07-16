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
/*
    "3D Fire" by @XorDev

    I really wanted to see if my turbulence effect worked in 3D.
    I wrote a few 2D variants, but this is my new favorite.
    Read about the technique here:
    https://mini.gmshaders.com/p/turbulence


    See my other 2D examples here:
    https://www.shadertoy.com/view/wffXDr
    https://www.shadertoy.com/view/WXX3RH
    https://www.shadertoy.com/view/tf2SWc

    Thanks!
*/
const float SPEED = 0.05;

vec3 fireColor(float heat, float stoke) {
  vec3 coolNormal = vec3(0.3, 0.0, 0.0); // dark red
  vec3 hotNormal = vec3(1.0, 0.5, 0.1); // bright orange
  vec3 coolStoked = vec3(0.0, 0.1, 0.8); // blue
  vec3 hotStoked = vec3(0.9, 0.95, 1.0); // near white

  vec3 normal = mix(coolNormal, hotNormal, heat);
  vec3 stoked = mix(coolStoked, hotStoked, heat);
  return mix(normal, stoked, stoke);
}

void mainImage(out vec4 O, vec2 I)
{
  float speedScale = 1.;
  float stoke = sk_attention_envelope() * 0.9 + sk_keypulse_envelope() * 0.1;

  //Time for animation
  float t = iTime * SPEED * speedScale,
  //Raymarch loop iterator
  i,
  //Raymarched depth
  z,
  //Raymarch step size and "Turbulence" frequency
  //https://www.shadertoy.com/view/WclSWn
  d;

  //Raymarching loop with 50 iterations
  for (O *= i; i++ < 50.;
    //Add color and glow attenuation
    O += (sin(z / 3. + vec4(7, 2, 3, 0)) + 1.1) / d)
  {
    //Compute raymarch sample point
    vec3 p = z * normalize(vec3(I + I, 0) - iResolution.xyy);
    //Shift back and animate
    p.z += 5. + cos(t);
    //Twist and rotate
    p.xz *= mat2(cos(p.y * .5 + vec4(0, 33, 11, 0)))
        //Expand upward
        / max(p.y * .1 + 1., .1);
    //Turbulence loop (increase frequency)
    for (d = 2.; d < 15.; d /= .6)
      //Add a turbulence wave
      p += cos((p.yzx - vec3(t / .1, t, d)) * d) / d;
    //Sample approximate distance to hollow cone
    float coneRadius = .5 + .15 * stoke;
    z += d = .01 + abs(length(p.xz) + p.y * .3 - coneRadius) / 7.;
  }
  //Tanh tonemapping
  //https://www.shadertoy.com/view/ms3BD7
  O = tanh(O / (1e3 / (1.0 + 0.6 * stoke)));

  // Depth-based heat: close fire (small z) is hotter, remote tips (large z) are cooler.
  float heat = exp(-z * 0.08) * 0.75;
  heat = heat * heat * heat * 20. - 1.;
  float lum = dot(O.rgb, vec3(0.2126, 0.7152, 0.0722));
  O.rgb = fireColor(heat, clamp(stoke, 0.0, 1.0)) * lum;
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
