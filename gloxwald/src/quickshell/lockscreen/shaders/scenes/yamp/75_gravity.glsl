// --- gravity: amps fired into a sun and three planets -------------------------
// the planets run on exact circular Kepler orbits (pure functions of time);
// the amps are test particles. bufferGravState integrates them (leapfrog,
// adaptive substeps) over its own previous output in iChannel9, one row per
// amp: x=0 pos.xy vel.xy, x=1 status (0 dead, 1 flying, 2 crashed,
// 3 parked round a planet), time of the last launch/release/crash/capture,
// position before the last step, x=2 last integration time, x=3 this
// frame's path segment for the trail pass, x=4 parking orbit (planet,
// radius, phase at capture, angular velocity), x=5 the capture's start
// radius and angular velocity, eased into the parking orbit over GRAV_RETRO. Texels from x=GRAV_GRID_X on are a coarse screen grid, one
// GRAV_CELL square per texel, each a 96-bit mask (24 per channel) of the
// amps near it, so the full-screen passes only look at those.
// bufferGravTrail is a decaying phosphor of the segments.
// Each amp relaunches every GRAV_CYCLE, the slots evenly staggered, from a
// fresh random spot just off screen with its own aim and speed.
// Planets can't capture on gravity alone (nothing sheds the energy, and the
// rails aren't Kepler), so amps do it with their rockets: swinging through
// periapsis of a planet close and slow enough, some fire a retro burn into a
// circular parking orbit, ride along for a while, then burn out again.
// Some do the same round the sun at their first periapsis.
const float GRAV_GM      = 1.35e-3;
const vec2  GRAV_ORBIT[3] = vec2[3](vec2(0.14, 0.3), vec2(0.26, 2.4), vec2(0.40, 4.4));
const float GRAV_RAD[4]  = float[4](0.06, 0.018, 0.03, 0.024);
const float GRAV_SOFT    = 0.004;
const float GRAV_ORBIT_SPEED = 0.3;
const int   GRAV_N       = 34;
const float GRAV_CYCLE   = 84.;
const float GRAV_BURN    = 1.6;
const float GRAV_V0      = 0.25;
const vec2  GRAV_SPEED   = vec2(0.028, 0.062);
const vec2  GRAV_PERI    = vec2(0.09, 0.5);
const float GRAV_DIVE    = 0.12;
const int   GRAV_STEPS   = 96;
const float GRAV_AMP     = 0.016;
const float GRAV_TRAIL_W = 0.0009;
const float GRAV_TRAIL_T = 1.;
const float GRAV_TRAIL_GAIN = 0.9;
const vec3  GRAV_SUN_COL = vec3(1., 0.85, 0.55);
const vec3  GRAV_PLANET_COL = vec3(0.75, 0.55, 0.4);
const vec3  GRAV_ORBIT_COL = vec3(0.7);
const float GRAV_ORBIT_A = 0.12;
const float GRAV_ORBIT_W = 0.0006;
const float GRAV_BOOM_T  = 0.8;
const float GRAV_CELL    = 1. / 14.;
const ivec2 GRAV_GRID    = ivec2(32, 14);
const int   GRAV_GRID_X  = 6;
const float GRAV_REACH   = 0.075;
const float GRAV_CAPTURE_R = 3.5;
const float GRAV_CAPTURE_V = 3.;
const float GRAV_CAPTURE_P = 0.7;
const float GRAV_CAPTURE_COOL = 3.;
const vec2  GRAV_PARK    = vec2(8., 25.);
const vec2  GRAV_SUN_PARK = vec2(20., 50.);
const float GRAV_SUN_P   = 0.25;
const float GRAV_ESCAPE  = 1.7;
const float GRAV_RETRO   = 0.8;

ivec2 gravCell(vec2 q, float asp){
    return ivec2(floor((q + vec2(0.5 * asp, 0.5)) / GRAV_CELL));
}

