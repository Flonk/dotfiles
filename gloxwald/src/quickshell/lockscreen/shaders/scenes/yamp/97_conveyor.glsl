// --- conveyor: a rube goldberg amp factory cut into a slab ---------------------
// bufferConveyor runs CV_N items through tunnels cut into one grey slab. The
// amp is cast in three pieces (J, the P bowl and the P's detached tail "."),
// each on its own line: poured four at a time from lava veins in the slab,
// cooled in a wind tunnel, knocked out of its mould by a drop hammer. A floor
// arm welds the "." onto the J, a ceiling arm then the P. The amp drops down
// the right edge into a water basin, rides a conveyor and a bucket elevator up
// to the heater, spirals down to four airbrush passes, tumbles down to
// quality control (stamp, scale, scanner; rejects melt), slides down to be
// boxed, taped and labelled, and falls off screen through a chute. Item rows:
// row 0 pos.xy, spin; row 1 track, arc length, timer, mask (bit k station k,
// and row 0 w the piece plus 4 if rejected). Row CV_ROW holds the stations
// (progress, holder, since done, extra), the jam, the sorter, the sim clock
// and the splash.
const int   CV_N       = 400;
const int   CV_NFRAME  = 56;
const float CV_K       = 0.8;
const float CV_M       = 0.78 * CV_K;
const float CV_DSIZE   = 0.06;
const float CV_SIZE    = CV_DSIZE * CV_M;
const float CV_AMPK    = CV_DSIZE / 0.04;
const float CV_GAP     = 0.047 * CV_M;
const float CV_BELT_V  = 0.09;
const float CV_RAMP_V  = 0.2;
const float CV_PAINT_V = 0.06;
const float CV_LIFT_V  = 0.11;
const float CV_WATER_V = 0.07;
const float CV_REJECT  = 0.14;
const float CV_JAM_LEN = 6.5;
const float CV_FIX_AT  = 4.2;
const float CV_WARM    = 0.;
const float CV_WARP    = 6.;
const float CV_HIT     = 0.3;
const int   CV_ROW     = AG_FIELD0;

// the layout is a grid of CV_CELL squares, one mould slot each: cell (i, j)
// spans [i, i + 1] x [j, j + 1] cells. Things sit centred in a cell (CVX),
// a row's tunnel is two cells tall from floor line j (CVR is where a piece
// standing on its belt is centred), rooms have their walls on grid lines
const float CV_CELL    = CV_GAP;
const float CV_ROWOFF  = 0.0227;
#define CVX(i) (((i) + 0.5) * CV_CELL)
#define CVR(j) ((j) * CV_CELL + CV_ROWOFF)
#define CVG(j) ((j) * CV_CELL)

const float CV_HALF_W  = 1.07;
const float CV_HALF_H  = 0.5;
const float CV_CX      = -0.05;
const float CV_CY      = 0.06;
const float CV_TANK_Y  = CVG(-12.);
const float CV_PLK1    = CVG(24.);
const float CV_DIVE    = CVR(15.) - CVG(-12.);
const float CV_TOPY    = CVR(15.);
const vec2  CV_HUB     = vec2(CVG(24.5), CVG(-6.));
const float CV_HUBR    = CVG(2.);
const float CV_SPIN_W  = 26.;
const float CV_GAL_V   = 0.18;
const float CV_DRUM_V  = 0.0088;
const vec2  CV_DRUM    = vec2(CVG(23.), CVG(10.));
const float CV_DRUMR   = CVG(3.);
const float CV_DRUM_W  = 1.0472;
const float CV_DRIP_V  = 0.03;
const float CV_FLAW    = 0.12;

const int CT_FREE = -1, CT_P = 0, CT_J = 1, CT_DROP = 2, CT_MAIN = 3, CT_REJ = 4, CT_SLIDE = 5, CT_PACK = 6, CT_D = 7, CT_FIN = 8, CT_FRAME = 9, CT_ARM1 = 10, CT_ARM2 = 11;
const int CV_NT = 10;
const int CV_KFRAME = 3;
const int CV_MAXP = 22;
const int CS_WELD1 = 6, CS_WELD2 = 7, CS_PRIME = 8, CS_CLEAR = 11, CS_STAMP = 12, CS_WEIGH = 13, CS_SCAN = 14, CS_BOX = 15, CS_TAPE = 16, CS_LABEL = 17;
const int CS_PRESS = 18, CS_CAUSTIC = 21, CS_SQUEEZE = 22, CS_STRETCH = 23, CS_GRIND = 24, CS_XRAY = 25, CS_BOOT = 26, CS_FLICK = 27, CS_POLISH = 28, CS_HAT = 29, CS_CLASS = 30;
const int CV_NS = 31;
const int CX_JAM = 31, CX_SORT = 32, CX_CLOCK = 33, CX_SPLASH = 34, CX_PUSH = 35, CX_FEED = 38, CX_QK = 41, CX_HATFLY = 46, CX_TEACH = 47;
const int   CV_QC_K[5] = int[](CS_STAMP, CS_SQUEEZE, CS_WEIGH, CS_STRETCH, CS_SCAN);
const float CV_QREJ[5] = float[](0.03, 0.04, 0.04, 0.04, 0.05);

const vec2 CV_PTS[58] = vec2[](
    vec2(CVX(-35.), CVR(12.)), vec2(CVX(2.), CVR(12.)),
    vec2(CVX(-35.), CVR(15.)), vec2(CVX(28.2), CVR(15.)),
    vec2(CVX(28.2), CVR(15.)), vec2(CVX(28.2), CVR(-15.)),
    vec2(CVX(32.), CVR(-15.)), vec2(CVX(4.), CVR(-15.)), vec2(CVX(2.), CVR(-12.)), vec2(CVX(3.), CVR(-10.)), vec2(CVX(9.), CVR(-10.)), vec2(CVX(9.), CVR(-7.)), vec2(CVX(4.), CVR(-7.)), vec2(CVX(4.), CVR(-4.)),
    vec2(CVX(18.), CVR(-4.)), vec2(CVX(26.), CVG(-6.)), vec2(CVX(26.), CVR(9.)), vec2(CVX(9.), CVR(9.)),
    vec2(CVX(9.), CVR(7.)), vec2(CVX(19.), CVR(7.)),
    vec2(CVX(-29.), CVR(3.)), vec2(CVX(-29.), CVR(3.)), vec2(CVX(-29.), CVR(3.)),
    vec2(CVX(-29.), CVR(3.)), vec2(CVX(-29.), CVR(-1.)),
    vec2(CVX(-29.), CVR(-1.)), vec2(CVG(-27.08), CVR(-1.)), vec2(CVX(-17.), CVR(-4.)), vec2(CVX(-8.), CVR(-4.)), vec2(CVX(-8.), CVR(-15.)), vec2(CVG(-9.4), CVR(-15.)), vec2(CVG(-10.1), CVR(-14.4)), vec2(CVG(-11.9), CVR(-14.4)), vec2(CVG(-12.6), CVR(-15.)), vec2(CVX(-17.), CVR(-15.)), vec2(CVX(-19.), CVR(-11.)),
    vec2(CVX(-28.), CVR(-11.)), vec2(CVX(-28.5), CVR(-12.)), vec2(CVX(-28.5), -1.3),
    vec2(CVX(-35.), CVR(9.)), vec2(CVX(-5.), CVR(9.)), vec2(CVX(-5.), CVR(9.)), vec2(CVX(-5.), CVR(9.)),
    vec2(CVX(19.), CVR(7.)), vec2(CVG(20.42), CVG(7.17)), vec2(CVG(22.42), CVG(1.17)), vec2(CVX(22.), CVR(-1.)), vec2(CVG(0.), CVR(-1.)), vec2(CVG(0.), CVR(-15.)),
    vec2(CVG(-5.), CVR(-15.)), vec2(CVG(-5.), CVR(3.)), vec2(CVX(-29.), CVR(3.)),
    vec2(CVX(-10.), CVR(15.)), vec2(CVX(-10.), CVR(6.)), vec2(CVX(-37.), CVR(6.)), vec2(CVX(-37.), CVR(-13.6)), vec2(CVX(-35.), CVR(-13.6)), vec2(CVX(-35.), CVR(15.))
);
const int CV_T0[10] = int[](0, 2, 4, 6, 20, 23, 25, 39, 43, 52);
const int CV_TN[10] = int[](2, 2, 2, 14, 3, 2, 14, 2, 9, 6);

const int   CV_ST_T[31]  = int[](0, 1, 7, 0, 1, 7, 1, 1, 3, 8, 8, 8, 8, 8, 8, 6, 6, 6, 0, 1, 7, 3, 8, 8, 1, 1, 1, 3, 8, 6, 6);
const float CV_ST_X[31]  = float[](CVX(-24.), CVX(-24.), CVX(-24.), CVX(-10.), CVX(-10.), CVX(-10.), CVX(-1.), CVX(5.),
    CVG(18.), CVG(18.), CVG(13.), CVG(8.), CVG(-5.), CVG(-5.), CVG(-5.), CVX(-19.), CVX(-24.), CVX(-27.),
    CVX(-33.), CVX(-33.), CVX(-33.), CVX(18.), CVG(-5.), CVG(-5.), CVX(9.), CVX(12.), CVX(15.), CVG(18.), CVG(2.), CVG(-11.), CVX(-17.));
const float CV_ST_Y[31]  = float[](CVR(12.), CVR(15.), CVR(9.), CVR(12.), CVR(15.), CVR(9.), CVR(15.), CVR(15.),
    CVR(9.), CVR(-1.), CVR(-1.), CVR(-1.), CVR(-11.5), CVR(-5.), CVR(1.5), CVR(-11.), CVR(-11.), CVR(-11.),
    CVR(12.), CVR(15.), CVR(9.), CVR(-4.), CVR(-8.25), CVR(-1.75), CVR(15.), CVR(15.), CVR(15.), CVR(9.), CVR(-1.), CVR(-14.4), CVR(-4.));
const int   CV_BATCH[3]  = int[](8, 8, 1);
const int   CV_FILLN     = 1;
const float CV_ST_DW[31] = float[](3.5, 3.5, 1., 1., 1., 1., 1.25, 1.25, 1.1, 1.5, 1.5, 1.75, 0.5, 0.75, 0.75, 0.5, 0.5, 0.5, 0.75, 0.75, 0.75, 10.4, 1., 1., 1., 0.75, 0.5, 1.5, 1.25, 0.75, 9.);
const float CV_TAKT = 2.;
const float CV_BEAT = 0.25;
const float CV_WAITCAP[3] = float[](5., 99., 4.);
// pieces, in glyph units: kind 0 J, 1 the P bowl, 2 the "." tail. A lone
// piece on its line is drawn at g = gp + CV_PO[kind] so it sits bottom-centred
// on the belt; every line casts in the same standard flask (CV_MCEN, CV_MHALF,
// in gp), only the pattern pressed into its sand differs; an arm
// grips it at CV_GRIP from its glyph origin
const vec2 CV_PO[3]    = vec2[](vec2(0.), vec2(-0.0185, 0.284), vec2(0.294, 0.02));
const vec2 CV_MCEN[3]  = vec2[](vec2(0., -0.02), vec2(0., -0.02), vec2(0., -0.02));
const vec2 CV_MHALF[3] = vec2[](vec2(0.42, 0.56), vec2(0.42, 0.56), vec2(0.42, 0.56));
const vec2 CV_GRIP[3]  = vec2[](vec2(0., 0.55), vec2(-0.02, 0.53), vec2(0.294, -0.27));
const float CV_PSPLIT  = -0.26;

// the weld room (cells -7..7 x 8..17) and its two arms: 0 sets the "." on
// the J (floor mounted), 1 the P (ceiling mounted)
const vec4  CV_WELDROOM = vec4(-7., 6., 7., 17.);
const vec2  CV_PICK[2] = vec2[](vec2(CVX(-5.), CVR(9.)), vec2(CVX(2.), CVR(12.)));
const vec2  CV_JOIN[2] = vec2[](vec2(CVX(-1.), CVR(15.)), vec2(CVX(5.), CVR(15.)));
const vec2  CV_ARMB[2] = vec2[](vec2(CVX(-3.), CVG(8.)), vec2(CVX(4.), CVG(17.)));
const float CV_ARML[2] = float[](0.115, 0.075);
const int   CV_ARMK[2] = int[](2, 1);
const vec2  CV_SEAM[2] = vec2[](vec2(0.22, -0.33), vec2(0.05, -0.05));

#define CVZ min(iFrame, 0)

// the mask bit of station k: masks are floats, exact to 2^24, so the stations
// past 23 reuse foundry bits of the lines a finished amp never ran on
int cvBit(int k){ return k < 24 ? k : k == CS_GRIND ? 0 : k == CS_XRAY ? 2 : k == CS_BOOT ? 3 : k == CS_FLICK ? 5 : k == CS_POLISH ? 18 : k == CS_HAT ? 4 : 1; }

int cvI(float x){ return int(round(x)); }

float cvLen(int t){
    t = clamp(t, 0, CV_NT - 1);
    float l = 0.;
    for(int k = 1; k < CV_MAXP + CVZ; k++){
        if(k >= CV_TN[t]) break;
        l += length(CV_PTS[CV_T0[t] + k] - CV_PTS[CV_T0[t] + k - 1]);
    }
    return l;
}

vec2 cvAt(int t, float s){
    t = clamp(t, 0, CV_NT - 1);
    vec2 p = CV_PTS[CV_T0[t]];
    for(int k = 1; k < CV_MAXP + CVZ; k++){
        if(k >= CV_TN[t]) break;
        vec2 b = CV_PTS[CV_T0[t] + k];
        float l = length(b - p);
        if(s <= l || k == CV_TN[t] - 1) return p + (b - p) * clamp(s / max(l, 1e-6), 0., 1.);
        s -= l;
        p = b;
    }
    return p;
}

vec2 cvDirAt(int t, float s){
    t = clamp(t, 0, CV_NT - 1);
    vec2 p = CV_PTS[CV_T0[t]];
    for(int k = 1; k < CV_MAXP + CVZ; k++){
        if(k >= CV_TN[t]) break;
        vec2 b = CV_PTS[CV_T0[t] + k];
        float l = length(b - p);
        if(l > 1e-6 && (s <= l || k == CV_TN[t] - 1)) return (b - p) / l;
        s -= l;
        p = b;
    }
    return vec2(1., 0.);
}

// arc length of the point of track t nearest q
float cvSAtP(int t, vec2 q){
    t = clamp(t, 0, CV_NT - 1);
    float best = 1e9, sb = 0., acc = 0.;
    for(int k = 1; k < CV_MAXP + CVZ; k++){
        if(k >= CV_TN[t]) break;
        vec2 a = CV_PTS[CV_T0[t] + k - 1], b = CV_PTS[CV_T0[t] + k];
        float l = length(b - a);
        float h = clamp(dot(q - a, b - a) / max(l * l, 1e-6), 0., 1.);
        float d = length(q - a - (b - a) * h);
        if(d < best){ best = d; sb = acc + h * l; }
        acc += l;
    }
    return sb;
}

vec2 cvStPos(int k){ return vec2(CV_ST_X[k], CV_ST_Y[k]); }

float cvSAtSt(int k){ return cvSAtP(CV_ST_T[k], cvStPos(k)); }
float cvPackEnd(){ return cvSAtP(CT_PACK, vec2(CVX(-28.), CVR(-11.))); }
float cvBounceS(){ return cvSAtP(CT_PACK, vec2(CVX(-17.), CVR(-15.))); }

// the foundry line (0 P, 1 J, 2 ".") of a track or a piece, -1 if none
int cvLineOfTrack(int t){ return t == CT_P ? 0 : t == CT_J ? 1 : t == CT_D ? 2 : -1; }
int cvLineOfKind(int kind){ return kind == 0 ? 1 : kind == 1 ? 0 : 2; }

// how many moulds station k works on at once, 0 if it is not a batch station
int cvBatchN(int k){ return k < 3 ? CV_BATCH[k] : k == CS_CAUSTIC ? 8 : k == CS_CLASS ? 12 : 0; }

int cvBatchSlot(int k, float s){
    float b = (cvSAtSt(k) - s) / CV_GAP;
    float r = floor(b + 0.5);
    return abs(b - r) < 0.05 && r >= 0. && r < float(cvBatchN(k)) - 0.5 ? int(r) : -1;
}

// on the main run: drying on the heater belt, hanging from the rail over the
// caustic pit, flung up the shaft by the centrifuge, along the gallery over the
// paint hall and tumbling down the zigzag to the airbrush row
bool cvHeatAt(vec2 p){ return p.x > CVG(2.) && p.x < CVG(10.) && p.y > CVG(-10.) && p.y < CVG(-2.); }
bool cvLaunchAt(vec2 p){ return abs(p.x - CVX(26.)) < 0.001 && p.y > CV_HUB.y + 0.001 && p.y < CVR(9.) - 0.001; }
bool cvRailAt(vec2 p){ return abs(p.y - CVR(-4.)) < 0.001 && p.x > CVX(9.) + 0.0005 && p.x < CVX(18.) + 0.001; }
bool cvGalleryAt(vec2 p){ return abs(p.y - CVR(9.)) < 0.001 && p.x > CVX(9.) + 0.0005; }
bool cvDripAt(vec2 p){ return abs(p.y - CVR(7.)) < 0.001 && p.x > CVX(9.) - 0.0005 && p.x < CVX(19.) - 0.0005; }
bool cvMainZig(vec2 p){ return false; }

bool cvRampAt(vec2 p){ return p.y > CVG(1.17) + 0.001 && p.x > CVX(19.) + 0.0005 && p.x < CVG(22.42) - 0.0005; }

// the batch on the rail, T seconds into its cycle: 0..3 dipped in the pit,
// 3..4.2 swung onto the centrifuge, spun up, each amp let go as its arm
// points right so it flies straight up the shaft, then spun down
float cvSpin(float T){
    if(T < 4.2) return 0.;
    if(T < 5.4) return CV_SPIN_W * (T - 4.2) * (T - 4.2) / 2.4;
    if(T < 9.6) return CV_SPIN_W * (0.6 + T - 5.4);
    float x = min(T - 9.6, 0.8);
    return CV_SPIN_W * (4.8 + x - x * x / 1.6);
}
float cvSpinW(float T){ return T < 4.2 ? 0. : T < 5.4 ? CV_SPIN_W * (T - 4.2) / 1.2 : T < 9.6 ? CV_SPIN_W : CV_SPIN_W * max(1. - (T - 9.6) / 0.8, 0.); }
float cvRelTheta(int r){
    float a = float(r) * 0.785398;
    return 6.283185 * (ceil((cvSpin(5.6) + a) / 6.283185) + 2. * float(r)) - a;
}
float cvShaftS(){ return cvSAtP(CT_MAIN, vec2(CVX(26.), CV_HUB.y)); }

float cvSpeed(int t, float s, vec2 p){
    if(t == CT_DROP) return s < CV_PLK1 ? 0.14 : s < CV_DIVE ? min(0.25 + 3.2 * (s - CV_PLK1), 1.3) : CV_WATER_V;
    if(t == CT_MAIN){
        if(p.y < CV_TANK_Y - 0.01) return CV_WATER_V;
        if(cvRailAt(p)) return 0.6;
        if(cvHeatAt(p)) return CV_BELT_V * 0.5;
        if(cvLaunchAt(p)){
            float h = CVR(9.) - CV_HUB.y, g = 0.5 * CV_SPIN_W * CV_SPIN_W * CV_HUBR * CV_HUBR / h;
            return max(sqrt(max(2. * g * h + 0.0144 - 2. * g * (p.y - CV_HUB.y), 0.)), 0.12);
        }
        if(cvGalleryAt(p)) return p.x < CVG(24.) && p.x > CVG(18.) ? CV_DRUM_V : CV_GAL_V;
        if(cvDripAt(p)) return CV_DRIP_V;
        if(cvMainZig(p)) return CV_RAMP_V * 0.6;
        if(abs(p.y - CVR(3.)) < 0.001) return CV_BELT_V;
        return CV_BELT_V * 0.25;
    }
    if(t == CT_FIN){
        float sw = CVG(7.3248);
        if(cvRampAt(p)) return sqrt(0.0064 + 2.8 * s);
        if(abs(p.y - CVR(-1.)) < 0.001 && p.x > CVG(16.) && p.x < CVX(22.) + 0.001) return 0.2;
        if(p.x > CVX(21.)) return p.y > CVR(-1.) + 0.001 ? sqrt(0.004 + 3. * max(s - sw, 0.)) : CV_PAINT_V;
        if(abs(p.x - CVG(0.)) < 0.001 && p.y < CVR(-1.) - 0.001) return min(0.2 + 3. * (CVR(-1.) - p.y), 1.2);
        if(abs(p.x - CVG(-5.)) < 0.001 && p.y > CVR(-15.) + 0.001 && p.y < CVR(3.) - 0.001) return 0.12;
        return CV_PAINT_V;
    }
    if(t == CT_SLIDE) return min(0.2 + 3. * s, 1.);
    if(t == CT_REJ) return CV_LIFT_V;
    if(t == CT_PACK){
        float pe = cvPackEnd();
        if(abs(p.x - CVX(-8.)) < 0.001 && p.y < CVR(-4.) - 0.001 && p.y > CVR(-15.) + 0.001) return min(0.2 + 3. * (CVR(-4.) - p.y), 1.2);
        if(p.y < CVR(-14.) && p.x > CVX(-17.) + 0.001 && p.x < CVX(-8.)) return 0.12;
        float sb = cvBounceS();
        if(s > sb - 1e-4 && s < sb + CVG(4.4721)) return 0.3;
        if(abs(p.y - CVR(-11.)) < 0.001 && s < pe) return 0.12;
        if(p.y > CVR(-4.) - 0.001 && p.x < CVX(-8.) - 0.0005) return 0.05;
        return s > pe ? min(0.25 + 3. * (s - pe), 1.3) : CV_BELT_V * 0.25;
    }
    if(t == CT_FRAME) return p.y < CVR(-13.) && p.x > CVX(-37.) + 0.001 ? 0.05 : (abs(p.x - CVX(-10.)) < 0.001 && p.y > CVR(6.) + 0.001) || (abs(p.x - CVX(-37.)) < 0.001 && p.y < CVR(6.) - 0.001) ? 0.6 : 0.12;
    return CV_BELT_V;
}

// the plinko chute the welded amps fall down into the water: off the end of
// the top belt and down twenty staggered rows of brass pegs, each bounce
// left or right, the chute walls turning them back
const float CV_PLK_X = CVX(30.);
const float CV_PLK_H = CVG(1.2);
const float CV_PLK_W = CVG(0.6);
const int   CV_PLK_N = 20;
float cvPlkDir(int i, int k){ return random(vec2(float(i) * 1.37 + 0.5, float(k) * 7.1 + 3.3)) < 0.5 ? -1. : 1.; }
vec2 cvPlkPos(int i, float s, inout float ang){
    float off = -3. * CV_PLK_W, a = 0.;
    int kk = s < CV_PLK1 ? int(floor(s / CV_PLK_H)) : CV_PLK_N;
    float d = 0.;
    for(int k = 0; k < CV_PLK_N + CVZ; k++){
        d = cvPlkDir(i, k);
        if(abs(off + CV_PLK_W * d) > 3. * CV_PLK_W + 1e-4) d = -d;
        if(k >= kk) break;
        off += CV_PLK_W * d;
        a -= 1.3 * d;
    }
    if(s < CV_PLK1){
        float fr = s / CV_PLK_H - float(kk), hop = kk == 0 ? 0. : 0.5;
        ang = a - 1.3 * d * fr;
        return vec2(CV_PLK_X + off + CV_PLK_W * d * fr, CVR(15.) - CV_PLK_H * float(kk) + CV_PLK_H * (hop * fr - (1. + hop) * fr * fr));
    }
    return vec2(CV_PLK_X + off, cvAt(CT_DROP, s).y);
}

// an amp v of the way through the tumbler: carried up the rising wall by a
// lifter, dropped back to the bottom, again and again on its own beat
vec2 cvDrumLift(float ph, float rin, float tw){
    vec2 d = vec2(cos(ph), sin(ph));
    return CV_DRUM + (CV_DRUMR - CVG(0.5) - rin) * d + tw * vec2(-d.y, d.x);
}
vec2 cvDrumPos(int i, float v, float tt, inout float ang){
    vec4 hr = vec4(random(vec2(float(i) * 3.1, 1.7)), random(vec2(float(i) * 1.9, 4.3)), random(vec2(float(i) * 2.7, 8.1)), random(vec2(float(i) * 5.3, 2.9)));
    float h = fract(0.5 + floor(hr.x * 3.) / 3.);
    float rin = CVG(0.9) * hr.y, tw = CVG(0.4 + 0.35 * hr.z), rel = 0.05 + 0.7 * hr.w;
    float f = fract(tt * CV_DRUM_W / 3.14159 + h), fr = (rel + 1.5708) / 3.14159, a;
    vec2 p;
    if(f < fr){
        float ph = -1.5708 + 3.14159 * f;
        p = cvDrumLift(ph, rin, tw);
        a = ph + 1.5708 + 0.3 * (hr.z - 0.5);
    } else {
        float tc = 3.14159 / CV_DRUM_W, tau = (f - fr) * tc, rest = (1. - fr) * tc, gr = 1.2;
        vec2 p1 = cvDrumLift(rel, rin, tw), p0 = cvDrumLift(-1.5708, rin, tw);
        vec2 v0 = CV_DRUM_W * (CV_DRUMR - CVG(0.5) - rin) * vec2(-sin(rel), cos(rel));
        float tl = min((v0.y + sqrt(v0.y * v0.y + 2. * gr * max(p1.y - p0.y, 0.))) / gr, rest * 0.8);
        float tf = min(tau, tl);
        p = p1 + v0 * tf - vec2(0., 0.5 * gr * tf * tf);
        a = rel + 1.5708 + (8. + 12. * hr.w) * tf;
        if(tau > tl){
            float u = smoothstep(0., 1., (tau - tl) / max(rest - tl, 1e-3));
            float tilt = 0.3 * (hr.z - 0.5);
            p = mix(p, p0, u);
            a = mix(a, tilt + 6.28318 * floor((a - tilt) / 6.28318 + 0.5), u);
        }
    }
    float e0 = smoothstep(0., 0.12, v);
    ang = a * e0;
    return mix(CV_DRUM + vec2(CV_DRUMR - CVG(0.55), 0.), p, e0);
}

