vec4 cvGet(int i, int r){ return texelFetch(iChannel9, ivec2(i, r), 0); }
vec4 cvSt(int k){ return texelFetch(iChannel9, ivec2(k, CV_ROW), 0); }

int cvNextTrack(int t, bool rej){
    if(t == CT_J) return CT_DROP;
    if(t == CT_DROP) return CT_MAIN;
    if(t == CT_MAIN) return CT_FIN;
    if(t == CT_FIN) return rej ? CT_REJ : CT_SLIDE;
    if(t == CT_SLIDE) return CT_PACK;
    return -1;
}

bool cvJammed(int k){
    vec4 j = cvSt(CX_JAM);
    return j.x == float(k) && j.y < CV_FIX_AT;
}

void cvFree(out vec4 r0, out vec4 r1){
    r0 = vec4(9., 9., 0., 0.);
    r1 = vec4(-1., 0., 0., 0.);
}

// a fresh factory as if it had been running a while: the first CV_NFRAME
// items are empty flasks spread round the return loop; then amps spread along
// every track after the weld, carrying every station they would have passed;
// then knocked-out pieces between each line's hammer and the weld room
void cvInit(int i, out vec4 r0, out vec4 r1){
    if(i < CV_NFRAME){
        float s = (float(i) + 0.5) / float(CV_NFRAME) * cvLen(CT_FRAME);
        r0 = vec4(cvAt(CT_FRAME, s), 0., float(CV_KFRAME));
        r1 = vec4(float(CT_FRAME), s, 0., 0.);
        return;
    }
    int k = i - CV_NFRAME;
    const int TR[6] = int[](CT_MAIN, CT_FIN, CT_PACK, CT_P, CT_J, CT_D);
    for(int n = 0; n < 6; n++){
        int t = TR[n];
        float s0 = 0.02, s1 = cvLen(t), sp = 0.1;
        if(t == CT_PACK) s1 = cvPackEnd() - 0.02;
        int li = cvLineOfTrack(t);
        if(li >= 0){
            s0 = cvSAtSt(3 + li) + 0.03;
            s1 = t == CT_J ? cvSAtSt(CS_WELD1) - 0.03 : s1 - 0.01;
            sp = 0.07;
        }
        int cnt = int(max(floor((s1 - s0) / sp), 0.));
        if(k >= cnt){ k -= cnt; continue; }
        float s = s0 + (float(k) + 0.5) * sp;
        if(t == CT_MAIN && s > cvSAtSt(CS_CAUSTIC) + 1e-3 && s < cvShaftS() + 0.01) break;
        if(t == CT_MAIN && s > cvSAtSt(CS_FLICK) + 1e-3 && s < cvSAtP(CT_MAIN, vec2(CVX(9.), CVR(7.))) + 1e-3) break;
        int m;
        float kind;
        if(li >= 0){
            m = (1 << (CS_PRESS + li)) | (1 << li) | (1 << (3 + li));
            kind = li == 0 ? 1. : li == 1 ? 0. : 2.;
        } else {
            m = (1 << CS_WELD1) | (1 << CS_WELD2);
            kind = 0.;
            int ri = t == CT_MAIN ? 0 : t == CT_FIN ? 1 : 3;
            for(int st = 8; st < CV_NS; st++){
                int ts = CV_ST_T[st];
                if(st > 17 && st < CS_CAUSTIC) continue;
                int rs = ts == CT_MAIN ? 0 : ts == CT_FIN ? 1 : ts == CT_PACK ? 3 : 9;
                if(rs < ri || (rs == ri && cvSAtSt(st) < s - 0.01)) m |= 1 << cvBit(st);
            }
        }
        r0 = vec4(cvAt(t, s), 0., kind);
        r1 = vec4(float(t), s, 0., float(m));
        return;
    }
    cvFree(r0, r1);
}

