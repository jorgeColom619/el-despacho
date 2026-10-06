shader_type spatial;

// Globo terráqueo (y mapa plano enmarcado) a partir del mapa de identificadores del mundo:
// cada país con su color (paleta `pal`, índice = id del país), fronteras marcadas y Valdoria en dorado.
uniform sampler2D map_tex : filter_nearest, repeat_enable;
uniform sampler2D pal : filter_nearest;
uniform vec2 tex_size = vec2(1600.0, 900.0);
uniform int style = 0;
uniform float highlight = 0.0;
uniform bool flat_map = false;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

int rid(vec2 uv) {
	return int(floor(texture(map_tex, uv).r * 255.0 / 16.0 + 0.5));
}

void fragment() {
	vec2 tuv;
	if (flat_map) {
		tuv = UV;
	} else {
		tuv = vec2(fract(1.0 - UV.x), clamp((UV.y - 0.5) * 1.3 + 0.5, 0.0, 1.0));
	}
	vec4 m = texture(map_tex, tuv);
	int id = rid(tuv);
	vec2 px = (flat_map ? 1.6 : 2.2) / tex_size;
	bool border = rid(tuv + vec2(px.x, 0.0)) != id || rid(tuv - vec2(px.x, 0.0)) != id || rid(tuv + vec2(0.0, px.y)) != id || rid(tuv - vec2(0.0, px.y)) != id;
	vec3 pc = texelFetch(pal, ivec2(clamp(id, 0, 15), 0), 0).rgb;
	float coast = 1.0 - clamp(m.g * 4.0, 0.0, 1.0);
	vec3 col;
	vec3 emit = vec3(0.0);
	if (style == 1) {
		vec3 ocean = mix(vec3(0.01, 0.025, 0.06), vec3(0.04, 0.09, 0.17), pow(coast, 2.0));
		col = ocean;
		if (id > 0) {
			col = mix(vec3(0.07, 0.08, 0.11), pc * 0.35, 0.5) * (0.85 + 0.3 * m.b);
			float city = step(0.93, hash(floor(tuv * vec2(260.0, 160.0))));
			emit = vec3(1.0, 0.8, 0.45) * city * 0.9;
			if (border) {
				col = mix(col, vec3(0.75, 0.6, 0.3), 0.55);
			}
		}
		if (id == 1) {
			col = vec3(0.95, 0.75, 0.35) * 0.8;
		}
	} else {
		vec3 ocean = mix(vec3(0.12, 0.27, 0.33), vec3(0.26, 0.47, 0.5), pow(coast, 2.0));
		col = ocean;
		if (id > 0) {
			col = pc * (0.86 + 0.22 * m.b);
			if (border) {
				col = mix(col, vec3(0.16, 0.11, 0.07), 0.7);
			}
		} else if (border) {
			col = mix(col, vec3(0.08, 0.16, 0.2), 0.5);
		}
		if (flat_map) {
			// pergamino envejecido en los bordes del mapa
			float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
			col *= mix(0.62, 1.0, smoothstep(0.0, 0.12, edge));
		}
	}
	ALBEDO = pow(min(col * 1.15, vec3(1.0)), vec3(2.2));
	ROUGHNESS = flat_map ? 0.85 : 0.55;
	SPECULAR = flat_map ? 0.2 : 0.35;
	EMISSION = pow(emit, vec3(2.2)) + vec3(0.9, 0.7, 0.3) * highlight * 0.08;
}
