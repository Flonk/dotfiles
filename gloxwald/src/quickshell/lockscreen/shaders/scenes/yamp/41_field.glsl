const float FIELD_ROWS      = 24.;
const float FIELD_AMP       = 0.45;
const float FIELD_ANGLE     = 0.6;
const float FIELD_SPEED     = 0.6;
const float FIELD_LANE_VAR  = 0.5;
const float FIELD_LANE_FREQ = 0.37;
const float FIELD_LANE_RATE = 0.11;
const float FIELD_WAVE_AMP  = 0.6;
const float FIELD_WAVE_FREQ = 0.15;
const float FIELD_WAVE_RATE = 0.2;
const vec2  FIELD_CLOCK     = vec2(0.3, 1.);

const float GOLD_PERIOD = 30.;
const float GOLD_DUR    = 3.5;
const float GOLD_REACH  = 1.3;
const float GOLD_FRONT  = 0.02;
const float GOLD_TAIL   = 0.175;
const float GOLD_WOBBLE = 0.;
const float GOLD_SWELL  = 0.2;
const float GOLD_GLOW   = 0.08;
const vec3  GOLD_TOP    = GRAD_TOP;
const vec3  GOLD_BOT    = GRAD_BOT;

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
    vec2 pJ, pP;
    ampSpin(gp, frame, (fract(n*7.3) < 0.5) ? -1. : 1., pJ, pP);
    vec2 d = ampPieces(pJ, pP);
    float k = amp / (FIELD_ROWS * gZoom);

    vec3 col = bgNoise(tp) + GOLD_BOT * GOLD_GLOW * gb;
    float da = min(d.x, d.y);
    col = mix(col, vec3(0.3), S(da * k));
    col = mix(col, ampGradient(gp), S(ampFill(pJ, pP, d, frame) * k));
    vec3 gold = mix(GOLD_BOT, GOLD_TOP, clamp(gp.y + 0.5, 0., 1.));
    return mix(col, gold, g * S(da * k));
}