void cvStep(int i, float dt, out vec4 r0, out vec4 r1){
    vec4 a0 = cvGet(i, 0), a1 = cvGet(i, 1);
    int t = cvI(a1.x), m = cvI(a1.w);
    float s = a1.y, tm = a1.z, ang = a0.z, info = a0.w;
    if(t == CT_FREE){
        int rank = 0;
        for(int j = 0; j < CV_N; j++){
            if(j >= i || rank > 2) break;
            if(cvI(cvGet(j, 1).x) == CT_FREE) rank++;
        }
        if(rank > 2){ cvFree(r0, r1); return; }
        int li = rank == 0 ? 1 : rank == 1 ? 0 : 2;
        vec4 hs = cvSt(3 + li);
        if(hs.w > 0.5){
            float fs = CV_TOPY - CV_ST_Y[li];
            r0 = vec4(cvAt(CT_FRAME, fs), 0., float(CV_KFRAME));
            r1 = vec4(float(CT_FRAME), fs, 0., 0.);
            return;
        }
        cvFree(r0, r1);
        return;
    }
    if(t == CT_ARM1 || t == CT_ARM2){
        int a = t == CT_ARM1 ? 0 : 1;
        float dw = CV_ST_DW[CS_WELD1 + a];
        tm += dt;
        if(tm >= dw){ cvFree(r0, r1); return; }
        r0 = vec4(cvArmP(a, tm / dw), 0., info);
        r1 = vec4(float(t), s, tm, float(m));
        return;
    }

    float len = cvLen(t);
    int nt = cvNextTrack(t, cvI(info) >= 4);
    float lim = 1e9, shs = cvShaftS();
    float dIn = shs + CVR(9.) - CV_HUB.y + CVG(2.5), dOut = dIn + CVG(6.);
    bool busy = false;
    int rn = 0;
    float sRin = t == CT_PACK ? cvSAtP(CT_PACK, vec2(CVX(-8.), CVR(-4.))) : 0., sRout = t == CT_PACK ? cvSAtP(CT_PACK, vec2(CVG(-15.), CVR(-15.))) : 0.;
    for(int j = 0; j < CV_N; j++){
        if(j == i) continue;
        vec4 b = cvGet(j, 1);
        int tj = cvI(b.x);
        if(tj == CT_MAIN && b.y > shs - 1e-4 && b.y < shs + 1.2 * CV_GAP) busy = true;
        if(t == CT_PACK && tj == CT_PACK && b.y > sRin - 1e-4 && b.y < sRout) rn++;
        float gp = t == CT_MAIN && s > dIn - 1e-3 && b.y < dOut ? 0. : CV_GAP;
        if(tj == t && (b.y > s || (b.y == s && j > i))) lim = min(lim, b.y - gp);
        else if(nt >= 0 && tj == nt) lim = min(lim, len + b.y - CV_GAP);
    }
    int ks = -1;
    float sk = 1e9;
    for(int k = 0; k < CV_NS; k++){
        if(CV_ST_T[k] != t || ((m >> cvBit(k)) & 1) == 1 || k == CS_PRIME || (k == CS_BOOT && cvI(info) < 4)) continue;
        float x = cvSAtSt(k);
        if(x >= s - 1e-3 && x < sk){ sk = x; ks = k; }
    }
    float s0 = s;
    int li = cvLineOfTrack(t);
    int kb = li < 0 ? (t == CT_MAIN && ((m >> CS_CAUSTIC) & 1) == 0 ? CS_CAUSTIC : t == CT_PACK && ((m >> cvBit(CS_CLASS)) & 1) == 0 ? CS_CLASS : -1) : ((m >> li) & 1) == 0 ? li : -1;
    vec4 kst = kb >= 0 ? cvSt(kb) : vec4(-1.);
    bool batch = kb >= 0 && (kst.w > float(cvBatchN(kb)) - 0.5 || (kb == CS_CAUSTIC && kst.x >= 0.)) && cvBatchSlot(kb, s) >= 0;
    if(batch && kb != CS_CAUSTIC && kst.z > 0.5) m |= 1 << cvBit(kb);
    if(ks >= 0 && s >= sk - 1e-4){
        s = sk;
        bool go = !cvJammed(ks) && cvBatchN(ks) == 0;
        if(ks == CS_WELD1 || ks == CS_WELD2){
            vec4 as = cvSt(ks);
            go = go && cvI(as.y) == i && as.w >= 0.;
        }
        if(go){
            tm += dt;
            if(tm >= CV_ST_DW[ks]){
                m |= 1 << cvBit(ks);
                tm = 0.;
                for(int j = 0; j < 5; j++){
                    if(CV_QC_K[j] != ks) continue;
                    vec4 kt = cvSt(CX_QK + j);
                    if(cvI(kt.y) == i && kt.z > 0.5){ cvFree(r0, r1); return; }
                }
                if(ks == CS_XRAY && random(vec2(float(i) * 2.11, fract(iTime * 0.173) * 57.)) < CV_FLAW && cvI(info) < 4) info += 4.;
                if(ks == CS_BOOT){ cvFree(r0, r1); return; }
                if(ks == CS_FLICK) s += CVG(18.) - CVX(9.) + CVR(9.) - CVR(7.) + 1e-4;
            }
        }
    } else if(!batch){
        float stop = min(lim, ks >= 0 ? sk : 1e9);
        if(nt < 0) stop = min(stop, len);
        if(rn >= 3 && s < sRin - 1e-4) stop = min(stop, sRin - 0.0006);
        if(kb == CS_CAUSTIC && kst.x >= 0.){
            float s7 = cvSAtSt(CS_CAUSTIC) - 7. * CV_GAP;
            if(s < s7 - 0.5 * CV_GAP) stop = min(stop, s7 - CV_GAP);
        }
        s = max(s, min(s + cvSpeed(t, s, cvAt(t, s)) * dt, stop));
    }
    if(t == CT_FIN){
        float sw = CVG(6.3852), se = cvSAtP(CT_FIN, vec2(CVX(22.), CVR(-1.)));
        if(s0 < se - 1e-4){
            tm += (s0 < sw ? 0.62 : 1.) * dt;
            float ns = s0 + tm * dt;
            if(s0 < sw && ns >= sw) tm *= 0.15;
            if(ns > lim){
                ns = lim;
                tm = 0.;
            }
            s = max(s0, min(ns, se));
            if(s >= se - 1e-4) tm = 0.;
        }
    }
    vec4 cs = cvSt(CS_CAUSTIC);
    float cT = cs.x * CV_ST_DW[CS_CAUSTIC] + dt;
    int cslot = t == CT_MAIN && ((m >> CS_CAUSTIC) & 1) == 0 && cs.x >= 0. ? cvBatchSlot(CS_CAUSTIC, s) : -1;
    if(cslot >= 0 && cT >= 5.6 && cvSpin(cT) >= cvRelTheta(cslot) && !busy){
        m |= 1 << CS_CAUSTIC;
        s = shs + 0.002;
        s0 = s;
        ang = 1.5708;
        tm = 0.;
        cslot = -1;
    }
    float shH = CVR(9.) - CV_HUB.y, lu = -1.;
    if(t == CT_MAIN && s0 > shs + 1e-3 && s0 < shs + shH - 1e-5){
        tm += dt;
        lu = min(tm / 1.1, 1.);
        float x = lu - 1.;
        s = max(s0, min(shs + 0.002 + (shH - 0.002) * min(1. + 2. * x * x * x + x * x, 1.), min(lim, shs + shH - 1e-4)));
        if(lu >= 1.){
            s = max(s, dIn + 1e-4);
            tm = 0.;
            lu = -1.;
        }
    }
    if(t == CT_MAIN && s >= cvSAtSt(CS_PRIME)) m |= 1 << CS_PRIME;
    vec2 dir = cvDirAt(t, s), p = cvAt(t, s);
    bool fall = (t == CT_DROP && s < CV_DIVE) || (t == CT_PACK && s > cvPackEnd()) || t == CT_REJ || (t == CT_MAIN && cvLaunchAt(p));
    bool roll = t == CT_SLIDE || (t == CT_FIN && cvRampAt(p)) || (t == CT_MAIN && cvMainZig(p));
    if(lu >= 0.) ang = 1.5708 + 10.9956 * (1. - (1. - lu) * (1. - lu) * (1. - lu));
    else if(t == CT_MAIN && cvRailAt(p)){
        float vx = dt > 0. ? (s - s0) / dt * dir.x : 0.;
        float th = mod(ang + 3.14159, 6.28318) - 3.14159;
        tm += (81. * (clamp(-1.1 * vx, -0.9, 0.9) - th) - 2.7 * tm) * dt;
        ang = th + tm * dt;
    }
    else if(fall) ang -= (s - s0) * 7.;
    else if(roll) ang -= (s - s0) * (abs(dir.x) > 0.2 ? sign(dir.x) : 1.) / (CV_SIZE * 0.45);
    else {
        ang = mod(ang + 3.14159, 6.28318) - 3.14159;
        ang *= exp(-dt * 10.);
    }

    if(nt >= 0 && s >= len){
        if(t == CT_DROP){
            float da = 0.;
            s += CVX(32.) - cvPlkPos(i, len, da).x;
        }
        if(t == CT_J) m &= ~((1 << 1) | (1 << 4) | (1 << 19));
        s -= len;
        t = nt;
    }
    else if((t == CT_REJ || t == CT_PACK) && s >= len - 1e-4){ cvFree(r0, r1); return; }
    else if(t == CT_FRAME){
        for(int k = 0; k < 3; k++){
            int fl = k == 0 ? 2 : k == 1 ? 0 : 1;
            float sr = len - (CV_TOPY - CV_ST_Y[fl]);
            if(s0 > sr + 1e-4 || s < sr - 1e-4) continue;
            int lt = fl == 0 ? CT_P : fl == 1 ? CT_J : CT_D;
            bool clear = true;
            for(int j = 0; j < CV_N; j++){
                vec4 b = cvGet(j, 1);
                if(cvI(b.x) == lt && b.y < CV_GAP * 1.5) clear = false;
            }
            if(clear && cvSt(CX_COUNT + fl).x < CV_LANECAP[fl] - 0.5){ t = lt; s = 0.; m = 0; info = float(fl == 0 ? 1 : fl == 1 ? 0 : 2); break; }
        }
    }
    else if((t == CT_P || t == CT_D) && s >= len - 1e-4){
        int k = t == CT_D ? CS_WELD1 : CS_WELD2;
        vec4 as = cvSt(k);
        if(as.y >= 0. && cvI(as.w) == i){ t = t == CT_D ? CT_ARM1 : CT_ARM2; tm = 0.; }
    }
    if(t == CT_MAIN && cvRailAt(cvAt(CT_MAIN, s0)) && !cvRailAt(p)) tm = 0.;
    vec2 swing = t == CT_MAIN && cvRailAt(p) ? vec2(sin(ang), 1. - cos(ang)) * CV_SIZE * 0.55 : vec2(0.);
    vec2 pos = t == CT_ARM1 ? cvArmP(0, 0.) : t == CT_ARM2 ? cvArmP(1, 0.) : cvAt(t, s);
    pos += swing;
    if(lu >= 0.){
        float x = lu - 1.;
        vec2 tg = CV_DRUM + vec2(CV_DRUMR - CVG(0.55), 0.);
        pos.y = CV_HUB.y + 0.002 + (tg.y - CV_HUB.y - 0.002) * (1. + 2. * x * x * x + x * x);
        pos.x = mix(CVX(26.), tg.x, lu);
    }
    if(t == CT_MAIN){
        vec2 np = cvAt(t, s);
        if(abs(np.y - CVR(9.)) < 0.001 && np.x < CVG(24.) && np.x > CVG(18.)){
            pos = cvDrumPos(i, (CVG(24.) - np.x) / CVG(6.), iTime, ang);
            vec2 rc = pos - CV_DRUM;
            float lim2 = CV_DRUMR - CVG(0.5);
            if(length(rc) > lim2) pos = CV_DRUM + rc / length(rc) * lim2;
        }
        if(ks == CS_FLICK && abs(s - sk) < 1e-4 && ((m >> cvBit(CS_FLICK)) & 1) == 0) pos = cvFlickPos(i, tm / CV_ST_DW[CS_FLICK], iTime, ang);
    }
    if(t == CT_PACK){
        float sb = cvBounceS(), L = CVG(4.4721);
        if(s > sb + 1e-4 && s < sb + L){
            float u = (s - sb) / L;
            vec2 pad = vec2(CVX(-17.), CVR(-15.)), land = vec2(CVX(-19.), CVR(-11.));
            pos = mix(pad, land, u) + vec2(0., CVG(5.) * 4. * u * (1. - u));
            ang = 6.28318 * u;
            if(u > 0.5) m &= ~(1 << cvBit(CS_HAT));
        }
    }
    if(t == CT_DROP){
        float pa = ang;
        pos = cvPlkPos(i, s, pa);
        if(s < CV_PLK1) ang = pa;
    }
    if(cslot >= 0){
        if(cT < 3.){
            float u = cT / 3.;
            float dip = smoothstep(0., 0.18, u) * (1. - smoothstep(0.82, 1., u));
            pos.y -= CVG(2.8) * dip + 0.002 * dip * sin(iTime * 40. + float(i));
        } else {
            float ph = cvSpin(cT) + float(cslot) * 0.785398;
            float e = smoothstep(3., 4.2, cT);
            pos = mix(cvAt(t, s), CV_HUB + CV_HUBR * vec2(cos(ph), sin(ph)), e);
            ang = cT < 4.2 ? e * (mod(ph + 1.5708 + 3.14159, 6.28318) - 3.14159) : ph + 1.5708;
            tm = 0.;
        }
    }
    r0 = vec4(pos, ang, info);
    r1 = vec4(float(t), s, tm, float(m));
}

