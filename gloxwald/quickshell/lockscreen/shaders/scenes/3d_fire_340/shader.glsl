/*
    "3D Fire" by @XorDev

    I really wanted to see if my turbulence effect worked in 3D.
    I wrote a few 2D variants, but this is my new favorite.
    Read about the technique here:
    https://mini.gmshaders.com/p/turbulence


    See my other 2D examples here:
    https://www.shadertoy.com/view/wffXDr
    https://www.shadertoy.com/view/WXX3RH
    https://www.shadertoy.com/view/tf2SWc

    Thanks!
*/
const float SPEED = 0.05;

vec3 fireColor(float heat, float stoke) {
  vec3 coolNormal = vec3(0.3, 0.0, 0.0); // dark red
  vec3 hotNormal = vec3(1.0, 0.5, 0.1); // bright orange
  vec3 coolStoked = vec3(0.0, 0.1, 0.8); // blue
  vec3 hotStoked = vec3(0.9, 0.95, 1.0); // near white

  vec3 normal = mix(coolNormal, hotNormal, heat);
  vec3 stoked = mix(coolStoked, hotStoked, heat);
  return mix(normal, stoked, stoke);
}

void mainImage(out vec4 O, vec2 I)
{
  float speedScale = 1.;
  float stoke = sk_attention_envelope() * 0.9 + sk_keypulse_envelope() * 0.1;

  //Time for animation
  float t = iTime * SPEED * speedScale,
  //Raymarch loop iterator
  i,
  //Raymarched depth
  z,
  //Raymarch step size and "Turbulence" frequency
  //https://www.shadertoy.com/view/WclSWn
  d;

  //Raymarching loop with 50 iterations
  for (O *= i; i++ < 50.;
    //Add color and glow attenuation
    O += (sin(z / 3. + vec4(7, 2, 3, 0)) + 1.1) / d)
  {
    //Compute raymarch sample point
    vec3 p = z * normalize(vec3(I + I, 0) - iResolution.xyy);
    //Shift back and animate
    p.z += 5. + cos(t);
    //Twist and rotate
    p.xz *= mat2(cos(p.y * .5 + vec4(0, 33, 11, 0)))
        //Expand upward
        / max(p.y * .1 + 1., .1);
    //Turbulence loop (increase frequency)
    for (d = 2.; d < 15.; d /= .6)
      //Add a turbulence wave
      p += cos((p.yzx - vec3(t / .1, t, d)) * d) / d;
    //Sample approximate distance to hollow cone
    float coneRadius = .5 + .15 * stoke;
    z += d = .01 + abs(length(p.xz) + p.y * .3 - coneRadius) / 7.;
  }
  //Tanh tonemapping
  //https://www.shadertoy.com/view/ms3BD7
  O = tanh(O / (1e3 / (1.0 + 0.6 * stoke)));

  // Depth-based heat: close fire (small z) is hotter, remote tips (large z) are cooler.
  float heat = exp(-z * 0.08) * 0.75;
  heat = heat * heat * heat * 20. - 1.;
  float lum = dot(O.rgb, vec3(0.2126, 0.7152, 0.0722));
  O.rgb = fireColor(heat, clamp(stoke, 0.0, 1.0)) * lum;
}
