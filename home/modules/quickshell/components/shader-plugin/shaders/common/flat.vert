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

void main() {
    gl_Position = ubuf.qt_Matrix * qt_VertexPosition;
    qt_TexCoord0 = qt_VertexTexCoord0;
}
