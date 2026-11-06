void placeCable(){
    float lx = SHADOW_OUTLET_SIZE.x * 0.25 * SHADOW_OUTLET_SCALE + SHADOW_CABLE_DROP.x;
    gPath[0] = vec2(gOutletPos.x + lx, SHADOW_WALL_Z - SHADOW_CABLE_DROP.y);
    gPath[4] = gPhoneC.xz - gPhoneU * SHADOW_PHONE_SIZE.y * 0.5;
    gPath[3] = gPath[4] - gPhoneU * SHADOW_CABLE_LEAD;
    gPath[1] = floorAt(SHADOW_CABLE_OUT1);
    gPath[2] = floorAt(SHADOW_CABLE_OUT2);
    vec2 dw = normalize(gPath[1] - gPath[0]);
    gCableDir = vec2(dw.x, -dw.y);
}

void setupCamera(){
    vec3 ro = SHADOW_CAM;
    gF = normalize(SHADOW_TARGET - ro);
    gR = normalize(cross(vec3(0., 1., 0.), gF));
    gU = cross(gF, gR);
    gYaw = rotY(SHADOW_YAW);
    vec3 pivot = vec3(0., 0., SHADOW_WALL_Z);
    gRo = pivot + gYaw * (ro - pivot);

    gCfwd = normalize(gYaw * vec3(gF.x, 0., gF.z));
    gCright = vec3(gCfwd.z, 0., -gCfwd.x);
    gCo = vec3(gRo.x, 0., gRo.z) + gCfwd * SHADOW_COUCH_FWD - gCright * SHADOW_COUCH_LEFT;
    mat3 rig = rotY(SHADOW_RIG_YAW);
    vec3 rp = vec3(gRo.x, 0., gRo.z);
    gLight = rp + rig * (SHADOW_LIGHT - rp);
    gAmpPos = rp + rig * (SHADOW_AMP_POS - rp);
    gAmpMi = transpose(rotY(SHADOW_FACE + SHADOW_RIG_YAW + SHADOW_SWAY * sin(iTime * SHADOW_SWAY_RATE)));

}

void setupRoom(){
    setupCamera();
    placeOutlet();
    placePhone();
    placeCable();
}

struct Hit {
    float t;
    int id;
    vec3 n;
    vec3 lp;
    vec3 ln;
};

Hit sceneTrace(vec3 ro, vec3 rd){
    Hit h = Hit(1e9, ID_NONE, vec3(0., 1., 0.), vec3(0.), vec3(0., 1., 0.));
    if(rd.y < 0.){ h.t = -ro.y / rd.y; h.id = ID_FLOOR; }
    if(rd.z > 0.){
        float tt = (SHADOW_WALL_Z - ro.z) / rd.z;
        if(tt < h.t){ h.t = tt; h.id = ID_WALL; h.n = vec3(0., 0., -1.); }
    }
    if(rd.x < 0.){
        float tt = (SHADOW_SIDE_X - ro.x) / rd.x;
        if(tt < h.t){ h.t = tt; h.id = ID_SIDE; h.n = vec3(1., 0., 0.); }
    }
    {
        float ys = SHADOW_SKIRT_H * 1.05;
        float ts = ro.y <= ys ? 0. : (rd.y < 0. ? (ys - ro.y) / rd.y : 1e9);
        if(ts < h.t){
            for(int i = 0; i < 64; i++){
                float ds = skirtUnion(ro + rd * ts);
                if(ds < 0.0002){
                    h.t = ts;
                    h.id = ID_SKIRT;
                    h.n = SDF_NORMAL(skirtUnion, ro + rd * ts, 0.0005);
                    break;
                }
                ts += ds * 0.9;
                if(ts > h.t) break;
            }
        }
    }
    {
        float to = outletMarch(ro, rd, h.t);
        if(to > 0. && to < h.t){
            h.t = to;
            vec3 lp = outletLocal(ro + rd * to);
            float m;
            outletSdf(lp, m);
            h.id = ID_FRAME + int(m + 0.5);
            h.lp = lp;
            vec3 g = SDF_NORMAL(outletDist, lp, 0.0005);
            h.n = vec3(g.x, g.y, -g.z);
        }
    }
    {
        float tp = phoneMarch(ro, rd, h.t);
        if(tp > 0. && tp < h.t){
            h.t = tp;
            vec3 lp = phoneLocal(ro + rd * tp);
            h.lp = lp;
            vec3 g = SDF_NORMAL(phoneSdf, lp, 0.0005);
            h.n = phoneWorldDir(g);
            float pm;
            phoneSdfM(lp, pm);
            h.id = pm > 0.5 ? ID_CABLE : g.y > 0.9 ? ID_SCREEN : ID_PHONE;
        }
    }
    {
        vec3 lro = toHocker(ro - gCo), lrd = toHocker(rd);
        float tc = couchMarch(lro, lrd, h.t);
        if(tc >= 0.){
            h.t = tc;
            vec3 lp = lro + lrd * tc;
            float foot;
            couchSdf(lp, foot);
            h.id = ID_FELT + int(foot + 0.5);
            h.lp = lp;
            h.ln = SDF_NORMAL(couchDist, lp, 0.002);
            h.n = fromHocker(h.ln);
        }
    }
    return h;
}

