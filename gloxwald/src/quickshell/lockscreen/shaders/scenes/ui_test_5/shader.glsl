#define MAX_STEPS 64
#define Rot(a) mat2(cos(a),-sin(a),sin(a),cos(a))
#define antialiasing(n) n/min(iResolution.y,iResolution.x)
#define S(d,b) smoothstep(antialiasing(1.0),b,d)
#define B(p,s) max(abs(p).x-s.x,abs(p).y-s.y)
#define Tri(p,s,a) max(-dot(p,vec2(cos(-a),sin(-a))),max(dot(p,vec2(cos(a),sin(a))),max(abs(p).x-s.x,abs(p).y-s.y)))
#define DF(a,b) length(a) * cos( mod( atan(a.y,a.x)+6.28/(b*8.0), 6.28/((b*8.0)*0.5))+(b-1.)*6.28/(b*8.0) + vec2(0,11) )
#define Skew(a,b) mat2(1.0,tan(a),tan(b),1.0)
#define SkewX(a) mat2(1.0,tan(a),0.0,1.0)
#define SkewY(a) mat2(1.0,0.0,tan(a),1.0)
#define seg_0 0
#define seg_1 1
#define seg_2 2
#define seg_3 3
#define seg_4 4
#define seg_5 5
#define seg_6 6
#define seg_7 7
#define seg_8 8
#define seg_9 9
#define seg_DP 39

const float SPEED = 0.15;

float Hash21(vec2 p) {
  p = fract(p * vec2(234.56, 789.34));
  p += dot(p, p + 34.56);
  return fract(p.x + p.y);
}

float cubicInOut(float t) {
  return t < 0.5
  ? 4.0 * t * t * t : 0.5 * pow(2.0 * t - 2.0, 3.0) + 1.0;
}

float getTime(float t, float duration) {
  return clamp(t, 0.0, duration) / duration;
}

float segBase(vec2 p) {
  vec2 prevP = p;

  float size = 0.02;
  float padding = 0.05;

  float w = padding * 3.0;
  float h = padding * 5.0;

  p = mod(p, 0.05) - 0.025;
  float thickness = 0.005;
  float gridMask = min(abs(p.x) - thickness, abs(p.y) - thickness);

  p = prevP;
  float d = B(p, vec2(w * 0.5, h * 0.5));
  float a = radians(45.0);
  p.x = abs(p.x) - 0.1;
  p.y = abs(p.y) - 0.05;
  float d2 = dot(p, vec2(cos(a), sin(a)));
  d = max(d2, d);
  d = max(-gridMask, d);
  return d;
}

float seg0(vec2 p) {
  vec2 prevP = p;
  float d = segBase(p);
  float size = 0.03;
  float mask = B(p, vec2(size, size * 2.7));
  d = max(-mask, d);
  return d;
}

float seg1(vec2 p) {
  vec2 prevP = p;
  float d = segBase(p);
  float size = 0.03;
  p.x += size;
  p.y += size;
  float mask = B(p, vec2(size * 2., size * 3.7));
  d = max(-mask, d);

  p = prevP;

  p.x += size * 1.8;
  p.y -= size * 3.5;
  mask = B(p, vec2(size));
  d = max(-mask, d);

  return d;
}

float seg2(vec2 p) {
  vec2 prevP = p;
  float d = segBase(p);
  float size = 0.03;
  p.x += size;
  p.y -= 0.05;
  float mask = B(p, vec2(size * 2., size));
  d = max(-mask, d);

  p = prevP;
  p.x -= size;
  p.y += 0.05;
  mask = B(p, vec2(size * 2., size));
  d = max(-mask, d);

  return d;
}

float seg3(vec2 p) {
  vec2 prevP = p;
  float d = segBase(p);
  float size = 0.03;
  p.y = abs(p.y);
  p.x += size;
  p.y -= 0.05;
  float mask = B(p, vec2(size * 2., size));
  d = max(-mask, d);

  p = prevP;
  p.x += 0.05;
  mask = B(p, vec2(size, size));
  d = max(-mask, d);

  return d;
}

float seg4(vec2 p) {
  vec2 prevP = p;
  float d = segBase(p);
  float size = 0.03;

  p.x += size;
  p.y += 0.08;
  float mask = B(p, vec2(size * 2., size * 2.0));
  d = max(-mask, d);

  p = prevP;

  p.y -= 0.08;
  mask = B(p, vec2(size, size * 2.0));
  d = max(-mask, d);

  return d;
}