// the flick arm over the drum's left edge: reaches in for an amp that has
// tumbled its time, lifts it clear and flings it out onto the exit belt
const vec2 CV_FLK_P = vec2(CVG(19.), CVG(14.) - 0.002);
const vec2 CV_FLK_H = vec2(CVG(22.), CVG(11.));
vec2 cvFlickPos(int i, float x, float tt, inout float ang){
    if(x < 0.3) return cvDrumPos(i, 0.99, tt, ang);
    float a0 = 0.;
    vec2 g = cvDrumPos(i, 0.99, tt - (x - 0.3) * CV_ST_DW[CS_FLICK], a0);
    if(x < 0.55){
        float u = smoothstep(0.3, 0.55, x);
        ang = mix(mod(a0 + 3.14159, 6.28318) - 3.14159, 0., u);
        return mix(g, CV_FLK_H, u);
    }
    float u = (x - 0.55) / 0.45;
    vec2 w = vec2(CVG(8.) + CV_SIZE * 0.42, CVG(10.5));
    if(u < 0.62){
        float a = u / 0.62;
        ang = 9. * a;
        return mix(CV_FLK_H, w, a) + vec2(0., CVG(2.) * a * (1. - a));
    }
    float b = (u - 0.62) / 0.38;
    ang = mix(9., 12.566, smoothstep(0., 1., b));
    return vec2(mix(w.x, CVX(9.), b), mix(w.y, CVR(7.), b * b));
}

const float CV_HOLD[3] = float[](0.6, 0.72, 0.55);
const vec2  CV_PA = vec2(CVG(18.), CVR(-1.));
const vec2  CV_PB = vec2(CVG(13.), CVR(2.));
const vec2  CV_PC = vec2(CVG(8.), CVR(-1.));
const float CV_CATL = CVG(1.6);
const vec2  CV_CATH = vec2(CVG(16.4), CVG(-1.));
const vec2  CV_TABLE = vec2(CVG(13.), CVG(2.));
const float CV_TABLEW = CVG(1.7);
const float CV_GOOP_FIRE = 0.58;
const float CV_GOOP_HIT = 0.6;
const vec2  CV_GUN_T = vec2(CVG(10.2), CVG(0.2));
const float CV_GUN_A = 0.32;
const float CV_GUN_LM = CVG(1.05);
const float CV_GUN_LB = CVG(0.5);

float cvPaintHold(int k){ return k > CS_PRIME && k <= CS_CLEAR ? CV_HOLD[k - CS_PRIME - 1] : -1.; }

float cvCoatP(int k, float x){
    if(k == CS_PRIME + 1) return clamp((x - 0.08) / 0.42, 0., 1.);
    if(k == CS_PRIME + 2) return clamp((x - 0.1) / 0.55, 0., 1.);
    if(k == CS_PRIME + 3) return clamp((x - CV_GOOP_HIT) / 0.05, 0., 1.);
    return x;
}

float cvCatAng(float x){
    float u = clamp((x - CV_HOLD[0]) / 0.05, 0., 1.);
    return 1.75 * (1. - (1. - u) * (1. - u) * (1. - u)) * (1. - smoothstep(0.78, 1., x));
}
vec2 cvCatCup(float th){ return CV_CATH + CV_CATL * vec2(cos(th), sin(th)); }
vec2 cvOnCup(float th){ return cvCatCup(th) + vec2(-sin(th), cos(th)) * (CV_SIZE * 0.5 + 0.003); }

float cvTilt(float x){ return 0.26 * smoothstep(CV_HOLD[1], CV_HOLD[1] + 0.07, x) * (1. - smoothstep(0.86, 1., x)); }
vec2 cvOnTable(float lx, float tl){ return CV_TABLE + Rot(-tl) * vec2(lx, CVR(2.) - CVG(2.)); }

float cvGunRecoil(float x){
    if(x < CV_GOOP_FIRE) return 0.;
    return CVG(0.45) * (1. - exp(-(x - CV_GOOP_FIRE) * CV_ST_DW[CS_CLEAR] * 150.)) * (1. - smoothstep(CV_GOOP_FIRE + 0.08, 0.97, x));
}
vec2 cvGunU(){ return vec2(cos(CV_GUN_A), sin(CV_GUN_A)); }
vec2 cvGunMuzzle(float x){ return CV_GUN_T - cvGunU() * (CV_GUN_LM - cvGunRecoil(x)); }
vec2 cvGoopImpact(){ return CV_PC + vec2(CV_SIZE * 0.4, CVG(0.12)); }

vec2 cvPaintPos(int k, float x, inout float ang){
    if(k == CS_PRIME + 1){
        float h = CV_HOLD[0], x0 = h + 0.03;
        if(x < h){ ang = 0.; return CV_PA; }
        if(x < x0){ float th = cvCatAng(x); ang = th; return cvOnCup(th); }
        float th0 = cvCatAng(x0), u = (x - x0) / (1. - x0);
        ang = mix(th0, 6.28318, u);
        return mix(cvOnCup(th0), CV_PB, u) + vec2(0., CVG(2.6) * 4. * u * (1. - u));
    }
    if(k == CS_PRIME + 2){
        float tl = cvTilt(x);
        if(x < 0.84){
            float v = clamp((x - CV_HOLD[1] - 0.04) / 0.08, 0., 1.);
            ang = tl;
            return cvOnTable(-CV_TABLEW * v * v, tl);
        }
        float t0 = cvTilt(0.84), u = (x - 0.84) / 0.16;
        vec2 pe = cvOnTable(-CV_TABLEW, t0);
        ang = mix(t0, 6.28318, smoothstep(0., 1., u));
        return vec2(mix(pe.x, CV_PC.x, u), mix(pe.y, CV_PC.y, u * u));
    }
    if(x < CV_GOOP_HIT){ ang = 0.; return CV_PC; }
    vec2 pp = cvStPos(CS_POLISH);
    if(x < 0.85){
        float u = (x - CV_GOOP_HIT) / (0.85 - CV_GOOP_HIT);
        ang = 18.84956 * u;
        return mix(CV_PC, pp, u) + vec2(0., CVG(0.9) * 4. * u * (1. - u));
    }
    float v = (x - 0.85) / 0.15, b = sin(v * 3.14159) * (1. - v);
    ang = -0.35 * b;
    return pp + vec2(CVG(0.14) * b, 0.);
}

// glyph origin of the piece in arm a, `ph` through its weld
vec2 cvArmP(int a, float ph){
    float u = smoothstep(0.08, 0.42, ph);
    vec2 st = CV_PICK[a] - CV_PO[CV_ARMK[a]] * CV_SIZE;
    return mix(st, CV_JOIN[a], u) + vec2(0., 0.012 * sin(3.14159 * u));
}

vec2 cvArmTip(int a, float ph, bool busy){
    vec2 grip = CV_GRIP[CV_ARMK[a]] * CV_SIZE;
    vec2 st = CV_PICK[a] - CV_PO[CV_ARMK[a]] * CV_SIZE + grip;
    vec2 home = st + vec2(0., a == 0 ? -0.025 : 0.02);
    if(!busy) return home;
    if(ph < 0.08) return mix(home, st, smoothstep(0., 0.08, ph));
    if(ph < 0.78) return cvArmP(a, ph) + grip;
    return mix(CV_JOIN[a] + grip, home, smoothstep(0.78, 1., ph));
}

float cvFit(float asp){ return min(0.5 * asp / CV_HALF_W, 0.5 / CV_HALF_H); }

// ---- drawing ------------------------------------------------------------------

vec4 cvState(int x, int y){ return texelFetch(iChannel17, ivec2(x, y), 0); }

float cvHash(float n){ return fract(sin(n * 127.1) * 43758.5453); }

vec3 cvLavaRamp(float t){
    vec3 c = mix(vec3(0.05, 0.008, 0.004), vec3(0.45, 0.04, 0.01), smoothstep(0., 0.3, t));
    c = mix(c, vec3(1.2, 0.3, 0.03), smoothstep(0.25, 0.6, t));
    c = mix(c, vec3(1.7, 0.95, 0.25), smoothstep(0.55, 0.85, t));
    return mix(c, vec3(1.9, 1.7, 1.1), smoothstep(0.85, 1., t));
}

// molten metal: a dark crust broken by bright cracks that drift and churn;
// `heat` 1 is all liquid, 0 a cold crust
vec3 cvLava(vec2 p, float heat){
    vec2 w = p * 70. + vec2(iTime * 0.35, -iTime * 0.2);
    vec2 warp = vec2(tcNoise(w * 0.6 + iTime * 0.4), tcNoise(w * 0.6 - iTime * 0.3 + 5.2));
    float n = tcNoise(w + 1.8 * warp);
    float crack = pow(1. - abs(2. * n - 1.), 5.);
    float body = tcNoise(w * 0.35 - iTime * 0.15);
    float t = mix(0.12 + 0.55 * crack, 0.55 + 0.25 * body + 0.3 * crack, smoothstep(0.55, 1., heat));
    return cvLavaRamp(t * smoothstep(0., 0.35, heat + 0.1 * crack));
}

vec3 cvSparks(vec3 col, vec2 q, vec2 o, vec2 dir, float on, float seed, float spread){
    if(on <= 0. || length(q - o) > 0.16) return col;
    for(int k = 0; k < 14 + CVZ; k++){
        float fk = float(k) + seed;
        float life = 0.35 + 0.3 * cvHash(fk);
        float t = mod(iTime + cvHash(fk + 3.1) * life, life);
        float a = (cvHash(fk + 7.7) - 0.5) * spread;
        vec2 v = Rot(a) * dir * (0.25 + 0.35 * cvHash(fk + 1.3));
        vec2 p = o + v * t + vec2(0., -0.9) * t * t;
        vec2 tail = p - v * 0.03;
        float d = sdSegment(q, p, tail) - 0.0012;
        float fade = 1. - t / life;
        col += vec3(1., 0.7, 0.25) * 1.3 * fade * on * S(d);
    }
    col += vec3(1., 0.6, 0.2) * 0.25 * on * exp(-length(q - o) / 0.012);
    return col;
}

float cvSeg7(vec2 p, int dg){
    const int M[10] = int[](0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F);
    int m = M[clamp(dg, 0, 9)];
    float on = 1e9, off = 1e9;
    vec2 a[7] = vec2[](vec2(0., 0.5), vec2(0.3, 0.25), vec2(0.3, -0.25), vec2(0., -0.5), vec2(-0.3, -0.25), vec2(-0.3, 0.25), vec2(0., 0.));
    for(int k = 0; k < 7 + CVZ; k++){
        bool hz = k == 0 || k == 3 || k == 6;
        float d = sdSegment(p, a[k] - (hz ? vec2(0.22, 0.) : vec2(0., 0.19)), a[k] + (hz ? vec2(0.22, 0.) : vec2(0., 0.19))) - 0.065;
        if(((m >> k) & 1) == 1) on = min(on, d); else off = min(off, d);
    }
    return on < off ? on : off + 10.;
}

// n digits of v, cell h tall, left edge at o
vec3 cvDigits(vec3 col, vec2 q, vec2 o, float h, int n, float v, vec3 lit){
    vec2 p = (q - o) / h;
    float w = 0.8;
    if(p.y < -0.6 || p.y > 0.6 || p.x < -0.1 || p.x > w * float(n)) return col;
    int c = int(floor(p.x / w));
    float dv = floor(v / pow(10., float(n - 1 - c)));
    int dg = int(mod(dv, 10.));
    float d = cvSeg7(vec2(p.x - (float(c) + 0.5) * w, p.y), dg);
    if(d < 5.) col = mix(col, lit, S(d * h));
    else col = mix(col, lit * 0.12, S((d - 10.) * h));
    if(d < 5.) col += lit * 0.25 * exp(-max(d, 0.) * h / 0.006);
    return col;
}


float cvTrapezoid(vec2 p, float r1, float r2, float he){
    vec2 k1 = vec2(r2, he), k2 = vec2(r2 - r1, 2. * he);
    p.x = abs(p.x);
    vec2 ca = vec2(p.x - min(p.x, p.y < 0. ? r1 : r2), abs(p.y) - he);
    vec2 cb = p - k1 + k2 * clamp(dot(k1 - p, k2) / dot(k2, k2), 0., 1.);
    float s = (cb.x < 0. && ca.y < 0.) ? -1. : 1.;
    return s * sqrt(min(dot(ca, ca), dot(cb, cb)));
}

const vec3  CV_SLAB   = vec3(0.165, 0.17, 0.175);
const vec3  CV_HOLE   = vec3(0.042, 0.044, 0.048);
const vec3  CV_MC     = vec3(0.3, 0.31, 0.32);
const vec3  CV_SAND   = vec3(0.46, 0.39, 0.28);
const float CV_TUN    = CV_CELL;
const float CV_TUN_UP = CV_CELL - CV_ROWOFF;
const float CV_RISER  = CVX(-32.);
const vec2  CV_MELT   = vec2(CVX(-26.), CVG(-2.));

float cvCeil(int k){ return CV_ST_Y[k] + CV_TUN + CV_TUN_UP; }

float cvShaft(vec2 q, int k, float w, float h){
    w = CVG(0.5); h *= CV_K;
    return sdBox(q - vec2(CV_ST_X[k], cvCeil(k) + h * 0.5 - 0.003), vec2(w, h * 0.5));
}

vec3 cvMach(vec3 col, float d, float shade){
    col = mix(col, CV_MC * shade, S(d));
    return mix(col, CV_MC * shade * 0.55, S(abs(d) - 0.0006) * 0.7);
}

// the P carved by the J's design gap falls apart into the bowl and the tail
float cvPcut(vec2 g){ return max(sdP(g), PAD - sdJ(g)); }
float cvPmain(vec2 g){ return max(cvPcut(g), CV_PSPLIT - g.y); }
float cvPdot(vec2 g){ return max(cvPcut(g), g.y - CV_PSPLIT); }

float cvMouldD(vec2 g, int kind){ return sdRoundBox(g - CV_MCEN[kind], CV_MHALF[kind], 0.06); }

// ---- moulds: one standard steel flask for every line. The hammer smashes the
// sand and drops the flask through a hatch into the return tunnel; flasks
// and sand ride left and fall down the tower shaft into the blast pit, where
// air jets strip the sand off. A paternoster lifts the flasks through a wash,
// a dryer and the one sand filler into the head of each line; a bucket
// elevator carries the sand from the pit back up to the hopper
const float CV_RET_X   = CVX(-10.);
const float CV_RET_Y   = CVG(7.);
const float CV_DROP_X  = CVX(-37.);
const float CV_PAT_X   = CVX(-35.);
const vec2  CV_PIT     = vec2(CVG(-35.5), CVG(-12.5));
const vec2  CV_PIT_H   = vec2(CVG(1.5), CVG(1.5));
const vec2  CV_HOPPER  = vec2(CVX(-33.), CVG(3.5));
const float CV_SELEV_X = CVX(-31.);
const float CV_FRAME_V = 0.12;
const vec2  CV_WASHY   = vec2(CVG(-9.), CVG(-5.));
const vec2  CV_DRYY    = vec2(CVG(-4.), CVG(0.));
const vec2  CV_FILLY   = vec2(CVG(1.), CVG(2.5));

// an empty flask, open at the top, around glyph point g of a piece's mould
float cvFlask(vec2 g, int kind){
    float md = cvMouldD(g, kind);
    return max(max(md, -(md + 0.1)), g.y - CV_MCEN[kind].y - CV_MHALF[kind].y + 0.04) * CV_DSIZE;
}

float cvCarveReturn(vec2 q){
    float d = sdBox(q - vec2((CV_RET_X + CV_DROP_X) * 0.5, CV_RET_Y), vec2((CV_RET_X - CV_DROP_X) * 0.5 + CVG(0.5), CV_CELL));
    d = min(d, sdBox(q - vec2(CV_RET_X, (CV_TOPY + CV_RET_Y) * 0.5), vec2(CVG(0.5), (CV_TOPY - CV_RET_Y) * 0.5)));
    d = min(d, sdBox(q - vec2(CV_DROP_X, (CV_RET_Y + CV_PIT.y) * 0.5), vec2(CVG(0.5), (CV_RET_Y - CV_PIT.y) * 0.5)));
    d = min(d, sdBox(q - CV_PIT, CV_PIT_H));
    return min(d, sdBox(q - vec2(CV_PAT_X, (CV_TOPY + CV_PIT.y) * 0.5 + 0.01), vec2(CVG(0.5), (CV_TOPY - CV_PIT.y) * 0.5 + 0.01)));
}

// the mould knocked off a piece `f` seconds after the hammer hit its top:
// the shatter transition's log-polar Voronoi round the impact, every shard
// flying out from it, tumbling and falling
vec3 cvShards(vec3 col, vec2 g, float f, float key, int kind){
    vec2 c = vec2(0., CV_MCEN[kind].y + CV_MHALF[kind].y);
    float px = 1. / (iResolution.y * CV_SIZE);
    vec2 rq = g - c - vec2(0., 0.6 * f - 3. * f * f);
    int s0 = int(floor(atan(rq.y, rq.x) / 6.2831853 * SH_SECTORS));
    col += vec3(1., 0.9, 0.7) * 0.5 * exp(-f * 14.) * exp(-length(g - c) / 0.3);
    for(int j = 0; j < SH_RINGS + 2 + CVZ; j++){
        for(int di = -SH_REACH; di <= SH_REACH; di++){
            int i = (s0 + di + 4 * int(SH_SECTORS)) % int(SH_SECTORS);
            vec2 cell = vec2(float(i), float(j - SH_RINGS));
            vec2 cs = shCentre(cell, c, key);
            vec2 dir = cs - c;
            float dl = length(dir);
            vec2 vel = dir / max(dl, 1e-3) * 1.3 * (0.6 + 0.8 * random(cell + key + 2.2)) / (dl + 0.5) + vec2(0., 0.5);
            vec2 off = vel * f + vec2(0., -3.5 * f * f);
            float th = 9. * (random(cell + key + 5.1) - 0.5) * f;
            vec2 rel = g - cs - off;
            float rad = dl * 0.8 + 0.08;
            if(dot(rel, rel) > rad * rad) continue;
            vec2 g0 = cs + mat2(cos(th), -sin(th), sin(th), cos(th)) * rel;
            float md = cvMouldD(g0, kind);
            if(md > 0.) continue;
            vec2 cn;
            vec3 v = shVoronoi(shPolar(g0, c), key + 22., cn);
            if(any(notEqual(v.xy, cell))) continue;
            float lit = 0.5 + 0.5 * cos(th * 1.7 + float(i));
            vec3 pc = CV_SAND * (0.5 + 0.6 * lit);
            float edge = min(-md, v.z * 0.05);
            col = mix(col, pc, smoothstep(0., 2. * px, edge) * (1. - smoothstep(0.45, 0.6, f)));
        }
    }
    return col;
}

// the finish after `stage` airbrush passes: bare metal, primer, base coat,
// the brand gradient, then clear coat with a travelling glint
vec3 cvPaint(int stage, vec2 g, float fi){
    if(stage <= 0) return vec3(0.4, 0.41, 0.43);
    if(stage == 1) return vec3(0.9, 0.9, 0.88);
    if(stage == 2) return GRAD_BOT * 0.85;
    vec3 c = ampGradient(g);
    if(stage >= 4){
        float ph = fract(iTime * 0.35 + fi * 0.37) * 5. - 2.;
        c = c * 1.08 + vec3(0.55) * exp(-pow((g.x + g.y - ph) * 6., 2.));
    }
    return c;
}

vec3 cvGoop(vec2 g, float fi){
    float n = tcNoise(g * 9. + fi);
    return vec3(0.36, 0.21, 0.1) * (0.75 + 0.45 * n) + vec3(0.3, 0.2, 0.1) * 0.6 * exp(-pow((g.x - g.y * 0.3 - 0.1) * 4., 2.));
}

// a mortarboard with a gold tassel, in glyph units of the amp wearing it
vec3 cvCap(vec3 col, vec2 gp){
    gp = (gp - vec2(0., 0.52)) / 1.3 + vec2(0., 0.52);
    float cap = min(sdBox(gp - vec2(0., 0.6), vec2(0.22, 0.08)), sdBox(gp - vec2(0., 0.7), vec2(0.46, 0.03))) * CV_DSIZE * 1.3;
    col = mix(col, vec3(0.01), S(cap - 0.0012) * 0.4);
    col = mix(col, vec3(0.06, 0.06, 0.07) + 0.08 * smoothstep(0.66, 0.73, gp.y), S(cap));
    float tl = min(sdSegment(gp, vec2(0., 0.73), vec2(0.36, 0.71)), sdSegment(gp, vec2(0.36, 0.71), vec2(0.4, 0.45))) * CV_DSIZE * 1.3;
    col = mix(col, vec3(0.85, 0.66, 0.2), S(tl - 0.0006));
    return mix(col, vec3(0.92, 0.72, 0.22), S(length(gp - vec2(0.4, 0.42)) * CV_DSIZE * 1.3 - 0.0016));
}

vec3 cvBox(vec3 col, vec2 bd, int m, float tp, float seed){
    float b = sdRoundBox(bd, vec2(0.0245, 0.0215), 0.002);
    if(b > 0.004) return col;
    col = mix(col, vec3(0.02), S(b - 0.002) * 0.5);
    vec3 cb = vec3(0.5, 0.36, 0.21) * (0.92 + 0.08 * tcNoise(bd * 400.));
    cb *= 1. - 0.25 * S(abs(bd.y - 0.012) - 0.0006);
    if(tp > 0.){
        float grow = smoothstep(0.15, 0.75, tp);
        float cx = (cvHash(seed + 1.) - 0.5) * 0.004 + (cvHash(seed) - 0.5) * 0.25 * bd.y;
        float y0 = 0.0225, y1 = y0 - 0.045 * grow;
        float tape = max(abs(bd.x - cx) - 0.0046 - 0.0005 * sin(bd.y * 1300. + seed * 7.), max(bd.y - y0, y1 - bd.y + 0.0006 * sin(bd.x * 1500. + seed)));
        cb = mix(cb, vec3(0.7, 0.58, 0.38) * (0.9 + 0.12 * tcNoise(bd * 700.)), S(tape) * 0.95);
        cb = mix(cb, vec3(0.84, 0.74, 0.54), S(abs(bd.x - cx - 0.002) - 0.0005) * S(tape) * 0.5);
    }
    if(((m >> CS_LABEL) & 1) == 1){
        vec2 lp = bd - vec2(0., -0.007);
        cb = mix(cb, vec3(0.88), S(sdRoundBox(lp, vec2(0.0115, 0.008), 0.001)));
        cb = mix(cb, GRAD_TOP * 0.9, S(glyphDist(lp / 0.012) * 0.012));
    }
    col = mix(col, cb, S(b));
    return mix(col, vec3(0.28, 0.19, 0.1), S(abs(b) - 0.0008));
}

float cvStressK(vec4 st){ return st.x >= 0. ? smoothstep(0.1, 0.4, st.x) * (1. - smoothstep(0.7, 0.95, st.x)) : 0.; }

vec3 cvTowerFlask(vec3 col, vec2 q, vec2 c, float id, float dirt, float wet, float fill);

// a returning flask at p: caked in sand until the blast pit, then on the
// paternoster wet from the wash, drying, filling with fresh sand
vec3 cvFrameItem(vec3 col, vec2 q, vec2 p, float id){
    vec3 st = vec3(1., 0., 0.);
    bool pat = abs(p.x - CV_PAT_X) < 0.001 && p.y > CVR(-13.6) + 0.001;
    if(pat) st = vec3(0.15 * (1. - smoothstep(CV_PIT.y, CV_WASHY.x, p.y)),
                      smoothstep(CV_WASHY.x, CV_WASHY.x + 0.03, p.y) * (1. - smoothstep(CV_DRYY.x, CV_DRYY.y, p.y)),
                      smoothstep(CV_FILLY.x, CV_FILLY.y, p.y));
    else if(p.y < CVR(-13.)) st.x = 1. - 0.85 * smoothstep(0.05, 0.9, (p.x - CV_DROP_X) / (CV_PAT_X - CV_DROP_X));
    vec2 c = p + vec2(0., (CV_MCEN[0].y - CV_MHALF[0].y) * CV_SIZE);
    if(pat) col = cvMach(col, sdBox(q - c + vec2(0., 0.002), vec2(0.014, 0.0015)), 0.7);
    return cvTowerFlask(col, q, c, id, st.x, st.y, st.z);
}

