void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 q = cvQ((fragCoord - 0.5 * iResolution.xy) / iResolution.y);
    fragColor = cvLayersItems(q, cvLayersRooms(q, texture(iChannel16, qt_TexCoord0)));
}
