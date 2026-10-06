shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// Oscurece un objeto del despacho 3D que todavía no está disponible.
void fragment() {
	ALBEDO = vec3(0.5, 0.5, 0.56);
}
