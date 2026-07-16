#define Rot(a) mat2(cos(a),-sin(a),sin(a),cos(a))
#define antialiasing(n) n/min(iResolution.y,iResolution.x)
#define S(d) 1.-smoothstep(-1.3,1.3, (d)*iResolution.y )
#define B(p,s) max(abs(p).x-s.x,abs(p).y-s.y)

int pacman[16] = int[](
    1360, 5460, 21824, 21760, 21824, 21909, 5460, 1360,
    1360, 5460, 21844, 21840, 21844, 21909, 5460, 1360
  );

int cat[16] = int[](
    34952, 17476, 21844, 21844, 26997, 33041, 341, 514,
    34976, 17488, 21844, 21844, 26997, 33041, 341, 514
  );

int explosion[24] = int[](
    0, 320, 2000, 7540, 7540, 2000, 320, 0,
    320, 5060, 19825, 63455, 63455, 19825, 5060, 320,
    16385, 12300, 1040, 960, 960, 1040, 12300, 16385
  );

int heart[16] = int[](
    0, 320, 2000, 7540, 30045, 30045, 23925, 5140,
    0, 320, 2000, 7540, 30045, 23925, 5140, 0
  );

float random(vec2 p) {
  return fract(sin(dot(p.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float plus(vec2 p) {
  float d = B(p, vec2(0.15, 0.4));
  float d2 = B(p, vec2(0.4, 0.15));
  return min(d, d2);
}

float animationCircle(vec2 p, float n) {
  float d = abs(length(p) - 0.35) - 0.05;
  float d2 = length(p) - 0.2;
  p *= Rot(radians(30. * iTime * (n * 2.) * ((n < 0.5) ? -1. : 1.)));
  d = max(-(abs(p.x) - 0.1), d);
  d = min(d, d2);
  return d;
}

float animationPlane(vec2 p, float n) {
  float a = radians(30. * iTime * (n * 2.) * ((n < 0.5) ? -1. : 1.));
  float d = dot(p, vec2(cos(a), sin(a)));
  return d;
}

vec3 renderPixels(vec2 p, vec3 col) {
  vec2 cell = p * 30.0;
  vec2 id = floor(cell);
  vec2 gr = fract(cell) - 0.5;

  float gridNum = 9.0;
  float column = mod(id.x, gridNum);
  float row = mod(id.y, gridNum);

  if (column == 8.0 || row == 8.0) {
    if (random(id) < 0.5) {
      gr *= Rot(radians(45.));
    } else {
      gr *= Rot(radians(-45.));
    }
    gr.x = abs(gr.x) - 0.35;
    float d = B(gr, vec2(0.1, 1.));

    return col = mix(col, vec3(0.2), S(d));
  }

  vec2 charCell = id - vec2(column, row);
  float n = random(charCell);
  int charaIndex = int(n * 4.);
  int charIndex = int(mod(iTime * 2., 2.0));
  int irow = int(row);
  int icol = int(column);
  int rowBits = pacman[charIndex * 8 + irow];
  if (charaIndex == 1) {
    rowBits = cat[charIndex * 8 + irow];
  } else if (charaIndex == 2) {
    charIndex = int(mod(iTime * 3., 3.0));
    rowBits = explosion[charIndex * 8 + irow];
  } else if (charaIndex == 3) {
    rowBits = heart[charIndex * 8 + irow];
  }

  int v = (rowBits >> (icol * 2)) & 3;

  vec3 colors[4];
  colors[0] = vec3(0.0);
  colors[1] = vec3(1.0);
  colors[2] = vec3(0.3);
  colors[3] = vec3(0.6);

  n = random(id);

  float d = B(gr, vec2(0.4));
  if (n >= 0.3 && n < 0.6) {
    d = animationCircle(gr, n);
  } else if (n >= 0.6 && n < 0.8) {
    d = plus(gr);
  } else if (n >= 0.8) {
    d = animationPlane(gr, n);
  }

  float d2 = abs(B(gr, vec2(0.47))) - 0.03;

  if (v > 0) {
    if (v == 2) d = B(gr, vec2(0.4));
    d = min(d, d2);
    col = mix(col, colors[v], S(d));
  } else {
    d2 = length(gr) - 0.03;
    col = mix(col, vec3(1.0), S(d2));
  }
  return col;
}

float cubicInOut(float t) {
  return t < 0.5
  ? 4.0 * t * t * t : 0.5 * pow(2.0 * t - 2.0, 3.0) + 1.0;
}

float getTime(float t, float duration) {
  return clamp(t, 0.0, duration) / duration;
}

float getAnimationValue() {
  float easeValue = 0.;
  float frame = mod(iTime, 12.0);
  float time = frame;

  float duration = 1.;
  if (frame >= 5. && frame < 6.) {
    time = getTime(time - 5., duration);
    easeValue = cubicInOut(time);
  } else if (frame >= 6. && frame < 11.) {
    easeValue = 1.;
  } else if (frame >= 11. && frame < 12.) {
    time = getTime(time - 11., duration);
    easeValue = 1.0 - cubicInOut(time);
  }

  return easeValue;
}

float getRotDir() {
  float dir = 1.;
  float frame = mod(iTime, 24.0);
  if (frame >= 12.) dir = -1.;
  return dir;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
  float ease = getAnimationValue();
  p *= 1. - (ease * 0.3);
  p *= Rot(sin(ease) * 0.5 * getRotDir());
  vec3 col = vec3(0.);
  p.y -= iTime * 0.1;
  col = renderPixels(p, col);
  fragColor = vec4(col, 1.0);
}
