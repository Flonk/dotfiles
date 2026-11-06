void mainImage(out vec4 fragColor, in vec2 fragCoord){
    fragColor = gravState(int(fragCoord.x), int(iResolution.y - fragCoord.y));
}