vec4 cvStation(int k, float dt){
    vec4 prev = cvSt(k);
    int t = CV_ST_T[k];
    float sk = cvSAtSt(k);
    bool weld = k == CS_WELD1 || k == CS_WELD2;
    int pt = k == CS_WELD1 ? CT_D : CT_P, at = k == CS_WELD1 ? CT_ARM1 : CT_ARM2;
    float lenPt = cvLen(pt);
    int holder = -1, pw = -1, pArm = -1;
    float prog = -1.;
    for(int j = 0; j < CV_N; j++){
        vec4 b = cvGet(j, 1);
        int tj = cvI(b.x), mj = cvI(b.w);
        if(tj == t && abs(b.y - sk) < 2e-4 && ((mj >> cvBit(k)) & 1) == 0 && (k != CS_BOOT || cvI(cvGet(j, 0).w) >= 4)){ holder = j; prog = b.z / CV_ST_DW[k]; }
        if(weld){
            if(tj == at) pArm = j;
            else if(tj == pt && b.y >= lenPt - 1e-3) pw = j;
        }
    }
    float since = prev.z + dt, extra = prev.w;
    int ph = cvI(prev.y);
    if(prev.x >= 0. && holder != ph){
        since = 0.;
        if((k == CS_SCAN || k == CS_XRAY) && ph >= 0) extra = cvI(cvGet(ph, 0).w) >= 4 ? 1. : 0.;
        if(k == CS_LABEL) extra = prev.w + 1.;
    }
    if(weld) extra = float(pArm >= 0 ? pArm : pw);
    if(k >= 3 && k <= 5) extra = prev.x >= 0. && holder != ph && ph >= 0 ? 1. : 0.;
    if(cvBatchN(k) > 0){
        extra = 0.;
        for(int j = 0; j < CV_N; j++){
            vec4 b = cvGet(j, 1);
            if(cvI(b.x) == t && ((cvI(b.w) >> cvBit(k)) & 1) == 0 && cvBatchSlot(k, b.y) >= 0) extra += 1.;
        }
        float pr = prev.z > 0.5 ? -1. : prev.x, rel = 0.;
        if(extra > float(cvBatchN(k)) - 0.5 || (k == CS_CAUSTIC && pr >= 0.)){
            pr = max(pr, 0.) + dt / CV_ST_DW[k];
            if(pr >= 1.){ pr = 1.; rel = 1.; }
        } else pr = -1.;
        return vec4(pr, float(holder), rel, extra);
    }
    return vec4(prog, float(holder), since, extra);
}

