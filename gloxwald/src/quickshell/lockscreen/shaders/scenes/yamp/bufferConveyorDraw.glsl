void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 q = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    vec2 tp = vec2(q.x, q.y + iTime * SCROLL * BG_SPEED) * NOISE_SCALE;
    fragColor = vec4(cvScene(q, tp), 1.);
}
