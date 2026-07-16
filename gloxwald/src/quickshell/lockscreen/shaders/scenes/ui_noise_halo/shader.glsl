vec4 extractAlpha(vec3 colorIn)
{
  vec4 colorOut;
  float maxValue = min(max(max(colorIn.r, colorIn.g), colorIn.b), 1.0);
  if (maxValue > 1e-5)
  {
    colorOut.rgb = colorIn.rgb * (1.0 / maxValue);
    colorOut.a = maxValue;
  }
  else
  {
    colorOut = vec4(0.0);
  }
  return colorOut;
}

#define BG_COLOR (vec3(sin(iTime)*0.5+0.5) * 0.0 + vec3(0.0))
#define time iTime
const vec3 color1 = vec3(0.611765, 0.262745, 0.996078);
const vec3 color2 = vec3(0.298039, 0.760784, 0.913725);
const vec3 color3 = vec3(0.062745, 0.078431, 0.600000);
const float innerRadius = 0.6;
const float noiseScale = 0.65;

float light1(float intensity, float attenuation, float dist)
{
  return intensity / (1.0 + dist * attenuation);
}
float light2(float intensity, float attenuation, float dist)
{
  return intensity / (1.0 + dist * dist * attenuation);
}

void draw(out vec4 _FragColor, in vec2 vUv)
{
  vec2 uv = vUv * 1.7;
  float ang = atan(uv.y, uv.x);
  float len = length(uv);
  float v0, v1, v2, v3, cl;
  float r0, d0, n0;
  float r, d;

  float flash = sk_keypulse_envelope();
  float failPulse = sk_fail_envelope();
  float authDelay = max((iTime - u_auth_started_time) - 0.08, 0.0);
  float authSpin = sk_load_envelope();

  float radiusPulse = 1.0 + sk_attention_envelope() * 0.3;

  float brightPulse = 1.0 + flash * 1.4 + sk_attention_envelope() * 0.15;

  // scale UVs so the ring expands outward uniformly
  uv /= radiusPulse;
  len = length(uv);

  // ring
  vec2 noiseUv = fract(uv * noiseScale * 0.08 + vec2(time * 0.015, -time * 0.02));
  vec4 noiseTex = texture(iChannel0, noiseUv);
  n0 = noiseTex.r;
  r0 = mix(mix(innerRadius, 1.0, 0.4), mix(innerRadius, 1.0, 0.6), n0);
  d0 = distance(uv, r0 / len * uv);
  v0 = light1(1.0, 10.0, d0) * brightPulse;
  v0 *= smoothstep(r0 * 1.05, r0, len);
  cl = cos(ang + time * 2.0) * 0.5 + 0.5;

  // high light
  float a = -time * mix(1.0, 8.0, authSpin);
  vec2 pos = vec2(cos(a), sin(a)) * r0;
  d = distance(uv, pos);
  v1 = light2(1.5, 5.0, d);
  v1 *= light1(1.0, 50.0, d0);
  float loadingSweep = authSpin * pow(max(cos(ang - authDelay * 6.0), 0.0), 18.0);
  v1 += loadingSweep * (0.18);

  // back decay
  v2 = smoothstep(1.0, mix(innerRadius, 1.0, n0 * 0.5), len);

  // hole
  v3 = smoothstep(innerRadius, mix(innerRadius, 1.0, 0.5), len);

  // color
  vec3 failColor = vec3(1.0, 0.08, 0.08);
  vec3 authColor = vec3(0.95, 0.98, 1.0);
  vec3 ringColor = mix(mix(color1, color2, cl), failColor, failPulse * 0.85);
  vec3 baseColor = mix(color3, failColor * 0.45, failPulse * 0.75);
  vec3 col = mix(baseColor, ringColor, v0);
  col = mix(col, failColor, failPulse * 0.25);
  col = mix(col, authColor, loadingSweep * 0.3);
  col = (col + v1) * v2 * v3;
  col.rgb = clamp(col.rgb, 0.0, 1.0);

  _FragColor = extractAlpha(col);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  vec2 uv = (fragCoord * 2. - iResolution.xy) / iResolution.y;

  vec4 col;
  draw(col, uv);

  vec3 bg = BG_COLOR;

  fragColor.rgb = mix(bg, col.rgb, col.a);
}
