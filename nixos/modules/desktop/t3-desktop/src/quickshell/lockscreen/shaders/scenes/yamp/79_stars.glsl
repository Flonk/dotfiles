// --- stars: the real night sky over Vienna, every star an amp -----------------
// The sky comes from sky.png in iChannel14 (gen_sky.py: Hipparcos stars to
// mag 5 with a sky-cell index, and the tour targets: constellations,
// asterisms, deep-sky objects, named stars and planets, with figures and
// names). u_lst is the local sidereal time when the pass was created; the sky
// turns from there at SKY_RATE, the real sidereal rate. u_planets holds Venus,
// Mars, Jupiter and Saturn for the day (unit vector, magnitude), worked out
// in scene.qml from orbital elements; u_algol is Algol's magnitude now,
// from its eclipse ephemeris. u_bodies (scene.qml, updated live) holds the
// Moon (direction, illuminated fraction), the Sun, and the ISS now and a few
// seconds ago (direction; 0 not up or no orbit, 1 in Earth's shadow, 2
// sunlit), propagated from its Celestrak TLE. The sky turns at the real
// sidereal rate, so all of it matches the real sky. The ecliptic (gold) and
// celestial equator (teal) are drawn as faint great circles, with a small
// ring round the north celestial pole; the Moon is a disc lit on the
// side facing the Sun (a real crescent or gibbous), mottled from the noise
// texture, the ISS the satellite emoji (baked into
// sky.png) with its trail.
// Every SKY_PERIOD a target that is well up is picked and the camera swings
// over to it (ease in-out over SKY_MOVE), holds it SKY_HOLD, takes it down
// again over SKY_OFF (lines retracting, stars shrinking) and rests until the
// next; its figure draws itself in line
// by line over SKY_DRAW (teal for constellations, gold for asterisms,
// dashed for star-hopping guides) or a
// marker ring opens round it, its stars swell (SKY_GROW) and glow in their
// own colour, and its name is set under it in the flap font (iChannel13). bufferStars works the
// target and camera out once per frame (SKY_FIG_W texels, iChannel15 in the
// main pass): x = 0 (target, envelope, label position), x = 1 the figure's
// screen bounding box, x = 2 (segments, name length, name width, type),
// x = 3 the camera axis, x = 4 (marker radius, draw-in progress, fade
// out), x = 5.. the deep-sky
// objects' screen circles (centre, radius, in front), then one texel per
// segment.
// Each pixel's ray is turned into RA/Dec and only the stars listed in its sky
// cell are drawn: an upright amp sized and brightened by magnitude, tinted by
// B-V, twinkling. Under them lie the Milky Way (a band about the galactic
// plane, a bulge towards the centre, the Great Rift, mottled by noise) and
// the deep-sky objects' glows; over them the planets, the odd meteor and a
// satellite now and then, all moving on great circles; a dark ridge cuts the
// horizon, and a horizon gizmo (skyGizmo) is drawn over everything.
const float SKY_LAT     = 0.84142;
const float SKY_RATE    = 7.2921159e-5;
const float SKY_FOCAL   = 1.;
const vec2  SKY_SIZE    = vec2(0.005, 0.028);
const vec2  SKY_BRIGHT  = vec2(0.45, 1.15);
const float SKY_MARGIN  = 0.02269;
const int   SKY_CELLS_RA = 48;
const int   SKY_CELLS_DEC = 24;
const int   SKY_TARGETS = 137;
const int   SKY_PLANET_FIRST = 131;
const int   SKY_DSO_FIRST = 103;
const int   SKY_DSO_N   = 10;
const int   SKY_SEGS    = 48;
const int   SKY_FIG_SEG = 5 + SKY_DSO_N;
const int   SKY_FIG_STAR = SKY_FIG_SEG + SKY_SEGS;
const int   SKY_FIG_W   = SKY_FIG_STAR + SKY_SEGS;
const int   SKY_NAME    = 25;
const float SKY_PERIOD  = 30.;
const float SKY_HOLD    = 20.;
const float SKY_OFF     = 2.;
const float SKY_MOVE    = 3.5;
const float SKY_DRAW    = 1.6;
const float SKY_STAGGER = 1.2;
const float SKY_GROW    = 0.8;
const float SKY_GROW_MAX = 0.034;
const float SKY_MIN_ALT = 0.3;
const float SKY_AIM_DROP = 0.06;
const vec2  SKY_ALT_RANGE = vec2(0.32, 1.15);
const vec3  SKY_TEAL    = vec3(0.25, 0.75, 0.82);
const vec3  SKY_GOLD    = vec3(0.95, 0.78, 0.45);
const vec3  SKY_GUIDE   = vec3(0.85, 0.9, 0.95);
const float SKY_DASH    = 0.014;
const vec3  SKY_ALGOL   = vec3(0.51468, 0.55267, 0.65536);
const vec3  SKY_ECLIPTIC = vec3(0., -0.39777, 0.91748);
const float SKY_CIRCLE  = 0.12;
const float SKY_MOON_R  = 0.035;
const vec3  SKY_MOON_LIT = vec3(0.95, 0.93, 0.86);
const vec3  SKY_MOON_DARK = vec3(0.09, 0.1, 0.13);
const float SKY_ISS_H   = 0.032;
const float SKY_ISS_DT  = 6.;
const float SKY_ISS_TRAIL = 5.;
const float SKY_TEXT_H  = 0.024;
const vec3  SKY_ZENITH  = vec3(0.003, 0.006, 0.02);
const vec3  SKY_HORIZON = vec3(0.03, 0.07, 0.11);
const vec3  SKY_GROUND  = vec3(0.004, 0.006, 0.01);
const float SKY_MW      = 0.075;
const vec3  SKY_NGP     = vec3(-0.86766, -0.19808, 0.45598);
const vec3  SKY_GC      = vec3(-0.05488, -0.87344, -0.48384);
const float SKY_DSO     = 0.35;
const vec3  SKY_PLANET_COL[4] = vec3[4](vec3(1., 0.98, 0.92), vec3(1., 0.6, 0.42), vec3(1., 0.93, 0.8), vec3(0.98, 0.88, 0.62));
const vec2  SKY_METEOR  = vec2(6., 0.5);
const float SKY_METEOR_T = 0.8;
const vec2  SKY_SAT     = vec2(40., 0.6);
const float SKY_SAT_T   = 30.;
const vec3  SKY_GIZMO   = vec3(0.45, 0.75, 0.8);
const vec3  SKY_GIZMO_A = vec3(0.07, 0.16, 0.3);
const float SKY_GIZMO_STEP = 0.261799;
const float SKY_GIZMO_H = 0.028;
const float SKY_COMPASS_EDGE = 0.035;
const int   SKY_COMPASS[16] = int[16](24, -1, 24, 15, 15, -1, 29, 15, 29, -1, 29, 33, 33, -1, 24, 33);

