const float SPEED = 0.12;

void mainImage(out vec4 O, vec2 u)
{
  vec2 R = iResolution.xy,
  uv = (u - R / 2.) / R.y;

  float t = iTime * SPEED,
  theta = atan(uv.y, uv.x) / 6.28 + .5,
  dist = log(length(uv) * 6.) * 2. - t + theta,
  cutoff = .3,
  d = fract(dist) - cutoff,
  offset = .314159,
  pVal = theta * (6. - offset) + floor(dist) * offset + t / 4.
      + (d > 0. ? pow(d, 3.) * .75 : -d / 8.
      ),
  val = fract(pVal);

  vec4 colorRed = mix(vec4(.65, 0, 0, 1), vec4(.1, .1, .85, 1), sk_load_envelope());
  vec4 colorBlue = mix(vec4(.1, .1, .85, 1), vec4(.65, 0, 0, 1), sk_fail_envelope());
  O = val < .25 ? vec4(1) : val < .5 ? colorRed : val < .75 ? vec4(1) : colorBlue;

  float mult = d < 0. ? 1. - uv.y : (1. - uv.y / 2.)
      * (1. - d - .3);
  mult = 1.0 - (1.0 - mult) * (1.0 + 0.05 * sk_keypulse_envelope());
  O *= mult;
}
