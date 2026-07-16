// Mobius Spiral Sphere Projection — Shane
// https://www.shadertoy.com/view/7fl3DX
//
// Stereographic projection of hexagons packed along loxodromic
// spiral lines on a unit sphere down to the plane, producing a
// Möbius spiral pattern.

const float SPEED = 0.2;

// ---------------------------------------------------------------
// Common
// ---------------------------------------------------------------

// Raytraced sphere (Cotterzz's robust variant).
float traceSphere(in vec3 ro, in vec3 rd, in vec4 sph) {
  vec3 oc = ro - sph.xyz;
  float b = dot(oc, rd);
  if (b > 0.) return 1e8;
  vec3 cx = cross(oc, rd);
  float h = sph.w * sph.w - dot(cx, cx);
  if (h < 0.) return 1e8;
  return -b - sqrt(h);
}

// Plane intersection.
float tracePlane(vec3 ro, vec3 rd, vec3 n, vec3 o) {
  float t = 1e8;
  float ndotdir = dot(rd, n);
  if (ndotdir < 0.) {
    float dist = -(dot(ro - o, n) + 9e-7 * 0.) / ndotdir;
    if (dist > 0.) {
      t = dist;
    }
  }
  return t;
}

#define FLAT_TOP_HEXAGON

#ifdef FLAT_TOP_HEXAGON
const vec2 s = vec2(1.7320508, 1) / 2.;
#else
const vec2 s = vec2(1, 1.7320508) / 2.;
#endif

// 2D hexagonal isosurface function.
float hex(in vec2 p) {
  p = abs(p);
  #ifdef FLAT_TOP_HEXAGON
  return max(dot(p, vec2(1.7320508, 1) / 2.), p.y);
  #else
  return max(dot(p, vec2(1, 1.7320508) / 2.), p.x);
  #endif
}

// Hexagon grid: returns local coords (.xy) and cell ID (.zw).
vec4 getHex(vec2 p) {
  vec4 h = vec4(p, p - s / 2.);
  vec4 iC = floor(h / s.xyxy) + .5;
  h -= iC * s.xyxy;
  return dot(h.xy, h.xy) < dot(h.zw, h.zw) ? vec4(h.xy, iC.xy) : vec4(h.zw, iC.zw + .5);
}

// ---------------------------------------------------------------
// Image
// ---------------------------------------------------------------

#define SHAPE 0
#define SHOW_SPHERE

#define PI 3.14159265358979323846
#define TAU 6.28318530717958647693
#define FAR 20.

int objID;

// Global sphere radius, driven by attention envelope in mainImage.
float gSphRadius = 0.5;

mat2 rot2(in float a) {
  float c = cos(a), s = sin(a);
  return mat2(c, s, -s, c);
}

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float sBoxS(in vec2 p, in vec2 b, in float rf) {
  vec2 d = abs(p) - b + rf;
  return min(max(d.x, d.y), 0.) + length(max(d, 0.)) - rf;
}

vec4 vObj;

float map(vec3 p) {
  float fl = p.y + .5;
  #ifdef SHOW_SPHERE
  float sph = length(p) - gSphRadius;
  #else
  float sph = 1e5;
  #endif
  vObj = vec4(fl, sph, 1e5, 1e5);
  return min(fl, sph);
}

float trace(in vec3 ro, in vec3 rd) {
  float t = 0., d;
  for (int i = min(0, iFrame); i < 128; i++) {
    d = map(ro + rd * t);
    if ((abs(d) < .001 && d < 0.) || t > FAR) break;
    t += d * .9;
  }
  return min(t, FAR);
}

vec3 getNormal(in vec3 p, float t) {
  const vec2 e = vec2(.001, 0);
  return normalize(vec3(map(p + e.xyy) - map(p - e.xyy),
      map(p + e.yxy) - map(p - e.yxy),
      map(p + e.yyx) - map(p - e.yyx)));
}

float softShadow(vec3 ro, vec3 lp, vec3 n, float k) {
  const int maxIterationsShad = 32;
  ro += n * .0015;
  vec3 rd = lp - ro;
  float shade = 1.;
  float t = 0.;
  float end = max(length(rd), .0001);
  rd /= end;
  for (int i = min(iFrame, 0); i < maxIterationsShad; i++) {
    float d = map(ro + rd * t);
    shade = min(shade, k * d / t);
    t += clamp(d, .005, .15);
    if (d < 0. || t > end) break;
  }
  return max(shade, 0.);
}