vec3 skyRGB(int i){ return floor(texelFetch(iChannel14, ivec2(i % 1024, i / 1024), 0).rgb * 255. + 0.5); }

vec3 skyVec(int i){
    vec3 a = skyRGB(i), b = skyRGB(i + 1);
    return vec3(a.x * 256. + a.y, a.z * 256. + b.x, b.y * 256. + b.z) / 65535. * 2. - 1.;
}

float skyNoise(float x){
    float i = floor(x), f = fract(x);
    return mix(random(vec2(i, 9.1)), random(vec2(i + 1., 9.1)), f * f * (3. - 2. * f));
}

float skyNoise3(vec3 p){
    vec3 i = floor(p), f = fract(p);
    f = f * f * (3. - 2. * f);
    float n = dot(i, vec3(1., 57., 113.));
    vec4 a = fract(sin(vec4(n, n + 1., n + 57., n + 58.)) * 43758.5453);
    vec4 b = fract(sin(vec4(n + 113., n + 114., n + 170., n + 171.)) * 43758.5453);
    vec4 m = mix(a, b, f.z);
    return mix(mix(m.x, m.y, f.x), mix(m.z, m.w, f.x), f.y);
}

// equatorial frame of the local horizon at time t: columns E, N, U
mat3 skyHorizon(float t){
    float lst = u_lst + t * SKY_RATE;
    vec3 U = vec3(cos(SKY_LAT) * cos(lst), cos(SKY_LAT) * sin(lst), sin(SKY_LAT));
    vec3 N = vec3(-sin(SKY_LAT) * cos(lst), -sin(SKY_LAT) * sin(lst), cos(SKY_LAT));
    return mat3(cross(N, U), N, U);
}

void skyCamera(vec3 fw, out vec3 rt, out vec3 up){
    rt = normalize(cross(fw, vec3(0., 0., 1.)));
    up = cross(rt, fw);
}

// screen position of a local (E, N, U) direction
vec2 skyScreen(vec3 l, vec3 fw, vec3 rt, vec3 up, out float z){
    z = dot(l, fw);
    return SKY_FOCAL * vec2(dot(l, rt), dot(l, up)) / max(z, 1e-4);
}

vec2 skyProject(vec3 s, mat3 H, vec3 fw, vec3 rt, vec3 up, out float z){
    return skyScreen(s * H, fw, rt, up, z);
}

int skyRec(int c){ return 36 * 1024 + 32 * c; }

// the ISS now: its position at the last update moved on along its motion over
// the SKY_ISS_DT before it, so it glides between updates
vec3 skyIss(out vec3 vel){
    vel = (u_bodies[2].xyz - u_bodies[3].xyz) / SKY_ISS_DT;
    return normalize(u_bodies[2].xyz + vel * (iTime - u_bodies[3].w));
}

