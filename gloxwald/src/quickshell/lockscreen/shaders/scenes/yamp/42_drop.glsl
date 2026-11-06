const float DROP_ROWS   = 12.;
const float DROP_AMP    = 0.45;
const float DROP_G      = 60.;
const vec2  DROP_RATE   = vec2(0.1, 0.35);
const float DROP_JITTER = 0.6;
const float DROP_CYCLE  = 40.;
const float DROP_FLUSH  = 1.5;
const float DROP_TILT   = 0.25;
const float DROP_SPIN   = 4.;
const float DROP_BOUNCE = 0.15;
const float DROP_FILL   = 0.35;

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

    vec3 col = bgNoise(tp);
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
        vec3 ac = random(cid + k * 5.1) < DROP_FILL ? ampGradient(gp) : vec3(0.3);
        col = mix(col, ac, S(glyphDist(gp) * kscr));
    }
    return col;
}
