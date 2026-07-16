// yamp: yasuo quadtree scene, X glyphs replaced by the and& ampersand.
// The build (convert-shaders.sh) concatenates NN_*.glsl in order, then
// shader.glsl:
//   00_knobs  — every tuning constant, incl. the mode table and playlist
//   10_lib    — generic helpers (rng, easing, squircle, stars)
//   20_modes  — mode sequencer machinery, structural-mode hooks
//   shader    — the scene: amp SDFs, quadtree, key indicator, mainImage
//
// Per tile, on its own clock (speed n*2*SPEED), the loop runs:
//   off (long) -> rotate (J/P counter-spin 360) -> off (short)
//   -> fill J (gradient wipe) -> fill P (offset wipe) -> on -> unfill -> loop
// sdJ/sdP sample a baked SDF texture (gen_sdf.py); the design gap (PAD) of
// the J is carved out of the P, so the pieces stay separated even mid-spin.
// Tiles are squircles (SQUIRCLENESS knob); the rim band refracts the content
// like glass (DISTORT knobs). The background noise (iChannel1) counter-scrolls
// and gets sucked toward each tile's rim, piling up into a bright event
// horizon that forms the border (PILE knobs) — no drawn ring.

// --- knobs ------------------------------------------------------------------
const float SPEED      = 0.8;    // global animation speed multiplier
const float T_OFF1     = 6.0;   // off, long (dark grey)
const float T_ROTATE   = 1.749; // J/P fast 360 spin
const float T_OFF2     = 2.5;   // off, short
const float T_FILL     = 1.104;  // duration of each white fill wipe
const float T_FILL_LAG = 0.067; // P wipe starts this long after J wipe
const float T_ON       = 2.;  // fully white hold
const float T_UNFILL   = 1.;  // wipes reverse out
const float T_REST     = 0.2;   // grey tail before the loop restarts

const float AMP_SCALE  = 0.94;  // glyph size within its tile
const float SCROLL     = 0.03; // vertical scroll speed
const float PAD_ZOOM   = 1.;   // how much tile content zooms out with the
                               // pad (1 = match the planet's shrink, 0 = off)

const float SQUIRCLENESS = 0.;   // tile shape: 0 = circle, 1 = square
const float DISTORT_BAND = 0.12;  // rim band that refracts

const float DARKEN = 0.25;        // off-amp darkening per subdivision level

const float NOISE_LO    = 0.0;   // background noise brightness range
const float NOISE_HI    = 0.05;
const float NOISE_SCALE = 3.0;   // background noise texture frequency
const float BG_SPEED    = 0.3;   // background scroll, fraction of SCROLL
const float STAR_BRIGHT = 0.7;   // starfield brightness
const float STAR_CELL   = 6.;    // star spacing in screen pixels (sheet 1)
const float STAR_R      = 0.9;   // star radius, screen pixels
const float STAR_POW    = 17.;   // brightness distribution (lower = denser)
const float STAR_DRIFT  = 0.01;  // second-sheet drift for depth parallax

// baked kaliset nebula (gen_nebula.py): the texture holds the two raw
// field layers, colored live below
const float NEB_SCALE   = 0.25;  // nebula frequency vs the background coords
const vec3  NEB1_COL    = vec3(0.20, 0.35, 0.80); // layer 1: blue wash
const float NEB1_BRIGHT = 0.9;
const vec3  NEB2_COL    = vec3(1.50, 0.50, 0.40); // layer 2: orange filaments
const float NEB2_BRIGHT = 1.8;

const float PILE_BAND = 0.001;    // event-horizon falloff width (tile units)
const float PILE_PULL = 0.35;    // how far the noise is sucked inward (uv units)
const float PILE_GAIN = 7.;      // brightness pile-up at the horizon

const float SCROLL_MIN = 0.045;  // tile content scroll speed, random per tile
const float SCROLL_MAX = 0.09;

// mode transitions ease over TRANS_DUR; the global zoom flips on ZOOM_PERIOD,
// offset by half — tuned so with the default two-mode playlist the four
// quarters run 2d-in, 2d-out, 3d-out, 3d-in
const float TRANS_DUR   = 1.2;   // mode/zoom flip transition duration
const float ZOOM_PERIOD = 60. * 8.; // seconds per zoom flip
const float ZOOM_OUT    = 0.30;  // global zoom-out amount
const float ZOOM_ECC    = 5.7;   // zoom target distance from screen center
const float ZOOM_DRIFT  = 2300.7;  // zoom target orbit period (s) — offbeat
                                 // vs ZOOM_PERIOD so the spot always differs

const float RING_BRIGHT = 0.3;    // border ring brightness
const float RING_WIDTH  = 0.0025; // border ring half-width, screen-height
                                  // units — same thickness at every level

