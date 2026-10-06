shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// Brillo de borde para los objetos interactivos del despacho 3D (se aplica como material_overlay).
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform float amount = 0.0;

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = glow_color.rgb * amount * (0.16 + pow(rim, 2.2) * 1.2);
}
