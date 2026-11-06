// --- gasket: endless zoom into an inverted Apollonian gasket of amps ----------
// The gasket is a lattice of tangent circles (centres on half-integers) whose
// square gaps hold, inverted about the gap centre (p -> 0.25 p / |p|^2), the
// whole lattice again. The screen is inverted onto it too (u -> 0.1 / conj u
// + GASK_O), and GASK_O is chosen so that one level down is an exact
// anti-similar copy of the level above about the fixed point GASK_FIX: two
// levels down is the same picture scaled by GASK_ZOOM. Zooming that far into
// GASK_FIX over GASK_PERIOD and wrapping is seamless, and every circle keeps
// its screen size and place, so animation clocks keyed on those (see below)
// carry on across the wrap.
const float GASK_PERIOD = 40.;
const float GASK_INV    = 0.1;
const float GASK_O      = -0.20710678;   // (1 - sqrt 2) / 2
const float GASK_FIX    = 0.07071068;    // 0.1 / sqrt 2
const float GASK_ZOOM   = 33.970563;     // (3 + 2 sqrt 2)^2
const float GASK_VIEW   = 0.04;
const int   GASK_LEVELS = 20;
const float GASK_AMP    = 0.68;
const float GASK_PAD    = 0.;
const float GASK_RING   = 0.0025;
const vec3  GASK_RING_COL = mix(GRAD_BOT, GRAD_TOP, 0.5) * 0.5;
const vec2  GASK_FADE   = vec2(3., 200.);
const float GASK_FADE_A = 0.5;
const float GASK_CYCLES = 3.;            // amp loops per zoom period, integer
const float GASK_OFF    = 0.15;
const vec3  GASK_DEEP   = vec3(0.3);
const vec2  GASK_TINT   = vec2(4., 250.);
const vec3  GASK_LIGHT  = vec3(-0.45, 0.55, 0.7);
const float GASK_BEVEL  = 0.08;
const float GASK_BEVEL_K = 1.6;
const float GASK_SPEC   = 0.25;
const float GASK_EMBOSS = 0.6;
const float GASK_EMBOSS_D = 0.025;
const float GASK_SHADOW = 0.6;
const float GASK_SHADOW_OFF = 0.08;
const float GASK_SHADOW_SOFT = 0.06;

// circle (xy centre, z radius) inverted about the origin with factor f
vec3 gaskInvert(vec3 c, float f){
    float k = dot(c.xy, c.xy) - c.z * c.z;
    return vec3(f * c.xy / k, f * c.z / abs(k));
}

// circle (centre, radius) of level i, in level-i coordinates, mapped back up
// through every level onto the screen
vec3 gaskScreen(vec3 c, int i, vec2 gap[GASK_LEVELS], float z){
    for(int k = i - 1; k >= 0; k--){
        c = gaskInvert(c, 0.25);
        c.xy += gap[k];
    }
    c.xy -= vec2(GASK_O, 0.);
    c = gaskInvert(c, GASK_INV);
    return vec3((c.xy - vec2(GASK_FIX, 0.)) / z, c.z / z);
}

