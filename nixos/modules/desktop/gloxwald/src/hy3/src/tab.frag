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
uniform float chromeTextures;
uniform highp vec2 monitorSize;
uniform sampler2D gradientTex;
uniform sampler2D noiseTex;
uniform sampler2D dotsTex;
varying highp vec2 monitorPix;

highp vec4 chromeStraight(highp vec4 c) {
	return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : c;
}

highp vec3 chromeOverlay(highp vec3 b, highp vec3 s) {
	return mix(2.0 * b * s, 1.0 - 2.0 * (1.0 - b) * (1.0 - s), step(0.5, b));
}

highp vec3 chromeSoftLight(highp vec3 b, highp vec3 s) {
	highp vec3 d = mix(((16.0 * b - 12.0) * b + 4.0) * b, sqrt(b), step(0.25, b));
	return mix(b - (1.0 - 2.0 * s) * b * (1.0 - b), b + (2.0 * s - 1.0) * (d - b), step(0.5, s));
}

highp vec3 chromeShade(highp vec3 c, float k) {
	highp vec3 lin = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)) * k;
	return mix(lin * 12.92, 1.055 * pow(lin, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, lin));
}

highp vec3 chromeColor(highp vec2 p) {
	highp vec3 c = texture2D(gradientTex, (p - monitorSize * 0.5) / vec2(3840.0, 2160.0) + 0.5).rgb;
	highp vec4 dots = chromeStraight(texture2D(dotsTex, fract(p / 26.0)));
	c = mix(c, chromeOverlay(c, dots.rgb), dots.a);
	highp vec4 noise = chromeStraight(texture2D(noiseTex, fract(p / 128.0)));
	return mix(c, chromeSoftLight(c, noise.rgb), noise.a);
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

	if (chromeTextures > 0.5 && gl_FragColor.a > 0.0) {
		gl_FragColor.rgb = chromeShade(chromeColor(monitorPix), mix(0.025, 0.8, chrome)) * gl_FragColor.a;
	}

	if (applyBlur && gl_FragColor.a != 1.0) {
		gl_FragColor = gl_FragColor + texture2D(blurTex, monitorTexCoord) * (1.0 - gl_FragColor.a);
	}

	gl_FragColor *= opacityMul;
}
