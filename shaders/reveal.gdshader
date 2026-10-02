shader_type canvas_item;

uniform vec2 lens_pos = vec2(-1000.0, -1000.0);
uniform float radius = 100.0;
uniform float base_alpha = 0.07;
uniform bool invert = false;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float d = distance(world, lens_pos);
	float r = 1.0 - smoothstep(radius * 0.72, radius, d);
	float a = invert ? (1.0 - r * 0.96) : mix(base_alpha, 1.0, r);
	COLOR.a *= a;
}
