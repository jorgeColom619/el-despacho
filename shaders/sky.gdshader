shader_type canvas_item;

uniform float tod = 0.0;
uniform float clouds = 0.3;
uniform float storm = 0.0;
uniform float flash = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec3 day_top = vec3(0.26, 0.48, 0.78);
	vec3 day_hor = vec3(0.76, 0.86, 0.94);
	vec3 dusk_top = vec3(0.19, 0.18, 0.40);
	vec3 dusk_hor = vec3(0.98, 0.58, 0.34);
	vec3 night_top = vec3(0.015, 0.025, 0.07);
	vec3 night_hor = vec3(0.09, 0.12, 0.24);
	vec3 top;
	vec3 hor;
	if (tod < 0.5) {
		float t = tod * 2.0;
		top = mix(day_top, dusk_top, t);
		hor = mix(day_hor, dusk_hor, t);
	} else {
		float t = (tod - 0.5) * 2.0;
		top = mix(dusk_top, night_top, t);
		hor = mix(dusk_hor, night_hor, t);
	}
	vec3 col = mix(top, hor, smoothstep(0.0, 0.8, uv.y));
	col = mix(col, vec3(0.3, 0.32, 0.36) * (1.0 - tod * 0.75), storm * 0.75);
	if (tod > 0.6) {
		vec2 sp = uv * vec2(90.0, 100.0);
		float h = hash(floor(sp));
		float st = step(0.986, h);
		col += st * (tod - 0.6) * 2.2 * (0.55 + 0.45 * sin(TIME * 2.5 + h * 40.0)) * (1.0 - uv.y) * (1.0 - storm);
	}
	vec2 cp = uv * vec2(2.6, 4.2) + vec2(TIME * 0.012, 0.0);
	float c = fbm(cp);
	float a = 0.72 - clouds * 0.42;
	float cov = smoothstep(a, a + 0.28, c);
	vec3 ccol = mix(vec3(1.0, 0.98, 0.96), vec3(0.96, 0.66, 0.55), clamp(tod * 2.0, 0.0, 1.0));
	ccol = mix(ccol, vec3(0.13, 0.15, 0.2), max(storm * 0.85, clamp((tod - 0.5) * 2.0, 0.0, 1.0) * 0.85));
	float shade = fbm(cp * 1.7 + 3.0);
	ccol *= 0.82 + shade * 0.3;
	col = mix(col, ccol, cov * 0.92 * (1.0 - uv.y * 0.5));
	col += vec3(flash);
	COLOR = vec4(col, 1.0);
}
