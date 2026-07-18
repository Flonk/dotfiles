// and& logo — J / P decomposition, exact SDFs from the brand SVG
// The mark is two shapes: sdP = upper loop whose tail runs continuously
// down to the bottom-right triangle, sdJ = hook + diagonal laid OVER it.
// sdLogo carves the dilated J out of P, re-creating the designed split.
// PAD is the actual gap measured from the artwork (~20.5 svg units).
// Shape lives in ~[-0.43,0.43] x [-0.5,0.5].

const int NJ = 41;              // segments [0,NJ) = J
const int NSEG = 76;         // segments [NJ,NSEG) = P
const float PAD = 0.0464;      // design gap, measured from the artwork
const vec2 S[228] = vec2[228](
vec2(0.0145,-0.2568),vec2(-0.0054,-0.2725),vec2(-0.0252,-0.2885),vec2(-0.0252,-0.2885),vec2(-0.0755,-0.3300),vec2(-0.1287,-0.3307),
vec2(-0.1287,-0.3307),vec2(-0.1819,-0.3314),vec2(-0.2145,-0.2930),vec2(-0.2145,-0.2930),vec2(-0.2470,-0.2530),vec2(-0.2433,-0.2057),
vec2(-0.2433,-0.2057),vec2(-0.2396,-0.1583),vec2(-0.1967,-0.1199),vec2(-0.1967,-0.1199),vec2(-0.1827,-0.1079),vec2(-0.1688,-0.0958),
vec2(-0.1688,-0.0958),vec2(-0.1782,-0.0836),vec2(-0.1902,-0.0675),vec2(-0.1902,-0.0675),vec2(-0.2022,-0.0514),vec2(-0.2156,-0.0326),
vec2(-0.2156,-0.0326),vec2(-0.2291,-0.0139),vec2(-0.2425,0.0061),vec2(-0.2425,0.0061),vec2(-0.2560,0.0261),vec2(-0.2682,0.0461),
vec2(-0.2682,0.0461),vec2(-0.2865,0.0305),vec2(-0.3047,0.0147),vec2(-0.3047,0.0147),vec2(-0.3491,-0.0207),vec2(-0.3794,-0.0696),
vec2(-0.3794,-0.0696),vec2(-0.4097,-0.1184),vec2(-0.4201,-0.1724),vec2(-0.4201,-0.1724),vec2(-0.4305,-0.2264),vec2(-0.4179,-0.2841),
vec2(-0.4179,-0.2841),vec2(-0.4053,-0.3418),vec2(-0.3624,-0.3965),vec2(-0.3624,-0.3965),vec2(-0.3225,-0.4498),vec2(-0.2633,-0.4734),
vec2(-0.2633,-0.4734),vec2(-0.2041,-0.4971),vec2(-0.1427,-0.4986),vec2(-0.1427,-0.4986),vec2(-0.0813,-0.5000),vec2(-0.0244,-0.4831),
vec2(-0.0244,-0.4831),vec2(0.0326,-0.4660),vec2(0.0696,-0.4394),vec2(0.0696,-0.4394),vec2(0.0946,-0.4198),vec2(0.1194,-0.4000),
vec2(0.1194,-0.4000),vec2(0.1471,-0.3765),vec2(0.1757,-0.3513),vec2(0.1757,-0.3513),vec2(0.2043,-0.3261),vec2(0.2276,-0.3054),
vec2(0.2276,-0.3054),vec2(0.2512,-0.2842),vec2(0.2648,-0.2722),vec2(0.2648,-0.2722),vec2(0.3451,-0.1976),vec2(0.4253,-0.1228),
vec2(0.4253,-0.1228),vec2(0.3677,-0.0599),vec2(0.3100,0.0029),vec2(0.3100,0.0029),vec2(0.3098,0.0028),vec2(0.3042,-0.0024),
vec2(0.3042,-0.0024),vec2(0.2987,-0.0076),vec2(0.2890,-0.0165),vec2(0.2890,-0.0165),vec2(0.2794,-0.0254),vec2(0.2671,-0.0368),
vec2(0.2671,-0.0368),vec2(0.2548,-0.0481),vec2(0.2413,-0.0605),vec2(0.2413,-0.0605),vec2(0.2279,-0.0730),vec2(0.2146,-0.0851),
vec2(0.2146,-0.0851),vec2(0.2013,-0.0973),vec2(0.1897,-0.1079),vec2(0.1897,-0.1079),vec2(0.1781,-0.1185),vec2(0.1695,-0.1262),
vec2(0.1695,-0.1262),vec2(0.1610,-0.1339),vec2(0.1569,-0.1373),vec2(0.1569,-0.1373),vec2(0.1528,-0.1407),vec2(0.1447,-0.1475),
vec2(0.1447,-0.1475),vec2(0.1366,-0.1543),vec2(0.1257,-0.1634),vec2(0.1257,-0.1634),vec2(0.1149,-0.1725),vec2(0.1026,-0.1829),
vec2(0.1026,-0.1829),vec2(0.0903,-0.1932),vec2(0.0778,-0.2037),vec2(0.0778,-0.2037),vec2(0.0653,-0.2141),vec2(0.0540,-0.2236),
vec2(0.0540,-0.2236),vec2(0.0427,-0.2331),vec2(0.0338,-0.2406),vec2(0.0338,-0.2406),vec2(0.0249,-0.2480),vec2(0.0198,-0.2524),
vec2(0.0198,-0.2524),vec2(0.0147,-0.2567),vec2(0.0145,-0.2568),vec2(-0.1235,-0.0770),vec2(-0.1090,-0.0954),vec2(-0.0901,-0.1189),
vec2(-0.0901,-0.1189),vec2(-0.0711,-0.1424),vec2(-0.0529,-0.1647),vec2(-0.0529,-0.1647),vec2(-0.0347,-0.1869),vec2(-0.0227,-0.2015),
vec2(-0.0227,-0.2015),vec2(-0.0107,-0.2160),vec2(-0.0103,-0.2166),vec2(-0.0103,-0.2166),vec2(0.0746,-0.3221),vec2(0.1596,-0.4274),
vec2(0.1596,-0.4274),vec2(0.1798,-0.4542),vec2(0.2001,-0.4809),vec2(0.2001,-0.4809),vec2(0.3153,-0.4810),vec2(0.4305,-0.4808),
vec2(0.4305,-0.4808),vec2(0.3624,-0.3949),vec2(0.2941,-0.3091),vec2(0.2941,-0.3091),vec2(0.2108,-0.2055),vec2(0.1273,-0.1020),
vec2(0.1273,-0.1020),vec2(0.0393,0.0090),vec2(-0.0488,0.1198),vec2(-0.0488,0.1198),vec2(-0.0784,0.1538),vec2(-0.0954,0.1812),
vec2(-0.0954,0.1812),vec2(-0.1124,0.2085),vec2(-0.1094,0.2456),vec2(-0.1094,0.2456),vec2(-0.1036,0.2855),vec2(-0.0783,0.3069),
vec2(-0.0783,0.3069),vec2(-0.0532,0.3283),vec2(-0.0147,0.3284),vec2(-0.0147,0.3284),vec2(0.0237,0.3284),vec2(0.0526,0.3010),
vec2(0.0526,0.3010),vec2(0.0814,0.2736),vec2(0.0977,0.2263),vec2(0.0977,0.2263),vec2(0.1761,0.2551),vec2(0.2545,0.2840),
vec2(0.2545,0.2840),vec2(0.2441,0.3284),vec2(0.2190,0.3683),vec2(0.2190,0.3683),vec2(0.1938,0.4083),vec2(0.1576,0.4371),
vec2(0.1576,0.4371),vec2(0.1213,0.4660),vec2(0.0755,0.4830),vec2(0.0755,0.4830),vec2(0.0296,0.5000),vec2(-0.0236,0.5000),
vec2(-0.0236,0.5000),vec2(-0.0769,0.5000),vec2(-0.1249,0.4822),vec2(-0.1249,0.4822),vec2(-0.1731,0.4645),vec2(-0.2100,0.4334),
vec2(-0.2100,0.4334),vec2(-0.2470,0.4023),vec2(-0.2685,0.3580),vec2(-0.2685,0.3580),vec2(-0.2899,0.3136),vec2(-0.2914,0.2603),
vec2(-0.2914,0.2603),vec2(-0.2929,0.2293),vec2(-0.2899,0.2071),vec2(-0.2899,0.2071),vec2(-0.2870,0.1849),vec2(-0.2810,0.1671),
vec2(-0.2810,0.1671),vec2(-0.2810,0.1669),vec2(-0.2775,0.1591),vec2(-0.2775,0.1591),vec2(-0.2741,0.1512),vec2(-0.2677,0.1383),
vec2(-0.2677,0.1383),vec2(-0.2613,0.1254),vec2(-0.2526,0.1099),vec2(-0.2526,0.1099),vec2(-0.2439,0.0945),vec2(-0.2333,0.0791),
vec2(-0.2333,0.0791),vec2(-0.2329,0.0785),vec2(-0.2214,0.0614),vec2(-0.2214,0.0614),vec2(-0.2099,0.0444),vec2(-0.1923,0.0189),
vec2(-0.1923,0.0189),vec2(-0.1748,-0.0066),vec2(-0.1563,-0.0325),vec2(-0.1563,-0.0325),vec2(-0.1378,-0.0585),vec2(-0.1235,-0.0770)
);
float dot2(vec2 v) { return dot(v,v); }

