void mainImage(out vec4 O, vec2 u)
{
  vec2 R = iResolution.xy,
  U = 5. * (u + u - R) / R.y,
  s = vec2(1, 1.732), // SQRT3
  p1 = U - (floor(U / s) + .5) * s,
  p2 = U - round(U / s) * s,
  p = dot(p1, p1) < dot(p2, p2) ? p1 : p2; // hexagone(U)

  float circles = pow(abs(2. * fract(length(U - p) * .1 - iTime * 0.1) - 1.), 5.);
  float bg = (-p.y * s.y > abs(p.x) ? .1 : p.x < 0. ? .2 : 0.);

  vec3 cCol = mix(vec3(1.0), vec3(1.0, 0.5, 0.0), sk_keypulse_envelope() * 0.1 + sk_load_envelope() * 0.5);
  cCol = mix(cCol, sk_fail_color, sk_fail_envelope());

  O = vec4(cCol * circles + bg, 1.0);
}