float roomAO(vec3 p, int id, float cable){
    if(id == ID_FLOOR){
        float ao = mix(SHADOW_CORNER, 1., smoothstep(0., 0.6, SHADOW_WALL_Z - SHADOW_SKIRT_D - p.z))
                 * mix(SHADOW_CORNER, 1., smoothstep(0., 0.6, p.x - SHADOW_SIDE_X - SHADOW_SKIRT_D));
        vec2 fxz = toHocker(p - gCo).xz;
        for(int i = 0; i < 4; i++)
            ao *= mix(0.3, 1., smoothstep(SHADOW_LEG_TOE * 0.6, SHADOW_LEG_TOE * 3.5, length(fxz - couchFoot(i).xz)));
        float fd = sdBox(fxz - vec2(-SHADOW_COUCH_W * 0.5, SHADOW_COUCH_L * 0.5), vec2(SHADOW_COUCH_W, SHADOW_COUCH_L) * 0.5);
        ao *= mix(SHADOW_COUCH_UNDER, 1., smoothstep(-0.1, SHADOW_COUCH_SPREAD, fd));
        if(cable >= SHADOW_CABLE_R) ao *= mix(0.45, 1., smoothstep(SHADOW_CABLE_R, SHADOW_CABLE_R * 3., cable));
        return ao;
    }
    float skirtTop = mix(SHADOW_CORNER, 1., smoothstep(0., 0.125, p.y - SHADOW_SKIRT_H));
    if(id == ID_WALL) return skirtTop * mix(SHADOW_CORNER, 1., smoothstep(0., 0.4, p.x - SHADOW_SIDE_X));
    if(id == ID_SIDE) return skirtTop * mix(SHADOW_CORNER, 1., smoothstep(0., 0.4, SHADOW_WALL_Z - p.z));
    if(id == ID_SKIRT){
        float gy = SHADOW_SKIRT_H - SHADOW_SKIRT_D * SHADOW_SKIRT_BEAD * 2.6;
        float gw = SHADOW_SKIRT_D * 0.12 + gPx;
        return mix(SHADOW_CORNER, 1., smoothstep(0., 0.03, p.y))
             * (1. - 0.55 * (1. - smoothstep(0., gw, abs(p.y - gy))));
    }
    return 1.;
}

float staticShadow(vec3 p, vec3 n, vec3 ld, float dist, int id){
    if(outletMarch(p + n * 0.002, ld, dist) > 0.) return 0.;
    if(id == ID_FLOOR || id == ID_WALL || id == ID_SKIRT)
        return couchShadow(toHocker(p + n * 0.004 - gCo), toHocker(ld), dist);
    return 1.;
}

struct Shade {
    vec3 base;
    vec3 light;
};

