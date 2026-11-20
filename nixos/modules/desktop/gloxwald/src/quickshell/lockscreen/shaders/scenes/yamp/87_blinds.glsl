// --- blinds: three-sided slats turning old scene -> card -> new scene --------
// A transition, T_BLINDS long. The screen is cut into vertical slats
// BL_W wide, each a triangular prism seen side on: one face the old scene,
// the next the card (the amp and the tagline), the third the new scene. At
// BL_AT.x and again at BL_AT.y the slats turn a third of the way round on
// an ease-out-back over BL_TURN, in a sweep left to right (BL_SWEEP), each
// face shaded by how far it faces away. The slats fade in out of the old
// scene over BL_FADE and out into the new one over the last BL_FADE.
const float BL_W     = 1. / 7.;
const vec2  BL_AT    = vec2(0.6, 4.4);
const float BL_FADE  = 0.5;
const float BL_TURN  = 0.9;
const float BL_SWEEP = 0.8;

vec3 blinds(vec2 q, vec2 tp){
    float ph = gModeT[MODE_BLINDS];
    float asp = iResolution.x / iResolution.y;
    float i = floor(q.x / BL_W);
    float sx = (i + 0.5) * BL_W, u = q.x - sx;
    float delay = clamp((sx + 0.5 * asp) / asp, 0., 1.) * BL_SWEEP;
    float third = 2.0943951;
    float a = third * (tcBack((ph - BL_AT.x - delay) / BL_TURN) + tcBack((ph - BL_AT.y - delay) / BL_TURN));
    float r = BL_W / (2. * sqrt(3.));
    vec3 col = vec3(0.02);
    for(int k = 0; k < 3; k++){
        float th = a - float(k) * third;
        float c = cos(th);
        if(c <= 0.01) continue;
        float hw = 0.5 * BL_W * c;
        float t = (u - r * sin(th)) / hw;
        if(abs(t) > 1.) continue;
        vec2 fq = vec2(sx + t * 0.5 * BL_W, q.y);
        vec3 face = k == 0 ? gPrevCol : k == 1 ? tcCard(bgNoise(tp), fq, vec2(0.), 1., 1.) : gNextCol;
        face *= 0.3 + 0.7 * c;
        face += 0.06 * pow(c, 24.) * smoothstep(1., 0.6, abs(t));
        col = mix(vec3(0.02), face, smoothstep(1., 1. - 3. / (iResolution.y * hw + 1e-3), abs(t)));
        break;
    }
    col = mix(gPrevCol, col, smoothstep(0., BL_FADE, ph));
    return mix(col, gNextCol, smoothstep(T_BLINDS - BL_FADE, T_BLINDS, ph));
}
