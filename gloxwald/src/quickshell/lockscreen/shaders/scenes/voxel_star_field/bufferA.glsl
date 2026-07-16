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
vec3 path(in float t)
{
  const float ISH = IS * 0.5;
  return vec3(
    ISH + 15.0 * sin(t * 0.20) + 5.0 * cos(t * 0.45),
    ISH + 10.0 * cos(t * 0.15) + 8.0 * sin(t * 0.30),
    t * 8.0
  );
}

vec3 dpath(in float t)
{
  return vec3(
    3.0 * cos(t * 0.20) - 2.25 * sin(t * 0.45),
    -1.5 * sin(t * 0.15) + 2.40 * cos(t * 0.30),
    8.0
  );
}

vec3 ddpath(in float t)
{
  return vec3(
    -0.600 * sin(t * 0.20) - 1.0125 * cos(t * 0.45),
    -0.225 * cos(t * 0.15) - 0.7200 * sin(t * 0.30),
    0.0
  );
}

void camera(in vec2 s, in float t, out vec3 ro, out vec3 rd)
{
  ro = path(t);

  vec3 forward = normalize(dpath(t + 2.0));
  vec3 accel = ddpath(t);
  vec3 up = vec3(0.0, 1.0, 0.0);
  vec3 side = normalize(cross(forward, up));
  float lateral = dot(accel, side);
  float bank = lateral * 0.15;
  up = normalize(up * cos(bank) + cross(forward, up) * sin(bank));
  vec3 right = normalize(cross(forward, up));
  up = cross(right, forward);

  rd = perspective(s, ro, ro + forward, up);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  vec2 s = (2.0 * fragCoord - iResolution.xy) / iResolution.y;
  vec3 color = vec3(0.0);
  vec3 dust = vec3(0.0);

  // world (camera) space
  float t = iTime * SPEED;
  vec3 ro, rd;
  camera(s, t, ro, rd);

  // grid space
  vec3 p = ro * SCALE;
  vec3 rcell = floor(p);
  vec3 rstep = sign(rd);

  vec3 ird = 1.0 / (rd + sign(rd) * 1e-9);
  vec3 tmax = (rcell + step(0.0, rd) - p) * ird; // dist to next cell
  vec3 tdel = abs(ird); // dist across 1 cell

  float ptc = 0.0;
  float tc = 0.0;
  float tf = -1.0;
  float alpha = 0.0;

  float idph = 1.0 / (iResolution.y * FOCAL_LENGTH);
  float scale = iResolution.y / REFERENCE_HEIGHT;

  // voxel traversal
  for (int i = 0; i < MAX_STEPS; ++i)
  {
    vec3 c = star(rcell, JITTER);

    vec3 oc = c - p;
    float tca = dot(oc, rd);
    if (tca > 0.0)
    {
      float d2 = dot(oc, oc) - tca * tca;
      float pxSize = (2.0 * tc) * idph * SCALE;
      float ph = max(1e-4, pxSize);
      float R = min(RADIUS, (MAX_RADIUS * scale) * pxSize);

      float dist = sqrt(max(0.0, d2));
      float coverage = clamp((R + ph - dist) / (2.0 * ph), 0.0, 1.0);

      if (coverage > 1e-4)
      {
        tf = max(1e-2, tc) * IS;
        alpha = coverage;
        break;
      }
    }

    float dstep = (tc - ptc) * IS;
    dust += DUST_COLOR * dstep * vnoise(rcell, fract(p + rd * tc));
    ptc = tc;

    // move to next cell boundary (branchless DDA)
    vec3 mask = step(tmax.xyz, tmax.yzx) * step(tmax.xyz, tmax.zxy);
    tc = dot(tmax, mask);
    rcell += rstep * mask;
    tmax += tdel * mask;

    if (tc * IS > FAR) break;
  }

  if (tf > 0.0)
  {
    float f = (exp(FALLOFF * tf) - E_BD) * IRE_BD;
    f *= 1.0 / (tf * tf + 1.0); // inverse-square law
    color += max(vec3(0.0), starcolor(rcell) * f * alpha);
  }

  color += dust * exp(-tf);

  fragColor = vec4(color, 1.0);
}