float seg5(vec2 p) {
  vec2 prevP = p;
  float d = segBase(p);
  float size = 0.03;
  p.x -= size;
  p.y -= 0.05;
  float mask = B(p, vec2(size * 2., size));
  d = max(-mask, d);

  p = prevP;
  p.x += size;
  p.y += 0.05;
  mask = B(p, vec2(size * 2., size));
  d = max(-mask, d);

  return d;
}

float seg6(vec2 p) {
  vec2 prevP = p;
  float d = segBase(p);
  float size = 0.03;
  p.x -= size;
  p.y -= 0.05;
  float mask = B(p, vec2(size * 2., size));
  d = max(-mask, d);

  p = prevP;
  p.y += 0.05;
  mask = B(p, vec2(size, size));
  d = max(-mask, d);

  return d;
}

float seg7(vec2 p) {
  vec2 prevP = p;
  float d = segBase(p);
  float size = 0.03;
  p.x += size;
  p.y += size;
  float mask = B(p, vec2(size * 2., size * 3.7));
  d = max(-mask, d);
  return d;
}

float seg8(vec2 p) {
  vec2 prevP = p;
  float d = segBase(p);
  float size = 0.03;
  p.y = abs(p.y);
  p.y -= 0.05;
  float mask = B(p, vec2(size, size));
  d = max(-mask, d);

  return d;
}

float seg9(vec2 p) {
  vec2 prevP = p;
  float d = segBase(p);
  float size = 0.03;
  p.y -= 0.05;
  float mask = B(p, vec2(size, size));
  d = max(-mask, d);

  p = prevP;
  p.x += size;
  p.y += 0.05;
  mask = B(p, vec2(size * 2., size));
  d = max(-mask, d);

  return d;
}

float segDecimalPoint(vec2 p) {
  vec2 prevP = p;
  float d = segBase(p);
  float size = 0.028;
  p.y += 0.1;
  float mask = B(p, vec2(size, size));
  d = max(mask, d);
  return d;
}

float drawFont(vec2 p, int ch) {
  p *= 2.0;
  float d = 10.0;
  if (ch == seg_0) {
    d = seg0(p);
  } else if (ch == seg_1) {
    d = seg1(p);
  } else if (ch == seg_2) {
    d = seg2(p);
  } else if (ch == seg_3) {
    d = seg3(p);
  } else if (ch == seg_4) {
    d = seg4(p);
  } else if (ch == seg_5) {
    d = seg5(p);
  } else if (ch == seg_6) {
    d = seg6(p);
  } else if (ch == seg_7) {
    d = seg7(p);
  } else if (ch == seg_8) {
    d = seg8(p);
  } else if (ch == seg_9) {
    d = seg9(p);
  } else if (ch == seg_DP) {
    d = segDecimalPoint(p);
  }

  return d;
}

float ring0(vec2 p) {
  vec2 prevP = p;
  p *= Rot(radians(-iTime * SPEED * 30. + 50.));
  p = DF(p, 16.0);
  p -= vec2(0.35);
  float d = B(p * Rot(radians(45.0)), vec2(0.005, 0.03));
  p = prevP;

  p *= Rot(radians(-iTime * SPEED * 30. + 50.));
  float deg = 165.;
  float a = radians(deg);
  d = max(dot(p, vec2(cos(a), sin(a))), d);
  a = radians(-deg);
  d = max(dot(p, vec2(cos(a), sin(a))), d);

  p = prevP;
  p *= Rot(radians(iTime * SPEED * 30. + 30.));
  float d2 = abs(length(p) - 0.55) - 0.015;
  d2 = max(-(abs(p.x) - 0.4), d2);
  d = min(d, d2);
  p = prevP;
  d2 = abs(length(p) - 0.55) - 0.001;
  d = min(d, d2);

  p = prevP;
  p *= Rot(radians(-iTime * SPEED * 50. + 30.));
  p += sin(p * 25. - radians(iTime * SPEED * 80.)) * 0.01;
  d2 = abs(length(p) - 0.65) - 0.0001;
  d = min(d, d2);

  p = prevP;
  a = radians(-sin(iTime * SPEED * 1.2)) * 120.0;
  a += radians(-70.);
  p.x += cos(a) * 0.58;
  p.y += sin(a) * 0.58;

  d2 = abs(Tri(p * Rot(-a) * Rot(radians(90.0)), vec2(0.03), radians(45.))) - 0.003;
  d = min(d, d2);

  p = prevP;
  a = radians(sin(iTime * SPEED * 1.3)) * 100.0;
  a += radians(-10.);
  p.x += cos(a) * 0.58;
  p.y += sin(a) * 0.58;

  d2 = abs(Tri(p * Rot(-a) * Rot(radians(90.0)), vec2(0.03), radians(45.))) - 0.003;
  d = min(d, d2);

  return d;
}