// the emoji at x0 of sky.png's emoji rows (0 the satellite, 128 the shark)
// at uv (0..1, y down), premultiplied, bilinear
vec4 skyEmojiAt(vec2 uv, int x0){
    vec2 f = clamp(uv * 64. - 0.5, 0., 63.);
    ivec2 i = ivec2(floor(f));
    vec2 t = f - vec2(i);
    vec4 c[4];
    for(int k = 0; k < 4; k++){
        ivec2 o = min(i + ivec2(k & 1, k >> 1), ivec2(63));
        c[k] = vec4(texelFetch(iChannel14, ivec2(x0 + o.x, 56 + o.y), 0).rgb, texelFetch(iChannel14, ivec2(x0 + 64 + o.x, 56 + o.y), 0).r);
    }
    return mix(mix(c[0], c[1], t.x), mix(c[2], c[3], t.x), t.y);
}

vec4 skyEmoji(vec2 uv){ return skyEmojiAt(uv, 0); }

vec3 skyTarget(int c){
    vec3 t = skyRGB(skyRec(c) + 1);
    if(t.y == 4.) return u_planets[int(t.z)].xyz;
    if(t.y == 6.) return u_bodies[0].xyz;
    vec3 vel;
    if(t.y == 7.) return u_bodies[2].w > 0. ? skyIss(vel) : vec3(0.);
    return skyVec(skyRec(c) + 2);
}

// the target of period k: the first, from a hashed start, that is well up
// at the period's start
int skyPick(float k){
    mat3 H = skyHorizon(k * SKY_PERIOD);
    int base = int(random(vec2(k, 0.37)) * float(SKY_TARGETS));
    for(int j = 0; j < SKY_TARGETS; j++){
        int c = (base + j * 37) % SKY_TARGETS;
        if((skyTarget(c) * H).z > SKY_MIN_ALT) return c;
    }
    return base;
}

// camera axis looking at target c, kept within SKY_ALT_RANGE of altitude
vec3 skyAim(int c, mat3 H){
    vec3 l = skyTarget(c) * H;
    float az = atan(l.x, l.y), alt = clamp(asin(clamp(l.z, -1., 1.)) - SKY_AIM_DROP, SKY_ALT_RANGE.x, SKY_ALT_RANGE.y);
    return vec3(sin(az) * cos(alt), cos(az) * cos(alt), sin(alt));
}

vec4 skyFigure(int x){
    mat3 H = skyHorizon(iTime);
    float k = floor(iTime / SKY_PERIOD), ph = iTime - k * SKY_PERIOD;
    int act = skyPick(k);
    vec3 a0 = skyAim(skyPick(k - 1.), H), a1 = skyAim(act, H);
    float e = cubicInOut(clamp(ph / SKY_MOVE, 0., 1.));
    vec3 fw = normalize(mix(a0, a1, e) + 1e-4 * vec3(0., 0., 1.));
    vec3 rt, up;
    skyCamera(fw, rt, up);
    float off = SKY_MOVE + SKY_HOLD;
    float env = smoothstep(SKY_MOVE, SKY_MOVE + 1.5, ph) * (1. - smoothstep(off, off + SKY_OFF, ph));
    float z;
    vec2 lp = skyProject(skyTarget(act), H, fw, rt, up, z);
    if(x == 0) return vec4(float(act), env, lp);
    if(x == 3) return vec4(fw, 0.);
    int rec = skyRec(act);
    vec3 h0 = skyRGB(rec), h1 = skyRGB(rec + 1);
    int sf = int(h0.x * 256. + h0.y), sn = min(int(h0.z), SKY_SEGS);
    float ring = h1.y == 2. ? SKY_FOCAL * tan(radians(skyRGB(rec + 29).x / 40.) * 0.5) + 0.012 : h1.y == 6. ? SKY_MOON_R * 1.6 : h1.y == 7. ? SKY_ISS_H * 0.9 : 0.022;
    if(x == 4) return vec4(sn > 0 ? 0. : ring, min(clamp((ph - SKY_MOVE) / SKY_DRAW, 0., 1.), 1. - clamp((ph - off) / SKY_OFF, 0., 1.)), step(ph, off + SKY_OFF), 0.);
    if(x >= 5 && x < SKY_FIG_SEG){
        int r = skyRec(SKY_DSO_FIRST + x - 5);
        vec2 sp = skyProject(skyVec(r + 2), H, fw, rt, up, z);
        float rad = SKY_FOCAL * tan(radians(skyRGB(r + 29).x / 40.) * 1.5) / max(z, 0.05);
        return z > 0.05 ? vec4(sp, rad, 1.) : vec4(0.);
    }
    if(x == 1){
        if(sn == 0) return vec4(lp - ring, lp + ring);
        vec4 bb = vec4(1e9, 1e9, -1e9, -1e9);
        for(int i = 0; i < SKY_SEGS; i++){
            if(i >= sn) break;
            int o = 42 * 1024 + 6 * (sf + i);
            vec2 pa = skyProject(skyVec(o), H, fw, rt, up, z);
            vec2 pb = skyProject(skyVec(o + 2), H, fw, rt, up, z);
            bb = vec4(min(bb.xy, min(pa, pb)), max(bb.zw, max(pa, pb)));
        }
        return bb;
    }
    if(x == 2){
        int nl = int(h1.x);
        float w = 0.;
        for(int i = 0; i < SKY_NAME; i++){ if(i >= nl) break; w += skyRGB(rec + 4 + i).y / 255.; }
        return vec4(float(sn), float(nl), w, h1.y);
    }
    if(x >= SKY_FIG_STAR){
        int i = x - SKY_FIG_STAR;
        if(i >= sn) return vec4(0.);
        int o = 42 * 1024 + 6 * (sf + i);
        return vec4(skyRGB(o + 4).xy, skyRGB(o + 5).xy) / 255.;
    }
    int i = x - SKY_FIG_SEG;
    if(i >= sn) return vec4(0.);
    int o = 42 * 1024 + 6 * (sf + i);
    float za, zb;
    vec2 pa = skyProject(skyVec(o), H, fw, rt, up, za);
    vec2 pb = skyProject(skyVec(o + 2), H, fw, rt, up, zb);
    return za > 0.05 && zb > 0.05 ? vec4(pa, pb) : vec4(1e4);
}

