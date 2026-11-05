// yamp scene body — see 00_knobs.glsl for the full scene description and
// 20_modes.glsl for the mode system. All mode-dependent values come from
// the global P; nothing here asks which mode is active.

vec3  SUN = vec3(0., 0.7, 0.7);   // sun direction, set in mainImage —
                                  // drives the glint and the aurora
float gCoast = 0.;  // coastline fbm amplitude for sdJ/sdP; set in
                    // mainImage for the scene, zeroed for the indicator
vec3  gPop = vec3(0.);  // warhol: this tile's pop color, set in quadTree
float gInv = 0.;        // warhol: 1 = inverted tile

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

// --- and& ampersand: baked SDF texture (gen_sdf.py) -------------------------
// iChannel0: R = J piece, G = P piece, B = glyph-space coastline fbm,
// glyph space [-SDF_BOX,SDF_BOX]^2 (v flipped), distances clamped to
// +-SDF_RANGE/2. The fbm is summed onto the distances (amplitude gCoast),
// sampled at the same uv — so the wobble is constant in the glyph frame
// and rotates/scales with each piece
const float PAD = 0.0464;      // design gap, measured from the artwork
const float SDF_BOX   = 0.75;
const float SDF_RANGE = 0.25;
float gFarPad = SDF_RANGE;

// the early-out branches return far + SDF_RANGE — clear of every coast
// band, so the switch never re-enters shelf/relief range (it used to sit
// at ~0.05, painting a phantom circular coastline around each amp). the
// max() keeps the field growing past the texture's clamp plateau
float sdJ(vec2 p) {
    float far = length(p) - 0.57;   // J fits in radius 0.554
    if (far > 0.05) return far + gFarPad;
    vec2 uv = vec2(p.x, -p.y)/(2.0*SDF_BOX) + 0.5;
    vec4 t = texture(iChannel0, uv);
    return max((t.r - 0.5) * SDF_RANGE + (t.b - 0.5) * gCoast, far);
}
float sdP(vec2 p) {
    float far = length(p) - 0.66;   // P fits in radius 0.646
    if (far > 0.09) return far + gFarPad;
    vec2 uv = vec2(p.x, -p.y)/(2.0*SDF_BOX) + 0.5;
    vec4 t = texture(iChannel0, uv);
    return max((t.g - 0.5) * SDF_RANGE + (t.b - 0.5) * gCoast, far);
}

// --- ampersand tile animation ----------------------------------------------
const vec2  CJ = vec2(-0.0644,-0.2581);   // J centroid (spin pivot)
const vec2  CP = vec2( 0.0148, 0.0562);   // P centroid
const vec2  SEED_J = vec2(-0.2871, 0.0267);  // wedge tip
const vec2  SEED_P = vec2(-0.0192, 0.4142);  // top of the loop
const float RJ = 0.76;                    // wipe radii covering each piece
const float RP = 1.04;

float fillAnim(float frame, float start){
    if(frame < start) return 0.;
    if(frame < start+T_FILL) return cubicInOut((frame-start)/T_FILL);
    if(frame < UNFILL_START) return 1.;
    if(frame < UNFILL_START+T_UNFILL) return 1.-cubicInOut((frame-UNFILL_START)/T_UNFILL);
    return 0.;
}

// brand gradient across the glyph (glyph space spans y in [-0.5,0.5])
vec3 ampGradient(vec2 p){
    return mix(GRAD_BOT, GRAD_TOP, clamp(p.y + 0.5, 0., 1.));
}

// cloud density — otavio's recipe on his texture (iChannel2, a lichen-rock
// photo): squared lookups at two scales, one flipped, multiplied and
// contrast-boosted; spiral-warped by a very-low-frequency sample of the
// same photo, which is where the cyclone swirls come from
float cloudDensity(vec2 cuv){
    float blur = texture(iChannel2, cuv * 0.0078).r;
    vec2 suv = spiral(cuv, blur * CLOUD_WARP);
    suv.x += iTime * CLOUD_DRIFT;
    float c1 = texture(iChannel2, suv).r;            c1 *= c1;
    float c2 = texture(iChannel2, 1. - suv * 0.5).r; c2 *= c2;
    return clamp(pow(max(c1 * c2, 0.), CLOUD_SHARP) * CLOUD_GAIN, 0., 1.);
}

