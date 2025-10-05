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
    float iSystemAnchor;
    float iMicrophoneAnchor;
    vec4 systemColorLow;
    vec4 systemColorHigh;
    vec4 microphoneColorLow;
    vec4 microphoneColorHigh;
} ubuf;

layout(binding = 1) uniform sampler2D iDataTexture;

struct LayerSample {
    vec3 color;
    float coverage;
};

LayerSample renderLayer(float value, float anchor, vec4 lowColor, vec4 highColor, float yCoord) {
    LayerSample layer;
    layer.color = vec3(0.0);
    layer.coverage = 0.0;

    value = clamp(value, 0.0, 1.0);
    if (value <= 0.001) {
        return layer;
    }

    float px = 1.0 / max(ubuf.iResolution.y, 1.0);
    float edge = px * 1.5;
    float gradient = 0.0;

    if (anchor > 1.5) { // center
        float halfValue = value * 0.5;
        float distance = abs(yCoord - 0.5);
        layer.coverage = smoothstep(-edge, edge, halfValue - distance);
        if (layer.coverage <= 0.0) {
            return layer;
        }
        float halfSafe = max(halfValue, 1e-3);
        gradient = distance / halfSafe;
    } else if (anchor > 0.5) { // top
        float distance = yCoord;
        layer.coverage = smoothstep(-edge, edge, value - distance);
        if (layer.coverage <= 0.0) {
            return layer;
        }
        gradient = distance / max(value, 1e-3);
    } else { // bottom
        float distance = 1.0 - yCoord;
        layer.coverage = smoothstep(-edge, edge, value - distance);
        if (layer.coverage <= 0.0) {
            return layer;
        }
        gradient = distance / max(value, 1e-3);
    }

    gradient = clamp(gradient, 0.0, 1.0);
    vec3 baseColor = mix(lowColor.rgb, highColor.rgb, gradient);
    float glow = smoothstep(0.75, 1.0, gradient);
    baseColor += glow * 0.25;
    layer.color = clamp(baseColor, 0.0, 1.0);
    return layer;
}

void main() {
    vec2 uv = qt_TexCoord0;

    float bars = max(1.0, ubuf.iBarCount);
    float barIndex = floor(uv.x * bars);
    float barCoord = (barIndex + 0.5) / bars;

    vec4 sampleData = texture(iDataTexture, vec2(barCoord, 0.5));
    float systemValue = clamp(sampleData.r, 0.0, 1.0);
    float microphoneValue = clamp(sampleData.g, 0.0, 1.0);

    LayerSample micLayer = renderLayer(microphoneValue, ubuf.iMicrophoneAnchor, ubuf.microphoneColorLow, ubuf.microphoneColorHigh, uv.y);
    LayerSample sysLayer = renderLayer(systemValue, ubuf.iSystemAnchor, ubuf.systemColorLow, ubuf.systemColorHigh, uv.y);

    vec3 micPremul = micLayer.color * micLayer.coverage;
    float micAlpha = micLayer.coverage;

    vec3 sysPremul = sysLayer.color * sysLayer.coverage;
    float sysAlpha = sysLayer.coverage;

    vec3 premultiplied = sysPremul + micPremul * (1.0 - sysAlpha);
    float combinedAlpha = sysAlpha + micAlpha * (1.0 - sysAlpha);

    float barX = fract(uv.x * bars);
    float gap = smoothstep(0.45, 0.5, abs(barX - 0.5));
    float spacingMask = mix(1.0, 0.35, gap);
    premultiplied *= spacingMask;
    combinedAlpha *= spacingMask;

    vec3 color = combinedAlpha > 0.0 ? premultiplied / combinedAlpha : vec3(0.0);

    float pulse = 0.03 * sin(ubuf.iTime * 5.5 + barIndex * 0.35);
    color = clamp(color + pulse, 0.0, 1.0);

    fragColor = vec4(color, ubuf.qt_Opacity * combinedAlpha);
}