vec3 skyMilkyWay(vec3 d){
    float b = asin(clamp(dot(d, SKY_NGP), -1., 1.));
    float l = atan(dot(d, cross(SKY_NGP, SKY_GC)), dot(d, SKY_GC));
    float band = exp(-b * b / 0.026);
    float bulge = exp(-l * l / 0.6) * exp(-b * b / 0.06);
    if(band + bulge < 0.01) return vec3(0.);
    vec2 gl = vec2(l * 0.6, b * 2.);
    float n = texture(iChannel1, fract(gl * 1.3)).r * 0.6 + texture(iChannel1, fract(gl * 4.1 + 0.37)).r * 0.4;
    float rift = 1. - 0.65 * exp(-(b - 0.03) * (b - 0.03) / 0.0012) * smoothstep(-0.9, -0.2, l) * smoothstep(1.7, 0.8, l);
    float mw = (band * (0.45 + 0.55 * n) + bulge * 0.8 * (0.7 + 0.3 * n)) * rift;
    return mix(vec3(0.5, 0.58, 0.75), vec3(0.85, 0.75, 0.6), bulge) * mw * SKY_MW;
}

vec3 skyDeep(vec3 d, vec2 q, int act){
    vec3 col = vec3(0.);
    for(int i = 0; i < SKY_DSO_N; i++){
        vec4 sb4 = texelFetch(iChannel15, ivec2(5 + i, 0), 0);
        if(sb4.w < 0.5 || length(q - sb4.xy) > sb4.z) continue;
        int c = SKY_DSO_FIRST + i, rec = skyRec(c);
        vec3 sh = skyRGB(rec + 29);
        float sa = radians(sh.x / 40.) * 0.5, sb = radians(sh.y / 40.) * 0.5;
        vec3 o = skyVec(rec + 2);
        vec3 ea = normalize(cross(vec3(0., 0., 1.), o)), no = cross(o, ea);
        vec2 p = vec2(dot(d, ea), dot(d, no));
        float pa = sh.z / 255. * 3.1415927;
        p = vec2(p.x * cos(pa) - p.y * sin(pa), p.x * sin(pa) + p.y * cos(pa));
        float r = length(vec2(p.x / sb, p.y / sa));
        float kind = skyRGB(rec + 1).z, g;
        if(kind == 0.) g = exp(-r * r * 6.) + 0.35 * exp(-r * 2.5);
        else if(kind == 1.) g = 0.35 * exp(-r * r * 2.) + 0.6 * step(0.985, random(floor(p / (sa * 0.08)))) * step(r, 1.);
        else if(kind == 2.) g = exp(-r * r * 1.6) * (0.4 + 0.6 * skyNoise3(vec3(p / sa * 3., 1.)));
        else g = exp(-(r - 0.7) * (r - 0.7) / 0.03) + 0.2 * exp(-r * r * 4.);
        col += skyRGB(rec + 30) / 255. * g * SKY_DSO * (c == act ? 1.8 : 1.);
    }
    return col;
}

