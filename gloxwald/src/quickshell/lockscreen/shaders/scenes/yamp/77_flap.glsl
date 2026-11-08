// --- flap: a split-flap board (transition) -----------------------------------
// FLAP_ROWS rows of tiles, each split at a hinge. On its own clock the board
// flips over the old scene to the amp (TRANS_AMP tall) from FLAP_IN_AT, the
// tagline flaps in along the bottom, and from FLAP_OUT_AT it flips on to
// the new scene; a tile showing a scene and not flipping is just the scene.
// A change of picture: a sweep from a random direction sets each tile off, which
// clatters through a few random cards (FLAP_T per flip) before landing on its
// piece of the new picture. A flip drops the top half of the old card over
// the hinge: on the way down it shows the old card's top, past vertical the
// new card's bottom (its back), foreshortened and widened towards the free
// edge. Pictures are sampled in screen space, so big ones run across tiles.
// Some tiles carry characters (black card, white
// Montserrat from the flap_font.png atlas in iChannel13, gen_flapfont.py):
// the small-amp picture shows the clock top right, whose digits roll forward when
// iClock changes (u_clock_prev, u_clock_at), and FLAP_TEXT_AT into the blue
// amp picture FLAP_TEXT flaps in below it on two lines, letter by letter,
// and into the inverted one FLAP_URL along the top right. Text slots are
// j < 32 for FLAP_TEXT, 32 + i for FLAP_URL.
// A card is ivec2(kind, value): 0 picture, 1 scramble, 2 character (-1
// blank) on black, 3 character + 1 + 128 * picture over that picture.
const float FLAP_ROWS   = 12.;
const float FLAP_ASPECT = 0.72;
const float FLAP_IN_AT  = 0.;
const float FLAP_OUT_AT = 7.6;
const float FLAP_PREV_END = 3.;
const float FLAP_SWEEP  = 1.6;
const float FLAP_JITTER = 0.25;
const float FLAP_T      = 0.085;
const vec2  FLAP_FLIPS  = vec2(3., 10.);
const float FLAP_FACE   = 0.45;
const float FLAP_RAD    = 0.06;
const float FLAP_GAP    = 0.012;
const float FLAP_WIDEN  = 0.12;
const float FLAP_BIG    = 0.82;
const float FLAP_SMALL  = 0.62;
const int   FLAP_PICS   = 4;
const int   FLAP_CLOCK_PIC = 2;
const int   FLAP_TEXT_PIC  = 0;
const float FLAP_HERO   = 0.5 * TRANS_AMP;
const int   FLAP_PREV   = 5;
const int   FLAP_NEXT   = 6;
const float FLAP_TEXT_AT   = 2.6;
const float FLAP_TEXT_STAGGER = 0.07;
const vec2  FLAP_TEXT_FLIPS   = vec2(4., 9.);
const float FLAP_CLOCK_STAGGER = 0.06;
const float FLAP_TEXT_SHADOW = 0.55;
const int   FLAP_TEXT_LEN = 19;
const int   FLAP_LINE     = 9;
const int   FLAP_TEXT_ROW = -3;
const int   FLAP_TEXT[FLAP_TEXT_LEN] = int[FLAP_TEXT_LEN](19, 56, 63, 55, -1, 56, 45, 49, 41, -1, 56, 51, -1, 38, 57, 45, 48, 40, 64);
const int   FLAP_URL_PIC = 1;
const int   FLAP_URL_LEN = 9;
const int   FLAP_URL[FLAP_URL_LEN] = int[FLAP_URL_LEN](37, 50, 40, 37, 49, 52, 64, 45, 51);
const vec2  FLAP_FONT_GRID = vec2(8., 9.);
const float FLAP_FONT_ASPECT = 0.75;
const float FLAP_FONT_RANGE  = 0.25;
const vec3  FLAP_CARD   = vec3(0.075);
const vec3  FLAP_HOUSING = vec3(0.012);
const vec3  FLAP_INK    = vec3(0.86);
const vec3  FLAP_BLACK  = vec3(0.025);
const vec3  FLAP_WHITE  = vec3(0.92);

