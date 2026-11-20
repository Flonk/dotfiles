// --- scope: XY oscilloscope tracing the amp outline ---------------------------
// iChannel8: beam path (gen_scope.py), iChannel9: phosphor feedback buffer
// (bufferScope: R = fast decay, G = slow decay, A = time of the last frame)
const vec3  SCOPE_HOT      = vec3(0.85, 0.97, 1.);
const float SCOPE_H        = 0.84;
const vec3  SCOPE_GRID_COL = vec3(0.7);
const float SCOPE_GRID_A   = 0.15;
const float SCOPE_GRID_W   = 0.0006;
const float SCOPE_TICK     = 0.008;
const float SCOPE_AMP      = 0.7;
const vec2  SCOPE_CENTER   = vec2(-0.02, 0.01);
const float SCOPE_LOOP     = 6.;
const float SCOPE_BEAM_W   = 0.0011;
const float SCOPE_GAIN     = 1.4;
const float SCOPE_FAST_T   = 0.15;
const float SCOPE_SLOW_T   = 2.2;
const float SCOPE_FAST_A   = 1.;
const float SCOPE_SLOW_A   = 0.7;
const float SCOPE_GLOW     = 1.5;
const float SCOPE_RETRACE  = 0.05;
const float SCOPE_NOISE    = 0.0004;
const float SCOPE_CYCLE    = 60.;
const float SCOPE_LISS_AT  = 36.;
const float SCOPE_MORPH    = 4.;
const vec2  SCOPE_LISS     = vec2(3., 2.);
const vec2  SCOPE_LISS_A   = vec2(0.36, 0.3);
const float SCOPE_LISS_DRIFT = 0.15;
const int   SCOPE_N        = 1024;
const int   SCOPE_STEPS    = 32;

vec3 scopeVertex(int i){
    i = i % SCOPE_N;
    vec3 a = round(texelFetch(iChannel8, ivec2(i, 0), 0).rgb * 255.);
    vec3 b = round(texelFetch(iChannel8, ivec2(i, 1), 0).rgb * 255.);
    vec2 v = vec2(a.r * 256. + a.g, b.r * 256. + b.g) / 65535. * 2. * SDF_BOX - SDF_BOX;
    return vec3(v, a.b > 127. ? 1. : 0.);
}

// beam position (screen space) and lit flag at time t
vec3 scopeBeam(float t){
    float s = mod(t, SCOPE_LOOP) / SCOPE_LOOP;
    float fi = s * float(SCOPE_N);
    int i = int(fi);
    vec3 a = scopeVertex(i), b = scopeVertex(i + 1);
    vec2 amp = (mix(a.xy, b.xy, fi - float(i)) - SCOPE_CENTER) * SCOPE_AMP;
    float ph = 6.2831853 * s;
    vec2 liss = SCOPE_LISS_A * sin(SCOPE_LISS * ph + vec2(t * SCOPE_LISS_DRIFT, 0.));
    float c = mod(t, SCOPE_CYCLE);
    float m = smoothstep(SCOPE_LISS_AT, SCOPE_LISS_AT + SCOPE_MORPH, c)
            * (1. - smoothstep(SCOPE_CYCLE - SCOPE_MORPH, SCOPE_CYCLE, c));
    m = cubicInOut(m);
    vec2 n = SCOPE_NOISE * vec2(sin(t * 23.1 + 2. * sin(t * 7.3)), cos(t * 19.7 + 2. * sin(t * 5.9)));
    vec2 p = mix(amp, liss, m) + n;
    return vec3(p, mix(mix(SCOPE_RETRACE, 1., a.z), 1., m));
}

// phosphor energy deposited at q by the beam between t0 and t1; segment
// bodies only (no caps) so consecutive segments tile without beading
vec2 scopeDeposit(vec2 q, float t0, float t1){
    float dt = t1 - t0;
    if(dt <= 0.) return vec2(0.);
    int n = clamp(int(ceil(dt / SCOPE_LOOP * float(SCOPE_N) * 1.5)) + 1, 1, SCOPE_STEPS);
    float h = dt / float(n);
    vec3 a = scopeBeam(t0);
    float speed = 5.8 * SCOPE_AMP / SCOPE_LOOP;
    float e = 0.;
    for(int k = 1; k <= SCOPE_STEPS; k++){
        if(k > n) break;
        vec3 b = scopeBeam(t0 + h * float(k));
        vec2 ab = b.xy - a.xy, aq = q - a.xy;
        float L2 = dot(ab, ab);
        float u = L2 > 0. ? dot(aq, ab) / L2 : 0.;
        if(u >= 0. && u < 1.){
            float d = length(aq - ab * u);
            float L = max(sqrt(L2), SCOPE_BEAM_W);
            float age = t1 - (t0 + h * (float(k) - 1. + u));
            e += a.z * h * speed / L * exp(-0.5 * d * d / (SCOPE_BEAM_W * SCOPE_BEAM_W)) * exp(-age / SCOPE_FAST_T);
        }
        a = b;
    }
    return SCOPE_GAIN * vec2(e);
}

vec4 scopePhosphor(vec2 q, vec4 prev){
    float t1 = iTime;
    if(abs(t1 - prev.a) > 0.5) prev.rg = vec2(0.);
    float dt = clamp(t1 - prev.a, 0., 0.1);
    vec2 e = prev.rg * exp(-dt / vec2(SCOPE_FAST_T, SCOPE_SLOW_T));
    e += scopeDeposit(q, t1 - dt, t1);
    return vec4(e, 0., t1);
}

vec2 scopeGlow(vec2 uv, float lod){
    vec2 px = exp2(lod) / vec2(textureSize(iChannel9, 0));
    vec2 g = vec2(0.);
    for(int i = 0; i < 6; i++){
        float a = float(i) * 1.0471976;
        g += textureLod(iChannel9, uv + px * 0.9 * vec2(cos(a), sin(a)), lod).rg;
    }
    return g / 6.;
}

float scopeGrid(vec2 q){
    float div = SCOPE_H / 8.;
    vec2 g = abs(fract(q / div + 0.5) - 0.5) * div;
    float d = min(g.x, g.y);
    vec2 m = abs(fract(q / (div * 0.2) + 0.5) - 0.5) * div * 0.2;
    float ax = min(max(abs(q.y) - SCOPE_TICK, m.x), max(abs(q.x) - SCOPE_TICK, m.y));
    d = min(d, ax);
    return S(d - SCOPE_GRID_W);
}

vec3 scope(vec2 q, vec2 tp){
    vec3 col = solidBg(q, tp);
    col = mix(col, SCOPE_GRID_COL, scopeGrid(q) * SCOPE_GRID_A);

    vec2 uv = roomUV(q);
    vec2 e = textureLod(iChannel9, uv, 0.).rg;
    vec2 g = 0.6 * scopeGlow(uv, 2.5) + 0.4 * scopeGlow(uv, 4.5);
    vec2 wa = vec2(SCOPE_FAST_A, SCOPE_SLOW_A);
    float I = dot(e, wa);
    float G = dot(g, wa) * SCOPE_GLOW;
    vec3 light = (1. - exp(-(I + G) * ampGradient(q / SCOPE_AMP + SCOPE_CENTER) * 1.6));
    light = mix(light, SCOPE_HOT, smoothstep(0.8, 2.5, I));
    return col + light;
}
