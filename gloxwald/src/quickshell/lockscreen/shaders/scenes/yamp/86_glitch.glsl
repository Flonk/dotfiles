// --- glitch: the old scene breaks up into the card and on into the new ------
// A transition, T_GLITCH long. Over GL_OUT the old scene tears into
// horizontal bands that flip one by one to the card (the amp and the
// tagline, RGB-split and shoved sideways while it lasts), some bands
// corrupted to posterized, channel-swapped colour and stray blocks; the
// card holds with a twitch every so often, and over GL_IN it breaks the
// same way into the new scene. The bands reroll GL_FPS times a second.
const vec2  GL_OUT = vec2(0.2, 1.3);
const vec2  GL_IN  = vec2(4.5, 5.8);
const float GL_FPS = 24.;

vec3 glCard(vec2 q, vec2 tp, float dx){
    vec3 bg = bgNoise(tp);
    if(dx < 1e-4) return tcCard(bg, q, vec2(0.), 1., 1.);
    return vec3(tcCard(bg, q + vec2(dx, 0.), vec2(0.), 1., 1.).r,
                tcCard(bg, q, vec2(0.), 1., 1.).g,
                tcCard(bg, q - vec2(dx, 0.), vec2(0.), 1., 1.).b);
}

vec3 glitch(vec2 q, vec2 tp){
    float ph = gModeT[MODE_GLITCH];
    bool first = ph < 0.5 * (GL_OUT.y + GL_IN.x);
    vec2 win = first ? GL_OUT : GL_IN;
    float p = (ph - win.x) / (win.y - win.x);
    float k = p > 0. && p < 1. ? sin(3.1415927 * p) : 0.;
    float fr = floor(ph * GL_FPS);
    if(k == 0. && !first && ph < GL_IN.x && fract(ph * 0.8) < 0.06) k = 0.3;
    if(k == 0. && first && ph > GL_OUT.y && fract(ph * 0.8 + 0.5) < 0.06) k = 0.3;

    float bands = 8. + floor(random(vec2(fr, 1.3)) * 30.);
    float band = floor((q.y + 0.5) * bands);
    float th = 0.7 * random(vec2(band + 0.5 * bands, 7.1)) + 0.3 * random(vec2(band, fr));
    bool b = p * 1.2 - 0.1 > th;
    float hit = random(vec2(band, fr + 3.3));
    float dx = 0.012 * k;
    vec2 qs = q + vec2((random(vec2(band, fr + 11.)) - 0.5) * 0.2 * k * step(0.55, hit), 0.);

    vec3 a = first ? gPrevCol : glCard(qs, tp, dx);
    vec3 c = first ? glCard(qs, tp, dx) : gNextCol;
    if(first && p >= 1.) a = c;
    if(!first && p <= 0.) c = a;
    vec3 col = b ? c : a;
    if(k > 0.){
        if(hit < 0.22 * k) col = floor(col.gbr * 4. + 0.5) / 4. * vec3(0.7, 1.1, 1.2);
        vec2 blk = floor(q * vec2(28., 18.) + vec2(fr * 3.1, fr));
        if(random(blk) < 0.025 * k) col = random(blk + 1.) < 0.5 ? GRAD_TOP * 1.2 : vec3(0.9);
        col *= 0.9 + 0.1 * sin(q.y * iResolution.y * 3.1415927);
    }
    return col;
}