// one item: a molten, rough, knocked-out piece, the J as the others are welded
// on, painted pass by pass, then a box, taped and labelled
vec3 cvItem(vec3 col, vec2 q, int i){
    vec4 r0 = cvState(i, 0), r1 = cvState(i, 1);
    int t = cvI(r1.x);
    if(t < 0) return col;
    vec2 d = (q - r0.xy) / CV_M;
    if(dot(d, d) > 0.0056) return col;
    int m = cvI(r1.w);
    float s = r1.y, fi = float(i);
    int kind = cvI(r0.w) & 3;
    if(kind == CV_KFRAME) return cvFrameItem(col, q, r0.xy, fi);
    bool rej = ((cvI(r0.w) >> 2) & 1) == 1;
    int li = cvLineOfKind(kind);
    bool line = cvLineOfTrack(t) >= 0;
    bool arm = t == CT_ARM1 || t == CT_ARM2;
    bool ground = ((m >> (3 + li)) & 1) == 1;
    if(((m >> CS_BOX) & 1) == 1){
        vec4 tst = cvState(CS_TAPE, CV_ROW);
        float tp = ((m >> CS_TAPE) & 1) == 1 ? 1. : cvI(tst.y) == i && tst.x >= 0. ? tst.x : 0.;
        return cvBox(col, (Rot(r0.z) * d - vec2(0., -0.0015 * CV_AMPK)) / CV_AMPK, m, tp, fi);
    }

    float hp = -1.;
    if(line && !ground){
        vec4 hs = cvState(3 + li, CV_ROW);
        if(cvI(hs.y) == i && hs.x >= 0.) hp = hs.x;
    }
    bool shat = hp >= CV_HIT;
    float pour = 1.;
    if(line && ((m >> li) & 1) == 0){
        vec4 ps = cvState(li, CV_ROW);
        pour = ps.w > float(cvBatchN(li)) - 0.5 && cvBatchSlot(li, s) >= 0 ? clamp(ps.x * 1.25 - 0.1, 0., 1.) : 0.;
    }
    vec2 gp = Rot(r0.z) * d / CV_DSIZE;
    if(t == CT_FIN){
        vec4 sq = cvState(CS_SQUEEZE, CV_ROW), sr = cvState(CS_STRETCH, CV_ROW);
        if(cvI(sq.y) == i) gp = (gp + vec2(0., 0.55)) * vec2(1. + 0.6 * cvStressK(sq), 1. - 0.15 * cvStressK(sq)) - vec2(0., 0.55);
        if(cvI(sr.y) == i) gp = (gp - vec2(0., 0.55)) * vec2(1. + 0.2 * cvStressK(sr), 1. / (1. + 0.4 * cvStressK(sr))) + vec2(0., 0.55);
    }
    vec2 g = arm ? gp : gp + CV_PO[kind];
    float dd;
    if(kind == 0){
        bool w1 = ((m >> CS_WELD1) & 1) == 1, w2 = ((m >> CS_WELD2) & 1) == 1;
        dd = w2 ? glyphDist(g) : w1 ? min(sdJ(g), cvPdot(g)) : sdJ(g);
    }
    else if(kind == 1) dd = cvPmain(g);
    else dd = cvPdot(g);
    if(line && !ground && !shat) dd += (tcNoise(g * 16. + fi * 3.7) - 0.5) * 0.06;
    dd *= CV_DSIZE;

    float heat = line ? clamp(1. - (s - cvSAtSt(li)) / 0.45, 0., 1.) * pour : 0.;
    int stage = 0;
    for(int k = CS_PRIME; k <= CS_CLEAR + CVZ; k++) stage += (m >> k) & 1;
    vec3 c = cvPaint(stage, g, fi);
    float blk = 0.;
    if(kind == 0 && ((m >> CS_WELD2) & 1) == 1 && stage == 0 && (t == CT_J || t == CT_DROP || t == CT_MAIN)){
        float soot = 0.;
        if(t == CT_MAIN){
            float h0 = cvSAtP(CT_MAIN, vec2(CVX(3.), CVR(-10.))), h1 = cvSAtP(CT_MAIN, vec2(CVG(10.), CVR(-4.)));
            soot = 0.85 * clamp((s - h0) / (h1 - h0), 0., 1.);
            vec4 cs = cvState(CS_CAUSTIC, CV_ROW);
            float dk = ((m >> CS_CAUSTIC) & 1) == 1 ? 1. : cs.x >= 0. && cvBatchSlot(CS_CAUSTIC, s) >= 0 ? smoothstep(0.3, 0.75, cs.x * CV_ST_DW[CS_CAUSTIC] / 3.) : 0.;
            soot = mix(soot, 0.97, dk);
        }
        blk = smoothstep(0.85, 0.97, soot);
        vec3 tg = mix(vec3(0.13, 0.12, 0.11), vec3(0.06, 0.058, 0.056), blk);
        c = mix(c, tg * (0.8 + 0.4 * tcNoise(g * 12. + fi)), soot);
    }
    if(t == CT_MAIN){
        vec2 np = cvAt(t, s);
        float cov = 0., dry = 0.;
        if(abs(np.y - CVR(9.)) < 0.001 && np.x < CVG(24.)) cov = clamp((CVG(24.) - np.x) / CVG(0.3), 0., 1.);
        if(cvDripAt(np)){
            cov = 1.;
            dry = clamp((np.x - CVX(9.)) / CVG(10.), 0., 1.);
        }
        vec3 wet = vec3(0.8, 0.8, 0.79) + 0.18 * exp(-pow((g.x + g.y - 0.3) * 5., 2.));
        c = mix(c, mix(wet, cvPaint(1, g, fi), dry), cov);
    }
    if(line && !ground && !shat) c = vec3(0.36, 0.37, 0.39) * (0.8 + 0.25 * tcNoise(g * 30.));
    if(stage < 4){
        vec4 sp = cvState(CS_PRIME + stage, CV_ROW);
        if(cvI(sp.y) == i && sp.x >= 0.){
            float cp = cvCoatP(CS_PRIME + stage, sp.x);
            float cov = stage == 3 ? smoothstep(0.08, -0.08, length(gp - vec2(0.5, 0.15)) + 0.3 * (tcNoise(gp * 6. + fi) - 0.5) - 2.4 * cp) : smoothstep(-0.04, 0.04, gp.y - (0.6 - 1.25 * cp));
            c = mix(c, stage == 3 ? cvGoop(g, fi) : cvPaint(stage + 1, g, fi), cov);
        }
    }
    if(stage >= 4 && ((m >> cvBit(CS_POLISH)) & 1) == 0){
        vec4 ps = cvState(CS_POLISH, CV_ROW);
        float rev = cvI(ps.y) == i && ps.x >= 0. ? smoothstep(-0.05, 0.05, -0.6 + 1.25 * smoothstep(0.15, 0.85, ps.x) - gp.y) : 0.;
        c = mix(cvGoop(g, fi), c, rev);
    }
    if(((m >> CS_STAMP) & 1) == 1) c = mix(c, vec3(0.95), S(length(g - vec2(0.17, 0.12)) * CV_DSIZE - 0.0028) * 0.9);
    if(rej && ((m >> CS_SCAN) & 1) == 1) c = mix(c, vec3(0.8, 0.12, 0.08), 0.55);
    vec3 hot = cvLavaRamp(0.35 + 0.55 * heat);
    c = mix(c * (1. - 0.5 * smoothstep(0., 0.3, heat)), cvLava(g * CV_SIZE * 1.4 + fi * 0.37, heat * 1.1), smoothstep(0.02, 0.35, heat));

    if(shat) col = cvShards(col, gp, (hp - CV_HIT) * CV_ST_DW[3 + li], fi * 1.37 + floor(s * 10.), kind);
    if(shat) col = cvTowerFlask(col, q, r0.xy + vec2(0., (CV_MCEN[0].y - CV_MHALF[0].y) * CV_SIZE), fi, 1., 0., 0.);
    if(line && !ground && !shat){
        float mould = cvMouldD(gp, kind) * CV_DSIZE;
        vec2 mc = CV_MCEN[kind], mh = CV_MHALF[kind];
        float sandTop = mc.y + mh.y, cav = 1.;
        if(((m >> (CS_PRESS + li)) & 1) == 0){
            vec4 pr = cvState(CS_PRESS + li, CV_ROW);
            cav = cvI(pr.y) == i && pr.x >= 0. ? smoothstep(0.3, 0.55, pr.x) : 0.;
        }
        float inner = mould + 0.004;
        col = mix(col, CV_HOLE * 1.4, S(mould));
        col = mix(col, CV_SAND * (0.62 + 0.12 * tcNoise(gp * 40. + fi)), S(max(inner, (gp.y - sandTop) * CV_DSIZE)));
        float wall = max(max(mould, -inner), (gp.y - mc.y - mh.y + 0.04) * CV_DSIZE);
        col = mix(col, CV_MC * 0.85, S(wall));
        float fill = mix(CV_MCEN[kind].y - CV_MHALF[kind].y, CV_MCEN[kind].y + CV_MHALF[kind].y, pour);
        if(gp.y > fill) return mix(col, vec3(0.06, 0.05, 0.04), S(dd) * 0.85 * cav);
    }
    vec4 xr = cvState(CS_XRAY, CV_ROW);
    if(t == CT_J && cvI(xr.y) == i && xr.x >= 0.){
        float on = smoothstep(0., 0.15, xr.x) * (1. - smoothstep(0.85, 1., xr.x));
        col = mix(col, mix(c, vec3(0.04, 0.1, 0.13), on), S(dd));
        col += vec3(0.35, 0.9, 1.) * on * (S(abs(dd) - 0.0006) + 0.25 * exp(-abs(dd) / 0.003));
        for(int w = 0; w < 2 + CVZ; w++) col += vec3(0.7, 1., 1.) * on * 0.8 * exp(-length(g - CV_SEAM[w]) / 0.07) * S(dd - 0.002);
        return col;
    }
    col += hot * 0.35 * heat * exp(-max(dd, 0.) / 0.008);
    col = mix(col, vec3(0.01), S(dd - 0.0015) * 0.35);
    col = mix(col, c, S(dd));
    col += vec3(0.24, 0.25, 0.27) * blk * S(abs(dd + 0.0005) - 0.00045);

    if(t == CT_PACK && kind == 0 && ((m >> cvBit(CS_HAT)) & 1) == 1) col = cvCap(col, gp);
    vec4 bx = cvState(CS_BOX, CV_ROW);
    if(cvI(bx.y) == i && bx.x >= 0.){
        float p = bx.x;
        vec2 bd = (d - vec2(0., -0.0015 * CV_AMPK)) / CV_AMPK;
        float b = sdRoundBox(bd, vec2(0.0245, 0.0215), 0.002);
        col = mix(col, vec3(0.5, 0.36, 0.21) * (0.92 + 0.08 * tcNoise(bd * 400.)), S(b));
        col = mix(col, vec3(0.28, 0.19, 0.1), S(abs(b) - 0.0008));
        float fl = smoothstep(0.1, 0.8, p);
        for(int sd = -1; sd <= 1 + CVZ; sd += 2){
            vec2 hinge = vec2(0.0245 * float(sd), 0.02);
            vec2 tip = hinge + Rot(float(sd) * (1. - fl) * 1.4) * vec2(-0.024 * float(sd), 0.);
            col = mix(col, vec3(0.42, 0.3, 0.17), S(sdSegment(d, hinge, tip) - 0.0016));
        }
    }
    return col;
}

// ---- the slab: one grey block with the tunnels cut out of it -------------------

float cvCarve(vec2 q){
    float d = 1e9;
    for(int t = 0; t < CV_NT + CVZ; t++){
        for(int k = 1; k < CV_MAXP + CVZ; k++){
            if(k >= CV_TN[t]) break;
            vec2 a = CV_PTS[CV_T0[t] + k - 1], b = CV_PTS[CV_T0[t] + k];
            vec2 lo = floor((min(a, b) - vec2(CVG(0.5), CV_ROWOFF)) / CV_CELL + 0.02) * CV_CELL;
            vec2 hi = ceil((max(a, b) + vec2(CVG(0.5), CVG(2.) - CV_ROWOFF)) / CV_CELL - 0.02) * CV_CELL;
            if(abs(a.y - b.y) > CVG(1.)) hi.y = ceil((max(a.y, b.y) - CV_ROWOFF) / CV_CELL + 0.98) * CV_CELL;
            if((t == CT_MAIN && k == 9) || (t == CT_FIN && k < 3)) continue;
            d = min(d, sdBox(q - (lo + hi) * 0.5, (hi - lo) * 0.5));
        }
    }
    d = min(d, sdBox(q - CVG(0.5) * (CV_WELDROOM.xy + CV_WELDROOM.zw), CVG(0.5) * (CV_WELDROOM.zw - CV_WELDROOM.xy)));
    d = min(d, sdBox(q - vec2(CVG(17.5), CVG(-13.)), vec2(CVG(15.5), CVG(2.))));
    d = min(d, sdBox(q - vec2(CVG(15.), CVG(-7.)), vec2(CVG(4.), CVG(3.))));
    d = min(d, sdBox(q - vec2(CVG(23.5), CVG(-6.)), vec2(CVG(3.5), CVG(4.))));
    d = min(d, sdBox(q - vec2(CVG(19.5), CVG(-3.)), vec2(CVG(1.5), CVG(1.))));
    d = min(d, sdBox(q - vec2(CVG(30.5), CVG(2.5)), vec2(CVG(2.5), CVG(14.5))));
    d = min(d, cvShaft(q, CS_GRIND, 0.016, 0.035));
    for(int j = 0; j < 5 + CVZ; j++) d = min(d, sdBox(q - vec2(CVG(-3.), CV_ST_Y[CV_QC_K[j]]), vec2(CVG(1.), CVG(1.))));
    d = min(d, cvShaft(q, 3, 0.017, 0.02));
    d = min(d, cvShaft(q, 4, 0.017, 0.03));
    d = min(d, cvShaft(q, 5, 0.017, 0.02));
    d = min(d, cvShaft(q, CS_TAPE, 0.016, 0.03));
    d = min(d, cvShaft(q, CS_LABEL, 0.013, 0.04));
    d = min(d, sdBox(q - vec2(CVG(-18.), CVG(-1.)), vec2(CVG(11.), CVG(3.))));
    d = min(d, sdBox(q - vec2(CVG(-11.), CVG(-10.)), vec2(CVG(4.), CVG(5.))));
    d = min(d, sdBox(q - vec2(CVG(-17.5), CVG(-10.)), vec2(CVG(1.5), CVG(5.))));
    d = min(d, sdBox(q - vec2(CVG(11.), CVG(2.)), vec2(CVG(12.), CVG(3.))));
    d = min(d, sdBox(q - vec2(CVG(21.5), CVG(6.)), vec2(CVG(1.5), CVG(1.))));
    d = min(d, sdBox(q - vec2(CVG(25.5), CVG(2.)), vec2(CVG(1.5), CVG(4.))));
    d = min(d, sdBox(q - vec2(CVG(17.5), CVG(10.)), vec2(CVG(9.5), CVG(4.))));
    for(int j = 0; j < 3 + CVZ; j++) d = min(d, sdBox(q - vec2(CVG(6.), CVG(-9. + 3. * float(j))), vec2(CVG(4.), CVG(1.))));
    d = min(d, cvCarveReturn(q));
    for(int li = 0; li < 3 + CVZ; li++) d = min(d, cvShaft(q, CS_PRESS + li, 0.016, li == 1 ? 0.03 : 0.02));
    float xr = CVG(20.) + (CVG(7.) - q.y) / 3.;
    d = max(d, -max(max((q.x - xr) * 0.949, CVG(20.) - q.x), max(CVG(1.) - q.y, q.y - CVG(7.))));
    d = max(d, -sdBox(q - vec2(CVG(-18.5), CVG(-11.5)), vec2(CVG(0.5), CVG(0.5))));
    d = max(d, -max(sdBox(q - vec2(CVG(5.5), CVG(2.)), vec2(CVG(0.5), CVG(3.))), -sdBox(q - vec2(CVG(5.5), CVG(0.5)), vec2(CVG(0.6), CVG(0.5)))));
    d = max(d, -max(sdBox(q - vec2(CVG(10.5), CVG(2.)), vec2(CVG(0.5), CVG(3.))), -sdBox(q - vec2(CVG(10.5), CVG(2.)), vec2(CVG(0.6), CVG(1.)))));
    d = max(d, -max(sdBox(q - vec2(CVG(15.5), CVG(2.)), vec2(CVG(0.5), CVG(3.))), -sdBox(q - vec2(CVG(15.5), CVG(2.)), vec2(CVG(0.6), CVG(2.)))));
    d = max(d, -sdBox(q - vec2(CVG(-10.5), CVG(0.)), vec2(CVG(0.5), CVG(2.))));
    d = min(d, sdBox(q - vec2(CVG(-6.5), CVG(1.5)), vec2(CVG(0.5), CVG(0.5))));
    d = max(d, -sdBox(q - vec2(CVG(-9.5), CVG(-1.5)), vec2(CVG(1.5), CVG(0.5))));
    return max(d, -sdBox(q - vec2(CVG(19.5), CVG(6.5)), vec2(CVG(0.5), CVG(0.5))));
}

vec3 cvSlab(vec2 q, vec2 tp, float carve);

vec3 cvWallHoles(vec3 col, vec2 q, vec2 tp){
    if(q.x < CVG(-9.) || q.x > CVG(16.) || q.y < CVG(-5.) || q.y > CVG(4.)) return col;
    float vent = sdBox(q - vec2(CVG(-6.5), CVG(1.5)), vec2(CVG(0.5), CVG(0.5)));
    float h = min(min(sdBox(q - vec2(CVG(5.5), CVG(0.5)), vec2(CVG(0.5), CVG(0.5))), sdBox(q - vec2(CVG(10.5), CVG(2.)), vec2(CVG(0.5), CVG(1.)))), sdBox(q - vec2(CVG(15.5), CVG(2.)), vec2(CVG(0.5), CVG(2.))));
    h = min(h, min(vent, sdBox(q - vec2(CVG(-7.5), CVG(-1.5)), vec2(CVG(0.5), CVG(0.5)))));
    h = min(h, sdBox(q - vec2(CVG(-7.5), CVG(-4.5)), vec2(CVG(0.5), CVG(0.5))));
    if(h > 0.) return col;
    vec3 back = cvSlab(q, tp, 1.) * vec3(0.6, 0.6, 0.66) * mix(0.55, 1., smoothstep(0., CVG(0.35), -h));
    col = mix(col, back, S(h));
    return mix(col, CV_MC * 0.85, S(max(vent, abs(fract((q.y - CVG(1.)) / CVG(0.2)) - 0.5) * CVG(0.2) - 0.0012)));
}

vec3 cvSlab(vec2 q, vec2 tp, float carve){
    float pp = CVG(1.) / 10.;
    vec2 pix = floor(q / pp), ip = mod(pix, 10.), id = floor(pix / 10.);
    float h = cvHash(id.x * 17.3 + id.y * 91.7), h2 = cvHash(id.x * 5.1 + id.y * 33.3 + 7.);
    float r = cvHash(pix.x * 1.37 + pix.y * 91.13);
    float brush = 0.82 + 0.3 * tcNoise(vec2(q.x * 30. + id.y * 7.3, pix.y * 1.7)) + 0.08 * (cvHash(pix.y * 3.1 + id.x * 1.7) - 0.5);
    float sheen = 0.88 + 0.24 * (1. - (ip.x + 9. - ip.y) / 18.);
    vec3 base = vec3(0.13, 0.135, 0.145) * (0.92 + 0.16 * h) * mix(vec3(1.), vec3(0.97, 1., 1.03), h2) * brush * sheen;
    bool inner = ip.x > 0.5 && ip.x < 8.5 && ip.y > 0.5 && ip.y < 8.5;
    if(h2 > 0.82 && inner && mod(ip.x + ip.y, 3.) < 0.5) base *= 1.3;
    else if(h2 > 0.72 && h2 <= 0.82 && ip.x > 1.5 && ip.x < 7.5 && ip.y > 1.5 && ip.y < 7.5 && mod(ip.y, 2.) > 0.5) base *= 0.35;
    if(ip.x < 0.5 || ip.y > 8.5) base *= 1.35;
    if(ip.x > 8.5 || ip.y < 0.5) base *= 0.55;
    if((abs(ip.x - 1.) < 0.5 || abs(ip.x - 8.) < 0.5) && (abs(ip.y - 1.) < 0.5 || abs(ip.y - 8.) < 0.5)) base = vec3(0.23, 0.24, 0.26);
    if(r < 0.04) base *= 0.85;
    if(tcNoise(id * 0.7 + 3.) > 0.7 && r < 0.25) base = mix(base, vec3(0.19, 0.1, 0.05), 0.35);
    vec3 col = floor(base * 64. + 0.5) / 64.;
    if(carve >= 0. && carve < pp) col = vec3(0.19, 0.195, 0.21);
    float hb = 1. + 0.18 * float(ip.x < 0.5 || ip.y > 8.5) - 0.22 * float(ip.x > 8.5 || ip.y < 0.5);
    float hg = 0.9 + 0.2 * tcNoise(vec2(q.x * 30. + id.y * 7.3, pix.y * 1.7));
    float ao = 0.55 + 0.45 * floor(smoothstep(0., 0.02, -carve) * 4.) / 4.;
    vec3 hole = floor(vec3(0.034, 0.036, 0.04) * (0.9 + 0.2 * h) * hb * hg * ao * 160. + 0.5) / 160.;
    return carve < 0. ? hole : col;
}

vec3 cvBelts(vec3 col, vec2 q){
    for(int t = 0; t < CV_NT + CVZ; t++){
        if(t == CT_DROP || t == CT_REJ || t == CT_SLIDE) continue;
        for(int k = 1; k < CV_MAXP + CVZ; k++){
            if(k >= CV_TN[t]) break;
            vec2 a = CV_PTS[CV_T0[t] + k - 1], b = CV_PTS[CV_T0[t] + k];
            if(abs(a.y - b.y) > 1e-3 || abs(a.x - b.x) < 0.1) continue;
            float y = a.y - CV_SIZE * 0.5 - 0.002;
            float d = sdSegment(q, vec2(a.x, y), vec2(b.x, y)) - 0.002;
            if(d > 0.004) continue;
            if(t == CT_MAIN && abs(a.y - CVR(-4.)) < 0.001 && q.x > CVG(10.)) continue;
            if(t == CT_PACK && a.y < CVR(-14.) && q.x > CVG(-15.) && q.x < CVG(-7.)) continue;
            if(t == CT_FIN && abs(a.y - CVR(-1.)) < 0.001 && q.x > CVG(5.) && q.x < CVG(16.)) continue;
            float bv = t == CT_FIN ? CV_PAINT_V : t == CT_MAIN && cvHeatAt(q) ? CV_BELT_V * 0.5 : (t == CT_MAIN && abs(a.y - CVR(3.)) > 0.001) || t == CT_PACK ? CV_BELT_V * 0.25 : CV_BELT_V;
            if(t == CT_PACK && abs(a.y - CVR(-11.)) < 0.001) bv = 0.12;
            if(t == CT_PACK && a.y > CVR(-4.) - 0.001) bv = 0.05;
            if(t == CT_MAIN && (abs(a.y - CVR(9.)) < 0.001 || abs(a.y - CVR(7.)) < 0.001)) continue;
            float tick = step(0.7, fract((q.x - iTime * bv * sign(b.x - a.x)) / 0.012));
            col = mix(col, CV_MC * (0.55 + 0.15 * tick), S(d));
        }
    }
    return col;
}

// lava veins in the slab: a riser from above feeding a channel over each
// foundry, four nozzles down to its batch of moulds
vec3 cvVeins(vec3 col, vec2 q, float carve){
    if(q.x > CVG(-23.) || q.y < CVG(10.)) return col;
    float fl = 0.85 + 0.15 * tcNoise(vec2(iTime * 5., 3.));
    float ch = 1e9;
    for(int li = 0; li < 3 + CVZ; li++){
        float c = cvCeil(li), y = c + 0.012;
        ch = min(ch, sdSegment(q, vec2(CV_RISER, y), vec2(CV_ST_X[li], y)));
        for(int k = 0; k < 8 + CVZ; k++){
            if(k >= cvBatchN(li)) break;
            float x = CV_ST_X[li] - CV_GAP * float(k);
            ch = min(ch, sdSegment(q, vec2(x, y), vec2(x, c)) - 0.001);
        }
    }
    ch -= 0.003;
    float riser = sdSegment(q, vec2(CV_RISER, 0.8), vec2(CV_RISER, cvCeil(2) + 0.012));
    float inTun = S(carve);
    col = mix(col, CV_MC * 0.7, S(riser - 0.005) * inTun);
    ch = min(ch, max(riser - 0.0035, -carve));
    col += vec3(1., 0.33, 0.06) * 0.1 * fl * exp(-max(ch, 0.) / 0.015) * (1. - inTun);
    col = mix(col, vec3(0.02), S(ch - 0.0015));
    col = mix(col, cvLava(q * 0.8, 0.95) * fl, S(ch));
    return mix(col, cvLava(q * 0.8 + 2., 0.9) * fl, S(riser - 0.002) * inTun * 0.85);
}

vec3 cvStream(vec3 col, vec2 q, vec2 a, vec2 b, float on, float seed){
    if(on <= 0.) return col;
    float d = sdSegment(q, a, b);
    if(d > 0.03) return col;
    float w = 0.0018 * on * (0.85 + 0.15 * sin(q.y * 400. - iTime * 50. + seed));
    vec3 c = cvLavaRamp(0.7 + 0.25 * tcNoise(vec2(q.y * 180. + iTime * 22., seed)) + 0.12 * (1. - smoothstep(0., w, d)));
    col = mix(col, c, S(d - w));
    col += vec3(1., 0.42, 0.1) * 0.2 * on * exp(-max(d - w, 0.) / 0.006);
    return col + vec3(1., 0.5, 0.15) * 0.3 * on * exp(-length(q - b) / 0.01);
}

vec3 cvPours(vec3 col, vec2 q, vec4 st[31]){
    if(q.x > CVG(-23.) || q.y < CVG(9.) || q.y > CVG(18.)) return col;
    for(int li = 0; li < 3 + CVZ; li++){
        vec4 ps = st[li];
        float on = ps.w > float(cvBatchN(li)) - 0.5 ? smoothstep(0.06, 0.12, ps.x) * (1. - smoothstep(0.8, 0.86, ps.x)) : 0.;
        int kind = li == 0 ? 1 : li == 1 ? 0 : 2;
        float bot = CV_ST_Y[li] + (CV_MCEN[kind].y + CV_MHALF[kind].y) * CV_SIZE - 0.004;
        for(int k = 0; k < 8 + CVZ; k++){
            if(k >= cvBatchN(li)) break;
            float x = CV_ST_X[li] - CV_GAP * float(k);
            col = cvStream(col, q, vec2(x, cvCeil(li)), vec2(x, bot), on, float(k + li * 5));
        }
    }
    return col;
}

const vec2 CV_WIND = vec2(CVG(-23.), CVG(-11.));

// a fan at the downstream end of each wind tunnel, behind the moulds,
// blowing back against them
vec3 cvFans(vec3 col, vec2 q){
    if(q.x < CV_WIND.y - 0.06 || q.x > CV_WIND.y + 0.03 || q.y < CVG(9.) || q.y > CVG(18.)) return col;
    for(int li = 0; li < 3 + CVZ; li++){
        vec2 c = vec2(CV_WIND.y - CVG(0.5), CV_ST_Y[li] + CV_TUN_UP);
        vec2 l = q - c;
        float r = length(l), R = CV_TUN * 0.85;
        if(r > R + 0.004) continue;
        float a = atan(l.y, l.x) - iTime * 22.;
        float blades = abs(sin(a * 2.5)) * R;
        col = mix(col, CV_HOLE * 0.6, S(r - R));
        col = mix(col, CV_MC * 0.45, S(max(r - blades, r - R * 0.92)) * 0.6);
        col = mix(col, CV_MC * 0.6, S(abs(r - R) - 0.0012));
        col = mix(col, CV_MC * 0.7, S(r - 0.004));
    }
    return col;
}

