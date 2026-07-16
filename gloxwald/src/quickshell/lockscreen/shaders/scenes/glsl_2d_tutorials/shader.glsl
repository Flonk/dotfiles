// "GLSL 2D Tutorials" by vug
// Welcome screen (Tutorial 0)

const float SPEED = 0.2;
#define TIME (iTime * SPEED)

#define PI 3.14159265359
#define TWOPI 6.28318530718

float square(vec2 r, vec2 bottomLeft, float side) {
  vec2 p = r - bottomLeft;
  return (p.x > 0.0 && p.x < side && p.y > 0.0 && p.y < side) ? 1.0 : 0.0;
}

float character(vec2 r, vec2 bottomLeft, float charCode, float squareSide) {
  vec2 p = r - bottomLeft;
  float ret = 0.0;
  float num, quotient, remainder, divider;
  float x, y;
  num = charCode;
  for (int i = 0; i < 20; i++) {
    float boxNo = float(19 - i);
    divider = pow(2., boxNo);
    quotient = floor(num / divider);
    remainder = num - quotient * divider;
    num = remainder;

    y = floor(boxNo / 4.0);
    x = boxNo - y * 4.0;
    if (quotient == 1.) {
      ret += square(p, squareSide * vec2(x, y), squareSide);
    }
  }
  return ret;
}

mat2 rot(float th) {
  return mat2(cos(th), -sin(th), sin(th), cos(th));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  float G = 990623.;
  float L = 69919.;
  float S = 991119.;

  float t = TIME;

  vec2 r = (fragCoord.xy - 0.5 * iResolution.xy) / iResolution.y;
  float c = 0.05;
  vec2 pL = (mod(r + vec2(cos(0.3 * t), sin(0.3 * t)), 2.0 * c) - c) / c;
  float circ = 1.0 - smoothstep(0.75, 0.8, length(pL));
  vec2 rG = rot(2. * 3.1415 * smoothstep(0., 1., mod(1.5 * t, 4.0))) * r;
  vec2 rStripes = rot(0.2) * r;

  float xMax = 0.5 * iResolution.x / iResolution.y;
  float letterWidth = 2.0 * xMax * 0.9 / 4.0;
  float side = letterWidth / 4.;
  float space = 2.0 * xMax * 0.1 / 5.0;

  r += 0.001;
  float maskGS = character(r, vec2(-xMax + space, -2.5 * side) + vec2(letterWidth + space, 0.0) * 0.0, G, side);
  float maskG = character(rG, vec2(-xMax + space, -2.5 * side) + vec2(letterWidth + space, 0.0) * 0.0, G, side);
  float maskL1 = character(r, vec2(-xMax + space, -2.5 * side) + vec2(letterWidth + space, 0.0) * 1.0, L, side);
  float maskSS = character(r, vec2(-xMax + space, -2.5 * side) + vec2(letterWidth + space, 0.0) * 2.0, S, side);
  float maskS = character(r, vec2(-xMax + space, -2.5 * side) + vec2(letterWidth + space, 0.0) * 2.0 + vec2(0.01 * sin(2.1 * t), 0.012 * cos(t)), S, side);
  float maskL2 = character(r, vec2(-xMax + space, -2.5 * side) + vec2(letterWidth + space, 0.0) * 3.0, L, side);
  float maskStripes = step(0.25, mod(rStripes.x - 0.5 * t, 0.5));

  float i255 = 0.00392156862;
  vec3 blue = vec3(43., 172., 181.) * i255;
  blue *= 1.0 + 0.1 * clamp(sk_keypulse_envelope() + sk_load_envelope(), 0.0, 1.0);
  blue = mix(blue, sk_fail_color, sk_fail_envelope());
  vec3 pink = vec3(232., 77., 91.) * i255;
  vec3 light = vec3(245., 236., 217.) * i255;
  vec3 green = vec3(180., 204., 18.) * i255;

  vec3 pixel = blue;
  pixel = mix(pixel, light, maskGS);
  pixel = mix(pixel, light, maskSS);
  pixel -= 0.1 * maskStripes;
  pixel = mix(pixel, green, maskG);
  pixel = mix(pixel, pink, maskL1 * circ);
  pixel = mix(pixel, green, maskS);
  pixel = mix(pixel, pink, maskL2 * (1.0 - circ));

  pixel -= smoothstep(0.45, 2.5, length(r));
  fragColor = vec4(pixel, 1.0);
}
