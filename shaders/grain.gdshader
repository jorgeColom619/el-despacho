shader_type canvas_item;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	float n = hash(floor(FRAGCOORD.xy * 0.5) + vec2(floor(TIME * 24.0) * 7.13, 0.0));
	COLOR = vec4(vec3(n), 0.035);
}