uvec4 gravNear(sampler2D st, vec2 q, float asp){
    ivec2 c = gravCell(q, asp);
    if(any(lessThan(c, ivec2(0))) || any(greaterThanEqual(c, GRAV_GRID))) return uvec4(0u);
    return uvec4(texelFetch(st, ivec2(GRAV_GRID_X, 0) + c, 0));
}

int gravPop(inout uvec4 m){
    for(int c = 0; c < 4; c++){
        if(m[c] == 0u) continue;
        int b = findLSB(m[c]);
        m[c] &= m[c] - 1u;
        return c * 24 + b;
    }
    return -1;
}

vec4 gravGrid(ivec2 c){
    if(c.x >= GRAV_GRID.x || c.y >= GRAV_GRID.y) return vec4(0.);
    vec2 bc = (vec2(c) + 0.5) * GRAV_CELL - vec2(0.5 * u_aspect, 0.5);
    float h = 0.5 * GRAV_CELL + GRAV_REACH;
    uvec4 m = uvec4(0u);
    for(int i = 0; i < GRAV_N; i++){
        vec2 p = texelFetch(iChannel9, ivec2(0, i), 0).xy;
        if(all(lessThan(abs(p - bc), vec2(h)))) m[i / 24] |= 1u << uint(i % 24);
    }
    return vec4(m);
}

vec3 gravBody(int k, float t){
    if(k == 0) return vec3(0., 0., GRAV_GM);
    vec2 o = GRAV_ORBIT[k - 1];
    float period = 6.2831853 * sqrt(o.x * o.x * o.x / GRAV_GM);
    float a = o.y + 6.2831853 * fract(t * GRAV_ORBIT_SPEED / period);
    return vec3(o.x * cos(a), o.x * sin(a), GRAV_GM * pow(GRAV_RAD[k] / GRAV_RAD[0], 3.));
}

vec2 gravBodyVel(int k, float t){
    if(k == 0) return vec2(0.);
    vec2 o = GRAV_ORBIT[k - 1];
    float period = 6.2831853 * sqrt(o.x * o.x * o.x / GRAV_GM);
    float a = o.y + 6.2831853 * fract(t * GRAV_ORBIT_SPEED / period);
    return o.x * 6.2831853 * GRAV_ORBIT_SPEED / period * vec2(-sin(a), cos(a));
}

vec4 gravPark(vec4 o, vec2 o2, float tc, float t){
    int k = int(o.x);
    float T = GRAV_RETRO, tau = t - tc;
    float u = clamp(tau / T, 0., 1.);
    float sm = u * u * (3. - 2. * u);
    float I = T * (u * u * u - 0.5 * u * u * u * u) + max(tau - T, 0.);
    float a = o.z + o2.y * tau + (o.w - o2.y) * I;
    float rr = mix(o2.x, o.y, sm);
    float dr = (o.y - o2.x) * 6. * u * (1. - u) / T;
    vec2 e = vec2(cos(a), sin(a));
    return vec4(gravBody(k, t).xy + rr * e, gravBodyVel(k, t) + rr * mix(o2.y, o.w, sm) * vec2(-e.y, e.x) + dr * e);
}

float gravHash(int id, uint salt){
    return pcgHash(uvec3(uint(id + 1000000), salt, uint(sk_seed(2) * 4e9)));
}

vec2 gravAccel(vec2 p, float t, out float rd, out int hit){
    vec2 a = vec2(0.);
    rd = 1e9;
    hit = -1;
    for(int k = 0; k < 4; k++){
        vec3 b = gravBody(k, t);
        vec2 d = b.xy - p;
        float r2 = dot(d, d) + GRAV_SOFT * GRAV_SOFT;
        a += b.z * d / (r2 * sqrt(r2));
        float s = length(d) - GRAV_RAD[k];
        if(s < 0.) hit = k;
        rd = min(rd, s);
    }
    return a;
}

float gravLaunch(int i, float t, out int id){
    float off = float(i) * GRAV_CYCLE / float(GRAV_N);
    float n = floor((t - off) / GRAV_CYCLE);
    id = int(n) * GRAV_N + i;
    return n * GRAV_CYCLE + off;
}

