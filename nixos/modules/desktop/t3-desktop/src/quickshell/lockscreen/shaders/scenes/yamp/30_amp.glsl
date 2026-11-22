const float PAD = 0.0464;
const float SDF_BOX   = 0.75;
const float SDF_RANGE = 0.25;
float gFarPad = SDF_RANGE;

vec2 glyphUV(vec2 p){ return vec2(p.x, -p.y) / (2.0 * SDF_BOX) + 0.5; }

float sdJ(vec2 p) {
    float far = length(p) - 0.57;
    if (far > (gFarPad > 0. ? 0.05 : SDF_RANGE * 0.5)) return far + gFarPad;
    return max((texture(iChannel0, glyphUV(p)).r - 0.5) * SDF_RANGE, far);
}
float sdP(vec2 p) {
    float far = length(p) - 0.66;
    if (far > (gFarPad > 0. ? 0.09 : SDF_RANGE * 0.5)) return far + gFarPad;
    return max((texture(iChannel0, glyphUV(p)).g - 0.5) * SDF_RANGE, far);
}

vec2 ampPieces(vec2 pJ, vec2 pP){
    float dj = sdJ(pJ);
    return vec2(dj, max(sdP(pP), PAD - dj));
}

float glyphDist(vec2 p){
    vec2 d = ampPieces(p, p);
    return min(d.x, d.y);
}

vec3 ampGradient(vec2 p){
    return mix(GRAD_BOT, GRAD_TOP, clamp(p.y + 0.5, 0., 1.));
}

const vec2  CJ = vec2(-0.0644,-0.2581);
const vec2  CP = vec2( 0.0148, 0.0562);
const vec2  SEED_J = vec2(-0.2871, 0.0267);
const vec2  SEED_P = vec2(-0.0192, 0.4142);
const float RJ = 0.76;
const float RP = 1.04;

float fillAnim(float frame, float start){
    if(frame < start) return 0.;
    if(frame < start+T_FILL) return cubicInOut((frame-start)/T_FILL);
    if(frame < UNFILL_START) return 1.;
    if(frame < UNFILL_START+T_UNFILL) return 1.-cubicInOut((frame-UNFILL_START)/T_UNFILL);
    return 0.;
}

void ampSpin(vec2 p, float frame, float dir, out vec2 pJ, out vec2 pP){
    pJ = p;
    pP = p;
    if(frame >= ROT_START && frame < ROT_START+T_ROTATE){
        float a = cubicInOut((frame-ROT_START)/T_ROTATE)*6.28318530718;
        pJ = rotAround(p, CJ, dir*a);
        pP = rotAround(p, CP, -dir*a);
    }
}

float ampFill(vec2 pJ, vec2 pP, vec2 d, float frame){
    float fj = fillAnim(frame, FILLJ_START);
    float fp = fillAnim(frame, FILLP_START);
    float wj = max(d.x, length(pJ-SEED_J) - (fj*(RJ+0.02)-0.02));
    float wp = max(d.y, length(pP-SEED_P) - (fp*(RP+0.02)-0.02));
    return min(wj, wp);
}