vec3 gasket(vec2 q, vec2 tp){
    float lt = iTime / GASK_PERIOD;
    float z = GASK_VIEW * pow(GASK_ZOOM, -fract(lt));
    vec2 u = vec2(GASK_FIX, 0.) + q * z;
    float uu = max(dot(u, u), 1e-12);
    vec2 p = GASK_INV * u / uu + vec2(GASK_O, 0.);
    float px = z / iResolution.y * GASK_INV / uu;
    vec3 L = normalize(GASK_LIGHT);
    vec2 sdir = -normalize(L.xy);

    vec2 gap[GASK_LEVELS];
    vec3 col = bgNoise(tp);
    float shadow = 0.;
    for(int i = 0; i < GASK_LEVELS; i++){
        vec2 cell = floor(p);
        float sqd = length(p - cell - 0.5) - 0.5 * (1. - GASK_PAD);
        // below level 0 the four circles round the origin are the parent
        // gap's bounding circles mapped onto themselves: already drawn
        bool parent = i > 0 && abs(cell.x + 0.5) < 1. && abs(cell.y + 0.5) < 1.;
        if(!parent && sqd < px * 1.3){
            vec3 c = gaskScreen(vec3(cell + 0.5, 0.5 * (1. - GASK_PAD)), i, gap, z);

            // the amp clock runs on the circle's screen size, which grows in
            // step with the zoom, and its angle round the zoom centre: the
            // same circle after a loop is in the same state
            float ang = atan(c.y, c.x);
            float ph = GASK_CYCLES * log(c.z) / log(GASK_ZOOM) + 0.5 * sin(3. * ang);
            float frame = LOOP_LEN * fract(ph);
            float shade = 1. - GASK_FADE_A * (1. - smoothstep(log(GASK_FADE.x), log(GASK_FADE.y), log(c.z * iResolution.y)));
            float deep = 1. - smoothstep(log(GASK_TINT.x), log(GASK_TINT.y), log(c.z * iResolution.y));

            vec2 rel = q - c.xy;
            float sd = length(rel) - c.z;
            float sc = c.z / (0.5 * (1. - GASK_PAD)) * GASK_AMP;
            vec2 gp = rel / sc;
            float dir = sin(5. * ang) < 0. ? -1. : 1.;
            vec2 pJ, pP;
            ampSpin(gp, frame, dir, pJ, pP);
            vec2 d = ampPieces(pJ, pP);
            vec3 inner = mix(vec3(0.), vec3(GASK_OFF), S(max(sd, min(d.x, d.y) * sc)));
            inner = mix(inner, mix(ampGradient(gp), GASK_DEEP, deep), S(max(sd, ampFill(pJ, pP, d, frame) * sc)));
            inner = mix(inner, mix(GASK_RING_COL, GASK_DEEP * 0.5, deep), S(abs(sd + GASK_RING) - GASK_RING));

            // embossed amp: compare the glyph with itself nudged towards the
            // light, lit where its edge faces the light, shaded opposite
            vec2 qJ, qP;
            ampSpin(gp + L.xy * GASK_EMBOSS_D, frame, dir, qJ, qP);
            vec2 d2 = ampPieces(qJ, qP);
            float w = max(1.5 / (iResolution.y * sc), 0.004);
            float m0 = smoothstep(w, -w, min(d.x, d.y)), m1 = smoothstep(w, -w, min(d2.x, d2.y));
            inner *= 1. + GASK_EMBOSS * (m0 - m1);

            // bevelled rim: the face tilts outwards over the last stretch
            float t = clamp(-sd / (c.z * GASK_BEVEL), 0., 1.);
            vec3 n = normalize(vec3(normalize(rel) * GASK_BEVEL_K * (1. - t) * (1. - t), 1.));
            inner *= dot(n, L) / L.z;
            inner += GASK_SPEC * pow(max(dot(reflect(-L, n), vec3(0., 0., 1.)), 0.), 16.) * (1. - t);

            col = mix(col, inner * shade, S(sd));
            if(sqd < -px * 1.3) break;
        }
        if(px > 0.25) break;
        vec2 l = fract(p - 0.5) - 0.5;
        gap[i] = p - l;

        // drop shadows of this gap's four bounding circles on everything
        // behind them (the parents' were cast a level up)
        bool home = i > 0 && gap[i] == vec2(0.);
        if(!home && length(l) < 0.42){
            for(int k = 0; k < 4; k++){
                vec2 o = vec2(k & 1, k >> 1) - 0.5;
                vec3 c = gaskScreen(vec3(gap[i] + o, 0.5 * (1. - GASK_PAD)), i, gap, z);
                float ds = length(q - c.xy - sdir * c.z * GASK_SHADOW_OFF) - c.z;
                shadow = max(shadow, 1. - smoothstep(-c.z * GASK_SHADOW_SOFT, c.z * GASK_SHADOW_SOFT, ds));
            }
        }

        float ll = max(dot(l, l), 1e-12);
        p = 0.25 * l / ll;
        px *= 0.25 / ll;
    }
    return col * (1. - GASK_SHADOW * shadow);
}