vec3 drawAmp(vec2 p, float n, vec3 sq, float depth, float tileDepth, vec2 tp, vec2 tlp){
    // fake sphere: rn runs 0 at the tile center to 1 at the rim; with the
    // rim gradient that gives a surface normal
    float rn = clamp((1. - P.pad + sq.x) / (1. - P.pad), 0., 1.);
    vec3 N = vec3(sq.yz * rn, sqrt(max(1. - rn*rn, 0.)));
    float tshade = pow(1. - DARKEN, tileDepth);

    // tile distance in screen-height units: undo the zoom, the two fixed
    // x2 grid scales and the tile's subdivision levels
    float kk = 4. * exp2(tileDepth) * gZoom;
    float sqs = sq.x / kk;

    // content clip at the rim: fades out fully AT the rim so nothing leaks
    // through the border ring's outer AA, which is wider in screen space
    // than the local-unit glyph edges. in warhol (pad 0, no ring) the clip
    // flips outward instead, so the print runs flush to the square's edge —
    // the inset otherwise leaves a bg-colored grout line between tiles
    float rim = S(sqs + 1.3/iResolution.y * (1. - 2.*P.warhol));

    // the cloud sphere is CLOUD_HEIGHT larger than the ground, so clouds
    // overhang the limb; its rim clip sits that much further out, and the
    // clouds thin out over CLOUD_FADE approaching it
    float shell = CLOUD_HEIGHT * step(0.001, P.cloud) / kk;
    float cloudRim = S(sqs - shell + 1.3/iResolution.y)
                   * smoothstep(CLOUD_HEIGHT, CLOUD_HEIGHT - CLOUD_FADE, sq.x);

    // event horizon (3d): outside the tile the noise and stars get sucked
    // toward the rim and pile up into a bright horizon — background and tile
    // border in one. windowed to zero within the pad so neighbouring cells
    // agree
    float pull = PILE_BAND / (max(sq.x, 0.) + PILE_BAND);
    pull *= pull * smoothstep(max(P.pad, 1e-3), 0., sq.x);
    vec2 tps = tp + sq.yz * pull * PILE_PULL;
    float nse = texture(iChannel1, fract(tps)).r;
    vec3 base = vec3(mix(NOISE_LO, NOISE_HI, nse)) + stars(tps, P.star) * STAR_BRIGHT;
    // baked kaliset nebula (iChannel3, raw fields in rg), riding the same
    // background coords so it scrolls and gets pulled into the horizon
    // like the stars. squared -> dark space stays dark, hues stay stable
    if(P.neb > 0.001){
        vec2 nf = texture(iChannel3, tps * NEB_SCALE).rg * 2.;
        nf *= nf;
        base += (NEB1_COL * nf.x * NEB1_BRIGHT
               + NEB2_COL * nf.y * NEB2_BRIGHT) * P.neb;
    }

    // aurora: the horizon pile-up takes the atmosphere tint, plus a soft
    // additive glow. the sunset warming only appears when the sun is
    // actually BEHIND the planet (SUN.z < 0), on the rim facing it
    float sunset = pow(max(dot(sq.yz, normalize(SUN.xy)), 0.), AUR_SUN_POW)
                 * max(-SUN.z, 0.);
    vec3 aurTint = mix(vec3(1.), mix(AUR_COLOR, AUR_SUNSET, sunset), P.aur);
    vec3 v3 = vec3(base)
            + (base * PILE_GAIN + AUR_GLOW * pull * P.aur) * pull * aurTint;
    // tile interior: black, becoming ocean in terra mode, or the pop color
    // on inverted warhol tiles — unclipped, so zero-pad squares meet with
    // no dark seam at the shared edge
    vec3 col = mix(v3 * P.bg, WATER_COL * P.terra, S(sq.x));
    col = mix(col, gPop * tshade, P.warhol * gInv);

    // outside pixels are done — skip both glyph SDFs entirely
    if ((sqs - shell) * iResolution.y > 1.5) return col;

    float frame = mod(iTime*n*2.*SPEED, LOOP_LEN);
    // terra: pad the amps within their cells so the coast bands get room
    // before the cell boundary
    float ampScale = AMP_SCALE * (1. - AMP_PAD * P.terra);
    p /= ampScale;

    // rotate state: J and P counter-spin a full turn
    vec2 pJ = p, pP = p;
    if(frame >= ROT_START && frame < ROT_START+T_ROTATE){
        float a = cubicInOut((frame-ROT_START)/T_ROTATE)*6.28318530718;
        float dir = (fract(n)<0.5)? -1. : 1.;
        pJ = rotAround(p, CJ, dir*a);
        pP = rotAround(p, CP, -dir*a);
    }

    float dj = sdJ(pJ);
    float dp = max(sdP(pP), PAD - dj);            // P with the J carved out
    float dAmp = min(dj, dp) * ampScale;

    // terra: soften the glyphs — a constant inset rounds the 90° corners
    float cw = -CORNER_ROUND * P.terra;
    dAmp += cw;
    dAmp = max(sq.x, dAmp);
    // terra: detail mottling, dirt specks (a spiral-distorted cloud-texture
    // lookup), and a shallow shelf on the water approaching a coast (the
    // land overdraws its inside half)
    float dmod = 1., spk = 0., cellW = 1.;
    if(P.terra > 0.001){
        float det = texture(iChannel2, tlp * DETAIL_SCALE + 0.37).g;
        dmod = 1. + (det - 0.5) * DETAIL_AMT;
        spk = texture(iChannel2, spiral(tlp * SPECK_SCALE + 0.71, SPECK_WARP)).r;
        spk = smoothstep(SPECK_LO, SPECK_HI, spk * spk) * SPECK_AMT;
        // cell-edge window: coast bands die out before the amp cell
        // boundary so neighbouring cells agree (the horizon-pad trick)
        cellW = smoothstep(0., COAST_W, 0.5/ampScale - max(abs(p.x), abs(p.y)));
        col = mix(col, WATER_SHALL,
                  smoothstep(COAST_W, 0., dAmp) * cellW * rim * P.terra);
    }

    // grey base, darker per subdivision level; in terra mode: a sand ring
    // at the waterline, detail-modulated specked lowland inside. warhol:
    // the print color (black on inverted tiles), same depth shading
    vec3 terrLand = mix(SAND_COL, mix(LAND_COL * dmod, SPECK_COL, spk),
                        smoothstep(0., -SAND_W, dAmp));
    vec3 ampBase = mix(vec3(0.3), terrLand, P.terra);
    ampBase = mix(ampBase, gPop * (1. - gInv), P.warhol);
    col = mix(col, ampBase * pow(1. - DARKEN, depth), S(dAmp) * rim);

    // fill states: brand-gradient wipes clipped inside each piece
    float fj = fillAnim(frame, FILLJ_START);
    float fp = fillAnim(frame, FILLP_START);
    float wj = max(dj, length(pJ-SEED_J) - (fj*(RJ+0.02)-0.02));
    float wp = max(dp, length(pP-SEED_P) - (fp*(RP+0.02)-0.02));
    float dw = min(wj, wp) * ampScale + cw;   // same terra softening
    dw = max(sq.x, dw);
    // brand-gradient fill; in terra mode snow-covered high terrain with a
    // thin rock rim, detail mottling toned down on the snow. suppressed in
    // warhol — tiles keep their printed color and just sit
    vec3 fillCol = mix(ampGradient(p),
                       mix(HIGH_BOT, HIGH_TOP, smoothstep(0., -SNOW_D, dw))
                       * mix(1., dmod, SNOW_DETAIL),
                       P.terra);
    col = mix(col, fillCol, S(dw) * rim * (1. - P.warhol));

    // emboss: terrain slopes facing the sun brighten, away-facing darken,
    // strongest right at coasts and ridges. the SDF gradients come from
    // screen derivatives (y flipped back to scene orientation)
    if(P.terra > 0.001){
        vec2 sxy = normalize(SUN.xy);
        vec2 gc = vec2(dFdx(dAmp), -dFdy(dAmp));
        vec2 gr_ = vec2(dFdx(dw),  -dFdy(dw));
        float rel = dot(normalize(gc + 1e-5), sxy) * smoothstep(RELIEF_W, 0., abs(dAmp))
                  + dot(normalize(gr_ + 1e-5), sxy) * smoothstep(RELIEF_W, 0., abs(dw));
        col *= 1. + rel * RELIEF * P.terra * rim * cellW;
    }

    // clouds, drawn before the shade so they get lit and shadowed too.
    // toy-planet height: the ground is darkened by the cloud shell sunward
    // of it, so the clouds float visibly above their own drop shadows
    if(P.cloud > 0.001){
        vec2 cuv = tlp * CLOUD_SCALE;
        float shadow = cloudDensity(cuv + SUN.xy * CLOUD_HEIGHT * CLOUD_SCALE);
        col = mix(col, vec3(0.), shadow * CLOUD_SHADOW * P.cloud * rim);
        col = mix(col, vec3(1.), cloudDensity(cuv) * P.cloud * cloudRim);
    }

    // sun diffuse on the fake sphere — lift the lit side toward white,
    // shadow the night side toward black, terminator where dot(N,SUN)
    // crosses zero. the lift is scaled by the TILE's depth shade (never
    // the per-amp one, which would break the gradient inside a tile); the
    // shadow is relative, so it reads the same at every depth
    float dif = dot(N, SUN);
    col = mix(col, vec3(1.), max( dif, 0.) * P.light * tshade * S(sq.x));
    col = mix(col, vec3(0.), max(-dif, 0.) * P.dark * S(sq.x));

    // sun glint: blinn-phong specular on the fake sphere normal, over
    // everything under the glass; in terra mode only the water reflects
    vec3 H = normalize(SUN + vec3(0., 0., 1.));
    col += mix(SUN_WHITE, SUN_COL, P.warm)
         * pow(max(dot(N, H), 0.), SPEC_POW) * SPEC_GAIN * P.spec * rim
         * (1. - S(dAmp) * rim * P.terra);

    // atmospheric haze: a constant veil over the whole disc, plus more
    // toward the limb where the view ray crosses more air (N.z -> 0)
    float haze = (ATMO_BASE + pow(1. - N.z, ATMO_POW) * ATMO_HAZE) * P.aur;
    col = mix(col, HAZE_COL, haze * S(sq.x));

    // hard border ring on the rim, gated by P.ring. drawn on the
    // screen-space distance so every level gets the same thickness, and
    // darkened per subdivision level like the amps
    float dring = abs(sqs + RING_WIDTH) - RING_WIDTH;
    col = mix(col, vec3(RING_BRIGHT) * tshade, S(dring) * P.ring);
    return col;
}