// flasks of line li in play: its moulds before the hammer and its returning
// frames
// moulds of line li still waiting for their pour
vec4 cvCountStep(int li){
    int lt = li == 0 ? CT_P : li == 1 ? CT_J : CT_D;
    float n = 0.;
    for(int j = 0; j < CV_N; j++){
        vec4 b = cvGet(j, 1);
        if(cvI(b.x) == lt && ((cvI(b.w) >> li) & 1) == 0) n += 1.;
    }
    return vec4(n, 0., 0., 0.);
}

// seconds since the paternoster last pushed a flask into line li
vec4 cvPushStep(int li, float dt){
    int lt = li == 0 ? CT_P : li == 1 ? CT_J : CT_D;
    for(int j = 0; j < CV_N; j++){
        vec4 b = cvGet(j, 1);
        if(cvI(b.x) == lt && b.y < 0.004) return vec4(0.);
    }
    return vec4(min(cvSt(CX_PUSH + li).x + dt, 10.));
}

vec4 cvJamStep(float dt){
    vec4 p = cvSt(CX_JAM);
    if(p.x < 0.){
        p.z -= dt;
        if(p.z <= 0.){
            const int C[6] = int[](3, 4, 5, 12, 15, 19);
            int r = min(int(random(vec2(fract(iTime * 0.37) * 50., 3.3)) * 6.), 5);
            p = vec4(float(C[r]), 0., 0., 0.);
        }
        return p;
    }
    p.y += dt;
    if(p.y >= CV_JAM_LEN) p = vec4(-1., 0., 16. + 20. * random(vec2(fract(iTime * 0.21) * 70., 7.1)), 0.);
    return p;
}

