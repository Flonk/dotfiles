const float SHADOW_OUTLET_SCREEN_X = 0.88;
const float SHADOW_OUTLET_Y      = 0.32;
const vec2  SHADOW_OUTLET_SIZE   = vec2(0.6, 0.31);
const float SHADOW_OUTLET_T      = 0.03;
const float SHADOW_OUTLET_SOCKET = 0.095;
const float SHADOW_OUTLET_PLUG   = 0.1;
const vec3  SHADOW_OUTLET_COL    = vec3(0.2, 0.42, 0.46);
const vec3  SHADOW_OUTLET_ACCENT = vec3(0.1, 0.32, 0.35);
const float SHADOW_OUTLET_GLOSS  = 0.25;
const float SHADOW_OUTLET_SCALE  = 0.7;
const float SHADOW_OUTLET_INSERT = 0.12;
const float SHADOW_OUTLET_GROOVE = 0.004;
const float SHADOW_OUTLET_PROUD  = 0.006;
const float SHADOW_OUTLET_INSERT_TINT = 1.1;
const vec3  SHADOW_OUTLET_SS     = vec3(0.07, 0.16, 0.05);
const vec3  SHADOW_CLIP_COL      = vec3(0.4, 0.44, 0.45);
const float SHADOW_CLIP_SHINE    = 0.8;
const float SHADOW_CABLE_R       = 0.011;
const vec2  SHADOW_CABLE_DROP    = vec2(0.06, 0.34);
const float SHADOW_CABLE_LEAD    = 0.2;
const vec2  SHADOW_CABLE_OUT1    = vec2(1.2, 0.78);
const vec2  SHADOW_CABLE_OUT2    = vec2(1.2, 0.92);
const vec3  SHADOW_CABLE_COL     = vec3(0.03, 0.045, 0.05);

vec2 gOutletPos, gOutletQ;
vec2 gCableDir;
vec2 gPath[5];

float cableSdf(vec3 q){
    float S = SHADOW_OUTLET_SCALE;
    vec2 hs = SHADOW_OUTLET_SIZE * 0.5;
    float r = SHADOW_CABLE_R;
    float z0 = SHADOW_OUTLET_T * 0.27 + SHADOW_OUTLET_PLUG;
    float plug = sdRoundBox(q / S - vec3(hs.x * 0.5, -0.005, z0 + 0.0175), vec3(0.026, 0.01, 0.0175), 0.004) * S;
    vec3 p0 = vec3(hs.x * 0.5, -0.005, z0 + 0.035) * S;
    vec3 p3 = vec3(p0.x + SHADOW_CABLE_DROP.x, -gOutletPos.y + r, SHADOW_CABLE_DROP.y);
    vec3 df = vec3(gCableDir.x, 0., gCableDir.y);
    vec3 c1 = p0 + vec3(0., 0., 0.12);
    vec3 c2 = p3 - df * 0.18 + vec3(0., 0.02, 0.);
    float d = 1e9;
    vec3 prev = p0;
    for(int i = 1; i <= 10; i++){
        vec3 cur = bez3(p0, c1, c2, p3, float(i) / 10.);
        d = min(d, sdSegment(q, prev, cur));
        prev = cur;
    }
    return min(plug, d - r);
}

float outletSdf(vec3 q, out float mat){
    float S = SHADOW_OUTLET_SCALE;
    vec3 qs = q / S;
    vec2 hs = SHADOW_OUTLET_SIZE * 0.5;
    float th = SHADOW_OUTLET_T;
    float plate = sdExtrude(sdRoundBox(qs.xy, hs, 0.035), qs.z - th * 0.5, th * 0.5, 0.006);
    float insert = 1e9, clips = 1e9;
    float ih = SHADOW_OUTLET_INSERT;
    float itop = th + SHADOW_OUTLET_PROUD;
    for(int i = 0; i < 2; i++){
        vec2 c = vec2(i == 0 ? -hs.x * 0.5 : hs.x * 0.5, 0.);
        float hole = sdRoundBox(qs.xy - c, vec2(ih + SHADOW_OUTLET_GROOVE), 0.02);
        plate = max(plate, -max(hole, th * 0.15 - qs.z));
        float ins = sdExtrude(sdRoundBox(qs.xy - c, vec2(ih), 0.018), qs.z - itop * 0.5, itop * 0.5, 0.007);
        float cyl = length(qs.xy - c) - SHADOW_OUTLET_SOCKET;
        ins = max(ins, -max(cyl, th * 0.27 - qs.z));
        insert = min(insert, ins);
        vec3 kq = vec3(qs.x - c.x, abs(qs.y) - SHADOW_OUTLET_SOCKET + 0.004, qs.z - th * 0.6);
        clips = min(clips, sdRoundBox(kq, vec3(0.017, 0.006, th * 0.32), 0.002));
    }
    float charger = sdRoundBox(qs - vec3(hs.x * 0.5, 0., th * 0.27 + SHADOW_OUTLET_PLUG * 0.5), vec3(0.068, 0.068, SHADOW_OUTLET_PLUG * 0.5), 0.018);
    plate *= S;
    insert *= S;
    clips *= S;
    charger *= S;
    float cable = cableSdf(q);
    float d = min(min(min(plate, insert), charger), min(cable, clips));
    mat = d == cable ? 2. : d == charger ? 1. : d == clips ? 3. : d == insert ? 4. : 0.;
    return d;
}

