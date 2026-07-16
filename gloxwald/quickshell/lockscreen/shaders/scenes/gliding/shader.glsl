// SPDX-License-Identifier: CC-BY-NC-SA-4.0
// Copyright (c) 2026 @Frostbyte
//[LICENSE] https://creativecommons.org/licenses/by-nc-sa/4.0/

//Super Golfed Version: https://fragcoord.xyz/s/gop7fy59

const float SPEED = 0.1;

void mainImage(out vec4 O, vec2 C) {
  float i, d, z, T = iTime * SPEED;
  vec3 p = iResolution, q, L = normalize(vec3(C - .5 * p.xy, p.y));
  for (O *= i; i++ < 1e2; ) {
    p = z * L;
    p = vec3(mat2(cos(p.z * .1 - vec4(0, 11, 33, 0))) * p.xy, p.z + T);
    float scale = 1.0 + 0.1 * sk_attention_envelope() + 0.05 * sk_keypulse_envelope();
    q = (abs(fract(p) - .5) - .5) / scale;
    d = (abs(length(max(q, .4)) + max(q.x, max(q.y, q.z)) - .4) + abs(sin(length(p.xy) + p.z - T * .5) * .4) * .01) * scale + .0001;
    z += d * .5;
    O += 4. / d;
  }
  vec3 tint = mix(vec3(1., 1., 3.) / 4e5, sk_fail_color / 1.5e5, sk_fail_envelope());
  O *= vec4(tint, 0.);
}
