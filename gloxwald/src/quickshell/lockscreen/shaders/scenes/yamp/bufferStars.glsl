void mainImage(out vec4 fragColor, in vec2 fragCoord){
    gSeed = 100. * vec2(sk_seed(0), sk_seed(1));
    fragColor = skyFigure(int(fragCoord.x));
}
