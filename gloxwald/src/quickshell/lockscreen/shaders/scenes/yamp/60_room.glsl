const vec3  SHADOW_CAM    = vec3(0., 1.2, -3.5);
const vec3  SHADOW_TARGET = vec3(0., 0.5, 1.5);
const float SHADOW_FOCAL  = 1.6;
const float SHADOW_WALL_Z = 2.;
const float SHADOW_YAW    = -0.45;
const vec3  SHADOW_AMP_POS = vec3(1.77, 0.5, -3.66);
const vec3  SHADOW_LIGHT  = vec3(4.38, 0.6, -9.06);
const float SHADOW_LIGHT_RANGE = 14.;
const float SHADOW_GAIN   = 2.2;
const float SHADOW_FACE   = -0.45;
const float SHADOW_RIG_YAW = 0.28;
const float SHADOW_SWAY   = 0.25;
const float SHADOW_SWAY_RATE = 0.15;
const float SHADOW_K      = 256.;
const int   SHADOW_STEPS  = 96;
const vec3  SHADOW_WALL   = vec3(0.13, 0.42, 0.47);
const float SHADOW_WALL_GRAIN = 0.012;
const float SHADOW_WALL_BUMP  = 0.6;
const float SHADOW_WALL_TONE  = 0.05;
const vec3  SHADOW_FLOOR  = vec3(0.08, 0.26, 0.30);
const float SHADOW_AMB    = 0.06;
const float SHADOW_CORNER = 0.55;
const float SHADOW_FLOOR_GAIN = 3.;
const float SHADOW_PLANK_W = 0.14;
const float SHADOW_PLANK_L = 1.;
const float SHADOW_PLANK_GAP = 0.006;
const float SHADOW_PLANK_VAR = 0.15;
const float SHADOW_PLANK_DARK = 0.3;
const float SHADOW_SKIRT_H = 0.08;
const float SHADOW_SKIRT_D = 0.022;
const float SHADOW_SKIRT_BEAD = 0.55;
const vec3  SHADOW_SKIRT  = vec3(0.22, 0.48, 0.52);
const vec2  SHADOW_SKIRT_SS = vec2(0.05, 0.04);
const float SHADOW_SIDE_X    = -2.12;
const float SHADOW_COUCH_FWD  = 3.8;
const float SHADOW_COUCH_LEFT = 0.65;
const float SHADOW_COUCH_W    = 1.6;
const float SHADOW_COUCH_L    = 1.8;
const float SHADOW_COUCH_TOP  = 1.7;
const float SHADOW_COUCH_LEG  = 0.35;
const vec3  SHADOW_COUCH      = vec3(0.13, 0.21, 0.24);
const float SHADOW_LEG_TOP    = 0.085;
const float SHADOW_LEG_TOE    = 0.04;
const float SHADOW_LEG_SPLAY  = 0.05;
const float SHADOW_LEG_FERRULE = 0.05;
const vec3  SHADOW_WOOD       = vec3(0.03, 0.042, 0.046);
const float SHADOW_WOOD_SHEEN = 0.25;
const vec3  SHADOW_BRASS      = vec3(0.025, 0.032, 0.035);
const float SHADOW_BRASS_SHINE = 0.35;
const float SHADOW_COUCH_AMB  = 0.45;
const float SHADOW_COUCH_UNDER = 0.4;
const float SHADOW_COUCH_SPREAD = 0.3;
const float SHADOW_FELT_SCALE  = 0.04;
const float SHADOW_FELT_FINE   = 0.8;
const float SHADOW_FELT_MOTTLE = 0.08;
const float SHADOW_FELT_GRAIN  = 0.1;
const float SHADOW_FELT_SHEEN  = 0.06;
const float SHADOW_FELT_STONE  = 0.3;
const float SHADOW_FELT_STONE_SCALE = 0.05;