float calcAO(in vec3 p, in vec3 n) {
  float sca = 2., occ = 0.;
  for (int i = 0; i < 5; i++) {
    float hr = float(i + 1) * .15 / 5.;
    float d = map(p + n * hr);
    occ += (hr - d) * sca;
    sca *= .7;
  }
  return clamp(1. - occ, 0., 1.);
}

vec2 cmul(vec2 a, vec2 b) {
  return mat2(a, -a.y, a.x) * b;
}
vec2 cinv(vec2 a) {
  return vec2(a.x, -a.y) / dot(a, a);
}
vec2 cdiv(vec2 a, vec2 b) {
  return cmul(a, cinv(b));
}
vec2 clog(in vec2 z) {
  return vec2(log(length(z)), atan(z.y, z.x));
}
vec2 cexp(vec2 z) {
  return exp(z.x) * vec2(cos(z.y), sin(z.y));
}
vec2 cpow(vec2 a, vec2 b) {
  return cexp(cmul(b, clog(a)));
}

vec3 rollObj(vec3 p) {
  p.xz *= rot2(iTime * SPEED / 2.);
  p.yz *= rot2(iTime * SPEED);
  return p;
}

vec2 stereographic(vec3 p) {
  return p.xz / (1. - p.y);
}

vec3 stereographicInverse(vec2 p) {
  float r2 = dot(p, p);
  return vec3(2. * p.x, r2 - 1., 2. * p.y) / (1. + r2);
}

vec2 fFloor(vec3 p) {
  p = stereographicInverse(p.xz);
  p = rollObj(p);
  return stereographic(p);
}

vec2 rep = vec2(4, 8);

vec3 transform(vec3 p) {
  p.xz = fFloor(p);
  #if 1
  p.xz = cdiv(p.xz - vec2(1, 0), p.xz + vec2(1, 0));
  p.xz = clog(p.xz);
  #else
  float N = 2.;
  p.xz = clog(cdiv(vec2(2, 0), cpow(p.xz, vec2(N, 0)) - vec2(1, 0)) + vec2(1, 0));
  #endif
  p.xz = cmul(p.xz, rep * vec2(1, sqrt(3.) / 2.) / TAU);
  return p;
}

vec3 funcD(vec3 p) {
  float px = 1e-4;
  vec3 f = transform(p);
  vec3 dtX = (transform(p + vec3(px, 0, 0)) - f) / px;
  vec3 dtY = (transform(p + vec3(0, px, 0)) - f) / px;
  vec3 dtZ = (transform(p + vec3(0, 0, px)) - f) / px;
  return (mat3(dtX, dtY, dtZ) * vec3(1)) / sqrt(3.);
}

float gCir;
float gCir2;

