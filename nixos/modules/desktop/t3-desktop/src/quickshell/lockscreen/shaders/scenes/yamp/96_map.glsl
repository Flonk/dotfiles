// --- map: the traffic scene on real road networks -----------------------------
// The traffic scene drives map u_traffic_map from maps.png in
// iChannel20 (gen_maps.py: OpenStreetMap roads baked into a lane graph; see
// there for the layout, read here as 24-bit words). Cars (bufferTraffic;
// row 0: position, speed, heading; row 1: edge, distance along it, the
// edge after it, time stopped) follow their lane, keep MP_GAP car lengths
// behind the car ahead (on their edge or the next two), slow for the
// curves of the connectors through junctions, and at a give-way connector
// wait at the end of their lane while any car with right of way is inside a
// conflicting connector or about to take one: within MP_LOOK and either
// MP_CLOSE metres or MP_ACCEPT seconds away at its speed (gap acceptance:
// a slow or queued main road still lets the ramp in; a car below MP_CRAWL
// is not coming at all). A car stopped
// (below MP_CRAWL, creeping counts) for MP_PATIENCE stops waiting. At each junction a car picks a random
// turn (the whole simulation runs MP_TIME times real time). Roads are
// drawn layer by layer (OSM layer + MP_GROUND, from the bridge / tunnel
// tags): decks MP_DECK metres up per layer, lighter, with parapets,
// casting shadows along MP_SHADOW on what is under them; cars under a deck
// are hidden, cars on one are a touch bigger (by height: a car hides only
// under a surface well above it, so it never blinks crossing joints).
// Tunnels show faintly. A car that leaves the map waits off it (MP_AWAY)
// for a gate at the edge of the screen to clear and comes in there.
// The map sets how many cars drive (by its lane length); the rest stay
// parked off it.
const int   MP_W        = 1024;
const int   MP_N        = 1023;
const float MP_LABEL    = 0.03;
const float MP_LABEL_PAD = 0.012;
const float MP_LABEL_PX = 64.;
const float MP_LABEL_RANGE = 0.25;
const float MP_SPEEDUP  = 0.7;
const float MP_TIME     = 4.;
const float MP_GAP      = 1.6;
const float MP_LOOK     = 32.;
const float MP_APPROACH = 22.;
const float MP_REACH    = 90.;
const float MP_ACC      = 3.;
const float MP_BRAKE    = 7.;
const float MP_PATIENCE = 8.;
const float MP_COURTESY = 3.;
const float MP_JAMMED = 120.;
const float MP_JUNCTION_PAD = 1.;
const int MP_CONG_ROW = AG_FIELD0;
const int MP_CONG_ROWS = 4;
const float MP_CONG = 0.5;
const float MP_CONG_NEAR = 2.;
const float MP_FULL = 0.05;
const int MP_CAR_ROW = MP_CONG_ROW + MP_CONG_ROWS;
const int MP_GATE_ROW = MP_CAR_ROW + 1;
const int MP_GATE_ROWS = 4;
const int MP_SENSE_ROW = MP_GATE_ROW + MP_GATE_ROWS;
const float MP_ROAM = 45.;
const float MP_ROAM_RAMP = 45.;
const float MP_HOME_M = 40.;
const float MP_COMING = 20.;
const int MP_GATE_STEPS = 48;
const float MP_GATE_BACK = 6.;
const float MP_GATE_GAP = 4.3;
const int MP_SCATTER_EVERY = 32;
const float MP_BIN_MOVE = 12.;
const float MP_LIFT_TOP = 6.;
const float MP_RING_SEE = 6.;
const float MP_RING_FREER = 2.;
const float MP_SHIFT_ROOM = 1.5;
const float MP_SHIFT_CREEP = 6.;
const float MP_HILL_EXAG = 1.5;
const float MP_HILL = 0.35;
const float MP_HILL_LIGHT = 0.08;
const float MP_TERRAIN_EXAG = 1.;
const float MP_TERRAIN_LMAX = 0.6;
const int MP_TERRAIN_STEPS = 96;
const float MP_LIFT_Q = 4000.;
const float MP_SHIFT    = 0.25;
const float MP_STEER    = 9.;
const float MP_TURN_R   = 3.;
const float MP_SEE      = 4.;
const float MP_ACCEPT   = 2.5;
const float MP_CLOSE    = 8.;
const float MP_CRAWL    = 2.;
const float MP_BODY     = 0.55;
const int   MP_MAX_PTS  = 24;
const int   MP_MAX_GIVE = 12;
const float MP_AWAY     = 9.;
const float MP_CAR_DRAW = 0.75;
const int   MP_LAYERS   = 8;
const int   MP_GROUND   = 2;
const vec2  MP_SHADOW   = vec2(0.6, -0.8);
const float MP_DECK     = 5.;
const float MP_SHADE_MIN = 0.3;
const float MP_DASH     = 2.;
const float MP_LINE     = 0.45;
const float MP_OFF      = 0.04;
const float MP_LANE_CHOOSE = 80.;
const float MP_LANE_LOCK = 50.;
const float MP_BLD_VIEW = 0.55;
const float MP_BLD_SUN  = 0.7;
const int   MP_BLD_MAX_V = 20;
const int   MP_BLD_CELL = 48;
const int   MP_BLD_WALL = 8;
const int   MP_GREEN_MAX_V = 48;
const int   MP_GREEN_CELL = 24;
const int   MP_PARK_CELL = 48;
const int   MP_SIG_CELL = 16;
const float MP_SIG_AMBER = 3.;
const float MP_SIG_CLEAR = 2.;
const int   MP_SEG_CELL = 448;
const float MP_PATH_GREY = 0.105;
const float MP_WALL_GREY = 0.155;
const float MP_SNOW_GREY = 0.42;
const float MP_LINE_BAND = 40.;
const float MP_LINE_RAG = 250.;
const float MP_TREE_R = 5.;
const vec3  MP_GREEN_TINT = vec3(0.55, 1.4, 0.75);
const vec3  MP_WATER_TINT = vec3(0.6, 0.85, 1.3);

int mpWord(int i){
    ivec3 c = ivec3(texelFetch(iChannel20, ivec2(i % MP_W, i / MP_W), 0).rgb * 255. + 0.5);
    return c.r << 16 | c.g << 8 | c.b;
}

float mpFx(int i){ return float(mpWord(i)) / 16777216. * 8. - 4.; }

// the map's header, read once per pixel / agent
int gMpBase, gMpLanes, gMpEdge, gMpPts, gMpSucc, gMpGive, gMpEntry, gMpEntries, gMpCars;
float gMpCar, gMpU;

int gMpIdx = 0;

void mpLoad(){
    gMpIdx = u_traffic_map < mpWord(0) ? u_traffic_map : 0;
    gMpBase = mpWord(1 + gMpIdx);
    gMpLanes = mpWord(gMpBase);
    gMpEdge = gMpBase + mpWord(gMpBase + 2);
    gMpPts = gMpBase + mpWord(gMpBase + 3);
    gMpSucc = gMpBase + mpWord(gMpBase + 4);
    gMpGive = gMpBase + mpWord(gMpBase + 5);
    gMpEntry = gMpBase + mpWord(gMpBase + 6);
    gMpEntries = mpWord(gMpBase + 7);
    gMpCars = u_traffic_cars > 0 ? min(u_traffic_cars, MP_N) : mpWord(gMpBase + 22);
    gMpCar = mpFx(gMpBase + 17);
    float km = mpFx(gMpBase + 18);
    gMpU = 1. / (km < 0. ? -km * 10000. : km * 1000.);
}

const int MP_EDGE_WORDS = 14;

int mpE(int e, int k){ return mpWord(gMpEdge + MP_EDGE_WORDS * e + k); }

float mpLen(int e){ return mpFx(gMpEdge + MP_EDGE_WORDS * e + 2); }

// traffic lights (gen_maps: an edge's lights + 1, bits 0-15 the junction's
// lights, 16 the phase): the two phases take turns on the simulation
// clock, each green as long as gen_maps gave it (by the traffic coming in
// on it), amber MP_SIG_AMBER, then red for both for MP_SIG_CLEAR, every
// junction at its own offset; 0 green, 1 amber, 2 red, -1 no light
int mpLight(int sig){
    if(sig <= 0) return -1;
    int g = (sig - 1) & 65535, ph = (sig - 1) >> 16;
    int gt = gMpBase + mpWord(gMpBase + 44) + 2 * g;
    float g0 = float(mpWord(gt)) * 0.1, g1 = float(mpWord(gt + 1)) * 0.1;
    float cycle = g0 + g1 + 2. * (MP_SIG_AMBER + MP_SIG_CLEAR);
    float t = mod(iTime * MP_TIME + random(vec2(float(g), 3.3)) * cycle, cycle);
    if(ph == 1) t -= g0 + MP_SIG_AMBER + MP_SIG_CLEAR;
    float green = ph == 1 ? g1 : g0;
    return t >= 0. && t < green ? 0 : t >= 0. && t < green + MP_SIG_AMBER ? 1 : 2;
}

int mpSig(int e){ return mpLight(mpE(e, 12) & 1048575); }

float mpOff(int e, bool far){ return mpFx(gMpEdge + MP_EDGE_WORDS * e + (far ? 11 : 10)); }

vec3 mpPoint(int k){ return vec3(mpFx(gMpPts + 3 * k), mpFx(gMpPts + 3 * k + 1), mpFx(gMpPts + 3 * k + 2) * 4.); }

// a car's heading and height (deck levels) share row 0's w
float mpPack(float heading, float h){ return heading + 8. * floor(h * 32. + 0.5); }
float mpHeight(float w){ return floor((w + 4.) / 8.) / 32.; }
float mpHeading(float w){ return w - 8. * floor((w + 4.) / 8.); }

int mpSucc(int e, float pick){
    int n = mpE(e, 4);
    if(n == 0) return -1;
    return mpWord(gMpSucc + mpE(e, 3) + min(int(pick * float(n)), n - 1));
}

int mpLanes(int e, bool far){ return max(mpE(e, 7) >> (far ? 20 : 16) & 15, 1); }

// the lane a connector comes out of (-1 for a lane)
int mpPred(int e){ return mpE(e, 13) - 1; }

// the connector out of e starting nearest lat (ring: 1 only those going
// on round, 0 only those leaving it, else any)
int mpNearest(int e, float lat, int ring){
    int n = mpE(e, 4), st = gMpSucc + mpE(e, 3), best = -1;
    float bd = 1e9;
    for(int k = 0; k < 64; k++){
        if(k >= n) break;
        int c = mpWord(st + k);
        if(ring >= 0 && (mpE(c, 7) >> 1 & 1) != ring) continue;
        float d = abs(lat - mpFx(gMpEdge + MP_EDGE_WORDS * c + 10));
        if(d < bd){ bd = d; best = c; }
    }
    return best;
}

// on a ring of MP_RING_LANES lanes or more a car knows which exit it takes (on a
// narrower ring it picks at each junction as anywhere else): k, counted
// from where it is, kept with its next edge (nx + MP_NX_SPAN * k). It
// drives in the k-th lane from the outside (as far as there are lanes),
// moves out one lane each exit it passes, and takes the road off at k == 1
const float MP_NX_SPAN = 16384.;
const int MP_RING_LANES = 3;
bool mpRing(int e){ return (mpE(e, 7) & 2) != 0; }

