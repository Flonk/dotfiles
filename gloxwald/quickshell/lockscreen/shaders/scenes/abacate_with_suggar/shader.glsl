//https://youtu.be/rbebWySZ_xY

#define rot(a) mat2(cos(a + vec4(0, 11, 33, 0)))
#define pi acos(-1.)

const float SPEED = 0.4;

void mainImage(out vec4 o, vec2 u) {
  float t = iTime * SPEED;
  vec2 r = iResolution.xy, U;
  u = 1.4 * (u - r / 2.) / r.y, U = u;
  o = vec4(0);

  u += cos(t * .1 + vec2(0, 11));
  float id = floor(u.x) + floor(u.y) * 2. + 5.;
  u = fract(u) - .5;

  float d, a, e, n = 5.;

  for (float i; i < n; i++)
    a = pi * i / n,
    e =
      cos(t + id) * .15 + .1
        - length(u)
        + cos(
          a
            + id * atan(u.y, u.x)
            - tanh(cos(t + id * 2. + u.y) * 5. + 2.) * pi
        ) * .05,

    d += 8e-5 / (e * e * (3. - 2. * e));

  float j = .5, g, h = length(u);
  vec2 f;
  while (j < 5.)
    f = U * j * 12.,

    f *= rot(
        +t * .1
          + dot(
            cos(U + d * 3.),
            sin(U.yx + d * 2.)
          )
      ) * .5,
    d += abs(dot(sin(f), f / f)) / j * .18,
    j += j;

  o = d / 2. + vec4(4. - h, 4. - h * 1.6, 0, 0) * vec4(.12, .16, 0, 0) - .51;
  o = pow(o, vec4(.45));
  o.a = 1.0;
  o *= 1.0 + 0.1 * clamp(sk_keypulse_envelope() + sk_load_envelope(), 0.0, 1.0);
}
