// Cava music visualizer shader - continuous line renderer
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

vec2 sampleAudio(float coord) {
    float bars = max(1.0, ubuf.iBarCount);
    if (bars <= 1.0) {
        vec4 s = texture(iDataTexture, vec2(0.5, 0.5));
        return s.rg;
    }

    float position = clamp(coord, 0.0, 0.9999) * (bars - 1.0);
    float baseIndex = floor(position);
    float nextIndex = min(baseIndex + 1.0, bars - 1.0);
    float t = position - baseIndex;

    float baseCoord = (baseIndex + 0.5) / bars;
    float nextCoord = (nextIndex + 0.5) / bars;

    vec4 baseSample = texture(iDataTexture, vec2(baseCoord, 0.5));
    vec4 nextSample = texture(iDataTexture, vec2(nextCoord, 0.5));

    return mix(baseSample.rg, nextSample.rg, t);
}

float bandCoverage(float y, float upper, float lower, float softness) {
    float enter = smoothstep(upper - softness, upper + softness, y);
    float exit = smoothstep(lower - softness, lower + softness, y);
    return clamp(enter - exit, 0.0, 1.0);
}

LayerSample renderLayer(float value, float anchor, vec4 lowColor, vec4 highColor, float uvY) {
    LayerSample layer;
    layer.color = vec3(0.0);
    layer.coverage = 0.0;

    value = clamp(value, 0.0, 1.0);
    vec3 baseColor = mix(lowColor.rgb, highColor.rgb, value);
    float pixelHeight = 1.0 / max(ubuf.iResolution.y, 1.0);
    float minSpan = pixelHeight;

    float topY;
    float bottomY;

    if (anchor > 1.5) {
        float halfSpan = max(value * 0.5, minSpan * 0.5);
        float center = 0.5;
        topY = clamp(center - halfSpan, 0.0, 1.0);
        bottomY = clamp(center + halfSpan, 0.0, 1.0);
    } else if (anchor > 0.5) {
        float span = max(value, minSpan);
        topY = 0.0;
        bottomY = clamp(span, 0.0, 1.0);
    } else {
        float span = max(value, minSpan);
        topY = clamp(1.0 - span, 0.0, 1.0);
        bottomY = 1.0;
    }

    float upper = min(topY, bottomY);
    float lower = max(topY, bottomY);
    float span = max(lower - upper, minSpan);
    float baseSoftness = pixelHeight * 0.75;
    float adaptiveSoftness = max(baseSoftness, fwidth(uvY));
    float maxSoftness = span * 0.45;
    float softness = clamp(adaptiveSoftness, pixelHeight * 0.25, maxSoftness);

    float coverageCenter = bandCoverage(uvY, upper, lower, softness);
    float offset = pixelHeight * 0.5;
    float coverageUp = bandCoverage(clamp(uvY - offset, 0.0, 1.0), upper, lower, softness);
    float coverageDown = bandCoverage(clamp(uvY + offset, 0.0, 1.0), upper, lower, softness);
    float coverage = (coverageCenter + coverageUp + coverageDown) / 3.0;
    coverage = clamp(coverage, 0.0, 1.0);

    layer.coverage = coverage;
    layer.color = baseColor * coverage;
    return layer;
}

void main() {
    vec2 uv = qt_TexCoord0;

    vec2 samples = sampleAudio(uv.x);
    float systemValue = samples.x;
    float microphoneValue = samples.y;

    LayerSample micLayer = renderLayer(microphoneValue, ubuf.iMicrophoneAnchor, ubuf.microphoneColorLow, ubuf.microphoneColorHigh, uv.y);
    LayerSample sysLayer = renderLayer(systemValue, ubuf.iSystemAnchor, ubuf.systemColorLow, ubuf.systemColorHigh, uv.y);

    vec3 sysPremul = sysLayer.color;
    float sysAlpha = sysLayer.coverage;

    vec3 micPremul = micLayer.color;
    float micAlpha = micLayer.coverage;

    vec3 premultiplied = sysPremul + micPremul * (1.0 - sysAlpha);
    float combinedAlpha = sysAlpha + micAlpha * (1.0 - sysAlpha);

    vec3 color = combinedAlpha > 0.0 ? premultiplied / combinedAlpha : vec3(0.0);

    fragColor = vec4(color, ubuf.qt_Opacity * combinedAlpha);
}
