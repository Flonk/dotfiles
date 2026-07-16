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
#ifdef GL_ES
#endif

#define PI 3.1415926535897932384626433832795

const float wave_amplitude = 0.076;
const float period = 2. * PI;

float wave_phase() {
  return iTime;
}

float square(vec2 st) {
  vec2 bl = step(vec2(0.), st); // bottom-left
  vec2 tr = step(vec2(0.), 1.0 - st); // top-right
  return bl.x * bl.y * tr.x * tr.y;
}

vec4 frame(vec2 st) {
  float tushka = square(st * mat2((1. / .48), 0., 0., (1. / .69)));

  mat2 sector_mat = mat2(1. / .16, 0., 0., 1. / .22);
  float sectors[4];
  sectors[0] = square(st * sector_mat + (1. / .16) * vec2(0.000, -0.280));
  sectors[1] = square(st * sector_mat + (1. / .16) * vec2(0.000, -0.060));
  sectors[2] = square(st * sector_mat + (1. / .16) * vec2(-0.240, -0.280));
  sectors[3] = square(st * sector_mat + (1. / .16) * vec2(-0.240, -0.060));
  vec3 sector_colors[4];
  sector_colors[0] = vec3(0.941, 0.439, 0.404) * sectors[0];
  sector_colors[1] = vec3(0.435, 0.682, 0.843) * sectors[1];
  sector_colors[2] = vec3(0.659, 0.808, 0.506) * sectors[2];
  sector_colors[3] = vec3(0.996, 0.859, 0.114) * sectors[3];

  return vec4(vec3(sector_colors[0] + sector_colors[1] +
        sector_colors[2] + sector_colors[3]), tushka);
}

vec4 trail_piece(vec2 st, vec2 index, float scale) {
  scale = index.x * 0.082 + 0.452;

  vec3 color;
  if (index.y > 0.9 && index.y < 2.1) {
    color = vec3(0.435, 0.682, 0.843);
    scale *= .8;
  } else if (index.y > 3.9 && index.y < 5.1) {
    color = vec3(0.941, 0.439, 0.404);
    scale *= .8;
  } else {
    color = vec3(0., 0., 0.);
  }

  float scale1 = 1. / scale;
  float shift = -(1. - scale) / (2. * scale);
  vec2 st2 = vec2(vec3(st, 1.) * mat3(scale1, 0., shift, 0., scale1, shift, 0., 0., 1.));
  float mask = square(st2);

  return vec4(color, mask);
}

vec4 trail(vec2 st) {
  // actually 1/width, 1/height
  const float piece_height = 7. / .69;
  const float piece_width = 6. / .54;

  // make distance between smaller segments slightly lower
  st.x = 1.2760 * pow(st.x, 3.0) - 1.4624 * st.x * st.x + 1.4154 * st.x;

  float x_at_cell = floor(st.x * piece_width) / piece_width;
  float x_at_cell_center = x_at_cell + 0.016;
  float incline = cos(0.5 * period + wave_phase()) * wave_amplitude;

  float offset = sin(x_at_cell_center * period + wave_phase()) * wave_amplitude +
      incline * (st.x - x_at_cell) * 5.452;

  float mask = step(offset, st.y) * (1. - step(.69 + offset, st.y)) * step(0., st.x);

  vec2 cell_coord = vec2((st.x - x_at_cell) * piece_width,
      fract((st.y - offset) * piece_height));
  vec2 cell_index = vec2(x_at_cell * piece_width,
      floor((st.y - offset) * piece_height));

  vec4 pieces = trail_piece(cell_coord, cell_index, 0.752);

  return vec4(vec3(pieces), pieces.a * mask);
}

vec4 logo(vec2 st) {
  if (st.x <= .54) {
    return trail(st);
  } else {
    vec2 st2 = st + vec2(0., -sin(st.x * period + wave_phase()) * wave_amplitude);
    return frame(st2 + vec2(-.54, 0));
  }
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 st = fragCoord.xy / iResolution.xy;
  st.x *= iResolution.x / iResolution.y;

  st += vec2(.0);
  st *= 1.472;
  st += vec2(-0.7, -0.68);
  float rot = PI * -0.124;
  st *= mat2(cos(rot), sin(rot), -sin(rot), cos(rot));
  vec3 color = vec3(1.);

  vec4 logo_ = logo(st);
  fragColor = mix(vec4(0., .5, .5, 1.000), logo_, logo_.a);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
