shader_type spatial;
render_mode cull_disabled;

// Bandera de interior colgada del mástil: cae con pliegues verticales que se mecen muy despacio.
// UV.x = 0 junto al mástil.
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float phase = 0.0;

void vertex() {
	float a = UV.x * 18.0 + phase;
	float b = UV.x * 7.0 + phase * 1.3 + TIME * 0.4;
	float k = 0.35 + 0.65 * UV.x;
	VERTEX.z += (sin(a) * 0.03 + sin(b) * 0.02) * k;
	NORMAL = normalize(vec3(-(cos(a) * 0.54 + cos(b) * 0.14) * k, 0.0, 1.0));
}

void fragment() {
	vec4 c = texture(tex, UV);
	// los pliegues que miran hacia dentro quedan algo más oscuros
	ALBEDO = c.rgb * (0.86 + 0.14 * sin(UV.x * 18.0 + phase + 1.2));
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
