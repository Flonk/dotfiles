// --- mode sequencer ------------------------------------------------------------
// The ModeParams struct and the MODES playlist live in 00_knobs. The
// sequencer walks the playlist and eases the global P between neighbours
// over TRANS_DUR at each boundary — so any mode expressible as parameters
// transitions for free. Structural modes (different traversal/tile content)
// branch on modeFrom/modeTo/modeBlend instead; keep those branches rare.

ModeParams P;          // active params, filled per frame by sequenceModes()
int   modeFrom  = 0;   // structural hooks branch on these
int   modeTo    = 0;
float modeBlend = 1.;  // eased from->to progress, 1 once settled
float modeTime  = 0.;  // seconds into the current playlist block

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
        mix(a.big, b.big, t));
}

void sequenceModes(){
    // super-mode order: sk_seed(2) may open the session on the warhol arc
    // by skipping the clock past the planets arc, onto its circles block
    float skip = 0.;
    if(sk_seed(2) < WARHOL_FIRST)
        for(int i = 0; i < WARHOL_START; i++) skip += MODE_DUR[i];
    float t = iTime + skip;
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
            modeBlend = smoothstep(0., TRANS_DUR, modeTime);
            break;
        }
        acc += d;
    }
    // very first block (already active at iTime 0, wherever the skip landed
    // it): no flip-in from the notional previous mode
    if(iTime <= modeTime + 0.001) modeFrom = modeTo;
    P = mixParams(MODES[modeFrom], MODES[modeTo], modeBlend);

    // clouds don't blend through transitions — the pad/zoom retune makes
    // them slide. instead they fade in for TRANS_DUR after the transition
    // lands, and fade out over the last TRANS_DUR before the next one
    float d = MODE_DUR[modeTo];
    P.cloud = MODES[modeTo].cloud
            * smoothstep(TRANS_DUR, 2.*TRANS_DUR, modeTime)
            * (1. - smoothstep(d - TRANS_DUR, d, modeTime));
}
