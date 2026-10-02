shader_type canvas_item;
render_mode blend_mul;

uniform float night = 0.0;
uniform float alert = 0.0;

void fragment() {
	vec2 uv = UV;
	float vig = smoothstep(1.3, 0.3, length((uv - vec2(0.5, 0.42)) * vec2(1.2, 1.0)));
	vec3 base = mix(vec3(1.0, 0.975, 0.93), vec3(0.5, 0.56, 0.76), night);
	float lamp = exp(-pow(length((uv - vec2(0.2, 0.74)) * vec2(1.7, 1.0)) * 2.8, 2.0));
	float scon1 = exp(-pow(length((uv - vec2(0.405, 0.22)) * vec2(1.8, 1.0)) * 5.0, 2.0));
	float scon2 = exp(-pow(length((uv - vec2(0.6, 0.22)) * vec2(1.8, 1.0)) * 5.0, 2.0));
	base += vec3(0.45, 0.32, 0.12) * lamp * (0.25 + night * 0.9);
	base += vec3(0.3, 0.22, 0.1) * (scon1 + scon2) * night;
	vec3 col = base * mix(0.52, 1.02, vig);
	float pulse = alert * (0.5 + 0.5 * sin(TIME * 3.2));
	col = mix(col, col * vec3(1.05, 0.5, 0.45), pulse * 0.4);
	COLOR = vec4(col, 1.0);
}
