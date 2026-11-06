void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 q = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    int chunk = int(u_prism_chunk);
    vec3 prev = chunk == 0 ? vec3(0.) : texelFetch(iChannel9, ivec2(fragCoord.x, iResolution.y - fragCoord.y), 0).rgb;
    fragColor = vec4(prev + prismLight(q, chunk * PRISM_CHUNK), 1.);
}
