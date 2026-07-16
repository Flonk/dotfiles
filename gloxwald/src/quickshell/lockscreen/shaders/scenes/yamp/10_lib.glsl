// --- generic helpers ---------------------------------------------------------
float gZoom = 1.;   // global zoom factor, set in mainImage — part of the
                    // screen->tile-local distance scale

#define Rot(a) mat2(cos(a),-sin(a),sin(a),cos(a))
#define S(d) (1.-smoothstep(-1.3,1.3, (d)*iResolution.y ))

vec2 gSeed = vec2(0.);   // session hash offset (sk_seed), set in mainImage —
                         // reshuffles every random() draw, so the quadtree
                         // pattern differs each session

float random (vec2 p) {
    return fract(sin(dot(p.xy + gSeed, vec2(12.9898,78.233)))* 43758.5453123);
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

// squircle tile: circle/rounded-box mix (Hyeve, shadertoy) — a true SDF,
// unlike the superellipse. Returns (distance, gradient); the gradient is
// the same mix of both shapes' gradients (mix is linear, so it's exact).
vec3 sdSquircle(vec2 p, float r, float n){
    float lp = max(length(p), 1e-6);
    vec2 q = abs(p) - n*r;
    vec2 mq = max(q, 0.);
    float lmq = length(mq);
    float square = min(max(q.x,q.y),0.) + lmq - (r - n*r);
    vec2 gsq = (lmq > 1e-6) ? sign(p)*mq/lmq
             : ((q.x > q.y) ? vec2(sign(p.x),0.) : vec2(0.,sign(p.y)));
    vec2 g = mix(p/lp, gsq, n);
    g /= max(length(g), 1e-6);
    return vec3(mix(lp - r, square, n), g);
}

// per-cell vortex swirl (otavio good's Spiral): rotational offset,
// strongest at each cell center, scaled by amt
vec2 spiral(vec2 uv, float amt){
    vec2 d = fract(uv * 2.) - 0.5;
    float blend = pow(clamp((0.5 - length(d)) * 2., 0., 1.), 1.5);
    return uv + vec2(d.y, -d.x) * blend * amt;
}

// star sheets (after the galaxy shader's starLayer): one jittered star per
// STAR_CELL-pixel cell, power-law brightness — thousands dim, a few
// bright — round and antialiased (sizes in actual screen pixels). ids wrap
// to keep the hash healthy after hours of background scroll
float starSheet(vec2 g, float cellPx, float dens){
    vec2 id = mod(floor(g), 1024.);
    vec2 f = fract(g) - 0.5;
    vec2 off = (vec2(random(id + 4.2), random(id + 8.4)) - 0.5) * 0.7;
    float dpx = length(f - off) * cellPx;
    return smoothstep(STAR_R + 0.7, STAR_R - 0.7, dpx)
         * pow(random(id), STAR_POW / max(dens, 1e-3));
}

// two sheets: the second is finer, dimmer, and drifts slowly against the
// background scroll for depth parallax. the lattice is fixed in background
// coords so stars ride the same scroll as the noise/nebula through zoom
// and pad transitions; only the pixel radius compensates for zoom so the
// dots stay STAR_R px round
float stars(vec2 p, float dens){
    float f = iResolution.y / (NOISE_SCALE * STAR_CELL);
    return starSheet(p * f, STAR_CELL / gZoom, dens)
         + starSheet(p * f * 1.7 + vec2(3.7, iTime * STAR_DRIFT),
                     STAR_CELL / (1.7 * gZoom), dens) * 0.8;
}
