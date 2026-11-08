// --- fluid: a stirred incompressible fluid, amps tinted by its shear stress ----
// bufferFluid is a W x H grid over the screen (row 0 at the top, cell units)
// plus one extra row holding the time of the last step, run over its own
// previous output in iChannel9: xy velocity (cells/s), z pressure, w the
// strain rate, low-passed and carried with the flow. Each step advects
// (semi-Lagrangian), relaxes the pressure one Jacobi sweep (warm-started from
// the last frame) and projects, adds vorticity confinement, and drags the
// fluid along with FLUID_STIRS invisible spoons and the odd jet kick.
// The main pass reads it from iChannel12: amps sit on a lattice, pushed off
// their spot and twisted by the local flow, and turn blue with the stress.
const int   FLUID_STIRS     = 3;
const float FLUID_STIR_R    = 14.;
const float FLUID_STIR_GRIP = 10.;
const vec2  FLUID_STIR_BOX  = vec2(0.38, 0.36);
const float FLUID_STIR_RATE = 0.22;
const float FLUID_STIR_CALM = 0.07;
const float FLUID_KICK_P    = 4.;
const float FLUID_KICK_T    = 0.35;
const float FLUID_KICK_V    = 220.;
const float FLUID_KICK_R    = 12.;
const float FLUID_VORT      = 0.7;
const float FLUID_VISC      = 0.6;
const float FLUID_DAMP      = 0.12;
const float FLUID_STRESS_T  = 0.5;
const float FLUID_ROWS      = 50.;
const float FLUID_AMP       = 0.42;
const float FLUID_DISP      = 0.2;
const float FLUID_DISP_MAX  = 0.4;
const float FLUID_TWIST     = 0.12;
const float FLUID_STRESS_REF = 2.5;
const vec3  FLUID_IDLE      = vec3(0.28);
const vec3  FLUID_HOT       = vec3(0.75, 0.95, 1.);
const float FLUID_GLOW      = 0.12;

ivec2 fluidSize(sampler2D s){ return textureSize(s, 0) - ivec2(0, 1); }

vec4 fluidAt(sampler2D s, ivec2 c, ivec2 R){
    vec4 v = texelFetch(s, clamp(c, ivec2(0), R - 1), 0);
    return any(isnan(v)) || any(isinf(v)) ? vec4(0.) : v;
}

vec4 fluidLerp(sampler2D s, vec2 f, ivec2 R){
    f = clamp(f, vec2(0.5), vec2(R) - 0.5) - 0.5;
    ivec2 i = ivec2(floor(f));
    vec2 t = f - vec2(i);
    return mix(mix(fluidAt(s, i, R), fluidAt(s, i + ivec2(1, 0), R), t.x),
               mix(fluidAt(s, i + ivec2(0, 1), R), fluidAt(s, i + ivec2(1, 1), R), t.x), t.y);
}

float fluidCurl(sampler2D s, ivec2 c, ivec2 R){
    return 0.5 * (fluidAt(s, c + ivec2(1, 0), R).y - fluidAt(s, c - ivec2(1, 0), R).y
                - fluidAt(s, c + ivec2(0, 1), R).x + fluidAt(s, c - ivec2(0, 1), R).x);
}

vec2 fluidStir(int k, float t, vec2 R){
    vec2 f = vec2(0.31, 0.23) * (1. + 0.37 * float(k)) * FLUID_STIR_RATE;
    vec2 ph = 6.2831853 * vec2(sk_seed(2 * k), sk_seed(2 * k + 1));
    return R * (0.5 + FLUID_STIR_BOX * vec2(sin(t * f.x + ph.x), sin(t * f.y + ph.y + 0.7 * sin(t * f.x * 0.6))));
}

float fluidStirOn(int k, float t){
    return smoothstep(0.25, 0.75, 0.5 + 0.5 * sin(t * FLUID_STIR_CALM * (1. + 0.41 * float(k)) + 6.2831853 * sk_seed(10 + k)));
}