// streaks of air blowing back through each wind tunnel, over the moulds
vec3 cvWind(vec3 col, vec2 q){
    if(q.x < CV_WIND.x || q.x > CV_WIND.y || q.y < CVG(9.) || q.y > CVG(18.)) return col;
    float fade = smoothstep(CV_WIND.x, CV_WIND.x + 0.08, q.x) * smoothstep(CV_WIND.y, CV_WIND.y - 0.03, q.x);
    for(int li = 0; li < 3 + CVZ; li++){
        float y0 = CV_ST_Y[li] - CV_SIZE * 0.5, y1 = cvCeil(li) - 0.004;
        if(q.y < y0 - 0.004 || q.y > y1 + 0.004) continue;
        for(int k = 0; k < 7 + CVZ; k++){
            float fk = float(k + li * 7);
            float y = mix(y0, y1, (float(k) + 0.5) / 7.) + 0.003 * sin(q.x * 45. + iTime * 4. + fk * 1.7);
            float u = (q.x + iTime * (0.55 + 0.25 * cvHash(fk))) / (0.07 + 0.05 * cvHash(fk + 3.));
            float f = fract(u + cvHash(fk + 7.));
            float dash = smoothstep(0., 0.15, f) * (1. - smoothstep(0.4, 0.75, f)) * step(0.35, cvHash(floor(u) + fk * 13.));
            col += vec3(0.75, 0.9, 1.) * 0.22 * fade * dash * S(abs(q.y - y) - 0.0006);
        }
        vec2 mp = vec2((q.x + iTime * 0.7) * 180., (q.y - y0) * 180.);
        vec2 mc = floor(mp), mf = fract(mp) - 0.5;
        float mote = step(0.93, random(mc + float(li) * 9.1)) * S(length(mf) / 180. - 0.0007);
        col += vec3(0.8, 0.9, 1.) * 0.25 * fade * mote * step(q.y, y1);
    }
    return col;
}

// the heater room: three storeys of slow belt between glowing heater walls,
// steam lifting off the wet amps
vec3 cvHeater(vec3 col, vec2 q, float carve){
    if(q.x < CVG(2.) || q.x > CVG(10.) || q.y < CVG(-10.) || q.y > CVG(-2.)) return col;
    float fl = 0.85 + 0.15 * sin(iTime * 2. + q.y * 30.);
    col += vec3(1., 0.35, 0.06) * 0.14 * fl * S(carve);
    for(int s = 0; s < 2 + CVZ; s++){
        float x = s == 0 ? CVG(2.) + 0.003 : CVG(10.) - 0.003;
        col = mix(col, vec3(1.3, 0.4, 0.06) * fl, S(sdBox(q - vec2(x, CVG(-6.)), vec2(0.0016, CVG(3.8)))) * S(carve));
        col += vec3(1., 0.35, 0.06) * 0.15 * fl * exp(-abs(q.x - x) / 0.01);
    }
    for(int j = 0; j < 8 + CVZ; j++){
        float a = fract(iTime * 0.5 + float(j) / 8.);
        vec2 sc = vec2(CVG(3.) + CVG(6.) * fract(float(j) * 0.37 + iTime * 0.03), CVG(-9.5) + a * CVG(7.));
        col = mix(col, vec3(0.75), S(length(q - sc) - 0.003 - a * 0.004) * 0.1 * (1. - a) * S(carve));
    }
    return col;
}

// the stress test on the quality-control run: two plates drop beside each
// amp and squeeze it thin, then a gripper takes its head and pulls it tall
// while the belt holds its feet; a gauge by each rig reads the load
vec3 cvStress(vec3 col, vec2 q, vec4 sq, vec4 sr){
    for(int g = 0; g < 2 + CVZ; g++){
        int k = g == 0 ? CS_SQUEEZE : CS_STRETCH;
        vec4 st = g == 0 ? sq : sr;
        vec2 a = cvStPos(k);
        if(abs(q.x - a.x) > 0.06 || abs(q.y - a.y) > 0.07) continue;
        float c = cvCeil(k);
        float x = st.x >= 0. ? st.x : 0.;
        float kk = cvStressK(st);
        float drop = smoothstep(0., 0.12, x) * (1. - smoothstep(0.92, 1., x));
        float foot = a.y - CV_SIZE * 0.55;
        if(g == 0){
            float w = CV_SIZE * 0.4 / (1. + 0.6 * kk) + 0.0018;
            float py = mix(c + 0.006, a.y + 0.002, drop);
            col = cvMach(col, sdBox(q - vec2(a.x, c + 0.004), vec2(w + 0.003, 0.0018)), 0.7);
            for(int s = -1; s <= 1 + CVZ; s += 2){
                float px = a.x + float(s) * w;
                col = cvMach(col, sdBox(q - vec2(px, (py + c + 0.004) * 0.5), vec2(0.0007, (c + 0.004 - py) * 0.5)), 0.75);
                col = cvMach(col, sdBox(q - vec2(px + float(s) * 0.0008, py), vec2(0.0013, 0.0105)), 1.05);
            }
        } else {
            float top = foot + CV_SIZE * 1.1 * (1. + 0.4 * kk);
            float hy = mix(c + 0.004, top + 0.002, drop);
            col = cvMach(col, sdBox(q - vec2(a.x, (hy + c + 0.01) * 0.5), vec2(0.0016, (c + 0.01 - hy) * 0.5)), 0.75);
            col = cvMach(col, sdBox(q - vec2(a.x, hy + 0.002), vec2(0.008, 0.0022)), 1.05);
            for(int s = -1; s <= 1 + CVZ; s += 2)
                col = cvMach(col, sdSegment(q, vec2(a.x + float(s) * 0.0065, hy), vec2(a.x + float(s) * (0.0045 - 0.0015 * drop), hy - 0.006)) - 0.0008, 0.9);
            for(int s = -1; s <= 1 + CVZ; s += 2)
                col = cvMach(col, sdBox(q - vec2(a.x + float(s) * 0.0085, foot + 0.0015), vec2(0.0035, 0.0015 + 0.0008 * drop)), 0.9);
        }
        vec2 gc = vec2(a.x + CV_CELL, c + 0.0115);
        float d = length(q - gc);
        col = mix(col, vec3(0.85, 0.83, 0.75), S(d - 0.0095));
        col = mix(col, CV_MC * 0.5, S(abs(d - 0.0095) - 0.0011));
        float na = -1.4 + 2.8 * kk + 0.08 * sin(iTime * 30.) * kk;
        col = mix(col, vec3(0.85, 0.15, 0.08), S(sdSegment(q, gc, gc + vec2(sin(na), cos(na)) * 0.0078) - 0.0008));
        col = mix(col, vec3(0.1), S(d - 0.0016));
        col = mix(col, vec3(0.85, 0.15, 0.08), S(length(q - gc - vec2(0.0068, 0.006)) - 0.0016) * step(0.8, kk));
    }
    return col;
}

vec3 cvBasin(vec3 col, vec2 q, vec2 spl){
    float sp = spl.x;
    vec2 c = vec2(CVG(17.5), CVG(-13.));
    if(abs(q.x - c.x) > 0.5 || q.y < c.y - 0.07 || q.y > c.y + 0.2) return col;
    float pit = sdBox(q - c, vec2(CVG(15.5), CVG(2.)));
    float wave = 0.0015 * sin(q.x * 120. + iTime * 3.) + 0.001 * sin(q.x * 230. - iTime * 5.);
    float liquid = max(pit, q.y - CV_TANK_Y - wave);
    vec3 lc = mix(vec3(0.05, 0.12, 0.16), vec3(0.12, 0.28, 0.34), smoothstep(CVG(-15.), CV_TANK_Y, q.y));
    vec2 bc = floor(q * vec2(90., 1.));
    float rise = fract(iTime * (0.3 + 0.3 * random(bc.xx)) + random(bc.xx + 2.));
    vec2 bp = vec2((bc.x + 0.5) / 90. + 0.004 * sin(rise * 9.), mix(CVG(-15.), CV_TANK_Y, rise));
    float bub = step(0.75, random(bc.xx + 5.)) * S(length(q - bp) - 0.0016);
    col = mix(col, lc, S(liquid) * 0.85);
    col += vec3(0.4, 0.7, 0.8) * 0.3 * bub * step(liquid, 0.);
    col += vec3(0.4, 0.75, 0.85) * 0.35 * S(abs(q.y - CV_TANK_Y - wave) - 0.0008) * step(pit, 0.);
    if(sp < 1.6){
        vec2 o = vec2(spl.y, CV_TANK_Y);
        float fade = 1. - sp / 0.8;
        if(fade > 0.){
            float r = length((q - o) * vec2(1., 5.));
            col += vec3(0.6, 0.85, 0.9) * 0.4 * fade * smoothstep(0.003, 0., abs(r - 0.01 - sp * 0.07)) * step(abs(q.y - o.y), 0.01);
            for(int k = 0; k < 10 + CVZ; k++){
                float fk = float(k);
                float a = (cvHash(fk + 0.3) - 0.5) * 2.;
                vec2 v = vec2(sin(a), cos(a)) * (0.14 + 0.16 * cvHash(fk + 4.1));
                vec2 p = o + v * sp + vec2(0., -1.1) * sp * sp;
                if(p.y < o.y - 0.002) continue;
                col = mix(col, vec3(0.65, 0.85, 0.9), S(length(q - p) - 0.0018 * (1. - 0.5 * sp)) * fade);
            }
        }
        for(int k = 0; k < 5 + CVZ; k++){
            float a = sp - float(k) * 0.12;
            if(a < 0. || a > 1.4) continue;
            vec2 sc = o + vec2(0.006 * sin(a * 5. + float(k)), 0.01 + a * 0.12);
            col = mix(col, vec3(0.75), S(length(q - sc) - 0.006 - a * 0.01) * 0.25 * (1. - a / 1.4));
        }
    }
    return col;
}

// the caustic bath under the rail past the heater: a square pit of sickly
// green lye, bubbling and fuming, boiling up while a batch is dipped
vec3 cvCaustic(vec3 col, vec2 q, vec4 cs){
    vec2 c = vec2(CVG(15.), CVG(-7.)), h = vec2(CVG(4.), CVG(3.));
    if(abs(q.x - c.x) > h.x + 0.01 || q.y < c.y - h.y - 0.01 || q.y > c.y + h.y + 0.06) return col;
    float pit = sdBox(q - c, h);
    float lvl = CVG(-5.4) + 0.0012 * sin(q.x * 140. + iTime * 2.5);
    float liquid = max(pit, q.y - lvl);
    vec3 lc = mix(vec3(0.16, 0.22, 0.04), vec3(0.42, 0.52, 0.1), smoothstep(CVG(-10.), lvl, q.y));
    col = mix(col, lc, S(liquid) * 0.8);
    col += vec3(0.6, 0.75, 0.2) * 0.35 * S(abs(q.y - lvl) - 0.0008) * step(pit, 0.);
    vec2 bc = floor(q * vec2(110., 1.));
    float rise = fract(iTime * (0.4 + 0.4 * random(bc.xx)) + random(bc.xx + 2.));
    vec2 bp = vec2((bc.x + 0.5) / 110. + 0.003 * sin(rise * 9.), mix(CVG(-10.), lvl, rise));
    col += vec3(0.7, 0.85, 0.3) * 0.35 * step(0.6, random(bc.xx + 5.)) * S(length(q - bp) - 0.0016) * step(liquid, 0.);
    float u = cs.x >= 0. ? cs.x * CV_ST_DW[CS_CAUSTIC] / 3. : -1.;
    float boil = u >= 0. ? smoothstep(0.15, 0.25, u) * (1. - smoothstep(0.75, 0.85, u)) : 0.;
    if(boil > 0.){
        col += vec3(0.7, 0.85, 0.3) * 0.4 * boil * step(0.2, random(bc.xx + 9.)) * S(length(q - bp) - 0.0022) * step(liquid, 0.);
        col += vec3(0.75, 0.9, 0.35) * 0.25 * boil * S(abs(q.y - lvl) - 0.002) * step(pit, 0.);
        for(int j = 0; j < 18 + CVZ; j++){
            float fj = float(j);
            float a = fract(iTime * 2.2 + cvHash(fj + 0.4));
            vec2 o = vec2(c.x - h.x + 2. * h.x * cvHash(fj + 3.3 + floor(iTime * 2.2 + cvHash(fj + 0.4))), lvl);
            vec2 p = o + vec2((cvHash(fj + 7.) - 0.5) * 0.03 * a, 0.05 * a - 0.09 * a * a);
            col = mix(col, vec3(0.75, 0.9, 0.35), S(length(q - p) - 0.0012) * boil * (1. - a * 0.5));
        }
    }
    for(int j = 0; j < 6 + CVZ; j++){
        float a = fract(iTime * 0.35 + float(j) / 6.);
        vec2 fc = vec2(c.x - h.x + 2. * h.x * fract(float(j) * 0.41 + 0.2), lvl + 0.004 + a * 0.05);
        fc.x += 0.01 * sin(a * 5. + float(j));
        col = mix(col, vec3(0.55, 0.65, 0.3), S(length(q - fc) - 0.004 - a * 0.008) * 0.14 * (1. - a));
    }
    return col;
}

vec3 cvHangRod(vec3 col, vec2 q, vec2 top, float c){
    if(abs(q.x - top.x) > 0.008) return col;
    col = cvMach(col, sdBox(q - vec2(top.x, (top.y + c) * 0.5), vec2(0.0012, (c - top.y) * 0.5)), 0.8);
    col = cvMach(col, sdBox(q - vec2(top.x, c - 0.002), vec2(0.004, 0.002)), 0.7);
    for(int s = -1; s <= 1 + CVZ; s += 2){
        vec2 f0 = vec2(top.x + 0.003 * float(s), top.y);
        col = cvMach(col, sdSegment(q, f0, f0 + vec2(0.002 * float(s), -0.006)) - 0.0009, 0.9);
    }
    return col;
}

// the gripper arms on the rail out of the heater: one drops from the ceiling
// to take each amp off the top heater belt and runs it along to the pit;
// eight at a time dip their amps into the lye, then swing them over onto the
// centrifuge and let go
vec3 cvHangers(vec3 col, vec2 q, float asp){
    if(q.x < CVG(8.) || q.x > CVG(27.) || q.y < CVG(-10.) || q.y > CVG(-2.)) return col;
    vec4 cs = cvState(CS_CAUSTIC, CV_ROW);
    float T = cs.x >= 0. ? cs.x * CV_ST_DW[CS_CAUSTIC] : -1.;
    float c = CVG(-2.);
    col = cvMach(col, sdBox(q - vec2(CVG(14.), c - 0.001), vec2(CVG(5.), 0.001)), 0.6);
    if(q.x < CVG(19.5)){
        for(int pass = 0; pass < 2 + CVZ; pass++){
            vec4 sl[AG_TEX];
            agSlots(iChannel17, vec2(q.x, pass == 0 ? CVR(-4.) : CVR(-6.8)), asp, sl);
            for(int k = 0; k < AG_SLOTS + CVZ; k++){
                int i = int(sl[k >> 2][k & 3] + 0.5) - 1;
                if(i < 0) break;
                vec4 r0 = cvState(i, 0), r1 = cvState(i, 1);
                if(cvI(r1.x) != CT_MAIN || ((cvI(r1.w) >> CS_CAUSTIC) & 1) == 1) continue;
                vec2 p = r0.xy;
                if(p.x < CVX(9.) + 0.0005 || p.x > CVX(18.) + 0.001 || p.y < CVR(-7.)) continue;
                if(T >= 3. && cvBatchSlot(CS_CAUSTIC, r1.y) >= 0) continue;
                col = cvHangRod(col, q, p + CV_SIZE * 0.55 * vec2(-sin(r0.z), cos(r0.z)), c);
            }
        }
    }
    if(T >= 3. && T < 4.6){
        float e = smoothstep(3., 4.2, T);
        for(int r = 0; r < 8 + CVZ; r++){
            float ph = float(r) * 0.785398;
            vec2 P = mix(vec2(CV_ST_X[CS_CAUSTIC] - float(r) * CV_GAP, CVR(-4.)), CV_HUB + CV_HUBR * vec2(cos(ph), sin(ph)), e);
            float a = e * (mod(ph + 1.5708 + 3.14159, 6.28318) - 3.14159);
            vec2 top = P + CV_SIZE * 0.55 * vec2(-sin(a), cos(a));
            top.y = mix(top.y, c - 0.004, smoothstep(4.2, 4.6, T));
            col = cvHangRod(col, q, top, c);
        }
    }
    return col;
}

// the centrifuge: eight arms on a hub that take the dipped batch, whirl it
// round and fling each amp off as it points right, straight up the shaft
vec3 cvRotor(vec3 col, vec2 q, vec4 cs){
    vec2 h = CV_HUB;
    if(abs(q.x - h.x) > CVG(4.) || q.y < CVG(-10.) || q.y > CVG(-2.)) return col;
    float T = cs.x >= 0. ? cs.x * CV_ST_DW[CS_CAUSTIC] : -1.;
    float th = cvSpin(T), blur = smoothstep(8., CV_SPIN_W, cvSpinW(T));
    col = cvMach(col, sdBox(q - vec2(h.x, (h.y + CVG(-10.)) * 0.5), vec2(0.0045, (h.y - CVG(-10.)) * 0.5)), 0.55);
    col = cvMach(col, sdBox(q - vec2(h.x, CVG(-10.) + 0.0025), vec2(0.018, 0.0025)), 0.6);
    float rr = length(q - h);
    float L = (CV_HUBR - CV_SIZE * 0.55) * (T < 0. ? 0.25 : mix(0.25, 1., smoothstep(3.6, 4.2, T) * (1. - smoothstep(9.7, 10.3, T))));
    col = mix(col, CV_MC * 0.8, 0.3 * blur * S(rr - L));
    for(int r = 0; r < 8 + CVZ; r++){
        float ph = th + float(r) * 0.785398;
        vec2 dir = vec2(cos(ph), sin(ph)), nrm = vec2(-dir.y, dir.x);
        vec2 tip = h + dir * L;
        float sh = 0.95 - 0.35 * blur;
        col = cvMach(col, sdSegment(q, h, tip) - 0.0013, sh);
        float f = T >= 3.6 && T < 9.6 && th < cvRelTheta(r) ? 0.003 : 0.0045;
        col = cvMach(col, sdSegment(q, tip + nrm * f, tip + nrm * f + dir * 0.005) - 0.0008, sh);
        col = cvMach(col, sdSegment(q, tip - nrm * f, tip - nrm * f + dir * 0.005) - 0.0008, sh);
    }
    col = cvMach(col, rr - 0.0075, 1.1);
    return mix(col, vec3(0.08), S(rr - 0.0022));
}

vec3 cvPlinko(vec3 col, vec2 q){
    if(abs(q.x - CV_PLK_X) > CVG(2.5) || q.y < CVG(-11.) || q.y > CVG(16.)) return col;
    float kf = clamp(floor((CVR(15.) - 0.0132 - q.y) / CV_PLK_H + 0.5), 1., float(CV_PLK_N));
    for(int dk = -1; dk <= 1 + CVZ; dk++){
        float k = kf + float(dk);
        if(k < 1. || k > float(CV_PLK_N)) continue;
        float y = CVR(15.) - CV_PLK_H * k - 0.0107 - 0.0025;
        bool odd = mod(k, 2.) > 0.5;
        float x0 = CV_PLK_X + (odd ? 0. : CV_PLK_W);
        float j = clamp(floor((q.x - x0) / (2. * CV_PLK_W) + 0.5), odd ? -1. : -2., 1.);
        vec2 pc = vec2(x0 + j * 2. * CV_PLK_W, y);
        float dd = length(q - pc) - 0.0024;
        col = mix(col, vec3(0.02), S(dd - 0.001) * 0.4);
        col = mix(col, vec3(0.72, 0.56, 0.26), S(dd));
        col = mix(col, vec3(1., 0.92, 0.7), S(length(q - pc - vec2(-0.0007, 0.0008)) - 0.0008));
    }
    return col;
}

// the x-ray booth: a dark lead-lined cell where a beam sweeps each amp and
// shows its welds glowing through; the lamp on top gives the verdict
vec3 cvXray(vec3 col, vec2 q, vec4 st, bool front){
    vec2 c = vec2(CV_ST_X[CS_XRAY], CVG(16.));
    if(abs(q.x - c.x) > CVG(0.8) || abs(q.y - c.y) > CVG(1.)) return col;
    float on = st.x >= 0. ? smoothstep(0., 0.15, st.x) * (1. - smoothstep(0.85, 1., st.x)) : 0.;
    if(!front){
        col = mix(col, vec3(0.01, 0.025, 0.035), 0.75 * S(sdBox(q - c, vec2(CVG(0.6), CVG(1.)))));
        float yb = mix(CVG(16.8), CVG(15.1), fract(max(st.x, 0.) * 2.));
        return col + vec3(0.3, 0.85, 1.) * on * (S(abs(q.y - yb) - 0.0005) * 0.8 + 0.15 * exp(-abs(q.y - yb) / 0.004)) * S(abs(q.x - c.x) - CVG(0.55));
    }
    for(int s = -1; s <= 1 + CVZ; s += 2)
        col = cvMach(col, sdBox(q - vec2(c.x + float(s) * CVG(0.62), c.y), vec2(0.0012, CVG(1.))), 0.6);
    col = cvMach(col, sdBox(q - vec2(c.x, CVG(17.) - 0.0025), vec2(CVG(0.62), 0.0025)), 0.7);
    vec2 lp = vec2(c.x + CVG(0.35), CVG(17.) - 0.0025);
    bool lit = on > 0. || st.z < 2.;
    vec3 lc = on > 0. ? vec3(1., 0.7, 0.2) : st.w > 0.5 ? vec3(1., 0.15, 0.1) : vec3(0.2, 1., 0.35);
    lc = lit ? lc : vec3(0.15);
    col = mix(col, lc, S(length(q - lp) - 0.0016));
    return col + (lit ? lc * 0.3 * exp(-length(q - lp) / 0.004) : vec3(0.));
}

// the grinder: a wheel on a ceiling ram drops onto the seam where the P was
// welded on and grinds it flush in a fan of sparks
vec3 cvGrinder(vec3 col, vec2 q, vec4 st){
    vec2 a = cvStPos(CS_GRIND);
    if(abs(q.x - a.x) > 0.17 || abs(q.y - a.y) > 0.17) return col;
    float x = st.x >= 0. ? st.x : 0.;
    float drop = smoothstep(0., 0.15, x) * (1. - smoothstep(0.85, 1., x));
    float grind = smoothstep(0.12, 0.2, x) * (1. - smoothstep(0.8, 0.88, x));
    float rw = 0.0075, c = cvCeil(CS_GRIND);
    vec2 wc = mix(vec2(a.x + 0.004, c + 0.012), vec2(a.x + 0.004, a.y + CV_SIZE * 0.55 + rw - 0.0015), drop);
    col = cvMach(col, sdBox(q - vec2(wc.x, (wc.y + c + 0.025) * 0.5), vec2(0.0015, (c + 0.025 - wc.y) * 0.5)), 0.7);
    vec2 l = Rot(iTime * (4. + 40. * grind)) * (q - wc);
    float rr = length(q - wc), d = rr - rw;
    col = mix(col, vec3(0.02), S(d - 0.001) * 0.4);
    col = mix(col, vec3(0.42, 0.4, 0.38) * (0.85 + 0.15 * sin(atan(l.y, l.x) * 10.)), S(d));
    col = mix(col, vec3(0.65), S(abs(d + 0.0015) - 0.0004));
    col = cvMach(col, max(abs(rr - rw - 0.0022) - 0.0011, wc.y - 0.002 - q.y), 0.75);
    col = cvMach(col, rr - 0.002, 1.1);
    return cvSparks(col, q, wc - vec2(-0.002, rw), normalize(vec2(1., 0.35)), grind, 57., 0.9);
}

// the reject boot: hangs cocked back under the ceiling right of the amp,
// and when the x-ray has marked one it winds up and punts it back left, clean
// out of the factory (drawn mirrored about the station)
vec3 cvBootAt(vec3 col, vec2 q, vec2 sa, float ceil, float x, float since){
    q.x = 2. * sa.x - q.x;
    vec2 P = vec2(sa.x - CVG(0.9), ceil - 0.002);
    if(abs(q.x - P.x) > 0.065 || q.y < P.y - 0.07 || q.y > P.y + 0.006) return col;
    float a = x >= 0. ? (x < 0.75 ? mix(-1.4, -1.65, smoothstep(0., 0.7, x)) : mix(-1.65, 0.95, smoothstep(0.75, 1., x)))
                      : mix(0.95, -1.4, smoothstep(0.03, 0.6, since));
    vec2 A = P + 0.03 * vec2(sin(a), -cos(a));
    col = cvMach(col, sdBox(q - vec2(P.x, P.y + 0.001), vec2(0.004, 0.002)), 0.7);
    col = cvMach(col, sdSegment(q, P, A) - 0.0026, 0.85);
    col = cvMach(col, length(q - P) - 0.0036, 1.05);
    vec2 r = q - A, l = vec2(dot(r, vec2(cos(a), sin(a))), dot(r, vec2(-sin(a), cos(a))));
    float b = min(min(sdRoundBox(l - vec2(0., -0.004), vec2(0.0065, 0.008), 0.0025), sdRoundBox(l - vec2(0.006, -0.0145), vec2(0.0105, 0.0045), 0.004)), length(l - vec2(0.0135, -0.0135)) - 0.0062);
    float sole = sdRoundBox(l - vec2(0.0062, -0.0192), vec2(0.0128, 0.0019), 0.0015);
    col = mix(col, vec3(0.02), S(min(b, sole) - 0.0018) * 0.45);
    col = mix(col, vec3(0.42, 0.22, 0.1) * (0.85 + 0.15 * tcNoise(l * 500.)) * (0.8 + 0.25 * smoothstep(-0.02, 0.004, l.x)), S(b));
    col = mix(col, vec3(0.58, 0.34, 0.16), S(sdRoundBox(l - vec2(0., 0.0035), vec2(0.0075, 0.0018), 0.0012)));
    col = mix(col, vec3(0.08, 0.06, 0.05), S(sole));
    col = mix(col, vec3(0.08, 0.06, 0.05), S(sdRoundBox(l - vec2(-0.0035, -0.0215), vec2(0.0035, 0.0018), 0.001)));
    col = mix(col, vec3(1.), S(length((l - vec2(0.0148, -0.0112)) * vec2(1., 1.7)) - 0.0018) * 0.55);
    for(int k = 0; k < 4 + CVZ; k++){
        vec2 lc = l - vec2(0.0042, 0.0005 - 0.0028 * float(k));
        col = mix(col, vec3(0.9, 0.86, 0.76), S(min(sdSegment(lc, vec2(-0.0012, -0.0009), vec2(0.0012, 0.0009)), sdSegment(lc, vec2(-0.0012, 0.0009), vec2(0.0012, -0.0009))) - 0.00045));
    }
    return col;
}

