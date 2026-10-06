shader_type canvas_item;
render_mode blend_mul;

// Viñeta suave sobre la vista 3D y pulso rojo durante las crisis.
uniform float alert = 0.0;
uniform float night = 0.0;

void fragment() {
	float vig = smoothstep(1.25, 0.35, length((UV - vec2(0.5)) * vec2(1.25, 1.0)));
	vec3 col = vec3(mix(0.6, 1.0, vig));
	col *= mix(vec3(1.0), vec3(0.82, 0.86, 1.0), night * 0.5);
	float pulse = alert * (0.5 + 0.5 * sin(TIME * 3.2));
	col = mix(col, col * vec3(1.05, 0.55, 0.5), pulse * 0.35);
	COLOR = vec4(col, 1.0);
}
