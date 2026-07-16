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

    vec3 iResolution;
    vec3 u_indicator_color;

    vec4 iMouse;
    vec4 iClock;

    // 32 random floats in [0,1), rerolled by the host each time the shader
    // pass is created — read them via sk_seed(i) to vary scenes per session
    mat4 iSeed0;
    mat4 iSeed1;
};

// Up to four input textures, resolved from QML properties.
layout(binding = 1) uniform sampler2D iChannel0;
layout(binding = 2) uniform sampler2D iChannel1;
layout(binding = 3) uniform sampler2D iChannel2;
layout(binding = 4) uniform sampler2D iChannel3;

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
#define MAPRES vec2(144,72)

#define PASS1 vec2(0.0,0.0)
#define PASS2 vec2(0.0,0.5)
#define PASS3 vec2(0.5,0.0)
#define PASS4 vec2(0.5,0.5)

#define N vec2( 0, 1)
#define E vec2( 1, 0)
#define S vec2( 0,-1)
#define W vec2(-1, 0)

#define PI 3.14159265359

// Hash without Sine
// Creative Commons Attribution-ShareAlike 4.0 International Public License
// Created by David Hoskins.

// https://www.shadertoy.com/view/4djSRW
// Trying to find a Hash function that is the same on ALL systens
// and doesn't rely on trigonometry functions that change accuracy
// depending on GPU.
// New one on the left, sine function on the right.
// It appears to be the same speed, but I suppose that depends.

// * Note. It still goes wrong eventually!
// * Try full-screen paused to see details.

#define ITERATIONS 4

// *** Change these to suit your range of random numbers..

// *** Use this for integer stepped ranges, ie Value-Noise/Perlin noise functions.
#define HASHSCALE1 .1031
#define HASHSCALE3 vec3(.1031, .1030, .0973)
#define HASHSCALE4 vec4(.1031, .1030, .0973, .1099)

// For smaller input rangers like audio tick or 0-1 UVs use these...
//#define HASHSCALE1 443.8975
//#define HASHSCALE3 vec3(443.897, 441.423, 437.195)
//#define HASHSCALE4 vec3(443.897, 441.423, 437.195, 444.129)

//----------------------------------------------------------------------------------------
//  1 out, 1 in...
float hash11(float p)
{
  vec3 p3 = fract(vec3(p) * HASHSCALE1);
  p3 += dot(p3, p3.yzx + 19.19);
  return fract((p3.x + p3.y) * p3.z);
}

//----------------------------------------------------------------------------------------
//  1 out, 2 in...
float hash12(vec2 p)
{
  vec3 p3 = fract(vec3(p.xyx) * HASHSCALE1);
  p3 += dot(p3, p3.yzx + 19.19);
  return fract((p3.x + p3.y) * p3.z);
}

//----------------------------------------------------------------------------------------
//  1 out, 3 in...
float hash13(vec3 p3)
{
  p3 = fract(p3 * HASHSCALE1);
  p3 += dot(p3, p3.yzx + 19.19);
  return fract((p3.x + p3.y) * p3.z);
}

//----------------------------------------------------------------------------------------
//  2 out, 1 in...
vec2 hash21(float p)
{
  vec3 p3 = fract(vec3(p) * HASHSCALE3);
  p3 += dot(p3, p3.yzx + 19.19);
  return fract((p3.xx + p3.yz) * p3.zy);
}

//----------------------------------------------------------------------------------------
///  2 out, 2 in...
vec2 hash22(vec2 p)
{
  vec3 p3 = fract(vec3(p.xyx) * HASHSCALE3);
  p3 += dot(p3, p3.yzx + 19.19);
  return fract((p3.xx + p3.yz) * p3.zy);
}

//----------------------------------------------------------------------------------------
///  2 out, 3 in...
vec2 hash23(vec3 p3)
{
  p3 = fract(p3 * HASHSCALE3);
  p3 += dot(p3, p3.yzx + 19.19);
  return fract((p3.xx + p3.yz) * p3.zy);
}

//----------------------------------------------------------------------------------------
//  3 out, 1 in...
vec3 hash31(float p)
{
  vec3 p3 = fract(vec3(p) * HASHSCALE3);
  p3 += dot(p3, p3.yzx + 19.19);
  return fract((p3.xxy + p3.yzz) * p3.zyx);
}

//----------------------------------------------------------------------------------------
///  3 out, 2 in...
vec3 hash32(vec2 p)
{
  vec3 p3 = fract(vec3(p.xyx) * HASHSCALE3);
  p3 += dot(p3, p3.yxz + 19.19);
  return fract((p3.xxy + p3.yzz) * p3.zyx);
}

