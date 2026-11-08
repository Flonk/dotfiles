// --- stamp: the amp slammed onto the old scene -------------------------------
// A transition, T_STAMP long. The amp drops onto the old scene from ST_DROP
// times its size, its shadow tightening under it, and slams down at ST_HIT
// with a shake and a soft shockwave running out from its edge (stWave);
// the tagline stamps down the same way at ST_TAG. At ST_LIFT both lift off and fade, and where the
// amp stood its imprint is a window onto the new scene, which opens out
// (irWindow) until it covers the screen.
const float ST_DROP = 2.6;
const float ST_FALL = 0.45;
const float ST_HIT  = 0.65;
const float ST_TAG  = 1.45;
const float ST_LIFT = 4.2;
const float ST_OPEN = 4.8;

float stWave(float d, float t, float reach){
    if(t < 0. || t > 0.9 || d < 0.) return 0.;
    float r = reach * (1. - (1. - t / 0.9) * (1. - t / 0.9) * (1. - t / 0.9));
    return exp(-abs(d - r) / (0.006 + 0.03 * t)) * (1. - t / 0.9) * smoothstep(0., 0.05, t);
}

vec3 stamp(vec2 q, vec2 tp){
    float ph = gModeT[MODE_STAMP];
    float lift = smoothstep(ST_LIFT, ST_LIFT + 0.5, ph);
    vec3 col = gPrevCol * (1. - 0.25 * smoothstep(ST_HIT, ST_HIT + 0.2, ph) * (1. - lift));

    float sh = ph - ST_HIT;
    vec2 shake = vec2(sin(ph * 70.), cos(ph * 53.)) * 0.012 * exp(-max(sh, 0.) * 8.) * step(0., sh);
    shake += vec2(sin(ph * 67.), cos(ph * 49.)) * 0.006 * exp(-max(ph - ST_TAG, 0.) * 8.) * step(ST_TAG, ph);

    float fa = clamp((ph - (ST_HIT - ST_FALL)) / ST_FALL, 0., 1.);
    float sa = mix(ST_DROP, 1., fa * fa) + lift * lift * 1.4;
    float aa = smoothstep(0., 0.3, fa) * (1. - lift);
    float ft = clamp((ph - (ST_TAG - ST_FALL)) / ST_FALL, 0., 1.);
    float stg = mix(ST_DROP, 1., ft * ft) + lift * lift * 1.4;
    float at = smoothstep(0., 0.3, ft) * (1. - lift);

    float d0 = glyphDist((q - TC_AMP_OFF) / TC_AMP) * TC_AMP;
    if(ph > ST_LIFT){
        float y = clamp((ph - ST_OPEN) / (T_STAMP - ST_OPEN), 0., 1.);
        vec2 g;
        float w = irWindow(q, exp(log(IR_ZOOM) * y * y * y), g);
        float win = max(S(w), smoothstep(0.85, 1., y));
        col = mix(col, gNextCol, win * smoothstep(ST_LIFT, ST_LIFT + 0.3, ph));
        col *= 1. - 0.6 * exp(-max(w, 0.) / 0.006) * (1. - y);
    }

    if(aa > 0.){
        float dsh = tcAmpD(q - vec2(0.012, -0.02) * sa, vec2(0.), sa * 0.98);
        col *= 1. - 0.45 * aa * exp(-max(dsh, 0.) / (0.01 + 0.04 * (sa - 1.)));
    }
    col += mix(GRAD_TOP, vec3(1.), 0.5) * 0.35 * stWave(d0, sh, 0.35);
    col = mix(col, tcCard(col, q + shake, vec2(0.), sa, 0.), aa);
    col = mix(col, tcCard(col, q + shake, vec2(0.), 0., stg), at);
    col += vec3(1.) * 0.15 * exp(-max(sh, 0.) * 12.) * step(0., sh) * (1. - smoothstep(0., 0.3, d0));
    return col;
}