float flapAmp(vec2 g, float sc){ return glyphDist(g / sc) * sc; }

float flapGlyph(int ch, vec2 l){
    if(ch < 0) return 1.;
    vec2 uv = vec2(l.x / FLAP_FONT_ASPECT + 0.5, 0.5 - l.y);
    if(any(lessThan(uv, vec2(0.))) || any(greaterThan(uv, vec2(1.)))) return 1.;
    vec2 cell = vec2(ch % 8, ch / 8);
    return (texture(iChannel13, (cell + uv) / FLAP_FONT_GRID).r - 0.5) * FLAP_FONT_RANGE;
}

// board states come in threes: the old scene, the amp with the tagline, the
// new scene; the board flips old -> amp at FLAP_IN_AT and amp -> new at
// FLAP_OUT_AT
int flapState(float n){ return int(mod(n, 3.) + .5); }

int flapPic(float n){ int s = flapState(n); return s == 0 ? FLAP_PREV : s == 1 ? 0 : FLAP_NEXT; }

float flapStart(float n){ return flapState(n) == 1 ? FLAP_IN_AT : FLAP_OUT_AT; }

int flapSlot(vec2 id, int pic, out int j){
    float asp = iResolution.x / iResolution.y;
    int xr = int(floor(0.5 * asp / (FLAP_ASPECT / FLAP_ROWS))) - 1;
    int x = int(id.x), y = int(id.y), top = int(FLAP_ROWS * 0.5) - 2;
    j = 0;
    if(pic == FLAP_CLOCK_PIC && y == top && x >= xr - 5 && x < xr){ j = x - (xr - 5); return 1; }
    int x0 = -(FLAP_LINE - 1) / 2, ln = FLAP_TEXT_ROW - y;
    if(pic == FLAP_TEXT_PIC && (ln == 0 || ln == 1) && x >= x0 && x < x0 + FLAP_LINE){ j = x - x0 + ln * (FLAP_LINE + 1); return 2; }
    if(pic == FLAP_URL_PIC && y == top && x >= xr - FLAP_URL_LEN && x < xr){ j = 32 + x - (xr - FLAP_URL_LEN); return 2; }
    return 0;
}

int flapDigit(vec4 c, int j){
    return int((j == 0 ? c.x : j == 1 ? c.y : j == 3 ? c.z : c.w) + 0.5);
}

int flapClockChar(int j){ return j == 2 ? 10 : flapDigit(iClock, j); }

float flapTextAt(float n, int j){
    return flapStart(n) + FLAP_TEXT_AT + float(j % 32) * FLAP_TEXT_STAGGER;
}

ivec2 flapTextCard(int j, int ch){ return ivec2(3, ch + 1 + 128 * (j < 32 ? FLAP_TEXT_PIC : FLAP_URL_PIC)); }

int flapTextChar(int j){ return j < 32 ? FLAP_TEXT[j] : FLAP_URL[j - 32]; }

ivec2 flapFace(float n, vec2 id, float t){
    int pic = flapPic(n), j;
    int sl = flapSlot(id, pic, j);
    if(sl == 1) return ivec2(2, flapClockChar(j));
    if(sl == 2 && t >= flapTextAt(n, j)) return flapTextCard(j, flapTextChar(j));
    return ivec2(0, pic);
}

