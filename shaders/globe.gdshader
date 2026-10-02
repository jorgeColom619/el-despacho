shader_type canvas_item;

uniform sampler2D map_tex : filter_nearest;
uniform float rot = 0.0;
uniform float highlight = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = dot(p, p);
	if (d > 1.0) {
		discard;
	}
	float z = sqrt(1.0 - d);
	float lon = atan(p.x, z) + rot;
	float lat = asin(clamp(p.y, -1.0, 1.0));
	vec2 tuv = vec2(fract(lon / 6.2831853 + 0.5), clamp(lat / 3.14159 * 1.3 + 0.5, 0.0, 1.0));
	vec4 m = texture(map_tex, tuv);
	float id = floor(m.r * 255.0 / 16.0 + 0.5);
	vec3 ocean = mix(vec3(0.16, 0.30, 0.33), vec3(0.26, 0.44, 0.45), clamp(m.g * 1.5, 0.0, 1.0));
	vec3 land = vec3(0.86, 0.75, 0.52) * (0.85 + 0.25 * m.b);
	vec3 col = ocean;
	if (id > 0.5) {
		col = land;
	}
	if (abs(id - 1.0) < 0.1) {
		col = vec3(0.98, 0.72, 0.25);
	}
	vec3 n = normalize(vec3(p.x, -p.y, z));
	float light = clamp(dot(n, normalize(vec3(-0.55, 0.5, 0.75))), 0.0, 1.0);
	col *= 0.32 + 0.8 * light;
	col += vec3(pow(light, 20.0) * 0.3);
	col += vec3(0.9, 0.7, 0.3) * highlight * 0.15;
	COLOR = vec4(col, 1.0);
}