// top speed on e: MP_SPEEDUP of its baked one, but a ring keeps its own
// (already slow), as does a connector onto it, so cars join at its pace
float mpSpeedOf(int e){ return float(mpE(e, 7) >> 8 & 255) * 0.001; }
float mpSpeed(int e){
    if(mpRing(e)) return mpSpeedOf(e);
    if((mpE(e, 7) & 1) == 1 && mpRing(mpSucc(e, 0.))) return mpSpeedOf(mpSucc(e, 0.));
    return mpSpeedOf(e) * MP_SPEEDUP;
}

int mpNx(float z){ return z < -0.5 ? -1 : int(mod(z + 0.5, MP_NX_SPAN)); }
float mpExitsLeft(float z){ return z < -0.5 ? 0. : floor((z + 0.5) / MP_NX_SPAN); }
float mpPackNx(int nx, float k){ return nx < 0 ? -1. : float(nx) + MP_NX_SPAN * k; }

// whether ring lane e has a road off it, and the ring edge after it
bool mpRingExit(int e, out int on){
    int n = mpE(e, 4), st = gMpSucc + mpE(e, 3);
    bool off = false;
    on = -1;
    for(int j = 0; j < 64; j++){
        if(j >= n) break;
        int s = mpWord(st + j);
        if(mpRing(s)) on = s; else off = true;
    }
    return off && (mpE(e, 7) & 1) == 0;
}

// the exit a car joining the ring at e takes: any but the one back the way
// it came (the roads off it once round)
float mpPickExit(int i, int e){
    int exits = 0, x = e, on;
    for(int j = 0; j < 64; j++){
        if(mpRingExit(x, on)) exits++;
        if((mpE(x, 7) & 1) == 1) on = mpSucc(x, 0.);
        if(on < 0 || !mpRing(on)) break;
        x = on;
        if(x == e) break;
    }
    return 1. + floor(random(vec2(i, iTime * 0.37)) * float(max(exits - 1, 1)));
}

// where on ring edge e at s a car with k exits to go drives
float mpRingLat(int e, float s, float k){
    float f = clamp(s / max(mpLen(e), 1e-6), 0., 1.);
    float n = mix(float(mpLanes(e, false)), float(mpLanes(e, true)), f);
    float w = mix(mpFx(gMpEdge + MP_EDGE_WORDS * e + 8), mpFx(gMpEdge + MP_EDGE_WORDS * e + 9), f);
    float d = clamp(k, 1., floor(n + 0.5)) - 1.;
    return ((mpWord(gMpBase + 21) & 1) == 1 ? -1. : 1.) * (0.5 * w - (d + 0.5) * w / n);
}

// how backed up each edge is (counted in the traffic buffer from row
// MP_CONG_ROW, AG_W edges a row): its stopped cars, and whether one is
// stopped within MP_CONG_NEAR cars of its start (full to the junction)
vec4 mpCong(sampler2D ch, int e){ return texelFetch(ch, ivec2(e % AG_W, MP_CONG_ROW + e / AG_W), 0); }

vec4 mpCongest(sampler2D ch, int e){
    float stopped = 0., full = 0.;
    for(int j = 0; j < MP_N; j++){
        if(j >= gMpCars) break;
        vec4 o = agGet(ch, j, 1);
        if(o.x < -0.5 || int(o.x + 0.5) != e || agGet(ch, j, 0).z > MP_CRAWL * gMpU) continue;
        stopped += 1.;
        if(o.y < MP_CONG_NEAR * gMpCar) full = 1.;
    }
    return vec4(stopped, full, 0., 0.);
}

// a turn's share: its flow weight, less for every car stopped on it and the
// road it leads to, next to nothing (MP_FULL) where that road is full
float mpRoom(sampler2D ch, int c){
    int r = (mpE(c, 7) & 1) == 1 ? mpSucc(c, 0.) : c;
    vec4 a = mpCong(ch, c), b = mpCong(ch, r);
    return (b.y > 0.5 ? MP_FULL : 1.) / (1. + MP_CONG * (a.x + b.x));
}

// what row MP_CAR_ROW keeps of car i: the edge it came onto the map by (or
// first stood on), when, and the edge it was on last frame
vec4 mpCarMem(sampler2D ch, int i){ return texelFetch(ch, ivec2(i, MP_CAR_ROW), 0); }

// metres from the start of e to the nearest way off the map
float mpAway(int e){ return float(mpWord(gMpBase + mpWord(gMpBase + 45) + e)); }

// how much a car that has roamed past MP_ROAM wants to leave (0 to 1)
float mpHome(sampler2D ch, int i){ return clamp((iTime - mpCarMem(ch, i).y - MP_ROAM) / MP_ROAM_RAMP, 0., 1.); }

// the edge after e at random, by flow and by how backed up each way is,
// and, as much as home, against ways that lead further from leaving
float mpTurnWeight(sampler2D ch, int e, int c, float home){
    float extra = max(mpAway(c) - mpAway(e) + mpLen(e) / gMpU, 0.);
    return mpRoom(ch, c) * exp(-home * extra / MP_HOME_M);
}

int mpPickTurn(sampler2D ch, int e, float pick, float home){
    int n = mpE(e, 4), st = gMpSucc + mpE(e, 3);
    if(n == 0) return -1;
    float total = 0.;
    for(int j = 0; j < 64; j++){
        if(j >= n) break;
        total += mpTurnWeight(ch, e, mpWord(st + j), home);
    }
    float want = pick * total, acc = 0.;
    for(int j = 0; j < 64; j++){
        if(j >= n) break;
        acc += mpTurnWeight(ch, e, mpWord(st + j), home);
        if(acc >= want) return mpWord(st + j);
    }
    return mpWord(st + min(n, 64) - 1);
}

// the freest connector out of e (-1 if none)
int mpFreest(sampler2D ch, int e, out float room){
    int n = mpE(e, 4), st = gMpSucc + mpE(e, 3), best = -1;
    room = 0.;
    for(int j = 0; j < 64; j++){
        if(j >= n) break;
        int x = mpWord(st + j);
        if((mpE(x, 7) & 1) == 0) continue;
        float r = mpRoom(ch, x);
        if(r > room){ room = r; best = x; }
    }
    return best;
}

// the edge after e for a car with k exits to go; one heading onto a ring
// picks its exit now, and the lane onto the ring that leads to its lane
int mpChoose(sampler2D ch, int i, int e, float pick, float home, inout float k){
    int on;
    int c = mpPickTurn(ch, e, pick, home), r = c >= 0 && (mpE(c, 7) & 1) == 1 ? mpSucc(c, 0.) : -1;
    if(!mpRing(e) && c >= 0 && !mpRing(c) && r >= 0 && mpRing(r) && mpLanes(r, false) >= MP_RING_LANES){
        if(k < 0.5) k = mpPickExit(i, r);
        float want = mpRingLat(r, 0., k), bd = 1e9;
        int n = mpE(e, 4), st = gMpSucc + mpE(e, 3);
        for(int j = 0; j < 64; j++){
            if(j >= n) break;
            int x = mpWord(st + j);
            if(mpSucc(x, 0.) != r) continue;
            float d = abs(mpOff(x, true) - want);
            if(d < bd){ bd = d; c = x; }
        }
        return c;
    }
    if(!mpRing(e) || mpLanes(e, false) < MP_RING_LANES || !mpRingExit(e, on) || on < 0) return c;
    if(k > 1.5) return mpNearest(e, mpRingLat(e, mpLen(e), k), 1);
    int n = mpE(e, 4), st = gMpSucc + mpE(e, 3), offs = 0;
    for(int j = 0; j < 64; j++){
        if(j >= n) break;
        if(!mpRing(mpWord(st + j))) offs++;
    }
    int want = min(int(pick * float(offs)), offs - 1), seen = 0;
    for(int j = 0; j < 64; j++){
        if(j >= n) break;
        int s = mpWord(st + j);
        if(mpRing(s)) continue;
        if(seen == want) return s;
        seen++;
    }
    return on;
}

// position and direction at distance s along edge e
void mpAt(int e, float s, out vec2 pos, out vec2 dir, out float h){
    int ps = mpE(e, 0), pc = mpE(e, 1);
    vec3 a = mpPoint(ps);
    pos = a.xy;
    h = a.z;
    dir = vec2(1., 0.);
    float acc = 0.;
    for(int k = 1; k < MP_MAX_PTS; k++){
        if(k >= pc) break;
        vec3 b = mpPoint(ps + k);
        float l = length(b.xy - a.xy);
        if(l > 1e-6) dir = (b.xy - a.xy) / l;
        if(acc + l >= s || k == pc - 1){
            vec3 m = mix(a, b, clamp((s - acc) / max(l, 1e-6), 0., 1.));
            pos = m.xy;
            h = m.z;
            return;
        }
        acc += l;
        a = b;
    }
}

// lanes: a car keeps one place across the road (mpPick), its lane on an
// edge of n lanes floor(pick * n); edges are whole carriageways (lanes
// share out its width), so a car's place is offset from the centre line
// into its lane, a connector moving it across from its lane at one end to
// its lane at the other. A car drifts toward its place at no more than
// MP_SHIFT sideways per distance driven, and turns toward the road's
// heading at MP_STEER but no faster than a car of MP_TURN_R turning
// circle could at its speed, so it never jumps, snaps or spins. Besides
// the cars ahead in its lane, any car within MP_BODY car lengths of its
// path and MP_SEE ahead (not oncoming, and at its height: not on a deck
// above or a road beneath) holds it back too, so cars never
// drive through each other; one stuck for MP_PATIENCE only still minds
// cars going its way
float mpPick(int i){ return random(vec2(float(i), 4.2)); }

int mpLaneOf(float pick, int e){ return int(pick * float(mpLanes(e, true))); }

float mpLat(int i, int e, float s){
    float f = mpPick(i);
    float n0 = float(mpLanes(e, false)), n1 = float(mpLanes(e, true));
    float w0 = mpFx(gMpEdge + MP_EDGE_WORDS * e + 8) / n0, w1 = mpFx(gMpEdge + MP_EDGE_WORDS * e + 9) / n1;
    float a = (floor(f * n0) + 0.5 - 0.5 * n0) * w0, b = (floor(f * n1) + 0.5 - 0.5 * n1) * w1;
    return mix(a, b, clamp(s / max(mpLen(e), 1e-6), 0., 1.));
}

// the connector out of e whose start lanes take in lat (nx if its do)
int mpBranchAt(int e, float lat, int nx){
    if(abs(lat - mpOff(nx, false)) <= 0.5 * mpFx(gMpEdge + MP_EDGE_WORDS * nx + 8)) return nx;
    int best = mpNearest(e, lat, -1);
    return best < 0 ? nx : best;
}

// row 0 for car i at s along e
// row 0 for a car at s along e, lat across from the centre line (square
// to the car's own heading, which turns toward the road's by follow, 1 at
// once, so kinks where pieces join never throw it sideways)
vec4 mpPlace(int e, float s, float v, float lat, float heading, float follow, float maxTurn){
    vec2 p, d;
    float h;
    mpAt(e, s, p, d, h);
    float want = atan(d.y, d.x);
    float turn = mod(want - heading + 3.1415927, 6.2831853) - 3.1415927;
    float hd = mod(heading + clamp(turn * follow, -maxTurn, maxTurn) + 3.1415927, 6.2831853) - 3.1415927;
    return vec4(p + vec2(sin(hd), -cos(hd)) * lat, v, mpPack(hd, h));
}

