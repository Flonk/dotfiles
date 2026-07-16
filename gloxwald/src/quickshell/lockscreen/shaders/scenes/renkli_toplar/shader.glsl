const float SPEED = 0.2;

float Hashfv2(vec2 p);
vec3 Hashv3v3(vec3 p);
vec3 ltDir;
float tCur, dstFar;
const vec3 bGrid = vec3(2.);
const float pi = 3.14159;

// --- 20 canlı top rengi ---
vec3 ballColors[20];
void initColors() {
  ballColors[0] = vec3(1.00, 0.10, 0.10); // kırmızı
  ballColors[1] = vec3(1.00, 0.45, 0.00); // turuncu
  ballColors[2] = vec3(1.00, 0.85, 0.00); // altın sarısı
  ballColors[3] = vec3(0.70, 1.00, 0.00); // limon yeşili
  ballColors[4] = vec3(0.00, 0.90, 0.20); // yeşil
  ballColors[5] = vec3(0.00, 0.95, 0.75); // turkuaz
  ballColors[6] = vec3(0.00, 0.70, 1.00); // açık mavi
  ballColors[7] = vec3(0.10, 0.20, 1.00); // kobalt mavi
  ballColors[8] = vec3(0.50, 0.00, 1.00); // mor
  ballColors[9] = vec3(0.90, 0.00, 0.90); // magenta
  ballColors[10] = vec3(1.00, 0.40, 0.70); // pembe
  ballColors[11] = vec3(0.00, 0.85, 0.85); // cyan
  ballColors[12] = vec3(1.00, 0.60, 0.20); // şeftali
  ballColors[13] = vec3(0.60, 1.00, 0.60); // açık yeşil
  ballColors[14] = vec3(0.30, 0.80, 1.00); // gökyüzü mavisi
  ballColors[15] = vec3(1.00, 0.30, 0.50); // mercan
  ballColors[16] = vec3(0.80, 0.50, 1.00); // lavanta
  ballColors[17] = vec3(1.00, 0.75, 0.30); // amber
  ballColors[18] = vec3(0.40, 1.00, 0.80); // mint
  ballColors[19] = vec3(0.90, 0.90, 0.30); // zeytin sarısı
}

// Mesafeye göre renk seçimi: yakın=sıcak, uzak=soğuk
vec3 distanceColor(float dist, vec3 cId) {
  initColors();
  // Hash ile her topa özgü renk indeksi
  vec3 h = Hashv3v3(cId);
  int baseIdx = int(fract(h.x * 7.3 + h.y * 13.7 + h.z * 3.1) * 20.);

  // Mesafe bandı: 0-10 yakın, 10-30 orta, 30-50 uzak
  float normDist = clamp(dist / dstFar, 0., 1.);

  // Uzaklaştıkça renk soğur ve solarken, yakında canlı
  int idx1 = int(mod(float(baseIdx), 20.));
  int idx2 = int(mod(float(baseIdx) + normDist * 8., 20.));
  float blend = smoothstep(0.1, 0.9, normDist);

  vec3 c1 = ballColors[idx1];
  vec3 c2 = ballColors[idx2];
  return mix(c1, c2, blend);
}

float ObjDf(vec3 p, vec3 cId) {
  vec3 h;
  float s, d, r, a;
  d = dstFar;
  h = Hashv3v3(cId);
  if (h.x * step(2., length(cId.xz)) > 0.5) {
    p -= bGrid * (cId + 0.5);
    s = fract(64. * length(h));
    s *= s;
    r = 0.2 + 0.2 * bGrid.x * h.x * (1. - s) * abs(sin(3. * pi * h.y * (1. - s)));
    a = h.z * tCur + h.x;
    d = length(p - r * vec3(cos(a), 0., sin(a))) - 0.4 + 0.3 * s;
  }
  return d;
}

