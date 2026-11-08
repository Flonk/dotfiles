// --- typewriter: the tagline typed out, then selected and deleted ------------
// A transition, T_TYPE long. The old scene fades to black (TY_FADE) and a
// cursor types FLAP_TEXT one letter per TY_STEP from TY_AT, a small amp as
// the last character, then blinks. At TY_SEL_AT the line is selected left
// to right over TY_SEL, at TY_DEL_AT it is deleted, and the cursor blinks
// alone while the new scene comes up behind it. TY_H is the text cell height.
const float TY_FADE   = 0.4;
const float TY_AT     = 0.6;
const float TY_STEP   = 0.075;
const float TY_H      = 0.09;
const float TY_GAP    = 0.25;
const float TY_AMP    = 0.62;
const float TY_SEL_AT = 4.4;
const float TY_SEL    = 0.45;
const float TY_DEL_AT = 5.2;

vec3 typewriter(vec2 q, vec2 tp){
    float ph = gModeT[MODE_TYPE];
    vec3 col = mix(gPrevCol, bgNoise(tp) * 0.6, smoothstep(0., TY_FADE, ph));
    col = mix(col, gNextCol, smoothstep(TY_DEL_AT + 0.4, T_TYPE - 0.1, ph));

    float w = TI_TAG_W + TY_GAP + TY_AMP;
    float x0 = -0.5 * w;
    bool gone = ph >= TY_DEL_AT;
    int n = gone ? 0 : int(clamp(floor((ph - TY_AT) / TY_STEP) + 1., 0., float(FLAP_TEXT_LEN + 1)));
    vec2 tq = q / TY_H;

    float sel = gone ? 0. : cubicInOut(clamp((ph - TY_SEL_AT) / TY_SEL, 0., 1.)) * w;
    if(sel > 0. && abs(tq.y) < 0.42 && tq.x > x0 - 0.03 && tq.x < x0 + sel) col = mix(GRAD_BOT, GRAD_TOP, 0.3) * 0.75;

    float x = x0, d = 1e9, cur = x0;
    for(int i = 0; i < FLAP_TEXT_LEN; i++){
        if(i >= n) break;
        float cx = x + 0.5 * TI_TAG_ADV[i];
        if(abs(tq.x - cx) < 0.4) d = min(d, flapGlyph(FLAP_TEXT[i], vec2(tq.x - cx, tq.y)));
        x += TI_TAG_ADV[i];
        cur = x;
    }
    if(n > 0 && abs(tq.y) < 0.5) col = mix(col, vec3(0.95), S(d * TY_H));
    if(n > FLAP_TEXT_LEN){
        vec2 g = (tq - vec2(x0 + TI_TAG_W + TY_GAP + 0.5 * TY_AMP, 0.)) / TY_AMP;
        if(abs(g.x) < 0.6 && abs(g.y) < 0.6) col = mix(col, ampGradient(g), S(glyphDist(g) * TY_AMP * TY_H));
        cur = x0 + w;
    }

    float typing = TY_AT + float(FLAP_TEXT_LEN + 1) * TY_STEP;
    bool blink = (ph > TY_AT - 0.3 && ph < typing + 0.2) || fract(ph * 1.6) < 0.55;
    if(ph > T_TYPE - 0.5 || ph < TY_FADE) blink = false;
    float cx = cur + 0.06;
    float bar = max(abs(tq.x - cx) - 0.035, abs(tq.y) - 0.38) * TY_H;
    if(blink) col = mix(col, vec3(0.95), S(bar));
    return col;
}