Shade shadeScene(vec3 ro, vec3 rd, Hit h){
    if(h.id == ID_NONE) return Shade(vec3(0.), vec3(0.));
    int id = h.id;
    vec3 n = h.n;
    vec3 p = ro + rd * h.t;
    gPx = h.t / (SHADOW_FOCAL * iResolution.y) / sqrt(max(abs(dot(n, rd)), 0.3));
    if(id == ID_SCREEN) return Shade(phoneScreen(h.lp.xz) * SHADOW_PHONE_BRIGHT, vec3(0.));
    vec3 cf = id == ID_FLOOR ? cableFloor(p.xz) : vec3(1e9, 0., 0.);
    bool onCable = cf.x < SHADOW_CABLE_R;
    if(onCable){
        float a = cf.x / SHADOW_CABLE_R;
        n = normalize(vec3(cf.y * a, sqrt(max(1. - a * a, 0.)), cf.z * a));
    }
    float rauh = 0.5;
    if(isWall(id)){
        vec2 wv = id == ID_WALL ? p.xy : p.zy;
        vec3 T = id == ID_WALL ? vec3(1., 0., 0.) : vec3(0., 0., 1.);
        float e = SHADOW_WALL_GRAIN;
        rauh = raufaser(wv);
        vec2 g = vec2(raufaser(wv + vec2(e, 0.)) - rauh, raufaser(wv + vec2(0., e)) - rauh) / e;
        float fade = 1. - smoothstep(1., 4., gPx / SHADOW_WALL_GRAIN);
        n = normalize(n - (g.x * T + g.y * vec3(0., 1., 0.)) * SHADOW_WALL_BUMP * SHADOW_WALL_GRAIN * fade);
    }
    vec3 tl = gLight - p;
    float dist = length(tl);
    vec3 ld = tl / dist;
    float dif = max(dot(n, ld), 0.) / (1. + pow(dist / SHADOW_LIGHT_RANGE, 2.));
    float sh = dif > 0. ? staticShadow(p, n, ld, dist, id) : 0.;
    float ao = roomAO(p, id, cf.x);

    float emit = 0.;
    vec3 albedo = id == ID_FLOOR ? (onCable ? SHADOW_CABLE_COL : SHADOW_FLOOR * floorBoards(p.xz))
                : id == ID_PHONE ? SHADOW_PHONE_COL
                : isWall(id) ? SHADOW_WALL * mix(1. - SHADOW_WALL_TONE, 1. + SHADOW_WALL_TONE, rauh)
                : id == ID_FELT ? SHADOW_COUCH * felt(h.lp, h.ln) + SHADOW_FELT_SHEEN * pow(1. - max(dot(n, -rd), 0.), 4.)
                : id == ID_LEG ? SHADOW_WOOD * mix(0.75, 1.25, texture(iChannel1, fract(vec2((h.lp.x + h.lp.z) * 1.7, h.lp.y * 0.08))).r)
                : id == ID_CAP ? SHADOW_BRASS
                : isOutlet(id) ? outletAlbedo(h.lp, id, emit) : SHADOW_SKIRT;
    float gain = SHADOW_GAIN * (id == ID_FLOOR ? SHADOW_FLOOR_GAIN : 1.);
    float amb = isHocker(id) ? SHADOW_COUCH_AMB : SHADOW_AMB;
    float rv = max(dot(reflect(-ld, n), -rd), 0.);
    vec3 spec = id == ID_LEG ? vec3(SHADOW_WOOD_SHEEN) * pow(rv, 24.)
              : id == ID_CAP ? vec3(SHADOW_BRASS_SHINE) * pow(rv, 60.)
              : id == ID_CLIP ? vec3(SHADOW_CLIP_SHINE) * pow(rv, 70.)
              : (isOutlet(id) || id == ID_SIDE || onCable) ? vec3(SHADOW_OUTLET_GLOSS) * pow(rv, 32.) : vec3(0.);
    float glow = id == ID_FLOOR ? phoneGlow(p) : 0.;
    return Shade(albedo * amb * ao + SHADOW_OUTLET_ACCENT * 3. * emit + GRAD_TOP * glow,
                 (albedo * gain * dif * ao + spec) * sh);
}

Shade roomBake(vec2 q){
    setupRoom();
    vec3 rd = camRay(q);
    bool ss = outletSS(q) || phoneSS(gRo, rd);
    if(rd.z > 0.){
        float yw = gRo.y + rd.y * (SHADOW_WALL_Z - gRo.z) / rd.z;
        ss = ss || (yw > -SHADOW_SKIRT_SS.x && yw < SHADOW_SKIRT_H + SHADOW_SKIRT_SS.y);
    }
    if(!ss) return shadeScene(gRo, rd, sceneTrace(gRo, rd));
    Shade acc = Shade(vec3(0.), vec3(0.));
    for(int i = 0; i < 4; i++){
        vec3 rs = camRay(q + ssOffset(i, 2) / iResolution.y);
        Shade s = shadeScene(gRo, rs, sceneTrace(gRo, rs));
        acc.base += s.base * 0.25;
        acc.light += s.light * 0.25;
    }
    return acc;
}

float roomDepth(vec2 q){
    setupRoom();
    return sceneTrace(gRo, camRay(q)).t;
}

vec2 roomUV(vec2 q){
    vec2 fc = q * iResolution.y + 0.5 * iResolution.xy;
    return vec2(fc.x, iResolution.y - fc.y) / iResolution.xy;
}

vec3 shadowPlay(vec2 q, vec2 tp){
    vec2 uv = roomUV(q);
    vec4 st = texture(iChannel3, uv);
    vec3 li = texture(iChannel4, uv).rgb;
    vec3 col = st.rgb + bgNoise(tp);
    if(max(li.r, max(li.g, li.b)) < 1e-4) return col;
    setupCamera();
    vec3 p = gRo + camRay(q) * st.a;
    vec3 tl = gLight - p;
    float dist = length(tl);
    vec3 ld = tl / dist;
    gFarPad = 0.;
    float sh = solidShadow(gAmpMi * (p + ld * 0.004 - gAmpPos), gAmpMi * ld, dist, SHADOW_K, SHADOW_STEPS);
    gFarPad = SDF_RANGE;
    return col + li * sh;
}