// row 1's w holds both how long a car has been stopped and where across
// the road it is (decimetres)
float mpPackWait(float wait, float lat){ return (floor(clamp(lat / gMpU * 10., -900., 900.) + 0.5) + 1000.) * 256. + min(wait, 255.); }
float mpWait(float w){ return w - 256. * floor(w / 256.); }
float mpLatOf(float w){ return (floor(w / 256.) - 1000.) * 0.1 * gMpU; }

// which lane of e a car lat across from its centre line at s is in
int mpLaneAt(int e, float s, float lat){
    float f = clamp(s / max(mpLen(e), 1e-6), 0., 1.);
    float n = f < 0.5 ? float(mpLanes(e, false)) : float(mpLanes(e, true));
    float w = mix(mpFx(gMpEdge + MP_EDGE_WORDS * e + 8), mpFx(gMpEdge + MP_EDGE_WORDS * e + 9), f);
    return int(clamp(floor((lat / max(w, 1e-6) + 0.5) * n), 0., n - 1.));
}

// off the screen (by MP_OFF): where cars appear and vanish, and where one
// stopped twice MP_PATIENCE gives up and enters again, so a jam nobody
// sees never holds cars back
bool mpOffscreen(vec2 p){ return abs(p.x) > 0.5 * u_aspect + MP_OFF || abs(p.y) > 0.5 + MP_OFF; }

// the screen's gates (rows from MP_GATE_ROW, AG_W edges a row): where edge e
// first comes in across the edge of the screen, the place on it
// MP_GATE_BACK short of that (-1 if it never does; the start of a lane
// nothing leads into that starts on it), its lanes times its baked spawn
// weight, and how many cars on the map came in by it; worked
// out once, the count every frame
vec4 mpGate(sampler2D ch, int e){ return texelFetch(ch, ivec2(e % AG_W, MP_GATE_ROW + e / AG_W), 0); }

bool mpInView(vec2 p){ return abs(p.x) < 0.5 * u_aspect + MP_OFF && abs(p.y) < 0.5 + MP_OFF; }

vec4 mpGateRow(sampler2D ch, int e){
    if(e >= mpWord(gMpBase + 1)) return vec4(-1., 0., 0., 1.);
    vec4 g = mpGate(ch, e);
    if(g.w < 0.5){
        int sw = mpWord(gMpBase + mpWord(gMpBase + 46) + e);
        g = vec4(-1., float(mpLanes(e, false)) * float(sw & 1048575) / 16., 0., 1.);
        float L = mpLen(e);
        vec2 p, d;
        float h;
        mpAt(e, 0., p, d, h);
        bool was = mpInView(p);
        for(int j = 1; j <= MP_GATE_STEPS; j++){
            float s = L * float(j) / float(MP_GATE_STEPS);
            mpAt(e, s, p, d, h);
            bool now = mpInView(p);
            if(now && !was){ g.x = max(s - MP_GATE_BACK * gMpU, 0.); break; }
            was = now;
        }
        mpAt(e, 0., p, d, h);
        if(g.x < 0. && (sw >> 20 & 1) == 1 && mpInView(p)) g.x = 0.;
    }
    g.z = 0.;
    if(g.x >= 0.){
        for(int j = 0; j < MP_N; j++){
            if(j >= gMpCars) break;
            if(agGet(ch, j, 1).x > -0.5 && abs(mpCarMem(ch, j).x - float(e)) < 0.5) g.z += 1.;
        }
    }
    return g;
}

// on a map whose roads all lie on the screen (header 21 bit 1, the map's
// scatter) a car comes in anywhere on them instead of at a gate: on a lane
// of the spawn list at random, on the screen, once no car is within
// MP_GATE_GAP cars of it there; one car in MP_SCATTER_EVERY a frame tries, so
// cars placed in one frame (which cannot see each other) are few
void mpScatter(sampler2D ch, int i, out vec4 r0, out vec4 r1){
    r0 = vec4(MP_AWAY, MP_AWAY, 0., 0.);
    r1 = vec4(-1., 0., -1., 0.);
    int ns = mpWord(gMpBase + 41), st = gMpBase + mpWord(gMpBase + 42), f = int(floor(iTime * 60.));
    if(ns == 0 || (f + i) % MP_SCATTER_EVERY != 0) return;
    float t = mod(float(f), 997.);
    int e = mpWord(st + int(random(vec2(float(i), t + 0.5)) * float(ns)) % ns);
    float s = random(vec2(float(i) + 0.3, t)) * mpLen(e);
    for(int j = 0; j < MP_N; j++){
        if(j >= gMpCars) break;
        vec4 o = agGet(ch, j, 1);
        if(j != i && o.x > -0.5 && int(o.x + 0.5) == e && abs(o.y - s) < MP_GATE_GAP * gMpCar) return;
    }
    float lat = mpLat(i, e, s);
    vec4 p = mpPlace(e, s, 0., lat, 0., 1., 9.);
    if(mpOffscreen(p.xy)) return;
    r0 = p;
    float ex = mpRing(e) ? mpPickExit(i, e) : 0.;
    int nx = mpChoose(ch, i, e, random(vec2(i, iTime)), 0., ex);
    r1 = vec4(float(e), s, mpPackNx(nx, ex), mpPackWait(0., lat));
}

// a car that left the map (or the screen) waits off it (edge -1) for a
// gate with fewer of the cars on the map that came in by it than its share
// (by lanes): it takes one of those at random, by lanes, once the car before
// it there is MP_GATE_GAP cars on
void mpEnter(sampler2D ch, int i, out vec4 r0, out vec4 r1){
    if((mpWord(gMpBase + 21) & 2) != 0){ mpScatter(ch, i, r0, r1); return; }
    r0 = vec4(MP_AWAY, MP_AWAY, 0., 0.);
    r1 = vec4(-1., 0., -1., 0.);
    float total = 0., open = 0.;
    for(int e = 0; e < 4096; e++){
        if(e >= mpWord(gMpBase + 1)) break;
        vec4 g = mpGate(ch, e);
        if(g.x >= 0.) total += g.y;
    }
    if(total <= 0.) return;
    for(int e = 0; e < 4096; e++){
        if(e >= mpWord(gMpBase + 1)) break;
        vec4 g = mpGate(ch, e);
        if(g.x >= 0. && g.z < ceil(float(gMpCars) * g.y / total)) open += g.y;
    }
    if(open <= 0.) return;
    float want = random(vec2(float(i), floor(iTime * 4.))) * open, acc = 0.;
    int e = -1;
    float s = 0.;
    for(int x = 0; x < 4096; x++){
        if(x >= mpWord(gMpBase + 1)) break;
        vec4 g = mpGate(ch, x);
        if(g.x < 0. || g.z >= ceil(float(gMpCars) * g.y / total)) continue;
        acc += g.y;
        if(acc >= want){ e = x; s = g.x; break; }
    }
    if(e < 0) return;
    for(int j = 0; j < MP_N; j++){
        vec4 o = agGet(ch, j, 1);
        if(j != i && o.x > -0.5 && int(o.x + 0.5) == e && abs(o.y - s) < MP_GATE_GAP * gMpCar) return;
    }
    float lat = mpLat(i, e, s);
    r0 = mpPlace(e, s, 0., lat, 0., 1., 9.);
    float ex = mpRing(e) ? mpPickExit(i, e) : 0.;
    int nx = mpChoose(ch, i, e, random(vec2(i, iTime)), 0., ex);
    r1 = vec4(float(e), s, mpPackNx(nx, ex), mpPackWait(0., lat));
}

// whether b is a, or one or two edges on from it
bool mpFollows(int a, int b){
    if(a == b) return true;
    int n = mpE(a, 4), st = gMpSucc + mpE(a, 3);
    for(int j = 0; j < 64; j++){
        if(j >= n) break;
        int x = mpWord(st + j);
        if(x == b) return true;
        int m = mpE(x, 4), s2 = gMpSucc + mpE(x, 3);
        for(int k = 0; k < 64; k++){
            if(k >= m) break;
            if(mpWord(s2 + k) == b) return true;
        }
    }
    return false;
}

// row MP_CAR_ROW for car i, a frame behind its step: a car on an edge it
// could not have driven to from last frame's came onto the map there now;
// w is set once it has been on the screen
vec4 mpRemember(sampler2D ch, int i, bool fresh){
    if(fresh || i >= gMpCars) return vec4(-1., iTime, -1., 0.);
    vec4 m = mpCarMem(ch, i);
    vec2 p = agGet(ch, i, 0).xy;
    float e = agGet(ch, i, 1).x;
    bool came = e > -0.5 && (m.z < -0.5 || !mpFollows(int(m.z + 0.5), int(e + 0.5)));
    float seen = abs(p.x) < 0.5 * u_aspect && abs(p.y) < 0.5 ? 1. : 0.;
    return came ? vec4(e, iTime, e, seen) : vec4(m.xy, e, max(m.w, seen));
}

