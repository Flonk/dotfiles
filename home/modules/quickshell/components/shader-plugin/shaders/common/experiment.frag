#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 resolution;
    vec4 backgroundColor;
    vec4 accentColorA;
    vec4 accentColorB;
} ubuf;

layout(binding = 1) uniform sampler2D source;

float sampleAudio(float x) {
    return texture(source, vec2(x, 0.0)).r;
}

void main() {
    vec2 uv = (qt_TexCoord0 * ubuf.resolution) / ubuf.resolution.y;
    vec2 center = vec2(0.5 * ubuf.resolution.x / ubuf.resolution.y, 0.5);
    vec2 p = uv - center;
    float dist = length(p);

    float angle = atan(p.y, p.x);
    float normAngle = (angle + 3.14159265) / (2.0 * 3.14159265);

    float audio = sampleAudio(clamp(normAngle, 0.0, 1.0));
    float radius = 0.35 + audio * 0.25;

    float glow = smoothstep(radius, radius - 0.03, dist);
    float inner = smoothstep(radius - 0.05, radius - 0.1, dist);

    vec4 edge = mix(ubuf.accentColorA, ubuf.accentColorB,
                    0.5 + 0.5 * sin(ubuf.time * 0.5 + normAngle * 6.28318));

    fragColor = mix(ubuf.backgroundColor, edge, glow);
    fragColor = mix(fragColor, vec4(edge.rgb, 1.0), inner);
    fragColor.a = max(glow, inner);
    fragColor *= ubuf.qt_Opacity;
}
