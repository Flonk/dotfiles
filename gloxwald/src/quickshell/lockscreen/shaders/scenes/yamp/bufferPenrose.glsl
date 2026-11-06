void mainImage(out vec4 fragColor, in vec2 fragCoord){
    fragColor = penroseStatic((fragCoord - 0.5 * iResolution.xy) / iResolution.y);
}
