const int   AG_W      = 1024;
const float AG_CELL   = 1. / 40.;
const int   AG_GY     = 40;
const int   AG_GX     = 108;
const int   AG_TEX    = 8;
const int   AG_SLOTS  = 4 * AG_TEX;
const int   AG_BIN0   = 2;
const int   AG_FIELD0 = AG_BIN0 + AG_GY;
const int   AG_FW     = 160;
const int   AG_FH     = 90;
const int   AG_H      = AG_FIELD0 + AG_FH;
const ivec2 AG_META   = ivec2(AG_W - 1, 1);
const float AG_GAP    = 1.;

vec4 agGet(sampler2D ch, int i, int row){ return texelFetch(ch, ivec2(i, row), 0); }

float agDt(sampler2D ch, out bool fresh){
    float last = texelFetch(ch, AG_META, 0).x;
    fresh = last <= 0. || iTime < last || iTime - last > AG_GAP;
    return fresh ? 0. : min(iTime - last, 0.05);
}

ivec2 agCellOf(vec2 q, float asp){ return ivec2(floor((q + vec2(0.5 * asp, 0.5)) / AG_CELL)); }

vec4 agBin(sampler2D ch, int bx, int by, int n, float reach, float asp){
    int cx = bx / AG_TEX, skip = (bx % AG_TEX) * 4;
    if(cx >= AG_GX || by >= AG_GY) return vec4(0.);
    vec2 lo = vec2(float(cx), float(by)) * AG_CELL - vec2(0.5 * asp, 0.5) - reach;
    vec2 hi = lo + AG_CELL + 2. * reach;
    vec4 o = vec4(0.);
    int c = 0;
    for(int j = 0; j < AG_W; j++){
        if(j >= n) break;
        vec2 p = agGet(ch, j, 0).xy;
        if(any(lessThan(p, lo)) || any(greaterThan(p, hi))) continue;
        if(c >= skip && c < skip + 4) o[c - skip] = float(j + 1);
        c++;
        if(c >= skip + 4) break;
    }
    return o;
}

void agSlots(sampler2D ch, vec2 q, float asp, out vec4 s[AG_TEX]){
    ivec2 c = agCellOf(q, asp);
    bool out_ = c.x < 0 || c.y < 0 || c.x >= AG_GX || c.y >= AG_GY;
    for(int k = 0; k < AG_TEX; k++){
        s[k] = out_ ? vec4(0.) : texelFetch(ch, ivec2(AG_TEX * c.x + k, AG_BIN0 + c.y), 0);
        out_ = out_ || s[k].w == 0.;
    }
}

vec4 agField(sampler2D ch, vec2 q, float asp){
    vec2 f = (q / vec2(asp, 1.) + 0.5) * vec2(AG_FW, AG_FH) - 0.5;
    ivec2 i = ivec2(floor(f));
    vec2 w = fract(f);
    ivec2 m = ivec2(AG_FW - 1, AG_FH - 1);
    vec4 a = texelFetch(ch, ivec2(clamp(i, ivec2(0), m)) + ivec2(0, AG_FIELD0), 0);
    vec4 b = texelFetch(ch, ivec2(clamp(i + ivec2(1, 0), ivec2(0), m)) + ivec2(0, AG_FIELD0), 0);
    vec4 c = texelFetch(ch, ivec2(clamp(i + ivec2(0, 1), ivec2(0), m)) + ivec2(0, AG_FIELD0), 0);
    vec4 d = texelFetch(ch, ivec2(clamp(i + ivec2(1, 1), ivec2(0), m)) + ivec2(0, AG_FIELD0), 0);
    return mix(mix(a, b, w.x), mix(c, d, w.x), w.y);
}

vec2 agFieldPos(int x, int y, float asp){ return ((vec2(x, y) + 0.5) / vec2(AG_FW, AG_FH) - 0.5) * vec2(asp, 1.); }

float agAmp(vec2 q, vec2 pos, vec2 up, float size){
    vec2 d = q - pos;
    if(dot(d, d) > size * size) return size;
    vec2 g = vec2(dot(d, vec2(up.y, -up.x)), dot(d, up)) / size;
    return glyphDist(g) * size;
}

vec2 agRand2(float i, float k){ return vec2(random(vec2(i, k)), random(vec2(k + 3.1, i * 1.7))); }

vec2 agLimit(vec2 v, float lo, float hi){
    float l = length(v);
    return l < 1e-6 ? vec2(lo, 0.) : v / l * clamp(l, lo, hi);
}

vec2 agWalls(vec2 p, float asp, float margin){
    vec2 e = vec2(0.5 * asp, 0.5) - margin;
    return -sign(p) * max(abs(p) - e, 0.) / margin;
}
