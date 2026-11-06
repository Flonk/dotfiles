const float SOLID_DIST   = 3.2;
const float SOLID_FOCAL  = 2.;
const float SOLID_DEPTH  = 0.12;
const float SOLID_BEVEL  = 0.025;
const float SOLID_NEPS   = 0.02;
const vec3  SOLID_FILL_DIR = vec3(0.6, -0.6, -0.5);
const float SOLID_FILL   = 0.35;
const float SOLID_GROUND = 0.6;
const float SOLID_SPIN   = 0.15;
const float SOLID_TILT   = 0.3;
const float SOLID_TILT_RATE = 0.085;
const int   SOLID_STEPS  = 96;
const float SOLID_HIT_PX = 0.5;
const int   SOLID_SS     = 2;
const vec3  SOLID_LIGHT  = vec3(-0.6, 0.7, -0.8);
const float SOLID_SHINE  = 64.;
const float SOLID_SPEC   = 0.8;
const float SOLID_REFL   = 1.;
const float SOLID_KD     = 0.35;
const int   SOLID_BOUNCES = 2;
const float SOLID_GLOW   = 0.2;
const float SOLID_GLOW_R = 0.8;
const float MATTE_AMBIENT = 0.25;
const float MATTE_SHINE   = 8.;
const float MATTE_SPEC    = 0.08;

const float SQ_ROOM   = 5.;
const vec3  SQ_LIGHT  = vec3(1., -2., -1.);
const float SQ_OFFSET = 1.1;
const vec3  SQ_BASE   = vec3(3.9, 0.6, 0.9);
const float SQ_GAIN   = 11.;

const float HALF_ROWS   = 64.;
const float HALF_ANGLE  = 0.785398;
const float HALF_MAX    = 0.85;
const float HALF_BG     = 0.;
const float HALF_AMBIENT = 0.08;
const float HALF_ORBIT  = 0.25;
const float HALF_LIGHT_Z = 0.6;
const float HALF_SHINE  = 24.;
const float HALF_GLINT  = 0.6;
const float HALF_CONTRAST = 1.6;
const vec3  HALF_GREY   = vec3(0.3);
const float HALF_TINT_LO = 0.2;
const float HALF_TINT_HI = 0.8;