float ring1(vec2 p) {
  vec2 prevP = p;
  float size = 0.45;
  float deg = 140.;
  float thickness = 0.02;
  float d = abs(length(p) - size) - thickness;

  p *= Rot(radians(iTime * SPEED * 60.));
  float a = radians(deg);
  d = max(dot(p, vec2(cos(a), sin(a))), d);
  a = radians(-deg);
  d = max(dot(p, vec2(cos(a), sin(a))), d);

  p = prevP;
  float d2 = abs(length(p) - size) - 0.001;

  return min(d, d2);
}

float ring2(vec2 p) {
  vec2 prevP = p;
  float size = 0.3;
  float deg = 120.;
  float thickness = 0.02;

  p *= Rot(-radians(sin(iTime * SPEED * 2.) * 90.));
  float d = abs(length(p) - size) - thickness;
  float a = radians(-deg);
  d = max(dot(p, vec2(cos(a), sin(a))), d);
  a = radians(deg);
  d = max(dot(p, vec2(cos(a), sin(a))), d);

  float d2 = abs(length(p) - size) - thickness;
  a = radians(-deg);
  d2 = max(-dot(p, vec2(cos(a), sin(a))), d2);
  a = radians(deg);
  d2 = max(-dot(p, vec2(cos(a), sin(a))), d2);

  return min(d, d2);
}

float ring3(vec2 p) {
  p *= Rot(radians(-iTime * SPEED * 80. - 120.));

  vec2 prevP = p;
  float deg = 140.;

  p = DF(p, 6.0);
  p -= vec2(0.3);
  float d = abs(B(p * Rot(radians(45.0)), vec2(0.03, 0.025))) - 0.003;

  p = prevP;
  float a = radians(-deg);
  d = max(dot(p, vec2(cos(a), sin(a))), d);
  a = radians(deg);
  d = max(dot(p, vec2(cos(a), sin(a))), d);

  p = prevP;

  p = DF(p, 6.0);
  p -= vec2(0.3);
  float d2 = abs(B(p * Rot(radians(45.0)), vec2(0.03, 0.025))) - 0.003;

  p = prevP;
  a = radians(-deg);
  d2 = max(-dot(p, vec2(cos(a), sin(a))), d2);
  a = radians(deg);
  d2 = max(-dot(p, vec2(cos(a), sin(a))), d2);

  return min(d, d2);
}

float ring4(vec2 p) {
  p *= Rot(radians(iTime * SPEED * 75. - 220.));

  vec2 prevP = p;
  float deg = 20.;

  float d = abs(length(p) - 0.25) - 0.01;

  p = DF(p, 2.0);
  p -= vec2(0.1);

  float a = radians(-deg);
  d = max(-dot(p, vec2(cos(a), sin(a))), d);
  a = radians(deg);
  d = max(-dot(p, vec2(cos(a), sin(a))), d);

  return d;
}

float ring5(vec2 p) {
  p *= Rot(radians(-iTime * SPEED * 70. + 170.));

  vec2 prevP = p;
  float deg = 150.;

  float d = abs(length(p) - 0.16) - 0.02;

  float a = radians(-deg);
  d = max(dot(p, vec2(cos(a), sin(a))), d);
  a = radians(deg);
  d = max(dot(p, vec2(cos(a), sin(a))), d);

  p = prevP;
  p *= Rot(radians(-30.));
  float d2 = abs(length(p) - 0.136) - 0.02;

  deg = 60.;
  a = radians(-deg);
  d2 = max(-dot(p, vec2(cos(a), sin(a))), d2);
  a = radians(deg);
  d2 = max(-dot(p, vec2(cos(a), sin(a))), d2);

  d = min(d, d2);

  return d;
}