vec4 gravSpawn(int id, out float v){
    uint s = uint(sk_seed(2) * 4e9), u = uint(id + 1000000);
    float h1 = pcgHash(uvec3(u, 1u, s)), h2 = pcgHash(uvec3(u, 2u, s)), h3 = pcgHash(uvec3(u, 3u, s));
    float h5 = pcgHash(uvec3(u, 5u, s));
    float th = 6.2831853 * h1;
    vec2 dir = vec2(cos(th), sin(th));
    vec2 E = vec2(0.5 * u_aspect + 0.03, 0.53);
    vec2 p = dir * min(E.x / max(abs(dir.x), 1e-4), E.y / max(abs(dir.y), 1e-4));
    v = mix(GRAV_SPEED.x, GRAV_SPEED.y, h5);
    float rp = h2 < GRAV_DIVE ? GRAV_RAD[0] * h2 / GRAV_DIVE : mix(GRAV_PERI.x, GRAV_PERI.y, (h2 - GRAV_DIVE) / (1. - GRAV_DIVE));
    float r0 = length(p);
    float vp = sqrt(max(v * v + 2. * GRAV_GM / rp - 2. * GRAV_GM / r0, 0.));
    float a = asin(clamp(rp * vp / (r0 * v), 0., 1.)) * (h3 < 0.5 ? -1. : 1.);
    vec2 d = -p / r0;
    d = vec2(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a));
    return vec4(p, d * v * GRAV_V0);
}

float gravRadial(vec4 s, int j, float t){
    return dot(s.xy - gravBody(j, t).xy, s.zw - gravBodyVel(j, t));
}

void gravFly(inout vec4 s, inout vec2 st, inout vec4 park, inout vec2 park2, float t0, float t1, float L, float v, int id){
    float t = t0;
    float thrust = v * (1. - GRAV_V0) / GRAV_BURN;
    vec4 rad0 = vec4(gravRadial(s, 0, t), gravRadial(s, 1, t), gravRadial(s, 2, t), gravRadial(s, 3, t));
    int pj = int(park.x);
    float esc = st.y > L + 0.5 ? abs(park.w) * park.y * (GRAV_ESCAPE - 1.) / GRAV_RETRO : 0.;
    for(int k = 0; k < GRAV_STEPS; k++){
        if(t >= t1) break;
        float rd;
        int hit;
        vec2 a = gravAccel(s.xy, t, rd, hit);
        float sp = max(length(s.zw), 0.02);
        float h = k == GRAV_STEPS - 1 ? t1 - t : min(clamp(0.03 * max(rd, 0.002) / sp, 2e-4, 0.01), t1 - t);
        vec2 th = t - L < GRAV_BURN ? normalize(s.zw) * thrust : vec2(0.);
        if(esc > 0. && t - st.y < GRAV_RETRO) th += normalize(s.zw - gravBodyVel(pj, t)) * esc;
        s.zw += (a + th) * h * 0.5;
        s.xy += s.zw * h;
        t += h;
        a = gravAccel(s.xy, t, rd, hit);
        th = t - L < GRAV_BURN ? normalize(s.zw) * thrust : vec2(0.);
        if(esc > 0. && t - st.y < GRAV_RETRO) th += normalize(s.zw - gravBodyVel(pj, t)) * esc;
        s.zw += (a + th) * h * 0.5;
        if(hit >= 0){ st = vec2(2., t); return; }
        if(length(s.xy) > 3.){ st = vec2(0.); return; }
        for(int j = 0; j < 4; j++){
            float r1 = gravRadial(s, j, t);
            bool peri = rad0[j] <= 0. && r1 > 0.;
            rad0[j] = r1;
            if(!peri || t - st.y < GRAV_CAPTURE_COOL) continue;
            vec3 b = gravBody(j, t);
            vec2 rel = s.xy - b.xy, vr = s.zw - gravBodyVel(j, t);
            float d = length(rel);
            if(j == 0){
                if(st.y > L + 0.5 || gravHash(id, 10u) > GRAV_SUN_P) continue;
            } else {
                if(d > GRAV_RAD[j] * GRAV_CAPTURE_R || length(vr) > GRAV_CAPTURE_V * sqrt(b.z / d)) continue;
                if(gravHash(id, uint(10 + j)) > GRAV_CAPTURE_P) continue;
            }
            float pr = max(d, GRAV_RAD[j] * 1.5);
            float sg = rel.x * vr.y - rel.y * vr.x < 0. ? -1. : 1.;
            park = vec4(float(j), pr, atan(rel.y, rel.x), sg * sqrt(b.z / (pr * pr * pr)));
            park2 = vec2(d, sg * length(vr) / d);
            st = vec2(3., t);
            s = gravPark(park, park2, t, t);
            return;
        }
    }
}