vec3 flapPicture(int pic, vec2 g, vec2 l, vec2 id, float th){
    if(pic == FLAP_PREV) return gPrevCol;
    if(pic == FLAP_NEXT) return gNextCol;
    if(pic == 0){
        float d = flapAmp(g, FLAP_HERO);
        return mix(FLAP_CARD, ampGradient(g / FLAP_HERO), S(d));
    }
    if(pic == 1){
        float d = flapAmp(g, FLAP_BIG);
        return mix(ampGradient(g / FLAP_BIG) * 0.9, FLAP_CARD, S(d));
    }
    if(pic == 2){
        float d = flapAmp(l * th, FLAP_SMALL * th);
        bool lit = random(id + 0.37) < 0.18;
        return mix(FLAP_CARD, lit ? ampGradient(l / FLAP_SMALL) : vec3(0.32), S(d));
    }
    vec2 cell = vec2(FLAP_ASPECT, 1.) * th;
    vec2 b = floor(id / 2.);
    vec2 bc = (b * 2. + 1.) * cell;
    float sc = FLAP_SMALL * 2. * th;
    float d = flapAmp(g - bc, sc);
    vec3 ink = random(b + 0.71) < 0.25 ? ampGradient((g - bc) / sc) : vec3(0.32);
    return mix(FLAP_CARD, ink, S(d));
}

vec3 flapScramble(vec2 id, float n, int k, vec2 l, float th){
    vec2 r = vec2(random(id + vec2(n * 1.3, float(k) * 7.1)), random(id + vec2(float(k) * 3.7, n * 0.9)));
    vec3 c = r.x < 0.55 ? FLAP_CARD : r.x < 0.8 ? vec3(0.3) : r.x < 0.93 ? ampGradient(l) : FLAP_INK * 0.9;
    if(r.y < 0.5){
        vec3 ink = c == FLAP_CARD ? vec3(0.5) : FLAP_CARD;
        c = mix(c, ink, S(flapAmp(l * th, FLAP_SMALL * th)));
    }
    return c;
}

vec3 flapRender(ivec2 c, float n, vec2 id, vec2 g, vec2 l, float th){
    if(c.x == 0) return flapPicture(c.y, g, l, id, th);
    if(c.x == 1) return flapScramble(id, n, c.y, l, th);
    if(c.x == 3){
        int ch = c.y % 128 - 1;
        vec3 bg = flapPicture(c.y / 128, g, l, id, th);
        bg *= 1. - FLAP_TEXT_SHADOW * smoothstep(0.05, -0.02, flapGlyph(ch, l + vec2(-0.02, 0.03)));
        return mix(bg, FLAP_WHITE, S(flapGlyph(ch, l) * th));
    }
    return mix(FLAP_BLACK, FLAP_WHITE, S(flapGlyph(c.y, l) * th));
}

// card k of a flip run: ev 0 board change, 1 text, 2 clock digit
ivec2 flapCard(int ev, int k, int m, float n, vec2 id, float st, int j, int prv, int base){
    if(ev == 0){
        if(k <= 0) return flapFace(n - 1., id, 1e4);
        if(k >= m) return flapFace(n, id, st);
        return ivec2(1, k);
    }
    if(ev == 1){
        if(k <= 0) return ivec2(0, j < 32 ? FLAP_TEXT_PIC : FLAP_URL_PIC);
        if(k >= m) return flapTextCard(j, flapTextChar(j));
        return flapTextCard(j, 37 + int(random(id + vec2(float(k) * 2.3, n)) * 26.));
    }
    return ivec2(2, (prv + k) % base);
}

