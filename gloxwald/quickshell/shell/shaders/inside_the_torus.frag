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

/* Shading constants */
/* --------------------- */
const vec3 LP = vec3(-0.6, 0.7, -0.3); // light position
const vec3 LC = vec3(.85, 0.80, 0.70); // light colour
const vec3 HC1 = vec3(.5, .4, .3); // hemisphere light colour 1
const vec3 HC2 = vec3(0.1, .1, .6) * .5; // hemisphere light colour 2
const vec3 HLD = vec3(0, 1, 0); // hemisphere light direction
const vec3 BC = vec3(0.25, 0.25, 0.25); // back light colour
const vec3 FC = vec3(1.30, 1.20, 1.00); // fresnel colour
const float AS = .5; // ambient light strength
const float DS = 1.; // diffuse light strength
const float BS = .3; // back light strength
const float FS = .3; // fresnel strength
/* Raymarching constants */
/* --------------------- */
const float MAX_TRACE_DISTANCE = 10.; // max trace distance
const float INTERSECTION_PRECISION = 0.0001; // precision of the intersection
const int NUM_OF_TRACE_STEPS = 64; // max number of trace steps
const float STEP_MULTIPLIER = 1.; // the step mutliplier - ie, how much further to progress on each step

/* Structures */
/* ---------- */
struct Camera {
  vec3 ro;
  vec3 rd;
  vec3 forward;
  vec3 right;
  vec3 up;
  float FOV;
};
struct Surface {
  float len;
  vec3 position;
  vec3 colour;
  float id;
  float steps;
  float AO;
};
struct Model {
  float dist;
  vec3 colour;
  float id;
};

/* Utilities */
/* ---------- */
vec2 toScreenspace(in vec2 p) {
  vec2 uv = (p - 0.5 * iResolution.xy) / min(iResolution.y, iResolution.x);
  return uv;
}
mat2 R(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat2(c, -s, s, c);
}
Camera getCamera(in vec2 uv, in vec3 pos, in vec3 target) {
  vec3 f = normalize(target - pos);
  vec3 r = normalize(vec3(f.z, 0., -f.x));
  vec3 u = normalize(cross(f, r));

  float FOV = 1. + cos(iTime * SPEED * .1) * .8;

  return Camera(
    pos,
    normalize(f + FOV * uv.x * r + FOV * uv.y * u),
    f,
    r,
    u,
    FOV
  );
}

//--------------------------------
// Modelling
//--------------------------------
float G(vec3 p) {
  return dot(sin(p.yzx), cos(p.zxy));
}
Model model(vec3 p) {
  float t = iTime * SPEED * .1;
  p.xz *= R(t);
  p.xy *= R(.3);
  p.xy -= .5;
  float d = abs(-(length(vec2(p.y, length(p.xz) - 2.)) - 1.8 + cos(t) * .3));

  // x variability
  //float gs = 3.+p.x;
  //float g = G(p.yxz*gs)/max(4.,gs);
  // mixing on the y
  //float g = mix(g, abs(g)-.4, cos(p.y*2.));
  // regular
  float g = G(p.yxz * 4.) / 4.;
  g *= 1.0 + 0.1 * sk_attention_envelope();

  d = length(vec2(d, g)) - .3;
  vec3 colour = vec3(g);

  return Model(d, colour, 1.);
}
Model map(vec3 p) {
  return model(p);
}

/* Modelling utilities */
/* ---------- */
// I *think* I borrowed this from Shane, but probably orginally comes from IQ.
// Calculates the normal by taking a very small distance,
// remapping the function, and getting normal for that
vec3 calcNormal(in vec3 pos) {
  vec3 eps = vec3(0.001, 0.0, 0.0);
  vec3 nor = vec3(
      map(pos + eps.xyy).dist - map(pos - eps.xyy).dist,
      map(pos + eps.yxy).dist - map(pos - eps.yxy).dist,
      map(pos + eps.yyx).dist - map(pos - eps.yyx).dist);
  return normalize(nor);
}

