#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// ---------------------------------------------------------------------------
// Uniform block — Qt maps QML properties to these by name
// ---------------------------------------------------------------------------

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    // Shadertoy-compatible inputs
    float iTime;
    int iFrame;
    int u_indicator_type;

    float u_last_key_time;
    float u_last_failed_unlock_time;
    float u_auth_started_time;
    vec2 u_key_bases;
    int u_dev_mode;
    float u_dev_mode_at;
    float u_dev_gold_at;
    int u_dev_prev_mode;
    float u_dev_prev_at;
    float u_dev_switch_at;
    float u_solid_matte;
    vec2 u_prism_beam;
    vec4 u_prism_ray;
    float u_prism_chunk;

    vec3 iResolution;
    vec3 u_indicator_color;

    vec4 iMouse;
    vec4 iClock;

    // 32 random floats in [0,1), rerolled by the host each time the shader
    // pass is created — read them via sk_seed(i) to vary scenes per session
    mat4 iSeed0;
    mat4 iSeed1;
};

// Up to ten input textures, resolved from QML properties.
layout(binding = 1) uniform sampler2D iChannel0;
layout(binding = 2) uniform sampler2D iChannel1;
layout(binding = 3) uniform sampler2D iChannel2;
layout(binding = 4) uniform sampler2D iChannel3;
layout(binding = 5) uniform sampler2D iChannel4;
layout(binding = 6) uniform sampler2D iChannel5;
layout(binding = 7) uniform sampler2D iChannel6;
layout(binding = 8) uniform sampler2D iChannel7;
layout(binding = 9) uniform sampler2D iChannel8;
layout(binding = 10) uniform sampler2D iChannel9;

// ---------------------------------------------------------------------------
// Shared constants
// ---------------------------------------------------------------------------

/// Canonical fail colour (227, 85, 50) in linear [0, 1] range.
const vec3 sk_fail_color = vec3(227.0 / 255.0, 85.0 / 255.0, 50.0 / 255.0);

// ---------------------------------------------------------------------------
// sk_ — gloxwaldlock standard library
// ---------------------------------------------------------------------------

/// Random float in [0,1) for i in 0..31, fixed for the session.
float sk_seed(int i) {
    mat4 m = i < 16 ? iSeed0 : iSeed1;
    return m[(i >> 2) & 3][i & 3];
}

float sk_ease_out_back(float t) {
    const float c1 = 4.0;
    const float c3 = c1 + 1.0;
    float x = t - 1.0;
    return 1.0 + c3 * x * x * x + c1 * x * x;
}

// _at variants evaluate the envelope at an arbitrary time t (<= iTime;
// there is no future to sample) — for phase-shifted copies of an envelope

float sk_keypulse_envelope_at(float t) {
    float age = t - u_last_key_time;
    float ramp = clamp(age / 0.03, 0.0, 1.0);
    float p = mix(u_key_bases.x, 1.0, ramp);
    float decay = clamp((age - 0.03) / 0.08, 0.0, 1.0);
    return p * (1.0 - decay * decay);
}
float sk_keypulse_envelope() { return sk_keypulse_envelope_at(iTime); }

float sk_key_envelope_at(float t) {
    float age = t - u_last_key_time;
    float ramp = clamp(age / 0.06, 0.0, 1.0);
    float p = mix(u_key_bases.y, 1.0, ramp);
    float decay = clamp((age - 1.06) / 2.0, 0.0, 1.0);
    return p * (1.0 - sk_ease_out_back(pow(decay, 0.65)));
}
float sk_key_envelope() { return sk_key_envelope_at(iTime); }

float sk_fail_envelope_at(float t) {
    float age = t - u_last_failed_unlock_time;
    float p = clamp(age / 0.03, 0.0, 1.0);
    float decay = clamp((age - 0.27) / 2.0, 0.0, 1.0);
    return p * pow(1.0 - decay, 3.0);
}
float sk_fail_envelope() { return sk_fail_envelope_at(iTime); }

float sk_load_envelope_at(float t) {
    float isLoading = step(-999.0, u_auth_started_time);
    float authAge = t - u_auth_started_time;
    float endedAge = t - u_last_failed_unlock_time;
    float loading = isLoading * clamp((authAge - 0.1) / 0.03, 0.0, 1.0);
    float unloading = (1.0 - isLoading) * clamp(1.0 - endedAge / 0.03, 0.0, 1.0);
    return loading + unloading;
}
float sk_load_envelope() { return sk_load_envelope_at(iTime); }

float sk_attention_envelope_at(float t) {
    float kf = sk_key_envelope_at(t) + sk_fail_envelope_at(t);
    float load = sk_load_envelope_at(t);
    kf = max(kf, load - 1.0);
    return min(kf + load, 1.0);
}
float sk_attention_envelope() { return sk_attention_envelope_at(iTime); }

// ---------------------------------------------------------------------------
// Shader body follows (injected by convert-shaders.sh)
// ---------------------------------------------------------------------------
void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 px = 1. / iResolution.xy;
    vec2 uv = vec2(fragCoord.x, iResolution.y - fragCoord.y) * px;
    const vec3 luma = vec3(0.299, 0.587, 0.114);

    vec4 c0 = texture(iChannel0, uv);
    if(c0.a < 0.001){
        fragColor = vec4(c0.rgb, 1.);
        return;
    }
    vec3 cc = c0.rgb;
    float lc = dot(cc, luma);
    float l00 = dot(texture(iChannel0, uv + vec2(-0.5, -0.5) * px).rgb, luma);
    float l10 = dot(texture(iChannel0, uv + vec2( 0.5, -0.5) * px).rgb, luma);
    float l01 = dot(texture(iChannel0, uv + vec2(-0.5,  0.5) * px).rgb, luma);
    float l11 = dot(texture(iChannel0, uv + vec2( 0.5,  0.5) * px).rgb, luma);

    vec2 dir = vec2((l01 + l11) - (l00 + l10), (l00 + l01) - (l10 + l11));
    float reduce = max((l00 + l10 + l01 + l11) * (1. / 32.), 1. / 128.);
    float rcp = 1. / (min(abs(dir.x), abs(dir.y)) + reduce);
    dir = clamp(dir * rcp, -8., 8.) * px;

    vec3 a = 0.5 * (texture(iChannel0, uv - dir / 6.).rgb + texture(iChannel0, uv + dir / 6.).rgb);
    vec3 b = a * 0.5 + 0.25 * (texture(iChannel0, uv - dir * 0.5).rgb + texture(iChannel0, uv + dir * 0.5).rgb);

    float lmin = min(lc, min(min(l00, l10), min(l01, l11)));
    float lmax = max(lc, max(max(l00, l10), max(l01, l11)));
    float lb = dot(b, luma);
    fragColor = vec4(mix(cc, (lb < lmin || lb > lmax) ? a : b, c0.a), 1.);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