vec3 quadTree(vec2 p, float nn, float depth, vec2 tp){
    p*=2.;
    vec3 sq = sdSquircle(p, 1. - P.pad, mix(SQUIRCLENESS, 1., P.squir));

    // warhol identity: each tile hashes a palette color and an invert flip
    gPop = WARHOL_COLS[int(min(fract(nn*13.7)*4., 3.))];
    gInv = step(fract(nn*29.3), WARHOL_INV);

    // glass: inside the rim band the content is sampled outward along the
    // squircle gradient, so the amps look refracted near the edge
    float lens = smoothstep(-DISTORT_BAND, 0., sq.x);
    p += sq.yz * lens*lens * P.distort;

    // cloud coords: anchored to the squircle (not the scrolling amp grid
    // inside it), offset by the TILE's seed so each planet differs
    vec2 tlp = p*0.5 + fract(nn * vec2(7.13, 3.71)) * 4.;

    // with a large pad the planet shrinks — zoom the content out to match
    float zf = 1. + P.pad / (1. - P.pad) * PAD_ZOOM;
    p *= zf;

    // extra-large level: sometimes the whole cell is one huge ampersand
    if(fract(nn*57.31) < P.big){
        return drawAmp(p*0.5, nn+0.3, sq, depth, depth, tp, tlp);
    }

    if(nn<0.5){
        float v = iTime*mix(SCROLL_MIN, SCROLL_MAX, nn*2.);
        p.y-=v+nn;
        p*=1.2;
        // the clouds ride the tile's content scroll (same screen velocity)
        // on top of their own drift
        tlp.y -= 0.5 * v / zf;
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

    return drawAmp(gr, n2+nn, sq, ad, depth, tp, tlp);
}

vec3 render(vec2 p, vec2 tp){
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

    return quadTree(gr, n2, depth, tp);
}

float goldBand(vec2 q, vec2 dir, vec2 nrm, float t, float side){
    if(t < 0. || t > 1.) return 0.;
    float front = side * mix(-GOLD_REACH, GOLD_REACH, t);
    float s = side * (dot(q, nrm) - front)
            + GOLD_WOBBLE * sin(dot(q, dir) * 5. + iTime * 1.3);
    float w = s > 0. ? GOLD_FRONT : GOLD_TAIL;
    return exp(-s * s / (w * w));
}

float goldWave(vec2 q, vec2 dir, vec2 nrm){
    float k = floor(iTime / GOLD_PERIOD);
    float start = k * GOLD_PERIOD + random(vec2(k, 3.1)) * (GOLD_PERIOD - GOLD_DUR);
    float side = (random(vec2(k, 5.9)) < 0.5) ? -1. : 1.;
    float g = goldBand(q, dir, nrm, (iTime - start) / GOLD_DUR, side);
    float mside = (fract(u_dev_gold_at * 7.31) < 0.5) ? -1. : 1.;
    return max(g, goldBand(q, dir, nrm, (iTime - u_dev_gold_at) / GOLD_DUR, mside));
}

vec3 field(vec2 p, vec2 q, vec2 tp){
    vec2 dir = vec2(cos(FIELD_ANGLE), sin(FIELD_ANGLE));
    vec2 nrm = vec2(-dir.y, dir.x);
    float u = dot(p, dir) * FIELD_ROWS;
    float v = dot(p, nrm) * FIELD_ROWS;
    v += FIELD_WAVE_AMP * sin(u * FIELD_WAVE_FREQ + iTime * FIELD_WAVE_RATE);
    float lane = floor(v);
    float ph = lane * FIELD_LANE_FREQ + iTime * FIELD_LANE_RATE;
    u -= FIELD_SPEED * (iTime - FIELD_LANE_VAR * cos(ph) / FIELD_LANE_RATE)
       + random(vec2(lane, 7.7)) * 13.;
    vec2 id = mod(vec2(floor(u), lane), 1024.);
    vec2 l = vec2(fract(u), fract(v)) - 0.5;
    vec2 lo = l.x * dir + l.y * nrm;
    float g = goldWave(q - lo / (FIELD_ROWS * gZoom), dir, nrm);
    float gb = goldWave(q, dir, nrm);
    float amp = FIELD_AMP * (1. + GOLD_SWELL * g);
    vec2 gp = lo / amp;

    float n = random(id);
    float frame = mod(iTime * mix(FIELD_CLOCK.x, FIELD_CLOCK.y, n) * 2. * SPEED
                      + n * LOOP_LEN, LOOP_LEN);
    vec2 pJ = gp, pP = gp;
    if(frame >= ROT_START && frame < ROT_START+T_ROTATE){
        float a = cubicInOut((frame-ROT_START)/T_ROTATE)*6.28318530718;
        float sd = (fract(n*7.3) < 0.5) ? -1. : 1.;
        pJ = rotAround(gp, CJ, sd*a);
        pP = rotAround(gp, CP, -sd*a);
    }
    float dj = sdJ(pJ);
    float dp = max(sdP(pP), PAD - dj);
    float k = amp / (FIELD_ROWS * gZoom);

    vec3 col = vec3(mix(NOISE_LO, NOISE_HI, texture(iChannel1, fract(tp)).r));
    col += GOLD_BOT * GOLD_GLOW * gb;
    float da = min(dj, dp);
    col = mix(col, vec3(0.3), S(da * k));
    float fj = fillAnim(frame, FILLJ_START);
    float fp = fillAnim(frame, FILLP_START);
    float wj = max(dj, length(pJ-SEED_J) - (fj*(RJ+0.02)-0.02));
    float wp = max(dp, length(pP-SEED_P) - (fp*(RP+0.02)-0.02));
    col = mix(col, ampGradient(gp), S(min(wj, wp) * k));
    vec3 gold = mix(GOLD_BOT, GOLD_TOP, clamp(gp.y + 0.5, 0., 1.));
    return mix(col, gold, g * S(da * k));
}

vec3 drop(vec2 q, vec2 tp){
    float cs = 1. / DROP_ROWS;
    float tau = iTime - gDropStart;
    float cyc = floor(tau / DROP_CYCLE);
    tau -= cyc * DROP_CYCLE;
    float flushAt = DROP_CYCLE - DROP_FLUSH;
    float fl = max(tau - flushAt, 0.);
    float sink = 0.5 * DROP_G * fl * fl;
    float tspawn = min(tau, flushAt);

    float c = floor(q.x / cs);
    float lx = fract(q.x / cs) - 0.5;
    float h = (q.y + 0.5) / cs;
    float top = DROP_ROWS + 1.;
    vec2 cid = vec2(c, cyc * 17.3);
    float rate = mix(DROP_RATE.x, DROP_RATE.y, random(cid + 0.17));
    float ns = floor(tspawn * rate);
    float j0 = floor(h + sink);

    vec3 col = vec3(mix(NOISE_LO, NOISE_HI, texture(iChannel1, fract(tp)).r));
    float kscr = DROP_AMP * cs;
    for(int i = 0; i < 5; i++){
        float k = (i == 0) ? j0 : ns - float(i - 1);
        if(k < 0. || k >= DROP_ROWS) continue;
        if(i > 0 && k == j0) continue;
        float s = (k + DROP_JITTER * random(cid + k * 1.31)) / rate;
        if(s > tspawn) continue;
        float tf = sqrt(2. * (top - k) / DROP_G);
        float dt = tau - s;
        float tilt = (random(cid + k * 2.7) - 0.5) * 2. * DROP_TILT;
        float y, ang;
        if(dt < tf){
            y = top - 0.5 * DROP_G * dt * dt;
            ang = tilt + DROP_SPIN * (tf - dt) * sign(random(cid + k * 3.3) - 0.5);
        } else {
            float b = dt - tf;
            y = k + DROP_BOUNCE * exp(-b * 8.) * abs(sin(b * 18.));
            ang = tilt;
        }
        y -= sink;
        vec2 gp = vec2(lx, h - y - 0.5) / DROP_AMP;
        if(dot(gp, gp) > 1.) continue;
        gp = gp * Rot(ang);
        float dj = sdJ(gp);
        float dp = max(sdP(gp), PAD - dj);
        vec3 ac = random(cid + k * 5.1) < DROP_FILL ? ampGradient(gp) : vec3(0.3);
        col = mix(col, ac, S(min(dj, dp) * kscr));
    }
    return col;
}

float glyphDist(vec2 p){
    float dj = sdJ(p);
    return min(dj, max(sdP(p), PAD - dj));
}

float solidMap(vec3 p){
    vec2 w = vec2(glyphDist(p.xy) + SOLID_BEVEL, abs(p.z) - SOLID_DEPTH + SOLID_BEVEL);
    return min(max(w.x, w.y), 0.) + length(max(w, 0.)) - SOLID_BEVEL;
}

vec3 solidNormal(vec3 p){
    vec2 e = vec2(SOLID_NEPS, 0.);
    vec2 g = vec2(glyphDist(p.xy + e.xy) - glyphDist(p.xy - e.xy),
                  glyphDist(p.xy + e.yx) - glyphDist(p.xy - e.yx));
    g = normalize(g + 1e-7);
    vec2 w = vec2(glyphDist(p.xy) + SOLID_BEVEL, abs(p.z) - SOLID_DEPTH + SOLID_BEVEL);
    vec2 nw = (w.x > 0. && w.y > 0.) ? normalize(w)
            : (w.x > w.y ? vec2(1., 0.) : vec2(0., 1.));
    return normalize(vec3(g * nw.x, sign(p.z) * nw.y));
}

float solidLight(vec3 n, vec3 L, vec3 F, vec3 up, float amb){
    return amb * mix(SOLID_GROUND, 1., dot(n, up) * 0.5 + 0.5)
         + (1. - amb) * max(dot(n, L), 0.)
         + SOLID_FILL * max(dot(n, F), 0.);
}

vec3 acesApprox(vec3 v){
    v = max(v, 0.) * 0.6;
    return clamp((v * (2.51 * v + 0.03)) / (v * (2.43 * v + 0.59) + 0.14), 0., 1.);
}

float raySphere4Inner(vec3 ro, vec3 rd, float ra){
    float r2 = ra * ra;
    vec3 d2 = rd * rd, d3 = d2 * rd, o2 = ro * ro, o3 = o2 * ro;
    float ka = 1. / dot(d2, d2);
    float k3 = ka * dot(ro, d3);
    float k2 = ka * dot(o2, d2);
    float k1 = ka * dot(o3, rd);
    float k0 = ka * (dot(o2, o2) - r2 * r2);
    float c2 = k2 - k3 * k3;
    float c1 = k1 + 2. * k3 * k3 * k3 - 3. * k3 * k2;
    float c0 = k0 - 3. * k3 * k3 * k3 * k3 + 6. * k3 * k3 * k2 - 4. * k3 * k1;
    float p = c2 * c2 + c0 / 3.;
    float q = c2 * c2 * c2 - c2 * c0 + c1 * c1;
    float h = q * q - p * p * p;
    if(h < 0.) return -1.;
    float sh = sqrt(h);
    float s = sign(q + sh) * pow(abs(q + sh), 1. / 3.);
    float t = sign(q - sh) * pow(abs(q - sh), 1. / 3.);
    vec2 w = vec2(s + t, s - t);
    vec2 v = vec2(w.x + c2 * 4., w.y * sqrt(3.)) * 0.5;
    float r = length(v);
    return abs(v.y) / sqrt(r + v.x) - c1 / r - k3;
}

vec3 superquadricEnv(vec3 ro, vec3 rd){
    vec3 o = vec3(0.);
    float A = 1.;
    vec3 L = normalize(SQ_LIGHT);
    for(int i = 0; i < 3; i++){
        if(A < 0.05) break;
        float z = raySphere4Inner(ro, rd, SQ_ROOM);
        if(z <= 0.) break;
        vec3 p = ro + rd * z;
        vec3 n = -normalize(p * p * p);
        float f = 1. + dot(n, rd);
        f *= f;
        o += A * pow(max(0., dot(n, L)), 9.) * (SQ_OFFSET + sin(-f + SQ_BASE));
        A *= mix(.3, .7, f);
        rd = reflect(rd, n);
        ro = p + 2e-3 * n;
    }
    vec3 c = acesApprox(o * SQ_GAIN);
    return mix(1.055 * pow(c, vec3(1. / 2.4)) - 0.055, 12.92 * c, step(c, vec3(0.0031308)));
}

float solidMarch(vec3 ro, vec3 rd, int steps, out float dmin, out float tmin){
    dmin = 1e9;
    tmin = 0.;
    vec3 bx = vec3(0.7, 0.7, SOLID_DEPTH + 0.01);
    vec3 m = 1. / (rd + vec3(1e-6));
    vec3 n0 = m * ro;
    vec3 k = abs(m) * bx;
    vec3 t1 = -n0 - k, t2 = -n0 + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    if(tN > tF || tF < 0.) return -1.;
    float t = max(tN, 0.);
    tmin = t;
    for(int i = 0; i < steps; i++){
        float d = solidMap(ro + rd * t);
        if(d < dmin){ dmin = d; tmin = t; }
        if(d < max(0.0002, t * SOLID_HIT_PX / (SOLID_FOCAL * iResolution.y))) return t;
        t += d * 0.9;
        if(t > tF) break;
    }
    return -1.;
}

vec3 solidSample(vec2 q, vec2 tp){
    vec3 bg = mix(GRAD_BOT, GRAD_TOP, 0.5) * SOLID_GLOW * (1. - smoothstep(0., SOLID_GLOW_R, length(q)))
            + vec3(mix(NOISE_LO, NOISE_HI, texture(iChannel1, fract(tp)).r));

    float a = iTime * SOLID_SPIN;
    float b = SOLID_TILT * sin(iTime * SOLID_TILT_RATE);
    mat3 ry = mat3(cos(a), 0., -sin(a), 0., 1., 0., sin(a), 0., cos(a));
    mat3 rx = mat3(1., 0., 0., 0., cos(b), sin(b), 0., -sin(b), cos(b));
    mat3 M = ry * rx;
    mat3 Mi = transpose(M);

    vec3 rd = normalize(vec3(q, SOLID_FOCAL));
    vec3 oro = Mi * vec3(0., 0., -SOLID_DIST);
    vec3 ord = Mi * rd;

    float dmin, tmin;
    float t = solidMarch(oro, ord, SOLID_STEPS, dmin, tmin);
    bool hit = t >= 0.;
    if(!hit && dmin > 1e8) return bg;
    float px = tmin / (SOLID_FOCAL * iResolution.y);
    float cov = hit ? 1. : 1. - smoothstep(0., 1.5 * px, dmin);
    if(cov < 0.001) return bg;
    if(!hit) t = tmin;

    vec3 L = Mi * normalize(SOLID_LIGHT);
    vec3 Fo = Mi * normalize(SOLID_FILL_DIR);
    vec3 up = Mi * vec3(0., 1., 0.);
    vec3 matte = vec3(0.);
    {
        vec3 po = oro + ord * t;
        vec3 no = solidNormal(po);
        vec3 base = ampGradient(po.xy) * mix(1., 0.5, 1. - abs(no.z));
        float dif = max(dot(no, L), 0.);
        float spec = pow(max(dot(no, normalize(L - ord)), 0.), MATTE_SHINE);
        matte = base * solidLight(no, L, Fo, up, MATTE_AMBIENT) + vec3(spec) * MATTE_SPEC;
    }
    if(u_solid_matte > 0.999) return mix(bg, matte, cov);

    vec3 col = vec3(0.);
    float A = 1.;
    vec3 ro = oro, dir = ord;
    for(int bnc = 0; bnc <= SOLID_BOUNCES; bnc++){
        vec3 po = ro + dir * t;
        vec3 no = solidNormal(po);
        vec3 base = ampGradient(po.xy) * mix(1., 0.5, 1. - abs(no.z));
        float dif = max(dot(no, L), 0.);
        float spec = pow(max(dot(no, normalize(L - dir)), 0.), SOLID_SHINE);
        col += A * (base * solidLight(no, L, Fo, up, 0.12) * SOLID_KD + vec3(spec) * SOLID_SPEC);
        float f = 1. + dot(no, dir);
        f *= f;
        A *= mix(.3, .7, f) * SOLID_REFL;
        dir = reflect(dir, no);
        ro = po + no * 0.015;
        if(bnc == SOLID_BOUNCES) break;
        float dm, tm;
        t = solidMarch(ro, dir, SOLID_STEPS / 2, dm, tm);
        if(t < 0.) break;
    }
    col += A * superquadricEnv(M * ro, M * dir);
    return mix(bg, mix(col, matte, u_solid_matte), cov);
}

vec3 solid(vec2 q, vec2 tp){
    gFarPad = 0.;
    vec3 c = vec3(0.);
    float px = 1. / iResolution.y;
    for(int i = 0; i < SOLID_SS; i++)
        for(int j = 0; j < SOLID_SS; j++){
            vec2 o = (vec2(i, j) + 0.5) / float(SOLID_SS) - 0.5;
            c += solidSample(q + o * px, tp);
        }
    gFarPad = SDF_RANGE;
    return c / float(SOLID_SS * SOLID_SS);
}

// --- key indicator -----------------------------------------------------------
vec3 keyIndicator(vec3 col, vec2 q){
    // the circle leads the amp by IND_LAG both ways: max of the live and the
    // delayed envelope rises first and falls last, min does the opposite
    float e0 = sk_attention_envelope();
    float e1 = sk_attention_envelope_at(iTime - IND_LAG);
    float cpres = max(e0, e1);
    float pres = min(e0, e1);
    if(cpres < 0.001) return col;

    // black circle growing from the center to past the corners
    float maxR = length(iResolution.xy) / iResolution.y * 0.51;
    col = mix(col, vec3(0.), S(length(q) - maxR * cubicInOut(cpres)));

    // the amp zooms in behind the circle; each key bumps size and brightness
    float pulse = sk_keypulse_envelope();
    float fail = sk_fail_envelope();
    float sc = IND_AMP * cubicInOut(pres) * (1. + pulse * IND_BUMP);
    if(sc < 1e-3) return col;
    vec2 ap = q / sc;
    float dj = sdJ(ap);
    float dp = max(sdP(ap), PAD - dj);
    vec3 ac = mix(ampGradient(ap), vec3(1.), pulse * IND_BRIGHT);
    ac = mix(ac, sk_fail_color, fail);
    return mix(col, ac, S(min(dj, dp) * sc));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    gSeed = 100. * vec2(sk_seed(0), sk_seed(1));
    vec2 p = (fragCoord-0.5*iResolution.xy)/iResolution.y;
    vec2 q = p;
    sequenceModes(q);
    gCoast = COASTF_AMT * P.terra;

    // global zoom-out (offset half a period) plus the wham zoom, centered
    // on a target orbiting off-screen so each zoom lands somewhere new
    float zo = flipflop(iTime + ZOOM_PERIOD*0.5, ZOOM_PERIOD);
    float ang = 6.2831853 * iTime / ZOOM_DRIFT;
    vec2 zc = ZOOM_ECC * vec2(cos(ang), sin(ang));
    gZoom = (1. + ZOOM_OUT*zo) * (1. + P.wham);
    p *= 1. + P.wham;                        // wham zooms about the screen center
    p = zc + (p - zc) * (1. + ZOOM_OUT*zo);  // cyclical zoom about its drifting target

    // sun direction, drifting slowly around the top
    float sa = 6.2831853 * iTime / SUN_PERIOD;
    SUN = normalize(vec3(sin(sa)*SUN_SWING, SUN_HEIGHT, SUN_Z));

    // noise coords, counter-scrolling slowly against the grid
    vec2 tp = vec2(p.x, p.y + iTime*SCROLL*BG_SPEED) * NOISE_SCALE;

    vec3 col = vec3(0.);
    if(P.field + P.drop + P.solid < 0.999) col = render(p, tp);
    if(P.field > 0.001) col = mix(col, field(p, q, tp), P.field);
    if(P.drop > 0.001) col = mix(col, drop(q, tp), P.drop);
    if(P.solid > 0.001) col = mix(col, solid(q, tp), P.solid);
    gCoast = 0.;   // the key indicator keeps clean brand glyphs
    fragColor = vec4(keyIndicator(col, q), 1.0);
}
