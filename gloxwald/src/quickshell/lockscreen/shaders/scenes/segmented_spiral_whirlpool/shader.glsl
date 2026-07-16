#define T (iTime*.5)

float gWavinessScale = 1.0; // driven by attention envelope in mainImage
#define A(v) mat2(cos(m.v*3.1416 + vec4(0, -1.5708, 1.5708, 0)))       // rotate
#define H(v) (cos(((v)+.5)*6.2832 + radians(vec3(60, 0, -60)))*.5+.5)  // hue

float sdRoundBox(vec3 p, vec3 b, float r)
{
  vec3 q = abs(p) - b + r;
  return length(max(q, 0.)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float map(vec3 u)
{
  float t = T, // speed
  l = 5., // loop to reduce clipping
  w = 40., // z warp size
  s = .4, // object size (max)
  f = 1e20, i = 0., y, z;

  u.yz = -u.zy;
  u.xy = vec2(atan(u.x, u.y), length(u.xy)); // polar transform
  u.x += t / 6.; // counter rotation

  vec3 p;
  for (; i++ < l; )
  {
    p = u;
    y = round(max(p.y - i, 0.) / l) * l + i; // segment y & skip rows
    p.x *= y; // scale x with rounded y
    p.x -= sqrt(y * t * t * 2.); // move x
    p.x -= round(p.x / 6.2832) * 6.2832; // segment x
    p.y -= y; // move y
    p.z += sqrt(y / w) * w; // curve inner z down
    z = cos(y * t / 50.) * .5 + .5; // radial wave
    p.z += z * 2. * gWavinessScale; // wave z
    p = abs(p);
    //f = min(f, max(p.x, max(p.y, p.z)) - s*z);  // cubes
    f = min(f, sdRoundBox(p, vec3(s * z), .1)); // a bit nicer
  }

  return f;
}

void mainImage(out vec4 C, in vec2 U)
{
  float l = 50., // loop
  i = 0., d = i, s, r;

  vec2 R = iResolution.xy,
  m = iMouse.z > 0. ? // clicking?
    (iMouse.xy - R / 2.) / R.y : // mouse coords
    vec2(0, -.17); // default (noclick)

  // Attention: increase waviness by up to 60%.
  gWavinessScale = 1.0 + 0.6 * sk_attention_envelope();

  vec3 o = vec3(0, 20, -120), // camera
  u = normalize(vec3(U - R / 2., R.y)), // 3d coords
  c = vec3(0), p;

  mat2 v = A(y), // pitch
  h = A(x); // yaw

  for (; i++ < l; ) // raymarch
  {
    p = u * d + o;
    p.yz *= v;
    p.xz *= h;

    s = map(p);
    r = (cos(round(length(p.xz)) * T / 50.) * .7 - 1.8) / 2.; // color gradient
    c += min(s, exp(-s / .08)) // black & white
        * H(r + .5) * (r + 2.4); // color

    if (s < 1e-3 || d > 1e3) break;
    d += s * .7;
  }

  // Keypulse: boost cube brightness by 8%.
  c *= 1.0 + 0.08 * sk_keypulse_envelope();
  // Fail: tint cubes toward fail hue.
  c = mix(c, c * sk_fail_color, sk_fail_envelope());

  C = vec4(exp(log(c) / 2.2), 1);
}