// what holds car i back: the nearest car ahead in its lane (on its edge or
// the next two), the nearest car in its path, and whether it must give way
void mpSense(sampler2D ch, int i, vec4 s0, vec4 s1, out float laneGap, out float nearGap, out bool yield){
    int e = int(s1.x + 0.5), nx = mpNx(s1.z);
    float s = s1.y, v = s0.z, wait = mpWait(s1.w), lat = mpLatOf(s1.w);
    float L = mpLen(e);
    int nn = nx >= 0 && (mpE(nx, 7) & 1) == 1 ? mpSucc(nx, 0.) : -1;
    float Ln = nx >= 0 ? mpLen(nx) : 0.;
    int give[MP_MAX_GIVE];
    int ng = 0;
    float left = L - s;
    if(nx >= 0 && left < MP_APPROACH * gMpU && wait < MP_PATIENCE){
        ng = min(mpE(nx, 6), MP_MAX_GIVE);
        int g0 = mpE(nx, 5);
        for(int k = 0; k < MP_MAX_GIVE; k++){ if(k >= ng) break; give[k] = mpWord(gMpGive + g0 + k); }
    }
    laneGap = 1e9; nearGap = 1e9;
    float latx = nx >= 0 ? lat + mpOff(e, true) - mpOff(nx, false) : 0.;
    int le = mpLaneAt(e, s, lat), lx = nx >= 0 ? mpLaneAt(nx, 0., latx) : -1;
    int ln = nn >= 0 ? mpLaneAt(nn, 0., latx + mpOff(nx, true) - mpOff(nn, false)) : -1;
    yield = false;
    float hd = mpHeading(s0.w);
    vec2 fw = vec2(cos(hd), sin(hd));
    bool stuck = wait > MP_PATIENCE;
    // the lane this car merges into and how far it has to go to its start
    bool onConn = (mpE(e, 7) & 1) == 1, nxConn = nx >= 0 && (mpE(nx, 7) & 1) == 1;
    int tgt = onConn ? nx : nxConn ? mpSucc(nx, 0.) : -1;
    float toTgt = onConn ? left : left + Ln;
    // nothing it minds lies further than MP_REACH metres off (along the
    // road is never shorter than straight), so cars beyond it are passed over
    // before anything else is read of them
    float reach = MP_REACH * gMpU;
    for(int j = 0; j < MP_N; j++){
        if(j >= gMpCars) break;
        if(j == i) continue;
        vec4 op = agGet(ch, j, 0);
        vec2 rel = op.xy - s0.xy;
        if(dot(rel, rel) > reach * reach) continue;
        vec4 o = agGet(ch, j, 1);
        if(o.x < -0.5) continue;
        int oe = int(o.x + 0.5);
        float ahead = dot(rel, fw), side = abs(dot(rel, vec2(-fw.y, fw.x)));
        bool level = abs(mpHeight(op.w) - mpHeight(s0.w)) < 0.5;
        // two cars on top of each other: the one behind waits (on a tie, or
        // when each has the other ahead as where two roads meet, the higher
        // index), so they part
        if(level && dot(rel, rel) < 0.25 * gMpCar * gMpCar){
            float oh = mpHeading(op.w);
            bool mutual = ahead > 1e-6 && dot(-rel, vec2(cos(oh), sin(oh))) > 1e-6;
            if(mutual ? j < i : ahead > 1e-6 || ahead > -1e-6 && j < i) nearGap = 0.;
        }
        // a car known to be in another lane (of this road, the next ones,
        // or the one both are about to take) is never in the way
        int ol = oe == e || oe == nx || oe == nn ? mpLaneAt(oe, o.y, mpLatOf(o.w)) : -1;
        int on = mpNx(o.z);
        // nor one on (or about to take) another lane's connector out of the
        // same road, or one into another lane of the same road from another
        // lane
        int mc = onConn ? e : nxConn ? nx : -1;
        int oc = (mpE(oe, 7) & 1) == 1 ? oe : on >= 0 && (mpE(on, 7) & 1) == 1 ? on : -1;
        bool sameIn = mc >= 0 && oc >= 0 && mc != oc && mpPred(mc) == mpPred(oc);
        bool sameOut = mc >= 0 && oc >= 0 && mc != oc && mpSucc(mc, 0.) == mpSucc(oc, 0.);
        bool intoLane = sameOut && abs(mpOff(mc, true) - mpOff(oc, true)) < 1e-4;
        // two cars on one road making for the same lane past the junction
        // queue as one lane already (so they reach it one by one)
        bool oNx = on >= 0 && (mpE(on, 7) & 1) == 1;
        bool sameLane = oe == e && nxConn && oNx && mpSucc(on, 0.) == mpSucc(nx, 0.) && abs(mpOff(on, true) - mpOff(nx, true)) < 1e-4;
        bool apart = oe == e && ol != le && !sameLane || oe == nx && ol != lx || oe == nn && ol != ln
                  || nx >= 0 && on == nx && oe != e && mpLaneAt(nx, 0., mpLatOf(o.w) + mpOff(oe, true) - mpOff(nx, false)) != lx
                  || sameIn && abs(mpOff(mc, false) - mpOff(oc, false)) > 1e-4 && !intoLane
                  || sameOut && !intoLane && !(sameIn && abs(mpOff(mc, false) - mpOff(oc, false)) < 1e-4);
        // two cars about to merge into one lane from different roads: the
        // one further from the merge follows the nearer one (a zipper)
        bool oConn = (mpE(oe, 7) & 1) == 1, oNxConn = on >= 0 && (mpE(on, 7) & 1) == 1;
        int otgt = oConn ? on : oNxConn ? mpSucc(on, 0.) : -1;
        bool partner = tgt >= 0 && otgt == tgt && oe != e && (on != nx || onConn && oConn) && level && (mc < 0 || oc < 0 || intoLane);
        if(partner && !apart && wait < 2. * MP_PATIENCE){
            float oTo = mpLen(oe) - o.y + (oConn ? 0. : mpLen(on));
            if(oTo < toTgt || oTo == toTgt && j < i) laneGap = min(laneGap, toTgt - oTo);
        }
        if(!apart && !partner && ahead > 0. && ahead < MP_SEE * gMpCar && side < MP_BODY * gMpCar && level){
            float oh = mpHeading(op.w);
            vec2 ofw = vec2(cos(oh), sin(oh));
            // two cars each seeing the other in front (lanes merging): the
            // lower index goes first; one stuck past its patience minds only
            // cars that are moving
            bool mutual = dot(-rel, ofw) > 0. && abs(dot(rel, vec2(-ofw.y, ofw.x))) < MP_BODY * gMpCar;
            bool still = op.z < MP_CRAWL * gMpU;
            if(dot(ofw, fw) > (stuck ? 0.7 : -0.3) && !(mutual && j > i) && !(stuck && still)) nearGap = min(nearGap, ahead);
        }
        if(oe == e && (o.y > s || (o.y == s && j < i)) && (ol == le || sameLane)) laneGap = min(laneGap, o.y - s);
        else if(oe == nx && ol == lx) laneGap = min(laneGap, left + o.y);
        else if(oe == nn && ol == ln) laneGap = min(laneGap, left + Ln + o.y);
        // courtesy at a merge: one waiting at its line to give way into the
        // connector this car is about to take is let in
        if(!yield && nx >= 0 && on >= 0 && left < MP_APPROACH * gMpU && wait < MP_PATIENCE && mpWait(o.w) > MP_COURTESY
           && op.z < MP_CRAWL * gMpU && mpLen(oe) - o.y < 2. * gMpCar){
            int g0 = mpE(on, 5), gn = min(mpE(on, 6), MP_MAX_GIVE);
            for(int k = 0; k < MP_MAX_GIVE; k++){
                if(k >= gn) break;
                if(mpWord(gMpGive + g0 + k) == nx){ yield = true; break; }
            }
        }
        // giving way (to a car within MP_LOOK on a connector it gives way to)
        // into the road it joins, only to a car that ends up in
        // the same lane of it
        if(ng > 0 && !yield){
            for(int k = 0; k < MP_MAX_GIVE; k++){
                if(k >= ng) break;
                int gc = give[k], gt = mpSucc(gc, 0.);
                float glat = mpLatOf(o.w) + (oe == gc ? 0. : mpOff(oe, true) - mpOff(gc, false)) + mpOff(gc, true) - mpOff(gt, false);
                bool beside = nn >= 0 && gt == nn && mpLaneAt(gt, 0., glat) != ln;
                if(oe == gc && !beside && length(rel) < MP_LOOK * gMpU){ yield = true; break; }
                float to = mpLen(oe) - o.y;
                bool moving = op.z > MP_CRAWL * gMpU;
                if(on == gc && !beside && (mpE(oe, 7) & 1) == 0 && moving && to < MP_LOOK * gMpU && (to < MP_CLOSE * gMpU || to < op.z * MP_ACCEPT)){ yield = true; break; }
            }
        }
    }
    // stopped for twice its patience a car minds only its lane: whatever
    // standoff held it, it drives out of it
    if(wait > 2. * MP_PATIENCE) nearGap = 1e9;
}

// whether a car at s on e has another in the lane of e at lat beside it
bool mpBeside(sampler2D ch, int i, int e, float s, float lat){
    int want = mpLaneAt(e, s, lat);
    for(int j = 0; j < MP_N; j++){
        if(j >= gMpCars) break;
        if(j == i) continue;
        vec4 o = agGet(ch, j, 1);
        if(o.x < -0.5 || int(o.x + 0.5) != e || abs(o.y - s) > MP_SHIFT_ROOM * gMpCar) continue;
        if(mpLaneAt(e, o.y, mpLatOf(o.w)) == want) return true;
    }
    return false;
}

// on a big ring a car makes for the lane for the exits it has left (k): of
// its own lane and the two beside it it takes the one with the most room
// ahead (cars on the ring up to MP_RING_SEE cars on, sorted into lanes by
// how far across they are), a lane nearer that lane counting
// 1.5 MP_RING_FREER cars more and staying put MP_RING_FREER, where there is
// room beside; for its own exit (k 1) always the outer lane
float mpRingTarget(sampler2D ch, int i, int e, float s, float lat, float k, vec2 pos, float hd){
    float want = mpRingLat(e, s, k);
    if(k < 1.5) return want;
    float f = clamp(s / max(mpLen(e), 1e-6), 0., 1.);
    int n = mpLanes(e, f > 0.5), d = int(clamp(k, 1., float(n))) - 1, cur = mpLaneAt(e, s, lat);
    float lw = mix(mpFx(gMpEdge + MP_EDGE_WORDS * e + 8), mpFx(gMpEdge + MP_EDGE_WORDS * e + 9), f) / float(n);
    float sgn = (mpWord(gMpBase + 21) & 1) == 1 ? -1. : 1., see = MP_RING_SEE * gMpCar;
    vec2 fw = vec2(cos(hd), sin(hd)), rt = vec2(sin(hd), -cos(hd));
    vec3 gap = vec3(see);
    for(int j = 0; j < MP_N; j++){
        if(j >= gMpCars) break;
        if(j == i) continue;
        vec4 o = agGet(ch, j, 1);
        if(o.x < -0.5 || !mpRing(int(o.x + 0.5))) continue;
        vec2 rel = agGet(ch, j, 0).xy - pos;
        float ahead = dot(rel, fw);
        if(ahead <= 0. || ahead > see) continue;
        float dl = floor(-dot(rel, rt) * sgn / lw + 0.5);
        if(dl == -1.) gap.x = min(gap.x, ahead);
        else if(dl == 0.) gap.y = min(gap.y, ahead);
        else if(dl == 1.) gap.z = min(gap.z, ahead);
    }
    float freer = MP_RING_FREER * gMpCar, score = -1e9;
    int best = cur;
    for(int t = -1; t <= 1; t++){
        int l = cur + t;
        if(l < 0 || l >= n) continue;
        float sc = (t == -1 ? gap.x : t == 0 ? gap.y : gap.z) + (abs(l - d) < abs(cur - d) ? 1.5 * freer : 0.) + (t == 0 ? freer : 0.);
        if(sc > score){ score = sc; best = l; }
    }
    float to = mpRingLat(e, s, float(best + 1));
    return best != cur && mpBeside(ch, i, e, s, to) ? lat : to;
}

// how far round a screen cell the bins list cars: as far as one is drawn
// (its headlights, on the highest deck) and drives between two rescans of
// that cell (MP_BIN_MOVE metres)
float mpBinReach(){ return 1.8 * max(gMpCar * MP_CAR_DRAW, 0.008) * (1. + 0.08 * MP_LIFT_TOP) + MP_BIN_MOVE * gMpU; }

// row MP_SENSE_ROW for car i: what holds it back (mpSense), worked out once a
// frame for both its rows to read the next (a frame late)
vec4 mpSensed(sampler2D ch, int i, bool fresh){
    vec4 s0 = agGet(ch, i, 0), s1 = agGet(ch, i, 1);
    if(fresh || i >= gMpCars || s1.x < -0.5) return vec4(1e9, 1e9, 0., 0.);
    float laneGap, nearGap;
    bool yield;
    mpSense(ch, i, s0, s1, laneGap, nearGap, yield);
    return vec4(laneGap, nearGap, yield ? 1. : 0., 0.);
}

