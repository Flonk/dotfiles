/*
// Intersection of a sphere of radius "r".
float traceSphere(in vec3 oc, in vec3 rd, float r){

	float b = dot(oc, rd);
    if(b > 0.) return 1e8;
	float c = dot(oc, oc) - r*r;
	float h = b*b - c;
	if(h<0.) return 1e8;
	return -b - sqrt(h);

}
*/

// Cotterzz's raytraced sphere fix: The standard function most
// of us use doesn't really cater for miniscule spheres. If speed
// was a concern and the spheres were larger (most of the time,
// they are), you could use the regular one.
float traceSphere(in vec3 oc, in vec3 rd, float r) {
  float b = dot(oc, rd);
  if (b > 0.) return 1e8;

  // OLD: catastrophic cancellation near silhouette edges
  // float c = dot(oc, oc) - r*r;
  // float h = b*b - c;

  // NEW: h = r² - |oc × rd|²  (stable, no large-minus-large)
  vec3 cx = cross(oc, rd);
  float h = r * r - dot(cx, cx);

  if (h < 0.) return 1e8;
  return -b - sqrt(h);
}

// Plane intersection: Old formula, and could do with some tidying up.
// The tiny "9e-7" figure is something I hacked in to stop near plane
// artifacts from appearing. I don't like it at all, but not a single
// formula I found deals with the problem. There definitely has to be
// a better way, so if someone knows of a more robust formula, I'd
// love to use it.
float tracePlane(vec3 ro, vec3 rd, vec3 n, vec3 o) {
  float t = 1e8;

  float ndotdir = dot(rd, n);

  if (ndotdir < 0.) {
    float dist = -(dot(ro - o, n) + 9e-7 * 0.) / ndotdir; // + 9e-7

    if (dist > 0.) {
      t = dist;
    }
  }

  return t;
}

// Two sphere distances, used for soft shadowing.
vec2 sphDistances(in vec3 ro, in vec3 rd, in vec4 sph)
{
  vec3 oc = ro - sph.xyz;
  float b = dot(oc, rd);
  float c = dot(oc, oc) - sph.w * sph.w;
  float h = b * b - c;
  float d = sqrt(max(0., sph.w * sph.w - h)) - sph.w;
  return vec2(d, -b - sqrt(max(h, 0.0)));
}

// IQ's soft shadow formula for spheres. He wrote an article on it
// that is worth the read.
//
// Related info: https://iquilezles.org/articles/spherefunctions
float sphSoftShadow(in vec3 ro, in vec3 rd, in vec4 sph)
{
  float s = 1.;
  vec2 r = sphDistances(ro, rd, sph);
  if (r.y > 0.0)
    s = max(r.x, 0.0) / r.y;
  return s;
}

/*

    Raytraced Transformed Spheres
    -----------------------------

    This is a rough sphere packing of a complex transformation. I wouldn't call this
    a textbook packing, but it's close enough. In particular, it is a rough
    reworking of "Electrostatics Vortices" by RandomDudeWhoCodes. The link is below
    for anyone who hasn't seen it.

    The idea is simple, but due to very few examples existing out there, it can be
    less than straight forward to implement. Basically, you transform some kind of
    grid -- In this case, it's a hexagon grid, since it lends itself well to packing
    2D circles. The local coordinates of the transformed grid cells will be warped,
    so use the inverse function to unwarp them and the derivative to determine
    relative cell size. Once you have that, you can render whatever you like, but
    circles (or spheres) make a lot of sense. The rest is just some basic raytracing,
    or 2D rendering, if preferred.

    Most of the work was performed by RandomDudeWhoCodes. The only thing I've done
    is color and shade things up a bit. I've also applied a couple of IQ's clever
    sphere shading routines. Anyway, the four pronged complex spiral transform here
    is just one of many possible transformations that this process would work with.
    At some stage, I'd like to try some others.



    Based on:

    // Fantastic example -- One of my favorites in a while.
    // It'd be great to see more of these.
    Electrostatics Vortices - randomdudewhocodes
    https://www.shadertoy.com/view/33tfWM
    Based on the following by Yann Le Gall... which if memory serves
    me correctly was based on one of Dan Piker's animations.
    https://x.com/yann_legall/status/1832136969914347703


    // Fabrice's simplified version, which is easier to follow.
    Electrostatics Vortices 2D - FabriceNeyret2
    https://www.shadertoy.com/view/tXcfRl

    // IQ's elegant example containing some of his elegant
    // sphere shading routines.
    Sphere - antialias
    https://www.shadertoy.com/view/MsSSWV
    //
    // Related info: https://iquilezles.org/articles/spherefunctions

*/

