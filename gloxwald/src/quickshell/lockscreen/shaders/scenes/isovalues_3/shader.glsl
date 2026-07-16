void mainImage(out vec4 O, vec2 U)
{
  O = texture(iChannel0, U / iResolution.xy);
}
