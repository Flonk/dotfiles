const float PEN_FILL      = 0.82;
const float PEN_LINE      = 0.0011;
const vec3  PEN_LINE_COL  = vec3(0.7);
const vec3  PEN_HOR_COL   = vec3(0.7);
const vec3  PEN_SING_COL  = vec3(0.7);
const vec3  PEN_GRID_COL  = vec3(0.7);
const float PEN_GRID_A    = 0.22;
const float PEN_GRID_W    = 0.0005;
const float PEN_GRID_R    = 0.5;
const float PEN_GRID_T    = 0.5;
const vec2  PEN_GRID_FADE = vec2(1., 3.);
const vec3  PEN_EXT_FILL  = vec3(0.012);
const vec3  PEN_BH_FILL   = vec3(0.);
const vec3  PEN_WH_FILL   = vec3(0.006);
const float PEN_ZIG       = 0.045;
const float PEN_ZIG_N     = 22.;
const int   PEN_AMPS      = 15;
const float PEN_SWEEP     = 100.;
const float PEN_AMP       = 0.026;
const float PEN_SPAGHETTI = 1.5;
const float PEN_PATH      = 0.0009;
const float PEN_TRAIL_A   = 0.6;
const float PEN_TRAIL_T   = 0.25;
const int   PEN_TRAIL_N   = 16;
const float PEN_EDGE_FADE = 0.08;
const float PEN_FLAME_LEN = 0.9;
const float PEN_FLAME_W   = 0.2;
const vec3  PEN_FLAME_HOT = vec3(1., 0.95, 0.8);
const vec3  PEN_FLAME_COL = vec3(1., 0.55, 0.15);
const vec3  PEN_FLAME_TIP = vec3(0.7, 0.15, 0.05);
const float PEN_SMOKE_LEN = 2.5;
const float PEN_SMOKE_W   = 0.5;
const vec3  PEN_SMOKE_COL = vec3(0.35);
const float PEN_SMOKE_A   = 0.5;
const vec3  PEN_PHOTON_COL = vec3(1.7, 1.2, 0.45);
const float PEN_PHOTON_W  = 0.0009;
const float PEN_WAVE_LEN  = 0.035;
const float PEN_WAVE_A    = 0.0035;
const float PEN_WAVE_L    = 0.011;
const float PEN_WAVE_SPEED = 4.;
const float PEN_GAMMA     = 0.03;
const float PEN_GAMMA_GAP = 0.009;

const vec3  PEN_LABEL_COL = vec3(0.7);
const float PEN_LABEL     = 0.055;
const float PEN_LABEL_GAP = 0.035;
const float PEN_LABEL_RANGE = 0.25;
const float PEN_MARGIN    = 0.13;
const float PEN_ER_R      = 0.009;

const float PEN_PI = 3.14159265;
const float PEN_H  = 1.5707963;

vec3 penHover(float R, float t){
    float a = sqrt(R - 1.);
    return vec3(atan(-a * exp((R - t) * 0.5)), atan(a * exp((R + t) * 0.5)), R);
}

vec3 penCycloid(float R, float e){
    float a = sqrt(R - 1.);
    float r = 0.5 * R * (1. + cos(e));
    float B = a * (e + 0.5 * R * (e + sin(e)));
    float U = (sin(e * 0.5) - a * cos(e * 0.5)) * exp((r - B) * 0.5);
    float V = (sin(e * 0.5) + a * cos(e * 0.5)) * exp((r + B) * 0.5);
    return vec3(atan(U), atan(V), r);
}

vec3 penDive(float t){
    float rs = -2.6 + 0.85 * sqrt(1. + t * t);
    return vec3(atan(-exp((rs - t) * 0.5)), atan(exp((rs + t) * 0.5)), 2.);
}

vec3 penHyperbolic(float E, float s, float u0){
    float k = E * E - 1.;
    float u = u0, ds = s / 16.;
    for(int i = 0; i < 16; i++){
        float x = (float(i) + 0.5) * ds;
        float rd = sqrt(k + 1. / max(x * x, 1e-6));
        u += 2. * x / (rd * (E + rd)) * ds;
    }
    float r = s * s;
    float U = -exp(-u * 0.5);
    return vec3(atan(U), atan((1. - r) * exp(r) / U), r);
}

vec3 penThroat(float p){
    float w = tan(p) * tan(p);
    float r = 1. - w;
    for(int i = 0; i < 6; i++) r = clamp(r + ((1. - r) - w * exp(-r)) / max(r, 1e-3), 1e-3, 1.);
    return vec3(p, p, r);
}

vec3 penParabolic(float s, float t0){
    float r = s * s, c = 2. / 3. * r * s + 2. * s;
    float U = -(s - 1.) * exp((r + c - t0) * 0.5);
    float V = (s + 1.) * exp((r - c + t0) * 0.5);
    return vec3(atan(U), atan(V), r);
}

