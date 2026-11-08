void mainImage(out vec4 fragColor, in vec2 fragCoord){
    int x = int(fragCoord.x), y = int(iResolution.y - fragCoord.y);
    float asp = u_aspect;
    bool fresh;
    float dt = agDt(iChannel9, fresh);
    if(ivec2(x, y) == AG_META){ fragColor = vec4(iTime, 0., 0., 0.); return; }
    if(y < 2){
        if(x >= FI_N){ fragColor = vec4(0.); return; }
        vec4 r0, r1;
        fiStep(iChannel9, x, dt, fresh, asp, r0, r1);
        fragColor = y == 0 ? r0 : r1;
        return;
    }
    if(y < AG_FIELD0){ fragColor = agBin(iChannel9, x, y - AG_BIN0, FI_N, FI_SIZE * 0.5 + 0.016, asp); return; }

    fragColor = vec4(0.);
}