vec4 gravState(int x, int i){
    if(x >= GRAV_GRID_X) return gravGrid(ivec2(x - GRAV_GRID_X, i));
    if(i >= GRAV_N) return vec4(0.);
    vec4 s = texelFetch(iChannel9, ivec2(0, i), 0);
    vec4 s1 = texelFetch(iChannel9, ivec2(1, i), 0);
    vec2 st = s1.xy, a0 = s1.zw;
    vec4 park = texelFetch(iChannel9, ivec2(4, i), 0);
    vec2 park2 = texelFetch(iChannel9, ivec2(5, i), 0).xy;
    float t0 = texelFetch(iChannel9, ivec2(2, 0), 0).x, t1 = iTime;
    if(t1 < t0 || t1 - t0 > 0.5){ st = vec2(0.); t0 = t1; }
    if(x == 2) return vec4(t1, 0., 0., 0.);
    vec2 a = s.xy;
    bool was = st.x == 1. || st.x == 3.;
    int id;
    float L = gravLaunch(i, t1, id), v;
    if(L > t0){
        s = gravSpawn(id, v);
        st = vec2(1., L);
        a = s.xy;
        a0 = a;
        was = true;
        t0 = L;
    } else gravSpawn(id, v);
    if(st.x == 3.){
        vec2 hold = park.x < 0.5 ? GRAV_SUN_PARK : GRAV_PARK;
        float rel = st.y + mix(hold.x, hold.y, gravHash(id, 20u));
        if(t1 < rel){
            s = gravPark(park, park2, st.y, t1);
            for(int k = 0; k < 4; k++)
                if(k != int(park.x) && length(s.xy - gravBody(k, t1).xy) < GRAV_RAD[k]) st = vec2(2., t1);
        }
        else {
            s = gravPark(park, park2, st.y, rel);
            st = vec2(1., rel);
            t0 = rel;
        }
    }
    if(st.x == 1.){
        gravFly(s, st, park, park2, t0, t1, L, v, id);
        if(st.x == 3.) s = gravPark(park, park2, st.y, t1);
    }
    if(x == 4) return park;
    if(x == 5) return vec4(park2, 0., 0.);
    if(x == 0) return st.x == 0. || st.x == 2. && t1 - st.y > GRAV_BOOM_T ? vec4(1e4) : s;
    if(x == 1) return vec4(st, a);
    return was ? vec4(a0, s.xy) : vec4(1e4);
}

vec4 gravTrail(vec2 q, vec4 prev){
    float T = texelFetch(iChannel8, ivec2(2, 0), 0).x;
    if(T == prev.a) return prev;
    float e = T < prev.a || T - prev.a > 0.5 ? 0. : prev.r * exp(-(T - prev.a) / GRAV_TRAIL_T);
    uvec4 m = gravNear(iChannel8, q, iResolution.x / iResolution.y);
    for(int k = 0; k < GRAV_N; k++){
        int i = gravPop(m);
        if(i < 0) break;
        vec4 g = texelFetch(iChannel8, ivec2(3, i), 0);
        if(g.x > 1e3) continue;
        float d = sdSegment(q, g.xy, g.zw);
        e = max(e, exp(-0.5 * d * d / (GRAV_TRAIL_W * GRAV_TRAIL_W)));
    }
    return vec4(e, 0., 0., T);
}

