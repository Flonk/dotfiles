// --- traffic: amp cars on real road networks ----------------------------------
// The scene is one of the maps (96_map.glsl), u_traffic_map picking which.
// the bins are rescanned a slice of rows a frame
const int   MP_BIN_SLICES = 8;

vec3 traffic(vec2 q, vec2 tp){ return mpRender(q, tp); }
