shader_type spatial;

// Globo terráqueo (y mapa plano enmarcado) a partir del mapa de identificadores del mundo.
uniform sampler2D map_tex : filter_nearest, repeat_enable;
uniform int style = 0;
uniform float highlight = 0.0;
uniform bool flat_map = false;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 tuv;
	if (flat_map) {
		tuv = UV;
	} else {
		tuv = vec2(fract(1.0 - UV.x), clamp((UV.y - 0.5) * 1.3 + 0.5, 0.0, 1.0));
	}
	vec4 m = texture(map_tex, tuv);
	float id = floor(m.r * 255.0 / 16.0 + 0.5);
	vec3 col;
	vec3 emit = vec3(0.0);
	if (style == 1) {
		vec3 ocean = mix(vec3(0.01, 0.025, 0.06), vec3(0.03, 0.07, 0.14), clamp(m.g * 1.5, 0.0, 1.0));
		vec3 land = vec3(0.07, 0.08, 0.11) * (0.85 + 0.3 * m.b);
		col = ocean;
		if (id > 0.5) {
			col = land;
			float city = step(0.93, hash(floor(tuv * vec2(260.0, 160.0))));
			emit = vec3(1.0, 0.8, 0.45) * city * 0.9;
		}
		if (abs(id - 1.0) < 0.1) {
			col = vec3(0.95, 0.75, 0.35) * 0.8;
		}
	} else {
		vec3 ocean = mix(vec3(0.16, 0.30, 0.33), vec3(0.26, 0.44, 0.45), clamp(m.g * 1.5, 0.0, 1.0));
		vec3 land = vec3(0.86, 0.75, 0.52) * (0.85 + 0.25 * m.b);
		col = ocean;
		if (id > 0.5) {
			col = land;
		}
		if (abs(id - 1.0) < 0.1) {
			col = vec3(0.98, 0.72, 0.25);
		}
		if (flat_map) {
			// pergamino envejecido
			float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
			col *= mix(0.62, 1.0, smoothstep(0.0, 0.12, edge));
		}
	}
	ALBEDO = pow(min(col * 1.35, vec3(1.0)), vec3(2.2));
	ROUGHNESS = flat_map ? 0.85 : 0.35;
	EMISSION = pow(emit, vec3(2.2)) + vec3(0.9, 0.7, 0.3) * highlight * 0.12;
}
