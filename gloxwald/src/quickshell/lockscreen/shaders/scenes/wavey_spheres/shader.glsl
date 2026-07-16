const float PI = acos(-1.);
const float LAYER_DISTANCE = 5.;
const float SPEED = 0.15;

const vec3 BLUE = vec3(47, 75, 162) / 255.;
const vec3 PINK = vec3(233, 71, 245) / 255.;
const vec3 PURPLE = vec3(128, 63, 224) / 255.;
const vec3 CYAN = vec3(61, 199, 220) / 255.;
const vec3 MAGENTA = vec3(222, 51, 150) / 255.;
const vec3 LIME = vec3(160, 220, 70) / 255.;
const vec3 ORANGE = vec3(245, 140, 60) / 255.;
const vec3 TEAL = vec3(38, 178, 133) / 255.;
const vec3 RED = vec3(220, 50, 50) / 255.;
const vec3 YELLOW = vec3(240, 220, 80) / 255.;
const vec3 VIOLET = vec3(180, 90, 240) / 255.;
const vec3 AQUA = vec3(80, 210, 255) / 255.;
const vec3 FUCHSIA = vec3(245, 80, 220) / 255.;
const vec3 GREEN = vec3(70, 200, 100) / 255.;

const int NUM_COLORS = 14;
const vec3 COLS[NUM_COLORS] = vec3[](
    BLUE,
    PINK,
    PURPLE,
    CYAN,
    MAGENTA,
    LIME,
    ORANGE,
    TEAL,
    RED,
    YELLOW,
    VIOLET,
    AQUA,
    FUCHSIA,
    GREEN
  );

// t within the range [0, 1]
vec3 get_color(float t) {
  float scaledT = t * float(NUM_COLORS - 1);

  float curr = floor(scaledT);
  float next = min(curr + 1., float(NUM_COLORS) - 1.);

  float localT = scaledT - curr;
  return mix(COLS[int(curr)], COLS[int(next)], localT);
}

// https://www.shadertoy.com/view/4djSRW
vec4 hash41(float p)
{
  vec4 p4 = fract(vec4(p) * vec4(.1031, .1030, .0973, .1099));
  p4 += dot(p4, p4.wzxy + 33.33);
  return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

float get_height(vec2 id, float layer) {
  float t = iTime * SPEED;

  vec4 h = hash41(layer) * 1000.;

  float o = 0.;
  o += sin((id.x + h.x) * .2 + t) * .3;
  o += sin((id.y + h.y) * .2 + t) * .3;
  o += sin((-id.x + id.y + h.z) * .3 + t) * .3;
  o += sin((id.x + id.y + h.z) * .3 + t) * .4;
  o += sin((id.x - id.y + h.w) * .8 + t) * .1;

  return o;
}

mat2x2 rotate(float r) {
  return mat2x2(cos(r), -sin(r), sin(r), cos(r));
}

float sdSphere(vec3 p, float r) {
  return length(p) - r;
}

float map(vec3 p) {
  float t = iTime * SPEED;
  const float xz = .3;
  vec3 s = vec3(xz, LAYER_DISTANCE, xz);
  vec3 id = round(p / s);

  float ho = get_height(id.xz, id.y);
  p.y += ho;
  p -= s * id;
  return sdSphere(p, smoothstep(1.3, -1.3, ho) * .03 + .0001);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  float seed = 42.0;
  float t = iTime * SPEED;
  vec3 col = vec3(0.);
  vec2 uv = (2. * gl_FragCoord.xy - iResolution.xy) / iResolution.y;
  uv.y *= -1.;

  float phase = t * .2;
  float y = sin(phase);
  float ny = smoothstep(-1., 1., y);
  vec3 c = get_color(mod((t + seed) / float(NUM_COLORS), 5. * 2. * PI) / (5. * 2. * PI));

  vec3 ro = vec3(0., y * LAYER_DISTANCE * .5, -t);
  vec3 rd = normalize(vec3(uv, -1.));

  rd.xy *= rotate(-ny * PI);
  rd.xz *= rotate(sin(t * .5) * .4);

  float d = 0.;
  for (int i = 0; i < 30; ++i) {
    vec3 p = ro + rd * d;

    float dt = map(p);
    dt = max(dt * (cos(ny * PI * 2.) * .3 + .5), 1e-3);

    col += (.1 / dt) * c;
    d += dt * .8;
  }

  col = tanh(col * .01);

  fragColor = vec4(col, 1.);
}