float ring6(vec2 p) {
  vec2 prevP = p;
  p *= Rot(radians(iTime * SPEED * 72. + 110.));

  float d = abs(length(p) - 0.95) - 0.001;
  d = max(-(abs(p.x) - 0.4), d);
  d = max(-(abs(p.y) - 0.4), d);

  p = prevP;
  p *= Rot(radians(-iTime * SPEED * 30. + 50.));
  p = DF(p, 16.0);
  p -= vec2(0.6);
  float d2 = B(p * Rot(radians(45.0)), vec2(0.02, 0.03));
  p = prevP;

  p *= Rot(radians(-iTime * SPEED * 30. + 50.));
  float deg = 155.;
  float a = radians(deg);
  d2 = max(-dot(p, vec2(cos(a), sin(a))), d2);
  a = radians(-deg);
  d2 = max(-dot(p, vec2(cos(a), sin(a))), d2);

  return min(d, d2);
}

float bg(vec2 p) {
  p.y -= iTime * SPEED * 0.1;
  vec2 prevP = p;

  p *= 2.8;
  vec2 gv = fract(p) - 0.5;
  vec2 gv2 = fract(p * 3.) - 0.5;
  vec2 id = floor(p);

  float d = min(B(gv2, vec2(0.02, 0.09)), B(gv2, vec2(0.09, 0.02)));

  float n = Hash21(id);
  gv += vec2(0.166, 0.17);
  float d2 = abs(B(gv, vec2(0.169))) - 0.004;

  if (n < 0.3) {
    gv *= Rot(radians(iTime * SPEED * 60.));
    d2 = max(-(abs(gv.x) - 0.08), d2);
    d2 = max(-(abs(gv.y) - 0.08), d2);
    d = min(d, d2);
  } else if (n >= 0.3 && n < 0.6) {
    gv *= Rot(radians(-iTime * SPEED * 60.));
    d2 = max(-(abs(gv.x) - 0.08), d2);
    d2 = max(-(abs(gv.y) - 0.08), d2);
    d = min(d, d2);
  } else if (n >= 0.6 && n < 1.) {
    gv *= Rot(radians(iTime * SPEED * 60.) + n);
    d2 = abs(length(gv) - 0.1) - 0.025;
    d2 = max(-(abs(gv.x) - 0.03), d2);
    d = min(d, abs(d2) - 0.003);
  }

  p = prevP;
  p = mod(p, 0.02) - 0.01;
  d2 = B(p, vec2(0.001));
  d = min(d, d2);

  return d;
}

float numberWithCIrcleUI(vec2 p) {
  vec2 prevP = p;
  vec2 q = p;
  int num0 = int(iClock.x);
  int num1 = int(iClock.y);
  int num2 = int(iClock.z);
  int num3 = int(iClock.w);

  q *= SkewX(radians(-15.0));
  float d = drawFont(q - vec2(-0.16, 0.0), num0);
  float d2 = drawFont(q - vec2(-0.08, 0.0), num1);
  d = min(d, d2);
  d2 = drawFont(q - vec2(-0.02, 0.0), seg_DP);
  d = min(d, d2);

  q = p * 1.5;
  d2 = drawFont(q - vec2(0.04, -0.03), num2);
  d = min(d, d2);
  d2 = drawFont(q - vec2(0.12, -0.03), num3);
  d = abs(min(d, d2)) - 0.002;

  q = prevP;
  q.x -= 0.07;
  q *= Rot(radians(-iTime * SPEED * 50.0));
  q = DF(q, 4.0);
  q -= vec2(0.085);
  d2 = B(q * Rot(radians(45.0)), vec2(0.015, 0.018));
  q = prevP;
  d2 = max(-B(q, vec2(0.13, 0.07)), d2);
  d = min(d, abs(d2) - 0.0005);

  return d;
}

float blockUI(vec2 p) {
  vec2 prevP = p;
  vec2 q = p;
  q.x += iTime * SPEED * 0.05;
  q.y = abs(q.y) - 0.02;
  q.x = mod(q.x, 0.04) - 0.02;
  float d = B(q, vec2(0.0085));

  q = prevP;
  q.x += iTime * SPEED * 0.05;
  q.x += 0.02;
  q.x = mod(q.x, 0.04) - 0.02;
  float d2 = B(q, vec2(0.0085));
  d = min(d, d2);

  q = prevP;
  d = max(abs(q.x) - 0.2, d);
  return abs(d) - 0.0002;
}