void mpStep(sampler2D ch, int i, float dt, bool fresh, out vec4 r0, out vec4 r1){
    mpLoad();
    dt *= MP_TIME;
    if(i >= gMpCars){ r0 = vec4(MP_AWAY, MP_AWAY, 0., 0.); r1 = vec4(-2., 0., -1., 0.); return; }
    if(fresh){ r0 = vec4(MP_AWAY, MP_AWAY, 0., 0.); r1 = vec4(-1., 0., -1., 0.); return; }
    vec4 s0 = agGet(ch, i, 0), s1 = agGet(ch, i, 1);
    if(s1.x < -0.5){ mpEnter(ch, i, r0, r1); return; }
    int e = int(s1.x + 0.5), nx = mpNx(s1.z);
    float s = s1.y, v = s0.z, wait = mpWait(s1.w), lat = mpLatOf(s1.w), exits = mpExitsLeft(s1.z);
    if(wait > 2. * MP_PATIENCE && mpOffscreen(s0.xy)){ mpEnter(ch, i, r0, r1); return; }
    float L = mpLen(e), left = L - s;
    vec4 sensed = texelFetch(ch, ivec2(i, MP_SENSE_ROW), 0);
    float laneGap = sensed.x, nearGap = sensed.y;
    bool yield = sensed.z > 0.5;
    float gap = min(laneGap, nearGap);
    float vmax = mpSpeed(e) * (0.85 + 0.15 * random(vec2(i, 6.6)));
    float want = vmax * clamp((gap - MP_GAP * gMpCar) / (3. * gMpCar), 0., 1.);
    if(nx >= 0) want = min(want, mix(mpSpeed(nx), vmax, clamp(left / (15. * gMpU), 0., 1.)));
    int light = nx >= 0 ? mpSig(nx) : -1;
    bool stopLight = light == 2 || light == 1 && left > v * v / (2. * MP_BRAKE * gMpU) + 2. * gMpU;
    if(yield || stopLight) want = min(want, vmax * clamp((left - 0.6 * gMpU) / (10. * gMpU), 0., 1.));
    v += clamp(want - v, -MP_BRAKE * gMpU * dt, MP_ACC * gMpU * dt);
    v = max(v, 0.);
    s += v * dt;
    wait = v < MP_CRAWL * gMpU ? wait + dt : 0.;
    for(int k = 0; k < 2; k++){
        if(s < L) break;
        if(nx < 0){ mpEnter(ch, i, r0, r1); return; }
        s -= L;
        lat += mpOff(e, true) - mpOff(nx, false);
        int on;
        if(!mpRing(e) && mpRing(nx)){ if(exits < 0.5) exits = mpPickExit(i, nx); }
        else if(mpRing(nx) && mpRingExit(e, on)) exits = max(exits - 1., 1.);
        else if(mpRing(e) && !mpRing(nx)) exits = 0.;
        e = nx;
        L = mpLen(e);
        nx = mpChoose(ch, i, e, random(vec2(float(i) + floor(iTime * 7.), float(e) * 0.37)), mpHome(ch, i), exits);
    }
    s = min(s, L);
    // a car near a junction making for a connector whose road is backed up
    // takes a clearly freer one out of the same road, changing lanes for it
    // (even late, even from a standstill) where there is room beside
    bool shift = false;
    if(nx >= 0 && !mpRing(e) && (mpE(nx, 7) & 1) == 1 && L - s < MP_LANE_CHOOSE * gMpU){
        float room;
        int alt = mpFreest(ch, e, room);
        float cur = mpRoom(ch, nx);
        if(alt >= 0 && alt != nx && cur < 2. * MP_FULL && room > 2. * cur){ nx = alt; if(!mpRing(mpSucc(alt, 0.))) exits = 0.; }
        int own = mpBranchAt(e, lat, nx);
        float ownRoom = mpRoom(ch, own);
        shift = own != nx && ownRoom < 2. * MP_FULL && mpRoom(ch, nx) > 2. * ownRoom;
    }
    // before a junction a car moves into the lane that feeds the connector
    // it takes (a split's own lanes, an exit's side) over MP_LANE_CHOOSE;
    // over the last MP_LANE_LOCK it keeps its lane, and if that lane feeds
    // another branch it takes that one instead
    float target = mpLat(i, e, s), step = MP_SHIFT * v * dt;
    // and over the first MP_LANE_LOCK after a junction it keeps it too, as
    // far as the road it is on has lanes there
    if((mpE(e, 7) & 1) == 0 && (mpE(e, 12) >> 20 & 1) == 0 && s < MP_LANE_LOCK * gMpU) target = lat;
    if(shift){
        target = mpBeside(ch, i, e, s, mpOff(nx, false)) ? lat : mpOff(nx, false);
        step = MP_SHIFT * max(v, MP_SHIFT_CREEP * gMpU) * dt;
    }
    else if(nx >= 0 && (mpE(nx, 7) & 1) == 1){
        float lock = MP_LANE_LOCK * gMpU;
        if(L - s > lock)
            target = mix(target, mpOff(nx, false) + mpLat(i, nx, 0.), clamp(1. - (L - s - lock) / (MP_LANE_CHOOSE * gMpU), 0., 1.));
        else {
            target = lat;
            nx = mpBranchAt(e, lat, nx);
        }
    }
    // and an exit whose road is backed up to the ring it passes, going
    // round again to take the next one
    int again;
    if(mpRing(e) && nx >= 0 && !mpRing(nx) && mpRingExit(e, again) && again >= 0 && L - s < MP_LANE_CHOOSE * gMpU){
        int after = mpSucc(nx, 0.);
        for(int j = 0; j < MP_N; j++){
            if(j >= gMpCars) break;
            vec4 o = agGet(ch, j, 1);
            int oe = int(o.x + 0.5);
            if(o.x > -0.5 && (oe == nx || oe == after && o.y < 3. * gMpCar) && agGet(ch, j, 0).z < MP_CRAWL * gMpU){ nx = mpNearest(e, lat, 1); break; }
        }
    }
    if(mpRing(e) && mpLanes(e, false) >= MP_RING_LANES){
        target = mpRingTarget(ch, i, e, s, lat, exits, s0.xy, mpHeading(s0.w));
        step = MP_SHIFT * max(v, MP_SHIFT_CREEP * gMpU) * dt;
    }
    lat += clamp(target - lat, -step, step);
    if((mpE(e, 7) & 1) == 0){
        float f = clamp(s / max(L, 1e-6), 0., 1.);
        float n = mix(float(mpLanes(e, false)), float(mpLanes(e, true)), f);
        float w = mix(mpFx(gMpEdge + MP_EDGE_WORDS * e + 8), mpFx(gMpEdge + MP_EDGE_WORDS * e + 9), f);
        float lim = 0.5 * w * (1. - 1. / n);
        lat = clamp(lat, -lim, lim);
    }
    r0 = mpPlace(e, s, v, lat, mpHeading(s0.w), 1. - exp(-dt * MP_STEER), (v / (MP_TURN_R * gMpU) + 0.3) * dt);
    r1 = vec4(float(e), s, mpPackNx(nx, exits), mpPackWait(wait, lat));
    float hd = mpHeading(r0.w);
    // off the screen a car is no use: one that has been on it goes at once,
    // one still coming in after MP_COMING
    vec4 mem = mpCarMem(ch, i);
    bool known = mem.z > -0.5 && mpFollows(int(mem.z + 0.5), e);
    if(mpOffscreen(r0.xy) && (dot(r0.xy, vec2(cos(hd), sin(hd))) > 0. || known && (mem.w > 0.5 || iTime - mem.y > MP_COMING))) mpEnter(ch, i, r0, r1);
}

// signed distance from p to a footprint (corners v[0..n), negative inside)
float mpPoly(vec2 v[MP_BLD_MAX_V], int n, vec2 p){
    vec2 a = v[n - 1];
    float d = 1e9;
    bool inside = false;
    for(int k = 0; k < MP_BLD_MAX_V; k++){
        if(k >= n) break;
        vec2 b = v[k], e = b - a, w = p - a;
        vec2 r = w - e * clamp(dot(w, e) / max(dot(e, e), 1e-12), 0., 1.);
        d = min(d, dot(r, r));
        if((a.y > p.y) != (b.y > p.y) && p.x < e.x * (p.y - a.y) / (b.y - a.y) + a.x) inside = !inside;
        a = b;
    }
    return (inside ? -1. : 1.) * sqrt(d);
}

// the buildings at q: how much shadow they cast on the ground there, and
// their walls and roofs (grey, lit window, -, coverage) to lay over the
// rest. A
// building of height h (screen units) rises MP_BLD_VIEW * h up the screen,
// its walls the footprint swept up there (MP_BLD_WALL samples), lit
// windows at random; its shadow falls MP_BLD_SUN * h along MP_SHADOW.
// Footprints in front (lower on screen) cover those behind.
vec4 mpBuildings(vec2 q, int ci, out float shade){
    shade = 0.;
    vec4 o = vec4(0.);
    int n = mpWord(ci + 1), st = gMpBase + mpWord(gMpBase + 27) + mpWord(ci);
    int tb = gMpBase + mpWord(gMpBase + 24), tv = gMpBase + mpWord(gMpBase + 25);
    float front = -1e9;
    for(int k = 0; k < MP_BLD_CELL; k++){
        if(k >= n) break;
        int bi = mpWord(st + k), r = tb + 7 * bi;
        float h = mpFx(r + 2);
        vec2 lo = vec2(mpFx(r + 3), mpFx(r + 4)), hi = vec2(mpFx(r + 5), mpFx(r + 6));
        vec2 sv = MP_SHADOW * MP_BLD_SUN * h, up = vec2(0., MP_BLD_VIEW * h);
        vec2 elo = min(lo, lo + sv) - 0.003, ehi = max(hi + up, hi + sv) + 0.003;
        if(any(lessThan(q, elo)) || any(greaterThan(q, ehi))) continue;
        int vs = mpWord(r), vc = min(mpWord(r + 1), MP_BLD_MAX_V);
        vec2 v[MP_BLD_MAX_V];
        for(int j = 0; j < MP_BLD_MAX_V; j++){
            if(j >= vc) break;
            v[j] = vec2(mpFx(tv + 2 * (vs + j)), mpFx(tv + 2 * (vs + j) + 1));
        }
        shade = max(shade, smoothstep(0.003, -0.002, mpPoly(v, vc, q - sv)));
        if(q.y < lo.y - 0.002 || q.y > hi.y + up.y + 0.002) continue;
        float roof = mpPoly(v, vc, q - up);
        float wall = 1e9, wt = 0.;
        int ns = clamp(int(up.y / 0.0025) + 1, 1, MP_BLD_WALL);
        for(int j = 0; j < MP_BLD_WALL; j++){
            if(j >= ns) break;
            float t = float(j) / float(ns);
            float d = mpPoly(v, vc, q - up * t);
            if(d < wall){ wall = d; wt = t; }
        }
        float a = max(S(roof), S(wall));
        if(a < 0.01 || -lo.y < front - 1e-4) continue;
        front = -lo.y;
        float rnd = random(vec2(float(bi), 3.3));
        float rc = 0.085 + 0.03 * rnd + 0.015 * smoothstep(0., 0.05, h);
        rc = mix(rc, 0.2, S(abs(roof + 0.0007) - 0.0006) * 0.7);
        float hm = h / gMpU;
        vec2 win = vec2(q.x / (2.6 * gMpU), wt * hm / 3.2);
        vec2 wc = floor(win), wf = fract(win);
        float lit = step(0.78, random(wc + float(bi))) * step(0.25, wf.x) * step(wf.x, 0.75) * step(0.3, wf.y) * step(wf.y, 0.75);
        bool onRoof = roof < 0. || S(roof) > S(wall);
        vec2 c = onRoof ? vec2(rc, 0.) : vec2(0.045 + 0.03 * wt, lit * step(0.08, wt));
        o = vec4(mix(o.rg, c, a), 0., max(o.a, a));
    }
    return o;
}