//----------------------------------------------------------------------------------------
///  3 out, 3 in...
vec3 hash33(vec3 p3)
{
  p3 = fract(p3 * HASHSCALE3);
  p3 += dot(p3, p3.yxz + 19.19);
  return fract((p3.xxy + p3.yxx) * p3.zyx);
}

//----------------------------------------------------------------------------------------
// 4 out, 1 in...
vec4 hash41(float p)
{
  vec4 p4 = fract(vec4(p) * HASHSCALE4);
  p4 += dot(p4, p4.wzxy + 19.19);
  return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

//----------------------------------------------------------------------------------------
// 4 out, 2 in...
vec4 hash42(vec2 p)
{
  vec4 p4 = fract(vec4(p.xyxy) * HASHSCALE4);
  p4 += dot(p4, p4.wzxy + 19.19);
  return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

//----------------------------------------------------------------------------------------
// 4 out, 3 in...
vec4 hash43(vec3 p)
{
  vec4 p4 = fract(vec4(p.xyzx) * HASHSCALE4);
  p4 += dot(p4, p4.wzxy + 19.19);
  return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

//----------------------------------------------------------------------------------------
// 4 out, 4 in...
vec4 hash44(vec4 p4)
{
  p4 = fract(p4 * HASHSCALE4);
  p4 += dot(p4, p4.wzxy + 19.19);
  return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

// 1-bit land/ocean map, 2.5 degree resolution
// auto-generated by https://github.com/rkibria/img2shadertoy
const vec2 bitmap_size = vec2(160, 72);
const int[] palette = int[](0x00000000, 0x00ffffff);
const int[] rle = int[](0x0001ff91, 0x03ff9100, 0xf8000000, 0x0008ff8f, 0xfffc0000, 0xf80fffff, 0x010aff89, 0xfe000000, 0x39ffffff, 0xff88fc3c, 0x0000030a, 0xffffc000, 0xc0003fff, 0x0100ff88, 0x80050084, 0x0000ffbf, 0x00ff87fe, 0x07008607, 0x20000078, 0xf7ffffff, 0x0f00ff83, 0x20000086, 0x20060083, 0xffff8fff, 0x00873fff, 0x00844000, 0x00007004, 0x0089f437, 0x00cd0100, 0x00921800, 0x00920c00, 0x00921c00, 0x008a1c00, 0x00860800, 0x008a3800, 0x00861000, 0x00897800, 0x00870400, 0x0089f800, 0x86400201, 0x01f80100, 0x0f000088, 0xf80b0087, 0x80000003, 0x00000007, 0x871fc3c0, 0x07f80b00, 0x0f800000, 0xc0000000, 0x00871fff, 0x000ff80b, 0x001f8000, 0xffc00000, 0x0b00871f, 0x00001ff0, 0x00001fc0, 0x1fffe000, 0xf00b0087, 0xc000003f, 0x0000063f, 0x870fffe0, 0xfff00b00, 0x3fe00000, 0xc0000004, 0x00870fff, 0x00fff00b, 0x0c3fe000, 0xfe000000, 0x0b008703, 0x0000fffc, 0x000cffe0, 0x027c0000, 0xfe0a0087, 0xe00000ff, 0x000008ff, 0x00883000, 0x01fffe05, 0x8dffe000, 0xffff0500, 0xffe00003, 0xff0b008d, 0xe00003ff, 0x000000ff, 0x87060004, 0xffff0b00, 0xfff00000, 0x02000000, 0x008703c1, 0x0007ff0a, 0x01fff000, 0x31710000, 0xff090088, 0xf000000f, 0x800003ff, 0x09008971, 0x000007fe, 0x0007fff0, 0x00896140, 0x0001fe09, 0x0ffffdf0, 0x88410100, 0xfec00b00, 0xfff80000, 0x80000fff, 0x00870600, 0x0008200a, 0xfffffc00, 0x0200c009, 0x700b0088, 0xfe000000, 0xc007ffff, 0x87010f80, 0x001e0b00, 0xfffc0000, 0x80e01eff, 0x00860107, 0x081bc00b, 0xfffc0000, 0xc3e07e7f, 0x0b008703, 0x000101c0, 0x7ffffe00, 0x07e7f0ff, 0xe00c0087, 0x00000001, 0x7fbffffc, 0x017ff7f8, 0xf00b0086, 0x00000081, 0x8ffffffc, 0x87ffffff, 0x83fc0c00, 0xf0000000, 0xfff7ffff, 0x8601ffff, 0x7ffa0700, 0xf0000000, 0xff83e77f, 0xfe070087, 0x000001ff, 0x83c00fe0, 0x853000ff, 0xff800800, 0x000003ff, 0x83c00f00, 0x85c800ff, 0xffc00e00, 0x000003ff, 0xcffb00f0, 0x043fffff, 0x0d008401, 0x07ffffc0, 0x61f00000, 0xffffcf67, 0x00850fff, 0xffffc00e, 0x8000000f, 0xfff707d7, 0x023fffff, 0xc00d0084, 0x003fffff, 0xafff8000, 0xffffffc3, 0x0900857f, 0x3fffffc0, 0xff800002, 0xff83e7ff, 0xe0070085, 0x03ffffff, 0x85fec000, 0x840100ff, 0xfff00700, 0x0001ff7f, 0xff85f890, 0x0083c000, 0xfff80108, 0x00007e1f, 0xff842840, 0x01c07f0f, 0x07000000, 0x6e03fffe, 0x7c000000, 0x0eff84fc, 0x00000101, 0xffffffc0, 0x00700603, 0x84ee7c00, 0x1f7f0eff, 0xff800000, 0x384fffff, 0xf00380f8, 0x0cff85fe, 0x8700007f, 0x7fffffff, 0x0003f878, 0x0eff87e0, 0xffc00000, 0x1e5c7bff, 0x80003ff8, 0x84df007f, 0x0d0084ff, 0xfc07f63e, 0x0000007f, 0xfffff820, 0x00841fef, 0xfd03c00c, 0x00fffc01, 0x00400000, 0x00875ffe, 0xf0e91204, 0x0083ffff, 0x1fa00302, 0x80060087, 0xfffff3f8, 0x0083f000, 0x00880300, 0xfffff004, 0x00c603ff);

const int rle_len_bytes = rle.length() << 2;

int get_rle_byte(in int byte_index)
{
  int long_val = rle[byte_index >> 2];
  return (long_val >> ((byte_index & 0x03) << 3)) & 0xff;
}

int get_uncompr_byte(in int byte_index)
{
  int rle_index = 0;
  int cur_byte_index = 0;
  while (rle_index < rle_len_bytes)
  {
    int cur_rle_byte = get_rle_byte(rle_index);
    bool is_sequence = int(cur_rle_byte & 0x80) == 0;
    int count = (cur_rle_byte & 0x7f) + 1;

    if (byte_index >= cur_byte_index && byte_index < cur_byte_index + count)
    {
      if (is_sequence)
      {
        return get_rle_byte(rle_index + 1 + (byte_index - cur_byte_index));
      }
      else
      {
        return get_rle_byte(rle_index + 1);
      }
    }
    else
    {
      if (is_sequence)
      {
        rle_index += count + 1;
        cur_byte_index += count;
      }
      else
      {
        rle_index += 2;
        cur_byte_index += count;
      }
    }
  }

  return 0;
}

int getPaletteIndexXY(in ivec2 fetch_pos)
{
  int palette_index = 0;
  if (fetch_pos.x >= 0 && fetch_pos.y >= 0
      && fetch_pos.x < int(bitmap_size.x) && fetch_pos.y < int(bitmap_size.y))
  {
    int uncompr_byte_index = fetch_pos.y * (int(bitmap_size.x) >> 3)
        + (fetch_pos.x >> 3);
    int uncompr_byte = get_uncompr_byte(uncompr_byte_index);

    int bit_index = fetch_pos.x & 0x07;
    palette_index = (uncompr_byte >> bit_index) & 1;
  }
  return palette_index;
}

int getPaletteIndex(in vec2 uv)
{
  int palette_index = 0;
  ivec2 fetch_pos = ivec2(uv * bitmap_size);
  palette_index = getPaletteIndexXY(fetch_pos);
  return palette_index;
}

vec4 getColorFromPalette(in int palette_index)
{
  int int_color = palette[palette_index];
  return vec4(float(int_color & 0xff) / 255.0,
    float((int_color >> 8) & 0xff) / 255.0,
    float((int_color >> 16) & 0xff) / 255.0,
    0);
}

vec4 getBitmapColor(in vec2 uv)
{
  return getColorFromPalette(getPaletteIndex(uv));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  vec2 uv = fragCoord / bitmap_size;
  fragColor = getBitmapColor(uv);
}

// --- Qt entry point ---
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
    fragColor *= qt_Opacity;
}