float ObjRay(vec3 ro, vec3 rd) {
  vec3 p, cId, s;
  float dHit, d, eps;
  eps = 0.0005;
  if (rd.x == 0.) rd.x = 0.001;
  if (rd.y == 0.) rd.y = 0.001;
  dHit = eps;
  for (int j = 0; j < 120; j++) {
    p = ro + rd * dHit;
    cId.xz = floor(p.xz / bGrid.xz);
    p.y -= tCur * (1. + Hashfv2(cId.xz));
    cId.y = floor(p.y / bGrid.y);
    d = ObjDf(p, cId);
    s = (bGrid * (cId + step(0., rd)) - p) / rd;
    d = min(d, abs(min(min(s.x, s.y), s.z)) + eps);
    if (d < eps || dHit > dstFar) break;
    dHit += d;
  }
  if (d >= eps) dHit = dstFar;
  return dHit;
}

float ObjDfN(vec3 p) {
  vec3 cId;
  cId.xz = floor(p.xz / bGrid.xz);
  p.y -= tCur * (1. + Hashfv2(cId.xz));
  cId.y = floor(p.y / bGrid.y);
  return ObjDf(p, cId);
}

vec3 ObjNf(vec3 p) {
  vec4 v;
  vec3 e = vec3(0.001, -0.001, 0.);
  v = vec4(ObjDfN(p + e.xxx), ObjDfN(p + e.xyy), ObjDfN(p + e.yxy), ObjDfN(p + e.yyx));
  return normalize(vec3(v.x - v.y - v.z - v.w) + 2. * v.yzw);
}

// Çarpan cId: yüzeyde hangi top rengi
vec3 ObjCId(vec3 p) {
  vec3 cId;
  cId.xz = floor(p.xz / bGrid.xz);
  p.y -= tCur * (1. + Hashfv2(cId.xz));
  cId.y = floor(p.y / bGrid.y);
  return cId;
}

// --- Zemin gradyan rengi ---
vec3 groundColor(vec3 p, float t) {
  // Zemin XZ konumuna ve zamana göre gradyan
  vec2 gp = p.xz * 0.15 + vec2(t * 0.07, t * 0.05);

  // 4 köşe rengi — dönen gradyan
  vec3 gA = vec3(0.15, 0.55, 0.90); // gökyüzü mavisi
  vec3 gB = vec3(0.70, 0.20, 0.80); // mor
  vec3 gC = vec3(0.10, 0.75, 0.50); // zümrüt
  vec3 gD = vec3(0.90, 0.55, 0.10); // amber

  // Sinüs bazlı ağırlıklar — yumuşak geçişler
  float wx = 0.5 + 0.5 * sin(gp.x * 1.3 + t * 0.3);
  float wy = 0.5 + 0.5 * cos(gp.y * 1.1 + t * 0.25);
  float wt = 0.5 + 0.5 * sin(t * 0.4 + length(p.xz) * 0.08);

  vec3 row1 = mix(gA, gB, wx);
  vec3 row2 = mix(gC, gD, wx);
  vec3 base = mix(row1, row2, wy);
  base = mix(base, gD * 0.8 + gA * 0.2, wt * 0.35);

  // Izgara çizgisi: parlak ince çizgiler
  float gridX = exp(-abs(fract(p.x * 0.5 + 0.5) - 0.5) * 18.) * 0.4;
  float gridZ = exp(-abs(fract(p.z * 0.5 + 0.5) - 0.5) * 18.) * 0.4;
  vec3 gridCol = vec3(1.0, 0.95, 0.8) * (gridX + gridZ);

  return base + gridCol;
}

vec3 BgCol(vec3 rd) {
  float t2, gd, b;
  t2 = tCur * 4.;
  b = dot(vec2(atan(rd.x, rd.z), 0.5 * pi - acos(rd.y)), vec2(2., sin(rd.x)));
  gd = clamp(sin(5. * b + t2), 0., 1.) * clamp(sin(3.5 * b - t2), 0., 1.)
      + clamp(sin(21. * b - t2), 0., 1.) * clamp(sin(17. * b + t2), 0., 1.);

  // Arka plan rengi: dinamik gradyan
  float hBand = 0.5 + 0.5 * sin(tCur * 0.18 + rd.x * 2.3);
  vec3 skyA = mix(vec3(0.10, 0.30, 0.80), vec3(0.50, 0.10, 0.70), hBand);
  vec3 skyB = mix(vec3(0.00, 0.50, 0.40), vec3(0.20, 0.60, 0.90), hBand);
  return mix(skyA, skyB, 0.5 * (1. - rd.y))
    * (0.24 + 0.44 * (rd.y + 1.) * (rd.y + 1.)) * (1. + 0.15 * gd);
}