float smallCircleUI(vec2 p) {
  p *= 1.1;
  vec2 prevP = p;

  float deg = 20.;

  p *= Rot(radians(sin(iTime * SPEED * 3.) * 50.));
  float d = abs(length(p) - 0.1) - 0.003;

  p = DF(p, 0.75);
  p -= vec2(0.02);

  float a = radians(-deg);
  d = max(-dot(p, vec2(cos(a), sin(a))), d);
  a = radians(deg);
  d = max(-dot(p, vec2(cos(a), sin(a))), d);

  p = prevP;
  p *= Rot(radians(-sin(iTime * SPEED * 2.) * 80.));
  float d2 = abs(length(p) - 0.08) - 0.001;
  d2 = max(-p.x, d2);
  d = min(d, d2);

  p = prevP;
  p *= Rot(radians(-iTime * SPEED * 50.));
  d2 = abs(length(p) - 0.05) - 0.015;
  deg = 170.;
  a = radians(deg);
  d2 = max(-dot(p, vec2(cos(a), sin(a))), d2);
  a = radians(-deg);
  d2 = max(-dot(p, vec2(cos(a), sin(a))), d2);
  d = min(d, abs(d2) - 0.0005);

  return d;
}

float smallCircleUI2(vec2 p) {
  vec2 q = p;
  float d = abs(length(q) - 0.04) - 0.0001;
  float d2 = length(q) - 0.03;

  q *= Rot(radians(iTime * SPEED * 30.0));
  float deg = 140.0;
  float a = radians(deg);
  d2 = max(-dot(q, vec2(cos(a), sin(a))), d2);
  a = radians(-deg);
  d2 = max(-dot(q, vec2(cos(a), sin(a))), d2);
  d = min(d, d2);

  d2 = length(q) - 0.03;
  a = radians(deg);
  d2 = max(dot(q, vec2(cos(a), sin(a))), d2);
  a = radians(-deg);
  d2 = max(dot(q, vec2(cos(a), sin(a))), d2);
  d = min(d, d2);

  d = max(-(length(q) - 0.02), d);

  return d;
}

float rectUI(vec2 p) {
  vec2 q = p * Rot(radians(45.0));
  vec2 prevQ = q;
  float d = abs(B(q, vec2(0.12))) - 0.003;

  q *= Rot(radians(iTime * SPEED * 60.0));
  d = max(-(abs(q.x) - 0.05), d);
  d = max(-(abs(q.y) - 0.05), d);

  q = prevQ;
  float d2 = abs(B(q, vec2(0.12))) - 0.0005;
  d = min(d, d2);

  d2 = abs(B(q, vec2(0.09))) - 0.003;
  q *= Rot(radians(-iTime * SPEED * 50.0));
  d2 = max(-(abs(q.x) - 0.03), d2);
  d2 = max(-(abs(q.y) - 0.03), d2);
  d = min(d, d2);

  q = prevQ;
  d2 = abs(B(q, vec2(0.09))) - 0.0005;
  d = min(d, d2);

  q *= Rot(radians(-45.0));
  q.y = abs(q.y) - 0.07 - sin(iTime * SPEED * 3.0) * 0.01;
  d2 = Tri(q, vec2(0.02), radians(45.0));
  d = min(d, d2);

  q = prevQ;
  q *= Rot(radians(45.0));
  q.y = abs(q.y) - 0.07 - sin(iTime * SPEED * 3.0) * 0.01;
  d2 = Tri(q, vec2(0.02), radians(45.0));
  d = min(d, d2);

  q = prevQ;
  q *= Rot(radians(45.0));
  d2 = abs(B(q, vec2(0.025))) - 0.0005;
  d2 = max(-(abs(q.x) - 0.01), d2);
  d2 = max(-(abs(q.y) - 0.01), d2);
  d = min(d, d2);

  return d;
}

float graphUI(vec2 p) {
  vec2 prevP = p;
  vec2 q = p;
  q.x += 0.5;
  q.y -= iTime * SPEED * 0.25;
  q *= vec2(1.0, 100.0);

  vec2 gv = fract(q) - 0.5;
  vec2 id = floor(q);

  float n = Hash21(vec2(id.y)) * 2.0;
  float w = (abs(sin(iTime * SPEED * n) + 0.25) * 0.03) * n * 0.5;
  float d = B(gv, vec2(w, 0.1));

  q = prevP;
  d = max(abs(q.x) - 0.2, d);
  d = max(abs(q.y) - 0.2, d);

  return d;
}