// 3d planet dressing (after Otavio Good's CC0 planet shader): a sun drifts
// around the top; each tile gets a blinn-phong glint, domain-warped clouds
// and an atmosphere ("aurora") tint on its event horizon. per-mode
// strengths live in the mode table (spec/cloud/aur)
const float SUN_PERIOD = 397.;   // sun azimuth drift period (s)
const float SUN_SWING  = 0.9;    // sun azimuth swing amplitude
const float SUN_HEIGHT = 1.8;    // sun elevation
const float SUN_Z      = 0.7;    // sun toward-viewer component
const vec3  SUN_COL    = vec3(1.66, 1.39, 0.87); // warm sun tint
const vec3  SUN_WHITE  = vec3(1.31);             // mono-mode sun tint
const float SPEC_POW   = 12.;    // glint tightness
const float SPEC_GAIN  = 0.3;    // sun reflection strength

const float CLOUD_SCALE = 1.1;   // cloud texture frequency (tile units)
const float CLOUD_DRIFT = 0.012; // cloud scroll speed
const float CLOUD_WARP  = 1.2;   // vortex swirl strength (x the blurry sample)
const float CLOUD_SHARP = 0.8;   // contrast exponent (lower = denser)
const float CLOUD_GAIN  = 3.;    // coverage boost after sharpening
const float CLOUD_HEIGHT = 0.04; // shell height: shadow offset sunward (tile units)
const float CLOUD_SHADOW = 0.75; // ground darkening under the cloud shell
const float CLOUD_FADE   = 0.1;  // cloud thinning band at the shell edge (tile units)

// full-planet terrain (terra field): the tile interior becomes ocean, the
// amps land, the filled amps high terrain; the sun then only reflects off
// the water. the amp SDFs double as height fields: distance to the coast
// drives shelves/beaches/snowlines, and its gradient drives the emboss
const vec3 WATER_COL   = vec3(0.02, 0.09, 0.18); // deep ocean
const vec3 WATER_SHALL = vec3(0.05, 0.22, 0.28); // shallow shelf at coasts
const float COAST_W    = 0.06;  // shallow shelf width (amp units) — must
                                // stay inside the SDF clamp (~0.07 usable)
const vec3 SAND_COL    = vec3(0.55, 0.47, 0.26); // beach ring
const float SAND_W     = 0.035; // beach ring width
const vec3 LAND_COL    = vec3(0.10, 0.19, 0.11); // low terrain (amps), muted
const vec3 HIGH_BOT    = vec3(0.45, 0.32, 0.18); // high terrain: rim rock...
const vec3 HIGH_TOP    = vec3(0.95, 0.95, 0.90); // ...to snowfields
const float SNOW_D     = 0.05;  // rock-to-snow rim width (amp units)
const float SNOW_DETAIL = 0.35; // how much detail mottling shows on snow
const float DETAIL_SCALE = 5.;  // terrain detail texture frequency
const float DETAIL_AMT   = 0.6; // terrain detail brightness modulation
const vec3  SPECK_COL  = vec3(0.30, 0.20, 0.10); // lowland dirt specks
const float SPECK_SCALE = 3.7;  // speck texture frequency
const float SPECK_WARP  = 1.5;  // speck spiral distortion
const float SPECK_LO    = 0.25; // speck threshold window (squared sample)
const float SPECK_HI    = 0.55;
const float SPECK_AMT   = 0.8;  // speck opacity on the lowland
const float CORNER_ROUND = 0.02; // round off sharp glyph corners (amp units)
const float COASTF_AMT   = 0.05; // baked coastline fbm amplitude (amp units)
const float AMP_PAD      = 0.25; // shrink amps within their cells so the
                                 // coast bands fit before the cell boundary
const float RELIEF     = 0.4;   // emboss strength at coasts/ridges (negative flips)
const float RELIEF_W   = 0.05;  // emboss band width (amp units), zero beyond

const vec3  AUR_COLOR   = vec3(0.15, 0.5, 1.0);  // atmosphere glow color
const vec3  AUR_SUNSET  = vec3(1.9, 0.5, 0.08);  // sun-facing rim color
const float AUR_SUN_POW = 1.;    // sunset concentration on the sun side
const float AUR_GLOW    = 0.25;  // additive horizon glow strength
const vec3  HAZE_COL    = vec3(0.45, 0.60, 0.85); // haze tint, desaturated
const float ATMO_BASE   = 0.12;  // constant atmosphere veil over the disc
const float ATMO_HAZE   = 0.45;  // limb haze: extra tint at the rim
const float ATMO_POW    = 2.;    // haze concentration toward the limb

// warhol mode: tiles become flat pop-color squares, no pad, no borders.
// each square hashes a palette color and a normal/inverted flip; the fill
// wipe becomes a pulse with a gradient tail — transparent toward the seed,
// solid at the wavefront. normal = black bg, amps printed in the color,
// pulsing to black; inverted = color bg, black amps, pulsing to
// color*WARHOL_FILL. colors are oklch-matched to the andamp blue (same
// lightness/chroma, rotated hue)
const vec3 WARHOL_COLS[4] = vec3[4](
    vec3(0.138, 0.633, 0.717),   // andamp blue
    vec3(0.768, 0.456, 0.581),   // pink
    vec3(0.482, 0.619, 0.336),   // lime
    vec3(0.764, 0.495, 0.304));  // orange