//--------------------------------
// Raymarcher
//--------------------------------
Surface march(in Camera cam) {
  float h = 1e4; // local distance
  float d = 0.; // ray depth
  float id = -1.; // surace id
  float s = 0.; // number of steps
  float ao = 0.; // march space AO. Simple weighted accumulator. Not really AO, but ¯\_(ツ)_/¯
  vec3 p; // ray position
  vec3 c; // surface colour

  for (int i = 0; i < NUM_OF_TRACE_STEPS; i++) {
    if (abs(h) < INTERSECTION_PRECISION || d > MAX_TRACE_DISTANCE) break;
    p = cam.ro + cam.rd * d;
    Model m = map(p);
    h = m.dist;
    d += h * STEP_MULTIPLIER;
    id = m.id;
    s += 1.;
    ao += max(h, 0.);
    c = m.colour;
  }

  if (d >= MAX_TRACE_DISTANCE) id = -1.0;

  return Surface(d, p, c, id, s, ao);
}

//--------------------------------
// Shading
//--------------------------------
/*
   * Soft shadows and AO curtesy of Inigo Quilez
   * https://iquilezles.org/articles/rmshadows
  */
float softshadow(in vec3 ro, in vec3 rd, in float mint, in float tmax) {
  float res = 1.0;
  float t = mint;
  for (int i = 0; i < 16; i++) {
    float h = map(ro + rd * t).dist;
    res = min(res, 8.0 * h / t);
    t += clamp(h, 0.02, 0.10);
    if (h < 0.001 || t > tmax) break;
  }
  return clamp(res, 0.0, 1.0);
}
float AO(in vec3 pos, in vec3 nor) {
  float occ = 0.0;
  float sca = 1.0;
  for (int i = 0; i < 5; i++)
  {
    float hr = 0.01 + 0.12 * float(i) / 4.0;
    vec3 aopos = nor * hr + pos;
    float dd = map(aopos).dist;
    occ += -(dd - hr) * sca;
    sca *= 0.95;
  }
  return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}
vec3 shade(vec3 col, vec3 pos, vec3 nor, vec3 ref, Camera cam) {
  vec3 plp = LP - pos; // point light

  float o = AO(pos, nor); // Ambient occlusion
  vec3 l = normalize(plp); // light direction

  float d = clamp(dot(nor, l), 0.0, 1.0) * DS; // diffuse component
  float b = clamp(dot(nor, normalize(vec3(-l.x, 0, -l.z))), 0.0, 1.0) * clamp(1.0 - pos.y, 0.0, 1.0) * BS; // back light component
  float f = pow(clamp(1.0 + dot(nor, cam.rd), 0.0, 1.0), 2.0) * FS; // fresnel component

  vec3 c = vec3(0.0);
  c += d * LC; // diffuse light integration
  c += mix(HC1, HC2, dot(nor, HLD)) * AS; // hemisphere light integration (ambient)
  c += b * BC * o; // back light integration
  c += f * FC * o; // fresnel integration

  return col * c;
}
vec3 render(Surface surface, Camera cam, vec2 uv) {
  vec3 colour = vec3(.04, .045, .05);
  colour = vec3(.35, .5, .75);
  vec3 colourB = vec3(.9, .85, .8);

  colour = mix(colourB, colour, pow(length(uv), 2.) / 1.5);
  colour = mix(colour, vec3(1.0), sk_keypulse_envelope() * 0.5);

  if (surface.id > -1.) {
    vec3 surfaceNormal = calcNormal(surface.position);
    vec3 ref = reflect(cam.rd, surfaceNormal);
    colour = surfaceNormal;
    vec3 pos = surface.position;

    float t = iTime * SPEED;
    vec3 c1 = vec3(.8, .3, .6);
    vec3 c2 = vec3(.6, .3, .8);
    c1 = mix(c1, sk_fail_color, sk_fail_envelope());
    c2 = mix(c2, sk_fail_color, sk_fail_envelope());

    vec3 col = mix(
        mix(
          c1,
          c2,
          dot(surfaceNormal, surfaceNormal.zxy)
        ),
        vec3(1),
        smoothstep(0., .1, cos(surface.colour.r * 40.))
      );

    colour = shade(col, pos, surfaceNormal, ref, cam);
  }

  return colour;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec3 c = vec3(0);
  for (int x = 0; x < 2; x++) {
    for (int y = 0; y < 2; y++) {
      vec2 uv = toScreenspace(fragCoord + vec2(x, y) * .5);

      Camera cam = getCamera(uv, vec3(1.5, 0, 1.5), vec3(0));
      Surface surface = march(cam);

      c += render(surface, cam, uv);
    }
  }

  fragColor = vec4(c * .25, 1);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
