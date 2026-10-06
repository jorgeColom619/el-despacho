shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Llamas de la chimenea: plano orientado a la cámara (solo en el eje vertical) con ruido animado.
uniform float seed = 0.0;
uniform float strength = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	mat4 bb = mat4(vec4(right, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(cross(right, vec3(0.0, 1.0, 0.0)), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * bb * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, 1, 0), vec4(0, 0, 0, 1));
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float n = noise(vec2(uv.x * 5.0 + seed, uv.y * 4.0 - TIME * 3.0)) * 0.6 + noise(vec2(uv.x * 11.0 - seed, uv.y * 9.0 - TIME * 5.0)) * 0.4;
	float width = (0.5 - abs(uv.x - 0.5)) * 2.0;
	float shape = width * (1.0 - uv.y) * 1.8 - uv.y * 0.4;
	float f = clamp(shape * (0.55 + n * 0.9) - 0.15, 0.0, 1.0);
	vec3 col = mix(vec3(0.9, 0.18, 0.02), vec3(1.0, 0.78, 0.32), f);
	ALBEDO = col * f * 1.8 * strength;
}
