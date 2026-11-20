// --- iris: the old scene shrinks into an amp-shaped window -------------------
// A transition, T_IRIS long. The amp starts IR_ZOOM times too big, held so
// IR_ANCHOR (a point well inside the stroke) sits mid-screen, and shrinks
// to TC_AMP over IR_SHRINK: the old scene shows only through it, black
// round it. It fills with the brand gradient, the tagline pops in under it,
// and from IR_GROW_AT the window opens on the new scene and grows until it
// covers the screen. irWindow is the window's distance at zoom z.
const float IR_ZOOM    = 60.;
const vec2  IR_ANCHOR  = vec2(0.111, -0.353);
const float IR_SHRINK  = 1.6;
const float IR_FILL    = 0.5;
const float IR_GROW_AT = 4.9;

float irWindow(vec2 q, float z, out vec2 g){
    float s = TC_AMP * z, w = 1. / z;
    g = (q - TC_AMP_OFF * w) / s + IR_ANCHOR * (1. - w);
    float box = max(abs(g.x), abs(g.y));
    return (box < 0.8 ? glyphDist(g) : box - 0.5) * s;
}

vec3 iris(vec2 q, vec2 tp){
    float ph = gModeT[MODE_IRIS];
    float x = clamp(ph / IR_SHRINK, 0., 1.), y = clamp((ph - IR_GROW_AT) / (T_IRIS - IR_GROW_AT), 0., 1.);
    float e = 1. - (1. - x) * (1. - x) * (1. - x);
    float z = exp(log(IR_ZOOM) * (ph < IR_GROW_AT ? 1. - e : y * y * y));
    vec2 g;
    float inside = S(irWindow(q, z, g));
    inside = max(inside, max(1. - smoothstep(0., 0.08, x), smoothstep(0.85, 1., y)));
    float fill = smoothstep(IR_SHRINK, IR_SHRINK + IR_FILL, ph) * (1. - smoothstep(IR_GROW_AT - 0.4, IR_GROW_AT, ph));
    vec3 win = mix(ph < 3. ? gPrevCol : gNextCol, ampGradient(g), fill);
    vec3 col = mix(bgNoise(tp), win, inside);
    return tcCard(col, q, vec2(0.), 0., tcPop(ph, IR_SHRINK + 0.2, IR_GROW_AT - 0.75));
}