vec3 gravity(vec2 q, vec2 tp){
    vec3 col = bgNoise(tp);
    float e = texture(iChannel11, roomUV(q)).r;
    col += (1. - exp(-e * GRAV_TRAIL_GAIN)) * mix(GRAD_BOT, GRAD_TOP, 0.5) * 0.8;

    for(int k = 0; k < 3; k++)
        col = mix(col, GRAV_ORBIT_COL, S(abs(length(q) - GRAV_ORBIT[k].x) - GRAV_ORBIT_W) * GRAV_ORBIT_A);

    float ds = length(q);
    col += GRAV_SUN_COL * (0.25 * exp(-max(ds - GRAV_RAD[0], 0.) / 0.025) + 0.08 * exp(-ds / 0.15));
    col = mix(col, mix(GRAV_SUN_COL, vec3(1.), 0.6 * (1. - ds / GRAV_RAD[0])), S(ds - GRAV_RAD[0]));

    for(int k = 1; k < 4; k++){
        vec3 b = gravBody(k, iTime);
        vec2 rel = (q - b.xy) / GRAV_RAD[k];
        float r2 = dot(rel, rel);
        if(r2 > 4.) continue;
        vec3 n = vec3(rel, sqrt(max(1. - r2, 0.)));
        vec3 L = normalize(vec3(-normalize(b.xy), 0.25));
        float lit = max(dot(n, L), 0.) * 0.95 + 0.05;
        col = mix(col, GRAV_PLANET_COL * lit, S((sqrt(r2) - 1.) * GRAV_RAD[k]));
    }

    uvec4 m = gravNear(iChannel10, q, iResolution.x / iResolution.y);
    for(int k = 0; k < GRAV_N; k++){
        int i = gravPop(m);
        if(i < 0) break;
        vec4 s = texelFetch(iChannel10, ivec2(0, i), 0);
        if(length(q - s.xy) > 0.07) continue;
        vec2 st = texelFetch(iChannel10, ivec2(1, i), 0).xy;
        if(st.x == 0.) continue;
        if(st.x == 2.){
            float age = iTime - st.y;
            if(age < 0. || age > GRAV_BOOM_T) continue;
            float f = age / GRAV_BOOM_T;
            float r = length(q - s.xy);
            float ring = S(abs(r - 0.045 * sqrt(f)) - 0.0015 * (1. - f));
            col += PEN_FLAME_COL * ring * (1. - f) + PEN_FLAME_HOT * exp(-r / (0.012 * (1. - f) + 1e-3)) * (1. - f) * (1. - f);
            continue;
        }
        int id;
        float L = gravLaunch(i, iTime, id);
        float age = iTime - L, ev = iTime - st.y;
        float vis = smoothstep(0., 0.3, age) * (1. - smoothstep(GRAV_CYCLE - 3., GRAV_CYCLE - 0.5, age));
        vec2 dir = normalize(s.zw);
        vec2 gp = (q - s.xy) / GRAV_AMP;
        gp = vec2(dot(gp, vec2(dir.y, -dir.x)), dot(gp, dir));
        float burn = smoothstep(0., 0.1, age) * smoothstep(GRAV_BURN, GRAV_BURN - 0.3, age);
        if(st.x == 1. && st.y > L + 0.5) burn = max(burn, smoothstep(0., 0.1, ev) * smoothstep(GRAV_RETRO, GRAV_RETRO - 0.3, ev));
        if(burn > 0.) col = penExhaust(col, gp, float(i), vis * burn);
        if(st.x == 3. && ev < GRAV_RETRO) col = penExhaust(col, -gp, float(i), vis * smoothstep(0., 0.1, ev) * smoothstep(GRAV_RETRO, GRAV_RETRO - 0.3, ev));
        col = mix(col, ampGradient(gp), S(glyphDist(gp) * GRAV_AMP) * vis);
    }
    return col;
}
