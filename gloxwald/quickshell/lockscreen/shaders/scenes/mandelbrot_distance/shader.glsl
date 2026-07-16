// Copyright Inigo Quilez, 2013 - https://iquilezles.org/
// I am the sole copyright owner of this Work.
// You cannot host, display, distribute or share this Work neither
// as it is or altered, here on Shadertoy or anywhere else, in any
// form including physical and digital. You cannot use this Work in any
// commercial or non-commercial product, website or project. You cannot
// sell this Work and you cannot mint an NFTs of it or train a neural
// network with it without permission. I share this Work for educational
// purposes, and you can link to it, through an URL, proper attribution
// and unmodified screenshot, as part of your educational material. If
// these conditions are too restrictive please contact me and we'll
// definitely work it out.

const float SPEED = 0.2;

// This shader computes the distance to the Mandelbrot Set for everypixel, and colorizes
// it accordingly.
//
// Z -> Z²+c, Z0 = 0.
// therefore Z' -> 2·Z·Z' + 1
//
// The Hubbard-Douady potential G(c) is G(c) = log Z/2^n
// G'(c) = Z'/Z/2^n
//
// So the distance is |G(c)|/|G'(c)| = |Z|·log|Z|/|Z'|
//
// More info:
// https://iquilezles.org/articles/distancefractals

float distanceToMandelbrot(in vec2 c)
{
  // iterate
  float di = 1.0;
  vec2 z = vec2(0.0);
  float m2 = 0.0;
  vec2 dz = vec2(0.0);
  for (int i = 0; i < 300; i++)
  {
    if (m2 > 1024.0) {
      di = 0.0;
      break;
    }

    // Z' -> 2·Z·Z' + 1
    dz = 2.0 * vec2(z.x * dz.x - z.y * dz.y, z.x * dz.y + z.y * dz.x) + vec2(1.0, 0.0);

    // Z -> Z² + c
    z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;

    m2 = dot(z, z);
  }

  // distance
  // d(c) = |Z|·log|Z|/|Z'|
  float d = 0.5 * sqrt(dot(z, z) / dot(dz, dz)) * log(dot(z, z));
  //if( di>0.5 ) d=0.0;

  return d;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  vec2 p = (2.0 * fragCoord - iResolution.xy) / iResolution.y;

  // animation
  float tz = 0.5 - 0.5 * cos(0.225 * iTime * SPEED);
  float zoo = pow(0.5, 13.0 * tz);
  vec2 c = vec2(-0.05, .6805) + p * zoo;

  // distance to Mandelbrot
  float d = distanceToMandelbrot(c);

  // do some soft coloring based on distance
  d = clamp(pow(4.0 * d / zoo, 0.2), 0.0, 1.0);
  //d =pow(d,.1);
  //d = 1.0-1.0/(1.0+1000.0*d);

  vec3 col = vec3(d);

  col *= 1.0 + 0.1 * sk_keypulse_envelope();
  col = mix(col, col * vec3(1.0, 0.5, 0.0), sk_load_envelope());
  col = mix(col, col * sk_fail_color, sk_fail_envelope());

  fragColor = vec4(col, 1.0);
}
