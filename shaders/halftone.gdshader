shader_type canvas_item;

uniform float dot_size = 5.0;
uniform vec4 paper : source_color = vec4(0.93, 0.9, 0.82, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	lum = mix(1.0, lum, c.a);
	lum = clamp((lum - 0.08) * 1.2, 0.0, 1.0);
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	float a = 0.785;
	vec2 rp = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * px;
	vec2 cell = fract(rp / dot_size) - 0.5;
	float d = length(cell);
	float r = (1.0 - lum) * 0.64;
	float ink = 1.0 - smoothstep(r - 0.07, r + 0.07, d);
	vec3 col = mix(paper.rgb, vec3(0.1, 0.1, 0.11), ink);
	COLOR = vec4(col, 1.0);
}
