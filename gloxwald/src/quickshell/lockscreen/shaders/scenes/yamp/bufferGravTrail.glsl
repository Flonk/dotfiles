void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec4 prev = texelFetch(iChannel9, ivec2(fragCoord.x, iResolution.y - fragCoord.y), 0);
    vec2 q = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    fragColor = gravTrail(q, prev);
}
