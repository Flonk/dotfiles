#version 300 es
precision highp float;
precision highp int;

// ---------------------------------------------------------------------------
// Shadertoy-compatible inputs
// ---------------------------------------------------------------------------

/// Viewport size in pixels (z is always 1.0).
uniform vec3 iResolution;

/// Seconds elapsed since the renderer was created (lock start).
uniform float iTime;

/// Frame counter, incremented every rendered frame.
uniform int iFrame;

/// Always (0, 0, 0, 0) — the lockscreen receives no mouse input.
uniform vec4 iMouse;

/// Current time as four decimal clock digits:
///   x = hours tens,   y = hours ones
///   z = minutes tens, w = minutes ones
/// e.g. 09:45 → (0.0, 9.0, 4.0, 5.0)
uniform vec4 iClock;

/// 32 random floats in [0,1), rerolled by the host each time the shader
/// pass is created. Read them via sk_seed(i), i in 0..31, to vary a scene
/// per session (reseed hashes, pick a starting mode, ...).
uniform mat4 iSeed0;
uniform mat4 iSeed1;

// Up to four named input textures, resolved from the shader bundle's channel list.
// Unbound slots fall back to a 1×1 dark fallback texture.
uniform sampler2D iChannel0;
uniform sampler2D iChannel1;
uniform sampler2D iChannel2;
uniform sampler2D iChannel3;

// ---------------------------------------------------------------------------
// Lockscreen-specific inputs
// ---------------------------------------------------------------------------

/// Indicator overlay type drawn on top of the shader output by the host footer.
///   0 = none
///   1 = small circle centred on screen (keypress dot)
///   2 = full-screen colour flash (failed unlock / auth feedback)
uniform int u_indicator_type;

/// RGB colour in [0, 1] for the active indicator.
uniform vec3 u_indicator_color;

/// iTime value recorded at the last keypress (-1000.0 before any key is pressed).
uniform float u_last_key_time;

/// Envelope bases recorded by the host at the moment of the last keypress,
/// so that mid-animation keypresses ramp up from the current level, not zero.
///   x = keypulse base  (for the 30 ms flash / 80 ms decay envelope)
///   y = key base       (for the 60 ms ramp  / 2 s   decay envelope)
uniform vec2 u_key_bases;

/// iTime value recorded at the last failed PAM authentication attempt.
/// -1000.0 if no failed attempt has occurred yet this session.
uniform float u_last_failed_unlock_time;

/// iTime value recorded when PAM authentication was started (Enter pressed).
/// Reset to -1000.0 after authentication completes (success or failure).
uniform float u_auth_started_time;

// ---------------------------------------------------------------------------
// Shared constants
// ---------------------------------------------------------------------------

/// Canonical fail colour (227, 85, 50) in linear [0, 1] range.
/// Use with sk_fail_envelope() to tint shaders on failed unlock.
const vec3 sk_fail_color = vec3(227.0 / 255.0, 85.0 / 255.0, 50.0 / 255.0);

// ---------------------------------------------------------------------------
// Fragment output
// ---------------------------------------------------------------------------

out vec4 fragColor;

// ---------------------------------------------------------------------------
// sk_ — gloxwaldlock standard library
//
// Ready-to-use envelope functions derived from the raw uniform timestamps.
// Call them directly in mainImage; no boilerplate needed.
//
// Envelope shapes
// ───────────────
//   sk_keypulse_envelope  30 ms linear up · 80 ms quadratic down
//   sk_key_envelope       60 ms linear up · 1 s hold ·  2 s ease-out-back down
//   sk_fail_envelope      30 ms linear up · 240 ms hold · 2 s smooth down
//   sk_load_envelope      100 ms delay · 30 ms linear up · hold while loading · 30 ms linear down
//   sk_attention_envelope sum of key + fail + load, clamped to [−∞, 1]
//
// Both keypress envelopes use a host-supplied base value so that a new
// keypress mid-animation ramps up from the current level, not from zero.
// Fail and load events are separated by > 2 s of password entry, so they
// always start from zero and need no continuity base.

// ---------------------------------------------------------------------------

// ---- Session seeds ----------------------------------------------------------

/// Random float in [0,1) for i in 0..31, fixed for the session.
float sk_seed(int i) {
  mat4 m = i < 16 ? iSeed0 : iSeed1;
  return m[(i >> 2) & 3][i & 3];
}

