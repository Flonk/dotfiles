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
    vec4 backgroundColor;
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

float dotPattern(vec2 uv, float thickness, float yMirror) {
    float dotSpacing = thickness * 2.5;
    float dotSpeed = 0.03;
    
    // Calculate aspect ratio
    float aspectRatio = ubuf.iResolution.x / max(ubuf.iResolution.y, 1.0);
    
    vec2 dotCoord = vec2(uv.x * aspectRatio, uv.y);
    // Diagonal movement
    float timeOffset = ubuf.iTime * dotSpeed;
    dotCoord.x -= timeOffset * aspectRatio;
    dotCoord.y -= timeOffset * 5.0 * yMirror; // Apply Y mirror
    
    // Create staggered grid (brick pattern)
    vec2 gridPos = dotCoord / dotSpacing;
    float row = floor(gridPos.y);
    float xOffset = mod(row, 2.0) * 0.5;
    gridPos.x += xOffset;
    
    vec2 cellCenter = (floor(gridPos) + 0.5) * dotSpacing;
    cellCenter.x -= xOffset * dotSpacing;
    
    // Distance to nearest dot center
    float distToDot = length(dotCoord - cellCenter);
    float dotRadius = thickness * 1.2;
    return 1.0 - smoothstep(dotRadius * 0.6, dotRadius, distToDot);
}

LayerSample renderLayer(float value, float anchor, vec4 lowColor, vec4 highColor, float uvY) {
    LayerSample layer;
    layer.color = vec3(0.0);
    layer.coverage = 0.0;

    value = clamp(value, 0.0, 1.0);
    vec3 baseColor = mix(lowColor.rgb, highColor.rgb, value);
    float pixelHeight = 1.0 / max(ubuf.iResolution.y, 1.0);
    float minSpan = pixelHeight;

    if (anchor > 1.5) {
        float halfSpan = max(value * 0.5, minSpan * 0.5);
        float center = 0.5;
        float topY = clamp(center - halfSpan, 0.0, 1.0);
        float bottomY = clamp(center + halfSpan, 0.0, 1.0);

        // Render as two lines instead of filled area
        float thickness = max(pixelHeight * 1.5, 0.0015);
        float inner = thickness * 0.4;
        float outer = thickness;

        // Top line
        float distTop = abs(uvY - topY);
        float coverageTop = 1.0 - smoothstep(inner, outer, distTop);

        // Bottom line
        float distBottom = abs(uvY - bottomY);
        float coverageBottom = 1.0 - smoothstep(inner, outer, distBottom);

        // Combine both lines
        float lineCoverage = clamp(coverageTop + coverageBottom, 0.0, 1.0);

        // Fill area between lines with dots
        float upper = min(topY, bottomY);
        float lower = max(topY, bottomY);
        float fillSoftness = pixelHeight * 0.5;
        float fillCoverage = bandCoverage(uvY, upper, lower, fillSoftness);
        
        float dots = dotPattern(qt_TexCoord0, thickness, 1.0); // Normal Y movement
        
        // Mix background color with dot color
        vec3 fillColor = mix(ubuf.backgroundColor.rgb, baseColor, dots * 0.5);
        
        // Fill where there's no line
        float fillOnly = fillCoverage * (1.0 - lineCoverage);

        layer.coverage = clamp(lineCoverage + fillOnly, 0.0, 1.0);
        layer.color = mix(fillColor, baseColor, lineCoverage / max(layer.coverage, 0.0001));
        return layer;
    }

    float targetY = anchor > 0.5 ? clamp(value, 0.0, 1.0) : clamp(1.0 - value, 0.0, 1.0);
    float thickness = max(pixelHeight * 1.5, 0.0015);
    float inner = thickness * 0.4;
    float outer = thickness;

    float dist = abs(uvY - targetY);
    float lineCoverage = 1.0 - smoothstep(inner, outer, dist);
    
    // Add dots fill for bottom/top anchored (microphone)
    float fillWidth = thickness * 2.0;
    float fillDist = anchor > 0.5 ? (uvY - targetY) : (targetY - uvY);
    float fillCoverage = smoothstep(0.0, fillWidth, fillDist) * (1.0 - lineCoverage);
    
    float dots = dotPattern(qt_TexCoord0, thickness, -1.0); // Mirrored Y movement
    vec3 fillColor = mix(ubuf.backgroundColor.rgb, baseColor, dots * 0.5);

    layer.coverage = clamp(lineCoverage + fillCoverage, 0.0, 1.0);
    layer.color = mix(fillColor, baseColor, lineCoverage / max(layer.coverage, 0.0001));
    return layer;
}

vec3 evaluateLayers(float sampleX, float uvY) {
    vec2 samples = sampleAudio(sampleX);
    float systemValue = samples.x;
    float microphoneValue = samples.y;

    LayerSample micLayer = renderLayer(microphoneValue, ubuf.iMicrophoneAnchor, ubuf.microphoneColorLow, ubuf.microphoneColorHigh, uvY);
    LayerSample sysLayer = renderLayer(systemValue, ubuf.iSystemAnchor, ubuf.systemColorLow, ubuf.systemColorHigh, uvY);

    vec3 color = ubuf.backgroundColor.rgb;
    color = mix(color, micLayer.color, micLayer.coverage);
    color = mix(color, sysLayer.color, sysLayer.coverage);
    return clamp(color, 0.0, 1.0);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec3 color = evaluateLayers(uv.x, uv.y);
    fragColor = vec4(color, ubuf.qt_Opacity);
}
