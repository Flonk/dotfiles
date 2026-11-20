void mainImage(out vec4 fragColor, in vec2 fragCoord){
    gSeed = 100. * vec2(sk_seed(20), sk_seed(21));
    fragColor = fluidStep(ivec2(fragCoord.x, iResolution.y - fragCoord.y));
}