vec3 ShowScene(vec3 ro, vec3 rd) {
  vec3 col, bgCol, vn, hitPos;
  float dstObj;
  initColors();
  bgCol = BgCol(rd);
  dstObj = ObjRay(ro, rd);

  if (dstObj < dstFar) {
    hitPos = ro + dstObj * rd;
    vn = ObjNf(hitPos);
    vec3 cId = ObjCId(hitPos);

    // Mesafeye + hash'e göre top rengi
    vec3 ballCol = distanceColor(dstObj, cId);

    // Işıklandırma
    float diff = max(dot(vn, ltDir), 0.);
    float spec = pow(max(dot(normalize(ltDir - rd), vn), 0.), 48.);
    float amb = 0.18 + 0.08 * max(vn.y, 0.);

    // Çevre yansıması: arka plan rengiyle mix
    vec3 refl = BgCol(reflect(rd, vn));
    vec3 litCol = ballCol * (amb + 0.6 * diff)
        + refl * 0.25
        + vec3(1.) * spec * 0.12;

    // Mesafeyle sisleme — uzaklaşınca zemin rengine karışır
    float fogT = smoothstep(0.3 * dstFar, dstFar, dstObj);
    litCol *= 0.3 + 0.7 * min(rd.y + 1., 1.5);
    col = mix(litCol, bgCol, fogT);

    // Yakın toplara hafif kenarlama (fresnel)
    float fresnel = pow(1. - abs(dot(rd, vn)), 3.);
    col += ballCol * fresnel * 0.3 * (1. - fogT);
  } else {
    // Zemin çizgisi: y aşağıda
    if (rd.y < -0.01) {
      float gDist = -(ro.y + 1.) / rd.y;
      if (gDist > 0. && gDist < dstFar) {
        vec3 gPos = ro + gDist * rd;
        vec3 gCol = groundColor(gPos, tCur);
        float gFog = smoothstep(0.3 * dstFar, dstFar, gDist);
        col = mix(gCol * 0.6, bgCol, gFog);
      } else col = bgCol;
    } else col = bgCol;
  }

  return clamp(col, 0., 1.);
}

void mainImage(out vec4 fragColor, vec2 fragCoord) {
  mat3 vuMat;
  vec4 mPtr;
  vec3 ro, rd;
  vec2 canvas, uv, ori, ca, sa;
  float el, az;
  canvas = iResolution.xy;
  uv = 2. * fragCoord.xy / canvas - 1.;
  uv.x *= canvas.x / canvas.y;
  tCur = iTime * SPEED;
  mPtr = iMouse;
  mPtr.xy = mPtr.xy / canvas - 0.5;
  az = 0.03 * pi * tCur;
  el = 0.2 * pi * sin(0.02 * pi * tCur);
  if (mPtr.z > 0.) {
    az = 2. * pi * mPtr.x;
    el = 0.6 * pi * mPtr.y;
  }
  tCur += 100.;
  el = clamp(el, -0.3 * pi, 0.3 * pi);
  ori = vec2(el, az);
  ca = cos(ori);
  sa = sin(ori);
  vuMat = mat3(ca.y, 0., -sa.y, 0., 1., 0., sa.y, 0., ca.y) *
      mat3(1., 0., 0., 0., ca.x, -sa.x, 0., sa.x, ca.x);
  ro = vec3(0.5);
  rd = vuMat * normalize(vec3(uv, 3.));
  ltDir = normalize(vec3(0.2, 1., -0.2));
  dstFar = 50.;
  fragColor = vec4(pow(ShowScene(ro, rd), vec3(0.8)), 1.);
}

const float cHashM = 43758.54;
float Hashfv2(vec2 p) {
  return fract(sin(dot(p, vec2(37., 39.))) * cHashM);
}
vec3 Hashv3v3(vec3 p) {
  vec3 cHashVA3 = vec3(37., 39., 41.);
  return fract(sin(vec3(dot(p, cHashVA3), dot(p + vec3(1, 0, 0), cHashVA3),
        dot(p + vec3(0, 1, 0), cHashVA3))) * cHashM);
}