// distance to a label of up to two characters (flap font indices, -1 none)
// centred at p, h tall
float skyLabel(vec2 q, vec2 p, int c0, int c1, float h){
    vec2 t = (q - p) / h;
    float n = c1 < 0 ? 1. : 2.;
    if(abs(t.y) > 0.5 || abs(t.x) > 0.25 * n + 0.3) return 1e9;
    float d = flapGlyph(c0, vec2(t.x + (n - 1.) * 0.24, t.y));
    if(c1 >= 0) d = min(d, flapGlyph(c1, vec2(t.x - 0.24, t.y)));
    return d * h;
}

// the horizon gizmo: altitude rings and meridians every SKY_GIZMO_STEP (the
// horizon and every third meridian stronger, meridians fading out at the
// zenith), compass points on the horizon (slid up their meridian to stay
// SKY_COMPASS_EDGE above the bottom of the screen) and altitudes up the meridian
// nearest the view; the compass points come back in over, to go on top of
// the ridge, the rest lies behind it
vec3 skyGizmo(vec2 q, vec3 rl, vec3 fw, vec3 rt, vec3 up, out vec3 over){
    float px = 1. / (SKY_FOCAL * iResolution.y);
    float alt = asin(clamp(rl.z, -1., 1.)), az = atan(rl.x, rl.y);
    float da = abs(alt - SKY_GIZMO_STEP * round(alt / SKY_GIZMO_STEP));
    float k = round(az / SKY_GIZMO_STEP), mz = k * SKY_GIZMO_STEP;
    float dm = abs(dot(rl, vec3(cos(mz), -sin(mz), 0.)));
    float major = mod(k, 3.) == 0. ? 1. : 0.;
    float ring = smoothstep(1.5 * px, 0.5 * px, da);
    float mer = smoothstep(1.5 * px, 0.5 * px, dm) * (1. - smoothstep(1.2, 1.45, alt));
    float hor = smoothstep(2. * px, 0.7 * px, abs(alt));
    float g = SKY_GIZMO_A.x * ring + SKY_GIZMO_A.x * mix(1., 1.6, major) * mer + SKY_GIZMO_A.z * hor;
    float dt = 1e9, dc = 1e9;
    float z;
    {
        float a = 0.785398 * round(az / 0.785398);
        int j = int(mod(round(az / 0.785398), 8.));
        vec3 h = vec3(sin(a), cos(a), 0.);
        float floorY = SKY_COMPASS_EDGE - 0.5;
        float lo = 0.035, hi = 1.2;
        vec2 sp = skyScreen(h * cos(lo) + vec3(0., 0., sin(lo)), fw, rt, up, z);
        if(z > 0.1 && sp.y < floorY){
            for(int k = 0; k < 12; k++){
                float m = 0.5 * (lo + hi);
                vec2 t = skyScreen(h * cos(m) + vec3(0., 0., sin(m)), fw, rt, up, z);
                if(t.y < floorY) lo = m; else hi = m;
            }
            sp = skyScreen(h * cos(hi) + vec3(0., 0., sin(hi)), fw, rt, up, z);
        }
        if(z > 0.1 && sp.y >= floorY - 0.001) dc = skyLabel(q, sp, SKY_COMPASS[2 * j], SKY_COMPASS[2 * j + 1], SKY_GIZMO_H);
    }
    int j = int(round(alt / SKY_GIZMO_STEP));
    if(j >= 1 && j <= 5){
        float am = 0.785398 * round(atan(fw.x, fw.y) / 0.785398), al = float(j) * SKY_GIZMO_STEP;
        vec2 sp = skyScreen(vec3(sin(am) * cos(al), cos(am) * cos(al), sin(al)), fw, rt, up, z);
        int v = j * 15;
        if(z > 0.1) dt = min(dt, skyLabel(q, sp + vec2(0.022, 0.012), v / 10, v % 10, SKY_GIZMO_H * 0.8));
    }
    over = SKY_GIZMO * SKY_GIZMO_A.y * 4. * S(dc);
    return SKY_GIZMO * (g + SKY_GIZMO_A.y * 4. * S(dt));
}

// how far segment i of n has drawn in at progress p (segments start one
// after another, each growing from its first star)
float skyReveal(float p, int i, int n){
    return clamp(p * (1. + SKY_STAGGER) - SKY_STAGGER * float(i) / float(max(n, 1)), 0., 1.);
}

// how much the star at screen position sp is highlighted as a point target
// (figure stars are drawn over by the figure pass)
float skyLit(vec2 sp, vec4 f0, vec4 f2, vec4 f4){
    if(f0.y <= 0. && f4.y <= 0.) return 0.;
    float g = 0.;
    int sn = int(f2.x);
    if(sn == 0) return length(sp - f0.zw) < 0.004 ? cubicInOut(f4.y) * f4.z : 0.;
    return 0.;
}

