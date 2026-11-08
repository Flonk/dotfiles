// --- fish: a school of small amps and a shark hunting it ---------------------
// FI_N - 1 small amps school as boids (bufferFish) and scatter from the
// predator, agent 0: a shark emoji (FI_BIG across, from sky.png, facing the
// way it swims and pitching with it) that cruises toward the school and
// lunges at the nearest fish it sees within FI_HUNT. Fish within FI_FEAR of
// it flee at a burst of speed, through deep water lit from the surface
// (fiWater).
const int   FI_N     = 160;
const float FI_SIZE  = 0.013;
const float FI_BIG   = 0.1;
const vec2  FI_SPEED = vec2(0.1, 0.22);
const float FI_BURST = 0.42;
const float FI_SEP   = 0.022;
const float FI_SEE   = 0.07;
const float FI_FEAR  = 0.17;
const float FI_HUNT  = 0.3;
const vec2  FI_PRED_SPEED = vec2(0.07, 0.24);
const float FI_FLOW   = 0.6;
const float FI_RAY_TILT = 0.35;

void fiStep(sampler2D ch, int i, float dt, bool fresh, float asp, out vec4 r0, out vec4 r1){
    r1 = vec4(0.);
    if(fresh){
        vec2 p = i == 0 ? vec2(-0.45 * asp, 0.3) : (agRand2(float(i), 2.1) - 0.5) * vec2(0.5, 0.35);
        float a = random(vec2(i, 5.5)) * 6.2831853;
        r0 = vec4(p, vec2(cos(a), sin(a)) * FI_SPEED.x);
        return;
    }
    vec4 s = agGet(ch, i, 0);
    vec2 p = s.xy, v = s.zw;
    vec2 pred = agGet(ch, 0, 0).xy;
    vec2 acc = vec2(0.);
    if(i == 0){
        vec2 cen = vec2(0.), near = p;
        float best = 1e9, n = 0.;
        for(int j = 1; j < FI_N; j++){
            vec2 o = agGet(ch, j, 0).xy;
            cen += o; n += 1.;
            float l = length(o - p);
            if(l < best){ best = l; near = o; }
        }
        bool hunt = best < FI_HUNT;
        acc = normalize((hunt ? near : cen / n) - p + 1e-5) * (hunt ? 0.9 : 0.25) + agWalls(p, asp, 0.1) * 1.5;
        float lim = hunt ? FI_PRED_SPEED.y : FI_PRED_SPEED.x + 0.05;
        v = agLimit(v + acc * dt, FI_PRED_SPEED.x, lim);
        r0 = vec4(p + v * dt, v);
        return;
    }
    vec2 sep = vec2(0.), ali = vec2(0.), coh = vec2(0.);
    float n = 0.;
    for(int j = 1; j < FI_N; j++){
        if(j == i) continue;
        vec4 o = agGet(ch, j, 0);
        vec2 d = o.xy - p;
        float l = length(d);
        if(l > FI_SEE) continue;
        if(l < FI_SEP) sep -= d / max(l * l, 1e-4) * FI_SEP;
        ali += o.zw; coh += o.xy; n += 1.;
    }
    acc = sep;
    if(n > 0.) acc += (ali / n - v) * 1.8 + (coh / n - p) * 1.6;
    float w = tcNoise(vec2(float(i) * 0.53, iTime * 0.4)) * 12.566;
    acc += vec2(cos(w), sin(w)) * 0.1 + agWalls(p, asp, 0.1) * 1.5;
    vec2 fd = p - pred;
    float fl = length(fd);
    float fear = 1. - smoothstep(FI_FEAR * 0.4, FI_FEAR, fl);
    acc += fd / max(fl, 1e-4) * fear * 3.;
    v = agLimit(v + acc * dt, FI_SPEED.x, mix(FI_SPEED.y, FI_BURST, fear));
    r0 = vec4(p + v * dt, v);
}

// deep water: brighter towards the surface, shafts of light slanting down
// from it (FI_RAY_TILT) and swaying, and motes drifting in the light
vec3 fiWater(vec2 q, vec2 tp){
    float depth = 0.5 - q.y;
    vec3 col = mix(GRAD_BOT * 0.32, GRAD_BOT * 0.025, smoothstep(0., 1., depth)) * (0.85 + 0.3 * tcFbm(q * 3. + iTime * 0.02));
    float t = iTime * FI_FLOW;
    float x = q.x + depth * FI_RAY_TILT + 0.03 * sin(t * 0.7 + depth * 2.);
    float rays = 0.;
    for(int k = 0; k < 3; k++){
        float f = 3. + float(k) * 4.3;
        float n = tcNoise(vec2(x * f + float(k) * 7.1, t * (0.25 + 0.1 * float(k))));
        rays += pow(n, 4.) * (1. - 0.25 * float(k));
    }
    col += mix(GRAD_TOP, vec3(0.85, 1., 1.), 0.3) * 0.22 * rays * exp(-depth * 1.6);
    col += vec3(0.8, 1., 1.) * 0.1 * smoothstep(0.06, 0., depth) * (0.6 + 0.4 * sin(q.x * 40. + t * 3.));
    vec2 mp = q * 55. + vec2(0., iTime * 0.6);
    vec2 mc = floor(mp), mf = fract(mp) - 0.5;
    vec2 jit = vec2(random(mc), random(mc + 7.3)) - 0.5;
    float mote = step(0.86, random(mc + 3.1)) * smoothstep(0.08, 0., length(mf - jit * 0.7));
    col += vec3(0.6, 0.85, 0.9) * 0.18 * mote * (0.4 + rays) * exp(-depth * 1.2);
    return col;
}

vec3 fish(vec2 q, vec2 tp){
    float asp = iResolution.x / iResolution.y;
    vec3 col = fiWater(q, tp);
    vec4 sl[AG_TEX];
    agSlots(iChannel16, q, asp, sl);
    vec4 ps = agGet(iChannel16, 0, 0);
    for(int k = 0; k < AG_SLOTS; k++){
        int i = int(sl[k >> 2][k & 3] + 0.5) - 1;
        if(i < 0) break;
        if(i == 0) continue;
        vec4 s = agGet(iChannel16, i, 0);
        float bank = clamp(-s.z / max(length(s.zw), 1e-4), -1., 1.) * 0.4;
        float d = agAmp(q, s.xy, vec2(sin(-bank), cos(bank)), FI_SIZE);
        vec3 c = mix(vec3(0.6, 0.72, 0.75), GRAD_TOP, random(vec2(i, 1.9)) * 0.6);
        col = mix(col, c, S(d));
    }
    vec2 d = (q - ps.xy) / FI_BIG;
    if(dot(d, d) < 0.6){
        bool right = ps.z > 0.;
        float a = clamp(atan(ps.w, abs(ps.z)), -0.6, 0.6) * (right ? -1. : 1.);
        d = mat2(cos(a), sin(a), -sin(a), cos(a)) * d;
        if(right) d.x = -d.x;
        vec2 uv = vec2(d.x + 0.5, 0.5 - d.y);
        if(all(greaterThan(uv, vec2(0.))) && all(lessThan(uv, vec2(1.)))){
            vec4 e = skyEmojiAt(uv, 128);
            col = col * (1. - e.a) + e.rgb;
        }
    }
    return col;
}
