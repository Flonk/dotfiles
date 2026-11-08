// --- shatter: a glass amp shot three times, bursting and rewinding ----------
// A transition, SH_PERIOD long on its own clock: the old scene dims away
// (SH_DIM) as a glass amp (SH_SCALE tall) takes bullets at SH_HITS
// times, each at one of the SH_SPOTS points inside the glyph: a flash, a hole,
// and a web of cracks round it. The cracks and shards come from a Voronoi
// in log-polar space round the impact (SH_SECTORS round, rings growing
// outwards), so pieces are small at the hole and large far from it. The
// last hit bursts it along that impact's pattern: every piece flies off away
// from the hole (faster the closer it was), tumbling and falling out of the
// frame. SH_TEXT_AT after the burst FLAP_TEXT pops in on an ease-out-back
// in Montserrat (the flap font atlas, SH_ADV advances in cell heights) and
// holds until it shrinks away as the period ends, when a new amp flies in, growing out
// of the distance on a fast ease-out-back (SH_IN). A
// pixel finds its piece by undoing each nearby piece's motion and checking
// that the point it lands on belongs to that piece; as every piece flies
// straight out from the hole (plus the shared lift and fall), only the
// SH_REACH sectors either side of the pixel's own direction are tried.
const float SH_PERIOD   = T_SHATTER;
const float SH_SCALE    = TRANS_AMP;
const vec3  SH_HITS     = vec3(2.2, 3., 3.8);
const float SH_IN       = 0.55;
const float SH_SECTORS  = 13.;
const float SH_RING     = 2.6;
const int   SH_RINGS    = 10;
const float SH_SPEED    = 0.16;
const float SH_GRAVITY  = 0.8;
const float SH_SPIN     = 3.;
const float SH_CRACK    = 0.045;
const int   SH_REACH    = 2;
const float SH_TEXT_AT  = 1.;
const float SH_DIM      = 0.45;
const float SH_TEXT_IN  = 0.5;
const float SH_TEXT_OUT = 0.35;
const float SH_TEXT_H   = 0.08;
const float SH_TEXT_W   = 6.188;
const float SH_ADV[FLAP_TEXT_LEN] = float[FLAP_TEXT_LEN](0.228, 0.303, 0.174, 0.368, 0.197, 0.303, 0.206, 0.752, 0.444, 0.197,
                                                         0.303, 0.461, 0.197, 0.490, 0.486, 0.206, 0.206, 0.491, 0.174);
const int   SH_N_SPOTS  = 16;
const vec2  SH_SPOTS[SH_N_SPOTS] = vec2[SH_N_SPOTS](
    vec2(0.111, -0.353), vec2(0.056, 0.389), vec2(-0.194, 0.325), vec2(-0.272, -0.347),
    vec2(0.272, -0.383), vec2(0.259, -0.169), vec2(-0.103, 0.420), vec2(-0.155, 0.071),
    vec2(-0.266, -0.068), vec2(-0.210, 0.197), vec2(0.178, 0.342), vec2(0.039, -0.081),
    vec2(0.011, -0.427), vec2(-0.316, -0.227), vec2(-0.156, -0.422), vec2(0.136, -0.213));

vec2 shSpot(float k, int h){
    return SH_SPOTS[int(random(vec2(k, float(h) * 3.7 + 0.4)) * float(SH_N_SPOTS)) % SH_N_SPOTS];
}

vec2 shSeed(vec2 cell, float key){
    return cell + 0.15 + 0.7 * vec2(random(cell + key), random(cell.yx + key + 7.3));
}

// log-polar coordinates of glyph point g round impact c
vec2 shPolar(vec2 g, vec2 c){
    vec2 v = g - c;
    return vec2(atan(v.y, v.x) / 6.2831853 * SH_SECTORS, log(length(v) + 0.02) * SH_RING);
}

