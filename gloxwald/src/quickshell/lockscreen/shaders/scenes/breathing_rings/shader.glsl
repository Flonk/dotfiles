float InPattern(vec2 coord)
{
  float repeatOnY = 5.;

  // We expand the space along y axis from 0..1 to 0..repeatOnY (increase density)
  // then fract abstracts away the point's relation to the origin
  // now two points (0.5,2.5) and (1.5,3.5) are the same (0.5, 0.5)
  vec2 local = fract(coord * repeatOnY);

  vec2 d = local - .5; // 0.5 being the local center
  float loadZoom = max(0.0, iTime - u_auth_started_time) * 1.5 * sk_load_envelope();
  float dist = length(d) / (1.0 + sk_keypulse_envelope() * 0.3 + loadZoom);
  float time = iTime * 0.3;
  float speed = 1.2;
  float maxRingCount = 3.;
  float thickness = 1.; // More like thin-ness
  float padding = thickness;

  // Multiplying the input of the sin function by a scaler increases the frequency of the wave
  // Then we add one to offset the range from -1..1 to 0..2 to avoid negatives
  // Then we multiply this by a scaler that increases the density of local space (or dist specifically)
  // In the end we add some padding to offset threshold range so discs don't cover the entire screen
  float threshold = (maxRingCount * (1. + sin(time * speed))) + padding;

  // Multiplying threshold scales dist over a larger range
  // Which we then normalize/abstract to get multiple bands
  // of value in range 0..1
  float ringPattern = sin(dist * threshold * 6.2831) + 1.;

  // Values between 0..thickness are made negative,
  // now we have signed distances
  return ringPattern - thickness;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  // The coordinate range
  // along y axis is shrunk to range 0..1
  // along x axis is shrunk to range 0..some multiple of iRes.y
  // basically preserving aspect ratio by using y as reference
  vec2 uv = fragCoord / iResolution.y;

  // Get the signed distance
  float d = InPattern(uv);

  // Get a value in range 0..1 based on
  // how far d is from the edge (as a factor of derivative of d)
  // i.e. input to smoothstep is closer to 0 near the edge
  // and smoothstep smoothly clamps that into 0..1 range
  float t = smoothstep(-1., 1., d / fwidth(d));

  // Mix the two color based on the factor
  vec3 color1 = vec3(1.0, 0.7, 0.2);
  vec3 color2 = vec3(1.0, 1.0, 1.0);

  vec3 finalColor = mix(color1, color2, t);
  finalColor = mix(finalColor, sk_fail_color, sk_fail_envelope() * 0.8);

  fragColor = vec4(finalColor, 1.0);
}