// a QC step's boot: seconds since it last kicked, the amp it is watching and
// whether that amp failed
vec4 cvQKickStep(int j, float dt){
    vec4 p = cvSt(CX_QK + j), st = cvSt(CV_QC_K[j]);
    int h = st.x >= 0. ? cvI(st.y) : -1;
    if(h != cvI(p.y)){
        float since = cvI(p.y) >= 0 && p.z > 0.5 ? 0. : min(p.x + dt, 10.);
        float v = h >= 0 && random(vec2(float(h) * 1.7 + float(j) * 3.1, fract(iTime * 0.37) * 50.)) < CV_QREJ[j] ? 1. : 0.;
        return vec4(since, float(h), v, 0.);
    }
    return vec4(min(p.x + dt, 10.), p.y, p.z, 0.);
}

// seconds since the bounce pad last knocked a cap off
vec4 cvHatFlyStep(float dt){
    float best = min(cvSt(CX_HATFLY).x + dt, 10.), sb = cvBounceS(), L = CVG(4.4721);
    for(int j = 0; j < CV_N; j++){
        vec4 b = cvGet(j, 1);
        if(cvI(b.x) == CT_PACK && b.y > sb + 1e-4 && b.y < sb + L) best = min(best, (b.y - sb) / 0.3);
    }
    return vec4(best, 0., 0., 0.);
}

