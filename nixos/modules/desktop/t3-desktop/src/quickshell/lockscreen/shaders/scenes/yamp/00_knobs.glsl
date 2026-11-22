const float SPEED      = 0.8;
const float T_OFF1     = 6.0;
const float T_ROTATE   = 1.749;
const float T_OFF2     = 2.5;
const float T_FILL     = 1.104;
const float T_FILL_LAG = 0.067;
const float T_ON       = 2.;
const float T_UNFILL   = 1.;
const float T_REST     = 0.2;

const float NOISE_LO    = 0.0;
const float NOISE_HI    = 0.05;
const float NOISE_SCALE = 3.0;
const float BG_SPEED    = 0.3;
const float SCROLL      = 0.03;

const float TRANS_DUR   = 1.2;
const float ZOOM_PERIOD = 60. * 8.;
const float ZOOM_OUT    = 0.30;

const float PROGRESS_H  = 2.;
const float ZOOM_ECC    = 5.7;
const float ZOOM_DRIFT  = 2300.7;

const float FILM_GRAIN = 0.15;
const float FILM_FPS   = 24.;

const float IND_AMP    = 0.1;
const float IND_BUMP   = 0.04;
const float IND_BRIGHT = 0.35;
const float IND_LAG    = 0.08;

const vec3 GRAD_TOP = vec3(0.212, 0.671, 0.729);
const vec3 GRAD_BOT = vec3(0.063, 0.596, 0.706);

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
const int MODE_FLUID    = 12;
const int MODE_FLAP     = 13;
const int MODE_GRID     = 14;
const int MODE_STARS    = 15;
const int MODE_SHATTER  = 16;
const int MODE_TITLE    = 17;
const int MODE_IRIS   = 18;
const int MODE_INK    = 19;
const int MODE_TYPE   = 20;
const int MODE_PEEL   = 21;
const int MODE_GLITCH = 22;
const int MODE_BLINDS = 23;
const int MODE_STAMP  = 24;
const int MODE_FISH     = 25;
const int MODE_TRAFFIC  = 26;
const int MODE_CONVEYOR = 27;
const int MODE_COUNT    = 28;

const float MODE_AA[MODE_COUNT]    = float[MODE_COUNT](0., 0., 0., 1., 1., 1., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0.);
const float MODE_GRAIN[MODE_COUNT] = float[MODE_COUNT](0., 0., 0., 0., 0., 1., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., 0.);

const float D = 180.;
const float T_FLAP = 10.5;
const float T_SHATTER = 9.5;
const float T_TITLE = 6.;
const float T_IRIS = 6.5;
const float T_INK = 7.0;
const float T_TYPE = 7.0;
const float T_PEEL = 7.0;
const float T_GLITCH = 6.0;
const float T_BLINDS = 7.0;
const float T_STAMP = 6.5;
const float TRANS_AMP = 0.546;

const float MODE_DUR[MODE_COUNT] = float[MODE_COUNT](D, D, D, D, D, D, D, D, D, D, D, D, D, T_FLAP, D, D, T_SHATTER, T_TITLE, T_IRIS, T_INK, T_TYPE, T_PEEL, T_GLITCH, T_BLINDS, T_STAMP, D, D, D);

const float ROT_START    = T_OFF1;
const float FILLJ_START  = ROT_START + T_ROTATE + T_OFF2;
const float FILLP_START  = FILLJ_START + T_FILL_LAG;
const float ON_START     = FILLP_START + T_FILL;
const float UNFILL_START = ON_START + T_ON;
const float LOOP_LEN     = UNFILL_START + T_UNFILL + T_REST;
