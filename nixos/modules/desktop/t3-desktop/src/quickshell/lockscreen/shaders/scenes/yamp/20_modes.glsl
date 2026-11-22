float W[MODE_COUNT];
float gModeT[MODE_COUNT];
float gModeK[MODE_COUNT];
float gDropStart = 0.;

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
