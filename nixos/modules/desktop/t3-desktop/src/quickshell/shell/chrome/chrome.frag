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
    vec4 accent;
    float plain;
    vec4 cutout;
    vec4 cutout2;
};

layout(binding = 1) uniform sampler2D noiseTex;
layout(binding = 2) uniform sampler2D dotsTex;
layout(binding = 3) uniform sampler2D markTex;
layout(binding = 4) uniform sampler2D grainTex;
layout(binding = 5) uniform sampler2D gradientTex;
layout(binding = 6) uniform sampler2D logoTex;

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

float mastheadDots(vec2 p) {
    float depth = p.y - bandHeight;
    float fade = 1.0 - clamp(depth / (144.0 * 0.7), 0.0, 1.0);
    if (fade <= 0.0)
        return 0.0;
    const float s = 0.29237170472273677;
    const float k = 0.9563047559630354;
    float cover = 0.0;
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            vec2 q = p + (vec2(float(i), float(j)) + 0.5) / 4.0 - 0.5;
            q = vec2(k * q.x + s * q.y, -s * q.x + k * q.y);
            vec2 cell = mod(q, 2.5) - 1.25;
            cover += step(length(cell), 0.55);
        }
    }
    return cover / 16.0 * fade;
}

float gridDots(vec2 p) {
    const float s = 0.29237170472273677;
    const float k = 0.9563047559630354;
    float cover = 0.0;
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            vec2 q = p + (vec2(float(i), float(j)) + 0.5) / 4.0 - 0.5;
            q = vec2(k * q.x + s * q.y, -s * q.x + k * q.y);
            float r = length(mod(q, 2.5) - 1.25);
            cover += 1.0 - smoothstep(0.4, 0.7, r);
        }
    }
    return cover / 16.0;
}

const float AMP_HEIGHT = 120.0;
const vec3 AMP_DARK = vec3(0.012, 0.013, 0.015);
const float SPOT_BELOW = 60.0;
const float SPOT_RANGE = 700.0;
const float SPOT_CONE = 0.62;
const float SPOT_GROUND = 0.2;
const float SPOT_WALL = 1.0;
const float SPOT_FLOOR = 0.15;
const float AMP_DEPTH = 8.4;

vec2 spotPos() {
    return vec2(screenSize.x * 0.5, screenSize.y + SPOT_BELOW);
}

float spot(vec2 p) {
    vec2 v = p - spotPos();
    float r = length(v);
    float cone = smoothstep(SPOT_CONE, 1.0, -v.y / r);
    return cone / (1.0 + (r / SPOT_RANGE) * (r / SPOT_RANGE));
}

vec2 ampCenter() {
    return vec2(screenSize.x * 0.5, (bandHeight + screenSize.y - border) * 0.5);
}

const vec2 LOGO_TEX = vec2(2048.0, 1024.0);
const float LOGO_TEXELS_HIGH = 814.0;
const float LOGO_RANGE = 24.0;

float ampDist(vec2 p) {
    float px = AMP_HEIGHT / LOGO_TEXELS_HIGH;
    vec2 uv = (p - ampCenter()) / (LOGO_TEX * px) + 0.5;
    vec2 outside = max(abs(uv - 0.5) - 0.5, 0.0) * LOGO_TEX * px;
    float d = (texture(logoTex, clamp(uv, 0.0, 1.0)).r - 0.5) * 2.0 * LOGO_RANGE * px;
    return d + length(outside);
}

vec3 sunkenAmp(vec2 p, vec3 c) {
    float d = ampDist(p);
    if (d > 2.0)
        return c;
    float inside = clamp(0.5 - d, 0.0, 1.0);
    vec2 L = normalize(p - spotPos());
    vec2 e = vec2(0.75, 0.0);
    vec2 n = normalize(vec2(ampDist(p + e.xy) - ampDist(p - e.xy), ampDist(p + e.yx) - ampDist(p - e.yx)) + 1e-6);
    float shadow = 0.0;
    for (int i = 1; i <= 6; i++)
        shadow += smoothstep(-0.75, 0.75, ampDist(p - L * AMP_DEPTH * float(i) / 6.0));
    shadow /= 6.0;
    float wall = exp(d / 1.5) * max(dot(n, L), 0.0);
    float light = spot(p);
    vec3 floor_ = AMP_DARK + accent.rgb * light * (SPOT_FLOOR * (1.0 - shadow) + SPOT_WALL * wall);
    float ring = clamp(0.5 - d, 0.0, 1.0) - clamp(-0.5 - d, 0.0, 1.0);
    floor_ = mix(floor_, lift(floor_), 0.25 * ring / max(inside, 1e-4));
    return mix(c, floor_, inside);
}

float roundUnion(float a, float b, float r) {
    vec2 u = max(vec2(r - a, r - b), vec2(0.0));
    return max(r, min(a, b)) - length(u);
}

float carve(float d, vec2 p, vec4 c) {
    if (c.z <= 0.0)
        return d;
    float reach = radius + 8.0;
    vec2 hc = vec2(c.x + c.z * 0.5, (c.y + c.w) * 0.5);
    vec2 hh = vec2(c.z * 0.5, (c.y + c.w) * 0.5 + reach);
    vec2 hq = abs(p - hc) - hh;
    return roundUnion(d, length(max(hq, 0.0)) + min(max(hq.x, hq.y), 0.0), radius);
}

vec3 groundAt(vec2 p) {
    vec4 grain = straight(texture(grainTex, fract(p / 128.0)));
    vec3 c = mix(ground.rgb + accent.rgb * SPOT_GROUND * spot(p) * (1.0 - plain), grain.rgb, grain.a);
    c = mix(c, vec3(1.0), 0.07 * gridDots(p));
    if (plain < 0.5)
        c = sunkenAmp(p, c);
    return mix(c, accent.rgb, 0.55 * mastheadDots(p));
}

void main() {
    vec2 p = origin + qt_TexCoord0 * itemSize;
    vec2 lo = vec2(border, bandHeight);
    vec2 hi = screenSize - vec2(border);
    vec2 extent = (hi - lo) * 0.5;
    vec2 q = abs(p - (lo + extent)) - (extent - radius);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    d = carve(d, p, cutout);
    d = carve(d, p, cutout2);
    if (cutout.z > 0.0 || cutout2.z > 0.0)
        d = roundUnion(d, p.y, radius);
    float inner = clamp(0.5 - d, 0.0, 1.0);

    if (inner >= 1.0) {
        if (overlayMode > 0.5) {
            fragColor = vec4(0.0);
            return;
        }
        fragColor = vec4(groundAt(p), 1.0) * qt_Opacity;
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
        c = mix(c, groundAt(p), inner);
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
