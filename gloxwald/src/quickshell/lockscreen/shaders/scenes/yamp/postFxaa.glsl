void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 px = 1. / iResolution.xy;
    vec2 uv = vec2(fragCoord.x, iResolution.y - fragCoord.y) * px;
    const vec3 luma = vec3(0.299, 0.587, 0.114);

    vec3 cc = texture(iChannel0, uv).rgb;
    float lc = dot(cc, luma);
    float l00 = dot(texture(iChannel0, uv + vec2(-0.5, -0.5) * px).rgb, luma);
    float l10 = dot(texture(iChannel0, uv + vec2( 0.5, -0.5) * px).rgb, luma);
    float l01 = dot(texture(iChannel0, uv + vec2(-0.5,  0.5) * px).rgb, luma);
    float l11 = dot(texture(iChannel0, uv + vec2( 0.5,  0.5) * px).rgb, luma);

    vec2 dir = vec2((l01 + l11) - (l00 + l10), (l00 + l01) - (l10 + l11));
    float reduce = max((l00 + l10 + l01 + l11) * (1. / 32.), 1. / 128.);
    float rcp = 1. / (min(abs(dir.x), abs(dir.y)) + reduce);
    dir = clamp(dir * rcp, -8., 8.) * px;

    vec3 a = 0.5 * (texture(iChannel0, uv - dir / 6.).rgb + texture(iChannel0, uv + dir / 6.).rgb);
    vec3 b = a * 0.5 + 0.25 * (texture(iChannel0, uv - dir * 0.5).rgb + texture(iChannel0, uv + dir * 0.5).rgb);

    float lmin = min(lc, min(min(l00, l10), min(l01, l11)));
    float lmax = max(lc, max(max(l00, l10), max(l01, l11)));
    float lb = dot(b, luma);
    fragColor = vec4((lb < lmin || lb > lmax) ? a : b, 1.);
}
