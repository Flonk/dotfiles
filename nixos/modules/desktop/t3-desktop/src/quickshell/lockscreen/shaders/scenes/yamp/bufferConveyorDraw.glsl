void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 q = cvQ((fragCoord - 0.5 * iResolution.xy) / iResolution.y);
    fragColor = vec4(cvLayersFront(q, cvLayersStations(q, cvLayersMachines(q, texture(iChannel16, qt_TexCoord0)))), 1.);
}