// nearest Voronoi seed's cell (x) and F2 - F1 (y, crack distance) at log-polar u
vec3 shVoronoi(vec2 u, float key, out vec2 nrm){
    vec2 iu = floor(u);
    float d1 = 1e9, d2 = 1e9;
    vec2 best = vec2(0.), s1 = vec2(0.), s2 = vec2(0.);
    for(int j = -1; j <= 1; j++) for(int i = -1; i <= 1; i++){
        vec2 c = iu + vec2(i, j);
        vec2 cw = vec2(mod(c.x, SH_SECTORS), c.y);
        vec2 sp = c + (shSeed(cw, key) - cw);
        float d = length(u - sp);
        if(d < d1){ d2 = d1; s2 = s1; d1 = d; s1 = sp; best = cw; } else if(d < d2){ d2 = d; s2 = sp; }
    }
    nrm = normalize(s2 - s1 + 1e-6);
    return vec3(best, d2 - d1);
}

// colour of a crack through glyph point g round impact c whose Voronoi edge
// has log-polar normal n: the edge's direction on the glass, carried back
// from log-polar space, decides how much of the light it catches, from deep
// amp blue to a bright teal glint
vec3 shCrackColour(vec2 g, vec2 c, vec2 n){
    vec2 er = normalize(g - c + 1e-6), et = vec2(-er.y, er.x);
    vec2 en = normalize(et * n.x * SH_SECTORS / 6.2831853 + er * n.y * SH_RING);
    float lit = abs(dot(en, normalize(vec2(-0.6, 0.8))));
    return mix(GRAD_BOT * 0.45, mix(GRAD_TOP, vec3(1.), 0.45) * 1.25, lit * lit);
}

// a piece's centre in glyph space
vec2 shCentre(vec2 cell, vec2 c, float key){
    vec2 s = shSeed(cell, key);
    float a = s.x / SH_SECTORS * 6.2831853, r = exp(s.y / SH_RING) - 0.02;
    return c + r * vec2(cos(a), sin(a));
}

vec3 shGlass(vec2 g, float lit){
    return ampGradient(g) * (0.85 + 0.3 * lit) + vec3(0.25) * pow(max(lit, 0.), 6.);
}