vec4 fluidStep(ivec2 c){
    ivec2 R = fluidSize(iChannel9);
    if(c.y >= R.y) return vec4(iTime, 0., 0., 0.);
    float T0 = texelFetch(iChannel9, ivec2(0, R.y), 0).x;
    float dt = isnan(T0) || T0 > iTime ? 0. : min(iTime - T0, 1. / 30.);
    vec4 s = fluidAt(iChannel9, c, R);
    if(dt <= 0.) return s;

    vec2 pos = vec2(c) + 0.5;
    vec4 a = fluidLerp(iChannel9, pos - dt * s.xy, R);
    vec4 e = fluidAt(iChannel9, c + ivec2(1, 0), R), w = fluidAt(iChannel9, c - ivec2(1, 0), R);
    vec4 n = fluidAt(iChannel9, c + ivec2(0, 1), R), so = fluidAt(iChannel9, c - ivec2(0, 1), R);

    float div = 0.5 * (e.x - w.x + n.y - so.y);
    float p = 0.25 * (e.z + w.z + n.z + so.z - div);
    vec2 v = a.xy - 0.5 * vec2(e.z - w.z, n.z - so.z);
    v = mix(v, 0.25 * (e.xy + w.xy + n.xy + so.xy), clamp(FLUID_VISC * dt * 10., 0., 0.5));

    float cE = abs(fluidCurl(iChannel9, c + ivec2(1, 0), R)), cW = abs(fluidCurl(iChannel9, c - ivec2(1, 0), R));
    float cN = abs(fluidCurl(iChannel9, c + ivec2(0, 1), R)), cS = abs(fluidCurl(iChannel9, c - ivec2(0, 1), R));
    vec2 gw = 0.5 * vec2(cE - cW, cN - cS);
    float om = fluidCurl(iChannel9, c, R);
    if(dot(gw, gw) > 1e-8) v += dt * FLUID_VORT * om * vec2(gw.y, -gw.x) / length(gw) * 4.;

    vec2 Rf = vec2(R);
    for(int k = 0; k < FLUID_STIRS; k++){
        vec2 sp = fluidStir(k, iTime, Rf);
        vec2 sv = (fluidStir(k, iTime + 0.05, Rf) - fluidStir(k, iTime - 0.05, Rf)) * 10.;
        vec2 d = pos - sp;
        float g = exp(-dot(d, d) / (FLUID_STIR_R * FLUID_STIR_R)) * fluidStirOn(k, iTime);
        v = mix(v, sv * 1.6, clamp(g * FLUID_STIR_GRIP * dt, 0., 1.));
    }

    float kn = floor(iTime / FLUID_KICK_P);
    float k0 = kn * FLUID_KICK_P + random(vec2(kn, 1.3)) * (FLUID_KICK_P - FLUID_KICK_T);
    if(iTime > k0 && iTime < k0 + FLUID_KICK_T){
        vec2 kp = Rf * (0.15 + 0.7 * vec2(random(vec2(kn, 2.7)), random(vec2(kn, 4.1))));
        float ka = 6.2831853 * random(vec2(kn, 8.9));
        vec2 d = pos - kp;
        float g = exp(-dot(d, d) / (FLUID_KICK_R * FLUID_KICK_R));
        v = mix(v, FLUID_KICK_V * vec2(cos(ka), sin(ka)), clamp(g * 12. * dt, 0., 1.));
    }

    v *= exp(-dt * FLUID_DAMP);
    if(c.x == 0 || c.x == R.x - 1) v.x = 0.;
    if(c.y == 0 || c.y == R.y - 1) v.y = 0.;
    float lv = length(v);
    if(lv > 240.) v *= 240. / lv;

    float ux = 0.5 * (e.x - w.x), uy = 0.5 * (n.x - so.x);
    float vx = 0.5 * (e.y - w.y), vy = 0.5 * (n.y - so.y);
    float rate = sqrt((ux - vy) * (ux - vy) + (uy + vx) * (uy + vx));
    float st = mix(rate, a.w, exp(-dt / FLUID_STRESS_T));
    return vec4(v, p, st);
}

vec2 fluidCell(vec2 q, ivec2 R){
    float asp = iResolution.x / iResolution.y;
    return vec2(q.x / asp + 0.5, 0.5 - q.y) * vec2(R);
}

vec3 fluid(vec2 q, vec2 tp){
    ivec2 R = fluidSize(iChannel12);
    vec3 col = bgNoise(tp);
    float field = fluidLerp(iChannel12, fluidCell(q, R), R).w;
    col += GRAD_BOT * FLUID_GLOW * (1. - exp(-field / FLUID_STRESS_REF));

    float h = 1. / FLUID_ROWS;
    vec2 id = floor(q / h);
    float best = 1e9;
    vec3 ac = FLUID_IDLE;
    float scale = FLUID_AMP * h;
    for(int j = -1; j <= 1; j++) for(int i = -1; i <= 1; i++){
        vec2 cc = (id + vec2(i, j) + 0.5) * h;
        vec4 f = fluidLerp(iChannel12, fluidCell(cc, R), R);
        vec2 vel = vec2(f.x, -f.y) / float(R.y);
        vec2 off = vel * FLUID_DISP;
        float lo = length(off);
        if(lo > FLUID_DISP_MAX * h) off *= FLUID_DISP_MAX * h / lo;
        vec2 fc = fluidCell(cc, R);
        ivec2 ic = ivec2(fc);
        float om = -fluidCurl(iChannel12, ic, R);
        float tw = clamp(om * FLUID_TWIST, -1.2, 1.2);
        vec2 gp = Rot(tw) * (q - cc - off) / scale;
        float sd = glyphDist(gp) * scale;
        if(sd < best){
            best = sd;
            float sx = 1. - exp(-f.w / FLUID_STRESS_REF);
            vec3 blue = ampGradient(gp) * mix(0.75, 1.15, sx);
            ac = mix(FLUID_IDLE, blue, smoothstep(0., 0.6, sx));
            ac = mix(ac, FLUID_HOT, smoothstep(0.7, 1., sx) * 0.6);
        }
    }
    return mix(col, ac, S(best));
}
