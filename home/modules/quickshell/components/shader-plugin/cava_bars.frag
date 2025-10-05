// Cava music visualizer shader - animated bars
#version 440

precision highp float;

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    vec2 iResolution;
    float iBarCount;
} ubuf;

layout(binding = 1) uniform sampler2D iDataTexture;

const vec3 bottomColor = vec3(0.2, 0.8, 1.0);
const vec3 topColor = vec3(1.0, 0.3, 0.8);

void main() {
    vec2 uv = qt_TexCoord0;

    float bars = max(1.0, ubuf.iBarCount);
    float barIndex = floor(uv.x * bars);
    float barCoord = (barIndex + 0.5) / bars;

    float barHeight = texture(iDataTexture, vec2(barCoord, 0.5)).r;
    barHeight = clamp(barHeight, 0.0, 1.0);

    float pixelHeight = 1.0 - uv.y;
    vec3 color = vec3(0.0);

    if (pixelHeight <= barHeight) {
        float heightRatio = barHeight > 0.0 ? pixelHeight / barHeight : 0.0;
        color = mix(bottomColor, topColor, heightRatio);

        float glow = smoothstep(0.8, 1.0, heightRatio);
        color += vec3(glow * 0.35);
    }

    float barX = fract(uv.x * bars);
    float gap = smoothstep(0.45, 0.5, abs(barX - 0.5));
    color *= mix(1.0, 0.35, gap);

    float pulse = 0.05 * sin(ubuf.iTime * 6.0 + barIndex * 0.35);
    color = clamp(color + pulse, 0.0, 1.0);

    fragColor = vec4(color, ubuf.qt_Opacity);
}
