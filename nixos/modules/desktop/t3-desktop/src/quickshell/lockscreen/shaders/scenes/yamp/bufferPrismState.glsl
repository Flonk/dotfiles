void mainImage(out vec4 fragColor, in vec2 fragCoord){
    int x = int(fragCoord.x), y = int(iResolution.y - fragCoord.y);
    int j = x % PRISM_PTS;
    fragColor = j < PRISM_PTS && x < PRISM_ROW * PRISM_PTS ? prismState(y * PRISM_ROW + x / PRISM_PTS, j) : vec4(0.);
}