const int ID_NONE    = -1;
const int ID_FLOOR   = 0;
const int ID_WALL    = 1;
const int ID_SIDE    = 2;
const int ID_SKIRT   = 3;
const int ID_FELT    = 4;
const int ID_LEG     = 5;
const int ID_CAP     = 6;
const int ID_FRAME   = 7;
const int ID_CHARGER = 8;
const int ID_CABLE   = 9;
const int ID_CLIP    = 10;
const int ID_INSERT  = 11;
const int ID_PHONE   = 12;
const int ID_SCREEN  = 13;

bool isWall(int id){ return id == ID_WALL || id == ID_SIDE; }
bool isHocker(int id){ return id >= ID_FELT && id <= ID_CAP; }
bool isOutlet(int id){ return id >= ID_FRAME && id <= ID_INSERT; }

float gPx = 0.001;
vec3 gRo, gF, gR, gU;
mat3 gYaw;
vec3 gCo, gCright, gCfwd, gLight, gAmpPos;
mat3 gAmpMi;

vec3 camRay(vec2 q){
    return gYaw * normalize(gF * SHADOW_FOCAL + gR * q.x + gU * q.y);
}

vec2 floorAt(vec2 frac){
    vec3 rd = camRay(vec2((frac.x - 0.5) * iResolution.x / iResolution.y, 0.5 - frac.y));
    return (gRo + rd * (-gRo.y / min(rd.y, -1e-3))).xz;
}

vec3 toHocker(vec3 v){ return vec3(dot(v, gCright), v.y, dot(v, gCfwd)); }
vec3 fromHocker(vec3 v){ return v.x * gCright + vec3(0., v.y, 0.) + v.z * gCfwd; }

float floorBoards(vec2 xz){
    float u = xz.x / SHADOW_PLANK_W;
    float ix = floor(u);
    float v = (xz.y + random(vec2(ix, 1.7)) * SHADOW_PLANK_L) / SHADOW_PLANK_L;
    float iz = floor(v);
    vec2 e = vec2(min(fract(u), 1. - fract(u)) * SHADOW_PLANK_W,
                  min(fract(v), 1. - fract(v)) * SHADOW_PLANK_L);
    vec2 fw = vec2(gPx) + 1e-5;
    float gap = smoothstep(0., 1.5, min(e.x / fw.x, e.y / fw.y) * 0.5)
              * smoothstep(0., SHADOW_PLANK_GAP, min(e.x, e.y));
    float tone = mix(1. - SHADOW_PLANK_VAR, 1. + SHADOW_PLANK_VAR, random(vec2(ix, iz)));
    float grain = texture(iChannel2, vec2(xz.x * 0.7 + ix * 0.37, xz.y * 0.06 + iz * 0.21)).r;
    return tone * mix(0.65, 1.25, grain) * mix(SHADOW_PLANK_DARK, 1., gap);
}

float raufaser(vec2 w){
    vec2 u = w / (SHADOW_WALL_GRAIN * 512.);
    float h = texture(iChannel1, fract(u)).r * 0.6 + texture(iChannel1, fract(u * 2.3 + 0.37)).r * 0.4;
    return h * h;
}

float skirtProfile(vec2 p){
    float D = SHADOW_SKIRT_D, H = SHADOW_SKIRT_H;
    float R = D * SHADOW_SKIRT_BEAD;
    float hb = H - R;
    float board = sdBox(p - vec2(D * 0.5, hb * 0.5), vec2(D * 0.5, hb * 0.5));
    float bead = length(p - vec2(D * 0.55, hb)) - R;
    float k = R * 0.8;
    float h = clamp(0.5 + 0.5 * (bead - board) / k, 0., 1.);
    return mix(bead, board, h) - k * h * (1. - h);
}

float skirtUnion(vec3 p){
    return min(skirtProfile(vec2(SHADOW_WALL_Z - p.z, p.y)), skirtProfile(vec2(p.x - SHADOW_SIDE_X, p.y)));
}

vec3 couchTop(int i){
    return vec3(i < 2 ? -0.17 : -SHADOW_COUCH_W + 0.17, SHADOW_COUCH_LEG + 0.02, i % 2 == 0 ? 0.2 : SHADOW_COUCH_L - 0.2);
}

