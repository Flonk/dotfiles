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

// 2018 David A Roberts <https://davidar.io>

// wind flow map

vec2 getVelocity(vec2 uv) {
  vec2 p = uv * MAPRES;
  if (p.x < 1.) p.x = 1.;
  vec2 v = texture(iChannel1, p / iResolution.xy + vec2(0.5, 0.5)).xy;
  if (length(v) > 1.) v = normalize(v);
  return v;
}

vec2 getPosition(vec2 fragCoord) {
  for (int i = -1; i <= 1; i++) {
    for (int j = -1; j <= 1; j++) {
      vec2 uv = (fragCoord + vec2(i, j)) / iResolution.xy;
      vec2 p = texture(iChannel0, fract(uv)).xy;
      if (p == vec2(0)) {
        if (hash13(vec3(fragCoord + vec2(i, j), iFrame)) > 1e-4) continue;
        p = fragCoord + vec2(i, j) + hash21(float(iFrame)) - 0.5; // add particle
      } else if (hash13(vec3(fragCoord + vec2(i, j), iFrame)) < 8e-3) {
        continue; // remove particle
      }
      vec2 v = getVelocity(uv);
      p = p + v;
      p.x = mod(p.x, iResolution.x);
      if (abs(p.x - fragCoord.x) < 0.5 && abs(p.y - fragCoord.y) < 0.5)
        return p;
    }
  }
  return vec2(0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  fragColor.xy = getPosition(fragCoord);
  fragColor.z = 0.9 * texture(iChannel0, fragCoord / iResolution.xy).z;
  if (fragColor.x > 0.) fragColor.z = 1.;
}
