// --- generic helpers ---------------------------------------------------------
float gZoom = 1.;   // global zoom factor, set in mainImage — part of the
                    // screen->tile-local distance scale

#define Rot(a) mat2(cos(a),-sin(a),sin(a),cos(a))
#define S(d) (1.-smoothstep(-1.3,1.3, (d)*iResolution.y ))
#define SDF_NORMAL(F, p, e) normalize(vec3( \
    F((p) + vec3(e, 0., 0.)) - F((p) - vec3(e, 0., 0.)), \
    F((p) + vec3(0., e, 0.)) - F((p) - vec3(0., e, 0.)), \
    F((p) + vec3(0., 0., e)) - F((p) - vec3(0., 0., e))))

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

vec2 gSeed = vec2(0.);   // session hash offset (sk_seed), set in mainImage —
                         // reshuffles every random() draw, so the quadtree
                         // pattern differs each session

float random (vec2 p) {
    return fract(sin(dot(p.xy + gSeed, vec2(12.9898,78.233)))* 43758.5453123);
}

uint pcg(uint v){
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

float pcgHash(uvec3 v){
    return float(pcg(v.x + pcg(v.y + pcg(v.z)))) / 4294967295.;
}

float cubicInOut(float t) {
  return t < 0.5
    ? 4.0 * t * t * t
    : 0.5 * pow(2.0 * t - 2.0, 3.0) + 1.0;
}

// alternates 0/1 every `period`, easing over TRANS_DUR at each flip;
// block 0 (and anything before it) is 0
float flipflop(float t, float period){
    float k = floor(t/period);
    float s = mod(k, 2.);
    float prev = (k < 0.5) ? 0. : 1.-s;
    return mix(prev, s, smoothstep(0., TRANS_DUR, t - k*period));
}

vec2 rotAround(vec2 p, vec2 c, float a){ return (p-c)*Rot(a)+c; }

mat3 rotY(float a){ return mat3(cos(a), 0., -sin(a), 0., 1., 0., sin(a), 0., cos(a)); }
mat3 rotX(float a){ return mat3(1., 0., 0., 0., cos(a), sin(a), 0., -sin(a), cos(a)); }

vec2 ssOffset(int i, int n){
    return (vec2(i % n, i / n) + 0.5) / float(n) - 0.5;
}

vec3 bgNoise(vec2 tp){
    return vec3(mix(NOISE_LO, NOISE_HI, texture(iChannel1, fract(tp)).r));
}

vec3 filmGrain(vec3 col, float amt){
    uvec2 px = uvec2(ivec2(floor(gl_FragCoord.xy)));
    uint fr = uint(iTime * FILM_FPS);
    float g = pcgHash(uvec3(px, fr)) + pcgHash(uvec3(px, fr + 7919u)) - 1.;
    float l = dot(col, LUMA);
    return max(col + g * amt * (0.3 + 0.7 * 4. * l * (1. - l)), 0.);
}

vec3 acesApprox(vec3 v){
    v = max(v, 0.) * 0.6;
    return clamp((v * (2.51 * v + 0.03)) / (v * (2.43 * v + 0.59) + 0.14), 0., 1.);
}

vec3 srgbEncode(vec3 c){
    return mix(1.055 * pow(c, vec3(1. / 2.4)) - 0.055, 12.92 * c, step(c, vec3(0.0031308)));
}

float sdBox(vec2 p, vec2 b){
    vec2 q = abs(p) - b;
    return length(max(q, 0.)) + min(max(q.x, q.y), 0.);
}
float sdBox(vec3 p, vec3 b){
    vec3 q = abs(p) - b;
    return length(max(q, 0.)) + min(max(q.x, max(q.y, q.z)), 0.);
}
float sdRoundBox(vec2 p, vec2 b, float r){ return sdBox(p, b - r) - r; }
float sdRoundBox(vec3 p, vec3 b, float r){ return sdBox(p, b - r) - r; }

float sdExtrude(float d2, float z, float h, float r){
    vec2 w = vec2(d2 + r, abs(z) - h + r);
    return min(max(w.x, w.y), 0.) + length(max(w, 0.)) - r;
}

float sdSegment(vec2 p, vec2 a, vec2 b){
    vec2 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0., 1.));
}
float sdSegment(vec3 p, vec3 a, vec3 b){
    vec3 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0., 1.));
}

float sdRoundCone(vec3 p, vec3 a, vec3 b, float r1, float r2){
    vec3 ba = b - a;
    float l2 = dot(ba, ba);
    float rr = r1 - r2;
    float a2 = l2 - rr * rr;
    float il2 = 1. / l2;
    vec3 pa = p - a;
    float y = dot(pa, ba);
    float z = y - l2;
    vec3 xv = pa * l2 - ba * y;
    float x2 = dot(xv, xv);
    float y2 = y * y * l2;
    float z2 = z * z * l2;
    float k = sign(rr) * rr * rr * x2;
    if(sign(z) * a2 * z2 > k) return sqrt(x2 + z2) * il2 - r2;
    if(sign(y) * a2 * y2 < k) return sqrt(x2 + y2) * il2 - r1;
    return (sqrt(x2 * a2 * il2) + y * rr) * il2 - r1;
}

vec2 boxHit(vec3 ro, vec3 rd, vec3 bmin, vec3 bmax){
    vec3 inv = 1. / (rd + vec3(1e-7));
    vec3 ta = (bmin - ro) * inv, tb = (bmax - ro) * inv;
    vec3 t0 = min(ta, tb), t1 = max(ta, tb);
    return vec2(max(max(t0.x, t0.y), t0.z), min(min(t1.x, t1.y), t1.z));
}

vec3 bez3(vec3 a, vec3 b, vec3 c, vec3 d, float t){
    float s = 1. - t;
    return s * s * s * a + 3. * s * s * t * b + 3. * s * t * t * c + t * t * t * d;
}

vec2 catmull(vec2 a, vec2 b, vec2 c, vec2 d, float t){
    return 0.5 * (2. * b + (c - a) * t + (2. * a - 5. * b + 4. * c - d) * t * t + (3. * b - a - 3. * c + d) * t * t * t);
}