vec3 couchFoot(int i){
    vec3 h = couchTop(i);
    return vec3(h.x + (i < 2 ? SHADOW_LEG_SPLAY : -SHADOW_LEG_SPLAY), SHADOW_LEG_TOE, h.z + (i % 2 == 0 ? -SHADOW_LEG_SPLAY : SHADOW_LEG_SPLAY));
}

float couchSdf(vec3 p, out float foot){
    vec3 b = vec3(SHADOW_COUCH_W, SHADOW_COUCH_TOP - SHADOW_COUCH_LEG, SHADOW_COUCH_L) * 0.5;
    float body = sdRoundBox(p - vec3(-b.x, SHADOW_COUCH_LEG + b.y, b.z), b, 0.08);
    float leg = 1e9, mat = 1.;
    for(int i = 0; i < 4; i++){
        vec3 lo = couchFoot(i);
        vec3 hi = couchTop(i);
        float d = sdRoundCone(p, lo, hi, SHADOW_LEG_TOE, SHADOW_LEG_TOP);
        float plate = sdBox(p - vec3(hi.x, SHADOW_COUCH_LEG, hi.z), vec3(0.07, 0.012, 0.07));
        if(d < leg){
            leg = d;
            mat = (p.y - lo.y + SHADOW_LEG_TOE) < SHADOW_LEG_FERRULE ? 2. : 1.;
        }
        if(plate < leg){ leg = plate; mat = 1.; }
    }
    foot = leg < body ? mat : 0.;
    return min(body, leg);
}

float couchDist(vec3 p){
    float f;
    return couchSdf(p, f);
}

float couchShadow(vec3 ro, vec3 rd, float tmax){
    vec2 h = boxHit(ro, rd, vec3(-SHADOW_COUCH_W - 0.1, 0., -0.2), vec3(0.15, SHADOW_COUCH_TOP + 0.1, SHADOW_COUCH_L + 0.2));
    float tF = min(h.y, tmax);
    if(h.x > tF || tF < 0.) return 1.;
    float res = 1., t = max(h.x, 0.01);
    for(int i = 0; i < 64; i++){
        float d = couchDist(ro + rd * t);
        if(d < 0.001) return 0.;
        res = min(res, SHADOW_K * 0.25 * d / t);
        t += clamp(d, 0.01, 0.4);
        if(t > tF) break;
    }
    return clamp(res, 0., 1.);
}

float couchMarch(vec3 ro, vec3 rd, float tmax){
    float t = 0.;
    for(int i = 0; i < 80; i++){
        float d = couchDist(ro + rd * t);
        if(d < 0.0005 * (1. + t)) return t < tmax ? t : -1.;
        t += d;
        if(t > tmax) break;
    }
    return -1.;
}

float felt(vec3 p, vec3 n){
    vec3 w = pow(abs(n), vec3(4.));
    w /= w.x + w.y + w.z;
    vec3 s = p * SHADOW_FELT_SCALE;
    float m = 0.;
    for(int i = 0; i < 2; i++){
        vec3 o = s * (i == 0 ? 1. : 2.3);
        m += (texture(iChannel1, fract(o.yz)).r * w.x + texture(iChannel1, fract(o.xz)).r * w.y + texture(iChannel1, fract(o.xy)).r * w.z) * 0.5;
    }
    vec3 f = p * SHADOW_FELT_FINE;
    float g = texture(iChannel1, fract(f.yz)).r * w.x + texture(iChannel1, fract(f.xz)).r * w.y + texture(iChannel1, fract(f.xy)).r * w.z;
    vec3 z = p * SHADOW_FELT_STONE_SCALE;
    float st = texture(iChannel2, z.yz).r * w.x + texture(iChannel2, z.xz).r * w.y + texture(iChannel2, z.xy).r * w.z;
    return mix(1. - SHADOW_FELT_MOTTLE, 1. + SHADOW_FELT_MOTTLE, m) * mix(1. - SHADOW_FELT_GRAIN, 1. + SHADOW_FELT_GRAIN, g)
         * mix(1., st, SHADOW_FELT_STONE);
}