const float WARHOL_INV  = 0.5;   // chance a square is inverted
const float WARHOL_FILL = 1.2;   // pulse brightness x the base color (inverted)
const float PULSE_W     = 0.35;  // pulse gradient tail width (glyph units)

// key indicator: on keypress a black circle fills the screen while a blue
// amp zooms in; each key bumps the amp, errors turn it red, inactivity
// reverses everything
const float IND_AMP    = 0.1;   // indicator amp scale (screen units)
const float IND_BUMP   = 0.04;   // per-key amp scale bump
const float IND_BRIGHT = 0.35;   // per-key brightness bump (toward white)
const float IND_LAG    = 0.08;   // circle leads the amp by this, in and out

// and& brand gradient, sampled from andamp-amp-blue.png (top -> bottom)
const vec3 GRAD_TOP = vec3(0.212, 0.671, 0.729);
const vec3 GRAD_BOT = vec3(0.063, 0.596, 0.706);

// --- modes -------------------------------------------------------------------
// a mode is one ModeParams entry in the playlist below; the sequencer
// (20_modes) walks it, easing between neighbours over TRANS_DUR
struct ModeParams {
    float pad;      // squircle padding to its cell edge
    float bg;       // background noise + stars visibility
    float light;    // sun diffuse: lift on the sunlit side toward white
    float dark;     // sun diffuse: shadow on the night side toward black
    float ring;     // border ring visibility (styled by RING_BRIGHT/RING_WIDTH)
    float distort;  // glass refraction strength at the tile rim
    float wham;     // extra global zoom-out
    float spec;     // sun specular glint strength
    float cloud;    // cloud coverage
    float aur;      // aurora: atmosphere tint + glow on the event horizon
    float warm;     // sun glint tint: 0 = SUN_WHITE, 1 = SUN_COL
    float terra;    // terrain palette: ocean interior, land amps,
                    // high-terrain fills, water-only glint
    float neb;      // kaliset nebula visibility in the background
    float star;     // starfield density (scales the brightness power law)
    float squir;    // tile squareness on top of SQUIRCLENESS (1 = square)
    float warhol;   // pop-palette strength (per-square colors + inversion)
    float big;      // chance a cell promotes to one huge amp
};

// each step grows the pad and zooms in (wham) — visual complexity goes up,
// so fewer but bigger planets. the event horizon dies out within the pad,
// so cells of different levels stay continuous
const int MODE_COUNT = 5;
const ModeParams MODES[MODE_COUNT] = ModeParams[MODE_COUNT](
    //         pad   bg  light dark  ring distort wham   spec cloud aur  warm terra neb  star squir warhol big
    // 2d base: flat — border ring, no noise/stars/shade/distortion
    ModeParams(0.01, 0., 0.,   0.,   1.,  0.,     0.,    0.,  0.,   0.,  0.,  0.,   0.,  0.,   0.,  0.,  0.15),
    // 3d mono: sparse starfield, white horizon (the old aurora), white sun
    ModeParams(0.25, 1., 0.25, 0.75, 0.,  0.12,   -0.3,  0.6, 0.,   0.,  0.,  0.,   0.,  0.25, 0.,  0.,  0.15),
    // 3d full: colored aurora, warm sun, clouds, ocean + terrain, nebula
    ModeParams(0.45, 1., 0.25, 0.75, 0.,  0.12,   -0.65, 0.6, 1.,   1.,  1.,  1.,   1.,  3.,   0.,  0.,  0.15),
    // back to base before the pop hits
    ModeParams(0.01, 0., 0.,   0.,   1.,  0.,     0.,    0.,  0.,   0.,  0.,  0.,   0.,  0.,   0.,  0.,  0.15),
    // warhol: flat pop-color squares, normal/inverted per tile, more bigs
    ModeParams(0.,   0., 0.,   0.,   0.,  0.,     0.,    0.,  0.,   0.,  0.,  0.,   0.,  0.,   1.,  1.,  0.85)
);

const float D = 480.;
const float MODE_DUR[MODE_COUNT] = float[MODE_COUNT](D, D, D, D, D);

// two super-modes, each opening on the circles base block: the planets arc
// is blocks 0-2 (circles -> 3d balls -> planets), the warhol arc blocks 3-4
// (circles -> squares); sk_seed(2) decides which arc a session opens on
const int   WARHOL_START = 3;    // playlist index of the warhol arc's circles block
const float WARHOL_FIRST = 0.5;  // chance a session opens on the warhol arc

// derived state boundaries — don't touch, tune the knobs above
const float ROT_START    = T_OFF1;
const float FILLJ_START  = ROT_START + T_ROTATE + T_OFF2;
const float FILLP_START  = FILLJ_START + T_FILL_LAG;
const float ON_START     = FILLP_START + T_FILL;
const float UNFILL_START = ON_START + T_ON;
const float LOOP_LEN     = UNFILL_START + T_UNFILL + T_REST;