// a punted amp: up in a big arc, then right across the screen at the
// camera, tumbling and swelling, a smear of ghosts behind it
vec3 cvKickedAt(vec3 col, vec2 q, vec2 s0, float since, float asp, float fit, bool fin){
    float T = since / 1.8;
    if(T >= 1.) return col;
    vec2 e = vec2(CV_CX - asp * 0.5 - 0.15, CV_CY - 0.5 / fit + 0.2);
    col += vec3(1., 0.85, 0.5) * exp(-since * 10.) * exp(-length(q - s0) / 0.012) * 0.9;
    float pw = 1. - smoothstep(0.08, 0.35, since);
    if(pw > 0.){
        vec2 r = q - s0 - vec2(-0.004, 0.006);
        float an = atan(r.y, r.x) + 0.3;
        float rr = (0.009 + 0.008 * smoothstep(0., 0.08, since)) * (0.5 + 0.5 * pow(abs(cos(an * 4.)), 3.));
        float d = length(r) - rr;
        col = mix(col, vec3(0.6, 0.15, 0.05), S(d - 0.0012) * pw);
        col = mix(col, vec3(1., 0.8, 0.15), S(d) * pw);
        col = mix(col, vec3(1., 1., 0.85), S(d + 0.003) * pw);
    }
    for(int k = 4; k >= 0 + CVZ; k--){
        float u = T - float(k) * 0.012;
        if(u < 0.) continue;
        vec2 p = mix(s0, e, u) + vec2(0., 1.6 * u * (1. - u));
        float sc = 1. + 9. * u * u;
        vec2 g = Rot(-u * 16.) * (q - p) / (CV_SIZE * sc);
        if(dot(g, g) > 2.) continue;
        float dd = glyphDist(g) * CV_SIZE * sc;
        float al = k == 0 ? 1. : 0.3 * (1. - float(k) / 5.);
        vec3 c = fin ? ampGradient(g) * 1.05 : mix(vec3(0.4, 0.41, 0.43), vec3(0.13, 0.12, 0.11), 0.65) * (0.8 + 0.3 * smoothstep(-0.3, 0.5, g.y));
        col = mix(col, vec3(0.01), S(dd - 0.0015 * sc) * 0.4 * al);
        col = mix(col, c, S(dd) * al);
    }
    return col;
}

// the tumbler: a big drum turning in the primer room, seen end on through
// its cut-away face; lifters carry the amps up the rising wall and drop them
// back through the grey slurry pooled in its bottom
vec3 cvDrum(vec3 col, vec2 q){
    vec2 r = q - CV_DRUM;
    float rr = length(r);
    if(rr > CV_DRUMR + 0.01) return col;
    float rot = iTime * CV_DRUM_W, inner = rr - CV_DRUMR;
    col = mix(col, vec3(0.045, 0.045, 0.05), S(inner));
    vec2 rs = Rot(0.35) * r;
    float lvl = -CVG(1.6) + 0.0012 * sin(rs.x * 160. - iTime * 4.);
    vec3 sc = vec3(0.82, 0.82, 0.8) * (0.85 + 0.2 * tcNoise(q * 90. + vec2(iTime * 0.5, 0.)));
    col = mix(col, sc, S(max(inner, rs.y - lvl)));
    col += vec3(0.6) * 0.25 * S(abs(rs.y - lvl) - 0.0006) * S(inner);
    for(int k = 0; k < 6 + CVZ; k++){
        float a = rot + float(k) * 1.0472, an = mod(a + 3.14159, 6.28318) - 3.14159;
        float load = smoothstep(-2.3, -1.7, an) * (1. - smoothstep(-0.3, 0.9, an));
        if(load <= 0.) continue;
        vec2 dir = vec2(cos(a), sin(a)), td = vec2(-dir.y, dir.x);
        vec2 p0 = CV_DRUM + dir * (CV_DRUMR - CVG(0.6));
        float along = clamp(dot(q - p0, dir) / CVG(0.6), 0., 1.);
        float heap = max(max(sdSegment(q, p0, CV_DRUM + dir * CV_DRUMR) - 0.008 * load * (0.35 + 0.65 * along), -dot(q - p0, td)), inner);
        col = mix(col, sc * 0.92, S(heap));
        float pour = smoothstep(-0.5, -0.1, an) * (1. - smoothstep(0.6, 1., an));
        if(pour <= 0.) continue;
        vec2 tip = p0 + td * 0.004;
        float py = CV_DRUM.y - CVG(1.6);
        if(tip.y <= py) continue;
        col = mix(col, sc, S(sdSegment(q, tip, vec2(tip.x - 0.003, py)) - 0.001 * pour) * 0.6 * pour);
        for(int n = 0; n < 6 + CVZ; n++){
            float u = fract(iTime * 2.3 + float(n) / 6. + float(k) * 0.13);
            col = mix(col, sc, S(length(q - tip - vec2(-0.003 * u, -(tip.y - py) * u * u)) - 0.0017) * pour);
        }
    }
    for(int k = 0; k < 6 + CVZ; k++){
        vec2 dir = vec2(cos(rot + float(k) * 1.0472), sin(rot + float(k) * 1.0472));
        col = cvMach(col, sdSegment(q, CV_DRUM + dir * (CV_DRUMR - CVG(0.6)), CV_DRUM + dir * CV_DRUMR) - 0.002, 0.75);
    }
    col = cvMach(col, abs(inner - 0.002) - 0.0025, 0.9);
    for(int k = 0; k < 12 + CVZ; k++){
        float a = rot + float(k) * 0.5236;
        col = mix(col, CV_MC * 1.3, S(length(r - (CV_DRUMR + 0.002) * vec2(cos(a), sin(a))) - 0.001));
    }
    return col;
}

vec3 cvFlickArm(vec3 col, vec2 q, vec4 st){
    if(q.x < CVG(16.) || q.x > CVG(27.) || q.y < CVG(6.) || q.y > CVG(14.)) return col;
    vec2 P = CV_FLK_P, rest = P + vec2(0.006, -0.014), away = P + vec2(-0.03, -0.012), tip = rest;
    bool hold = false;
    if(st.x >= 0.){
        vec4 r0 = cvState(cvI(st.y), 0);
        vec2 top = r0.xy + CV_SIZE * 0.55 * vec2(-sin(r0.z), cos(r0.z));
        if(st.x < 0.55){
            tip = mix(rest, top, smoothstep(0., 0.28, st.x));
            hold = st.x > 0.28;
        } else {
            tip = mix(top, away, smoothstep(0.55, 0.68, st.x));
            hold = st.x < 0.57;
        }
    } else tip = mix(away, rest, smoothstep(0., 0.6, st.z));
    vec2 dv = tip - P;
    float L = max(length(dv), 1e-4);
    vec2 dir = dv / L, nrm = vec2(-dir.y, dir.x);
    col = cvMach(col, sdSegment(q, P, P + dir * min(L, 0.022)) - 0.003, 0.7);
    col = cvMach(col, sdSegment(q, P, tip) - 0.0014, 0.95);
    float f = hold ? 0.0028 : 0.0045;
    for(int s = -1; s <= 1 + CVZ; s += 2)
        col = cvMach(col, sdSegment(q, tip + nrm * float(s) * f, tip + nrm * float(s) * f + dir * 0.005) - 0.0008, 0.95);
    col = cvMach(col, length(q - P) - 0.004, 1.1);
    return col;
}

// the drip rack after the drum: rollers with gaps under the wet amps, white
// slurry dripping off them into a tray on the floor, less as they dry
vec3 cvDripBack(vec3 col, vec2 q){
    if(q.x < CVG(8.) || q.x > CVG(21.) || q.y < CVG(6.) || q.y > CVG(7.5)) return col;
    float ty = CVG(6.6) + 0.0007 * sin(q.x * 300. + iTime * 3.);
    float pool = max(sdBox(q - vec2(CVG(13.5), CVG(6.3)), vec2(CVG(5.5), CVG(0.3))), q.y - ty);
    col = mix(col, vec3(0.82, 0.82, 0.8) * (0.85 + 0.15 * smoothstep(CVG(6.), ty, q.y)) * (0.92 + 0.08 * tcNoise(q * 120.)), S(pool));
    col += vec3(0.25) * S(abs(q.y - ty) - 0.0006) * step(pool, 0.002);
    float by = CVR(7.) - CV_SIZE * 0.5 - 0.002;
    if(q.x > CVG(19.)) return col;
    float rx = (fract(q.x / CVG(0.5)) - 0.5) * CVG(0.5);
    vec2 rp = vec2(rx, q.y - by);
    float rr = length(rp) - 0.0024;
    col = mix(col, vec3(0.02), S(rr - 0.0008) * 0.4);
    col = mix(col, CV_MC * (0.7 + 0.3 * step(0., sin(atan(rp.y, rp.x) * 3. + iTime * CV_DRIP_V / 0.0024))), S(rr));
    return col;
}

vec3 cvDripFront(vec3 col, vec2 q, float asp){
    if(q.x < CVG(8.5) || q.x > CVG(21.) || q.y < CVG(6.) || q.y > CVG(8.)) return col;
    vec4 sl[AG_TEX];
    agSlots(iChannel17, vec2(q.x, CVR(7.)), asp, sl);
    float ty = CVG(6.6);
    for(int k = 0; k < AG_SLOTS + CVZ; k++){
        int i = int(sl[k >> 2][k & 3] + 0.5) - 1;
        if(i < 0) break;
        vec4 r0 = cvState(i, 0), r1 = cvState(i, 1);
        if(cvI(r1.x) != CT_MAIN || abs(r0.y - CVR(7.)) > 0.002 || r0.x < CVG(9.) || r0.x > CVG(20.)) continue;
        float wet = 1. - clamp((r0.x - CVG(9.5)) / CVG(10.5), 0., 1.);
        for(int j = 0; j < 3 + CVZ; j++){
            float fj = float(j) + float(i) * 3.7;
            float u = fract(iTime * (0.9 + 0.5 * cvHash(fj)) + cvHash(fj + 2.));
            if(cvHash(fj + floor(iTime * (0.9 + 0.5 * cvHash(fj)) + cvHash(fj + 2.)) * 1.3) > wet) continue;
            vec2 o = vec2(r0.x + (cvHash(fj + 5.) - 0.5) * 0.012, r0.y - CV_SIZE * 0.45);
            if(o.x > CVG(19.) - 0.0015) continue;
            vec2 p = vec2(o.x, mix(o.y, ty, u * u));
            col = mix(col, vec3(0.88, 0.88, 0.86), S(sdSegment(q, p, p + vec2(0., 0.0025 * u)) - 0.0011));
        }
    }
    return col;
}

// the splat on the primer room's left wall where the flick arm throws the
// amps: a white blot with runs down the rock, fresh spray on every hit
vec3 cvSplat(vec3 col, vec2 q, vec4 st){
    vec2 w = vec2(CVG(8.), CVG(10.5));
    if(abs(q.x - w.x) > 0.04 || abs(q.y - w.y) > 0.06) return col;
    vec2 r = q - w;
    float an = atan(r.y, r.x);
    float blot = length(r * vec2(1.4, 1.)) - 0.011 * (0.75 + 0.45 * tcNoise(vec2(an * 2.5, 3.1)));
    float runs = 1e9;
    for(int k = 0; k < 4 + CVZ; k++){
        float x = w.x - 0.0015 - 0.0035 * float(k);
        float len = 0.012 + 0.018 * cvHash(float(k) * 7.3);
        runs = min(runs, sdSegment(q, vec2(x, w.y - 0.004), vec2(x, w.y - len)) - 0.0012 * (1. - 0.4 * float(k & 1)));
    }
    float d = max(min(blot, runs), q.x - w.x - 0.0008);
    col = mix(col, vec3(0.86, 0.86, 0.84) * (0.92 + 0.1 * tcNoise(q * 300.)), S(d));
    if(st.x >= 0.){
        float t = (st.x - 0.829) * CV_ST_DW[CS_FLICK];
        if(t > 0. && t < 0.5){
            for(int k = 0; k < 10 + CVZ; k++){
                float fk = float(k);
                vec2 v = vec2(0.15 + 0.25 * cvHash(fk + 1.), (cvHash(fk + 2.) - 0.3) * 0.5);
                vec2 p = w + vec2(0.004, 0.) + v * t + vec2(0., -1.5) * t * t;
                col = mix(col, vec3(0.9), S(length(q - p) - 0.0014) * (1. - t * 2.));
            }
        }
    }
    return col;
}

vec3 cvMelt(vec3 col, vec2 q){
    float d = max(length(q - CV_MELT) - 0.024, q.y - CV_MELT.y - 0.008);
    if(d > 0.04) return col;
    float fl = 0.85 + 0.15 * tcNoise(vec2(iTime * 4., 8.));
    col += vec3(1., 0.33, 0.06) * 0.1 * fl * exp(-max(d, 0.) / 0.015);
    col = mix(col, vec3(0.02), S(d - 0.0015));
    return mix(col, cvLava(q * 0.9 + 5., 0.9) * fl, S(d));
}

// a head hanging in the ceiling shaft (h tall) of station k: `drop` 0 up in
// it, 1 down on `bot`
vec3 cvHead(vec3 col, vec2 q, int k, float drop, vec2 size, float shade, float h, float bot){
    size *= CV_K; h *= CV_K;
    float top = cvCeil(k) + h - 0.004;
    float y = mix(top - size.y, bot + size.y, drop);
    float x = CV_ST_X[k];
    col = cvMach(col, sdBox(q - vec2(x, (top + y) * 0.5), vec2(0.0025 * CV_K, max((top - y) * 0.5, 0.))), 0.8);
    return cvMach(col, sdRoundBox(q - vec2(x, y), size, 0.002), shade);
}

vec3 cvHammer(vec3 col, vec2 q, int k, vec4 st, vec4 jam){
    vec2 sp = cvStPos(k);
    if(abs(q.x - sp.x) > 0.05 || q.y < sp.y - 0.03 || q.y > sp.y + 0.07) return col;
    int li = k - 3, kind = li == 0 ? 1 : li == 1 ? 0 : 2;
    bool jammed = jam.x == float(k) && jam.y < CV_FIX_AT;
    float p = st.x >= 0. && !jammed ? st.x : 0.;
    float fall = p < CV_HIT ? pow(p / CV_HIT, 2.2) : 1. - smoothstep(CV_HIT + 0.08, 0.95, p);
    float top = sp.y + (CV_MCEN[kind].y + CV_MHALF[kind].y) * CV_SIZE;
    col = cvHead(col, q, k, fall, vec2(0.015, 0.006), 1., li == 1 ? 0.03 : 0.02, top);
    float since = (p - CV_HIT) * CV_ST_DW[k];
    if(p > CV_HIT && since < 0.25) col += vec3(1., 0.85, 0.6) * 0.5 * exp(-since * 25.) * exp(-length(q - vec2(sp.x, top)) / 0.01);
    return col;
}

vec3 cvArm(vec3 col, vec2 q, int a, vec4 st){
    vec2 b = CV_ARMB[a], j = CV_JOIN[a], pk = CV_PICK[a];
    vec2 lo = min(min(b, j), pk) - 0.06, hi = max(max(b, j), pk) + 0.06;
    if(any(lessThan(q, lo)) || any(greaterThan(q, hi))) return col;
    bool busy = st.x >= 0. && st.w >= 0.;
    float ph = busy ? st.x : 0.;
    vec2 tip = cvArmTip(a, ph, busy);
    float L = CV_ARML[a];
    vec2 v = tip - b;
    float l = min(length(v), 2. * L - 1e-3);
    float an = atan(v.y, v.x), al = acos(clamp(l / (2. * L), -1., 1.)) * (a == 0 ? -1. : 1.);
    vec2 el = b + L * vec2(cos(an + al), sin(an + al));
    float mount = a == 0 ? -1. : 1.;
    if(a == 0) col = cvMach(col, sdBox(q - vec2(b.x, (b.y + CVG(CV_WELDROOM.y)) * 0.5), vec2(0.0045, (b.y - CVG(CV_WELDROOM.y)) * 0.5)), 0.7);
    col = cvMach(col, sdRoundBox(q - b - vec2(0., 0.006 * mount), vec2(0.018, 0.007) * CV_K, 0.003), 0.8);
    col = cvMach(col, sdSegment(q, b, el) - 0.0045 * CV_K, 1.);
    col = cvMach(col, sdSegment(q, el, tip) - 0.0035 * CV_K, 1.);
    col = cvMach(col, length(q - b) - 0.0065 * CV_K, 0.7);
    col = cvMach(col, length(q - el) - 0.005 * CV_K, 0.7);
    float open = busy && ph > 0.06 && ph < 0.42 ? 0.3 : 1.;
    for(int s = -1; s <= 1 + CVZ; s += 2){
        vec2 f0 = tip + vec2(0.004 * float(s), 0.) * CV_K;
        vec2 f1 = f0 + Rot(float(s) * -0.4 * open) * vec2(0.0025 * float(s), -0.009) * CV_K;
        col = cvMach(col, sdSegment(q, f0, f1) - 0.0014 * CV_K, 0.8);
    }
    float weld = busy ? smoothstep(0.42, 0.45, ph) * (1. - smoothstep(0.75, 0.78, ph)) : 0.;
    vec2 seam = j + CV_SEAM[a] * CV_SIZE;
    if(weld > 0.){
        float fl = 0.6 + 0.4 * random(vec2(floor(iTime * 30.), 2. + float(a)));
        col += vec3(0.7, 0.9, 1.2) * weld * fl * (S(length(q - seam) - 0.0035) + 0.5 * exp(-length(q - seam) / 0.013));
        col = cvSparks(col, q, seam, vec2(0., 1.), weld, 91. + float(a) * 13., 2.6);
    }
    return col;
}

// ---- the paint hall: four booths, each a gilded alcove with a turntable
// spinning the amp under a spotlight while two gold arms spray it ----------
const vec3 CV_GOLD = vec3(0.72, 0.56, 0.24);

vec3 cvMistColour(int k){
    return k == CS_PRIME ? vec3(0.78) : k == CS_PRIME + 1 ? GRAD_BOT : k == CS_PRIME + 2 ? GRAD_TOP : vec3(0.45, 0.25, 0.11);
}

float cvBoothOn(vec4 st){ return st.x >= 0. ? smoothstep(0., 0.08, st.x) * (1. - smoothstep(0.88, 1., st.x)) : 0.; }

vec3 cvBoothBack(vec3 col, vec2 q, int k, vec4 st){
    vec2 sp = cvStPos(k);
    float fl = sp.y - CV_ROWOFF;
    if(abs(q.x - sp.x) > CVG(2.) || q.y < fl - 0.01 || q.y > fl + CVG(6.)) return col;
    float panel = sdBox(q - vec2(sp.x, fl + CVG(3.)), vec2(CVG(2.), CVG(3.)));
    col = mix(col, CV_HOLE * 1.6, S(panel));
    return col + cvMistColour(k) * (0.08 + 0.25 * cvBoothOn(st)) * exp(-length((q - sp) * vec2(0.8, 1.)) / 0.035) * S(panel);
}

vec3 cvCatapult(vec3 col, vec2 q, float x){
    if(abs(q.x - CVG(17.5)) > CVG(2.5) || q.y > CVG(2.) || q.y < CVG(-1.) - 0.01) return col;
    float th = x >= 0. ? cvCatAng(x) : 0.;
    vec2 tip = cvCatCup(th), tg = vec2(cos(th), sin(th)), n = vec2(-tg.y, tg.x);
    col = mix(col, CV_GOLD * 0.85, S(sdSegment(q, CV_CATH + n * 0.0012, tip + n * 0.0012) - 0.0016));
    vec2 lq = vec2(dot(q - tip, tg), dot(q - tip, n));
    col = mix(col, CV_GOLD, S(max(abs(length(lq - vec2(0., 0.009)) - 0.009) - 0.0011, lq.y - 0.004)));
    return cvMach(col, length(q - CV_CATH - vec2(0., 0.003)) - 0.0035, 1.);
}

vec3 cvCoatRing(vec3 col, vec2 q, float x){
    vec2 sp = CV_PA;
    float fl = CVG(-1.), top = fl + CVG(5.3);
    if(abs(q.x - sp.x) > CVG(2.3) || q.y < fl || q.y > fl + CVG(6.)) return col;
    float y = top, on = 0.;
    if(x >= 0.){
        float yl = sp.y + (0.6 - 1.25 * cvCoatP(CS_PRIME + 1, x)) * CV_SIZE + 0.004;
        y = x < 0.08 ? mix(top, yl, smoothstep(0., 0.08, x)) : x < 0.5 ? yl : mix(yl, top, smoothstep(0.5, 0.6, x));
        on = smoothstep(0.07, 0.1, x) * (1. - smoothstep(0.47, 0.5, x));
    }
    vec2 v = q - vec2(sp.x, y);
    float sheet = step(abs(v.x), CVG(1.6)) * smoothstep(-CVG(0.8), 0., v.y) * step(v.y, 0.);
    col = mix(col, GRAD_BOT * 1.15, sheet * on * (0.2 + 0.25 * tcNoise(vec2(v.x * 400., v.y * 60. + iTime * 25.))));
    float bar = sdBox(v - vec2(0., 0.0055), vec2(CVG(2.), 0.0055));
    col = mix(col, vec3(0.01), S(bar - 0.0015) * 0.4);
    col = mix(col, CV_GOLD * (0.75 + 0.35 * smoothstep(0., 0.011, v.y)), S(bar));
    col = mix(col, CV_MC * 0.5, S(sdBox(v - vec2(0., 0.0012), vec2(CVG(1.7), 0.0012))));
    for(int s = -1; s <= 1 + CVZ; s += 2) col = cvMach(col, sdBox(v - vec2(float(s) * CVG(1.85), 0.0055), vec2(CVG(0.15), 0.009)), 0.8);
    return col;
}

vec3 cvTiltTable(vec3 col, vec2 q, float x){
    if(abs(q.x - CV_TABLE.x) > CVG(2.2) || q.y > CV_TABLE.y + CVG(1.) || q.y < CVG(-1.) - 0.01) return col;
    float tl = x >= 0. ? cvTilt(x) : 0., fl = CVG(-1.);
    col = cvMach(col, sdBox(q - vec2(CV_TABLE.x, fl + 0.002), vec2(0.009, 0.002)), 0.7);
    col = cvMach(col, sdBox(q - vec2(CV_TABLE.x, (fl + CV_TABLE.y) * 0.5 - 0.003), vec2(0.0028, (CV_TABLE.y - fl) * 0.5 - 0.003)), 0.85);
    col = mix(col, CV_GOLD * 0.8, S(sdBox(q - vec2(CV_TABLE.x, fl + CVG(1.2)), vec2(0.0034, 0.0012))));
    vec2 lq = Rot(tl) * (q - CV_TABLE);
    float top = sdBox(lq - vec2(0., -0.0028), vec2(CV_TABLEW, 0.0028));
    col = mix(col, vec3(0.01), S(top - 0.0015) * 0.4);
    col = mix(col, vec3(0.11, 0.08, 0.06) * (0.85 + 0.15 * sin(lq.x * 900.)), S(top));
    col = mix(col, vec3(0.08, 0.22, 0.14), S(sdBox(lq - vec2(0., -0.0005), vec2(CV_TABLEW - 0.0015, 0.0005))));
    col = mix(col, CV_GOLD, S(abs(top) - 0.0006));
    col = cvMach(col, length(q - CV_TABLE + vec2(0., 0.004)) - 0.0026, 1.15);
    return col;
}

vec3 cvPlotter(vec3 col, vec2 q, float x){
    vec2 sp = CV_PB;
    float park = CVG(4.3), w = CVG(0.7);
    if(abs(q.x - sp.x) > CVG(2.3) || q.y > CVG(5.) || q.y < sp.y - CVG(1.)) return col;
    float p = x >= 0. ? cvCoatP(CS_PRIME + 2, x) : 1.;
    float yl = sp.y + (0.6 - 1.25 * p) * CV_SIZE + CVG(0.85);
    float y = x < 0. ? park : x < 0.1 ? mix(park, yl, smoothstep(0., 0.1, x)) : x < 0.65 ? yl : mix(yl, park, smoothstep(0.65, 0.78, x));
    float cx = sp.x + w * (2. * abs(fract(p * 3.5) - 0.5) * 2. - 1.);
    if(x >= 0. && x < 0.1) cx = mix(sp.x - w, sp.x + w, smoothstep(0., 0.1, x));
    float on = x >= 0. ? smoothstep(0.09, 0.11, x) * (1. - smoothstep(0.63, 0.66, x)) : 0.;
    vec3 mc = mix(GRAD_TOP, GRAD_BOT, p) * 1.25;
    col = mix(col, CV_GOLD, S(sdBox(q - vec2(sp.x, y), vec2(CVG(2.), 0.0009))));
    vec2 tip = vec2(cx, y - CVG(0.72));
    col = mix(col, CV_GOLD * 1.1, S(sdSegment(q, vec2(cx, y), tip) - 0.0006));
    col += mc * on * 0.9 * exp(-length(q - tip) / 0.0015);
    return col;
}

vec2 cvGoopShake(float x){
    return x > CV_GOOP_FIRE ? 0.007 * exp(-(x - CV_GOOP_FIRE) * CV_ST_DW[CS_CLEAR] * 8.) * vec2(sin(iTime * 93.), cos(iTime * 71.)) : vec2(0.);
}

vec3 cvGoopStains(vec3 col, vec2 q, float x){
    if(x < CV_GOOP_HIT || q.x < CVG(6.) || q.x > CVG(10.) || q.y > CVG(5.) || q.y < CVG(-1.) - 0.01) return col;
    float a = smoothstep(CV_GOOP_HIT, CV_GOOP_HIT + 0.02, x) * (1. - smoothstep(0.75, 1., x));
    float tt = (x - CV_GOOP_HIT) * CV_ST_DW[CS_CLEAR];
    vec2 imp = cvGoopImpact();
    for(int j = 0; j < 14 + CVZ; j++){
        float fj = float(j), h = cvHash(fj * 3.1 + 0.4);
        vec2 c = imp + vec2(-h * h * CVG(5.), (cvHash(fj * 5.7 + 1.9) - 0.35) * CVG(3.4) * (0.4 + h));
        float r = (0.002 + 0.006 * cvHash(fj + 7.3) * (1. - 0.6 * h)) * smoothstep(0., 0.03 + 0.1 * h, tt);
        float dl = min(tt * 0.016 * cvHash(fj + 2.2), 0.016);
        float d = min(length((q - c) * vec2(0.8 + 0.6 * h, 1.2)) - r + 0.0018 * tcNoise((q - c) * 900.), sdSegment(q, c, c - vec2(0., dl)) - r * 0.25);
        col = mix(col, vec3(0.3, 0.17, 0.08) * (0.8 + 0.3 * tcNoise(q * 500.)), S(d) * a * 0.92);
    }
    vec2 pd = q - vec2(CV_PC.x - CVG(0.3), CVG(-1.) + 0.0006);
    col = mix(col, vec3(0.26, 0.15, 0.07), S(length(pd * vec2(0.8, 5.)) - CVG(1.) * smoothstep(0., 0.3, tt)) * a);
    vec2 sc = q - cvGunMuzzle(CV_GOOP_FIRE);
    col *= 1. - 0.5 * a * exp(-length(sc * vec2(0.7, 1.)) / 0.02);
    return col;
}