// unsigned distance to a quadratic bezier — iq, https://iquilezles.org/articles/distfunctions2d
float udBezier(vec2 pos, vec2 A, vec2 B, vec2 C)
{
    vec2 a = B - A, b = A - 2.0*B + C, c = a*2.0, d = A - pos;
    float kk = 1.0/dot(b,b);
    float kx = kk * dot(a,b);
    float ky = kk * (2.0*dot(a,a)+dot(d,b))/3.0;
    float kz = kk * dot(d,a);
    float p  = ky - kx*kx;
    float q  = kx*(2.0*kx*kx - 3.0*ky) + kz;
    float h  = q*q + 4.0*p*p*p;
    float res;
    if (h >= 0.0)
    {
        h = sqrt(h);
        vec2 x = (vec2(h,-h)-q)/2.0;
        vec2 uv = sign(x)*pow(abs(x), vec2(1.0/3.0));
        float t = clamp(uv.x+uv.y-kx, 0.0, 1.0);
        res = dot2(d + (c + b*t)*t);
    }
    else
    {
        float z = sqrt(-p);
        float v = acos(q/(p*z*2.0))/3.0;
        float m = cos(v), n = sin(v)*1.732050808;
        vec2 t = clamp(vec2(m+m,-n-m)*z - kx, 0.0, 1.0);
        res = min(dot2(d+(c+b*t.x)*t.x), dot2(d+(c+b*t.y)*t.y));
    }
    return sqrt(res);
}