bool penPhoton(int i){ return i >= 12; }
vec2 penPhotonDir(int i){ return i == 14 ? vec2(-0.7071, 0.7071) : vec2(0.7071); }

bool penRocket(int i){ return i == 0 || i == 4 || i == 6; }

vec3 penExhaust(vec3 col, vec2 p, float seed, float vis){
    float y = -0.5 - p.y;
    if(y < 0. || y > PEN_FLAME_LEN + PEN_SMOKE_LEN || abs(p.x) > PEN_SMOKE_W * 1.5) return col;
    float n = texture(iChannel1, fract(vec2(p.x * 0.35 + seed * 0.37, y * 0.25 - iTime * 1.7))).r;
    float n2 = texture(iChannel1, fract(vec2(p.x * 0.2 + seed * 0.71, y * 0.12 - iTime * 0.35))).r;
    float L = PEN_FLAME_LEN * (0.85 + 0.3 * n);
    float f = clamp(y / L, 0., 1.);
    float w = PEN_FLAME_W * pow(1. - f, 0.6) * smoothstep(0., 0.08, y);
    float flame = (1. - smoothstep(w * 0.4, w, abs(p.x))) * (1. - f);
    vec3 fc = mix(PEN_FLAME_HOT, PEN_FLAME_COL, smoothstep(0., 0.5, f + abs(p.x) / max(w, 1e-3) * 0.4));
    fc = mix(fc, PEN_FLAME_TIP, smoothstep(0.5, 1., f));
    float sy = y - PEN_FLAME_LEN * 0.6;
    float sw = PEN_SMOKE_W * (0.3 + sy / PEN_SMOKE_LEN);
    float smoke = sy > 0. ? (1. - smoothstep(sw * 0.3, sw, abs(p.x + (n2 - 0.5) * 0.3 * sy)))
                          * (1. - smoothstep(0., PEN_SMOKE_LEN, sy)) * smoothstep(0.35, 0.75, n2) : 0.;
    col = mix(col, PEN_SMOKE_COL, smoke * PEN_SMOKE_A * vis);
    return col + fc * flame * vis;
}

vec3 penPath(int i, float u){
    vec3 w;
    if(i == 0) w = penHover(1.6, 2. * atanh(clamp(2. * u - 1., -0.99999, 0.99999)));
    else if(i == 1) w = penCycloid(2.4, mix(-PEN_PI, PEN_PI, u));
    else if(i == 2){ w = penParabolic(3.8 * pow(u, 1.5), -0.6); w.xy = -w.yx; }
    else if(i == 3){ w = penParabolic(3.8 * pow(1. - u, 1.5), 0.4); w.xy = w.yx; }
    else if(i == 4){ w = penHover(2.6, 2. * atanh(clamp(2. * u - 1., -0.99999, 0.99999))); w.xy = w.yx; }
    else if(i == 5){ w = penCycloid(1.7, mix(-PEN_PI, PEN_PI, u)); w.xy = w.yx; }
    else if(i == 6){ w = penDive(2.5 * atanh(clamp(2. * u - 1., -0.99999, 0.99999))); w.xy = w.yx; }
    else if(i == 7){ w = penHyperbolic(1.4, 5.5 * pow(u, 1.3), 0.); w.xy = w.yx; }
    else if(i == 8){ w = penHyperbolic(1.4, 5.5 * pow(1. - u, 1.3), 0.); w.xy = -w.yx; }
    else if(i == 9) w = penThroat(mix(-0.249, 0.249, u) * PEN_PI);
    else if(i == 10) w = penHyperbolic(3., 3. * u, 0.8);
    else if(i == 11){ w = penHyperbolic(8., 3. * u, -0.6); w.xy = w.yx; }
    else if(i == 12) w = vec3(-0.5, mix(-PEN_H + 0.5, PEN_H, u), 2.);
    else if(i == 13) w = vec3(0.6, mix(-PEN_H, PEN_H - 0.6, u), 2.);
    else w = vec3(mix(-PEN_H, PEN_H - 0.4, u), 0.4, 2.);
    return w;
}

vec2 penXT(vec2 pq){ return vec2(pq.y - pq.x, pq.y + pq.x); }

float penLabel(vec2 q, vec2 at, int i, float size){
    vec2 p = (q - at) / size;
    if(abs(p.x) > 1. || abs(p.y) > 0.5) return 1e9;
    vec2 uv = (vec2(i % 4, i / 4) + vec2(p.x * 0.5 + 0.5, 0.5 - p.y)) / vec2(4., 2.);
    return (texture(iChannel5, uv).r - 0.5) * PEN_LABEL_RANGE * size;
}