vec3 cvGoopCannon(vec3 col, vec2 q, float x){
    float fl = CVG(-1.);
    if(q.x < CVG(1.) || q.x > CVG(13.1) || q.y < fl - 0.01 || q.y > CVG(4.6)) return col;
    vec2 u = cvGunU(), n = vec2(-u.y, u.x);
    float rec = cvGunRecoil(x);
    vec2 qj = q;
    float bed = cvTrapezoid(qj - vec2(CV_GUN_T.x + CVG(0.2), (fl + CV_GUN_T.y) * 0.5 - 0.002), CVG(1.1), CVG(0.6), (CV_GUN_T.y - fl) * 0.5 - 0.002);
    col = mix(col, vec3(0.01), S(bed - 0.002) * 0.5);
    col = mix(col, vec3(0.42, 0.4, 0.38) * (0.8 + 0.3 * smoothstep(fl, CV_GUN_T.y, qj.y)), S(bed));
    col = mix(col, vec3(0.25, 0.24, 0.23), S(abs(bed) - 0.0007));
    vec2 b0 = CV_GUN_T + u * rec;
    vec2 v = qj - b0, lv = vec2(dot(v, u), dot(v, n));
    float body = length(lv - vec2(CVG(0.05), 0.)) - CVG(0.62);
    body = min(body, max(abs(lv.y) - CVG(0.5), max(-CV_GUN_LM + CVG(0.3) - lv.x, lv.x - CVG(0.1))));
    body = min(body, max(abs(lv.y) - mix(CVG(0.85), CVG(0.5), clamp((lv.x + CV_GUN_LM) / CVG(0.4), 0., 1.)), max(-CV_GUN_LM - lv.x, lv.x + CV_GUN_LM - CVG(0.4))));
    body = min(body, length(lv - vec2(CV_GUN_LB + CVG(0.2), 0.)) - CVG(0.18));
    vec3 brz = vec3(0.78, 0.52, 0.24);
    col = mix(col, vec3(0.01), S(body - 0.0025) * 0.55);
    col = mix(col, brz * (0.65 + 0.6 * smoothstep(-CVG(0.6), CVG(0.6), lv.y + CVG(0.2))) + vec3(1., 0.9, 0.7) * 0.35 * exp(-abs(lv.y - CVG(0.3)) / 0.002), S(body));
    for(int j = 0; j < 2 + CVZ; j++){
        float bx = j == 0 ? -CV_GUN_LM + CVG(0.42) : CVG(0.1);
        col = mix(col, brz * 0.55, S(max(abs(lv.x - bx) - 0.0016, abs(lv.y) - CVG(j == 0 ? 0.52 : 0.62))));
    }
    col = mix(col, vec3(0.04, 0.03, 0.02), S(max(abs(lv.x + CV_GUN_LM) - 0.0018, abs(lv.y) - CVG(0.66))));
    col = mix(col, vec3(0.26, 0.14, 0.05), S(max(abs(lv.x + CV_GUN_LM) - 0.001, abs(lv.y) - CVG(0.56))));
    col = mix(col, brz * 1.2, S(length(qj - CV_GUN_T) - 0.0045));
    col = mix(col, brz * 0.5, S(length(qj - CV_GUN_T) - 0.002));
    if(x < CV_GOOP_FIRE) return col;

    float tf = (x - CV_GOOP_FIRE) * CV_ST_DW[CS_CLEAR];
    vec2 m0 = cvGunMuzzle(CV_GOOP_FIRE), dir = -u, imp = cvGoopImpact();
    vec2 mv = q - m0;
    float along = dot(mv, dir), side = dot(mv, n);
    for(int j = 0; j < 8 + CVZ; j++){
        float fj = float(j), h = cvHash(fj * 1.9 + 0.3);
        vec2 c = m0 + dir * (0.006 + 0.035 * h) * (1. - exp(-tf * 5.)) + n * (cvHash(fj + 4.4) - 0.4) * 0.03 * (1. - exp(-tf * 3.)) + vec2(0., 0.012 * tf);
        float rr = 0.004 + 0.018 * (1. - exp(-tf * 3.)) * (0.5 + h);
        float sm = smoothstep(0., -rr, length(q - c) - rr + 0.004 * tcNoise((q - c) * 300. + fj));
        col = mix(col, vec3(0.17, 0.14, 0.11), sm * 0.75 * exp(-tf * 1.3));
    }
    float fe = exp(-tf * 16.);
    float cone = step(0., along) * smoothstep(0.75, 0.15, abs(side) / max(along, 1e-4)) * exp(-along / 0.035);
    col += vec3(1., 0.78, 0.4) * fe * (2.5 * exp(-length(mv) / 0.008) + 1.6 * cone);
    col += vec3(1.) * fe * 1.5 * exp(-length(mv) / 0.003);
    float rad = 0.22 * pow(tf, 0.65);
    col += vec3(1., 0.9, 0.7) * 0.7 * exp(-abs(length(mv) - rad) / 0.0016) * exp(-tf * 7.);
    if(x < CV_GOOP_HIT){
        float k = (x - CV_GOOP_FIRE) / (CV_GOOP_HIT - CV_GOOP_FIRE);
        vec2 c = mix(m0, imp, k), sv = q - c;
        float slug = length(vec2(dot(sv, dir) * 0.6, dot(sv, n) * 0.9)) - CVG(0.5);
        col = mix(col, cvGoop(sv * 60., 5.), S(slug));
        col = mix(col, vec3(0.3, 0.17, 0.08), S(sdSegment(q, c, m0) - CVG(0.12) * (1. - k)) * 0.8);
        return col;
    }
    float th = (x - CV_GOOP_HIT) * CV_ST_DW[CS_CLEAR];
    vec2 iv = q - imp;
    col += vec3(1., 0.75, 0.45) * exp(-th * 14.) * 2.2 * exp(-length(iv) / 0.012);
    float br = 0.006 + 0.035 * (1. - exp(-th * 12.));
    float burst = length(iv) - br + 0.01 * (tcNoise(iv * 200. + 7.) - 0.5) * (1. + 4. * th);
    col = mix(col, cvGoop(iv * 60., 9.), S(burst) * (1. - smoothstep(0.05, 0.3, th)) * 0.9);
    if(th < 0.9){
        for(int j = 0; j < 30 + CVZ; j++){
            float fj = float(j), h = cvHash(fj * 2.3 + 0.7);
            float a = atan(dir.y, dir.x) + (h - 0.5) * (j < 22 ? 2.6 : 6.28);
            float sp = 0.25 + 0.5 * cvHash(fj * 4.1 + 2.3);
            vec2 p = imp + sp * th * vec2(cos(a), sin(a)) - vec2(0., 0.9 * th * th);
            float rr = (0.0014 + 0.003 * cvHash(fj + 9.1)) * (1. - th / 0.9);
            col = mix(col, vec3(0.33, 0.18, 0.08), S(length((q - p) * vec2(1., 1.3)) - rr));
        }
        for(int j = 0; j < 12 + CVZ; j++){
            float fj = float(j), a = cvHash(fj * 7.7 + 1.1) * 6.28318, sp = 0.6 + 0.6 * cvHash(fj * 3.3);
            vec2 vel = sp * vec2(cos(a), sin(a)) - vec2(0., 1.5 * th);
            vec2 p = imp + sp * th * vec2(cos(a), sin(a)) - vec2(0., 0.75 * th * th);
            col += vec3(1., 0.6, 0.2) * exp(-th * 9.) * S(sdSegment(q, p, p - vel * 0.012) - 0.0005);
        }
    }
    float dummy = 0.;
    for(int j = 1; j < 9 + CVZ; j++){
        float xs = x - float(j) * 0.015;
        if(xs < CV_GOOP_HIT || xs > 0.85) continue;
        vec2 p = cvPaintPos(CS_CLEAR, xs, dummy) + (vec2(cvHash(float(j) + floor(x * 40.)), cvHash(float(j) * 1.7)) - 0.5) * 0.006;
        col = mix(col, vec3(0.32, 0.18, 0.08), S(length(q - p) - 0.003 * (1. - float(j) / 9.)));
    }
    return col;
}


vec3 cvAirbrush(vec3 col, vec2 q, int k, vec4 st){
    vec2 sp = cvStPos(k);
    if(abs(q.x - sp.x) > 0.05 || q.y < sp.y - 0.03 || q.y > sp.y + 0.045) return col;
    float c = cvCeil(k);
    vec2 tip = vec2(sp.x, c - 0.004);
    col = cvMach(col, sdBox(q - vec2(sp.x, c + 0.003), vec2(0.0055, 0.006) * CV_K), 0.9);
    col = cvMach(col, cvTrapezoid(q - tip - vec2(0., 0.0015), 0.0015 * CV_K, 0.0035 * CV_K, 0.0025 * CV_K), 1.1);
    if(st.x < 0.) return col;
    vec3 mist = k == CS_PRIME ? vec3(0.7) : k == CS_PRIME + 1 ? GRAD_BOT : k == CS_PRIME + 2 ? GRAD_TOP : vec3(0.9, 0.95, 1.);
    vec2 v = q - tip;
    float on = smoothstep(0., 0.08, st.x) * (1. - smoothstep(0.85, 1., st.x));
    float cone = step(v.y, 0.) * smoothstep(0.65, 0.4, abs(v.x) / max(-v.y, 1e-3)) * smoothstep(-0.032, -0.004, v.y);
    float grain = tcNoise(v * 300. + vec2(0., iTime * 30.));
    col = mix(col, mist, cone * on * (0.18 + 0.25 * grain));
    for(int j = 0; j < 8 + CVZ; j++){
        float fj = float(j);
        float a = fract(iTime * 1.6 + cvHash(fj + float(k)));
        vec2 p = tip + vec2((cvHash(fj + 1.7) - 0.5) * 0.04 * a, -0.03 * a);
        col = mix(col, mist, S(length(q - p) - 0.0012) * on * (1. - a));
    }
    return col;
}

// the polishing shrine after the goop booth: crimson velvet in a gold arch,
// a spotlight fades up, two cloth wheels on gold arms swing in from the
// sides and buff the goop away, then withdraw and the amp is unveiled in a
// flash of sparkles
float cvPolishOn(vec4 st){ return st.x >= 0. ? smoothstep(0., 0.12, st.x) * (1. - smoothstep(0.88, 1., st.x)) : 0.; }

vec3 cvPolishBack(vec3 col, vec2 q, vec4 st){
    vec2 sp = cvStPos(CS_POLISH);
    float fl = sp.y - CV_ROWOFF;
    if(abs(q.x - sp.x) > CVG(3.) || q.y < fl - 0.01 || q.y > fl + CVG(6.)) return col;
    float on = cvPolishOn(st);
    float room = sdBox(q - vec2(sp.x, fl + CVG(3.)), vec2(CVG(3.), CVG(3.)));
    float arch = max(sdBox(q - vec2(sp.x, fl + CVG(3.)), vec2(CVG(2.4), CVG(3.))), length((q - vec2(sp.x, fl + CVG(3.4))) * vec2(1., 1.2)) - CVG(2.4) - (q.y < fl + CVG(3.4) ? 1. : 0.));
    float fold = 0.75 + 0.25 * sin((q.x - sp.x) * 900. + 0.6 * sin(q.y * 200.));
    vec3 vel = vec3(0.3, 0.035, 0.06) * fold;
    float beam = smoothstep(0.5, 0.15, abs(q.x - sp.x) / max(fl + CVG(5.4) - q.y, 1e-3)) * step(q.y, fl + CVG(5.4));
    col = mix(col, vel * 0.45, S(room));
    col = mix(col, vel * (0.55 + 0.6 * on * beam) + vec3(1., 0.9, 0.7) * 0.18 * on * beam, S(arch));
    col = mix(col, CV_GOLD * 1.1, S(abs(arch) - 0.0018));
    for(int s = -1; s <= 1 + CVZ; s += 2){
        vec2 cnd = vec2(sp.x + float(s) * CVG(2.7), fl + CVG(3.6));
        col = mix(col, CV_GOLD, S(sdBox(q - cnd + vec2(0., 0.005), vec2(0.004, 0.0012))));
        col = mix(col, vec3(0.92, 0.88, 0.78), S(sdBox(q - cnd, vec2(0.0018, 0.004))));
        float fl2 = 0.8 + 0.2 * sin(iTime * 13. + float(s) * 2.);
        col += vec3(1., 0.75, 0.35) * 0.6 * fl2 * exp(-length((q - cnd - vec2(0., 0.006)) * vec2(1.6, 1.)) / 0.0025);
        col += vec3(1., 0.7, 0.3) * 0.08 * fl2 * exp(-length(q - cnd) / 0.02);
    }
    col = mix(col, vec3(1., 0.95, 0.8), S(length(q - vec2(sp.x, fl + CVG(5.5))) - 0.004) * (0.4 + 0.6 * on));
    return col;
}

vec3 cvPolishFront(vec3 col, vec2 q, vec4 st){
    vec2 sp = cvStPos(CS_POLISH);
    float fl = sp.y - CV_ROWOFF;
    if(abs(q.x - sp.x) > CVG(3.) || q.y < fl - 0.01 || q.y > fl + CVG(6.)) return col;
    float x = st.x >= 0. ? st.x : 1.;
    float reach = smoothstep(0.05, 0.18, x) * (1. - smoothstep(0.8, 0.92, x));
    float buff = smoothstep(0.15, 0.2, x) * (1. - smoothstep(0.78, 0.82, x));
    for(int s = -1; s <= 1 + CVZ; s += 2){
        float fs = float(s);
        vec2 sh = vec2(sp.x + fs * CVG(2.2), fl + CVG(3.8));
        vec2 rest = vec2(sp.x + fs * CVG(1.9), fl + CVG(2.4));
        vec2 tgt = vec2(sp.x + fs * (0.012 * CV_AMPK + 0.002 * sin(iTime * 9.) * buff), sp.y + 0.002 * cos(iTime * 9.) * buff);
        vec2 wc = mix(rest, tgt, reach);
        vec2 el = mix(sh, wc, 0.5) + vec2(fs * 0.008, 0.01);
        col = mix(col, CV_GOLD, S(sdSegment(q, sh, el) - 0.0022));
        col = mix(col, CV_GOLD * 1.15, S(sdSegment(q, el, wc) - 0.0018));
        col = cvMach(col, length(q - el) - 0.003, 0.9);
        col = cvMach(col, length(q - sh) - 0.004, 0.8);
        float rw = 0.0065;
        vec2 l = Rot(iTime * (2. + 40. * buff) * fs) * (q - wc);
        float rr = length(q - wc), d = rr - rw;
        col = mix(col, vec3(0.02), S(d - 0.001) * 0.4);
        col = mix(col, vec3(0.88, 0.84, 0.76) * (0.85 + 0.15 * sin(atan(l.y, l.x) * 20.)), S(d));
        col = mix(col, vec3(0.45, 0.28, 0.14), S(d) * smoothstep(rw * 0.5, rw, rr) * 0.5 * buff);
        col = cvMach(col, rr - 0.0018, 1.1);
        if(buff > 0.){
            for(int k = 0; k < 6 + CVZ; k++){
                float fk = float(k) + fs * 5.;
                float u = fract(iTime * 2.4 + cvHash(fk + 0.3));
                vec2 p = wc + vec2(fs * (0.008 + 0.014 * cvHash(fk + 1.7)) * u, 0.012 * u - 0.03 * u * u);
                col = mix(col, vec3(0.4, 0.24, 0.11), S(length(q - p) - 0.0011) * buff * (1. - u));
            }
        }
    }
    float rev = st.x >= 0. ? smoothstep(0.82, 0.9, st.x) : 1. - smoothstep(0.1, 0.7, st.z);
    if(rev > 0.){
        float t = st.x >= 0. ? 0. : st.z;
        col += vec3(1., 0.95, 0.85) * 0.5 * rev * exp(-length(q - sp) / 0.02) * (st.x >= 0. ? 1. : exp(-t * 4.));
        col += vec3(1., 0.95, 0.8) * 0.6 * rev * S(abs(length(q - sp) - 0.012 - t * 0.06) - 0.0008);
        for(int k = 0; k < 8 + CVZ; k++){
            float fk = float(k);
            float a = fk * 0.785 + 0.3 * cvHash(fk);
            vec2 p = sp + vec2(cos(a), sin(a)) * (0.015 + 0.01 * cvHash(fk + 2.)) * (1. + t * 2.);
            vec2 r = abs(q - p);
            float tw = 0.5 + 0.5 * sin(iTime * 12. + fk * 2.);
            float star = max(1. - (r.x * r.y) * 4e5 - (r.x + r.y) * 60., 0.);
            col += vec3(1., 0.95, 0.8) * star * rev * tw;
        }
    }
    return col;
}

// the classroom the finished amps sit a lecture in before packing: twelve
// seats on wooden steps rising from the teacher, who taps the chalk amp on
// the board with a long pointer until the class files out
vec3 cvTrapDoor(vec3 col, vec2 q, float asp){
    vec2 hg = vec2(CVG(-8.), CVG(-4.));
    if(q.x < hg.x - 0.005 || q.x > hg.x + CVG(1.) + 0.005 || q.y > hg.y + 0.005 || q.y < hg.y - CVG(1.2)) return col;
    vec4 sl[AG_TEX];
    agSlots(iChannel17, vec2(CVX(-8.), CVR(-5.)), asp, sl);
    float op = 0.;
    for(int k = 0; k < AG_SLOTS + CVZ; k++){
        int i = int(sl[k >> 2][k & 3] + 0.5) - 1;
        if(i < 0) break;
        vec4 r0 = cvState(i, 0), r1 = cvState(i, 1);
        if(cvI(r1.x) != CT_PACK) continue;
        vec2 p = r0.xy;
        if(abs(p.x - CVX(-8.)) < CVG(0.6) && p.y < CVR(-4.) + 0.001 && p.y > CVR(-7.)) op = max(op, smoothstep(CVR(-4.) + 0.0005, CVR(-4.) - CVG(0.4), p.y) * smoothstep(CVR(-7.), CVR(-6.), p.y));
    }
    float a = -1.45 * min(op, 1.);
    vec2 lq = Rot(a) * (q - hg);
    float door = sdBox(lq - vec2(CVG(0.5), -0.0022), vec2(CVG(0.5), 0.0022));
    col = mix(col, vec3(0.01), S(door - 0.0012) * 0.4);
    col = mix(col, vec3(0.36, 0.23, 0.12) * (0.85 + 0.15 * sin(lq.x * 700.)), S(door));
    col = mix(col, vec3(0.2, 0.12, 0.06), S(abs(door) - 0.0005));
    return cvMach(col, length(q - hg - vec2(0.002, -0.002)) - 0.0022, 1.1);
}

vec3 cvClassBack(vec3 col, vec2 q, vec4 st){
    if(q.x < CVG(-29.) || q.x > CVG(-7.) || q.y < CVG(-4.) || q.y > CVG(2.)) return col;
    float on = st.x >= 0. ? 1. : 0.;
    float room = sdBox(q - vec2(CVG(-18.), CVG(-1.)), vec2(CVG(11.), CVG(3.)));
    room = max(room, -min(sdBox(q - vec2(CVG(-10.5), CVG(0.)), vec2(CVG(0.5), CVG(2.))), sdBox(q - vec2(CVG(-9.), CVG(-1.5)), vec2(CVG(2.), CVG(0.5)))));
    vec3 paper = q.y > CVG(-3.) ? vec3(0.3, 0.33, 0.26) * (0.9 + 0.1 * step(0.5, fract(q.x / CVG(0.5)))) : vec3(0.26, 0.16, 0.09) * (0.85 + 0.15 * tcNoise(q * 150.));
    col = mix(col, paper, S(room));
    col = mix(col, vec3(0.38, 0.25, 0.13), S(abs(q.y - CVG(-3.)) - 0.0008) * S(room));
    vec2 bc = vec2(CVG(-13.), CVG(0.025)), bh = vec2(CVG(2.), CVG(1.975)) - 0.003;
    float bd = sdBox(q - bc, bh);
    col = mix(col, vec3(0.3, 0.19, 0.1), S(bd - 0.003));
    col = mix(col, vec3(0.07, 0.17, 0.12) * (0.9 + 0.15 * tcNoise(q * 80.)), S(bd));
    vec2 ac = bc - vec2(CVG(0.9), -CVG(0.3));
    float ch = abs(glyphDist((q - ac) / 0.045)) * 0.045 - 0.0006;
    for(int k = 0; k < 6 + CVZ; k++){
        float y = bc.y + CVG(1.2) - float(k) * CVG(0.45), x0 = bc.x + CVG(0.25);
        float x1 = x0 + CVG(0.5 + 0.9 * cvHash(float(k) + 3.));
        ch = min(ch, max(abs(q.y - y - 0.001 * sin(q.x * 900. + float(k) * 3.)) - 0.0004, max(x0 - q.x, q.x - x1)));
    }
    col = mix(col, vec3(0.85, 0.88, 0.84), S(ch) * step(bd, 0.));
    col = mix(col, vec3(0.3, 0.19, 0.1), S(sdBox(q - vec2(bc.x, bc.y - bh.y - 0.002), vec2(bh.x, 0.0015))));
    vec2 sb = vec2(CVG(-27.08), CVR(-1.));
    float sk = cvSAtSt(CS_CLASS);
    vec3 wood = vec3(0.3, 0.19, 0.11) * (0.85 + 0.15 * tcNoise(q * 200.));
    for(int r = 1; r < 12 + CVZ; r++){
        vec2 p = cvAt(CT_PACK, sk - CV_GAP * float(r));
        float yb = p.y - CV_SIZE * 0.5;
        float stp = sdBox(q - vec2(p.x, (yb + CVG(-4.)) * 0.5), vec2(CVG(0.5), (yb - CVG(-4.)) * 0.5));
        col = mix(col, wood, S(stp));
        col = mix(col, vec3(0.48, 0.32, 0.18), S(abs(q.y - yb) - 0.0008) * S(stp - 0.0008));
    }
    float pb = sb.y - CV_SIZE * 0.5;
    float plat = sdBox(q - vec2((CVG(-29.) + sb.x) * 0.5, (pb + CVG(-4.)) * 0.5), vec2((sb.x - CVG(-29.)) * 0.5, (pb - CVG(-4.)) * 0.5));
    col = mix(col, wood, S(plat));
    col = mix(col, vec3(0.48, 0.32, 0.18), S(abs(q.y - pb) - 0.0008) * S(plat - 0.0008));
    vec4 tch = cvState(CX_TEACH, CV_ROW);
    float aw = tch.x, flr = CVG(-1.);
    float rm = sdBox(q - vec2(CVG(-8.5), CVG(0.5)), vec2(CVG(1.5), CVG(1.5)));
    vec3 wp = vec3(0.3, 0.22, 0.17) * (0.9 + 0.1 * step(0.5, fract(q.x / CVG(0.4))));
    col = mix(col, wp, S(rm));
    vec2 lb = vec2(CVG(-8.5), CVG(1.7));
    col = mix(col, vec3(0.1), S(sdSegment(q, lb, vec2(lb.x, CVG(2.))) - 0.0005));
    col = mix(col, vec3(1., 0.85, 0.55), S(length(q - lb) - 0.0022));
    col += vec3(1., 0.75, 0.4) * 0.12 * exp(-length(q - lb) / 0.03) * S(rm);
    vec2 fc = vec2(CVG(-9.45), CVG(1.5));
    col = cvMach(col, sdBox(q - vec2(CVG(-9.97), fc.y), vec2(0.0015, CVG(0.2))), 0.7);
    col = cvMach(col, sdSegment(q, vec2(CVG(-10.), fc.y), fc) - 0.0009, 0.8);
    col = cvMach(col, length((q - fc) * vec2(1., 1.3)) - CVG(0.14), 1.);
    float bl = 0.6 + 0.4 * step(0.5, fract(iTime * 23.));
    col = mix(col, vec3(0.75, 0.78, 0.8) * bl, S(length((q - fc - vec2(CVG(0.18), 0.)) * vec2(4., 1.)) - CVG(0.3)) * 0.7);
    col = mix(col, CV_MC * 0.8, S(abs(length((q - fc - vec2(CVG(0.18), 0.)) * vec2(4., 1.)) - CVG(0.32)) - 0.0005));
    for(int s = -1; s <= 1 + CVZ; s += 2) col = mix(col, vec3(0.45, 0.32, 0.18), S(sdSegment(q, vec2(CVG(-7.5) + float(s) * CVG(0.25), CVG(-4.)), vec2(CVG(-7.5) + float(s) * CVG(0.25), flr + CVG(0.3))) - 0.0007));
    if(q.y > CVG(-4.) && q.y < flr && abs(q.x - CVG(-7.5)) < CVG(0.25)) col = mix(col, vec3(0.45, 0.32, 0.18), S(abs(fract((q.y - CVG(-4.)) / CVG(0.4)) - 0.5) * CVG(0.4) - 0.0006));
    vec2 base = vec2(CVG(-12.4), CVR(-4.) + 0.004), foot = vec2(CVG(-7.5), CVR(-4.) + 0.004);
    vec2 up = vec2(CVG(-7.5), flr + CV_ROWOFF + 0.004), seat = vec2(CVG(-9.), flr + CV_ROWOFF + 0.004);
    vec2 tp = aw < 0.3 ? mix(base, foot, smoothstep(0., 0.3, aw)) : aw < 0.75 ? mix(foot, up, smoothstep(0.3, 0.75, aw)) : mix(up, seat, smoothstep(0.75, 1., aw));
    float moving = aw > 0.001 && aw < 0.999 ? 1. : 0.;
    tp.y += 0.0012 * sin(iTime * 6.) * on * (1. - step(0.02, aw)) + 0.0015 * abs(sin(iTime * 12.)) * moving;
    float fx = aw > 0.99 ? -1. : 1.;
    float ts = CV_SIZE * 1.25;
    vec2 tg = (q - tp) / ts;
    tg.x *= -fx;
    float td = glyphDist(tg) * ts;
    col = mix(col, vec3(0.01), S(td - 0.0015) * 0.4);
    col = mix(col, ampGradient(tg) * 0.95, S(td));
    for(int e = 0; e < 2 + CVZ; e++){
        vec2 gc = tp + vec2((-0.0055 + 0.0048 * float(e)) * fx, 0.0045) * CV_AMPK;
        col = mix(col, vec3(0.05), S(abs(length(q - gc) - 0.0017) - 0.00045));
    }
    vec2 h = tp + vec2(-0.0085, 0.003) * CV_AMPK;
    if(aw < 0.02){
        vec2 tgt = ac + vec2(0.006, 0.004) + 0.0015 * vec2(sin(iTime * 5.), cos(iTime * 7.)) * on;
        col = mix(col, vec3(0.5, 0.32, 0.15), S(sdSegment(q, h, tgt) - 0.0008));
    }
    vec2 lc = vec2(CVG(-13.2), CVG(-4.));
    vec3 lw = vec3(0.36, 0.23, 0.12) * (0.85 + 0.15 * tcNoise(q * 300.));
    float lec = min(sdBox(q - lc - vec2(0., 0.002), vec2(CVG(0.45), 0.002)), sdBox(q - lc - vec2(0., CVG(0.45)), vec2(CVG(0.12), CVG(0.45))));
    vec2 lt = q - lc - vec2(0., CVG(0.95));
    lec = min(lec, sdBox(Rot(-0.3) * lt, vec2(CVG(0.5), 0.0022)));
    lec = min(lec, sdBox(q - lc - vec2(0., CVG(0.75)), vec2(CVG(0.35), CVG(0.2))));
    col = mix(col, vec3(0.01), S(lec - 0.0012) * 0.4);
    col = mix(col, lw, S(lec));
    col = mix(col, vec3(0.2, 0.12, 0.06), S(abs(lec) - 0.0005));
    if(aw > 0.98){
        vec2 m0 = tp + vec2(-0.0075 * fx, -0.001) * CV_AMPK, m1 = m0 + vec2(-0.008 * fx, -0.002);
        float puff = 0.5 + 0.5 * sin(iTime * 0.9);
        col = mix(col, vec3(0.92, 0.9, 0.85), S(sdSegment(q, m0, m1) - 0.0009));
        col = mix(col, vec3(1., 0.35, 0.1) * (0.7 + 0.6 * puff), S(length(q - m1) - 0.0011));
        col += vec3(1., 0.4, 0.1) * 0.4 * puff * exp(-length(q - m1) / 0.003);
        for(int k = 0; k < 6 + CVZ; k++){
            float fk = float(k), f = fract(iTime * 0.22 + fk / 6.);
            if(f > 0.6) continue;
            float u = f / 0.6;
            vec2 fs = vec2(CVG(-8.7), CVG(1.5));
            vec2 sp = u < 0.4 ? mix(m1, fs, smoothstep(0., 1., u / 0.4)) + vec2(0.003 * sin(u * 9. + fk), 0.) : mix(fs, vec2(CVG(-6.), CVG(1.5)), (u - 0.4) / 0.6) + vec2(0., 0.002 * sin(u * 11. + fk));
            float rr = 0.0015 + 0.009 * u;
            col = mix(col, vec3(0.75, 0.75, 0.78), S(length(q - sp) - rr) * 0.35 * smoothstep(0., 0.1, u));
        }
    }
    return col;
}