vec3 shatter(vec2 q, vec2 tp){
    float k = gModeK[MODE_SHATTER], ph = gModeT[MODE_SHATTER];
    vec3 col = mix(gPrevCol, bgNoise(tp), smoothstep(0., SH_DIM, ph));
    vec2 g = q / SH_SCALE;
    float px = 1. / (iResolution.y * SH_SCALE);
    float arrive = clamp(ph / SH_IN, 0., 1.);
    float back = arrive - 1., grow = 1. + 2.70158 * back * back * back + 1.70158 * back * back;
    vec2 gi = g / max(grow, 1e-3);
    vec2 c3 = shSpot(k, 2);
    float key = k * 1.37;

    float fly = max(ph - SH_HITS.z, 0.);

    if(fly <= 0.){
        g = gi;
        float d = glyphDist(g);
        if(d < 4. * px){
            float lit = 0.5 + 0.5 * dot(normalize(vec2(glyphDist(g + vec2(.01, 0.)) - glyphDist(g - vec2(.01, 0.)), glyphDist(g + vec2(0., .01)) - glyphDist(g - vec2(0., .01))) + 1e-6), normalize(vec2(-0.6, 0.8)));
            vec3 gc = shGlass(g, smoothstep(-0.03, 0., d) * lit);
            for(int h = 0; h < 3; h++){
                if(ph < SH_HITS[h]) continue;
                vec2 c = shSpot(k, h);
                vec2 cn;
                vec3 v = shVoronoi(shPolar(g, c), key + float(h) * 11., cn);
                float r = length(g - c);
                float crack = smoothstep(SH_CRACK * (0.4 + r), 0., v.z) * smoothstep(0.55, 0.05, r) * smoothstep(0., 0.15, ph - SH_HITS[h]);
                gc = mix(gc, shCrackColour(g, c, cn), crack * 0.9);
                gc = mix(gc, vec3(0.02), smoothstep(0.018, 0.01, r));
            }
            col = mix(col, gc, S(d * SH_SCALE * grow) * step(0.001, grow));
        }
    } else {
        float f = fly;
        vec2 rq = g - c3 - vec2(0., 0.15 * f - 0.5 * SH_GRAVITY * f * f);
        int s0 = int(floor(atan(rq.y, rq.x) / 6.2831853 * SH_SECTORS));
        for(int j = 0; j < SH_RINGS; j++){
            for(int di = -SH_REACH; di <= SH_REACH; di++){
                int i = (s0 + di + 4 * int(SH_SECTORS)) % int(SH_SECTORS);
                vec2 cell = vec2(float(i), float(j - SH_RINGS));
                vec2 cs = shCentre(cell, c3, key);
                vec2 dir = cs - c3;
                float dl = length(dir);
                vec2 vel = dir / max(dl, 1e-3) * SH_SPEED * (0.6 + 0.8 * random(cell + key + 2.2)) / (dl + 0.15) + vec2(0., 0.15);
                vec2 off = vel * f + vec2(0., -0.5 * SH_GRAVITY * f * f);
                float th = SH_SPIN * (random(cell + key + 5.1) - 0.5) * f;
                vec2 rel = g - cs - off;
                float rad = dl * 0.8 + 0.04;
                if(dot(rel, rel) > rad * rad) continue;
                vec2 g0 = cs + mat2(cos(th), -sin(th), sin(th), cos(th)) * rel;
                if(glyphDist(g0) > 0.) continue;
                vec2 cn;
                vec3 v = shVoronoi(shPolar(g0, c3), key + 22., cn);
                if(any(notEqual(v.xy, cell))) continue;
                float lit = 0.5 + 0.5 * cos(th * 1.7 + float(i));
                vec3 pc = shGlass(g0, lit) * mix(0.7, 1.1, lit);
                pc = mix(pc, shCrackColour(g0, c3, cn), smoothstep(0.06, 0.0, v.z) * 0.7);
                float edge = min(glyphDist(g0) * -1., v.z * 0.05);
                col = mix(col, pc, smoothstep(0., 2. * px, edge));
            }
        }
    }

    for(int h = 0; h < 3; h++){
        float dt = ph - SH_HITS[h];
        if(dt < 0. || dt > 0.6) continue;
        vec2 c = shSpot(k, h);
        float r = length(g - c);
        col += vec3(1., 0.95, 0.85) * exp(-dt * 10.) * (exp(-r / 0.04) + 0.6 * exp(-r / 0.2));
        col += vec3(0.9) * smoothstep(0.012, 0., abs(r - dt * 0.9)) * (1. - dt / 0.6) * 0.5;
    }

    col = mix(col, gNextCol, smoothstep(SH_PERIOD - SH_TEXT_OUT, SH_PERIOD, ph));
    float tin = clamp((ph - SH_HITS.z - SH_TEXT_AT) / SH_TEXT_IN, 0., 1.);
    float tout = clamp((ph - SH_PERIOD + SH_TEXT_OUT) / SH_TEXT_OUT, 0., 1.);
    float tb = tin - 1., ts = (1. + 2.70158 * tb * tb * tb + 1.70158 * tb * tb) * (1. - tout * tout * tout);
    if(ts > 0.001){
        float h = SH_TEXT_H * ts;
        vec2 tq = q / h;
        if(abs(tq.y) < 0.5 && abs(tq.x) < 0.5 * SH_TEXT_W + 0.5){
            float x = -0.5 * SH_TEXT_W, dt = 1e9;
            for(int i = 0; i < FLAP_TEXT_LEN; i++){
                float cx = x + 0.5 * SH_ADV[i];
                if(abs(tq.x - cx) < 0.4) dt = min(dt, flapGlyph(FLAP_TEXT[i], vec2(tq.x - cx, tq.y)));
                x += SH_ADV[i];
            }
            col = mix(col, vec3(0.95), S(dt * h));
        }
    }
    return col;
}
