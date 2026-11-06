// --- prism: white light dispersed through an amp-shaped glass prism -----------
// the beam is rolled per session by scene.qml (u_prism_ray: glyph-space start
// xy, angle z), from the left half of the screen through the centre with some
// jitter; u_prism_beam (x = height, y = tilt) offsets it from the preview panel. bufferPrismState traces PRISM_RAYS wavelengths through the
// glyph SDF (Snell at every edge, total internal reflection where it happens)
// into iChannel8 (prismTexel(ray, j) = j-th path point in glyph space, xy),
// w = 1 while the path goes on. bufferPrismLight sums the spectral rays
// additively (where they overlap they add back up to white) into a linear
// light buffer, PRISM_CHUNK rays per update (u_prism_chunk, driven by
// scene.qml) accumulated over its own previous output in iChannel9, only
// when the beam moves; the main pass tonemaps it from iChannel8.
const int   PRISM_RAYS     = 20000;
const int   PRISM_ROW      = 125;
const int   PRISM_CHUNK    = 48;
const int   PRISM_PTS      = 10;

// state texel of path point j of ray i: PRISM_ROW rays side by side per row
ivec2 prismTexel(int i, int j){ return ivec2((i % PRISM_ROW) * PRISM_PTS + j, i / PRISM_ROW); }
const float PRISM_SCALE    = 0.5;
const vec2  PRISM_CENTER   = vec2(0.05, 0.);
const float PRISM_N        = 1.5;
const float PRISM_DISP     = 0.12;
const float PRISM_BEAM_W   = 0.0018;
const float PRISM_SPREAD   = 0.02;
const float PRISM_GLOW     = 0.35;
const float PRISM_GAIN     = 3.2;
const vec3  PRISM_LINE_COL = vec3(0.7);
const float PRISM_LINE_W   = 0.0024;
const float PRISM_EDGE_W   = 0.014;
const float PRISM_EDGE_A   = 0.55;

float prismLambda(int i){ return mix(400., 700., (float(i) + 0.5) / float(PRISM_RAYS)); }

vec3 prismBump(vec3 x, vec3 y){ return clamp(1. - x * x - y, 0., 1.); }

// Zucconi's 6-bump fit of the visible spectrum
vec3 prismSpectral(float w){
    float x = clamp((w - 400.) / 300., 0., 1.);
    return prismBump(vec3(3.54585104, 2.93225262, 2.41593945) * (x - vec3(0.69549072, 0.49228336, 0.27699880)), vec3(0.02312639, 0.15225084, 0.52607955))
         + prismBump(vec3(3.90307140, 3.21182957, 3.96587128) * (x - vec3(0.11748627, 0.86755042, 0.66077860)), vec3(0.84897130, 0.88445281, 0.73949448));
}

vec2 prismNormal(vec2 p){
    vec2 e = vec2(0.002, 0.);
    return normalize(vec2(glyphDist(p + e.xy) - glyphDist(p - e.xy), glyphDist(p + e.yx) - glyphDist(p - e.yx)));
}

vec4 prismState(int i, int j){
    if(i >= PRISM_RAYS || j >= PRISM_PTS) return vec4(0.);
    gFarPad = 0.;
    float ang = u_prism_ray.z + u_prism_beam.y;
    vec2 p = u_prism_ray.xy + vec2(0., u_prism_beam.x), d = vec2(cos(ang), sin(ang));
    if(j == 0) return vec4(p, 0., 1.);
    float n = PRISM_N + PRISM_DISP * (pow(550. / prismLambda(i), 2.) - 1.);
    bool inside = false;
    for(int k = 1; k < PRISM_PTS; k++){
        bool hit = false;
        for(int s = 0; s < 128; s++){
            float g = glyphDist(p);
            float dist = inside ? -g : g;
            if(dist < 0.0004){ hit = true; break; }
            if(length(p) > 3.) break;
            p += d * max(dist * 0.9, 0.0008);
        }
        if(!hit) return k == j ? vec4(p + d * 3., 0., 1.) : vec4(0.);
        vec2 nrm = prismNormal(p);
        vec2 nf = dot(d, nrm) < 0. ? nrm : -nrm;
        vec2 r = refract(d, nf, inside ? n : 1. / n);
        if(dot(r, r) < 1e-6) d = reflect(d, nf);
        else { d = r; inside = !inside; }
        if(k == j) return vec4(p, inside ? 1. : 0., 1.);
        p += d * 0.004;
    }
    return vec4(0.);
}

// linear light of rays [i0, i0 + PRISM_CHUNK)
vec3 prismLight(vec2 q, int i0){
    vec3 norm = vec3(0.);
    for(int i = 0; i < 96; i++) norm += prismSpectral(mix(400., 700., (float(i) + 0.5) / 96.));
    norm *= float(PRISM_RAYS) / 96.;

    vec3 light = vec3(0.);
    for(int i = i0; i < i0 + PRISM_CHUNK; i++){
        if(i >= PRISM_RAYS) break;
        vec3 c = prismSpectral(prismLambda(i)) / norm;
        vec2 a = texelFetch(iChannel8, prismTexel(i, 0), 0).xy * PRISM_SCALE + PRISM_CENTER;
        float e = 0.;
        for(int j = 1; j < PRISM_PTS; j++){
            vec4 b4 = texelFetch(iChannel8, prismTexel(i, j), 0);
            if(b4.w < 0.5) break;
            vec2 b = b4.xy * PRISM_SCALE + PRISM_CENTER;
            bool last = j == PRISM_PTS - 1 || texelFetch(iChannel8, prismTexel(i, j + 1), 0).w < 0.5;
            vec2 ab = b - a;
            float h = clamp(dot(q - a, ab) / dot(ab, ab), 0., 1.);
            float dist = length(q - a - ab * h);
            float s = h * length(ab);
            float w = PRISM_BEAM_W + (last && j > 1 ? s * PRISM_SPREAD : 0.);
            float x = dist / w;
            e += sqrt(PRISM_BEAM_W / w) * (exp(-x * x) + PRISM_GLOW * exp(-dist / (w * 6.)));
            a = b;
        }
        light += c * e;
    }
    return light;
}

vec3 prism(vec2 q, vec2 tp){
    vec3 col = bgNoise(tp);
    vec2 g = (q - PRISM_CENTER) / PRISM_SCALE;
    float gd = glyphDist(g) * PRISM_SCALE;
    float band = clamp(-gd / PRISM_EDGE_W, 0., 1.);
    float fade = (1. - band) * (1. - band) * S(gd);
    float shade = mix(0.55, 1., clamp(g.y + 0.5, 0., 1.));
    col = mix(col, PRISM_LINE_COL * shade, max(fade * PRISM_EDGE_A, S(abs(gd) - PRISM_LINE_W) * 0.9));
    return col + 1. - exp(-texture(iChannel8, roomUV(q)).rgb * PRISM_GAIN);
}