// I guess the 3D part is real, but some perspective hackery
// has been employed. Commenting this out will show the cleaner
// 2D version, which, in some ways, I prefer.
#define FAUX_3D

const float SPEED = 0.4;
#define T (iTime * SPEED)

// PI and 2 PI.
#define PI 3.14159265
#define TAU 6.2831853

// Standard 2D rotation formula.
mat2 rot2(in float a) {
  float c = cos(a), s = sin(a);
  return mat2(c, s, -s, c);
}

// Hash without Sine -- Dave Hoskins
// https://www.shadertoy.com/view/4djSRW
// 1 out, 2 in...
float hash21(vec2 p) {

  //p.y = mod(p.y, 2.);
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

// Common complex arithmetic functions. Most are self explanatory...
// provided you know a little bit about complex analysis. If you don't,
// it's not difficult to learn.
//vec2 conj(vec2 a){ return vec2(a.x, -a.y); }
vec2 cmul(vec2 a, vec2 b) {
  return mat2(a, -a.y, a.x) * b;
}
vec2 cinv(vec2 a) {
  return vec2(a.x, -a.y) / dot(a, a);
}
vec2 cdiv(vec2 a, vec2 b) {
  return cmul(a, cinv(b));
}
vec2 clog(in vec2 z) {
  return vec2(log(length(z)), atan(z.y, z.x));
}
vec2 cexp(vec2 z) {
  return exp(z.x) * vec2(cos(z.y), sin(z.y));
}
vec2 csqrt(vec2 z) {
  return cexp(clog(z) / 2.);
}
vec2 cpow(vec2 a, vec2 b) {
  return cexp(cmul(b, clog(a)));
}

// Hexagon grid dimension factor.
const vec2 s = vec2(sqrt(3.) / 2., .5);
// Polar angle wrapping factor -- to get things into the zero-to-one
// wrapping range when applying "fract", and so forth.
const vec2 wrap = s * 32. / TAU;

// Complex spirals.
vec2 map(vec2 z) {
  z = cmul(z, s); // Hexagon grid sizing.
  return cmul(wrap, clog(vec2(1, 0) + cdiv(vec2(2, 0),
          cpow(z, vec2(2, 0)) - vec2(1, 0))));
}

// Inverse function.
vec2 invMap(vec2 w) {
  return cdiv(csqrt(cdiv(vec2(2, 0), cexp(cdiv(w, wrap)) - vec2(1, 0)) + vec2(1, 0)), s);
}

// Analytic derivative. Numeric derivatives will work too.
vec2 map_derivative(vec2 z) {

  /*
                    // Numeric derivative.
                    float px = .01/iResolution.y;
                    vec2 dtX = (map(z + vec2(px, 0)) - map(z))/px;
                    vec2 dtY = (map(z + vec2(0, px)) - map(z))/px;
                    return vec2(length(dtX), length(dtY))/sqrt(2.);
                    */

  z = cmul(z, s);
  return -cmul(wrap, cdiv(z, cpow(z, vec2(4, 0)) - vec2(1, 0))) * 4.;
}

// Converting the ID back to pixel position.
vec2 HexIDPos(vec2 ip) {
  return vec2(ip.x + ip.y * s.y, ip.y * s.x);
}

// Central hexagon point, which can double as a unique cell ID.
vec2 hexID(vec2 p) {
  return round(vec2(p.x - p.y * s.x * 2. / 3., p.y / s.x));
}

// Different from "sign" in that it has no zero value.
float sgn(float x) {
  return x < 0. ? -1. : 1.;
}

void mainImage(out vec4 fragColor, vec2 fragCoord) {

  // Pixel coordinates.
  vec2 iR = iResolution.xy;
  vec2 uv = (fragCoord - iR * .5) / iR.y;

  //uv *= 1.15 - dot(uv, uv)*.3;

  // Rotating and scaling.
  vec2 p = rot2(T / 8. + PI / 12.) * uv * 2.5;

  // Loop number variable. "2" for a 2 by 2 loop, "3"
  // for a "3x3" loop, and so forth.
  int N = 3;

  // Spiral movement. The ID's are wrapped, so a modulo isn't necessary,
  // but it can be helpful to restrict large values where possible.
  vec2 tmOffs = vec2(mod(T, 8.), sqrt(3.) / 4.);
  if ((N & 1) == 0) tmOffs.y -= .5;

  // Complex transformation with animation component.
  vec2 trP = map(p) - tmOffs;

  // Obtaining the hexagon grid ID
  vec2 ip = hexID(trP);

  // Overall ID.
  vec2 id;

  // Disc and disc shadow distances.
  float d = 1e5, dSh = 1e5, dHi = 1e5;

  float t = 1e5, tSh = 1.;

  // Light direction -- Moving with the plane.
  vec2 ld = rot2(T / 8. + PI / 12.) * normalize(vec2(-1));

  vec3 col3 = vec3(0);

  float shadow = 1.;
  float minTSh = 1e5;

  // Circle distance.
  //float dI = length(p - invP) - r*.97;
  vec3 ro = vec3(0, 0, -32);
  // Going through to the central ground position to keep the
  // unit direction ray withing range.
  vec3 rd = normalize(vec3(p, 0) - ro);

  vec3 lp = vec3(2, 2, -12);

  vec3 sphPos;

  int objID;

  float svR = 0.;

  // Finding the nearst circle or sphere. There are 9 taps here, but
  // you could get away with a seven tap hexagon arrangement. I might
  // update to that later.
  for (int i = 0; i < N * N; i++) {

    // Offset ID.
    vec2 idOffs = ip + vec2(i % N, i / N) - float(N - 1) / 2.;

    // Converting the ID to the central hexagon position based ID.
    vec2 cntrID = HexIDPos(idOffs) + tmOffs;

    ////////
    // Using the inverse mapping to unwarp things back to
    // Euclidean space.
    vec2 invP = invMap(cntrID);
    // Mapping the results to the full domain. I'll assume this is
    // necessary since the mapping is not stricly one-to-one?
    invP *= sgn(dot(p, invP));

    // The cell size will vary with the derivative, so you need to
    // account for that. The "max(x, 2)" hack is there to counter some
    // blow-out effects on the peripheral.
    float r = .48 / max(length(map_derivative(invP)), 2.);
    //////////

    #ifdef FAUX_3D

    // Basic sphere and plane intersections.
    vec3 sphPosI = vec3(invP, -r);
    vec3 planePos = vec3(0, 0, 0);
    float tI = traceSphere(ro - sphPosI, rd, r);
    float tI2 = tracePlane(ro - planePos, rd, vec3(0, 0, -1), vec3(0));
    // Minimum scene distance.
    float minT = min(tI, tI2);

    // If this offset sample is closer, update.
    if (minT < t) {
      t = minT; // Distance.
      objID = tI < tI2 ? 0 : 1; // Object ID.
      sphPos = sphPosI; // Sphere position.
      id = idOffs; // Offset ID.
      svR = r; // Sphere radius.
    }

    // Shadows.
    vec3 p3 = ro + rd * minT;

    // Sphere normal or plane normal.
    vec3 n = objID == 0 ? normalize(p3 - sphPos) : vec3(0, 0, -1);

    // Point light, for shadow calculation.
    vec3 ld3 = normalize(lp - p3);
    ld3.xy = rot2(T / 8. + PI / 12.) * ld3.xy;

    // IQ's clever raytraced soft shadows for spheres. It's a bit of a
    // hidden gem that I don't see used very often.
    float minSh = sphSoftShadow(p3 + n * .0001, ld3, vec4(sphPosI, r));

    // Multiplying the soft shadows by a bit more to back off
    // the shadow range a bit.
    tSh = min(tSh, minSh * 2.);

    #else

    // 2D disc version. Obviously, this requires much less effort.

    // Cell circle distance.
    float dI = length(p - invP) - r * .98;

    // If it's closer, update the distance and ID.
    if (dI < d) {
      d = dI;
      id = idOffs;
    }

    // Last minute shadow distance.
    dSh = min(dSh, length(p - invP - ld * .04) - r);
    // Highlighting sample. Not used.
    dHi = min(dHi, length(p - invP - ld * .001) - r * .98);

    #endif
  }

  #ifdef FAUX_3D

  // Very basic 3D lighting.
  if (t < 1e5) {

    // Surface point.
    vec3 p3 = ro + rd * t;

    // Point lighting.
    vec3 ld3 = lp - p3;
    float lDist = length(ld3);
    ld3 /= lDist;
    ld3.xy = rot2(T / 8. + PI / 12.) * ld3.xy;
    //vec3 ld3 = normalize(vec3(1, 1, -1));

    // Sphere or plane normal.
    vec3 n = objID == 0 ? normalize(p3 - sphPos) : vec3(0, 0, -1);

    // Ambient light.
    //
    // Quick Lighting Tech - blackle
    // https://www.shadertoy.com/view/ttGfz1
    // Studio and outdoor.
    //float amb = pow(length(sin(n*2.)*.5 + .5), 2.);
    float amb = length(sin(n * 2.) * .5 + .5) / sqrt(3.) * smoothstep(-1., 1., -n.z);

    // Diffuse and specular.
    float diff = max(dot(n, ld3), 0.);
    float spec = pow(max(dot(reflect(ld3, n), rd), 0.), 32.);
    float specR = pow(max(dot(normalize(ld3 - rd), n), 0.), 5.);

    vec3 sCol = vec3(.2, .16, .12) * .7; // Plane color.

    // Sphere coloring.
    if (objID == 0) {
      // ID wrapping.
      id = mod(id, 8.);
      // ID value: Made up. The radial component needed reflecting across the
      // center. Not important, be it looks neater.
      id.x = abs(id.x - 4.) * 2.;
      // I wanted a hard edge, but you can reflect and scale the "Y" component also.
      //id.y = abs(id.y - 4.) + 3.;

      float val = (id.x + id.y * 8.) / 64.;
      // IQ's cosine color palette.
      sCol = .5 + .45 * cos(TAU * val * 1.07 + vec3(0, PI / 2., PI) * val * 1.07 + .5);
    }

    // Shadadows.
    float sh = tSh * .9 + .1;

    // Darkening near the vortices. It's not necessary, but looks better.
    sCol *= smoothstep(0., .05, svR);

    // Backscatter.
    float bf = max(dot(normalize(vec3(-ld3.xy, 0)), n), 0.);
    sCol += sCol * bf * .5;

    // Applying the lighting.
    col3 = sCol * (amb * .4 + diff * sh + spec * sh);

    // Adding a bit more depth.
    col3 *= .8 + n.y * .4;

    // Specular reflections.
    vec3 txR = texture(iChannel0, reflect(rd, n).xy * 0.5 + 0.5).xyz;
    txR *= txR;
    col3 += col3 * txR * specR * 2.;
  }
  #endif

  // 3D.
  #ifdef FAUX_3D
  vec3 col = col3;
  col = col / (2. + col) * 2.5; //tanh(col);  //
  #else

  // Wrapping the ID.
  id = mod(id, 8.);

  // ID value: Made up. The radial component needed reflecting across the
  // center. Not important, be it looks neater.
  float val = (abs(id.x - 4.) * 2. + id.y * 8.) / 64.; // Ordered.
  //float val = hash21(id + 56.); // Random.

  /*
                    // Intermittent holes, to break things up a bit.
                    //if(hash21(id + .04)<.65){ // Random.
                    if(mod(id.x + id.y, 2.)<.5){
                       float ew = .035;
                       d = abs(d + ew) - ew;
                       dSh = abs(dSh + ew) - ew;
                       dHi = abs(dHi + ew) - ew;
                    }
                    */

  // Object (disk) color.
  vec3 pCol = .5 + .45 * cos(TAU * val * 1.07 + vec3(0, PI / 2., PI) * val * 1.07 + .5);

  float b = max(.5 + (dHi - d) / .001, 0.);
  //pCol *= .5 + b*b*.5;

  // Background, shadow and object color layers.
  vec3 col = vec3(.3, .28, .25);
  col = mix(col, col * .5, 1. - smoothstep(0., 16. / 450., dSh));
  col = mix(col, pCol * .1, 1. - smoothstep(0., 2.5 / iR.y, d));
  col = mix(col, pCol, 1. - smoothstep(0., 2.5 / iR.y, d + .012));

  #endif

  // Vignette.
  uv = fragCoord / iR.xy;
  col *= pow(16. * uv.x * uv.y * (1. - uv.x) * (1. - uv.y), 1. / 16.) * 1.05;

  // Gamma correction and screen presentation.
  fragColor = vec4(pow(max(col, 0.), vec3(1) / 2.2), 1);
}