// the map's static layer, baked once per map into bufferMapStatic: r the
// ground and roads (grey) + 2 * how green there, + 32 * how much water
// and + 512 * how much parked car (all in 15ths), g the height of the top
// surface / 4 + 4 * the parked car's shade (15ths), b the
// buildings' grey (+ 2 on a lit window), a their coverage
float mpPolyG(vec2 v[MP_GREEN_MAX_V], int n, vec2 p){
    vec2 a = v[n - 1];
    float d = 1e9;
    bool inside = false;
    for(int k = 0; k < MP_GREEN_MAX_V; k++){
        if(k >= n) break;
        vec2 b = v[k], e = b - a, w = p - a;
        vec2 r = w - e * clamp(dot(w, e) / max(dot(e, e), 1e-12), 0., 1.);
        d = min(d, dot(r, r));
        if((a.y > p.y) != (b.y > p.y) && p.x < e.x * (p.y - a.y) / (b.y - a.y) + a.x) inside = !inside;
        a = b;
    }
    return (inside ? -1. : 1.) * sqrt(d);
}

// green areas at q (gen_maps GREEN: lawns, parks, woods): how green, and
// the ground there as grey (water first, then grass texture, then tree
// crowns lit from the top left, overhanging banks, their shadows along
// MP_SHADOW). Trees stand on a jittered grid,
// sparse in parks and dense in woods; one is kept if its trunk is inside
// the nearest green area, and its crown may overhang the edge. The crowns
// and their shadows come back apart (crown: coverage, grey; shadow) so
// they can go over the footpaths
float mpGreen(vec2 q, int ci, inout float grey, inout float water, out vec2 crown, out float shadow){
    int n = mpWord(ci + 1), st = gMpBase + mpWord(gMpBase + 32) + mpWord(ci);
    int tg = gMpBase + mpWord(gMpBase + 29), tv = gMpBase + mpWord(gMpBase + 30);
    crown = vec2(0.);
    shadow = 0.;
    float reach = MP_TREE_R * gMpU;
    float near = 1e9, kind = -1.;
    vec2 bv[MP_GREEN_MAX_V];
    int bn = 0;
    for(int k = 0; k < MP_GREEN_CELL; k++){
        if(k >= n) break;
        int gi = mpWord(st + k), r = tg + 7 * gi;
        vec2 lo = vec2(mpFx(r + 3), mpFx(r + 4)) - reach, hi = vec2(mpFx(r + 5), mpFx(r + 6)) + reach;
        if(any(lessThan(q, lo)) || any(greaterThan(q, hi))) continue;
        int vs = mpWord(r), vc = min(mpWord(r + 1), MP_GREEN_MAX_V);
        vec2 v[MP_GREEN_MAX_V];
        for(int j = 0; j < MP_GREEN_MAX_V; j++){
            if(j >= vc) break;
            v[j] = vec2(mpFx(tv + 2 * (vs + j)), mpFx(tv + 2 * (vs + j) + 1));
        }
        float d = mpPolyG(v, vc, q);
        if(mpWord(r + 2) == 3){ water = max(water, S(d)); continue; }
        if(d < near){ near = d; kind = float(mpWord(r + 2)); bv = v; bn = vc; }
    }
    float ripple = 0.045 + 0.015 * tcFbm(vec2(q.x * 0.6, q.y * 1.6) / (5. * gMpU)) + 0.007 * tcNoise(q / (1.5 * gMpU));
    grey = mix(grey, ripple, water);
    if(near > reach) return 0.;
    float g = S(near) * (1. - water);
    float lawn = 0.045 + 0.02 * tcFbm(q / (6. * gMpU)) + 0.01 * tcNoise(q / (1.2 * gMpU));
    float ground = mix(grey, lawn, g);
    if(kind >= 1.){
        float sp = (kind >= 2. ? 6.5 : 12.) * gMpU, dens = kind >= 2. ? 0.9 : 0.45;
        vec2 ci2 = floor(q / sp);
        float cr = 1e9, shade = 0., sh = 1e9;
        for(int y = -1; y <= 1; y++) for(int x = -1; x <= 1; x++){
            vec2 c = ci2 + vec2(x, y);
            if(random(c + 0.37) > dens) continue;
            vec2 ctr = (c + 0.2 + 0.6 * vec2(random(c), random(c + 7.1))) * sp;
            if(mpPolyG(bv, bn, ctr) > 0.) continue;
            float rad = (2.2 + 2.2 * random(c + 3.3)) * gMpU;
            float d = length(q - ctr) - rad;
            if(d < cr){ cr = d; shade = dot(normalize(q - ctr + 1e-6), normalize(-MP_SHADOW)) * clamp(1. + d / rad, 0., 1.); }
            sh = min(sh, length(q - ctr - MP_SHADOW * rad * 1.4) - rad);
        }
        shadow = 0.45 * smoothstep(0.002, -0.002, sh);
        crown = vec2(S(cr), 0.075 + 0.035 * shade + 0.02 * tcNoise(q / (0.8 * gMpU)));
        water *= 1. - crown.x;
    }
    grey = ground;
    return g;
}

// parked cars at q (gen_maps parked): amps in their bays, each its own
// shade of the car colours (shade out), with a small shadow; returns how
// much of q they cover
float mpParked(vec2 q, int ci, inout vec3 col, out float shade){
    int n = mpWord(ci + 1), st = gMpBase + mpWord(gMpBase + 36) + mpWord(ci);
    int tb = gMpBase + mpWord(gMpBase + 34);
    float sz = max(gMpCar * MP_CAR_DRAW, 0.008), cov = 0.;
    shade = 0.;
    for(int k = 0; k < MP_PARK_CELL; k++){
        if(k >= n) break;
        int pi = mpWord(st + k), r = tb + 3 * pi;
        vec2 p = vec2(mpFx(r), mpFx(r + 1));
        if(length(q - p) > sz * 1.2) continue;
        float a = float(mpWord(r + 2)) / 4096. * 6.2831853;
        vec2 f = vec2(cos(a), sin(a));
        col *= 1. - 0.35 * S(agAmp(q, p + MP_SHADOW * sz * 0.12, f, sz) - sz * 0.05);
        float c = S(agAmp(q, p, f, sz));
        if(c > cov){ cov = c; shade = random(vec2(float(pi), 5.5)); }
    }
    return cov;
}

