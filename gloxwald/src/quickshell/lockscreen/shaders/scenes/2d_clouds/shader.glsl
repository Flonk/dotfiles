const float cloudscale = 1.1;
const float speed = 0.03;
const float clouddark = 0.5;
const float cloudlight = 0.3;
const float cloudcover = 0.2;
const float cloudalpha = 8.0;
const float skytint = 0.5;
const vec3 skycolour1 = vec3(0.2, 0.4, 0.6);
const vec3 skycolour2 = vec3(0.4, 0.7, 1.0);

const mat2 m = mat2(1.6, 1.2, -1.2, 1.6);

float noise(in vec2 p) {
  return texture(iChannel0, p / 10.0).r * 2.0 - 1.0;
}

float fbm(vec2 n) {
  float total = 0.0, amplitude = 0.1;
  for (int i = 0; i < 7; i++) {
    total += noise(n) * amplitude;
    n = m * n;
    amplitude *= 0.4;
  }
  return total;
}

// -----------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 p = fragCoord.xy / iResolution.xy;
  vec2 uv = p * vec2(iResolution.x / iResolution.y, 1.0);
  float time = iTime * speed;
  float q = fbm(uv * cloudscale * 0.5);

  //ridged noise shape
  float r = 0.0;
  uv *= cloudscale;
  uv -= q - time;
  float weight = 0.8;
  for (int i = 0; i < 8; i++) {
    r += abs(weight * noise(uv));
    uv = m * uv + time;
    weight *= 0.7;
  }

  //noise shape
  float f = 0.0;
  uv = p * vec2(iResolution.x / iResolution.y, 1.0);
  uv *= cloudscale;
  uv -= q - time;
  weight = 0.7;
  for (int i = 0; i < 8; i++) {
    f += weight * noise(uv);
    uv = m * uv + time;
    weight *= 0.6;
  }

  f *= r + f;

  //noise colour
  float c = 0.0;
  time = iTime * speed * 2.0;
  uv = p * vec2(iResolution.x / iResolution.y, 1.0);
  uv *= cloudscale * 2.0;
  uv -= q - time;
  weight = 0.4;
  for (int i = 0; i < 7; i++) {
    c += weight * noise(uv);
    uv = m * uv + time;
    weight *= 0.6;
  }

  //noise ridge colour
  float c1 = 0.0;
  time = iTime * speed * 3.0;
  uv = p * vec2(iResolution.x / iResolution.y, 1.0);
  uv *= cloudscale * 3.0;
  uv -= q - time;
  weight = 0.4;
  for (int i = 0; i < 7; i++) {
    c1 += abs(weight * noise(uv));
    uv = m * uv + time;
    weight *= 0.6;
  }

  c += c1;

  vec3 skycolour = mix(skycolour2, skycolour1, p.y);
  skycolour = mix(skycolour, sk_fail_color, sk_fail_envelope() * 0.5);
  skycolour *= 1.0 + 0.075 * clamp(sk_keypulse_envelope() + sk_load_envelope(), 0.0, 1.0);
  vec3 cloudcolour = vec3(1.1, 1.1, 0.9) * clamp((clouddark + cloudlight * c), 0.0, 1.0);

  f = cloudcover + cloudalpha * f * r;

  vec3 result = mix(skycolour, clamp(skytint * skycolour + cloudcolour, 0.0, 1.0), clamp(f + c, 0.0, 1.0));

  fragColor = vec4(result, 1.0);
}