vec3 getPattern(vec3 p3) {
  vec2 sc = vec2(1) / 2.;
  float tdF = length(funcD(p3));
  p3 = transform(p3);
  vec2 p = p3.xz;
  vec4 p4 = getHex(p);
  p = p4.xy;
  vec2 ip = p4.zw;

  #if SHAPE == 1
  float poly = length(p) - s.y / 2.;
  #else
  float poly = hex(p) - s.y / 2.;
  #endif

  poly = max(poly, -(length(p) - sc.x / 32.));
  poly /= tdF;

  vec2 offs = s * vec2(1, -1);
  vec2 offs2 = s * vec2(1, -1) / 8.;
  gCir = -(length(p - offs2) - s.y / 2. / .866);
  gCir /= tdF;
  gCir2 = length(p - offs2.yx / 2.) - sc.x / 5.;
  gCir2 /= tdF;

  return vec3(poly, ip);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = (fragCoord - iResolution.xy * .5) / iResolution.y;

  // Attention: shrink sphere radius by up to 40%.
  gSphRadius = 0.5 * (1.0 - 0.4 * sk_attention_envelope());

  vec3 ro = vec3(0, 1.5, -2);
  vec3 lk = vec3(0, -.25, 0);
  vec3 lp = ro + vec3(.75, 0, 1.5);

  float FOV = .85;
  vec3 fwd = normalize(lk - ro);
  vec3 rgt = normalize(cross(vec3(0, 1, 0), fwd));
  vec3 up = cross(fwd, rgt);
  vec3 rd = normalize(uv.x * rgt + uv.y * up + fwd / FOV);

  float t = trace(ro, rd);
  float minDist = 1e5;
  objID = vObj.x < vObj.y ? 0 : 1;

  vec3 col = vec3(0);

  if (t < FAR) {
    vec3 sp = ro + rd * t;
    vec3 sn = getNormal(sp, t);
    vec3 ld = lp - sp;
    float lDist = max(length(ld), .001);
    ld /= lDist;

    float sh = softShadow(sp, lp, sn, 16.);
    float ao = calcAO(sp, sn);
    float atten = 1. / (1. + lDist * .05);
    float diff = max(dot(sn, ld), 0.);
    float spec = pow(max(dot(reflect(ld, sn), rd), 0.), 32.);
    float Schlick = pow(1. - max(dot(rd, normalize(rd + ld)), 0.), 5.);
    float freS = mix(.15, 1., Schlick);

    vec3 texCol = vec3(.6);
    vec3 txP = sp;
    float sf = .005;

    // Keypulse: thinner outlines (ew shrinks toward 40% of base at peak).
    float ew = .018 * (1.0 - 0.2 * sk_keypulse_envelope());

    vec3 d3;

    if (objID > 0) {
      vec3 rd2 = normalize(txP - vec3(0, .5, 0));
      float t2 = tracePlane(txP, rd2, vec3(0, 1, 0), vec3(0, -.5, 0));
      vec3 txP2 = txP + rd2 * t2;
      d3 = getPattern(txP2);
      ew *= 2. / length(txP - vec3(0, 1, 0));
    }
    else {
      d3 = getPattern(txP);
    }

    vec2 id = mod(d3.yz, rep.yx) / (rep.x * rep.y);
    float rnd = hash21(id + .1);
    rnd = dot(id, rep);

    vec3 cCol = .5 + .45 * cos(TAU * rnd + vec3(0, PI / 2., PI));
    vec3 cCol2 = .5 + .45 * cos(TAU * rnd + .25 + vec3(0, PI / 2., PI));
    if (dot(cCol2 - cCol, vec3(299, .587, .114)) < 0.) {
      vec3 tmp = cCol;
      cCol = cCol2;
      cCol2 = tmp;
    }

    // Fail: shift hexagon colors toward fail hue.
    float failE = sk_fail_envelope();
    cCol = mix(cCol, sk_fail_color, failE);
    cCol2 = mix(cCol2, sk_fail_color, failE);

    cCol = mix(cCol, cCol2 * 1.2 + .05, 1. - smoothstep(0., sf * 2., gCir));
    cCol = mix(cCol, cCol * 1.5 + .1,
        1. - smoothstep(0., sf * 2., abs(gCir + ew / 4.) - ew / 4.));

    texCol = vec3(.0);
    texCol = mix(texCol, cCol, 1. - smoothstep(0., sf, d3.x + ew));

    #ifdef SHOW_SPHERE
    mat3 cam = mat3(rgt, up, fwd);
    mat4 cam4 = mat4(rgt, 0, up, 0, fwd, 0, ro, 1.);
    mat4 invCam = inverse(cam4);
    vec3 qq = (invCam * vec4(vec3(0), 1.)).xyz;
    vec2 s = (uv - qq.xy / qq.z / FOV) * qq.z;
    float r = gSphRadius / FOV;
    texCol = mix(texCol, vec3(0),
        1. - smoothstep(0., .003, abs(length(s) - r - .015) - .01));
    #endif

    col = texCol * (diff * sh + .3 + vec3(1, .97, .92) * spec * freS * 2. * sh);
    col *= ao * atten;
  }

  col = mix(col, vec3(0), smoothstep(0., .99, t / FAR));

  vec2 w = vec2(iResolution.x / iResolution.y, 1);
  col *= 1.05 - smoothstep(0., .1, sBoxS(uv, w / 2., .15) + .1) * .15;

  fragColor = vec4(sqrt(max(col, 0.)), 1);
}