float outletDist(vec3 q){
    float m;
    return outletSdf(q, m);
}

vec3 outletLocal(vec3 p){
    return vec3(p.x - gOutletPos.x, p.y - gOutletPos.y, SHADOW_WALL_Z - p.z);
}

float outletMarch(vec3 ro, vec3 rd, float tmax){
    vec3 lo = outletLocal(ro), ld = vec3(rd.x, rd.y, -rd.z);
    vec3 bmin = vec3(-SHADOW_OUTLET_SIZE.x * 0.5 * SHADOW_OUTLET_SCALE - 0.01, -gOutletPos.y - 0.01, -0.01);
    vec3 bmax = vec3(SHADOW_OUTLET_SIZE.x * 0.5 * SHADOW_OUTLET_SCALE + SHADOW_CABLE_DROP.x + 0.1, SHADOW_OUTLET_SIZE.y * 0.5 * SHADOW_OUTLET_SCALE + 0.01, max(SHADOW_CABLE_DROP.y, SHADOW_OUTLET_T + SHADOW_OUTLET_PLUG + 0.2) + 0.05);
    vec2 h = boxHit(lo, ld, bmin, bmax);
    float tF = min(h.y, tmax);
    if(h.x > tF || tF < 0.) return -1.;
    float t = max(h.x, 0.);
    for(int i = 0; i < 64; i++){
        float d = outletDist(lo + ld * t);
        if(d < 0.0002) return t;
        t += d;
        if(t > tF) break;
    }
    return -1.;
}

vec3 outletAlbedo(vec3 qw, int id, out float emit){
    vec3 q = qw / SHADOW_OUTLET_SCALE;
    vec2 hs = SHADOW_OUTLET_SIZE * 0.5;
    float floorZ = SHADOW_OUTLET_T * 0.27 + 0.002;
    float px = gPx / SHADOW_OUTLET_SCALE + 1e-5;
    emit = 0.;
    if(id == ID_CABLE) return SHADOW_CABLE_COL;
    if(id == ID_CLIP) return SHADOW_CLIP_COL;
    if(id == ID_CHARGER){
        vec2 c = vec2(hs.x * 0.5, -0.005);
        if(q.z < SHADOW_OUTLET_T * 0.27 + SHADOW_OUTLET_PLUG - 0.004) return SHADOW_OUTLET_COL * 0.95;
        vec2 d = abs(q.xy - c);
        float port = 1. - smoothstep(-px, px, max(d.x - 0.03, d.y - 0.011));
        float tongue = 1. - smoothstep(-px, px, max(d.x - 0.024, d.y - 0.004));
        emit = 1. - smoothstep(-px, px, length(q.xy - vec2(c.x, 0.044)) - 0.006);
        return mix(mix(SHADOW_OUTLET_COL * 0.95, vec3(0.02), port), SHADOW_OUTLET_ACCENT, tongue);
    }
    if(id == ID_FRAME) return SHADOW_OUTLET_COL;
    vec3 col = SHADOW_OUTLET_COL * SHADOW_OUTLET_INSERT_TINT;
    vec2 c = vec2(-hs.x * 0.5, 0.);
    vec2 r = q.xy - c;
    if(q.z < floorZ && length(r) < SHADOW_OUTLET_SOCKET){
        col *= 0.7;
        float holes = min(length(r - vec2(0.046, 0.)), length(r + vec2(0.046, 0.))) - 0.011;
        col = mix(col, vec3(0.03), 1. - smoothstep(-px, px, holes));
    }
    return col;
}

vec3 cableFloor(vec2 p){
    float best = 1e9;
    vec2 perp = vec2(0.);
    for(int s = 0; s < 4; s++){
        vec2 a = s == 0 ? 2. * gPath[0] - gPath[1] : gPath[s - 1];
        vec2 b = gPath[s], c = gPath[s + 1];
        vec2 d = s == 3 ? 2. * gPath[4] - gPath[3] : gPath[s + 2];
        vec2 prev = b;
        for(int i = 1; i <= 6; i++){
            vec2 cur = catmull(a, b, c, d, float(i) / 6.);
            vec2 pa = p - prev, ba = cur - prev;
            vec2 h = pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0., 1.);
            float l = length(h);
            if(l < best){ best = l; perp = h / max(l, 1e-6); }
            prev = cur;
        }
    }
    return vec3(best, perp);
}

void placeOutlet(){
    float qx = (SHADOW_OUTLET_SCREEN_X - 0.5) * iResolution.x / iResolution.y;
    float qy = 0.;
    vec3 hit;
    for(int i = 0; i < 4; i++){
        vec3 d0 = camRay(vec2(qx, qy));
        vec3 d1 = camRay(vec2(qx, qy + 0.01));
        vec3 h0 = gRo + d0 * (SHADOW_WALL_Z - gRo.z) / d0.z;
        vec3 h1 = gRo + d1 * (SHADOW_WALL_Z - gRo.z) / d1.z;
        qy += (SHADOW_OUTLET_Y - h0.y) * 0.01 / (h1.y - h0.y);
        hit = h0;
    }
    gOutletPos = vec2(hit.x, SHADOW_OUTLET_Y);
    gOutletQ = vec2(qx, qy);
}

bool outletSS(vec2 q){
    vec2 dq = q - gOutletQ;
    return abs(dq.x) < SHADOW_OUTLET_SS.x && dq.y > -SHADOW_OUTLET_SS.y && dq.y < SHADOW_OUTLET_SS.z;
}
