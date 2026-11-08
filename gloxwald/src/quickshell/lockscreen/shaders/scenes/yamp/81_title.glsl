// --- title: the amp and the tagline -----------------------------------------
// A transition, T_TITLE long on its own clock: the old scene dims away over
// TI_FADE, then the amp (TI_AMP tall) and FLAP_TEXT pop in one
// after the other on an ease-out-back (TI_AT, TI_IN), hold, shrink away in
// turn (TI_OUT) and the new scene comes up over the last TI_FADE. Text is
// Montserrat from the flap font atlas, TI_TAG_ADV advances in cell heights.
const float TI_FADE   = 0.45;
const vec2  TI_AT     = vec2(0.35, 0.6);
const float TI_IN     = 0.6;
const float TI_OUT    = 0.35;
const float TI_LEAVE  = 0.08;
const float TI_AMP    = 0.35 * TRANS_AMP;
const float TI_AMP_Y  = 0.05;
const float TI_TAG_Y  = -0.1;
const float TI_TAG_H  = 0.08;
const float TI_TAG_W  = 6.193;
const float TI_TAG_ADV[FLAP_TEXT_LEN] = float[FLAP_TEXT_LEN](0.228, 0.303, 0.174, 0.368, 0.197, 0.303, 0.207, 0.753, 0.445, 0.197,
                                                             0.303, 0.461, 0.197, 0.490, 0.487, 0.207, 0.207, 0.491, 0.174);

float tiScale(float ph, int i){
    float a = clamp((ph - TI_AT[i]) / TI_IN, 0., 1.), b = a - 1.;
    float o = clamp((ph - (T_TITLE - TI_FADE - TI_OUT - float(1 - i) * TI_LEAVE)) / TI_OUT, 0., 1.);
    return (1. + 2.70158 * b * b * b + 1.70158 * b * b) * (1. - o * o * o);
}

float tiTag(vec2 tq){
    float x = -0.5 * TI_TAG_W, d = 1e9;
    for(int i = 0; i < FLAP_TEXT_LEN; i++){
        float cx = x + 0.5 * TI_TAG_ADV[i];
        if(abs(tq.x - cx) < 0.4) d = min(d, flapGlyph(FLAP_TEXT[i], vec2(tq.x - cx, tq.y)));
        x += TI_TAG_ADV[i];
    }
    return d;
}

vec3 title(vec2 q, vec2 tp){
    float ph = gModeT[MODE_TITLE];
    vec3 col = mix(gPrevCol, bgNoise(tp), smoothstep(0., TI_FADE, ph));
    col = mix(col, gNextCol, smoothstep(T_TITLE - TI_FADE, T_TITLE, ph));

    float s = tiScale(ph, 0) * TI_AMP;
    if(s > 0.001){
        vec2 g = (q - vec2(0., TI_AMP_Y)) / s;
        if(abs(g.y) < 0.6 && abs(g.x) < 0.6) col = mix(col, ampGradient(g), S(glyphDist(g) * s));
    }
    float h = tiScale(ph, 1) * TI_TAG_H;
    if(h > 0.001){
        vec2 tq = (q - vec2(0., TI_TAG_Y)) / h;
        if(abs(tq.y) < 0.5 && abs(tq.x) < 0.5 * TI_TAG_W + 0.5) col = mix(col, vec3(0.95), S(tiTag(tq) * h));
    }
    return col;
}

// --- shared by the transitions after this one --------------------------------
// tcCard draws the amp (TC_AMP tall) and the tagline under it round c, each
// scaled about its own centre (as, ts); tcBack is the ease-out-back the cards
// pop in on, tcPop one in at `at` and out from `leave`; tcFbm is value noise
const float TC_AMP     = 0.5 * TRANS_AMP;
const vec2  TC_AMP_OFF = vec2(0., 0.07);
const vec2  TC_TAG_OFF = vec2(0., -0.125);

float tcBack(float x){
    x = clamp(x, 0., 1.);
    float b = x - 1.;
    return 1. + 2.70158 * b * b * b + 1.70158 * b * b;
}

float tcPop(float t, float at, float leave){
    float o = clamp((t - leave) / TI_OUT, 0., 1.);
    return tcBack((t - at) / TI_IN) * (1. - o * o * o);
}

float tcAmpD(vec2 q, vec2 c, float s){
    if(s < 1e-3) return 1.;
    vec2 g = (q - c - TC_AMP_OFF) / (TC_AMP * s);
    float box = max(abs(g.x), abs(g.y));
    return (box < 0.8 ? glyphDist(g) : box - 0.5) * TC_AMP * s;
}

float tcTagD(vec2 q, vec2 c, float s){
    if(s < 1e-3) return 1.;
    float h = TI_TAG_H * s;
    vec2 tq = (q - c - TC_TAG_OFF) / h;
    if(abs(tq.y) > 0.5 || abs(tq.x) > 0.5 * TI_TAG_W + 0.5) return h;
    return min(tiTag(tq), 1.) * h;
}

vec3 tcCard(vec3 col, vec2 q, vec2 c, float as, float ts){
    if(as > 1e-3){
        vec2 g = (q - c - TC_AMP_OFF) / (TC_AMP * as);
        if(abs(g.x) < 0.6 && abs(g.y) < 0.6) col = mix(col, ampGradient(g), S(glyphDist(g) * TC_AMP * as));
    }
    if(ts > 1e-3) col = mix(col, vec3(0.95), S(tcTagD(q, c, ts)));
    return col;
}

float tcNoise(vec2 p){
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3. - 2. * f);
    return mix(mix(random(i), random(i + vec2(1., 0.)), f.x), mix(random(i + vec2(0., 1.)), random(i + 1.), f.x), f.y);
}

float tcFbm(vec2 p){
    float a = 0.5, s = 0.;
    for(int i = 0; i < 4; i++){
        s += a * tcNoise(p);
        p = p * 2.03 + 17.1;
        a *= 0.5;
    }
    return s;
}
