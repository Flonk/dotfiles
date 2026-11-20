const vec2  SHADOW_PHONE_SCREEN  = vec2(0.82, 0.74);
const float SHADOW_PHONE_YAW     = 0.7;
const vec3  SHADOW_PHONE_SIZE    = vec3(0.238, 0.493, 0.0255);
const vec3  SHADOW_PHONE_COL     = vec3(0.02, 0.025, 0.03);
const float SHADOW_PHONE_BRIGHT  = 1.6;
const float SHADOW_PHONE_GLOW    = 0.;
const float SHADOW_PHONE_DIGIT   = 0.038;
const float SHADOW_PHONE_TIME_Y  = 0.;

vec3 gPhoneC;
vec2 gPhoneU, gPhoneR;

vec3 phoneHalf(){
    return vec3(SHADOW_PHONE_SIZE.x, SHADOW_PHONE_SIZE.z, SHADOW_PHONE_SIZE.y) * 0.5;
}

vec3 phoneLocal(vec3 p){
    vec2 d = p.xz - gPhoneC.xz;
    return vec3(dot(d, gPhoneR), p.y - SHADOW_PHONE_SIZE.z * 0.5, dot(d, gPhoneU));
}

vec3 phoneLocalDir(vec3 rd){
    return vec3(dot(rd.xz, gPhoneR), rd.y, dot(rd.xz, gPhoneU));
}

vec3 phoneWorldDir(vec3 g){
    return vec3(g.x * gPhoneR.x + g.z * gPhoneU.x, g.y, g.x * gPhoneR.y + g.z * gPhoneU.y);
}

float phoneSdfM(vec3 q, out float mat){
    vec3 b = phoneHalf();
    float body = sdExtrude(sdRoundBox(q.xz, b.xz, 0.04), q.y, b.y, 0.008);
    float r = SHADOW_CABLE_R;
    float plug = sdRoundBox(q - vec3(0., 0., -b.z - 0.018), vec3(0.016, 0.007, 0.02), 0.003);
    vec3 a0 = vec3(0., 0., -b.z - 0.036), a1 = vec3(0., -b.y + r, -b.z - SHADOW_CABLE_LEAD * 0.6);
    vec3 h = a0 + vec3(0., 0., -0.03);
    float stub = min(sdSegment(q, a0, h), sdSegment(q, h, a1)) - r;
    float acc = min(plug, stub);
    mat = acc < body ? 1. : 0.;
    return min(body, acc);
}

float phoneSdf(vec3 q){
    float m;
    return phoneSdfM(q, m);
}

vec2 phoneBoxHit(vec3 ro, vec3 rd, float pad){
    vec3 hb = phoneHalf() + pad;
    vec3 lb = -hb - vec3(0., 0., SHADOW_CABLE_LEAD * 0.6 + 0.05);
    return boxHit(phoneLocal(ro), phoneLocalDir(rd), lb, hb);
}

bool phoneSS(vec3 ro, vec3 rd){
    vec2 h = phoneBoxHit(ro, rd, 0.02);
    return h.x < h.y;
}

float phoneMarch(vec3 ro, vec3 rd, float tmax){
    vec2 h = phoneBoxHit(ro, rd, 0.01);
    float tF = min(h.y, tmax);
    if(h.x > tF || tF < 0.) return -1.;
    vec3 lo = phoneLocal(ro), ld = phoneLocalDir(rd);
    float t = max(h.x, 0.);
    for(int i = 0; i < 40; i++){
        float d = phoneSdf(lo + ld * t);
        if(d < 0.0002) return t;
        t += d;
        if(t > tF) break;
    }
    return -1.;
}

float digitDist(vec2 p, int n){
    int masks[10] = int[10](0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F);
    int m = masks[clamp(n, 0, 9)];
    float w = 0.5, h = 1.;
    vec2 A[7] = vec2[7](vec2(-w, h), vec2(w, h), vec2(w, 0.), vec2(-w, -h), vec2(-w, 0.), vec2(-w, h), vec2(-w, 0.));
    vec2 B[7] = vec2[7](vec2(w, h), vec2(w, 0.), vec2(w, -h), vec2(w, -h), vec2(-w, -h), vec2(-w, 0.), vec2(w, 0.));
    float d = 1e9;
    for(int s = 0; s < 7; s++)
        if(((m >> s) & 1) == 1) d = min(d, sdSegment(p, A[s], B[s]));
    return d - 0.13;
}

vec3 phoneScreen(vec2 s){
    float px = gPx + 1e-5;
    vec4 c = iClock;
    float ch = SHADOW_PHONE_DIGIT;
    vec2 tp = (vec2(-s.y, s.x) - vec2(0., SHADOW_PHONE_TIME_Y)) / ch;
    float d = min(min(digitDist(tp - vec2(-3.3, 0.), int(c.x)), digitDist(tp - vec2(-1.3, 0.), int(c.y))),
                  min(digitDist(tp - vec2(1.3, 0.), int(c.z)), digitDist(tp - vec2(3.3, 0.), int(c.w))));
    d = min(d, min(length(tp - vec2(0., 0.45)), length(tp - vec2(0., -0.45))) - 0.15);
    return GRAD_TOP * (1. - smoothstep(-px, px, d * ch));
}

float phoneGlow(vec3 p){
    vec2 d = p.xz - gPhoneC.xz;
    vec2 pd = abs(vec2(dot(d, gPhoneR), dot(d, gPhoneU))) - SHADOW_PHONE_SIZE.xy * 0.5;
    return exp(-length(max(pd, 0.)) * 12.) * SHADOW_PHONE_GLOW;
}

void placePhone(){
    vec2 c = floorAt(SHADOW_PHONE_SCREEN);
    gPhoneC = vec3(c.x, SHADOW_PHONE_SIZE.z * 0.5, c.y);
    vec2 cfw = gCfwd.xz;
    float pa = SHADOW_PHONE_YAW;
    gPhoneU = vec2(cos(pa) * cfw.x - sin(pa) * cfw.y, sin(pa) * cfw.x + cos(pa) * cfw.y);
    gPhoneR = vec2(gPhoneU.y, -gPhoneU.x);
}