// signed distance from p to triangle abc (negative inside)
float mpTri(vec2 p, vec2 a, vec2 b, vec2 c){
    vec2 e0 = b - a, e1 = c - b, e2 = a - c, v0 = p - a, v1 = p - b, v2 = p - c;
    vec2 p0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0., 1.);
    vec2 p1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0., 1.);
    vec2 p2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0., 1.);
    float sg = sign(e0.x * e2.y - e0.y * e2.x);
    vec2 d = min(min(vec2(dot(p0, p0), sg * (v0.x * e0.y - v0.y * e0.x)), vec2(dot(p1, p1), sg * (v1.x * e1.y - v1.y * e1.x))),
                 vec2(dot(p2, p2), sg * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}

// the ground's height at q (screen units), across the terrain grid
float mpTerrain(vec2 q){
    int nx = mpWord(gMpBase + 12), ny = mpWord(gMpBase + 13);
    vec2 g = clamp((q - vec2(mpFx(gMpBase + 14), mpFx(gMpBase + 15))) / mpFx(gMpBase + 16), vec2(0.), vec2(nx, ny) - 0.001);
    ivec2 c = ivec2(floor(g));
    vec2 f = g - vec2(c);
    int t = gMpBase + mpWord(gMpBase + 43) + c.y * (nx + 1) + c.x;
    return mix(mix(mpFx(t), mpFx(t + 1), f.x), mix(mpFx(t + nx + 1), mpFx(t + nx + 2), f.x), f.y);
}

// hillshade: the ground lit from the sun (against MP_SHADOW), its slopes
// MP_HILL_EXAG times as steep, 1 on the flat; worked out at the corners of
// the terrain grid (from their neighbours' heights) and blended across it
float mpHillAt(int t0, int nx, int ny, int x, int y, float cs){
    x = clamp(x, 1, nx - 1); y = clamp(y, 1, ny - 1);
    int t = t0 + y * (nx + 1) + x;
    vec2 d = vec2(mpFx(t + 1) - mpFx(t - 1), mpFx(t + nx + 1) - mpFx(t - nx - 1)) / (2. * cs) * MP_HILL_EXAG;
    vec3 n = normalize(vec3(-d, 1.)), sun = normalize(vec3(-MP_SHADOW, 1.));
    return clamp(dot(n, sun) / sun.z, 1. - MP_HILL, 1. + MP_HILL);
}

float mpHill(vec2 q){
    int nx = mpWord(gMpBase + 12), ny = mpWord(gMpBase + 13), t0 = gMpBase + mpWord(gMpBase + 43);
    float cs = mpFx(gMpBase + 16);
    vec2 g = clamp((q - vec2(mpFx(gMpBase + 14), mpFx(gMpBase + 15))) / cs, vec2(0.), vec2(nx, ny) - 0.001);
    ivec2 c = ivec2(floor(g));
    vec2 f = smoothstep(0., 1., g - vec2(c));
    return mix(mix(mpHillAt(t0, nx, ny, c.x, c.y, cs), mpHillAt(t0, nx, ny, c.x + 1, c.y, cs), f.x),
               mix(mpHillAt(t0, nx, ny, c.x, c.y + 1, cs), mpHillAt(t0, nx, ny, c.x + 1, c.y + 1, cs), f.x), f.y);
}

// the terrain stands up the screen as buildings do (MP_BLD_VIEW of its
// height, MP_TERRAIN_EXAG times as high): the ground a pixel shows is the
// one nearest the viewer (lowest on the screen) whose lifted place is it,
// found by marching up from MP_TERRAIN_LMAX below and halving in on it
vec2 mpGround(vec2 q, out float lift){
    float k = MP_BLD_VIEW * MP_TERRAIN_EXAG, lo = q.y - MP_TERRAIN_LMAX, dy = MP_TERRAIN_LMAX / float(MP_TERRAIN_STEPS);
    float y0 = lo, y1 = q.y;
    bool hit = false;
    for(int i = 0; i <= MP_TERRAIN_STEPS; i++){
        float y = lo + float(i) * dy;
        if(y + k * mpTerrain(vec2(q.x, y)) >= q.y){ y1 = y; y0 = y - dy; hit = true; break; }
    }
    if(!hit){ lift = 0.; return q; }
    for(int i = 0; i < 6; i++){
        float y = 0.5 * (y0 + y1);
        if(y + k * mpTerrain(vec2(q.x, y)) >= q.y) y1 = y; else y0 = y;
    }
    lift = q.y - y1;
    return vec2(q.x, y1);
}

vec4 mpStatic(vec2 q){
    mpLoad();
    float lift;
    q = mpGround(q, lift);
    vec3 col = vec3(0.03) + bgNoise(q * NOISE_SCALE) * 0.15;
    int nx = mpWord(gMpBase + 12), ny = mpWord(gMpBase + 13);
    vec2 mn = vec2(mpFx(gMpBase + 14), mpFx(gMpBase + 15));
    float cs = mpFx(gMpBase + 16);
    ivec2 c = ivec2(floor((q - mn) / cs));
    vec2 sh = MP_SHADOW * MP_DECK * gMpU;
    float road[MP_LAYERS], line[MP_LAYERS], sdw[MP_LAYERS], hgt[MP_LAYERS];
    for(int l = 0; l < MP_LAYERS; l++){ road[l] = 1e9; line[l] = 1e9; sdw[l] = 1e9; hgt[l] = 0.; }
    float bare = 1e9, path = 1e9, pathHi = 1e9, river = 1e9, water = 0., parked = 0., pshade = 0.;
    float wall = 1e9, wallShade = 1e9;
    if(c.x >= 0 && c.y >= 0 && c.x < nx && c.y < ny){
        int ci = gMpBase + mpWord(gMpBase + 10) + 2 * (c.y * nx + c.x);
        int st = gMpBase + mpWord(gMpBase + 11) + mpWord(ci), n = mpWord(ci + 1);
        int seg = gMpBase + mpWord(gMpBase + 8);
        for(int k = 0; k < MP_SEG_CELL; k++){
            if(k >= n) break;
            int o = seg + 9 * mpWord(st + k);
            vec2 a = vec2(mpFx(o), mpFx(o + 1)), b = vec2(mpFx(o + 2), mpFx(o + 3));
            float hw = mpFx(o + 4);
            int kind = mpWord(o + 6), l = clamp((kind >> 4 & 15), 0, MP_LAYERS - 1);
            vec2 ab = b - a;
            float ab2 = max(dot(ab, ab), 1e-12);
            float t = clamp(dot(q - a, ab) / ab2, 0., 1.);
            float d = length(q - a - ab * t);
            if((kind & 15) == 2){
                float arc = mpFx(o + 5) + t * length(ab);
                if(fract(arc / (MP_DASH * gMpCar)) < 0.5) line[l] = min(line[l], d);
                continue;
            }
            if((kind & 15) == 5){ river = min(river, d - hw); continue; }
            if((kind & 15) == 7){
                wall = min(wall, d - hw);
                vec2 qs = q - sh * mpFx(o + 7) * 4.;
                float ts = clamp(dot(qs - a, ab) / ab2, 0., 1.);
                wallShade = min(wallShade, length(qs - a - ab * ts) - hw);
                continue;
            }
            if((kind & 15) == 6){
                vec2 c3 = vec2(hw, mpFx(o + 5));
                float dt = mpTri(q, a, b, c3) - MP_JUNCTION_PAD * gMpU;
                if(dt < road[l]){
                    vec2 e0 = b - a, e1 = c3 - a, pq = q - a;
                    float den = e0.x * e1.y - e0.y * e1.x;
                    vec2 w = abs(den) > 1e-12 ? clamp(vec2(pq.x * e1.y - pq.y * e1.x, e0.x * pq.y - e0.y * pq.x) / den, 0., 1.) : vec2(0.);
                    road[l] = dt;
                    hgt[l] = mpFx(o + 7) * 4. * (1. - w.x - w.y) + mpFx(o + 8) * 4. * w.x + float(kind >> 12) / 256. * w.y;
                }
                continue;
            }
            if((kind & 15) == 4){
                float pd = d - max(hw, 0.0007);
                if(l > MP_GROUND) pathHi = min(pathHi, pd); else path = min(path, pd);
                continue;
            }
            float ha = mpFx(o + 7) * 4., hb = mpFx(o + 8) * 4.;
            if(d - hw < road[l]){ road[l] = d - hw; hgt[l] = mix(ha, hb, t); }
            if(max(ha, hb) < 0.02) continue;
            float hc = mix(ha, hb, t);
            vec2 qs = q - sh * hc;
            float ts = clamp(dot(qs - a, ab) / ab2, 0., 1.);
            hc = mix(ha, hb, ts);
            qs = q - sh * hc;
            ts = clamp(dot(qs - a, ab) / ab2, 0., 1.);
            bare = min(bare, length(qs - a - ab * ts) - hw);
        }
        // decks shade the surfaces of the layers under them by how far
        // above those surfaces (where they are here) they stand
        for(int k = 0; k < MP_SEG_CELL; k++){
            if(k >= n) break;
            int o = seg + 9 * mpWord(st + k);
            int kind = mpWord(o + 6), l = clamp((kind >> 4 & 15), 0, MP_LAYERS - 1);
            if((kind & 15) != 0 || l <= MP_GROUND) continue;
            float ha = mpFx(o + 7) * 4., hb = mpFx(o + 8) * 4.;
            if(max(ha, hb) < 0.02) continue;
            vec2 a = vec2(mpFx(o), mpFx(o + 1)), b = vec2(mpFx(o + 2), mpFx(o + 3));
            float hw = mpFx(o + 4);
            vec2 ab = b - a;
            float ab2 = max(dot(ab, ab), 1e-12);
            for(int u = MP_GROUND; u < MP_LAYERS; u++){
                if(u >= l) break;
                float base = road[u] < 0.01 ? hgt[u] : float(u - MP_GROUND);
                vec2 qu = q;
                float dh = 0.;
                for(int it = 0; it < 2; it++){
                    float tu = clamp(dot(qu - a, ab) / ab2, 0., 1.);
                    dh = mix(ha, hb, tu) - base;
                    qu = q - sh * max(dh, 0.);
                }
                if(dh < MP_SHADE_MIN) continue;
                float tu = clamp(dot(qu - a, ab) / ab2, 0., 1.);
                sdw[u] = min(sdw[u], length(qu - a - ab * tu) - hw);
            }
        }
    }
    // ground, then each layer up: a layer's surface in the shadow of the
    // decks above it, bridge decks lighter with parapets, tunnels faint
    float topH = 0.;
    float green = 0., tshadow = 0.;
    vec2 crown = vec2(0.);
    water = max(water, S(river));
    if(c.x >= 0 && c.y >= 0 && c.x < nx && c.y < ny){
        float grey = col.r;
        green = mpGreen(q, gMpBase + mpWord(gMpBase + 31) + 2 * (c.y * nx + c.x), grey, water, crown, tshadow);
        col = vec3(grey);
    }
    green *= 1. - water;
    // on a map with a treeline and snowline (header 21 bit 2, the two after
    // its terrain) no green or trees above the one and snow above the other,
    // their edges ragged by MP_LINE_RAG metres
    float snow = 0.;
    if((mpWord(gMpBase + 21) & 4) != 0){
        int tl = gMpBase + mpWord(gMpBase + 43) + (nx + 1) * (ny + 1);
        float h = mpTerrain(q) + (bgNoise(q / (MP_LINE_RAG * gMpU)).r - 0.5) * MP_LINE_RAG * gMpU;
        float above = smoothstep(-MP_LINE_BAND, MP_LINE_BAND, (h - mpFx(tl)) / gMpU);
        snow = smoothstep(-MP_LINE_BAND, MP_LINE_BAND, (h - mpFx(tl + 1)) / gMpU);
        green *= 1. - above;
        crown.x *= 1. - above;
        tshadow *= 1. - above;
    }
    col = mix(col, vec3(0.04), S(path - 0.0006) * 0.6);
    col = mix(col, vec3(MP_PATH_GREY), S(path));
    green *= 1. - S(path - 0.0014);
    water *= 1. - S(path - 0.0014);
    // walls: a pale stone ridge with a lit rim, its shadow cast like a deck's
    col *= 1. - 0.45 * S(wallShade) * (1. - S(wall));
    col = mix(col, vec3(MP_WALL_GREY), S(wall));
    col = mix(col, vec3(MP_WALL_GREY + 0.045), S(abs(wall + 0.0005) - 0.0003) * S(wall + 0.0002));
    green *= 1. - S(wall - 0.0006);
    water *= 1. - S(wall - 0.0006);
    col *= 1. - tshadow;
    col = mix(col, vec3(crown.y), crown.x);
    green = max(green, crown.x);
    col = mix(col, vec3(MP_SNOW_GREY), snow);
    green *= 1. - snow;
    col *= 1. - 0.5 * smoothstep(0.004, -0.002, bare);
    if(c.x >= 0 && c.y >= 0 && c.x < nx && c.y < ny && mpWord(gMpBase + 33) > 0){
        parked = mpParked(q, gMpBase + mpWord(gMpBase + 35) + 2 * (c.y * nx + c.x), col, pshade);
        green *= 1. - parked;
        water *= 1. - parked;
    }
    for(int l = 0; l < MP_LAYERS; l++){
        if(road[l] > 0.01) continue;
        float cov = S(road[l]);
        float lift = hgt[l], dk = smoothstep(0.08, 0.6, lift);
        // where a deck runs on into road of about its height on any other
        // layer (the ramp it joins, the deck it splits from), its end and
        // edges are not drawn: one surface
        float edge = 1.;
        for(int m = MP_GROUND; m < MP_LAYERS; m++)
            if(m != l) edge = min(edge, 1. - S(road[m] + 0.002) * (1. - smoothstep(0.15, 0.45, abs(hgt[m] - lift))));
        vec3 rc = vec3(0.075 + 0.018 * lift) * (1. - 0.5 * smoothstep(0.004, -0.002, sdw[l]));
        float a = l < MP_GROUND ? 0.3 : 1.;
        col = mix(col, vec3(0.16 + (0.04 + 0.02 * lift) * dk), S(road[l] - mix(0.0012, 0.0016, dk)) * a * edge);
        col = mix(col, rc, cov * a);
        float under = S(road[l] - mix(0.0012, 0.0016, dk)) * a;
        green *= 1. - under;
        water *= 1. - under;
        parked *= 1. - under * dk;
        col = mix(col, vec3(0.28 + 0.03 * lift), S(abs(road[l] + 0.0006) - 0.0005) * a * dk * edge);
        col = mix(col, vec3(0.3), S(line[l] - 0.0006) * cov * a * MP_LINE);
        if(cov > 0.5 && l >= MP_GROUND) topH = lift;
    }
    col = mix(col, vec3(0.04), S(pathHi - 0.0008) * 0.6);
    col = mix(col, vec3(MP_PATH_GREY + 0.04), S(pathHi));
    green *= 1. - S(pathHi - 0.0016);
    water *= 1. - S(pathHi - 0.0016);

    col = max(col + vec3(MP_HILL_LIGHT * (mpHill(q) - 1.)), vec3(0.));

    vec4 bld = vec4(0.);
    if(c.x >= 0 && c.y >= 0 && c.x < nx && c.y < ny && mpWord(gMpBase + 23) > 0){
        float shade;
        bld = mpBuildings(q, gMpBase + mpWord(gMpBase + 26) + 2 * (c.y * nx + c.x), shade);
        col *= 1. - 0.45 * shade;
    }

    return vec4(col.r + 2. * floor(green * 15. + 0.5) + 32. * floor(water * 15. + 0.5) + 512. * floor(parked * 15. + 0.5),
                topH / 4. + 4. * floor(pshade * 15. + 0.5) + 256. * floor(lift * MP_LIFT_Q + 0.5), bld.r + 2. * step(0.5, bld.g), bld.a);
}

// traffic light heads at q: a dark housing with the lit lamp glowing red,
// amber or green; hidden, like cars, under a surface well above them
// (topH)
vec3 mpHeads(vec2 q, vec3 col, float topH){
    int nx = mpWord(gMpBase + 12), ny = mpWord(gMpBase + 13);
    ivec2 c = ivec2(floor((q - vec2(mpFx(gMpBase + 14), mpFx(gMpBase + 15))) / mpFx(gMpBase + 16)));
    if(c.x < 0 || c.y < 0 || c.x >= nx || c.y >= ny || mpWord(gMpBase + 37) == 0) return col;
    int ci = gMpBase + mpWord(gMpBase + 39) + 2 * (c.y * nx + c.x);
    int n = mpWord(ci + 1), st = gMpBase + mpWord(gMpBase + 40) + mpWord(ci), tb = gMpBase + mpWord(gMpBase + 38);
    float r = max(0.8 * gMpU, 0.0016);
    for(int k = 0; k < MP_SIG_CELL; k++){
        if(k >= n) break;
        int o = tb + 4 * mpWord(st + k);
        float d = length(q - vec2(mpFx(o), mpFx(o + 1)));
        if(d > r * 6. || topH > mpFx(o + 3) * 4. + 0.5) continue;
        int s = mpLight(mpWord(o + 2));
        vec3 lamp = s == 0 ? vec3(0.2, 1., 0.45) : s == 1 ? vec3(1., 0.7, 0.1) : vec3(1., 0.12, 0.08);
        col = mix(col, vec3(0.02), S(d - r * 1.3));
        col = mix(col, lamp, S(d - r * 0.8));
        col += lamp * 0.25 * exp(-d / (r * 1.5));
    }
    return col;
}

// with a dev car count set, a bar along the top: of the cars on the map,
// those stopped over MP_JAMMED (white: jammed, longer than any light),
// stopped (red), moving (green), and waiting off it (blue)
// every car on a small map of the screen and around it (the preview's
// minimap button): green moving, red stopped, magenta jammed
vec3 mpMinimap(vec2 q, vec3 col){
    vec2 mc = vec2(0.5 * u_aspect - 0.12, 0.36), mq = (q - mc) / 0.1 * 1.4;
    if(abs(mq.x) < 1.4 && abs(mq.y) < 1.4){
        vec3 c = vec3(0.05);
        if(abs(abs(mq.x) - 0.5 * u_aspect) < 0.006 && abs(mq.y) < 0.5 || abs(abs(mq.y) - 0.5) < 0.006 && abs(mq.x) < 0.5 * u_aspect) c = vec3(0.5);
        for(int i = 0; i < MP_N; i++){
            if(i >= gMpCars) break;
            vec4 a1 = agGet(iChannel19, i, 1);
            if(a1.x < -0.5) continue;
            vec4 a0 = agGet(iChannel19, i, 0);
            if(length(a0.xy - mq) < 0.02) c = mpWait(a1.w) > MP_JAMMED ? vec3(1., 0., 1.) : a0.z < MP_CRAWL * gMpU ? vec3(1., 0.2, 0.1) : vec3(0.2, 1., 0.3);
        }
        return c;
    }
    return col;
}

vec3 mpMeter(vec2 q, vec3 col){
    if(q.y >= 0.43 && q.y < 0.46 && q.x >= -0.44 && q.x <= 0.){
        float on = 0., off = 0.;
        for(int i = 0; i < MP_N; i++){
            if(i >= gMpCars) break;
            vec4 a0 = agGet(iChannel19, i, 0), a1 = agGet(iChannel19, i, 1);
            if(a1.x < -0.5) continue;
            if(abs(a0.x) > 0.5 * u_aspect || abs(a0.y) > 0.5) off += 1.; else on += 1.;
        }
        float x = (q.x + 0.44) / 0.44 * float(gMpCars);
        return x < on ? vec3(0., 1., 0.) : x < on + off ? vec3(1., 0., 0.) : vec3(0., 0., 1.);
    }
    if(q.y < 0.47 || q.x < -0.44 || q.x > 0.) return col;
    float stk = 0., stp = 0., mov = 0., away = 0.;
    for(int i = 0; i < MP_N; i++){
        if(i >= gMpCars) break;
        vec4 a0 = agGet(iChannel19, i, 0), a1 = agGet(iChannel19, i, 1);
        if(a1.x < -0.5) away += 1.;
        else if(mpWait(a1.w) > MP_JAMMED) stk += 1.;
        else if(a0.z < MP_CRAWL * gMpU) stp += 1.;
        else mov += 1.;
    }
    float x = (q.x + 0.44) / 0.44 * float(gMpCars);
    return x < stk ? vec3(1.) : x < stk + stp ? vec3(1., 0., 0.) : x < stk + stp + mov ? vec3(0., 1., 0.) : vec3(0., 0., 1.);
}

// the map's name in the bottom left corner (gen_maps labels: a strip of
// LABEL_W x LABEL_H per map in iChannel22), MP_LABEL tall a strip, over a
// soft shadow
vec3 mpLabel(vec2 q, vec3 col){
    vec2 ts = vec2(textureSize(iChannel22, 0));
    float rows = floor(ts.y / MP_LABEL_PX + 0.5), w = ts.x / MP_LABEL_PX;
    vec2 uv = (q - vec2(-0.5 * iResolution.x / iResolution.y + MP_LABEL_PAD, -0.5 + MP_LABEL_PAD)) / MP_LABEL;
    if(rows < 1. || uv.x < 0. || uv.y < 0. || uv.x > w || uv.y > 1.) return col;
    float d = (texture(iChannel22, vec2(uv.x / w, (float(gMpIdx) + 1. - clamp(uv.y, 0.02, 0.98)) / rows)).r - 0.5) * MP_LABEL_RANGE * MP_LABEL;
    col *= 1. - 0.6 * smoothstep(MP_LABEL * 0.08, 0., d);
    return mix(col, vec3(0.88), S(d));
}

// the lane graph over the map (the preview's lanes button): each lane's
// centre line dim, connectors through junctions green, orange where they
// give way, blue on a ring, over each junction's area tinted; a road with
// stopped cars washed amber, red where it is backed up to its start
vec3 mpLanes(sampler2D ch, vec2 q, vec3 col){
    int nx = mpWord(gMpBase + 12), ny = mpWord(gMpBase + 13);
    ivec2 c = ivec2(floor((q - vec2(mpFx(gMpBase + 14), mpFx(gMpBase + 15))) / mpFx(gMpBase + 16)));
    if(c.x < 0 || c.y < 0 || c.x >= nx || c.y >= ny) return col;
    int ci = gMpBase + mpWord(gMpBase + 10) + 2 * (c.y * nx + c.x);
    int st = gMpBase + mpWord(gMpBase + 11) + mpWord(ci), n = mpWord(ci + 1);
    int seg = gMpBase + mpWord(gMpBase + 8);
    float px = 0.6 / iResolution.y;
    bool area = false;
    vec4 jam = vec4(0.);
    for(int k = 0; k < MP_SEG_CELL; k++){
        if(k >= n) break;
        int o = seg + 9 * mpWord(st + k);
        int kind = mpWord(o + 6);
        vec2 a = vec2(mpFx(o), mpFx(o + 1)), b = vec2(mpFx(o + 2), mpFx(o + 3)), ab = b - a;
        if((kind & 15) == 6 && mpTri(q, a, b, vec2(mpFx(o + 4), mpFx(o + 5))) - MP_JUNCTION_PAD * gMpU < 0.) area = true;
        if((kind & 15) != 0) continue;
        float d = length(q - a - ab * clamp(dot(q - a, ab) / max(dot(ab, ab), 1e-12), 0., 1.));
        int eid = (kind >> 12) - 1;
        if(eid >= 0 && d < mpFx(o + 4)){ vec4 g = mpCong(ch, eid); if(g.x > jam.x || g.y > jam.y) jam = g; }
        bool conn = (kind >> 9 & 1) == 1;
        vec3 lc = !conn ? vec3(0.45) : (kind >> 11 & 1) == 1 ? vec3(0.3, 0.6, 1.) : (kind >> 10 & 1) == 1 ? vec3(1., 0.55, 0.1) : vec3(0.2, 1., 0.35);
        col = mix(col, lc, smoothstep(px, 0., d - (conn ? px : 0.)));
    }
    if(area) col = mix(col, vec3(1., 0.3, 0.8), 0.25);
    return jam.x > 0.5 ? mix(col, mix(vec3(1., 0.75, 0.1), vec3(1., 0.1, 0.1), jam.y), min(0.15 + 0.06 * jam.x, 0.55)) : col;
}

vec3 mpRender(vec2 q, vec2 tp){
    mpLoad();
    float asp = iResolution.x / iResolution.y;
    vec4 st = texture(iChannel21, roomUV(q));
    float lq = floor(st.g / 256.);
    st.g -= 256. * lq;
    vec2 qs = q;
    q.y -= lq / MP_LIFT_Q;
    float ck = floor(st.r / 512.), rr = st.r - 512. * ck;
    float wk = floor(rr / 32.), gk = floor((rr - 32. * wk) / 2.), grey = rr - 32. * wk - 2. * gk;
    vec3 col = mix(vec3(grey), grey * MP_GREEN_TINT, gk / 15.);
    col = mix(col, grey * MP_WATER_TINT, wk / 15.);
    float sk = floor(st.g / 4.);
    col = mix(col, mix(GRAD_BOT, GRAD_TOP, sk / 15.), ck / 15.);
    float topH = (st.g - 4. * sk) * 4.;
    float sz = max(gMpCar * MP_CAR_DRAW, 0.008);
    vec4 sl[AG_TEX];
    agSlots(iChannel19, q, asp, sl);
    for(int k = 0; k < AG_SLOTS; k++){
        int i = int(sl[k >> 2][k & 3] + 0.5) - 1;
        if(i < 0) break;
        vec4 s = agGet(iChannel19, i, 0);
        float lift = mpHeight(s.w), hd = mpHeading(s.w);
        if(topH > lift + 0.5) continue;
        float csz = sz * (1. + 0.08 * lift);
        vec2 p = s.xy, f = vec2(cos(hd), sin(hd));
        float near = csz * 1.8;
        if(dot(q - p, q - p) > near * near) continue;
        vec2 d = q - p;
        float ahead = dot(d, f), side = dot(d, vec2(-f.y, f.x));
        float beam = smoothstep(csz * 1.6, 0., ahead) * step(csz * 0.3, ahead) * smoothstep(csz * 0.2 + ahead * 0.35, 0., abs(side));
        col += vec3(1., 0.92, 0.7) * 0.18 * beam;
        float brake = s.z < 2. * gMpU ? 1. : 0.35;
        col += vec3(1., 0.1, 0.05) * brake * 0.5 * exp(-length(d + f * csz * 0.45) / (csz * 0.18));
        vec3 body = mix(GRAD_BOT, GRAD_TOP, random(vec2(i, 8.8)));
        vec4 dbg = (u_traffic_debug & 8) != 0 ? agGet(iChannel19, i, 1) : vec4(0.);
        if((u_traffic_debug & 8) != 0 && mpWait(dbg.w) > MP_JAMMED) body = (mpE(int(dbg.x + 0.5), 7) & 1) == 1 ? vec3(1., 0., 1.) : vec3(1., 1., 0.);
        col = mix(col, body, S(agAmp(q, p, f, csz)));
    }
    col = mpHeads(q, col, topH);
    bool lit = st.b > 1.;
    vec3 ov = vec3(st.b - (lit ? 2. : 0.)) + (lit ? vec3(1., 0.8, 0.5) * 0.35 : vec3(0.));
    if((u_traffic_debug & 1) != 0) col = mpLanes(iChannel19, q, col);
    col = mpLabel(qs, mix(col, ov, st.a));
    if((u_traffic_debug & 4) != 0) col = mpMeter(qs, col);
    if((u_traffic_debug & 2) != 0) col = mpMinimap(qs, col);
    return col;
}