float staticUI(vec2 p) {
  vec2 prevP = p;
  float d = B(p, vec2(0.005, 0.13));
  p -= vec2(0.02, -0.147);
  p *= Rot(radians(-45.));
  float d2 = B(p, vec2(0.005, 0.028));
  d = min(d, d2);
  p = prevP;
  d2 = B(p - vec2(0.04, -0.2135), vec2(0.005, 0.049));
  d = min(d, d2);
  p -= vec2(0.02, -0.28);
  p *= Rot(radians(45.));
  d2 = B(p, vec2(0.005, 0.03));
  d = min(d, d2);
  p = prevP;
  d2 = length(p - vec2(0., 0.13)) - 0.012;
  d = min(d, d2);
  d2 = length(p - vec2(0., -0.3)) - 0.012;
  d = min(d, d2);
  return d;
}

float arrowUI(vec2 p) {
  vec2 prevP = p;
  vec2 q = p;
  q.x *= -1.0;
  q.x -= iTime * SPEED * 0.12;
  q.x = mod(q.x, 0.07) - 0.035;
  q.x -= 0.0325;

  q *= vec2(0.9, 1.5);
  q *= Rot(radians(90.0));
  float d = Tri(q, vec2(0.05), radians(45.0));
  d = max(-Tri(q - vec2(0.0, -0.03), vec2(0.05), radians(45.0)), d);
  d = abs(d) - 0.0005;

  q = prevP;
  d = max(abs(q.x) - 0.15, d);
  return d;
}

float sideLine(vec2 p) {
  p.x *= -1.0;
  vec2 prevP = p;
  p.y = abs(p.y) - 0.17;
  p *= Rot(radians(45.));
  float d = B(p, vec2(0.035, 0.01));
  p = prevP;
  float d2 = B(p - vec2(0.0217, 0.), vec2(0.01, 0.152));
  d = min(d, d2);
  return abs(d) - 0.0005;
}

float sideUI(vec2 p) {
  vec2 prevP = p;
  p.x *= -1.;
  p.x += 0.025;
  float d = sideLine(p);
  p = prevP;
  p.y = abs(p.y) - 0.275;
  float d2 = sideLine(p);
  d = min(d, d2);
  return d;
}

float overlayUI(vec2 p) {
  vec2 prevP = p;
  vec2 q = p;

  float d = numberWithCIrcleUI(q - vec2(0.56, -0.34));

  q = prevP;
  q.x = abs(q.x) - 0.56;
  q.y -= 0.45;
  float d2 = blockUI(q);
  d = min(d, d2);

  q = prevP;
  q.x = abs(q.x) - 0.72;
  q.y -= 0.35;
  d2 = smallCircleUI2(q);
  d = min(d, d2);

  q = prevP;
  d2 = smallCircleUI2(q - vec2(-0.39, -0.42));
  d = min(d, d2);

  q = prevP;
  q.x -= 0.58;
  q.y -= 0.07;
  q.y = abs(q.y) - 0.12;
  d2 = smallCircleUI(q);
  d = min(d, d2);

  q = prevP;
  d2 = rectUI(q - vec2(-0.58, -0.3));
  d = min(d, d2);

  q = prevP;
  q -= vec2(-0.58, 0.1);
  q.x = abs(q.x) - 0.05;
  d2 = graphUI(q);
  d = min(d, d2);

  q = prevP;
  q.x = abs(q.x) - 0.72;
  q.y -= 0.13;
  d2 = staticUI(q);
  d = min(d, d2);

  q = prevP;
  q.x = abs(q.x) - 0.51;
  q.y -= 0.35;
  d2 = arrowUI(q);
  d = min(d, d2);

  q = prevP;
  q.x = abs(q.x) - 0.82;
  d2 = sideUI(q);
  d = min(d, d2);

  return d;
}

