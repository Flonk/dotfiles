// --- key indicator -----------------------------------------------------------
vec3 keyIndicator(vec3 col, vec2 q){
    // the circle leads the amp by IND_LAG both ways: max of the live and the
    // delayed envelope rises first and falls last, min does the opposite
    float e0 = sk_attention_envelope();
    float e1 = sk_attention_envelope_at(iTime - IND_LAG);
    float cpres = max(e0, e1);
    float pres = min(e0, e1);
    if(cpres < 0.001) return col;

    // black circle growing from the center to past the corners
    float maxR = length(iResolution.xy) / iResolution.y * 0.51;
    col = mix(col, vec3(0.), S(length(q) - maxR * cubicInOut(cpres)));

    // the amp zooms in behind the circle; each key bumps size and brightness
    float pulse = sk_keypulse_envelope();
    float fail = sk_fail_envelope();
    float sc = IND_AMP * cubicInOut(pres) * (1. + pulse * IND_BUMP);
    if(sc < 1e-3) return col;
    vec2 ap = q / sc;
    vec3 ac = mix(ampGradient(ap), vec3(1.), pulse * IND_BRIGHT);
    ac = mix(ac, sk_fail_color, fail);
    return mix(col, ac, S(glyphDist(ap) * sc));
}

vec3 renderMode(int m, vec2 p, vec2 q, vec2 tp){
    if(m == MODE_TILES) return tiles(p);
    if(m == MODE_FIELD) return field(p, q, tp);
    if(m == MODE_DROP) return drop(q, tp);
    if(m == MODE_SOLID) return solid(q, tp);
    if(m == MODE_HALFTONE) return halftone(q, tp);
    if(m == MODE_SHADOW) return shadowPlay(q, tp);
    if(m == MODE_PENROSE) return penrose(q, tp);
    if(m == MODE_SCOPE) return scope(q, tp);
    if(m == MODE_SPECTRUM) return spectrum(q, tp);
    if(m == MODE_PRISM) return prism(q, tp);
    if(m == MODE_GASKET) return gasket(q, tp);
    if(m == MODE_GRAVITY) return gravity(q, tp);
    if(m == MODE_FLUID) return fluid(q, tp);
    if(m == MODE_GRID) return grid(q, tp);
    if(m == MODE_FISH) return fish(q, tp);
    if(m == MODE_TRAFFIC) return traffic(q, tp);
    if(m == MODE_CONVEYOR) return conveyor(q, tp);
    return stars(q, tp);
}

// how long into transition m it still shows the old scene, and from when
// it shows the new one
vec2 transWindow(int m){
    if(m == MODE_FLAP) return vec2(FLAP_PREV_END, FLAP_OUT_AT);
    if(m == MODE_SHATTER) return vec2(SH_DIM, SH_PERIOD - SH_TEXT_OUT);
    if(m == MODE_TITLE) return vec2(TI_FADE, T_TITLE - TI_FADE);
    if(m == MODE_IRIS) return vec2(IR_SHRINK + IR_FILL, IR_GROW_AT - 0.4);
    if(m == MODE_INK) return vec2(INK_DROP + INK_SPREAD + 0.2, INK_CLEAR_AT);
    if(m == MODE_TYPE) return vec2(TY_FADE, TY_DEL_AT + 0.4);
    if(m == MODE_PEEL) return vec2(PE_AT.x + PE_DUR, PE_AT.y);
    if(m == MODE_GLITCH) return vec2(GL_OUT.y, GL_IN.x);
    if(m == MODE_BLINDS) return vec2(BL_AT.x + BL_SWEEP + BL_TURN + 0.2, BL_AT.y);
    return vec2(T_STAMP, ST_LIFT);
}

vec3 transition(int m, vec2 q, vec2 tp){
    if(m == MODE_FLAP) return flap(q, tp);
    if(m == MODE_SHATTER) return shatter(q, tp);
    if(m == MODE_TITLE) return title(q, tp);
    if(m == MODE_IRIS) return iris(q, tp);
    if(m == MODE_INK) return ink(q, tp);
    if(m == MODE_TYPE) return typewriter(q, tp);
    if(m == MODE_PEEL) return peel(q, tp);
    if(m == MODE_GLITCH) return glitch(q, tp);
    if(m == MODE_BLINDS) return blinds(q, tp);
    return stamp(q, tp);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    gSeed = 100. * vec2(sk_seed(0), sk_seed(1));
    vec2 p = (fragCoord-0.5*iResolution.xy)/iResolution.y;
    vec2 q = p;
    sequenceModes(q);

    // global zoom-out (offset half a period), centered on a target orbiting
    // off-screen so each zoom lands somewhere new
    float zo = flipflop(iTime + ZOOM_PERIOD*0.5, ZOOM_PERIOD);
    float ang = 6.2831853 * iTime / ZOOM_DRIFT;
    vec2 zc = ZOOM_ECC * vec2(cos(ang), sin(ang));
    gZoom = 1. + ZOOM_OUT*zo;
    p = zc + (p - zc) * gZoom;

    // noise coords, counter-scrolling slowly against the grid
    vec2 tp = vec2(p.x, p.y + iTime*SCROLL*BG_SPEED) * NOISE_SCALE;

    // the scene, or the transition's two neighbours as far as it shows them
    bool tr = gTrans >= 0;
    float lt = tr ? gModeT[gTrans] : 0.;
    int ms[2] = int[2](tr ? gPrev : gScene, gNext);
    vec2 win = tr ? transWindow(gTrans) : vec2(0.);
    bool need[2] = bool[2](!tr || lt < win.x, tr && lt > win.y);
    vec3 sc[2] = vec3[2](vec3(0.), vec3(0.));
    for(int i = 0; i < 2; i++) if(need[i]) sc[i] = renderMode(ms[i], p, q, tp);

    vec3 col = sc[0];
    float aa = tr ? 0. : MODE_AA[gScene], grain = tr ? 0. : MODE_GRAIN[gScene];
    if(tr){
        gPrevCol = sc[0];
        gNextCol = sc[1];
        col = transition(gTrans, q, tp);
    }
    if(grain > 0.001) col = filmGrain(col, grain * FILM_GRAIN);
    if(!tr && fragCoord.y < PROGRESS_H){
        float left = (1. - gModeT[gScene] / max(u_seq2.y, 1e-3)) * iResolution.x;
        vec3 bar = mix(GRAD_BOT, GRAD_TOP, fragCoord.x / iResolution.x);
        col = mix(col * 0.4, bar, clamp(left - fragCoord.x + 0.5, 0., 1.));
    }
    fragColor = vec4(keyIndicator(col, q), aa);
}
