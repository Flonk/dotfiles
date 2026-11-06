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
    return prism(q, tp);
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

    vec3 col = vec3(0.);
    float aa = 0., grain = 0.;
    for(int i = 0; i < MODE_COUNT; i++){
        if(W[i] < 0.001) continue;
        col += W[i] * renderMode(i, p, q, tp);
        aa += W[i] * MODE_AA[i];
        grain += W[i] * MODE_GRAIN[i];
    }
    if(grain > 0.001) col = filmGrain(col, grain * FILM_GRAIN);
    fragColor = vec4(keyIndicator(col, q), aa);
}
