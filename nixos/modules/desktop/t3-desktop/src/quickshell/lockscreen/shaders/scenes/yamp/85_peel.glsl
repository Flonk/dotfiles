// --- peel: the old scene peeled off like a sticker ---------------------------
// A transition, T_PEEL long, in three layers: the old scene on top, the amp
// with the tagline under it, the new scene at the bottom. From PE_AT.x the
// top layer is peeled from the bottom right corner, folding back flat along
// a line sweeping to the far corner over PE_DUR, its pale back showing and
// a soft shadow along the fold; from PE_AT.y the card is peeled the same
// way from the bottom left.
const vec2  PE_AT  = vec2(0.2, 4.6);
const float PE_DUR = 1.7;
const vec3  PE_BACK = vec3(0.80, 0.85, 0.86);

vec3 pePeel(vec2 q, vec3 top, vec3 below, float t, bool right){
    float asp = iResolution.x / iResolution.y;
    vec2 k = vec2((right ? 0.5 : -0.5) * asp, -0.5);
    vec2 dir = normalize(vec2(right ? -asp : asp, 1.));
    float smax = length(vec2(asp, 1.));
    float f = smax * 1.03 * cubicInOut(clamp(t / PE_DUR, 0., 1.));
    if(t <= 0.) return top;
    float s = dot(q - k, dir);
    if(s < f) return below * (1. - 0.5 * exp(-(f - s) / 0.03));
    vec2 src = q - 2. * (s - f) * dir;
    float on = S(sdBox(src, vec2(0.5 * asp, 0.5)));
    float u = s - f;
    vec3 back = PE_BACK * (0.62 + 0.38 * (1. - exp(-u / 0.06))) + 0.15 * exp(-u / 0.01);
    vec3 col = top;
    float shadow = (1. - on) * S(sdBox(q - 2. * (s - f + 0.012) * dir, vec2(0.5 * asp, 0.5)));
    col *= 1. - 0.35 * shadow;
    return mix(col, back, on);
}

vec3 peel(vec2 q, vec2 tp){
    float ph = gModeT[MODE_PEEL];
    vec3 card = tcCard(bgNoise(tp), q, vec2(0.), 1., 1.);
    if(ph < PE_AT.y) return pePeel(q, gPrevCol, card, ph - PE_AT.x, true);
    return pePeel(q, card, gNextCol, ph - PE_AT.y, false);
}