vec3 flap(vec2 q, vec2 tp){
    float th = 1. / FLAP_ROWS;
    vec2 cell = vec2(FLAP_ASPECT * th, th);
    vec2 id = floor(q / cell);
    vec2 cc = (id + 0.5) * cell;
    vec2 l = (q - cc) / th;

    float lt = gModeT[MODE_FLAP];
    float n = 3. * gModeK[MODE_FLAP] + (lt < FLAP_OUT_AT ? 1. : 2.);
    float ang = 6.2831853 * random(vec2(n, 4.4));
    vec2 dir = vec2(cos(ang), sin(ang));
    float span = 0.5 * (abs(dir.x) * iResolution.x / iResolution.y + abs(dir.y));
    float delay = (dot(cc, dir) / span * 0.5 + 0.5) * FLAP_SWEEP + random(id + vec2(n, 2.2)) * FLAP_JITTER;

    int ev = 0, j, prv = 0, base = 10;
    float st = flapStart(n) + delay;
    int m = int(mix(FLAP_FLIPS.x, FLAP_FLIPS.y + 1., random(id + vec2(5.5, n))));
    int sl = flapSlot(id, flapPic(n), j);
    if(sl == 2){
        float e0 = flapTextAt(n, j);
        if(lt >= e0){
            ev = 1; st = e0;
            m = int(mix(FLAP_TEXT_FLIPS.x, FLAP_TEXT_FLIPS.y + 1., random(id + vec2(n, 8.1))));
        }
    }
    if(sl == 1 && j != 2){
        base = j == 0 ? 3 : j == 3 ? 6 : 10;
        prv = flapDigit(u_clock_prev, j);
        int cm = (flapDigit(iClock, j) - prv + base) % base;
        float c0 = u_clock_at + float(j) * FLAP_CLOCK_STAGGER;
        if(cm > 0 && c0 > st && lt >= c0){ ev = 2; st = c0; m = cm; }
    }

    float s = (lt - st) / FLAP_T;
    int k = int(floor(clamp(s, 0., float(m))));
    float p = s >= 0. && k < m ? fract(s) : 0.;

    ivec2 c0 = flapCard(ev, k, m, n, id, st, j, prv, base);
    if(p <= 0. && c0.x == 0 && (c0.y == FLAP_PREV || c0.y == FLAP_NEXT)) return c0.y == FLAP_PREV ? gPrevCol : gNextCol;
    vec2 face = vec2(FLAP_FACE * FLAP_ASPECT, FLAP_FACE);
    vec2 bq = abs(l) - face + FLAP_RAD;
    float box = (length(max(bq, 0.)) + min(max(bq.x, bq.y), 0.) - FLAP_RAD) * th;
    vec3 col = FLAP_HOUSING;

    ivec2 cA = flapCard(ev, k, m, n, id, st, j, prv, base);
    ivec2 cB = p > 0. ? flapCard(ev, k + 1, m, n, id, st, j, prv, base) : cA;
    vec3 under;
    float shade = 1.;
    if(p <= 0.){
        under = flapRender(cA, n, id, q, l, th);
    } else {
        under = flapRender(l.y > 0. ? cB : cA, n, id, q, l, th);
        if(l.y < 0.) shade = 1. - 0.35 * sin(3.1415927 * min(p * 2., 1.)) * (1. - smoothstep(0., 0.25, -l.y));
    }
    under *= (l.y > 0. ? 1.06 : 0.94) * shade;
    col = mix(col, under, S(box));

    if(p > 0.){
        float a = 3.1415927 * pow(p, 1.5);
        float ca = cos(a);
        float h = FLAP_FACE * abs(ca);
        bool top = ca > 0.;
        bool hit = top ? (l.y > 0. && l.y < h) : (l.y < 0. && l.y > -h);
        if(hit && abs(ca) > 0.02){
            float ys = l.y / abs(ca);
            float w = 1. + FLAP_WIDEN * sin(a) * abs(ys) / FLAP_FACE;
            vec2 ls = vec2(l.x / w, ys);
            vec2 gs = cc + ls * th;
            vec2 fq = abs(ls) - face + FLAP_RAD;
            float fbox = (length(max(fq, 0.)) + min(max(fq.x, fq.y), 0.) - FLAP_RAD) * th * min(abs(ca) * 4., 1.);
            vec3 fc = flapRender(top ? cA : cB, n, id, gs, ls, th);
            fc *= top ? mix(1.06, 0.55, sin(a)) : mix(0.94, 0.6, sin(a));
            col = mix(col, fc, S(fbox));
        }
    }
    col = mix(col, FLAP_HOUSING, S(abs(l.y * th) - FLAP_GAP * 0.5 * th) * S(box));
    return col;
}
