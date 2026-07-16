
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

// comment out the following line for original style
//#define PAPER

// uncomment the following line for Mollweide projection
//#define ELLIPTICAL

#ifdef PAPER
#define  LOW_PRESSURE vec3(0.,0.5,1.)
#define HIGH_PRESSURE vec3(1.,0.5,0.)
#else
#define  LOW_PRESSURE vec3(1.,0.5,0.)
#define HIGH_PRESSURE vec3(0.,0.5,1.)
#endif

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  float lat = 180. * fragCoord.y / iResolution.y - 90.;
  #ifdef ELLIPTICAL
  fragCoord.x -= iResolution.x / 2.;
  fragCoord.x /= sqrt(1. - pow(lat / 90., 2.));
  if (abs(fragCoord.x / iResolution.x) > 0.5) return;
  fragCoord.x += iResolution.x / 2.;
  fragCoord.x -= 0.05 * iTime * iResolution.x;
  fragCoord.x -= iMouse.x;
  fragCoord.x = mod(fragCoord.x, iResolution.x);
  #endif
  vec2 p = fragCoord * MAPRES / iResolution.xy;
  if (p.x < 1.) p.x = 1.;
  vec2 uv = p / iResolution.xy;
  float land = texture(iChannel0, uv).x;
  fragColor = vec4(0, 0, 0, 1);
  if (0.25 < land && land < 0.75) fragColor.rgb = vec3(0.5);
  float mbar = texture(iChannel1, uv + PASS3).x;
  if (iMouse.z > 0.) {
    vec3 r = LOW_PRESSURE;
    r = mix(r, vec3(0), smoothstep(1000., 1012., floor(mbar)));
    r = mix(r, HIGH_PRESSURE, smoothstep(1012., 1024., floor(mbar)));
    fragColor.rgb += 0.5 * r;
  } else {
    vec2 v = texture(iChannel1, uv + PASS4).xy;
    float flow = texture(iChannel2, fragCoord / iResolution.xy).z;
    vec3 hue = vec3(1., 0.75, 0.5);
    #ifndef PAPER
    hue = vec3(0.7, 0.8, 1.0);
    #endif
    float alpha = clamp(length(v), 0., 1.) * flow;
    fragColor.rgb = mix(fragColor.rgb, hue, alpha);
  }
  #ifdef PAPER
  fragColor.rgb = 0.9 - 0.8 * fragColor.rgb;
  if (mod(fragCoord.x, floor(iResolution.x / 36.)) < 1. ||
      mod(fragCoord.y, floor(iResolution.y / 18.)) < 1.)
    fragColor.rgb = mix(fragColor.rgb, vec3(0., 0.5, 1.), 0.2);
  #endif
}
