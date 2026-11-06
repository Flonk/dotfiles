const float AMP_SCALE  = 0.94;  // glyph size within its tile
const float TILE_PAD   = 0.01;  // circle padding to its cell edge
const float PAD_ZOOM   = 1.;   // how much tile content zooms out with the
                               // pad (1 = match the circle's shrink, 0 = off)
const float BIG_CHANCE = 0.15;  // chance a cell promotes to one huge amp
const float DARKEN = 0.25;        // off-amp darkening per subdivision level
const float SCROLL_MIN = 0.045;  // tile content scroll speed, random per tile
const float SCROLL_MAX = 0.09;
const float RING_BRIGHT = 0.3;    // border ring brightness
const float RING_WIDTH  = 0.0025; // border ring half-width, screen-height
                                  // units — same thickness at every level

// tile zoom pulse: up during rotate, hold, down during unfill
float pulseAnim(float n){
    float frame = mod(iTime*n*2.*SPEED, LOOP_LEN);
    if(frame >= ROT_START && frame < ROT_START+T_ROTATE)
        return cubicInOut((frame-ROT_START)/T_ROTATE);
    if(frame >= ROT_START+T_ROTATE && frame < UNFILL_START)
        return 1.;
    if(frame >= UNFILL_START && frame < UNFILL_START+T_UNFILL)
        return 1.-cubicInOut((frame-UNFILL_START)/T_UNFILL);
    return 0.;
}

vec3 drawAmp(vec2 p, float n, float sqd, float depth, float tileDepth){
    float tshade = pow(1. - DARKEN, tileDepth);

    // tile distance in screen-height units: undo the zoom, the two fixed
    // x2 grid scales and the tile's subdivision levels
    float sqs = sqd / (4. * exp2(tileDepth) * gZoom);
    if (sqs * iResolution.y > 1.5) return vec3(0.);

    // content clip at the rim: fades out fully AT the rim so nothing leaks
    // through the border ring's outer AA
    float rim = S(sqs + 1.3/iResolution.y);

    float frame = mod(iTime*n*2.*SPEED, LOOP_LEN);
    p /= AMP_SCALE;
    vec2 pJ, pP;
    ampSpin(p, frame, (fract(n)<0.5)? -1. : 1., pJ, pP);
    vec2 d = ampPieces(pJ, pP);

    // grey base, darker per subdivision level, then the gradient fill
    float dAmp = max(sqd, min(d.x, d.y) * AMP_SCALE);
    vec3 col = mix(vec3(0.), vec3(0.3) * pow(1. - DARKEN, depth), S(dAmp) * rim);
    float dw = max(sqd, ampFill(pJ, pP, d, frame) * AMP_SCALE);
    col = mix(col, ampGradient(p), S(dw) * rim);

    // hard border ring on the rim, drawn on the screen-space distance so
    // every level gets the same thickness
    float dring = abs(sqs + RING_WIDTH) - RING_WIDTH;
    return mix(col, vec3(RING_BRIGHT) * tshade, S(dring));
}

vec3 quadTree(vec2 p, float nn, float depth){
    p*=2.;
    float sqd = max(length(p), 1e-6) - (1. - TILE_PAD);

    // with a large pad the circle shrinks — zoom the content out to match
    p *= 1. + TILE_PAD / (1. - TILE_PAD) * PAD_ZOOM;

    // extra-large level: sometimes the whole cell is one huge ampersand
    if(fract(nn*57.31) < BIG_CHANCE){
        return drawAmp(p*0.5, nn+0.3, sqd, depth, depth);
    }

    if(nn<0.5){
        p.y-=iTime*mix(SCROLL_MIN, SCROLL_MAX, nn*2.)+nn;
        p*=1.2;
    } else {
        p*=1.2+pulseAnim(nn)*0.5;
    }

    vec2 id = floor(p);
    vec2 gr = (p-id)-0.5;

    float n = random(id)*nn;
    float n2 = n;
    vec2 cell = id;
    float ad = depth;   // per-amp depth; `depth` stays the tile's

    // four subdivision levels (the last two add the extra-small amps)
    float thresholds[4] = float[](0.3+nn, 0.8+nn, 0.9+nn*0.5, 0.93+nn*0.5);

    for (int i = 0; i < 4; i++)
    {
        n = random(cell + id + float(i) * 12.34+nn);

        if (n < thresholds[i])
            break;

        gr *= 2.0;
        cell = floor(gr);
        gr = fract(gr) - 0.5;
        ad += 1.;
    }

    return drawAmp(gr, n2+nn, sqd, ad, depth);
}

vec3 tiles(vec2 p){
    p.y-=iTime*SCROLL;
    p*=2.;
    vec2 id = floor(p);
    vec2 gr = (p-id)-0.5;

    float n = random(id);
    float n2 = n;
    vec2 cell = id;
    float depth = 0.;

    float thresholds[3] = float[](0.6, 0.8, 0.9);

    for (int i = 0; i < 3; i++)
    {
        n = random(cell + id + float(i) * 12.34);

        if (n < thresholds[i])
            break;

        gr *= 2.0;
        cell = floor(gr);
        gr = fract(gr) - 0.5;
        depth += 1.;
    }

    return quadTree(gr, n2, depth);
}
