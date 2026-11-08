// --- grid: flying through an endless lattice of flat amps ---------------------
// Flat amps face the camera on planes z = (k + 0.5) GRID_S, each plane a grid
// of amps GRID_S apart, so together they fill space. Nothing is marched: for
// each pixel the ray is intersected with the planes ahead, front to back,
// and at each crossing only the amp of that cell is tested (one glyph lookup,
// skipped outside its bounding circle), composited with coverage-based AA
// until opaque. The camera glides down the corridor along x = y = 0 with a
// gentle sway and roll, so the amps stream past on all sides. Each amp runs
// the usual clock (counter-spin, fill wipes) on its own phase and speed, and
// distance fog fades the far planes into a haze that runs from the brand
// gradient up close to pale cyan far off (GRID_DEPTH_K), with a slowly
// pulsing light at the end of the tunnel, round the forward axis. The
// fog factors step by a constant ratio per plane. Amps past GRID_LOD don't
// animate: a plain glyph, lit (blue) with the share of the loop an amp
// spends filled (GRID_LOD_LIT), else black.
const float GRID_S      = 1.6;
const float GRID_AMP    = 0.432;
const float GRID_BOUND  = 0.325;
const int   GRID_LAYERS = 64;
const float GRID_SPEED  = 0.7;
const vec2  GRID_SWAY   = vec2(0.12, 0.1);
const float GRID_ROLL   = 0.18;
const float GRID_FOCAL  = 1.3;
const vec2  GRID_CLOCK  = vec2(0.3, 1.);
const vec3  GRID_OFF    = vec3(0.);
const float GRID_FOG_K  = 0.018;
const float GRID_DEPTH_K = 0.03;
const vec3  GRID_FAR_COL = vec3(0.55, 0.88, 0.95);
const vec3  GRID_GLOW_COL = vec3(1., 1., 0.95);
const vec2  GRID_GLOW   = vec2(0.9, 0.35);
const vec2  GRID_GLOW_P = vec2(400., 30.);
const float GRID_PULSE  = 0.15;
const float GRID_LOD    = 24.;
const float GRID_LOD_LIT = 0.28;

vec3 grid(vec2 q, vec2 tp){
    float ct = iTime * GRID_SPEED;
    vec3 ro = vec3(GRID_SWAY.x * sin(ct * 0.37), GRID_SWAY.y * sin(ct * 0.29 + 1.), ct);
    vec3 fw = normalize(vec3(0.12 * sin(ct * 0.23), 0.08 * sin(ct * 0.19 + 2.), 1.));
    float rl = GRID_ROLL * sin(ct * 0.11);
    vec3 rt = normalize(cross(vec3(sin(rl), cos(rl), 0.), fw));
    vec3 up = cross(fw, rt);
    vec3 rd = normalize(q.x * rt + q.y * up + GRID_FOCAL * fw);

    vec3 near = mix(GRAD_BOT, GRAD_TOP, clamp(q.y + 0.5, 0., 1.));
    float ax = max(rd.z, 0.);
    float pulse = 1. + GRID_PULSE * sin(iTime * 0.6);
    vec3 far = GRID_FAR_COL + GRID_GLOW_COL * pulse * (GRID_GLOW.x * pow(ax, GRID_GLOW_P.x) + GRID_GLOW.y * pow(ax, GRID_GLOW_P.y));
    vec3 col = vec3(0.);
    float a = 0.;
    float k0 = floor(ro.z / GRID_S - 0.5) + 1.;
    float dtz = GRID_S / rd.z;
    float t = ((k0 + 0.5) * GRID_S - ro.z) / rd.z;
    vec2 pc = (ro.xy + rd.xy * t) / GRID_S;
    vec2 dpc = rd.xy * dtz / GRID_S;
    const float bound = (GRID_BOUND / GRID_S) * (GRID_BOUND / GRID_S);
    float pxk = 1. / (GRID_FOCAL * iResolution.y);
    float vis = exp(-t * GRID_FOG_K), visStep = exp(-dtz * GRID_FOG_K);
    float tint = exp(-t * GRID_DEPTH_K), tintStep = exp(-dtz * GRID_DEPTH_K);
    for(int i = 0; i < GRID_LAYERS; i++){
        vec2 l = fract(pc) - 0.5;
        if(dot(l, l) < bound){
            vec2 c = floor(pc);
            float n = random(c + (k0 + float(i)) * 7.31);
            vec2 gp = l * (GRID_S / GRID_AMP);
            float px = t * pxk;
            float cov, fill;
            if(t < GRID_LOD){
                float frame = mod(iTime * mix(GRID_CLOCK.x, GRID_CLOCK.y, n) * 2. * SPEED + n * LOOP_LEN, LOOP_LEN);
                vec2 pJ, pP;
                ampSpin(gp, frame, fract(n * 7.3) < 0.5 ? -1. : 1., pJ, pP);
                vec2 d = ampPieces(pJ, pP);
                cov = smoothstep(px, -px, min(d.x, d.y) * GRID_AMP);
                fill = cov > 0.001 ? smoothstep(px, -px, ampFill(pJ, pP, d, frame) * GRID_AMP) : 0.;
            } else {
                cov = smoothstep(px, -px, glyphDist(gp) * GRID_AMP);
                fill = fract(n * 13.7) < GRID_LOD_LIT ? 1. : 0.;
            }
            if(cov > 0.001){
                vec3 c3 = mix(GRID_OFF, ampGradient(gp), fill);
                c3 = mix(mix(near, far, 1. - tint), c3, vis);
                col += (1. - a) * cov * c3;
                a += (1. - a) * cov;
                if(a > 0.995) break;
            }
        }
        t += dtz;
        pc += dpc;
        vis *= visStep;
        tint *= tintStep;
    }
    return col + (1. - a) * far + bgNoise(tp) * 0.3;
}