// ---- Easing ---------------------------------------------------------------

/// Ease-out-back curve.  t in [0, 1] maps to [0, 1] with a slight undershoot
/// (goes briefly negative) before settling.  c1 = 4.0 matches the Rust side.
float sk_ease_out_back(float t) {
  const float c1 = 4.0;
  const float c3 = c1 + 1.0;
  float x = t - 1.0;
  return 1.0 + c3 * x * x * x + c1 * x * x;
}

// ---- Keypress envelopes ---------------------------------------------------

/// [0, 1]  Brief flash envelope per keypress.
/// 30 ms linear ramp to 1, then immediately a 80 ms quadratic decay back to 0.
/// Ramps from u_key_bases.x so mid-animation keypresses are seamless.
float sk_keypulse_envelope() {
  float age = iTime - u_last_key_time;
  float ramp = clamp(age / 0.03, 0.0, 1.0);
  float p = mix(u_key_bases.x, 1.0, ramp);
  float decay = clamp((age - 0.03) / 0.08, 0.0, 1.0);
  return p * (1.0 - decay * decay);
}

/// [−ε, 1]  Sustained key-pressure envelope.
/// 60 ms linear ramp to 1 · 1 s hold · 2 s ease-out-back decay.
/// Ramps from u_key_bases.y so mid-animation keypresses are seamless.
float sk_key_envelope() {
  float age = iTime - u_last_key_time;
  float ramp = clamp(age / 0.06, 0.0, 1.0);
  float p = mix(u_key_bases.y, 1.0, ramp);
  float decay = clamp((age - 1.06) / 2.0, 0.0, 1.0);
  return p * (1.0 - sk_ease_out_back(pow(decay, 0.65)));
}

// ---- Failed-unlock envelope -----------------------------------------------

/// [0, 1]  Failed-unlock indicator.
/// 30 ms linear ramp to 1 · 240 ms hold · 2 s smooth decay.
/// Always starts from zero (password entry takes > 2 s, so no mid-animation overlap).
float sk_fail_envelope() {
  float age = iTime - u_last_failed_unlock_time;
  float p = clamp(age / 0.03, 0.0, 1.0);
  float decay = clamp((age - 0.27) / 2.0, 0.0, 1.0);
  return p * pow(1.0 - decay, 3.0);
}

// ---- Loading envelope -----------------------------------------------------

/// [0, 1]  Gate that is 1 while PAM is running, with 30 ms linear ramps
/// on both edges and a 100 ms delay before ramping up.
///
/// Ramp-up   — measured from u_auth_started_time + 100 ms.
/// Ramp-down — measured from u_last_failed_unlock_time (the moment auth
///             ended with a failure; for a successful auth the screen
///             disappears immediately so the decay is never visible).
///
/// When neither auth is active nor a recent failure has occurred both
/// terms evaluate to 0, so the envelope is silent at rest.
float sk_load_envelope() {
  float isLoading = step(-999.0, u_auth_started_time);
  float authAge = iTime - u_auth_started_time;
  float endedAge = iTime - u_last_failed_unlock_time;

  // While loading: linear ramp up over 30 ms after 100 ms delay.
  float loading = isLoading * clamp((authAge - 0.1) / 0.03, 0.0, 1.0);

  // After loading ends (fail): linear ramp down over 30 ms from fail time.
  // When endedAge is large (no recent fail) this evaluates to 0.
  float unloading = (1.0 - isLoading) * clamp(1.0 - endedAge / 0.03, 0.0, 1.0);

  return loading + unloading;
}

// ---- Combined attention envelope ------------------------------------------

/// [−ε, 1]  Sum of sk_key_envelope + sk_fail_envelope + sk_load_envelope,
/// top-clamped to 1.  The lower bound is intentionally unclamped so the
/// ease-out-back undershoot of the key and fail envelopes is preserved.
/// To prevent wobble when load is active, negative undershoot is clamped
/// as the load envelope approaches 1.
float sk_attention_envelope() {
  float kf = sk_key_envelope() + sk_fail_envelope();
  float load = sk_load_envelope();
  kf = max(kf, load - 1.0);
  return min(kf + load, 1.0);
}
