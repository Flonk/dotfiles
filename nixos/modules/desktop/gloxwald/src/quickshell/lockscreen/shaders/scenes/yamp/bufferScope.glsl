void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = vec2(fragCoord.x, iResolution.y - fragCoord.y) / iResolution.xy;
    vec4 prev = textureLod(iChannel9, uv, 0.);
    vec2 q = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    sequenceModes(q);
    if(W[MODE_SCOPE] < 0.001){
        fragColor = vec4(0., 0., 0., iTime);
        return;
    }
    fragColor = scopePhosphor(q, prev);
}
