// yamp: and& ampersand lockscreen, cycling through a playlist of modes.
// The build (convert-shaders.sh) concatenates NN_*.glsl in order, then
// shader.glsl:
//   00_knobs   — shared tuning constants, the mode table and playlist
//   10_lib     — generic helpers (rng, easing, sdf primitives, ray/box, grain)
//   20_modes   — mode sequencer machinery
//   30_amp     — glyph SDF and the per-amp spin/fill clock
//   40..42     — 2d modes: tiles (quadtree), field, drop
//   50_solid   — raymarched 3d amp, 3d amp mode and halftone
//   60..63     — shadow room: structure, outlet, phone, render
//   shader     — key indicator, mainImage
// Mode-specific knobs live at the top of their mode's file.
//
// Per amp, on its own clock (speed n*2*SPEED), the loop runs:
//   off (long) -> rotate (J/P counter-spin 360) -> off (short)
//   -> fill J (gradient wipe) -> fill P (offset wipe) -> on -> unfill -> loop
// sdJ/sdP sample a baked SDF texture (gen_sdf.py); the design gap (PAD) of
// the J is carved out of the P, so the pieces stay separated even mid-spin.

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

const float NOISE_LO    = 0.0;   // background noise brightness range
const float NOISE_HI    = 0.05;
const float NOISE_SCALE = 3.0;   // background noise texture frequency
const float BG_SPEED    = 0.3;   // background scroll, fraction of SCROLL
const float SCROLL      = 0.03;  // vertical scroll speed

// mode transitions circle-wipe over WIPE_DUR; the global zoom flips on
// ZOOM_PERIOD, offset by half
const float TRANS_DUR   = 1.2;   // zoom flip duration
const float WIPE_DUR    = 0.4;
const float ZOOM_PERIOD = 60. * 8.; // seconds per zoom flip
const float ZOOM_OUT    = 0.30;  // global zoom-out amount
const float ZOOM_ECC    = 5.7;   // zoom target distance from screen center
const float ZOOM_DRIFT  = 2300.7;  // zoom target orbit period (s) — offbeat
                                 // vs ZOOM_PERIOD so the spot always differs

const float FILM_GRAIN = 0.15;
const float FILM_FPS   = 24.;

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
// the playlist runs the modes in order, MODE_DUR each; the sequencer
// (20_modes) circle-wipes between neighbours over WIPE_DUR
const int MODE_TILES    = 0;
const int MODE_FIELD    = 1;
const int MODE_DROP     = 2;
const int MODE_SOLID    = 3;
const int MODE_HALFTONE = 4;
const int MODE_SHADOW   = 5;
const int MODE_PENROSE  = 6;
const int MODE_SCOPE    = 7;
const int MODE_SPECTRUM = 8;
const int MODE_PRISM    = 9;
const int MODE_GASKET   = 10;
const int MODE_GRAVITY  = 11;
const int MODE_COUNT    = 12;

const float MODE_AA[MODE_COUNT]    = float[MODE_COUNT](0., 0., 0., 1., 1., 1., 0., 0., 0., 0., 0., 0.);
const float MODE_GRAIN[MODE_COUNT] = float[MODE_COUNT](0., 0., 0., 0., 0., 1., 0., 0., 0., 0., 0., 0.);

const float D = 480.;
const float MODE_DUR[MODE_COUNT] = float[MODE_COUNT](D, D, D, D, D, D, D, D, D, D, D, D);

// derived state boundaries — don't touch, tune the knobs above
const float ROT_START    = T_OFF1;
const float FILLJ_START  = ROT_START + T_ROTATE + T_OFF2;
const float FILLP_START  = FILLJ_START + T_FILL_LAG;
const float ON_START     = FILLP_START + T_FILL;
const float UNFILL_START = ON_START + T_ON;
const float LOOP_LEN     = UNFILL_START + T_UNFILL + T_REST;
