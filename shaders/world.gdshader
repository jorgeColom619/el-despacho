shader_type canvas_item;

uniform sampler2D ids : filter_nearest;
uniform sampler2D pal : filter_nearest;
uniform vec2 tex_size = vec2(1600.0, 900.0);

int rid(vec2 uv) {
	return int(floor(texture(ids, uv).r * 255.0 / 16.0 + 0.5));
}

void fragment() {
	vec4 m = texture(ids, UV);
	int id = rid(UV);
	vec2 px = 1.0 / tex_size;
	bool border = rid(UV + vec2(px.x, 0.0)) != id || rid(UV - vec2(px.x, 0.0)) != id || rid(UV + vec2(0.0, px.y)) != id || rid(UV - vec2(0.0, px.y)) != id;
	vec3 col;
	float grid = step(0.985, fract(UV.x * 24.0)) + step(0.98, fract(UV.y * 12.0));
	if (id == 0) {
		float coast = 1.0 - clamp(m.g * 4.0, 0.0, 1.0);
		col = mix(vec3(0.04, 0.09, 0.15), vec3(0.08, 0.2, 0.28), pow(coast, 2.0));
		col += vec3(0.1, 0.2, 0.25) * grid * 0.25;
	} else {
		vec4 p = texelFetch(pal, ivec2(id, 0), 0);
		col = p.rgb * (0.82 + 0.3 * m.b);
		col += vec3(0.25) * p.a;
	}
	if (border && id != 0) {
		col = mix(col, vec3(0.05, 0.06, 0.08), 0.7);
	}
	COLOR = vec4(col, 1.0);
}
