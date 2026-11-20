precision highp float;

uniform highp vec2 pixelSize;
uniform float opacity;
uniform highp vec4 fillColor;
uniform highp vec4 borderColor;
uniform float outerRadius;
uniform float borderWidth;

uniform bool applyBlur;
uniform sampler2D blurTex;

varying highp vec2 pixCoord;
varying highp vec2 monitorTexCoord;

uniform float chrome;
uniform highp vec2 monitorSize;
varying highp vec2 monitorPix;

highp vec3 chromeLinear(highp vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

highp vec3 chromeSrgb(highp vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}

highp vec3 chromeToLab(highp vec3 srgb) {
	highp vec3 c = chromeLinear(srgb);
	highp vec3 lms = vec3(
		0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b,
		0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b,
		0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b);
	lms = pow(max(lms, 0.0), vec3(1.0 / 3.0));
	return vec3(
		0.2104542553 * lms.x + 0.7936177850 * lms.y - 0.0040720468 * lms.z,
		1.9779984951 * lms.x - 2.4285922050 * lms.y + 0.4505937099 * lms.z,
		0.0259040371 * lms.x + 0.7827717662 * lms.y - 0.8086757660 * lms.z);
}

highp vec3 chromeFromLab(highp vec3 lab) {
	highp vec3 lms = vec3(
		lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z,
		lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z,
		lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z);
	lms = lms * lms * lms;
	return chromeSrgb(vec3(
		4.0767416621 * lms.x - 3.3077115913 * lms.y + 0.2309699292 * lms.z,
		-1.2684380046 * lms.x + 2.6097574011 * lms.y - 0.3413193965 * lms.z,
		-0.0041960863 * lms.x - 0.7034186147 * lms.y + 1.7076147010 * lms.z));
}

highp vec3 chromeShift(highp vec3 lab, float dl, float dc, float dh) {
	float c = max(length(lab.yz) + dc, 0.0);
	float h = atan(lab.z, lab.y) + dh;
	return chromeFromLab(vec3(lab.x + dl, c * cos(h), c * sin(h)));
}

highp vec3 chromeSoftLight(highp vec3 b, highp vec3 s) {
	highp vec3 d = mix(((16.0 * b - 12.0) * b + 4.0) * b, sqrt(b), step(0.25, b));
	return mix(b - (1.0 - 2.0 * s) * b * (1.0 - b), b + (2.0 * s - 1.0) * (d - b), step(0.5, s));
}

highp vec3 chromeColor(highp vec2 p, highp vec3 accent) {
	highp vec3 lab = chromeToLab(accent);
	highp vec3 a = accent;
	highp vec3 b = chromeShift(lab, 0.087, -0.009, radians(24.0));
	highp vec3 g = chromeShift(lab, 0.16, -0.031, radians(43.2));
	float turn = radians(110.0);
	highp vec2 dir = vec2(sin(turn), -cos(turn));
	float len = abs(monitorSize.x * dir.x) + abs(monitorSize.y * dir.y);
	float t = clamp(dot(p - monitorSize * 0.5, dir) / len + 0.5, 0.0, 1.0);
	highp vec3 c = t < 0.5 ? mix(a, b, t * 2.0) : mix(b, a, t * 2.0 - 1.0);
	highp vec2 orbit = vec2(0.5 + cos(turn) * 0.4, 0.2 + sin(turn) * 0.3) * monitorSize;
	float vmax = max(monitorSize.x, monitorSize.y);
	float d = length((p - orbit) / (vec2(0.42, 0.28) * vmax));
	c = mix(c, g, clamp(1.0 - d / 0.7, 0.0, 1.0));
	float n = fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453);
	return mix(c, chromeSoftLight(c, vec3(n)), 0.35);
}

void main() {
	float opacityMul = opacity;
	highp vec2 cornerDist = min(pixCoord, pixelSize - pixCoord);

	gl_FragColor = fillColor;

	if (cornerDist.x <= outerRadius && cornerDist.y <= outerRadius) {
		highp vec2 vcornerDist = vec2(outerRadius) - cornerDist;
		float distSq = vcornerDist.x * vcornerDist.x + vcornerDist.y * vcornerDist.y;

		// See https://github.com/hyprwm/Hyprland/blob/e75e2cdac79417ffdbbbe903f72668953483a4e7/src/render/shaders/SharedValues.hpp#L3
		const float SMOOTHING_CONSTANT = 0.58758063398831095317;
		const float SMOOTHING_CONSTANT_2X = SMOOTHING_CONSTANT * 2.0;

		float innerRadius = outerRadius - borderWidth;
		float outerTest1 = outerRadius + SMOOTHING_CONSTANT_2X;
		float outerTest2 = outerRadius - SMOOTHING_CONSTANT_2X;
		float innerTest1 = innerRadius + SMOOTHING_CONSTANT_2X;
		float innerTest2 = innerRadius - SMOOTHING_CONSTANT_2X;

		float dist;
		bool calculatedDist = false;

		if (distSq > outerTest1 * outerTest1) {
			discard;
		} else if (distSq > outerTest2 * outerTest2) {
			dist = sqrt(distSq);
			calculatedDist = true;
			float normalized = 1.0 - smoothstep(0.0, 1.0, (dist - outerRadius + SMOOTHING_CONSTANT) / (SMOOTHING_CONSTANT_2X));
			gl_FragColor = borderColor;
			opacityMul *= normalized;
		} else if (distSq > innerTest2 * innerTest2) {
			gl_FragColor = borderColor;
		}

		if (distSq > innerTest2 * innerTest2 && distSq <= innerTest1 * innerTest1) {
			if (!calculatedDist) dist = sqrt(distSq);
			float normalized = 1.0 - smoothstep(0.0, 1.0, (dist - innerRadius + SMOOTHING_CONSTANT) / (SMOOTHING_CONSTANT_2X));
			gl_FragColor = gl_FragColor * (1.0 - normalized) + fillColor * normalized;
		}
	} else if (cornerDist.x <= borderWidth || cornerDist.y <= borderWidth) {
		gl_FragColor = borderColor;
	}

	if (chrome > 0.0 && gl_FragColor.a > 0.0) {
		highp vec3 accent = fillColor.rgb / max(fillColor.a, 0.001);
		gl_FragColor.rgb = mix(gl_FragColor.rgb, chromeColor(monitorPix, accent) * gl_FragColor.a, chrome);
	}

	if (applyBlur && gl_FragColor.a != 1.0) {
		gl_FragColor = gl_FragColor + texture2D(blurTex, monitorTexCoord) * (1.0 - gl_FragColor.a);
	}

	gl_FragColor *= opacityMul;
}
