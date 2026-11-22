const float AMP_SCALE  = 0.94;
const float TILE_PAD   = 0.01;
const float PAD_ZOOM   = 1.;
const float BIG_CHANCE = 0.15;
const float DARKEN = 0.25;
const float SCROLL_MIN = 0.045;
const float SCROLL_MAX = 0.09;
const float RING_BRIGHT = 0.3;
const float RING_WIDTH  = 0.0025;

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

    float sqs = sqd / (4. * exp2(tileDepth) * gZoom);
    if (sqs * iResolution.y > 1.5) return vec3(0.);

    float rim = S(sqs + 1.3/iResolution.y);

    float frame = mod(iTime*n*2.*SPEED, LOOP_LEN);
    p /= AMP_SCALE;
    vec2 pJ, pP;
    ampSpin(p, frame, (fract(n)<0.5)? -1. : 1., pJ, pP);
    vec2 d = ampPieces(pJ, pP);

    float dAmp = max(sqd, min(d.x, d.y) * AMP_SCALE);
    vec3 col = mix(vec3(0.), vec3(0.3) * pow(1. - DARKEN, depth), S(dAmp) * rim);
    float dw = max(sqd, ampFill(pJ, pP, d, frame) * AMP_SCALE);
    col = mix(col, ampGradient(p), S(dw) * rim);

    float dring = abs(sqs + RING_WIDTH) - RING_WIDTH;
    return mix(col, vec3(RING_BRIGHT) * tshade, S(dring));
}

vec3 quadTree(vec2 p, float nn, float depth){
    p*=2.;
    float sqd = max(length(p), 1e-6) - (1. - TILE_PAD);

    p *= 1. + TILE_PAD / (1. - TILE_PAD) * PAD_ZOOM;

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
    float ad = depth;

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
