// --- mode sequencer ------------------------------------------------------------
// The ModeParams struct and the MODES playlist live in 00_knobs. The
// sequencer walks the playlist and swaps the global P between neighbours
// per pixel behind a circle wipe (WIPE_DUR) — so any mode expressible as parameters
// transitions for free. Structural modes (different traversal/tile content)
// branch on modeFrom/modeTo/modeBlend instead; keep those branches rare.

ModeParams P;          // active params, filled per frame by sequenceModes()
int   modeFrom  = 0;   // structural hooks branch on these
int   modeTo    = 0;
float modeBlend = 1.;  // eased from->to progress, 1 once settled
float modeTime  = 0.;  // seconds into the current playlist block
float gDropStart = 0.;

ModeParams mixParams(ModeParams a, ModeParams b, float t){
    return ModeParams(
        mix(a.pad, b.pad, t), mix(a.bg, b.bg, t),
        mix(a.light, b.light, t), mix(a.dark, b.dark, t),
        mix(a.ring, b.ring, t), mix(a.distort, b.distort, t),
        mix(a.wham, b.wham, t), mix(a.spec, b.spec, t),
        mix(a.cloud, b.cloud, t), mix(a.aur, b.aur, t),
        mix(a.warm, b.warm, t), mix(a.terra, b.terra, t),
        mix(a.neb, b.neb, t), mix(a.star, b.star, t),
        mix(a.squir, b.squir, t), mix(a.warhol, b.warhol, t),
        mix(a.big, b.big, t), mix(a.field, b.field, t),
        mix(a.drop, b.drop, t), mix(a.solid, b.solid, t),
        mix(a.halftone, b.halftone, t), mix(a.shadow, b.shadow, t));
}

float wipe(vec2 q, float t){
    float x = clamp(t / WIPE_DUR, 0., 1.);
    if(x >= 1.) return 1.;
    float r = (1. - pow(1. - x, 3.)) * (0.5 * length(iResolution.xy) / iResolution.y + 0.01);
    return S(length(q) - r);
}

ModeParams evalModes(vec2 q, float time, int devMode, float devAt){
    float skip = 0.;
    float since = time;
    if(devMode >= 0){
        for(int i = 0; i < devMode % MODE_COUNT; i++) skip += MODE_DUR[i];
        since = time - devAt;
    }
    float t = since + skip;
    float total = 0.;
    for(int i = 0; i < MODE_COUNT; i++) total += MODE_DUR[i];
    float c = mod(t, total);
    float acc = 0.;
    for(int i = 0; i < MODE_COUNT; i++){
        float d = MODE_DUR[i];
        if(c < acc + d){
            modeTo    = i;
            modeFrom  = (i + MODE_COUNT - 1) % MODE_COUNT;
            modeTime  = c - acc;
            modeBlend = wipe(q, modeTime);
            break;
        }
        acc += d;
    }
    // very first block (already active at iTime 0, wherever the skip landed
    // it): no flip-in from the notional previous mode
    if(since <= modeTime + 0.001) modeFrom = modeTo;
    if(MODES[modeTo].drop > 0.5) gDropStart = time - modeTime;
    else if(MODES[modeFrom].drop > 0.5) gDropStart = time - modeTime - MODE_DUR[modeFrom];
    ModeParams r = mixParams(MODES[modeFrom], MODES[modeTo], modeBlend);

    // clouds don't blend through transitions — the pad/zoom retune makes
    // them slide. instead they fade in for TRANS_DUR after the transition
    // lands, and fade out over the last TRANS_DUR before the next one
    float d = MODE_DUR[modeTo];
    r.cloud = MODES[modeTo].cloud
            * smoothstep(TRANS_DUR, 2.*TRANS_DUR, modeTime)
            * (1. - smoothstep(d - TRANS_DUR, d, modeTime));
    return r;
}

void sequenceModes(vec2 q){
    float sw = iTime - u_dev_switch_at;
    bool switching = sw >= 0. && sw < WIPE_DUR;
    ModeParams prev;
    if(switching) prev = evalModes(q, u_dev_switch_at, u_dev_prev_mode, u_dev_prev_at);
    P = evalModes(q, iTime, u_dev_mode, u_dev_mode_at);
    if(switching) P = mixParams(prev, P, wipe(q, sw));
}
