// --- spectrum: spectrogram waterfall with the amp hidden in the signal ---------
// frequency runs left to right, time scrolls down from the live spectrum strip
// at the top; every cell is a pure function of (bin, frame), so rows scroll
// without a feedback buffer. Every SPEC_PERIOD the amp is transmitted, one
// glyph row per frame, so it builds up under the strip and scrolls away.
const int   SPEC_BINS      = 320;
const float SPEC_SPEED     = 0.03;
const float SPEC_ROW       = 0.004;
const float SPEC_STRIP     = 0.16;
const float SPEC_STRIP_H   = 0.11;
const float SPEC_LO        = -1.5;
const float SPEC_HI        = 5.;
const float SPEC_TILT      = 2.;
const float SPEC_CARRIER   = 25.;
const float SPEC_VOICE     = 60.;
const float SPEC_CHIRP     = 30.;
const float SPEC_CLICK     = 8.;
const float SPEC_GLYPH     = 45.;
const float SPEC_LEAK      = 0.005;
const float SPEC_PERIOD    = 50.;
const float SPEC_GLYPH_AT  = 4.;
const float SPEC_GLYPH_DUR = 18.;
const vec3  SPEC_GRID_COL  = vec3(0.7);

float specFps(){ return SPEC_SPEED / SPEC_ROW; }

float specLine(float f, float fc, float w){
    float x = (f - fc) * float(SPEC_BINS) / w;
    return exp(-x * x);
}

float specPower(int bin, int frame){
    float f = (float(bin) + 0.5) / float(SPEC_BINS);
    float t = (float(frame) + 0.5) / specFps();
    uint ub = uint(bin), uf = uint(frame);
    float P = -log(max(pcgHash(uvec3(ub, uf, 7u)), 1e-4)) * (1. + SPEC_TILT * exp(-f * 6.));

    for(int k = 0; k < 4; k++){
        float fk = 0.18 + 0.21 * float(k) + 0.004 * sin(t * (0.13 + 0.05 * float(k)) + float(k) * 2.1);
        float on = smoothstep(-0.2, 0.2, sin(t * (0.021 + 0.013 * float(k)) + float(k) * 1.7));
        P += SPEC_CARRIER * on * (0.5 + 0.5 * float(k & 1)) * specLine(f, fk, 0.9);
    }

    float f0 = 0.022 + 0.003 * sin(t * 0.7) + 0.0015 * sin(t * 1.9);
    float syl = smoothstep(0., 0.3, sin(t * 0.9) * sin(t * 0.23 + 1.)) * smoothstep(0.3, 0.6, sin(t * 0.05));
    if(syl > 0.) for(int h = 1; h <= 12; h++)
        P += syl * SPEC_VOICE / float(h) * specLine(f, f0 * float(h), 1.);

    float tc = mod(t, 29.);
    if(tc < 8.) P += SPEC_CHIRP * smoothstep(0., 1., tc) * smoothstep(8., 7., tc) * specLine(f, 0.52 + 0.012 * tc + 0.0035 * tc * tc, 1.6);

    float ck = pcgHash(uvec3(uf, 3u, 9u));
    if(ck < 0.012) P += SPEC_CLICK * (0.5 + 50. * ck) * exp(-f * 2.5);

    float occ = floor(t / SPEC_PERIOD);
    float tl = t - occ * SPEC_PERIOD - SPEC_GLYPH_AT;
    if(tl > 0. && tl < SPEC_GLYPH_DUR){
        float sc = SPEC_SPEED * SPEC_GLYPH_DUR;
        float fc = 0.5 + 0.3 * (pcgHash(uvec3(uint(int(occ)), 5u, 11u)) - 0.5);
        float asp = iResolution.x / iResolution.y;
        vec2 g = vec2((f - fc) * asp / sc, tl / SPEC_GLYPH_DUR - 0.5);
        float d = glyphDist(g);
        float tex = 0.6 + 0.8 * pcgHash(uvec3(ub, uf, 13u));
        P += SPEC_GLYPH * tex * (d < 0. ? 1. : exp(-d / SPEC_LEAK));
    }
    return P;
}

float specLevel(float P){ return clamp((log(P) - SPEC_LO) / (SPEC_HI - SPEC_LO), 0., 1.); }

// bilinear between the four (bin, frame) cells around (fb, ff)
float specAt(float fb, float ff){
    vec2 c = vec2(fb, ff) - 0.5;
    ivec2 i = ivec2(floor(c));
    vec2 w = c - vec2(i);
    float a = specLevel(specPower(i.x, i.y)), b = specLevel(specPower(i.x + 1, i.y));
    float e = specLevel(specPower(i.x, i.y + 1)), d = specLevel(specPower(i.x + 1, i.y + 1));
    return mix(mix(a, b, w.x), mix(e, d, w.x), w.y);
}

vec3 specMap(float v){
    vec3 c = mix(vec3(0.004, 0.008, 0.012), GRAD_BOT * 0.18, smoothstep(0., 0.4, v));
    c = mix(c, GRAD_BOT * 0.8, smoothstep(0.35, 0.7, v));
    c = mix(c, GRAD_TOP * 1.15, smoothstep(0.62, 0.85, v));
    return mix(c, vec3(0.92, 1., 1.), smoothstep(0.82, 1., v));
}

vec3 spectrum(vec2 q, vec2 tp){
    float asp = iResolution.x / iResolution.y;
    float fb = (q.x / asp + 0.5) * float(SPEC_BINS);
    float top = 0.5 - SPEC_STRIP;
    float now = iTime * specFps();
    if(q.y < top){
        float ff = now - (top - q.y) / SPEC_ROW;
        return specMap(specAt(fb, ff));
    }

    vec3 col = specMap(0.);
    float px = 1. / iResolution.y;
    float dfb = float(SPEC_BINS) / asp * px;
    float base = top + 0.012;
    float v0 = specAt(fb, now), v1 = specAt(fb + dfb, now);
    float y = base + v0 * SPEC_STRIP_H;
    float slope = (v1 - v0) * SPEC_STRIP_H / px;
    float d = (q.y - y) / sqrt(1. + slope * slope);
    col = mix(col, GRAD_BOT * 0.25, step(q.y, y) * step(base, q.y));
    col = mix(col, GRAD_TOP, S(abs(d) - 0.0008));

    float tick = abs(fract(fb / float(SPEC_BINS) * 20. + 0.5) - 0.5) * asp / 20.;
    float major = abs(fract(fb / float(SPEC_BINS) * 4. + 0.5) - 0.5) * asp / 4.;
    float tk = max(S(tick - 0.0005) * step(q.y, top + 0.006), S(major - 0.0005) * step(q.y, top + 0.012));
    col = mix(col, SPEC_GRID_COL, 0.35 * max(tk, S(abs(q.y - top) - 0.0005)));
    return col;
}
