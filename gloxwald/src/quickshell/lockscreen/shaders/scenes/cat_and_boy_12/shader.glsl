// --- دوال رياضية مساعدة ---
vec2 rot(vec2 p, float a) {
  float s = sin(a), c = cos(a);
  return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

float circle(vec2 uv, vec2 center, float radius) {
  return smoothstep(0.01, 0.0, length(uv - center) - radius);
}

float ellipse(vec2 uv, vec2 center, vec2 radii) {
  vec2 p = (uv - center) / radii;
  return smoothstep(1.0, 0.95, length(p));
}

float rect(vec2 uv, vec2 center, vec2 size) {
  vec2 d = abs(uv - center) - size;
  return smoothstep(0.01, 0.0, max(d.x, d.y));
}

// --- رسم الخلفية (المدينة والشجرة) ---
vec3 drawBackground(vec2 uv) {
  // تدرج لون السماء
  vec3 col = mix(vec3(0.6, 0.8, 1.0), vec3(0.2, 0.4, 0.7), uv.y + 0.5);

  // مباني المدينة (مستطيلات بأحجام مختلفة)
  float city = 0.0;
  city += rect(uv, vec2(-0.6, -0.1), vec2(0.1, 0.3));
  city += rect(uv, vec2(-0.3, -0.05), vec2(0.15, 0.35));
  city += rect(uv, vec2(0.0, -0.2), vec2(0.1, 0.2));
  city += rect(uv, vec2(0.7, 0.0), vec2(0.12, 0.4));
  city += rect(uv, vec2(-0.8, -0.2), vec2(0.08, 0.2));
  col = mix(col, vec3(0.4, 0.45, 0.5), clamp(city, 0.0, 1.0));

  // الأرض
  float ground = rect(uv, vec2(0.0, -0.45), vec2(1.0, 0.05));
  col = mix(col, vec3(0.3, 0.6, 0.3), ground);

  // جذع الشجرة
  float trunk = rect(uv, vec2(0.4, -0.1), vec2(0.03, 0.3));
  col = mix(col, vec3(0.4, 0.25, 0.15), trunk);

  // أوراق الشجرة
  float leaves = 0.0;
  leaves += circle(uv, vec2(0.4, 0.25), 0.18);
  leaves += circle(uv, vec2(0.25, 0.2), 0.12);
  leaves += circle(uv, vec2(0.55, 0.2), 0.12);
  leaves += circle(uv, vec2(0.4, 0.4), 0.12);
  col = mix(col, vec3(0.15, 0.5, 0.2), clamp(leaves, 0.0, 1.0));

  return col;
}

// --- رسم الولد ---
void drawBoy(vec2 uv, vec2 pos, float armAngle, float t, float dir, inout float skin, inout float clothes) {
  vec2 p = uv - pos;
  p.x *= dir; // عكس الاتجاه إذا لزم الأمر

  // الرأس
  skin += circle(p, vec2(0.0, 0.12), 0.04);

  // الجسم (قميص أحمر)
  clothes += rect(p, vec2(0.0, 0.0), vec2(0.035, 0.07));

  // الأرجل (حركة المشي)
  float walk = sin(t * 15.0) * 0.04;
  float walk2 = sin(t * 15.0 + 3.14) * 0.04;
  clothes += rect(p, vec2(-0.015, -0.11 + walk), vec2(0.012, 0.05));
  clothes += rect(p, vec2(0.015, -0.11 + walk2), vec2(0.012, 0.05));

  // الذراع (تتحرك لأعلى لالتقاط القطة)
  vec2 armPivot = vec2(0.0, 0.05);
  vec2 pArm = p - armPivot;
  pArm = rot(pArm, armAngle);
  skin += rect(pArm, vec2(0.04, 0.0), vec2(0.03, 0.01));
}

// --- رسم القطة ---
void drawCat(vec2 uv, vec2 pos, float angle, float t, float dir, inout float catShape, inout float eyesShape) {
  vec2 p = uv - pos;
  p = rot(p, -angle); // دوران القطة (للتسلق)
  p.x *= dir; // عكس الاتجاه

  catShape += ellipse(p, vec2(0.0), vec2(0.12, 0.06)); // الجسم
  vec2 headPos = vec2(0.12, 0.04);
  catShape += circle(p, headPos, 0.06); // الرأس
  catShape += ellipse(p, headPos + vec2(0.03, 0.06), vec2(0.015, 0.04)); // أذن 1
  catShape += ellipse(p, headPos + vec2(-0.02, 0.05), vec2(0.015, 0.04)); // أذن 2

  float tailWag = sin(iTime * 10.0) * 0.05;
  catShape += ellipse(p, vec2(-0.12, 0.03 + tailWag), vec2(0.05, 0.012)); // الديل

  float walk = sin(t * 20.0) * 0.03;
  float walk2 = sin(t * 20.0 + 3.14) * 0.03;
  catShape += ellipse(p, vec2(0.06, -0.06 + walk), vec2(0.012, 0.04)); // أرجل
  catShape += ellipse(p, vec2(0.03, -0.06 + walk2), vec2(0.012, 0.04));
  catShape += ellipse(p, vec2(-0.06, -0.06 + walk2), vec2(0.012, 0.04));
  catShape += ellipse(p, vec2(-0.09, -0.06 + walk), vec2(0.012, 0.04));

  eyesShape += circle(p, headPos + vec2(0.02, 0.01), 0.01); // عيون
  eyesShape += circle(p, headPos + vec2(0.05, 0.01), 0.01);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = fragCoord / iResolution.xy;
  uv -= 0.5;
  uv.x *= iResolution.x / iResolution.y;

  // 1. رسم الخلفية الثابتة
  vec3 col = drawBackground(uv);

  // 2. إعداد متغيرات الزمن والقصة (الحلقة مدتها 14 ثانية)
  float t = mod(iTime, 14.0);

  vec2 catPos = vec2(0.0);
  float catAngle = 0.0;
  float catDir = 1.0;
  float catWalkTime = 0.0;

  vec2 boyPos = vec2(-2.0, -0.22);
  float boyDir = 1.0;
  float boyWalkTime = 0.0;
  float armAngle = -1.0; // ذراع الولد لأسفل

  // 3. كتابة السيناريو (Logic)
  if (t < 3.0) {
    // المشهد الأول: القطة تجري نحو الشجرة
    catPos = vec2(mix(-1.0, 0.32, t / 3.0), -0.34 + abs(sin(t * 20.0)) * 0.02);
    catWalkTime = t;
  }
  else if (t < 5.0) {
    // المشهد الثاني: القطة تتسلق الشجرة
    float climb = (t - 3.0) / 2.0;
    catPos = vec2(0.31, mix(-0.34, 0.25, climb));
    catAngle = 1.57; // دوران 90 درجة لأعلى
    catWalkTime = t;
  }
  else if (t < 7.0) {
    // المشهد الثالث: القطة عالقة، الولد يجري لإنقاذها
    catPos = vec2(0.31, 0.25);
    catDir = -1.0; // تنظر لليسار
    boyPos = vec2(mix(-1.2, 0.15, (t - 5.0) / 2.0), -0.22 + abs(sin(t * 15.0)) * 0.02);
    boyWalkTime = t;
  }
  else if (t < 9.0) {
    // المشهد الرابع: الولد يرفع يده والقطة تقفز
    boyPos = vec2(0.15, -0.22);
    armAngle = mix(-1.0, 1.2, clamp((t - 7.0) * 2.0, 0.0, 1.0)); // يرفع يده

    float jump = clamp((t - 7.5) * 2.0, 0.0, 1.0);
    catPos = mix(vec2(0.31, 0.25), boyPos + vec2(-0.02, 0.12), jump); // تسقط في يده
    catDir = -1.0;
  }
  else {
    // المشهد الخامس: الولد يأخذ القطة ويغادر
    float walk = (t - 9.0) / 5.0;
    boyPos = vec2(mix(0.15, -1.2, walk), -0.22 + abs(sin(t * 15.0)) * 0.02);
    boyDir = -1.0; // يلتف لليسار
    boyWalkTime = t;
    armAngle = 0.5; // يحضن القطة
    catPos = boyPos + vec2(-0.02, 0.1); // القطة تتحرك مع الولد
    catDir = -1.0;
  }

  // 4. رسم الولد
  float skin = 0.0, clothes = 0.0;
  drawBoy(uv, boyPos, armAngle, boyWalkTime, boyDir, skin, clothes);
  col = mix(col, vec3(0.9, 0.3, 0.3), clamp(clothes, 0.0, 1.0)); // ملابس حمراء
  col = mix(col, vec3(1.0, 0.8, 0.6), clamp(skin, 0.0, 1.0)); // لون البشرة

  // 5. رسم القطة فوق الولد
  float catShape = 0.0, eyesShape = 0.0;
  drawCat(uv, catPos, catAngle, catWalkTime, catDir, catShape, eyesShape);
  catShape = clamp(catShape, 0.0, 1.0);
  col = mix(col, vec3(0.15), catShape); // قطة سوداء
  col = mix(col, vec3(1.0, 1.0, 0.0), eyesShape * catShape); // عيون صفراء

  fragColor = vec4(col, 1.0);
}
