// --- mode sequencer ------------------------------------------------------------
// Walks the playlist and fills W, the per-pixel weight of each mode: 1 on
// the active mode, split between neighbours behind a circle wipe (WIPE_DUR)

float W[MODE_COUNT];
float gDropStart = 0.;

float wipe(vec2 q, float t){
    float x = clamp(t / WIPE_DUR, 0., 1.);
    if(x >= 1.) return 1.;
    float r = (1. - pow(1. - x, 3.)) * (0.5 * length(iResolution.xy) / iResolution.y + 0.01);
    return S(length(q) - r);
}

void addModes(vec2 q, float time, int devMode, float devAt, float k){
    float skip = 0.;
    float since = time;
    if(devMode >= 0){
        for(int i = 0; i < devMode % MODE_COUNT; i++) skip += MODE_DUR[i];
        since = time - devAt;
    }
    float total = 0.;
    for(int i = 0; i < MODE_COUNT; i++) total += MODE_DUR[i];
    float c = mod(since + skip, total);
    float acc = 0.;
    int to = 0;
    float modeTime = 0.;
    for(int i = 0; i < MODE_COUNT; i++){
        if(c < acc + MODE_DUR[i]){
            to = i;
            modeTime = c - acc;
            break;
        }
        acc += MODE_DUR[i];
    }
    int from = (to + MODE_COUNT - 1) % MODE_COUNT;
    // very first block (already active at iTime 0, wherever the skip landed
    // it): no wipe-in from the notional previous mode
    if(since <= modeTime + 0.001) from = to;
    if(to == MODE_DROP) gDropStart = time - modeTime;
    else if(from == MODE_DROP) gDropStart = time - modeTime - MODE_DUR[from];
    float b = wipe(q, modeTime);
    W[from] += k * (1. - b);
    W[to] += k * b;
}

void sequenceModes(vec2 q){
    for(int i = 0; i < MODE_COUNT; i++) W[i] = 0.;
    float sw = iTime - u_dev_switch_at;
    float b = (sw >= 0. && sw < WIPE_DUR) ? wipe(q, sw) : 1.;
    if(b < 1.) addModes(q, u_dev_switch_at, u_dev_prev_mode, u_dev_prev_at, 1. - b);
    addModes(q, iTime, u_dev_mode, u_dev_mode_at, b);
}
