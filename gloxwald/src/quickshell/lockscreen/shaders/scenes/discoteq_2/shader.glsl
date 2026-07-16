#define S smoothstep

const float SPEED = 0.1;

vec4 Line(vec2 uv, float speed, float height, vec3 col) {
  uv.y += S(1., 0., abs(uv.x)) * sin(iTime * SPEED * speed + uv.x * height) * .2 * (1.0 + sk_attention_envelope() * 0.4);
  return vec4(S(.06 * S(.2, .9, abs(uv.x)), 0., abs(uv.y) - .004) * col, 1.0) * S(1., .3, abs(uv.x));
}

void mainImage(out vec4 O, in vec2 I) {
  vec2 uv = (I - .5 * iResolution.xy) / iResolution.y;
  O = vec4(0.);
  float attention = sk_attention_envelope();
  for (float i = 0.; i <= 5.; i += 1.) {
    float t = i / 5.;
    vec3 c = vec3(.2 + t * .7, .2 + t * .4, 0.3);
    float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = mix(vec3(lum), c, 1.0 + 0.2 * attention);
    c = mix(c, sk_fail_color, sk_fail_envelope());
    O += Line(uv, 1. + t, 4. + t, c);
  }
}
