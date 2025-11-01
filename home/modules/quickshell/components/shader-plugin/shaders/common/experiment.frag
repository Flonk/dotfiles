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

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    vec2 uv = (qt_TexCoord0 * ubuf.resolution) / ubuf.resolution.y;
    vec2 center = vec2(0.5 * ubuf.resolution.x / ubuf.resolution.y, 0.5);
    vec2 pos = (uv - center) * 2.0;
    
    float t = ubuf.time * 0.001;
    
    // Popcorn coordinate transform
    // V17(x, y) = (x + c sin(tan 3y), y + f sin(tan 3x))
    // The "3" parameter varies slowly with time
    float popcornParam = 3.0 + 5 * sin(t * 0.2);
    float c = 0.05;
    float f = 0.05;
    
    vec2 popcornPos;
    popcornPos.x = pos.x + c * sin(tan(popcornParam * pos.y));
    popcornPos.y = pos.y + f * sin(tan(popcornParam * pos.x));
    
    pos = popcornPos;
    
    float avgLoudness = 0.0;
    for (int i = 0; i < 10; i++) {
        avgLoudness += sampleAudio(float(i) / 10.0);
    }
    avgLoudness /= 10.0;
    
    vec2 juliaC = vec2(
        0.7885 * cos(t * 0.5),
        0.7885 * sin(t * 0.5)
    );
    
    vec2 tilePos = fract(pos * 3.0) - 0.5;
    tilePos *= 1.5;
    
    vec2 z = tilePos;
    int iterations = 0;
    const int MAX_ITER = 100;
    
    for (int i = 0; i < MAX_ITER; i++) {
        float zx2 = z.x * z.x;
        float zy2 = z.y * z.y;
        
        if (zx2 + zy2 > 4.0) {
            iterations = i;
            break;
        }
        
        z = vec2(zx2 - zy2, 2.0 * z.x * z.y) + juliaC;
    }
    
    float t_julia = float(iterations) / float(MAX_ITER);
    float hue = avgLoudness;
    float saturation = 0.6;
    float value = t_julia;
    
    vec3 backgroundColor = hsv2rgb(vec3(hue, saturation, value));
    
    float radius = length(pos);
    float angle = atan(pos.y, pos.x);
    
    // Store original angle for audio sampling (before rotation)
    float originalAngle = angle;
    
    // Add rotation over time
    float rotationSpeed = 9; // Radians per second
    angle += mod(t * rotationSpeed, 1.0) * 2.0 * 3.14159265;
    
    // Archimedean spiral that repeats: r = a * theta
    float spiralTightness = 0.05;
    
    // For a given radius and angle, find distance to nearest spiral arm
    // The spiral equation is: r = spiralTightness * theta
    // So theta = r / spiralTightness
    // But we need to account for the 2*PI periodicity
    
    // Calculate which "arm" of the spiral we're closest to
    float thetaForRadius = radius / spiralTightness;
    float currentTheta = angle;
    if (currentTheta < 0.0) currentTheta += 2.0 * 3.14159265;
    
    // Find the nearest spiral arm by checking multiple rotations
    float minDist = 1e10;
    for (int n = -5; n <= 5; n++) {
        float spiralTheta = currentTheta + float(n) * 2.0 * 3.14159265;
        float spiralR = spiralTightness * spiralTheta;
        minDist = min(minDist, abs(radius - spiralR));
    }
    
    float distToSpiral = minDist;
    
    // Sample audio spectrum based on ORIGINAL angle (before rotation) so visualizer stays fixed
    float audioPos = mod(originalAngle / (2.0 * 3.14159265), 1.0);
    float audioLevel = sampleAudio(clamp(audioPos, 0.0, 1.0));
    
    float thickness = 0.02 + 0.18 * audioLevel;
    
    float spiralMask = smoothstep(thickness, thickness * 0.9, distToSpiral);
    
    // Spiral color: orange base, mixed more towards white with higher audio
    vec3 orangeColor = vec3(1.0, 0.5, 0.0);
    vec3 whiteColor = vec3(1.0, 1.0, 1.0);
    vec3 spiralColor = mix(orangeColor, whiteColor, audioLevel * 0.5);
    
    // Opacity varies from 0.4 (low audio) to 1.0 (high audio)
    float spiralOpacity = mix(0.4, 1.0, audioLevel);
    
    vec3 finalColor = mix(backgroundColor, spiralColor, spiralMask * spiralOpacity);
    
    fragColor = vec4(finalColor, 1.0) * ubuf.qt_Opacity;
}
