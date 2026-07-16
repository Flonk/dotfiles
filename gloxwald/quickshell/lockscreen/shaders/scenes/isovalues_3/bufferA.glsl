// --- noise from procedural pseudo-Perlin (better but not so nice derivatives) ---------
// ( adapted from IQ )

float noise3(vec3 x) {
  vec3 p = floor(x), f = fract(x);

  f = f * f * (3. - 2. * f); // or smoothstep     // to make derivative continuous at borders

  #define hash3(p)  fract(sin(1e3*dot(p,vec3(1,57,-13.7)))*4375.5453)        // rand

  return mix(mix(mix(hash3(p + vec3(0, 0, 0)), hash3(p + vec3(1, 0, 0)), f.x), // triilinear interp
      mix(hash3(p + vec3(0, 1, 0)), hash3(p + vec3(1, 1, 0)), f.x), f.y),
    mix(mix(hash3(p + vec3(0, 0, 1)), hash3(p + vec3(1, 0, 1)), f.x),
      mix(hash3(p + vec3(0, 1, 1)), hash3(p + vec3(1, 1, 1)), f.x), f.y), f.z);
}

#define noise(x) (noise3(x)+noise3(x+11.5)) / 2. // pseudoperlin improvement from foxes idea

const float SPEED = 0.3;

void mainImage(out vec4 O, vec2 U) // ------------ draw isovalues
{
  vec2 R = iResolution.xy;
  U = (U - 0.5 * R) / (1.0 + 0.003 * sk_attention_envelope()) + 0.5 * R;
  float n = noise(vec3(U * 8. / R.y, .1 * iTime * SPEED)),
  v = sin(6.28 * 10. * n),
  t = iTime * SPEED;

  v = smoothstep(1., 0., .5 * abs(v) / fwidth(v));

  vec3 colA = vec3(0.969, 0.616, 0.000); // #f79d00
  vec3 colB = vec3(0.392, 0.953, 0.549); // #64f38c

  colA = mix(colA, sk_fail_color, sk_fail_envelope());
  vec3 mixCol = mix(colA, colB, n);

  O = mix(exp(-33. / R.y) * texture(iChannel0, (U + vec2(1, sin(t))) / R), // .97
      vec4(mixCol, 1.0),
      v);
}
