shader_type canvas_item;

uniform sampler2D ids : filter_nearest;
uniform sampler2D pal : filter_nearest;
uniform vec2 tex_size = vec2(1000.0, 760.0);
uniform int mode = 0;
uniform vec4 base_col : source_color = vec4(0.09, 0.2, 0.24, 1.0);
uniform vec4 hot_col : source_color = vec4(0.95, 0.22, 0.12, 1.0);

int rid(vec2 uv) {
	return int(floor(texture(ids, uv).r * 255.0 / 16.0 + 0.5));
}

void fragment() {
	vec4 m = texture(ids, UV);
	int id = rid(UV);
	vec2 px = 1.0 / tex_size;
	bool border = false;
	int a = rid(UV + vec2(px.x * 1.5, 0.0));
	int b = rid(UV - vec2(px.x * 1.5, 0.0));
	int c = rid(UV + vec2(0.0, px.y * 1.5));
	int d = rid(UV - vec2(0.0, px.y * 1.5));
	if (a != id || b != id || c != id || d != id) {
		border = true;
	}
	vec3 col;
	float grid = step(0.96, fract(UV.x * 40.0)) + step(0.96, fract(UV.y * 30.0));
	if (id == 0) {
		float coast = 1.0 - clamp(m.g * 3.0, 0.0, 1.0);
		col = vec3(0.02, 0.05, 0.09) + vec3(0.05, 0.16, 0.22) * pow(coast, 3.0) * 0.8;
		col += vec3(0.05, 0.12, 0.16) * grid * 0.35;
	} else if (id >= 9) {
		col = vec3(0.07, 0.08, 0.1) + vec3(0.02) * m.b;
		col += vec3(0.04) * grid * 0.3;
	} else {
		vec4 p = texelFetch(pal, ivec2(id, 0), 0);
		float inten = p.r;
		float hover = p.a;
		float extra = p.g;
		if (mode == 0) {
			col = base_col.rgb * (0.85 + 0.3 * m.b);
			float pulse = 0.85 + 0.15 * sin(TIME * (3.0 + inten * 6.0));
			col = mix(col, hot_col.rgb * pulse, clamp(inten * 1.1, 0.0, 1.0));
			col += vec3(0.25, 0.3, 0.3) * hover * 0.35;
			col = mix(col, vec3(0.2, 0.45, 0.9), extra * 0.35);
		} else {
			col = p.rgb * (0.8 + 0.35 * m.b) + vec3(hover * 0.15);
		}
		col += vec3(0.1, 0.2, 0.25) * grid * 0.15;
	}
	if (border && id != 0) {
		col = mix(col, vec3(0.55, 0.85, 0.95), 0.65);
	}
	float scan = 0.94 + 0.06 * sin(FRAGCOORD.y * 1.3);
	COLOR = vec4(col * scan, 1.0);
}