vec4 cvSortStep(float dt){
    vec4 p = cvSt(CX_SORT);
    for(int j = 0; j < CV_N; j++){
        vec4 b = cvGet(j, 1);
        if(cvI(b.x) == CT_REJ && b.y < 0.02) return vec4(0.);
    }
    return vec4(min(p.x + dt, 10.), 0., 0., 0.);
}

vec4 cvSplashStep(float dt){
    vec4 p = cvSt(CX_SPLASH);
    float best = min(p.x + dt, 10.), bx = p.y;
    for(int j = 0; j < CV_N; j++){
        vec4 b = cvGet(j, 1);
        if(cvI(b.x) == CT_DROP && b.y > CV_DIVE && (b.y - CV_DIVE) / CV_WATER_V < best){
            best = (b.y - CV_DIVE) / CV_WATER_V;
            bx = cvGet(j, 0).x;
        }
    }
    return vec4(best, bx, 0., 0.);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    int x = int(fragCoord.x), y = int(iResolution.y - fragCoord.y);
    float asp = u_aspect / cvFit(u_aspect);
    bool fresh;
    float dt = agDt(iChannel9, fresh);
    if(ivec2(x, y) == AG_META){ fragColor = vec4(iTime, 0., 0., 0.); return; }
    float clk = fresh ? 0. : cvSt(CX_CLOCK).x;
    float sdt = dt * (clk < CV_WARM ? CV_WARP : 1.);
    if(y < 2){
        if(x >= CV_N){ fragColor = vec4(0.); return; }
        vec4 r0, r1;
        if(fresh) cvInit(x, r0, r1);
        else cvStep(x, sdt, r0, r1);
        fragColor = y == 0 ? r0 : r1;
        return;
    }
    if(y < AG_FIELD0){ fragColor = agBin(iChannel9, x, y - AG_BIN0, CV_N, 0.075, max(asp, 2.3)); return; }
    if(y == CV_ROW){
        if(x < CV_NS){ fragColor = fresh ? vec4(-1., -1., 10., x == CS_LABEL ? 0. : -1.) : cvStation(x, sdt); return; }
        if(x == CX_JAM){ fragColor = fresh ? vec4(-1., 0., 14., 0.) : cvJamStep(sdt); return; }
        if(x >= CX_QK && x < CX_QK + 5){ fragColor = fresh ? vec4(10., -1., 0., 0.) : cvQKickStep(x - CX_QK, sdt); return; }
        if(x == CX_HATFLY){ fragColor = fresh ? vec4(10.) : cvHatFlyStep(sdt); return; }
        if(x == CX_SORT){ fragColor = fresh ? vec4(10., 0., 0., 0.) : cvSortStep(sdt); return; }
        if(x == CX_SPLASH){ fragColor = fresh ? vec4(10., 0., 0., 0.) : cvSplashStep(sdt); return; }
        if(x >= CX_COUNT && x < CX_COUNT + 3){ fragColor = fresh ? vec4(0.) : cvCountStep(x - CX_COUNT); return; }
        if(x >= CX_PUSH && x < CX_PUSH + 3){ fragColor = fresh ? vec4(10.) : cvPushStep(x - CX_PUSH, sdt); return; }
        if(x == CX_CLOCK){ fragColor = vec4(clk + dt, 0., 0., 0.); return; }
    }
    fragColor = vec4(0.);
}
