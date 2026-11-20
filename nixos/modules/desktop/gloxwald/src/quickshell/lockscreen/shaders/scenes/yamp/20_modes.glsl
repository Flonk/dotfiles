// --- mode sequencer ------------------------------------------------------------
// The playlist (scenes with a transition after each) is walked once a frame
// in LockContext (seqInfo), which hands over the slot playing as u_seq (mode,
// seconds into it, a number unique to this showing, the mode before) and
// u_seq2 (the mode after, how long this slot runs, how long the one before
// ran; scene lengths live in LockContext's sceneTable). Scenes cut
// straight into transitions and out of them; each transition draws the
// scene before it and the one after it (gPrevCol, gNextCol) into its own
// handover.

float W[MODE_COUNT];
// each mode's own clock (seconds since its slot began) and a number unique
// to that showing, for the transitions
float gModeT[MODE_COUNT];
float gModeK[MODE_COUNT];
float gDropStart = 0.;

// the slot playing at time (dev jumps restart the playlist at the chosen
// mode): a scene (gScene), or a transition (gTrans) between gPrev and gNext;
// every mode it touches gets its own clock in gModeT and a number unique to
// this showing in gModeK
int gScene = 0, gTrans = -1, gPrev = 0, gNext = 0;
vec3 gPrevCol = vec3(0.), gNextCol = vec3(0.);

bool isTransition(int m){ return m == MODE_FLAP || (m >= MODE_SHATTER && m <= MODE_STAMP); }

void sequenceModes(vec2 q){
    int m = int(u_seq.x + 0.5);
    float modeTime = u_seq.y, lap = u_seq.z;
    for(int i = 0; i < MODE_COUNT; i++) W[i] = 0.;
    W[m] = 1.;
    gModeT[m] = modeTime;
    gModeK[m] = lap;
    gTrans = -1;
    gScene = m;
    if(isTransition(m)){
        gTrans = m;
        gPrev = int(u_seq.w + 0.5);
        gNext = int(u_seq2.x + 0.5);
        W[gPrev] = 1.;
        W[gNext] = 1.;
        if(gPrev == MODE_DROP) gDropStart = iTime - modeTime - u_seq2.z;
        if(gNext == MODE_DROP) gDropStart = iTime - modeTime + MODE_DUR[m];
    } else if(m == MODE_DROP) gDropStart = iTime - modeTime;
}