vec3 cvVentSmoke(vec3 col, vec2 q){
    vec2 ex = vec2(CVG(-6.), CVG(1.5));
    if(q.x < ex.x - CVG(1.) || q.x > CVG(-2.) || q.y < CVG(0.) || q.y > CVG(4.5)) return col;
    if(cvState(CX_TEACH, CV_ROW).x < 0.98) return col;
    for(int k = 0; k < 6 + CVZ; k++){
        float fk = float(k), f = fract(iTime * 0.22 + fk / 6.);
        if(f < 0.6) continue;
        float u = (f - 0.6) / 0.4;
        vec2 sp = ex + vec2(CVG(1.2) * sqrt(u) + 0.003 * sin(u * 6. + fk), CVG(1.6) * u * u + 0.002 * cos(u * 5. + fk));
        float rr = 0.002 + 0.012 * u;
        col = mix(col, vec3(0.75, 0.75, 0.78), S(length(q - sp) - rr) * 0.3 * (1. - u) * smoothstep(0., 0.1, u));
    }
    return col;
}

// the coronation room under the classroom: purple banners and a spotlight;
// each graduate lands on the floor and a mortarboard tumbles down out of the
// dark onto its head
vec3 cvCoronBack(vec3 col, vec2 q, vec4 st){
    vec2 a = cvStPos(CS_HAT);
    if(q.x < CVG(-15.) || q.x > CVG(-7.) || q.y < CVG(-15.) || q.y > CVG(-5.)) return col;
    float on = st.x >= 0. ? smoothstep(0., 0.15, st.x) * (1. - smoothstep(0.9, 1., st.x)) : 0.;
    float rm = sdBox(q - vec2(CVG(-11.), CVG(-10.)), vec2(CVG(4.), CVG(5.)));
    vec3 wall = vec3(0.3, 0.05, 0.08) * (0.8 + 0.25 * smoothstep(CVG(-15.), CVG(-5.), q.y)) * (0.85 + 0.35 * exp(-abs(q.x - a.x) / 0.04));
    col = mix(col, wall, S(rm));
    vec3 gold = CV_GOLD * 1.15;
    col = mix(col, vec3(0.22, 0.11, 0.05), S(max(rm, q.y - CVG(-14.))));
    col = mix(col, gold, S(abs(q.y - CVG(-14.)) - 0.001) * S(rm));
    col = mix(col, gold, S(max(rm, CVG(-5.4) - q.y)));
    col = mix(col, gold * 0.6, S(abs(q.y - CVG(-5.4)) - 0.0006) * S(rm));
    for(int b = 0; b < 2 + CVZ; b++){
        float bx = CVG(-11.) + (b == 0 ? -1. : 1.) * CVG(2.5);
        float bd = max(sdBox(q - vec2(bx, CVG(-7.6)), vec2(CVG(0.6), CVG(2.2))), CVG(-9.8) + (CVG(0.6) - abs(q.x - bx)) * 0.9 - q.y);
        col = mix(col, vec3(0.28, 0.08, 0.36) * (0.85 + 0.15 * sin((q.x - bx) * 600.)), S(bd));
        col = mix(col, gold, S(abs(bd) - 0.0009));
        col = mix(col, gold * 1.1, S(abs(length((q - vec2(bx, CVG(-6.9))) * vec2(1., 1.2)) - 0.005) - 0.0008));
    }
    float py = CVR(-14.4) - CV_SIZE * 0.5;
    vec3 marble = vec3(0.86, 0.84, 0.8) * (0.9 + 0.1 * tcNoise(q * 140.)) - vec3(0.12) * smoothstep(0.85, 0.95, abs(sin(q.x * 600. + q.y * 300. + 3. * tcNoise(q * 60.))));
    for(int k = 0; k < 2 + CVZ; k++){
        float hw = k == 0 ? CVG(1.45) : CVG(1.05), ty = k == 0 ? mix(CVG(-15.), py, 0.5) : py;
        float st2 = sdBox(q - vec2(CVG(-11.), (ty + CVG(-15.)) * 0.5), vec2(hw, (ty - CVG(-15.)) * 0.5));
        col = mix(col, vec3(0.02), S(st2 - 0.0015) * 0.4);
        col = mix(col, marble * (k == 0 ? 0.85 : 1.), S(st2));
        col = mix(col, gold, S(abs(q.y - ty) - 0.0009) * S(st2 - 0.0009));
    }
    float beam = smoothstep(0.4, 0.12, abs(q.x - a.x) / max(CVG(-5.6) - q.y, 1e-3)) * step(q.y, CVG(-5.6));
    col += vec3(1., 0.92, 0.7) * (0.05 + 0.14 * on) * beam;
    col = mix(col, vec3(1., 0.95, 0.8), S(length(q - vec2(a.x, CVG(-5.7))) - 0.0035) * (0.5 + 0.5 * on));
    return col;
}

vec3 cvHatRig(vec3 col, vec2 q, vec4 st){
    vec2 a = cvStPos(CS_HAT);
    if(q.x < CVG(-15.) || q.x > CVG(-7.) || q.y < CVG(-15.) || q.y > CVG(-5.)) return col;
    float x = st.x >= 0. ? st.x : 0.;
    float u = smoothstep(0., 0.6, x);
    float top = CVG(-5.4) - 0.006 - 0.73 * CV_SIZE;
    vec2 o = vec2(a.x + 0.004 * sin(x * 17.) * (1. - u), mix(top, a.y, u * u));
    float ang = 0.6 * sin(x * 21.) * (1. - u);
    col = cvMach(col, sdBox(q - vec2(a.x, CVG(-5.4) - 0.0015), vec2(0.006, 0.0015)), 0.7);
    if(st.x >= 0. && x > 0.6 && x < 0.85){
        float t = (x - 0.6) / 0.25;
        for(int k = 0; k < 8 + CVZ; k++){
            float fk = float(k), an = fk * 0.785 + 0.4;
            vec2 p = a + vec2(0., CV_SIZE * 0.7) + vec2(cos(an), sin(an)) * (0.006 + 0.014 * t);
            col += vec3(1., 0.85, 0.4) * S(length(q - p) - 0.0012) * (1. - t);
        }
    }
    if(st.x < 0.) return cvCap(col, (q - o) / CV_SIZE);
    return cvCap(col, Rot(ang) * (q - o) / CV_SIZE);
}

// the cap knocked off at the top of the bounce: it flips up and away and
// tumbles down the shaft
vec3 cvBounceRoom(vec3 col, vec2 q, float t){
    if(q.x < CVG(-19.) || q.x > CVG(-16.) || q.y < CVG(-15.) || q.y > CVG(-5.)) return col;
    float rm = sdBox(q - vec2(CVG(-17.5), CVG(-10.)), vec2(CVG(1.5), CVG(5.)));
    rm = max(rm, -sdBox(q - vec2(CVG(-18.5), CVG(-11.5)), vec2(CVG(0.5), CVG(0.5))));
    col = mix(col, vec3(0.3, 0.31, 0.34) * (0.92 + 0.08 * tcNoise(q * 120.)), S(rm));
    float hz = step(0.5, fract((q.x + q.y) / 0.008));
    col = mix(col, mix(vec3(0.08), vec3(0.85, 0.65, 0.1), hz), S(max(rm, q.y - CVG(-14.6))));
    vec2 b = vec2(CVX(-17.), CVG(-15.));
    float since = t;
    float kick = exp(-since * 14.) * sin(min(since * 30., 3.14159));
    float top = b.y + 0.004 + 0.008 * kick;
    float spring = abs(fract((q.y - b.y) / max(top - b.y, 0.002) * 4.) - 0.5) * 2.;
    col = cvMach(col, max(abs(q.x - b.x - (spring - 0.5) * CVG(0.6)) - 0.0014, max(b.y - q.y, q.y - top)), 0.8);
    return cvMach(col, sdBox(q - vec2(b.x, top + 0.0015), vec2(CVG(0.45), 0.0018)), 1.15);
}

vec3 cvHatFly(vec3 col, vec2 q, float t){
    t -= 0.22;
    if(t < 0. || t > 1.2) return col;
    vec2 pad = vec2(CVX(-17.), CVR(-15.)), land = vec2(CVX(-19.), CVR(-11.));
    vec2 ap = mix(pad, land, 0.5) + vec2(0., CVG(5.));
    vec2 o = ap + vec2(0.04 * t, 0.07 * t - 0.45 * t * t);
    if(length(q - o) > 0.04) return col;
    vec3 c = cvCap(col, Rot(-7. * t) * (q - o) / CV_SIZE);
    return mix(col, c, 1. - smoothstep(0.9, 1.2, t));
}

// the QC column: amps hauled up a pure vertical shaft, each by its own arm
// running on a rail up the left wall, stopping at every step: a stamp, a
// squeeze, a scale, a stretch and a scanner, each in a niche in the right
// wall beside a boot for the ones that fail
vec3 cvColumn(vec3 col, vec2 q, vec4 st[31], float asp){
    if(q.x < CVG(-6.5) || q.x > CVG(-1.8) || q.y < CVG(-15.5) || q.y > CVG(4.)) return col;
    col = cvMach(col, sdBox(q - vec2(CVG(-6.) + 0.003, CVG(-5.75)), vec2(0.003, CVG(9.25))), 0.6);
    vec4 sl[AG_TEX];
    agSlots(iChannel17, vec2(CVG(-5.), q.y), asp, sl);
    for(int k = 0; k < AG_SLOTS + CVZ; k++){
        int i = int(sl[k >> 2][k & 3] + 0.5) - 1;
        if(i < 0) break;
        vec4 r0 = cvState(i, 0), r1 = cvState(i, 1);
        if(cvI(r1.x) != CT_FIN || abs(r0.x - CVG(-5.)) > 0.004 || r0.y < CVR(-15.) + 0.001 || r0.y > CVR(3.) - 0.001) continue;
        vec2 p = r0.xy;
        float top = p.y + CV_SIZE * 0.55;
        col = cvMach(col, sdBox(q - vec2(CVG(-6.) + 0.006, top + 0.001), vec2(0.0055, 0.0055)), 0.75);
        col = cvMach(col, sdSegment(q, vec2(CVG(-6.) + 0.006, top + 0.001), vec2(p.x, top + 0.001)) - 0.0022, 0.9);
        col = cvMach(col, sdBox(q - vec2(p.x, top + 0.002), vec2(0.005, 0.002)), 1.);
        for(int s = -1; s <= 1 + CVZ; s += 2)
            col = cvMach(col, sdSegment(q, vec2(p.x + float(s) * 0.0045, top + 0.001), vec2(p.x + float(s) * 0.0055, top - 0.005)) - 0.0015, 0.95);
    }
    float wx = CVG(-2.);
    for(int j = 0; j < 5 + CVZ; j++){
        int k = CV_QC_K[j];
        vec2 a = cvStPos(k);
        if(abs(q.y - a.y) > CVG(1.2)) continue;
        vec4 s = st[k];
        float x = s.x >= 0. ? s.x : 0.;
        if(j == 0){
            float press = s.x >= 0. ? smoothstep(0.2, 0.45, x) * (1. - smoothstep(0.6, 0.85, x)) : 0.;
            float hx = mix(CVG(-2.7), a.x + CV_SIZE * 0.42 + 0.003, press);
            col = cvMach(col, sdBox(q - vec2(CVG(-2.35), a.y), vec2(CVG(0.35), 0.013)), 0.6);
            col = cvMach(col, sdBox(q - vec2((hx + wx) * 0.5, a.y), vec2((wx - hx) * 0.5, 0.0038)), 0.75);
            col = cvMach(col, sdBox(q - vec2(hx + 0.005, a.y), vec2(0.005, 0.011)), 1.1);
            col += GRAD_TOP * 0.4 * press * press * exp(-length(q - vec2(hx, a.y)) / 0.01);
        } else if(j == 1){
            float kk = cvStressK(s);
            float w = CV_SIZE * 0.4 / (1. + 0.6 * kk) + 0.0018;
            float drop = s.x >= 0. ? smoothstep(0., 0.12, x) * (1. - smoothstep(0.92, 1., x)) : 0.;
            for(int sd = -1; sd <= 1 + CVZ; sd += 2){
                float fs = float(sd), base = fs > 0. ? wx : CVG(-6.) + 0.003;
                float px = mix(base - fs * 0.003, a.x + fs * w, drop);
                col = cvMach(col, sdBox(q - vec2(base + fs * 0.002, a.y - 0.004), vec2(0.004, 0.008)), 0.6);
                col = cvMach(col, sdBox(q - vec2((px + base) * 0.5, a.y - 0.004), vec2(abs(base - px) * 0.5, 0.0028)), 0.75);
                col = cvMach(col, sdBox(q - vec2(px, a.y), vec2(0.0028, 0.012)), 1.05);
            }
        } else if(j == 2){
            vec2 c = vec2(CVG(-2.9), a.y);
            col = cvMach(col, sdBox(q - c, vec2(0.016, 0.016)), 0.6);
            float d = length(q - c);
            col = mix(col, vec3(0.85, 0.83, 0.75), S(d - 0.0125));
            col = mix(col, CV_MC * 0.45, S(abs(d - 0.0125) - 0.002));
            float na = s.x < 0. ? -1.6 : -1.6 + 2.6 * (1. - exp(-x * 6.) * cos(x * 22.));
            col = mix(col, vec3(1., 0.4, 0.15), S(sdSegment(q, c, c + vec2(sin(na), cos(na)) * 0.0105) - 0.0014));
            col = mix(col, vec3(0.1), S(d - 0.0025));
        } else if(j == 3){
            float kk = cvStressK(s);
            float drop = s.x >= 0. ? smoothstep(0., 0.12, x) * (1. - smoothstep(0.92, 1., x)) : 0.;
            float fy = a.y - CV_SIZE * 0.55 * (1. + 0.4 * kk) - 0.001;
            float cx = mix(wx - 0.003, a.x + 0.004, drop);
            col = cvMach(col, sdBox(q - vec2(CVG(-2.3), fy - 0.003), vec2(CVG(0.3), 0.008)), 0.6);
            col = cvMach(col, sdBox(q - vec2((cx + wx) * 0.5, fy - 0.003), vec2((wx - cx) * 0.5, 0.003)), 0.75);
            col = cvMach(col, max(sdBox(q - vec2(cx - 0.004, fy - 0.002), vec2(0.0105, 0.005)), -sdBox(q - vec2(cx - 0.004, fy + 0.0005), vec2(0.0075, 0.004))), 1.05);
        } else {
            col = cvMach(col, sdBox(q - vec2(CVG(-2.4), a.y), vec2(0.006, CVG(0.9))), 0.85);
            col = cvMach(col, sdBox(q - vec2(CVG(-2.4) - 0.006, a.y), vec2(0.0012, CVG(0.8))), 1.2);
            if(s.x >= 0.){
                float y = a.y - CV_SIZE * 0.5 + CV_SIZE * (0.5 - 0.5 * cos(x * 9.42));
                col += vec3(1., 0.15, 0.1) * 0.8 * S(abs(q.y - y) - 0.0006) * step(a.x - 0.012, q.x) * step(q.x, CVG(-2.4));
            }
            vec4 kt = cvState(CX_QK + j, CV_ROW);
            bool bad = s.x >= 0. && cvI(kt.y) == cvI(s.y) && kt.z > 0.5 && x > 0.6;
            vec2 lp = vec2(CVG(-2.4), a.y + CVG(0.9));
            vec3 lc = s.x < 0. ? CV_SLAB * 0.6 : bad ? vec3(1., 0.15, 0.1) : vec3(0.25, 1., 0.5);
            col = mix(col, lc, S(length(q - lp) - 0.0045));
            if(s.x >= 0.) col += lc * 0.15 * exp(-length(q - lp) / 0.01);
        }
    }
    return col;
}

vec3 cvQC(vec3 col, vec2 q, vec4 st[31], vec4 jam, vec4 so){
    if(q.y < CVG(-7.) || q.y > CVG(6.)) return col;
    vec2 sp = cvStPos(CS_STAMP);
    if(abs(q.x - sp.x) < 0.05){
        bool jm = jam.x == float(CS_STAMP) && jam.y < CV_FIX_AT;
        float p = st[CS_STAMP].x >= 0. && !jm ? st[CS_STAMP].x : 0.;
        float press = smoothstep(0.2, 0.45, p) * (1. - smoothstep(0.6, 0.85, p));
        col = cvHead(col, q, CS_STAMP, press, vec2(0.012, 0.006), 1.1, 0.045, sp.y + CV_SIZE * 0.5);
        col += GRAD_TOP * 0.4 * press * press * exp(-length(q - sp - vec2(0., CV_SIZE * 0.5)) / 0.012);
    }
    sp = cvStPos(CS_WEIGH);
    if(abs(q.x - sp.x) < 0.05){
        float p = st[CS_WEIGH].x;
        float sink = p >= 0. ? 0.002 * (1. - exp(-p * 6.) * cos(p * 22.)) : 0.;
        col = cvMach(col, sdBox(q - vec2(sp.x, sp.y - CV_SIZE * 0.5 - 0.002 - sink), vec2(0.02, 0.0022) * CV_K), 1.2);
        vec2 c = vec2(sp.x, sp.y - 0.046);
        col = mix(col, CV_HOLE, S(length(q - c) - 0.011 * CV_K));
        float na = p < 0. ? -1.6 : -1.6 + 2.6 * (1. - exp(-p * 6.) * cos(p * 22.));
        col = mix(col, vec3(1., 0.4, 0.15), S(sdSegment(q, c, c + vec2(sin(na), cos(na)) * 0.008 * CV_K) - 0.0009));
    }
    sp = cvStPos(CS_SCAN);
    if(abs(q.x - sp.x) < 0.05){
        float c = cvCeil(CS_SCAN);
        col = cvMach(col, sdBox(q - vec2(sp.x, c - 0.001), vec2(0.016, 0.0025) * CV_K), 1.);
        if(st[CS_SCAN].x >= 0.){
            float y = sp.y - CV_SIZE * 0.5 + CV_SIZE * (0.5 - 0.5 * cos(st[CS_SCAN].x * 9.42));
            col += vec3(1., 0.15, 0.1) * 0.8 * S(abs(q.y - y) - 0.0006) * step(abs(q.x - sp.x), 0.015 * CV_K);
        }
        bool lit = st[CS_SCAN].z < 1.2;
        vec3 lc = st[CS_SCAN].w > 0.5 ? vec3(1., 0.15, 0.1) : vec3(0.25, 1., 0.5);
        vec2 lp = vec2(sp.x, c + 0.016);
        col = mix(col, lit ? lc : CV_SLAB * 0.6, S(length(q - lp) - 0.0035 * CV_K));
        if(lit) col += lc * 0.15 * exp(-length(q - lp) / 0.01);
    }
    return col;
}

vec3 cvPack(vec3 col, vec2 q, vec4 st[31], vec4 jam){
    if(q.y < CVG(-12.) || q.y > CVG(-4.)) return col;
    vec2 sp = cvStPos(CS_BOX);
    if(abs(q.x - sp.x) < 0.05){
        float tl = cvState(CX_HATFLY, CV_ROW).x;
        if(st[CS_BOX].x < 0. && tl < 0.46){
            float u = clamp(tl / 0.34, 0., 1.);
            vec2 bp = vec2(sp.x, mix(CVG(-5.6), sp.y, u * u));
            vec2 d = (q - bp) / (CV_M * CV_AMPK), bd = d - vec2(0., -0.0015);
            float b = sdRoundBox(bd, vec2(0.0245, 0.0215), 0.002);
            col = mix(col, vec3(0.02), S(b - 0.002) * 0.5);
            col = mix(col, vec3(0.5, 0.36, 0.21) * (0.92 + 0.08 * tcNoise(bd * 400.)), S(b));
            col = mix(col, vec3(0.28, 0.19, 0.1), S(abs(b) - 0.0008));
            for(int sd = -1; sd <= 1 + CVZ; sd += 2){
                vec2 hinge = vec2(0.0245 * float(sd), 0.02);
                col = mix(col, vec3(0.42, 0.3, 0.17), S(sdSegment(d, hinge, hinge + Rot(float(sd) * 1.4) * vec2(-0.024 * float(sd), 0.)) - 0.0016));
            }
        }
        vec2 hc = vec2(sp.x, CVG(-5.6));
        float hb = sdBox(q - hc, vec2(CVG(0.75), CVG(0.6)));
        col = cvMach(col, hb, 0.75);
        float win = sdBox(q - hc - vec2(0., 0.002), vec2(CVG(0.5), CVG(0.3)));
        col = mix(col, vec3(0.5, 0.36, 0.21) * (0.75 + 0.25 * step(0.5, fract((q.y - hc.y) / 0.0025))), S(win));
        col = mix(col, CV_MC * 0.45, S(abs(win) - 0.0008));
        float op = tl < 0.3 ? sin(clamp(tl / 0.3, 0., 1.) * 3.14159) : 0.;
        for(int sd = -1; sd <= 1 + CVZ; sd += 2){
            vec2 hg = vec2(hc.x + float(sd) * CVG(0.7), CVG(-6.2));
            col = cvMach(col, sdSegment(q, hg, hg + Rot(-float(sd) * op * 1.4) * vec2(-float(sd) * CVG(0.68), 0.)) - 0.0013, 0.9);
        }
    }
    sp = cvStPos(CS_TAPE);
    if(abs(q.x - sp.x) < 0.05){
        bool jm = jam.x == float(CS_TAPE) && jam.y < CV_FIX_AT;
        float p = st[CS_TAPE].x >= 0. && !jm ? st[CS_TAPE].x : 0.;
        float c = cvCeil(CS_TAPE), top = sp.y + 0.02 * CV_M;
        float grow = smoothstep(0.15, 0.75, p), reach = smoothstep(0., 0.15, p) * (1. - smoothstep(0.8, 1., p));
        float hy = mix(c + 0.008, top - 0.045 * CV_M * grow + 0.004, reach);
        vec2 h = vec2(sp.x + 0.0055, hy);
        col = cvMach(col, sdBox(q - vec2(h.x, (hy + c + 0.02) * 0.5), vec2(0.0012, (c + 0.02 - hy) * 0.5)), 0.75);
        col = cvMach(col, sdBox(q - h, vec2(0.0025, 0.004)), 0.9);
        vec2 rc = h + vec2(0.005, 0.002);
        float rd = length(q - rc);
        col = mix(col, vec3(0.02), S(rd - 0.0055) * 0.4);
        col = mix(col, vec3(0.62, 0.5, 0.33), S(rd - 0.0045));
        col = cvMach(col, rd - 0.0016, 0.8);
        col = mix(col, CV_MC * 0.4, S(sdSegment(q, rc, rc + 0.0035 * vec2(cos(grow * 20.), sin(grow * 20.))) - 0.0005));
    }
    sp = cvStPos(CS_LABEL);
    if(abs(q.x - sp.x) < 0.05){
        float p = st[CS_LABEL].x >= 0. ? st[CS_LABEL].x : 0.;
        float down = smoothstep(0.3, 0.55, p) * (1. - smoothstep(0.65, 0.9, p));
        col = cvHead(col, q, CS_LABEL, down, vec2(0.011, 0.005), 1., 0.04, sp.y + 0.02 * CV_M);
    }
    return col;
}

