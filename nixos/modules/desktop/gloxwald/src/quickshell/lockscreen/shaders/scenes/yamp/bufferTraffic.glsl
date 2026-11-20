void mainImage(out vec4 fragColor, in vec2 fragCoord){
    int x = int(fragCoord.x), y = int(iResolution.y - fragCoord.y);
    bool fresh;
    float dt = agDt(iChannel9, fresh);
    mpLoad();
    vec4 meta = texelFetch(iChannel9, AG_META, 0);
    float stamp = float(mpWord(gMpBase + 1)) + float(mpWord(gMpBase + 9)) * 0.001 + float(gMpCars) * 10000.;
    if(meta.y != float(u_traffic_map) || meta.z != stamp){ fresh = true; dt = 0.; }
    if(ivec2(x, y) == AG_META){ fragColor = vec4(iTime, float(u_traffic_map), stamp, fresh ? 0. : mod(meta.w + 1., 1024.)); return; }
    if(y < 2){
        if(x >= MP_N){ fragColor = vec4(0.); return; }
        vec4 r0, r1;
        mpStep(iChannel9, x, dt, fresh, r0, r1);
        fragColor = y == 0 ? r0 : r1;
        return;
    }
    if(y == MP_SENSE_ROW){
        fragColor = x < MP_N ? mpSensed(iChannel9, x, fresh) : vec4(0.);
        return;
    }
    if(y >= MP_GATE_ROW && y < MP_GATE_ROW + MP_GATE_ROWS){
        fragColor = fresh ? vec4(0.) : mpGateRow(iChannel9, x + (y - MP_GATE_ROW) * AG_W);
        return;
    }
    if(y == MP_CAR_ROW){
        fragColor = x < MP_N ? mpRemember(iChannel9, x, fresh) : vec4(0.);
        return;
    }
    if(y >= MP_CONG_ROW && y < MP_CONG_ROW + MP_CONG_ROWS){
        int e = x + (y - MP_CONG_ROW) * AG_W;
        fragColor = e >= mpWord(gMpBase + 1) || fresh ? vec4(0.)
                  : (y - MP_CONG_ROW) != int(meta.w) % MP_CONG_ROWS ? texelFetch(iChannel9, ivec2(x, y), 0) : mpCongest(iChannel9, e);
        return;
    }
    if(y < AG_FIELD0){
        fragColor = !fresh && (y - AG_BIN0) % MP_BIN_SLICES != int(meta.w) % MP_BIN_SLICES ? texelFetch(iChannel9, ivec2(x, y), 0)
                  : agBin(iChannel9, x, y - AG_BIN0, gMpCars, mpBinReach(), u_aspect);
        return;
    }

    fragColor = vec4(0.);
}
