#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec2 origin;
    vec2 screenSize;
    float bandHeight;
    float border;
    float radius;
    float outerRadius;
    float overlayMode;
    vec4 ground;
    vec4 markRect;
};

layout(binding = 1) uniform sampler2D noiseTex;
layout(binding = 2) uniform sampler2D dotsTex;
layout(binding = 3) uniform sampler2D markTex;
layout(binding = 4) uniform sampler2D grainTex;
layout(binding = 5) uniform sampler2D gradientTex;

vec3 toLinear(vec3 c) {
    return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

vec3 toSrgb(vec3 c) {
    c = clamp(c, 0.0, 1.0);
    return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}

vec3 lift(vec3 srgb) {
    vec3 c = toLinear(srgb);
    vec3 lms = vec3(
        0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b,
        0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b,
        0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b);
    lms = pow(max(lms, 0.0), vec3(1.0 / 3.0));
    vec3 lab = vec3(
        0.2104542553 * lms.x + 0.7936177850 * lms.y - 0.0040720468 * lms.z,
        1.9779984951 * lms.x - 2.4285922050 * lms.y + 0.4505937099 * lms.z,
        0.0259040371 * lms.x + 0.7827717662 * lms.y - 0.8086757660 * lms.z);
    lab.x += 0.2 * (1.0 - lab.x);
    lms = vec3(
        lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z,
        lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z,
        lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z);
    lms = lms * lms * lms;
    return toSrgb(vec3(
        4.0767416621 * lms.x - 3.3077115913 * lms.y + 0.2309699292 * lms.z,
        -1.2684380046 * lms.x + 2.6097574011 * lms.y - 0.3413193965 * lms.z,
        -0.0041960863 * lms.x - 0.7034186147 * lms.y + 1.7076147010 * lms.z));
}

vec3 chrome(vec2 p, bool lifted) {
    vec2 uv = (p - screenSize * 0.5) / vec2(3840.0, 2160.0) + 0.5;
    vec3 c = texture(gradientTex, uv).rgb;
    return lifted ? lift(c) : c;
}

vec3 overlay(vec3 b, vec3 s) {
    return mix(2.0 * b * s, 1.0 - 2.0 * (1.0 - b) * (1.0 - s), step(0.5, b));
}

vec3 softLight(vec3 b, vec3 s) {
    vec3 d = mix(((16.0 * b - 12.0) * b + 4.0) * b, sqrt(b), step(0.25, b));
    vec3 dark = b - (1.0 - 2.0 * s) * b * (1.0 - b);
    vec3 light = b + (2.0 * s - 1.0) * (d - b);
    return mix(dark, light, step(0.5, s));
}

vec4 straight(vec4 c) {
    return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : c;
}

void main() {
    vec2 p = origin + qt_TexCoord0 * itemSize;
    vec2 lo = vec2(border, bandHeight);
    vec2 hi = screenSize - vec2(border);
    vec2 extent = (hi - lo) * 0.5;
    vec2 q = abs(p - (lo + extent)) - (extent - radius);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float inner = clamp(0.5 - d, 0.0, 1.0);

    if (inner >= 1.0) {
        if (overlayMode > 0.5) {
            fragColor = vec4(0.0);
            return;
        }
        vec4 grain = straight(texture(grainTex, fract(p / 128.0)));
        fragColor = vec4(mix(ground.rgb, grain.rgb, grain.a), 1.0) * qt_Opacity;
        return;
    }

    vec3 c = chrome(p, false);
    vec4 dots = straight(texture(dotsTex, fract(p / 26.0)));
    c = mix(c, overlay(c, dots.rgb), dots.a);
    vec4 noise = straight(texture(noiseTex, fract(p / 128.0)));
    c = mix(c, softLight(c, noise.rgb), noise.a);

    float ring = clamp(1.5 - d, 0.0, 1.0) - inner;
    if (ring > 0.0)
        c = mix(c, chrome(p, true), ring / max(1.0 - inner, 1e-4));
    if (inner > 0.0 && overlayMode < 0.5) {
        vec4 grain = straight(texture(grainTex, fract(p / 128.0)));
        c = mix(c, mix(ground.rgb, grain.rgb, grain.a), inner);
    }

    if (markRect.z > 0.0) {
        vec2 m = (p - markRect.xy) / markRect.zw;
        if (all(greaterThanEqual(m, vec2(0.0))) && all(lessThanEqual(m, vec2(1.0)))) {
            float r = length(p - markRect.xy - markRect.zw * 0.5);
            float disc = 1.0 - smoothstep(markRect.z * 0.5 - 0.75, markRect.z * 0.5 + 0.25, r);
            float knock = texture(markTex, m).a;
            c = mix(c, vec3(0.0), disc * (1.0 - knock));
        }
    }

    vec2 screenHalf = screenSize * 0.5;
    vec2 so = abs(p - screenHalf) - (screenHalf - outerRadius);
    float outer = length(max(so, 0.0)) + min(max(so.x, so.y), 0.0) - outerRadius;
    c *= clamp(0.5 - outer, 0.0, 1.0);

    float alpha = overlayMode > 0.5 ? 1.0 - inner : 1.0;
    fragColor = vec4(c * alpha, alpha) * qt_Opacity;
}