vec3 cvJamLamp(vec3 col, vec2 q, vec4 jam){
    if(jam.x < 0. || jam.y >= CV_FIX_AT) return col;
    int js = clamp(cvI(jam.x), 0, CV_NS - 1);
    vec2 lp = vec2(CV_ST_X[js] + 0.03, cvCeil(js) + 0.014);
    float fl = step(0.5, fract(iTime * 3.));
    col = mix(col, mix(vec3(0.3, 0.05, 0.03), vec3(1., 0.15, 0.08), fl), S(length(q - lp) - 0.0035 * CV_K));
    return col + vec3(1., 0.1, 0.05) * 0.2 * fl * exp(-length(q - lp) / 0.015);
}

vec3 cvPanel(vec3 col, vec2 q, float shipped){
    if(abs(q.x) > 0.11 || abs(q.y) > 0.085) return col;
    float b = sdBox(q, vec2(0.1, 0.075));
    col = mix(col, CV_HOLE, S(b));
    col = mix(col, CV_SLAB * 0.55, S(abs(b) - 0.0007) * 0.8);
    col = cvDigits(col, q, vec2(-0.086, 0.035), 0.035, 6, 104217. + shipped, GRAD_TOP * 0.9);
    float h = iClock.x * 10. + iClock.y, mi = iClock.z * 10. + iClock.w;
    col = cvDigits(col, q, vec2(-0.064, -0.035), 0.035, 2, h, CV_MC * 1.6);
    col = cvDigits(col, q, vec2(0.006, -0.035), 0.035, 2, mi, CV_MC * 1.6);
    float blink = step(0.5, fract(iTime));
    for(int s = -1; s <= 1 + CVZ; s += 2) col = mix(col, CV_MC * 1.6 * (0.3 + 0.7 * blink), S(length(q - vec2(-0.002, -0.035 + 0.007 * float(s))) - 0.0025));
    return col;
}

// sand running through a pipe from a to b; crossing a tunnel it runs in a
// casing
vec3 cvSandSeg(vec3 col, vec2 q, vec2 a, vec2 b, float carve, float speed){
    float d = sdSegment(q, a, b) - 0.0032;
    if(d > 0.006) return col;
    vec2 dir = normalize(b - a);
    float inTun = S(carve);
    col = mix(col, CV_MC * 0.6, S(d - 0.0016) * inTun);
    col = mix(col, CV_SLAB * 0.45, S(d - 0.0012) * (1. - inTun));
    vec2 u = vec2(dot(q - a, dir), dot(q - a, vec2(-dir.y, dir.x)));
    float g = tcNoise(vec2((u.x - iTime * speed) * 500., u.y * 500.));
    return mix(col, CV_SAND * (0.5 + 0.55 * g), S(d));
}

// a flask standing at (c.x, bottom c.y): `dirt` caked in sand, `wet` from the
// wash, `fill` how full of fresh sand
vec3 cvTowerFlask(vec3 col, vec2 q, vec2 c, float id, float dirt, float wet, float fill){
    vec2 g = (q - c) / CV_SIZE + vec2(0., CV_MCEN[0].y - CV_MHALF[0].y);
    float fl = cvFlask(g, 0);
    float md = cvMouldD(g, 0);
    if(md * CV_DSIZE > 0.006) return col;
    float bot = CV_MCEN[0].y - CV_MHALF[0].y, top = CV_MCEN[0].y + CV_MHALF[0].y;
    if(dirt > 0.){
        float lvl = bot + (0.25 + 0.55 * tcNoise(vec2(g.x * 5., id))) * dirt;
        col = mix(col, CV_SAND * (0.5 + 0.3 * tcNoise(g * 14. + id)), S(max(md + 0.1, g.y - lvl) * CV_DSIZE));
    }
    if(fill > 0.) col = mix(col, CV_SAND * (0.62 + 0.12 * tcNoise(g * 40. + id)), S(max(md + 0.1, g.y - mix(bot, top, fill)) * CV_DSIZE));
    vec3 fc = mix(CV_MC * 0.85, CV_SAND * (0.5 + 0.25 * tcNoise(g * 9. + id)), dirt * 0.85);
    fc = fc * (1. - 0.2 * wet) + vec3(0.1, 0.15, 0.2) * wet + vec3(0.35) * wet * smoothstep(0.3, 0.5, g.y - g.x * 0.3) * 0.3;
    col = mix(col, fc, S(fl));
    if(wet > 0.05){
        for(int k = 0; k < 2 + CVZ; k++){
            float a = fract(iTime * 1.6 + cvHash(id + float(k) * 3.));
            vec2 dp = vec2(c.x + (cvHash(id + float(k)) - 0.5) * 0.02, c.y - 0.002 - a * 0.012);
            col = mix(col, vec3(0.55, 0.75, 0.85), S(length(q - dp) - 0.0009) * wet * (1. - a));
        }
    }
    return col;
}

const float CV_FDT    = 0.5;
const float CV_FALL_V = 0.6;

float cvBeltY(){ return CV_RET_Y - CV_CELL + 0.002; }
float cvPitY(){ return CV_PIT.y - CV_PIT_H.y + 0.012; }

// flask `id` on its round: out of the hatch and left along the return tunnel,
// down the shaft, blasted in the pit and over to the paternoster, up through
// wash, dryer and filler, off into the head of line id % 3. Bottom centre at
// p, false once it has left; dirt, wet, fill its state
bool cvFlaskPath(float id, out vec2 p, out vec3 st, out bool carried){
    float TA = (CV_RET_X - CV_DROP_X) / CV_FRAME_V;
    float TB = (cvBeltY() - cvPitY()) / CV_FALL_V;
    float TC = CV_FDT * 0.9;
    float tt = iTime - id * CV_FDT;
    carried = false;
    st = vec3(1., 0., 0.);
    if(tt < 0.) return false;
    if(tt < TA){
        p = vec2(CV_RET_X - tt * CV_FRAME_V, cvBeltY() + CVG(2.) * (1. - smoothstep(0., 0.35, tt)));
        return true;
    }
    tt -= TA;
    if(tt < TB){
        p = vec2(CV_DROP_X, cvBeltY() - tt * CV_FALL_V);
        return true;
    }
    tt -= TB;
    if(tt < TC){
        float u = tt / TC;
        p = vec2(mix(CV_DROP_X, CV_PAT_X, smoothstep(0.6, 1., u)), cvPitY() + 0.001 * sin(iTime * 60.) * (1. - u));
        st.x = 1. - 0.85 * smoothstep(0.05, 0.6, u);
        return true;
    }
    tt -= TC;
    int row = int(mod(id, 3.));
    p = vec2(CV_PAT_X, cvPitY() + tt * CV_FRAME_V);
    carried = true;
    if(p.y > CV_ST_Y[row] - CV_SIZE * 0.5) return false;
    st = vec3(0.15 * (1. - smoothstep(CV_PIT.y, CV_WASHY.x, p.y)),
              smoothstep(CV_WASHY.x, CV_WASHY.x + 0.03, p.y) * (1. - smoothstep(CV_DRYY.x, CV_DRYY.y, p.y)),
              smoothstep(CV_FILLY.x, CV_FILLY.y, p.y));
    return true;
}

vec3 cvFlaskDraw(vec3 col, vec2 q, float id){
    vec2 p;
    vec3 st;
    bool carried;
    if(!cvFlaskPath(id, p, st, carried)) return col;
    if(abs(q.x - p.x) > 0.03 || abs(q.y - p.y - 0.014) > 0.03) return col;
    if(carried) col = cvMach(col, sdBox(q - p + vec2(0., 0.002), vec2(0.014, 0.0015)), 0.7);
    return cvTowerFlask(col, q, p, id, st.x, st.y, st.z);
}

vec3 cvFlasks(vec3 col, vec2 q){
    float y0 = cvBeltY();
    float TA = (CV_RET_X - CV_DROP_X) / CV_FRAME_V;
    float TB = (y0 - cvPitY()) / CV_FALL_V;
    float TC = CV_FDT * 0.9;
    if(q.x < CVG(-32.) && q.x > CVG(-39.)){
        if(abs(q.x - CV_DROP_X) < CV_CELL && q.y < CV_RET_Y && q.y > CV_PIT.y){
            col = mix(col, CV_SAND * (0.5 + 0.5 * tcNoise(vec2(q.x * 500., (q.y + iTime * 0.4) * 500.))), S(abs(q.x - CV_DROP_X - 0.011) - 0.0012) * 0.8);
        }
        vec2 pq = q - CV_PIT;
        if(all(lessThan(abs(pq), CV_PIT_H + 0.02))){
            float floorY = CV_PIT.y - CV_PIT_H.y;
            float dune = floorY + 0.012 + 0.006 * sin(pq.x * 90. + 1.) + 0.003 * tcNoise(vec2(pq.x * 200., iTime * 0.2));
            col = mix(col, CV_SAND * (0.5 + 0.4 * tcNoise(q * 400.)), S(max(sdBox(pq, CV_PIT_H), q.y - dune)));
            col += CV_SAND * 0.08 * step(sdBox(pq, CV_PIT_H), 0.) * (0.6 + 0.4 * tcNoise(q * 120. + vec2(iTime * 6., 0.)));
            for(int s = -1; s <= 1 + CVZ; s += 2){
                vec2 nz = vec2(CV_PIT.x + float(s) * (CV_PIT_H.x - 0.003), dune + 0.02);
                col = cvMach(col, sdBox(q - nz, vec2(0.0025, 0.003)), 0.9);
                for(int j = 0; j < 4 + CVZ; j++){
                    float a = fract(iTime * 4. + cvHash(float(j) + float(s) * 7.));
                    vec2 a0 = nz + vec2(-float(s) * 0.003, 0.002 * float(j - 2));
                    vec2 a1 = a0 + vec2(-float(s) * 0.035, -0.008) * (0.3 + a);
                    col += vec3(0.85, 0.9, 1.) * 0.18 * S(sdSegment(q, mix(a0, a1, a * 0.6), a1) - 0.0005) * (1. - a);
                }
            }
            for(int j = 0; j < 10 + CVZ; j++){
                float fj = float(j);
                float a = fract(iTime * 1.8 + cvHash(fj + 0.7));
                vec2 o = vec2(CV_DROP_X + (cvHash(fj + 2.1) - 0.5) * 0.02, dune + 0.01);
                vec2 p = o + vec2(0.05 * a * (cvHash(fj + 5.) - 0.5), 0.03 * a - 0.05 * a * a);
                col = mix(col, CV_SAND * 0.9, S(length(q - p) - 0.0008) * (1. - a));
            }
        }
        if(abs(q.x - CV_PAT_X) < 0.03 && q.y > CV_PIT.y - 0.05 && q.y < CV_TOPY + 0.03){
            col = mix(col, CV_MC * 0.5, S(abs(q.x - CV_PAT_X + 0.015) - 0.0008));
            float dryK = smoothstep(0.03, 0., max(CV_DRYY.x - q.y, q.y - CV_DRYY.y));
            col += vec3(1., 0.35, 0.06) * 0.1 * dryK * step(abs(q.x - CV_PAT_X), 0.017);
            col = mix(col, vec3(1.3, 0.4, 0.06) * (0.8 + 0.2 * sin(iTime * 3. + q.y * 40.)), S(sdBox(q - vec2(CV_PAT_X - 0.0155, (CV_DRYY.x + CV_DRYY.y) * 0.5), vec2(0.0015, (CV_DRYY.y - CV_DRYY.x) * 0.5))));
            if(q.y > CV_WASHY.x - 0.02 && q.y < CV_WASHY.y + 0.02){
                for(int k = 0; k < 3 + CVZ; k++){
                    vec2 nz = vec2(CV_PAT_X + 0.0155, mix(CV_WASHY.x, CV_WASHY.y, (float(k) + 0.5) / 3.));
                    col = cvMach(col, sdBox(q - nz, vec2(0.0022, 0.003)), 0.9);
                    for(int j = 0; j < 5 + CVZ; j++){
                        float a = fract(iTime * 2.5 + cvHash(float(j + k * 5) + 0.3));
                        vec2 p = nz + vec2(-0.03 * a, (cvHash(float(j + k * 5)) - 0.5) * 0.02 * a - 0.008 * a * a);
                        col = mix(col, vec3(0.6, 0.8, 0.9), S(length(q - p) - 0.0008) * (1. - a * 0.6));
                    }
                }
            }
            if(q.y > CV_DRYY.x && q.y < CV_DRYY.y + 0.04){
                for(int j = 0; j < 4 + CVZ; j++){
                    float a = fract(iTime * 0.6 + float(j) * 0.25);
                    vec2 sc = vec2(CV_PAT_X + 0.006 * sin(a * 6. + float(j)), CV_DRYY.x + 0.02 + a * 0.11);
                    col = mix(col, vec3(0.75), S(length(q - sc) - 0.004 - a * 0.006) * 0.15 * (1. - a));
                }
            }
            float nzY = CV_FILLY.y + 0.022;
            col = cvMach(col, sdBox(q - vec2(CV_PAT_X, nzY), vec2(0.004, 0.003)), 0.9);
            float stream = sdSegment(q, vec2(CV_PAT_X, nzY - 0.003), vec2(CV_PAT_X, CV_FILLY.x)) - 0.0012;
            col = mix(col, CV_SAND * (0.6 + 0.5 * tcNoise(vec2(q.x * 600., (q.y + iTime * 0.3) * 600.))), S(stream));
        }
    }
    return col;
}

vec3 cvSand(vec3 col, vec2 q, float carve){
    if(q.x > CVG(-30.) && q.x < CV_RET_X - 0.02 && abs(q.y - CV_RET_Y) > CVG(1.5)) return col;
    if(q.x > CV_RET_X + 0.03) return col;
    col = cvSandSeg(col, q, vec2(CV_RET_X + 0.009, CV_TOPY - CV_SIZE * 0.5 - 0.003), vec2(CV_RET_X + 0.009, CV_RET_Y - CV_CELL - 0.003), carve, 0.25);
    col = cvSandSeg(col, q, vec2(CV_RET_X + 0.009, CV_RET_Y - CV_CELL - 0.003), vec2(CV_DROP_X + 0.011, CV_RET_Y - CV_CELL - 0.003), carve, 0.12);
    float pitB = CV_PIT.y - CV_PIT_H.y + 0.004;
    col = cvSandSeg(col, q, vec2(CV_PIT.x + CV_PIT_H.x, pitB), vec2(CV_SELEV_X, pitB), carve, 0.1);
    float topY = CV_HOPPER.y + 0.045;
    if(abs(q.x - CV_SELEV_X) < 0.015 && q.y > pitB - 0.01 && q.y < topY + 0.01){
        float sh = sdBox(q - vec2(CV_SELEV_X, (pitB + topY) * 0.5), vec2(0.008, (topY - pitB) * 0.5));
        col = mix(col, CV_HOLE, S(sh));
        col = mix(col, CV_SLAB * 0.55, S(abs(sh) - 0.0007) * 0.8);
        col = mix(col, CV_MC * 0.5, S(abs(q.x - CV_SELEV_X + 0.004) - 0.0007) * step(sh, 0.));
        float v = q.y - iTime * 0.06;
        float cell = fract(v / 0.022) * 0.022 - 0.011;
        float bk = max(sdBox(vec2(q.x - CV_SELEV_X - 0.001, cell), vec2(0.0045, 0.004)), -sdBox(vec2(q.x - CV_SELEV_X - 0.001, cell - 0.002), vec2(0.0032, 0.004)));
        col = mix(col, CV_MC * 0.8, S(bk) * step(sh, 0.));
        col = mix(col, CV_SAND * 0.8, S(sdBox(vec2(q.x - CV_SELEV_X - 0.001, cell - 0.0005), vec2(0.0032, 0.0022))) * step(sh, 0.));
    }
    col = cvSandSeg(col, q, vec2(CV_SELEV_X, topY), vec2(CV_HOPPER.x + 0.02, topY), carve, 0.1);
    col = cvSandSeg(col, q, vec2(CV_HOPPER.x, CV_HOPPER.y - 0.03), vec2(CV_HOPPER.x, CV_FILLY.y + 0.022), carve, 0.2);
    col = cvSandSeg(col, q, vec2(CV_HOPPER.x, CV_FILLY.y + 0.022), vec2(CV_PAT_X + 0.004, CV_FILLY.y + 0.022), carve, 0.2);
    vec2 hq = q - CV_HOPPER;
    float hop = cvTrapezoid(hq, 0.01, 0.035, 0.03);
    if(hop < 0.01){
        col = mix(col, vec3(0.), (1. - smoothstep(0., 0.006, hop)) * 0.3);
        float lvl = 0.01 + 0.002 * sin(iTime * 0.7);
        vec3 inner = mix(CV_HOLE, CV_SAND * (0.5 + 0.45 * tcNoise(q * 500. + vec2(0., iTime * 0.3))), step(hq.y, lvl));
        col = mix(col, inner, S(hop));
        col = mix(col, CV_SLAB * 0.55, S(abs(hop) - 0.0007) * 0.8);
    }
    for(int li = 0; li < 3 + CVZ; li++){
        float y = CV_ST_Y[li] - CV_SIZE * 0.5 - 0.002;
        float gr = sdBox(q - vec2(CV_RET_X, y), vec2(0.014, 0.0025));
        if(gr > 0.003) continue;
        col = mix(col, CV_HOLE * 0.6, S(gr));
        col = mix(col, CV_MC * 0.6, S(gr) * step(0.5, fract(q.x / 0.004)));
    }
    return col;
}

// the mould press at the head of foundry line k - CS_PRESS: its head
// stamps the piece into a fresh block of sand
vec3 cvMouldPress(vec3 col, vec2 q, int k, vec4 st, vec4 jam){
    vec2 sp = cvStPos(k);
    if(abs(q.x - sp.x) > 0.04 || q.y < sp.y - 0.02 || q.y > sp.y + 0.07) return col;
    int li = k - CS_PRESS, kind = li == 0 ? 1 : li == 1 ? 0 : 2;
    bool jm = jam.x == float(k) && jam.y < CV_FIX_AT;
    float p = st.x >= 0. && !jm ? st.x : 0.;
    float down = smoothstep(0.1, 0.35, p) * (1. - smoothstep(0.6, 0.9, p));
    float top = sp.y + (CV_MCEN[kind].y + CV_MHALF[kind].y) * CV_SIZE;
    col = cvHead(col, q, k, down, vec2(0.014, 0.005), 1., li == 1 ? 0.03 : 0.02, top);
    float since = (p - 0.35) * CV_ST_DW[k];
    if(p > 0.35 && since < 0.3){
        vec2 c = vec2(sp.x, top);
        for(int j = 0; j < 6 + CVZ; j++){
            float fj = float(j);
            vec2 v = vec2((cvHash(fj + float(k)) - 0.5) * 0.12, 0.03 + 0.03 * cvHash(fj + 3.));
            vec2 pp = c + v * since + vec2(0., -0.3) * since * since;
            col = mix(col, CV_SAND, S(length(q - pp) - 0.0012) * (1. - since / 0.3));
        }
    }
    return col;
}

// the paternoster's pistons, one in the wall by the head of each line, out
// when they have just pushed a flask across
vec3 cvPistons(vec3 col, vec2 q){
    if(q.x < CVG(-36.) || q.x > CVG(-34.) || q.y < CVG(8.) || q.y > CVG(17.)) return col;
    for(int li = 0; li < 3 + CVZ; li++){
        float since = cvState(CX_PUSH + li, CV_ROW).x;
        float ext = 1. - smoothstep(0.12, 0.45, since);
        float y = CV_ST_Y[li];
        float wall = CVG(-35.);
        col = cvMach(col, sdBox(q - vec2(wall - CVG(0.45), y), vec2(CVG(0.4), 0.006)), 0.75);
        float hx = wall + ext * CVG(0.35);
        col = cvMach(col, sdBox(q - vec2((wall + hx) * 0.5, y), vec2(max((hx - wall) * 0.5, 0.0005), 0.0018)), 1.1);
        col = cvMach(col, sdBox(q - vec2(hx, y), vec2(0.0015, 0.009)), 0.9);
    }
    return col;
}

vec3 cvScene(vec2 q, vec2 tp){
    float fit = cvFit(iResolution.x / iResolution.y);
    float asp = iResolution.x / iResolution.y / fit;
    q = q / fit + vec2(CV_CX, CV_CY);
    vec4 st[31];
    for(int k = 0; k < CV_NS + CVZ; k++) st[k] = cvState(k, CV_ROW);
    vec4 jam = cvState(CX_JAM, CV_ROW), so = cvState(CX_SORT, CV_ROW);
    float carve = cvCarve(q);
    vec3 col = cvSlab(q, tp, carve);
    col = cvWallHoles(col, q, tp);
    col = cvVeins(col, q, carve);
    col = cvHeater(col, q, carve);
    col = cvDrum(col, q);
    col = cvDripBack(col, q);
    col = cvSplat(col, q, st[CS_FLICK]);
    col = cvSand(col, q, carve);
    col = cvFlasks(col, q);
    col = cvFans(col, q);
    col = cvPanel(col, (q - vec2(CVG(-23.5), CVG(-13.6))) / 0.6, st[CS_LABEL].w);
    col = cvBelts(col, q);
    col = cvPlinko(col, q);
    col = cvXray(col, q, st[CS_XRAY], false);
    vec2 gs = cvGoopShake(st[CS_CLEAR].x);
    for(int k = CS_PRIME + 1; k <= CS_CLEAR + CVZ; k++) col = cvBoothBack(col, k == CS_CLEAR ? q + gs : q, k, st[k]);
    col = cvGoopStains(col, q + gs, st[CS_CLEAR].x);
    col = cvCatapult(col, q, st[CS_PRIME + 1].x);
    col = cvTiltTable(col, q, st[CS_PRIME + 2].x);
    col = cvPolishBack(col, q, st[CS_POLISH]);
    col = cvClassBack(col, q, st[CS_CLASS]);
    col = cvTrapDoor(col, q, max(asp, 2.3));
    col = cvBounceRoom(col, q, cvState(CX_HATFLY, CV_ROW).x);
    col = cvCoronBack(col, q, st[CS_HAT]);

    vec4 sl[AG_TEX];
    agSlots(iChannel17, q, max(asp, 2.3), sl);
    int ids[AG_SLOTS];
    float keys[AG_SLOTS];
    int nid = 0;
    for(int k = 0; k < AG_SLOTS + CVZ; k++){
        int i = int(sl[k >> 2][k & 3] + 0.5) - 1;
        if(i < 0) break;
        vec4 r1 = cvState(i, 1);
        int t = cvI(r1.x);
        float rk = t == CT_DROP ? 1. : t == CT_MAIN ? 2. : t == CT_FIN ? 3. : t == CT_SLIDE || t == CT_REJ ? 4. : t == CT_PACK ? 5. : 0.;
        float key = rk * 100. + r1.y;
        int j = nid;
        while(j > 0 && keys[j - 1] > key){ ids[j] = ids[j - 1]; keys[j] = keys[j - 1]; j--; }
        ids[j] = i;
        keys[j] = key;
        nid++;
    }
    for(int k = 0; k < AG_SLOTS + CVZ; k++){
        if(k >= nid) break;
        col = cvItem(col, q, ids[k]);
    }

    col = cvWind(col, q);
    col = cvPistons(col, q);
    col = cvCaustic(col, q, st[CS_CAUSTIC]);
    col = cvHangers(col, q, max(asp, 2.3));
    col = cvFlickArm(col, q, st[CS_FLICK]);
    col = cvDripFront(col, q, max(asp, 2.3));
    col = cvRotor(col, q, st[CS_CAUSTIC]);
    col = cvPours(col, q, st);
    col = cvBasin(col, q, cvState(CX_SPLASH, CV_ROW).xy);
    for(int k = 3; k < 6 + CVZ; k++) col = cvHammer(col, q, k, st[k], jam);
    for(int k = CS_PRESS; k < CS_PRESS + 3 + CVZ; k++) col = cvMouldPress(col, q, k, st[k], jam);
    col = cvArm(col, q, 0, st[CS_WELD1]);
    col = cvArm(col, q, 1, st[CS_WELD2]);
    col = cvXray(col, q, st[CS_XRAY], true);
    col = cvGrinder(col, q, st[CS_GRIND]);
    col = cvBootAt(col, q, cvStPos(CS_BOOT), CVG(17.), st[CS_BOOT].x, st[CS_BOOT].z);
    for(int j = 0; j < 5 + CVZ; j++){
        int k = CV_QC_K[j];
        vec4 kt = cvState(CX_QK + j, CV_ROW);
        float bx = st[k].x >= 0. && cvI(kt.y) == cvI(st[k].y) && kt.z > 0.5 ? st[k].x : -1.;
        col = cvBootAt(col, q, cvStPos(k), cvStPos(k).y + CVG(0.95), bx, kt.x);
    }
    col = cvCoatRing(col, q, st[CS_PRIME + 1].x);
    col = cvPlotter(col, q, st[CS_PRIME + 2].x);
    col = cvGoopCannon(col, q + gs, st[CS_CLEAR].x);
    col = cvColumn(col, q, st, max(asp, 2.3));
    col = cvVentSmoke(col, q);
    col = cvPolishFront(col, q, st[CS_POLISH]);
    col = cvHatRig(col, q, st[CS_HAT]);
    col = cvHatFly(col, q, cvState(CX_HATFLY, CV_ROW).x);
    col = cvPack(col, q, st, jam);
    col = cvJamLamp(col, q, jam);
    col *= 1. - 0.2 * smoothstep(0.65, 1.3, length((q - vec2(CV_CX, CV_CY)) * vec2(0.8, 1.)));
    col = cvKickedAt(col, q, cvStPos(CS_BOOT), st[CS_BOOT].z, asp, fit, false);
    for(int j = 0; j < 5 + CVZ; j++) col = cvKickedAt(col, q, cvStPos(CV_QC_K[j]), cvState(CX_QK + j, CV_ROW).x, asp, fit, true);
    if((u_traffic_debug & 16) != 0){
        vec2 gc = q / CV_CELL;
        vec2 gd = abs(gc - floor(gc + 0.5)) * CV_CELL;
        vec2 g5 = abs(gc / 5. - floor(gc / 5. + 0.5)) * 5. * CV_CELL;
        float px = 1. / iResolution.y;
        col = mix(col, vec3(0.45, 0.8, 1.), 0.18 * (1. - smoothstep(0., px, min(gd.x, gd.y))));
        col = mix(col, vec3(0.45, 0.8, 1.), 0.35 * (1. - smoothstep(0., 1.5 * px, min(g5.x, g5.y))));
        col = mix(col, vec3(1., 0.5, 0.3), 0.6 * (1. - smoothstep(0., 1.5 * px, min(abs(q.x), abs(q.y)))));
    }
    return col;
}

vec3 conveyor(vec2 q, vec2 tp){ return texture(iChannel18, roomUV(q)).rgb; }