float penLabels(vec2 q, float k){
    float g = PEN_LABEL_GAP, s = 0.7071;
    float d = 1e9;
    for(int side = 0; side < 2; side++){
        float sx = side == 0 ? 1. : -1.;
        d = min(d, penLabel(q, vec2(sx * 0.75 * PEN_PI, 0.25 * PEN_PI) * k + vec2(sx, 1.) * s * g * 1.3, 0, PEN_LABEL));
        d = min(d, penLabel(q, vec2(sx * 0.75 * PEN_PI, -0.25 * PEN_PI) * k + vec2(sx, -1.) * s * g * 1.3, 1, PEN_LABEL));
        d = min(d, penLabel(q, vec2(sx * PEN_H, PEN_H) * k + vec2(sx * 1.1, 0.7) * g, 2, PEN_LABEL));
        d = min(d, penLabel(q, vec2(sx * PEN_H, -PEN_H) * k + vec2(sx * 1.1, -0.7) * g, 3, PEN_LABEL));
        d = min(d, penLabel(q, vec2(sx * PEN_PI, 0.) * k + vec2(sx * 1.4, 0.) * g, 4, PEN_LABEL));
        d = min(d, penLabel(q, vec2(0., sx * PEN_H) * k + vec2(0., sx * 1.1) * g, 5, PEN_LABEL));
    }
    return d;
}

float penZigzag(vec2 d, float y0){
    float w = PEN_PI / PEN_ZIG_N;
    float i = floor((d.x + PEN_H) / w);
    float best = 1e9;
    for(int k = -1; k <= 1; k++){
        float j = clamp(i + float(k), 0., PEN_ZIG_N - 1.);
        float x0 = -PEN_H + j * w;
        float sg = mod(j, 2.) < 0.5 ? 1. : -1.;
        vec2 a = vec2(x0, y0), m = vec2(x0 + 0.5 * w, y0 + sg * PEN_ZIG * 0.5), b = vec2(x0 + w, y0);
        best = min(best, min(sdSegment(d, a, m), sdSegment(d, m, b)));
    }
    return best;
}

float penGrid(vec2 d, float k){
    vec2 pq = 0.5 * vec2(d.y - d.x, d.y + d.x);
    vec2 lu = log(abs(tan(pq)) + 1e-9);
    vec2 f = vec2((lu.x + lu.y) / PEN_GRID_R, (lu.y - lu.x) / PEN_GRID_T);
    vec2 s = sin(2. * pq);
    float gl = sqrt(2. * (1. / (s.x * s.x) + 1. / (s.y * s.y)));
    vec2 g = gl / vec2(PEN_GRID_R, PEN_GRID_T);
    vec2 dist = abs(fract(f + 0.5) - 0.5) / g * k;
    vec2 fade = smoothstep(PEN_GRID_FADE.x, PEN_GRID_FADE.y, k * iResolution.y / g);
    return max(S(dist.x - PEN_GRID_W) * fade.x, S(dist.y - PEN_GRID_W) * fade.y);
}

float penSolve(int i, float T){
    float lo = 0., hi = 1.;
    for(int j = 0; j < 24; j++){
        float m = 0.5 * (lo + hi);
        if(penXT(penPath(i, m).xy).y < T) lo = m; else hi = m;
    }
    return 0.5 * (lo + hi);
}

float penScale(){
    return min(PEN_FILL / PEN_PI, (iResolution.x / iResolution.y - 2. * PEN_MARGIN) / (2. * PEN_PI));
}

vec4 penroseStatic(vec2 q){
    float k = penScale();
    vec2 d = q / k;
    vec3 col = vec3(0.);
    float a = 0.;
    if(abs(d.y) < PEN_H && abs(d.x) + abs(d.y) < PEN_PI){
        col += d.y > abs(d.x) ? PEN_BH_FILL : d.y < -abs(d.x) ? PEN_WH_FILL : PEN_EXT_FILL;
        float g = penGrid(d, k) * PEN_GRID_A;
        col = mix(col, PEN_GRID_COL, g);
        a = g;
    }
    vec2 H = vec2(PEN_H);
    float outer = min(min(sdSegment(d, H, vec2(PEN_PI, 0.)), sdSegment(d, vec2(PEN_PI, 0.), H * vec2(1., -1.))),
                      min(sdSegment(d, H * vec2(-1., 1.), vec2(-PEN_PI, 0.)), sdSegment(d, vec2(-PEN_PI, 0.), -H)));
    float hor = min(sdSegment(d, -H, H), sdSegment(d, H * vec2(-1., 1.), H * vec2(1., -1.)));
    float sing = min(penZigzag(d, PEN_H), penZigzag(d, -PEN_H));
    float lo = S(outer * k - PEN_LINE), lh = S(hor * k - PEN_LINE), ls = S(sing * k - PEN_LINE), ll = S(penLabels(q, k));
    col = mix(col, PEN_LINE_COL, lo);
    col = mix(col, PEN_HOR_COL, lh);
    col = mix(col, PEN_SING_COL, ls);
    col = mix(col, PEN_LABEL_COL, ll);
    float er = length(q) - PEN_ER_R;
    float ein = S(er), ering = S(abs(er) - PEN_LINE);
    col = mix(mix(col, vec3(0.), ein), PEN_LINE_COL, ering);
    ll = max(ll, ering);
    a *= 1. - ein;
    lo *= 1. - ein;
    lh *= 1. - ein;
    ls *= 1. - ein;
    return vec4(col, max(a, max(max(lo, lh), max(ls, ll))));
}