float GetDist(vec3 p) {
  vec3 q = p;

  q.z += 0.7;
  float maxThick = 0.03;
  float minThick = 0.007;
  float thickness = maxThick;
  float frame = mod(iTime * SPEED, 30.0);
  float time = frame;
  if (frame >= 10.0 && frame < 20.0) {
    time = getTime(time - 10.0, 1.5);
    thickness = (maxThick + minThick) - cubicInOut(time) * maxThick;
  } else if (frame >= 20.0) {
    time = getTime(time - 20.0, 1.5);
    thickness = minThick + cubicInOut(time) * maxThick;
  }

  float d = ring0(q.xy);
  d = max(abs(q.z) - thickness, d);

  q.z -= 0.2;
  float d2 = ring1(q.xy);
  d2 = max(abs(q.z) - thickness, d2);
  d = min(d, d2);

  q.z -= 0.2;
  d2 = ring2(q.xy);
  d2 = max(abs(q.z) - thickness, d2);
  d = min(d, d2);

  q.z -= 0.2;
  d2 = ring3(q.xy);
  d2 = max(abs(q.z) - thickness, d2);
  d = min(d, d2);

  q.z -= 0.2;
  d2 = ring4(q.xy);
  d2 = max(abs(q.z) - thickness, d2);
  d = min(d, d2);

  q.z -= 0.2;
  d2 = ring5(q.xy);
  d2 = max(abs(q.z) - thickness, d2);
  d = min(d, d2);

  q.z -= 0.2;
  d2 = ring6(q.xy);
  d2 = max(abs(q.z) - thickness, d2);
  d = min(d, d2);

  return d;
}

vec3 RayMarch(vec3 ro, vec3 rd, int stepnum) {
  vec3 res = vec3(0.0);
  float steps = 0.0;
  float alpha = 0.0;

  float tmax = 5.;
  float t = 0.0;

  float glowVal = 0.003;

  for (float i = 0.; i < float(stepnum); i++) {
    steps = i;
    vec3 p = ro + rd * t;
    float d = GetDist(p);
    float absd = abs(d);

    if (t > tmax) break;

    alpha += 1.0 - smoothstep(0.0, glowVal, d);
    t += max(0.0001, absd * 0.6);
  }
  alpha /= steps;

  res += alpha * vec3(1.5);
  return res;
}

vec3 R(vec2 uv, vec3 p, vec3 l, float z) {
  vec3 f = normalize(l - p),
  r = normalize(cross(vec3(0, 1, 0), f)),
  u = cross(f, r),
  c = p + f * z,
  i = c + uv.x * r + uv.y * u,
  d = normalize(i - p);
  return d;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
  vec2 m = iMouse.xy / iResolution.xy;

  vec3 ro = vec3(0.0, 0.0, -2.1);
  if (iMouse.z > 0.0) {
    ro.yz *= Rot(m.y * 3.14 + 1.0);
    ro.y = max(-0.9, ro.y);
    ro.xz *= Rot(-m.x * 6.2831);
  } else {
    float yzAngle = 45.0;
    float baseRxz = 50.0;
    float animRxz = 20.0;

    float frame = mod(iTime * SPEED, 30.0);
    float time = frame;

    if (frame >= 10.0 && frame < 20.0) {
      time = getTime(time - 10.0, 1.5);

      yzAngle = 45.0 - cubicInOut(time) * 45.0;
      baseRxz = 50.0 - cubicInOut(time) * 50.0;
      animRxz = 20.0 - cubicInOut(time) * 20.0;
    } else if (frame >= 20.0) {
      time = getTime(time - 20.0, 1.5);

      yzAngle = cubicInOut(time) * 45.0;
      baseRxz = cubicInOut(time) * 50.0;
      animRxz = cubicInOut(time) * 20.0;
    }

    ro.yz *= Rot(radians(yzAngle));
    ro.xz *= Rot(radians(sin(iTime * SPEED * 0.3) * animRxz + baseRxz));
  }

  vec3 rd = R(uv, ro, vec3(0.0, 0.0, 0.0), 1.0);
  vec3 marchCol = RayMarch(ro, rd, MAX_STEPS);
  vec3 col = vec3(0.0);
  float bgDist = bg(uv);
  col = mix(col, vec3(1.0), S(bgDist, 0.0));

  col = mix(col, marchCol.xyz, 0.7);
  col = pow(col, vec3(0.9545));

  float overlayDist = overlayUI(uv);
  col = mix(col, vec3(1.0), S(overlayDist, 0.0));

  fragColor = vec4(col, 1.0);
}