// a point moving on a great circle in local (E, N, U), seeded by h
vec3 skyTrack(float h, float ang){
    float az = 6.2831853 * random(vec2(h, 1.1)), alt = 0.35 + 0.6 * random(vec2(h, 2.3));
    vec3 s = vec3(sin(az) * cos(alt), cos(az) * cos(alt), sin(alt));
    float th = 6.2831853 * random(vec2(h, 3.7));
    vec3 a = normalize(cross(s, vec3(0., 0., 1.)));
    vec3 t = a * cos(th) + cross(s, a) * sin(th);
    return normalize(s * cos(ang) + t * sin(ang));
}

vec3 stars(vec2 q, vec2 tp){
    mat3 H = skyHorizon(iTime);
    vec3 fw = texelFetch(iChannel15, ivec2(3, 0), 0).xyz, rt, up;
    if(dot(fw, fw) < 0.5) fw = vec3(0., -cos(0.4), sin(0.4));
    fw = normalize(fw);
    skyCamera(fw, rt, up);
    vec3 rl = normalize(q.x * rt + q.y * up + SKY_FOCAL * fw);
    vec4 f0 = texelFetch(iChannel15, ivec2(0, 0), 0);
    vec4 f4 = texelFetch(iChannel15, ivec2(4, 0), 0);
    int act = f4.z > 0. ? int(f0.x) : -1;
    vec4 f2 = texelFetch(iChannel15, ivec2(2, 0), 0);
    vec4 bb = texelFetch(iChannel15, ivec2(1, 0), 0);
    vec2 lab = abs(q - vec2(f0.z, bb.y - 0.045)) - vec2((0.5 * f2.z + 0.5) * SKY_TEXT_H, SKY_TEXT_H);
    bool nearFig = act >= 0 && ((all(greaterThan(q, bb.xy - 0.08)) && all(lessThan(q, bb.zw + 0.08))) || max(lab.x, lab.y) < 0.);

    vec3 col = mix(SKY_HORIZON, SKY_ZENITH, smoothstep(0., 0.7, rl.z));
    float raz = atan(rl.x, rl.y);
    float ridge = 0.012 + 0.025 * skyNoise(raz * 7.) + 0.01 * skyNoise(raz * 31.);
    float ground = smoothstep(0.0015, -0.0015, rl.z - ridge);

    if(ground < 1.){
        vec3 d = H * rl;
        col += skyMilkyWay(d) + skyDeep(d, q, act);
        float pxa = 1. / (SKY_FOCAL * iResolution.y);
        col += SKY_GOLD * SKY_CIRCLE * smoothstep(1.5 * pxa, 0.5 * pxa, abs(dot(d, SKY_ECLIPTIC)));
        col += SKY_TEAL * SKY_CIRCLE * smoothstep(1.5 * pxa, 0.5 * pxa, abs(d.z));
        col += SKY_TEAL * 0.5 * smoothstep(1.5 * pxa, 0.5 * pxa, abs(acos(clamp(d.z, -1., 1.)) - 0.014));

        float ra = mod(atan(d.y, d.x), 6.2831853);
        float dec = asin(clamp(d.z, -1., 1.));
        int rb = min(int(ra / 6.2831853 * float(SKY_CELLS_RA)), SKY_CELLS_RA - 1);
        int db = clamp(int((dec / 3.1415927 + 0.5) * float(SKY_CELLS_DEC)), 0, SKY_CELLS_DEC - 1);
        vec3 cl = skyRGB(32 * 1024 + db * SKY_CELLS_RA + rb);
        int first = int(cl.x * 256. + cl.y), count = int(cl.z);
        float cm = cos(SKY_MARGIN);
        int sn = nearFig ? int(f2.x) : 0;
        float dl = 1e9, dpt = 1e9, along = 0.;
        vec2 fsp = vec2(1e4), mb = vec2(0.);
        for(int i = 0; i < SKY_SEGS; i++){
            if(i >= sn) break;
            float r = skyReveal(f4.y, i, sn);
            if(r <= 0.) continue;
            vec4 sg = texelFetch(iChannel15, ivec2(SKY_FIG_SEG + i, 0), 0);
            vec2 e = mix(sg.xy, sg.zw, r), ab = e - sg.xy;
            float hh = clamp(dot(q - sg.xy, ab) / max(dot(ab, ab), 1e-8), 0., 1.);
            float dd = length(q - sg.xy - ab * hh);
            if(dd < dl){ dl = dd; along = hh * length(ab); }
            float da = length(q - sg.xy), db = r >= 1. ? length(q - sg.zw) : 1e9;
            if(min(da, db) < dpt){
                vec4 st = texelFetch(iChannel15, ivec2(SKY_FIG_STAR + i, 0), 0);
                dpt = min(da, db);
                fsp = da < db ? sg.xy : sg.zw;
                mb = da < db ? st.xy : st.zw;
            }
        }
        for(int i = 0; i < 64; i++){
            if(i >= count) break;
            int r = 3 * (first + i);
            vec3 s = skyVec(r);
            if(dot(d, s) < cm) continue;
            vec3 m = skyRGB(r + 2);
            float mag = m.x / 255. * 8. - 2., bv = m.y / 255. * 2.4 - 0.4;
            if(dot(s, SKY_ALGOL) > 0.99999) mag = u_algol;
            float z;
            vec2 sp = skyProject(s, H, fw, rt, up, z);
            if(z <= 0. || length(sp - fsp) < 0.003) continue;
            float b = clamp((5. - mag) / 6.5, 0., 1.);
            float lit = nearFig ? skyLit(sp, f0, f2, f4) : 0.;
            float h0 = mix(SKY_SIZE.x, SKY_SIZE.y, b * b);
            float h = mix(h0, max(min(h0 * (1. + SKY_GROW), SKY_GROW_MAX), h0), lit);
            float rr = length(q - sp);
            float hs = random(vec2(float(first + i), 4.2) + s.xy);
            vec3 tint = mix(vec3(0.72, 0.84, 1.), vec3(1., 0.84, 0.62), clamp(bv / 1.6, 0., 1.));
            float tw = 1. + 0.3 * (1. - b) * (1. - lit) * sin(iTime * (2. + 6. * hs) + hs * 40.);
            col += tint * b * b * 0.15 * exp(-rr / (h * 0.7));
            col += tint * lit * 0.4 * exp(-rr * rr / (h * h * 0.2));
            if(rr < h){
                float cov = S(glyphDist((q - sp) / h) * h);
                col = mix(col, tint * mix(mix(SKY_BRIGHT.x, SKY_BRIGHT.y, b), 1.3, lit) * tw, cov);
            }
        }

        for(int i = 0; i < 4; i++){
            vec4 pl = u_planets[i];
            if(dot(pl.xyz, pl.xyz) < 0.5) continue;
            float z;
            vec2 sp = skyProject(pl.xyz, H, fw, rt, up, z);
            if(z <= 0.) continue;
            float b = clamp((2. - pl.w) / 6.5, 0.3, 1.);
            float lit = act == SKY_PLANET_FIRST + i ? cubicInOut(f4.y) * f4.z : 0.;
            float h = SKY_SIZE.y * mix(1., 1.4, b) * (1. + SKY_GROW * lit);
            float rr = length(q - sp);
            col += SKY_PLANET_COL[i] * (0.25 * b * exp(-rr / (h * 0.8)) + 0.5 * lit * exp(-rr * rr / (h * h * 0.2)));
            if(rr < h) col = mix(col, SKY_PLANET_COL[i] * 1.2, S(glyphDist((q - sp) / h) * h));
        }

        vec4 mo = u_bodies[0];
        if(dot(mo.xyz, mo.xyz) > 0.5){
            float z;
            vec2 sp = skyProject(mo.xyz, H, fw, rt, up, z);
            if(z > 0.){
                float rr = length(q - sp);
                col += vec3(0.55, 0.6, 0.7) * 0.2 * mo.w * exp(-rr / 0.12);
                if(rr < SKY_MOON_R * 1.1){
                    vec2 dk = (q - sp) / SKY_MOON_R;
                    vec3 sl = u_bodies[1].xyz * H, ml = mo.xyz * H;
                    vec3 sc = normalize(vec3(dot(sl, rt), dot(sl, up), -dot(sl, ml)));
                    vec3 n = vec3(dk, sqrt(max(1. - dot(dk, dk), 0.)));
                    float alb = 0.75 + 0.25 * texture(iChannel1, fract(dk * 0.35 + 0.5)).r - 0.18 * smoothstep(0.55, 0.75, texture(iChannel1, fract(dk * 0.12 + 0.23)).r);
                    vec3 mc = mix(SKY_MOON_DARK, SKY_MOON_LIT * alb, smoothstep(-0.03, 0.05, dot(n, sc)));
                    col = mix(col, mc, S(rr - SKY_MOON_R));
                }
            }
        }
        if(u_bodies[2].w > 0.){
            vec3 vel;
            vec3 id = skyIss(vel);
            float z, zp;
            vec2 sp = skyProject(id, H, fw, rt, up, z);
            vec2 pp = skyProject(normalize(id - vel * SKY_ISS_TRAIL), H, fw, rt, up, zp);
            if(z > 0. && zp > 0.){
                bool lit = u_bodies[2].w > 1.5;
                vec3 ic = lit ? vec3(1.) : vec3(0.55, 0.3, 0.25);
                vec2 ab = sp - pp;
                float u = clamp(dot(q - pp, ab) / max(dot(ab, ab), 1e-8), 0., 1.);
                float dt = length(q - pp - ab * u);
                col += ic * 0.5 * u * (S(dt - 0.0005) + 0.3 * exp(-dt / 0.003));
                col += ic * 0.25 * exp(-length(q - sp) / 0.015);
                vec2 uv = vec2(q.x - sp.x, sp.y - q.y) / SKY_ISS_H + 0.5;
                if(all(greaterThanEqual(uv, vec2(0.))) && all(lessThanEqual(uv, vec2(1.)))){
                    vec4 e = skyEmoji(uv);
                    col = col * (1. - e.a) + e.rgb * (lit ? 1. : 0.45) * (lit ? vec3(1.) : vec3(1., 0.7, 0.65));
                }
            }
        }

        float mk = floor(iTime / SKY_METEOR.x);
        float mt = iTime - mk * SKY_METEOR.x - random(vec2(mk, 5.5)) * (SKY_METEOR.x - SKY_METEOR_T);
        if(random(vec2(mk, 6.6)) < SKY_METEOR.y && mt > 0. && mt < SKY_METEOR_T){
            float th = mt * 0.7;
            vec3 hd = skyTrack(mk, th), tl = skyTrack(mk, max(th - 0.12 * min(mt * 4., 1.), 0.));
            float za, zb;
            vec2 pa = skyScreen(hd, fw, rt, up, za), pb = skyScreen(tl, fw, rt, up, zb);
            if(za > 0.1 && zb > 0.1){
                vec2 ab = pa - pb;
                float u = clamp(dot(q - pb, ab) / max(dot(ab, ab), 1e-8), 0., 1.);
                float dm = length(q - pb - ab * u);
                col += vec3(0.85, 0.93, 1.) * u * u * (1. - mt / SKY_METEOR_T) * (S(dm - 0.0006) + 0.4 * exp(-dm / 0.003));
            }
        }
        float sk = floor(iTime / SKY_SAT.x), st = iTime - sk * SKY_SAT.x;
        if(random(vec2(sk, 7.7)) < SKY_SAT.y && st < SKY_SAT_T){
            float z;
            vec2 sp = skyScreen(skyTrack(sk + 100., (st - SKY_SAT_T * 0.5) * 0.035), fw, rt, up, z);
            if(z > 0.1) col += vec3(0.9) * smoothstep(1., 0.4, st / SKY_SAT_T) * smoothstep(0., 2., st) * exp(-length(q - sp) / 0.0015);
        }

        if(nearFig){
            vec3 ink = f2.w == 1. ? SKY_GOLD : f2.w == 5. ? SKY_GUIDE : SKY_TEAL;
            float env = f0.y;
            if(sn > 0){
                float dash = f2.w == 5. ? step(0.45, fract(along / SKY_DASH)) : 1.;
                col += ink * f4.z * dash * (0.85 * S(dl - 0.0007) + 0.15 * exp(-dl / 0.004)) * smoothstep(0.012, 0.022, dpt);
                float mag = mb.x * 8. - 2., bv = mb.y * 2.4 - 0.4;
                float b = clamp((5. - mag) / 6.5, 0., 1.);
                float h0 = mix(SKY_SIZE.x, SKY_SIZE.y, b * b);
                float h = mix(h0, max(min(h0 * (1. + SKY_GROW), SKY_GROW_MAX), h0), f4.z);
                vec3 tint = mix(vec3(0.72, 0.84, 1.), vec3(1., 0.84, 0.62), clamp(bv / 1.6, 0., 1.));
                col += tint * f4.z * 0.4 * exp(-dpt * dpt / (h * h * 0.2));
                if(dpt < h) col = mix(col, tint * mix(mix(SKY_BRIGHT.x, SKY_BRIGHT.y, b), 1.3, f4.z), S(glyphDist((q - fsp) / h) * h));
            } else {
                float dr = abs(length(q - f0.zw) - f4.x * cubicInOut(f4.y));
                col += ink * f4.z * step(0.001, f4.y) * (0.8 * S(dr - 0.0006) + 0.15 * exp(-dr / 0.003));
            }

            int rec = skyRec(act);
            int nl = int(f2.y);
            float w = f2.z;
            vec2 tq = (q - vec2(f0.z, bb.y - 0.045)) / SKY_TEXT_H;
            if(abs(tq.y) < 0.5 && abs(tq.x) < 0.5 * w + 0.5){
                float x = -0.5 * w, dt = 1e9;
                for(int i = 0; i < SKY_NAME; i++){
                    if(i >= nl) break;
                    vec3 ch = skyRGB(rec + 4 + i);
                    float adv = ch.y / 255.;
                    float cx = x + 0.5 * adv;
                    if(ch.x < 255. && abs(tq.x - cx) < 0.4) dt = min(dt, flapGlyph(int(ch.x), vec2(tq.x - cx, tq.y)));
                    x += adv;
                }
                col = mix(col, ink, S(dt * SKY_TEXT_H) * env);
            }
        }
    }
    vec3 over;
    col += skyGizmo(q, rl, fw, rt, up, over);
    col = mix(col, SKY_GROUND, ground) + over;
    return col + bgNoise(tp) * 0.2;
}
