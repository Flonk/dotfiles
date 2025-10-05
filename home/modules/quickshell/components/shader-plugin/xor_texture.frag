// Basic animated pattern shader - compatible with GLSL ES
#version 440

precision highp float;

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    vec2 iResolution;
};

// Simple hash function to simulate XOR-like pattern
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void main() {
    // Convert texture coordinates to pixel coordinates
    vec2 fragCoord = qt_TexCoord0 * iResolution;
    
    // Create a grid pattern with animation
    vec2 gridPos = floor(fragCoord / 8.0);
    gridPos.x += floor(iTime * 6.0);
    
    // Generate pattern using hash (simulates XOR visually)
    float pattern = hash(gridPos);
    
    // Animate colors
    float r = pattern;
    float g = hash(gridPos + vec2(iTime * 3.0, 0.0));
    float b = hash(gridPos + vec2(0.0, iTime * 5.0));
    
    fragColor = vec4(r, g, b, qt_Opacity);
}
