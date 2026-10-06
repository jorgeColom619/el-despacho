shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Haz de luz que entra por la ventana (se usa cuando no hay niebla volumétrica).
// UV.y: 0 en la ventana, 1 en el suelo; UV.x: de un borde al otro de la cara.
uniform float strength = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.72, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float edge = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
	float along = mix(1.0, 0.25, UV.y);
	float n = noise(vec2(UV.x * 7.0 + TIME * 0.04, UV.y * 2.5 - TIME * 0.02));
	float facing = abs(dot(NORMAL, VIEW));
	ALBEDO = tint.rgb * strength * 0.06 * edge * along * (0.7 + 0.6 * n) * facing;
}