float solidMap(vec3 p){
    return sdExtrude(glyphDist(p.xy), p.z, SOLID_DEPTH, SOLID_BEVEL);
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

mat3 solidSpin(){
    return rotY(iTime * SOLID_SPIN) * rotX(SOLID_TILT * sin(iTime * SOLID_TILT_RATE));
}

float solidMarch(vec3 ro, vec3 rd, int steps, out float dmin, out float tmin){
    dmin = 1e9;
    tmin = 0.;
    vec3 bx = vec3(0.7, 0.7, SOLID_DEPTH + 0.01);
    vec2 h = boxHit(ro, rd, -bx, bx);
    if(h.x > h.y || h.y < 0.) return -1.;
    float t = max(h.x, 0.);
    tmin = t;
    for(int i = 0; i < steps; i++){
        float d = solidMap(ro + rd * t);
        if(d < dmin){ dmin = d; tmin = t; }
        if(d < max(0.0002, t * SOLID_HIT_PX / (SOLID_FOCAL * iResolution.y))) return t;
        t += d * 0.9;
        if(t > h.y) break;
    }
    return -1.;
}

float solidShadow(vec3 ro, vec3 rd, float tmax, float k, int steps){
    vec3 bx = vec3(0.85, 0.85, SOLID_DEPTH + 0.15);
    vec2 h = boxHit(ro, rd, -bx, bx);
    if(h.x > h.y || h.y < 0. || h.x > tmax) return 1.;
    float res = 1.;
    float t = max(h.x, 0.);
    for(int i = 0; i < steps; i++){
        float d = solidMap(ro + rd * t);
        if(d < 0.0005) return 0.;
        if(d < 0.1) res = min(res, k * d / t);
        t += clamp(d, 0.002, 0.1);
        if(t > h.y) break;
    }
    res = clamp(res, 0., 1.);
    return res * res * (3. - 2. * res);
}

float solidLight(vec3 n, vec3 L, vec3 F, vec3 up, float amb){
    return amb * mix(SOLID_GROUND, 1., dot(n, up) * 0.5 + 0.5)
         + (1. - amb) * max(dot(n, L), 0.)
         + SOLID_FILL * max(dot(n, F), 0.);
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
    return srgbEncode(acesApprox(o * SQ_GAIN));
}

vec3 solidShade(vec3 po, vec3 no, vec3 dir, vec3 L, vec3 Fo, vec3 up, float amb, float kd, float shine, float spec){
    vec3 base = ampGradient(po.xy) * mix(1., 0.5, 1. - abs(no.z));
    float s = pow(max(dot(no, normalize(L - dir)), 0.), shine);
    return base * solidLight(no, L, Fo, up, amb) * kd + vec3(s) * spec;
}

vec3 solidSample(vec2 q, vec3 bg, mat3 M){
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
    vec3 p0 = oro + ord * t;
    vec3 matte = solidShade(p0, solidNormal(p0), ord, L, Fo, up, MATTE_AMBIENT, 1., MATTE_SHINE, MATTE_SPEC);
    if(u_solid_matte > 0.999) return mix(bg, matte, cov);

    vec3 col = vec3(0.);
    float A = 1.;
    vec3 ro = oro, dir = ord;
    for(int bnc = 0; bnc <= SOLID_BOUNCES; bnc++){
        vec3 po = ro + dir * t;
        vec3 no = solidNormal(po);
        col += A * solidShade(po, no, dir, L, Fo, up, 0.12, SOLID_KD, SOLID_SHINE, SOLID_SPEC);
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

vec3 solidBg(vec2 q, vec2 tp){
    return mix(GRAD_BOT, GRAD_TOP, 0.5) * SOLID_GLOW * (1. - smoothstep(0., SOLID_GLOW_R, length(q)))
         + bgNoise(tp);
}

vec3 solid(vec2 q, vec2 tp){
    vec3 bg = solidBg(q, tp);
    mat3 M = solidSpin();
    gFarPad = 0.;
    {
        mat3 Mi = transpose(M);
        float dmin, tmin;
        float t = solidMarch(Mi * vec3(0., 0., -SOLID_DIST), Mi * normalize(vec3(q, SOLID_FOCAL)), SOLID_STEPS, dmin, tmin);
        if(t < 0. && dmin * SOLID_FOCAL * iResolution.y > 3. * max(tmin, 1.)){
            gFarPad = SDF_RANGE;
            return bg;
        }
    }
    vec3 c = vec3(0.);
    for(int i = 0; i < SOLID_SS * SOLID_SS; i++)
        c += solidSample(q + ssOffset(i, SOLID_SS) / iResolution.y, bg, M);
    gFarPad = SDF_RANGE;
    return c / float(SOLID_SS * SOLID_SS);
}

vec3 halftone(vec2 q, vec2 tp){
    float ca = cos(HALF_ANGLE), sa = sin(HALF_ANGLE);
    mat2 R = mat2(ca, sa, -sa, ca);
    vec2 u = R * q * HALF_ROWS;
    vec2 cid = floor(u);
    vec2 l = transpose(R) * (fract(u) - 0.5);
    vec2 qc = transpose(R) * ((cid + 0.5) / HALF_ROWS);

    mat3 M = solidSpin();
    mat3 Mi = transpose(M);
    vec3 rd = normalize(vec3(qc, SOLID_FOCAL));
    vec3 oro = Mi * vec3(0., 0., -SOLID_DIST);
    vec3 ord = Mi * rd;

    gFarPad = 0.;
    float dmin, tmin;
    float t = solidMarch(oro, ord, SOLID_STEPS, dmin, tmin);
    float lum = HALF_BG, glint = 0., gy = 0.;
    if(t >= 0.){
        vec3 po = oro + ord * t;
        vec3 nw = M * solidNormal(po);
        float la = iTime * HALF_ORBIT;
        vec3 L = normalize(vec3(cos(la), sin(la), -HALF_LIGHT_Z));
        lum = HALF_AMBIENT + (1. - HALF_AMBIENT) * max(dot(nw, L), 0.);
        lum = clamp((lum - 0.5) * HALF_CONTRAST + 0.5, 0., 1.);
        glint = pow(max(dot(reflect(-L, nw), -rd), 0.), HALF_SHINE) * HALF_GLINT;
        gy = po.y;
    }
    gFarPad = SDF_RANGE;

    vec3 col = bgNoise(tp);
    float s = HALF_MAX * sqrt(clamp(lum, 0., 1.));
    if(s < 0.01) return col;
    vec2 gp = l / s;
    vec3 tint = mix(HALF_GREY, ampGradient(vec2(0., gy)), smoothstep(HALF_TINT_LO, HALF_TINT_HI, lum));
    vec3 ink = mix(tint, vec3(1.), glint);
    return mix(col, ink, S(glyphDist(gp) * s / HALF_ROWS));
}
