#version 300 es
precision highp float;
precision highp int;

uniform vec3 iResolution;

uniform float iTime;

uniform int iFrame;

uniform vec4 iMouse;

uniform vec4 iClock;

uniform mat4 iSeed0;
uniform mat4 iSeed1;

uniform sampler2D iChannel0;
uniform sampler2D iChannel1;
uniform sampler2D iChannel2;
uniform sampler2D iChannel3;

uniform int u_indicator_type;

uniform vec3 u_indicator_color;

uniform float u_last_key_time;

uniform vec2 u_key_bases;

uniform float u_last_failed_unlock_time;

uniform float u_auth_started_time;

const vec3 sk_fail_color = vec3(227.0 / 255.0, 85.0 / 255.0, 50.0 / 255.0);

out vec4 fragColor;

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

float sk_keypulse_envelope() {
  float age = iTime - u_last_key_time;
  float ramp = clamp(age / 0.03, 0.0, 1.0);
  float p = mix(u_key_bases.x, 1.0, ramp);
  float decay = clamp((age - 0.03) / 0.08, 0.0, 1.0);
  return p * (1.0 - decay * decay);
}

float sk_key_envelope() {
  float age = iTime - u_last_key_time;
  float ramp = clamp(age / 0.06, 0.0, 1.0);
  float p = mix(u_key_bases.y, 1.0, ramp);
  float decay = clamp((age - 1.06) / 2.0, 0.0, 1.0);
  return p * (1.0 - sk_ease_out_back(pow(decay, 0.65)));
}

float sk_fail_envelope() {
  float age = iTime - u_last_failed_unlock_time;
  float p = clamp(age / 0.03, 0.0, 1.0);
  float decay = clamp((age - 0.27) / 2.0, 0.0, 1.0);
  return p * pow(1.0 - decay, 3.0);
}

float sk_load_envelope() {
  float isLoading = step(-999.0, u_auth_started_time);
  float authAge = iTime - u_auth_started_time;
  float endedAge = iTime - u_last_failed_unlock_time;

  float loading = isLoading * clamp((authAge - 0.1) / 0.03, 0.0, 1.0);

  float unloading = (1.0 - isLoading) * clamp(1.0 - endedAge / 0.03, 0.0, 1.0);

  return loading + unloading;
}

float sk_attention_envelope() {
  float kf = sk_key_envelope() + sk_fail_envelope();
  float load = sk_load_envelope();
  kf = max(kf, load - 1.0);
  return min(kf + load, 1.0);
}