// exact SDF of segments [i0,i1) of S — one closed even-odd shape
float sdShape(vec2 p, int i0, int i1)
{
    float d = 1e9;
    bool inside = false;
    for (int i = i0; i < i1; i++)
    {
        vec2 A = S[3*i], B = S[3*i+1], C = S[3*i+2];
        d = min(d, udBezier(p, A, B, C));

        // even-odd: horizontal +x ray, roots of y(t) = p.y on this segment
        float ay = A.y - 2.0*B.y + C.y;
        float by = B.y - A.y;
        float cy = A.y - p.y;
        float ax = A.x - 2.0*B.x + C.x;
        float bx = B.x - A.x;
        if (abs(ay) < 1e-5)
        {
            if (abs(by) > 1e-7)
            {
                float t = cy / (-2.0*by);
                if (t >= 0.0 && t < 1.0 && ax*t*t + 2.0*bx*t + A.x > p.x) inside = !inside;
            }
        }
        else
        {
            float disc = by*by - ay*cy;
            if (disc > 0.0)
            {
                // numerically stable quadratic roots (citardauq)
                float r  = sqrt(disc) * (by >= 0.0 ? 1.0 : -1.0);
                float hh = -(by + r);
                float t1 = hh/ay;
                float t2 = cy/hh;
                if (t1 >= 0.0 && t1 < 1.0 && ax*t1*t1 + 2.0*bx*t1 + A.x > p.x) inside = !inside;
                if (t2 >= 0.0 && t2 < 1.0 && ax*t2*t2 + 2.0*bx*t2 + A.x > p.x) inside = !inside;
            }
        }
    }
    return inside ? -d : d;
}

// the J: bottom-left hook + long diagonal sweep
float sdJ(vec2 p) { return sdShape(p, 0, NJ); }

// the P: upper loop + tail, one continuous stroke through to the
// bottom-right triangle (the artwork's cut is undone)
float sdP(vec2 p) { return sdShape(p, NJ, NSEG); }

// full mark: J over P — carve the J (dilated by the design gap) out of P
float sdLogo(vec2 p)
{
    float dj = sdJ(p);
    float dp = sdP(p);
    return min(dj, max(dp, PAD - dj));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 p = (2.0*fragCoord - iResolution.xy) / iResolution.y;
    p *= 1.35;

    float d  = sdLogo(p);
    float px = 2.7 / iResolution.y;   // ~1 pixel in SDF units

    vec3 col = vec3(smoothstep(px, -px, d));
    fragColor = vec4(col, 1.0);
}