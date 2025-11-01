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

// RGB to HSV conversion
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// HSV to RGB conversion
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    // Configurable Mandelbrot parameters
    vec2 mbCenter = vec2(-0.7461890198219407, -0.10268168504444519);
    
    // Oscillate zoom between 1.5 and 0.001 using simple sine wave
    // Complete cycle (in and out) every 100 minutes
    float cycleDuration = 100.0 * 60.0;
    float cycleProgress = ubuf.time / cycleDuration;
    
    // Simple sine oscillation: oscillates between 0 and 1
    float oscillation = 0.5 + 0.5 * sin(cycleProgress * 2.0 * 3.14159265);
    
    float baseZoom = mix(1.5, 0.001, oscillation);
    
    float mbZoom = baseZoom;
    
    // Normalize coordinates to center
    vec2 uv = (qt_TexCoord0 * ubuf.resolution) / ubuf.resolution.y;
    vec2 center = vec2(0.5 * ubuf.resolution.x / ubuf.resolution.y, 0.5);
    
    // Apply rotation around center (5 full rotations per zoom cycle)
    vec2 centered = uv - center;
    float angle = cycleProgress * 2.0 * 3.14159265 * 5.0;
    float cosA = cos(angle);
    float sinA = sin(angle);
    vec2 rotated = vec2(
        centered.x * cosA - centered.y * sinA,
        centered.x * sinA + centered.y * cosA
    );
    
    // Mandelbrot zoom and center
    vec2 c = rotated * mbZoom + mbCenter;
    
    // Adaptive max iterations based on zoom level
    // Zoomed out (1.5): fewer iterations needed (less aliasing)
    // Zoomed in (0.001): more iterations needed (more detail)
    const int MAX_ITERATIONS = 1000;
    
    // Calculate adaptive iteration limit based on zoom
    // At zoom=1.5: ~200 iterations, at zoom=0.001: ~800 iterations
    float adaptiveIterLimit = 200.0 + 600.0 * (1.0 - oscillation);
    int actualMaxIter = int(clamp(adaptiveIterLimit, 200.0, float(MAX_ITERATIONS)));
    
    // Calculate target iterations based on zoom (for normalization)
    float targetIterations = 40.0 + 30.0 * log(1.0 / mbZoom);
    targetIterations = clamp(targetIterations, 40.0, float(actualMaxIter));
    
    // Mandelbrot iteration with orbit tracking
    vec2 z = vec2(0.0);
    vec2 dz = vec2(0.0); // Derivative for distance estimation
    int iterations = 0;
    float finalMagnitude = 0.0;  // For smooth coloring
    
    // Orbit properties to track
    float orbitTrapDist = 1e10;  // Min distance to origin
    float finalAngle = 0.0;       // Angle at escape
    float avgDistance = 0.0;      // Average distance during orbit
    float stripeSum = 0.0;        // For stripe coloring
    float maxDist = 0.0;          // Maximum distance reached
    
    for (int i = 0; i < MAX_ITERATIONS; i++) {
        // Early exit if we've reached the adaptive iteration limit
        if (i >= actualMaxIter) {
            iterations = actualMaxIter;
            break;
        }
        
        // z = z² + c
        float zx2 = z.x * z.x;
        float zy2 = z.y * z.y;
        float magnitude = zx2 + zy2;
        
        if (magnitude > 4.0) {
            iterations = i;
            finalMagnitude = magnitude;
            finalAngle = atan(z.y, z.x);
            break;
        }
        
        // Track orbit properties
        float dist = sqrt(magnitude);
        orbitTrapDist = min(orbitTrapDist, dist);
        maxDist = max(maxDist, dist);
        avgDistance += dist;
        
        // Stripe coloring (track sign changes)
        stripeSum += 0.5 + 0.5 * sin(z.y * 3.14159265);
        
        // Update derivative: dz = 2*z*dz + 1
        dz = 2.0 * vec2(z.x * dz.x - z.y * dz.y, z.x * dz.y + z.y * dz.x) + vec2(1.0, 0.0);
        
        // Pure Mandelbrot iteration
        z = vec2(zx2 - zy2, 2.0 * z.x * z.y) + c;
        iterations = i + 1;
    }
    
    avgDistance /= float(iterations + 1);
    
    // Smooth iteration count using continuous escape time
    float smoothIter = float(iterations);
    if (iterations < actualMaxIter && finalMagnitude > 0.0) {
        // Add fractional part for smooth coloring
        smoothIter = float(iterations) + 1.0 - log(log(finalMagnitude)) / log(2.0);
    }
    
    // Normalize iteration count against target
    float t = smoothIter / targetIterations;
    
    if (iterations >= actualMaxIter) {
        // Inside the set - audio visualization based purely on angle
        
        // Calculate angle to final orbit position
        float angle = atan(z.y, z.x);
        
        // Make angle repeat more frequently as we zoom in
        // This creates more detailed patterns at deeper zoom levels
        float angleFrequency = 1.0 / mbZoom; // Higher zoom = more repetitions
        float normalizedAngle = fract(angle / (2.0 * 3.14159265) * angleFrequency);
        
        // Sample audio based on angle
        float audioAtAngle = sampleAudio(clamp(normalizedAngle, 0.0, 1.0));
        
        // Brightness controlled purely by audio
        float brightness = mix(0.2, 1.0, audioAtAngle);
        
        // Color based on angle
        vec4 interiorColor = mix(ubuf.accentColorA, ubuf.accentColorB, normalizedAngle);
        interiorColor.rgb *= brightness;
        interiorColor.rgb *= brightness;
        
        fragColor = interiorColor;
    } else {
        // Normalize orbit properties
        float normAngle = (finalAngle + 3.14159265) / (2.0 * 3.14159265);
        float normTrap = clamp(orbitTrapDist / 2.0, 0.0, 1.0);
        float normStripe = fract(stripeSum * 0.1);
        float normAvgDist = clamp(avgDistance / 2.0, 0.0, 1.0);
        
        // Sample different audio frequencies for different orbit properties
        float audioAngle = sampleAudio(clamp(normAngle, 0.0, 1.0));
        float audioTrap = sampleAudio(clamp(normTrap, 0.0, 1.0));
        float audioStripe = sampleAudio(clamp(normStripe, 0.0, 1.0));
        float audioAvg = sampleAudio(clamp(normAvgDist, 0.0, 1.0));
        
        // Combine orbit properties for base color
        float colorMix1 = mix(normAngle, normTrap, 0.5);
        float colorMix2 = mix(normStripe, t, 0.5);
        
        // Multi-dimensional color mixing
        vec4 color1 = mix(ubuf.accentColorA, ubuf.accentColorB, colorMix1);
        vec4 color2 = mix(ubuf.accentColorB, ubuf.accentColorA, colorMix2);
        vec4 baseColor = mix(color1, color2, normAvgDist);
        
        // Audio modulation - INVERTED: audio darkens instead of brightens
        // Combine audio samples
        float audioLevel = audioAngle * 0.3 + audioTrap * 0.3 + audioStripe * 0.2 + audioAvg * 0.2;
        // Invert: high audio = darker (0.5-0.7 range), low audio = brighter (1.0)
        float audioMod = mix(1.0, 0.5, audioLevel);
        
        // Brightness falloff based on iteration count (darker near boundary)
        // At low iterations: brightness = 1.0, at max iterations: brightness = 0.7
        float brightnessFalloff = mix(1.0, 0.01, t);
        
        // Convert to HSV for hue shift
        vec3 hsv = rgb2hsv(baseColor.rgb);
        
        // Apply hue shift based on iteration count AND time
        // Higher iterations (closer to boundary) shift hue more
        float iterationHueShift = t * 0.3; // Shift up to 30% of the hue wheel
        
        // Time-based hue shift - full rotation every 30 seconds
        float timeHueShift = fract(ubuf.time / (100.0 * 30.0));
        
        // Combine both hue shifts
        hsv.x = fract(hsv.x + iterationHueShift + timeHueShift);
        
        // Apply brightness modulation
        hsv.z *= audioMod * brightnessFalloff;
        
        // Apply saturation boost based on orbit trap
        hsv.y = mix(hsv.y, hsv.y * normTrap * 2.0, audioTrap * 0.3);
        
        // Convert back to RGB
        vec3 finalColor = hsv2rgb(hsv);
        
        fragColor = vec4(finalColor, 1.0);
    }
    
    fragColor *= ubuf.qt_Opacity;
}
