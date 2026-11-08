// --- ink: the amp drops into the old scene like ink into water ---------------
// A transition, T_INK long. The amp falls onto the old scene and lands at
// INK_DROP, then bleeds out as swirling deep-teal ink, its edge torn up by
// noise, until the screen is ink (INK_SPREAD). The amp and the tagline
// surface out of it, sink again, and from INK_CLEAR_AT a second noisy front
// clears the ink from the middle outwards onto the new scene.
const float INK_DROP     = 0.6;
const float INK_SPREAD   = 2.;
const float INK_CLEAR_AT = 4.9;
const float INK_CLEAR    = 1.8;
const float INK_REACH    = 1.9;

float inkFront(vec2 q, float r, float seed, float t){
    float d = length(q - TC_AMP_OFF);
    float a = atan(q.y - TC_AMP_OFF.y, q.x);
    float w = tcFbm(q * 3. + vec2(seed, t * 0.2)) - 0.5;
    float tend = tcFbm(vec2(a * 2.5 + seed, d * 3. - t * 0.6)) - 0.5;
    return d + (0.35 * w + 0.25 * tend) * (0.25 + d) - r;
}

vec3 ink(vec2 q, vec2 tp){
    float ph = gModeT[MODE_INK];
    vec3 col = gPrevCol;

    float u = clamp((ph - INK_DROP) / INK_SPREAD, 0., 1.);
    float r = INK_REACH * (1. - (1. - u) * (1. - u)) * step(INK_DROP, ph);
    float f = inkFront(q, r, 0., ph);
    float m = smoothstep(0.02, -0.02, f) * step(1e-4, r);
    vec2 sw = q * 4. + 0.3 * vec2(sin(ph * 0.4), cos(ph * 0.3));
    float v = tcFbm(sw + 2. * tcFbm(q * 2. + ph * 0.1));
    vec3 inkc = mix(GRAD_BOT * 0.08, GRAD_BOT * 0.6, v * v);
    inkc += GRAD_TOP * 0.5 * smoothstep(0.05, 0., abs(f)) * (1. - u);
    col = mix(col, inkc, m);

    float fall = clamp(ph / INK_DROP, 0., 1.);
    vec2 c = vec2(0., 0.9 * (1. - fall * fall));
    float melt = 1. - smoothstep(0., 0.6, ph - INK_DROP);
    vec2 g = (q - c - TC_AMP_OFF) / TC_AMP;
    if(melt > 0. && abs(g.x) < 0.6 && abs(g.y) < 0.6) col = mix(col, ampGradient(g), S(glyphDist(g) * TC_AMP) * melt);

    col = tcCard(col, q, vec2(0.), tcPop(ph, 2.5, INK_CLEAR_AT - 0.45), tcPop(ph, 2.75, INK_CLEAR_AT - 0.37));

    float u2 = clamp((ph - INK_CLEAR_AT) / INK_CLEAR, 0., 1.);
    float r2 = INK_REACH * cubicInOut(u2) * step(INK_CLEAR_AT, ph);
    float f2 = inkFront(q, r2, 7.3, ph);
    float m2 = smoothstep(0.02, -0.02, f2) * step(1e-4, r2);
    col = mix(col, gNextCol, m2);
    col += GRAD_TOP * 0.4 * smoothstep(0.04, 0., abs(f2)) * step(1e-4, r2) * (1. - u2);
    return col;
}
