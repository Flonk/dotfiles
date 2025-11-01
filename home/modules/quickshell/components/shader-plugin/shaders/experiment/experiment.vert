#version 440

layout(location = 0) in vec4 qt_VertexPosition;
layout(location = 1) in vec2 qt_VertexTexCoord0;

layout(location = 0) out vec2 qt_TexCoord0;

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
    float theta = qt_VertexTexCoord0.x * 6.2831853; // map horizontal axis to angle
    float baseRadius = mix(0.18, 0.48, qt_VertexTexCoord0.y);

    float audio = sampleAudio(qt_VertexTexCoord0.x);
    float animatedPulse = 0.04 * sin(ubuf.time * 0.06 + theta * 3.0);
    float displacement = audio * 0.22 * smoothstep(0.05, 1.0, qt_VertexTexCoord0.y);
    float radius = baseRadius + displacement + animatedPulse;

    vec2 circle = vec2(cos(theta), sin(theta));
    vec2 center = ubuf.resolution * 0.5;
    float uniformScale = ubuf.resolution.y; // keep shape round even if width != height
    vec2 warped = center + circle * radius * uniformScale;

    vec4 position = qt_VertexPosition;
    position.xy = warped;

    gl_Position = ubuf.qt_Matrix * position;
    qt_TexCoord0 = qt_VertexTexCoord0;
}