vec4 penState(int i, int j){
    if(i >= PEN_AMPS || j > PEN_TRAIL_N) return vec4(0., 0., 0., -1.);
    vec2 a = penXT(penPath(i, 0.).xy), b = penXT(penPath(i, 1.).xy);
    float Tn = mix(-PEN_H, PEN_H, fract(iTime / PEN_SWEEP + fract(float(i) * 0.618034)));
    if(Tn <= a.y || Tn >= b.y) return vec4(0., 0., 0., -1.);
    vec3 w = penPath(i, penSolve(i, max(Tn - float(j) / float(PEN_TRAIL_N) * PEN_TRAIL_T, a.y)));
    vec2 c = penXT(w.xy);
    return vec4(w, smoothstep(0., PEN_EDGE_FADE, length(c - a)) * smoothstep(0., PEN_EDGE_FADE, length(c - b)));
}

vec3 penrose(vec2 q, vec2 tp){
    float k = penScale();
    vec4 st = texture(iChannel6, roomUV(q));
    vec3 col = bgNoise(tp) * (1. - st.a) + st.rgb;
    vec2 d = q / k;
    for(int i = 0; i < PEN_AMPS; i++){
        vec4 h = texelFetch(iChannel7, ivec2(0, i), 0);
        if(h.w < 0.) continue;
        vec3 w = h.xyz;
        vec2 c = penXT(w.xy);
        float vis = h.w;
        if(length(d - c) * k > 0.15) continue;
        if(penPhoton(i)){
            vec2 dir = penPhotonDir(i), nrm = vec2(-dir.y, dir.x);
            vec2 rel = q - c * k;
            float a = -dot(rel, dir), b = dot(rel, nrm);
            bool inside = abs(d.y) < PEN_H + 0.01 && abs(d.x) + abs(d.y) < PEN_PI + 0.01;
            if(inside && a > -0.01 && a < PEN_GAMMA_GAP + PEN_WAVE_LEN + 0.01){
                float env = smoothstep(PEN_GAMMA_GAP, PEN_GAMMA_GAP + 0.004, a) * smoothstep(PEN_GAMMA_GAP + PEN_WAVE_LEN, PEN_GAMMA_GAP + PEN_WAVE_LEN * 0.6, a);
                float ph = 6.2831853 * a / PEN_WAVE_L + iTime * PEN_WAVE_SPEED;
                float y = PEN_WAVE_A * env * sin(ph);
                float dy = PEN_WAVE_A * env * cos(ph) * 6.2831853 / PEN_WAVE_L;
                col = mix(col, PEN_PHOTON_COL, S(abs(b - y) / sqrt(1. + dy * dy) - PEN_PHOTON_W) * env * vis);
            }
            vec2 ga = c * k;
            col = mix(col, PEN_PHOTON_COL, S(penLabel(q, ga, 6, PEN_GAMMA)) * vis);
            continue;
        }
        float tr = 1e9, ta = 0.;
        vec2 prev = c;
        for(int j = 1; j <= PEN_TRAIL_N; j++){
            float f = float(j) / float(PEN_TRAIL_N);
            vec2 cur = penXT(texelFetch(iChannel7, ivec2(j, i), 0).xy);
            float sd = sdSegment(d, prev, cur);
            if(sd < tr){ tr = sd; ta = 1. - f; }
            prev = cur;
        }
        col = mix(col, ampGradient(vec2(0., 0.5)), S(tr * k - PEN_PATH * 1.4) * PEN_TRAIL_A * ta * vis);
        vec2 gp = (q - c * k) / PEN_AMP;
        if(penRocket(i)){
            vec2 sp = sin(2. * w.xy);
            vec2 dir = normalize(vec2(sp.y - sp.x, sp.y + sp.x));
            gp = vec2(dot(gp, vec2(dir.y, -dir.x)), dot(gp, dir));
            col = penExhaust(col, gp, float(i), vis);
        }
        float s = w.z < 1. ? (1. - w.z) * (1. - w.z) * PEN_SPAGHETTI : 0.;
        gp *= vec2(1. + s, 1. / (1. + s));
        col = mix(col, ampGradient(gp), S(glyphDist(gp) * PEN_AMP / (1. + s)) * vis);
    }
    return col;
}
