shader_type canvas_item;

uniform float seed = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float n = noise(lp * 0.25) * 0.6 + noise(lp * 0.9) * 0.4;
	float speck = step(0.2, hash(floor(lp * 0.7)));
	COLOR.a *= smoothstep(0.18, 0.5, n) * mix(0.75, 1.0, speck);
}
