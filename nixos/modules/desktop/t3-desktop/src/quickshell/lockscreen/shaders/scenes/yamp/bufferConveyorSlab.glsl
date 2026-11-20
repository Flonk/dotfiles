void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 q = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    fragColor = cvLayersSlab(cvQ(q), vec2(0.));
}
