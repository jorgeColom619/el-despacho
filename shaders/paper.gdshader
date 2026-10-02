shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.95, 0.92, 0.84, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	float n = hash(floor(uv * vec2(420.0, 500.0)));
	float fib = hash(floor(uv * vec2(80.0, 1000.0)));
	vec3 col = tint.rgb * (0.965 + 0.035 * n) * (0.985 + 0.015 * fib);
	float edge = smoothstep(0.0, 0.05, uv.x) * smoothstep(1.0, 0.95, uv.x) * smoothstep(0.0, 0.04, uv.y) * smoothstep(1.0, 0.96, uv.y);
	col *= mix(0.9, 1.0, edge);
	COLOR = vec4(col, 1.0);
}
