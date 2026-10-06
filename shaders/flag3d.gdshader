shader_type spatial;
render_mode cull_disabled;

// Bandera colgada del mástil: ondea suavemente, más cuanto más lejos del mástil.
uniform sampler2D flag_tex : source_color, filter_linear;
uniform float wind = 1.0;

void vertex() {
	float k = UV.x;
	float ph = UV.x * 6.0 - TIME * 1.6 + UV.y * 1.2;
	VERTEX.z += (sin(ph) * 0.05 + sin(UV.x * 13.0 - TIME * 2.3) * 0.012) * k * wind;
	VERTEX.y -= k * k * 0.06;
	NORMAL = normalize(vec3(-cos(ph) * 0.3 * k * wind, 0.0, 1.0));
}

void fragment() {
	vec4 c = texture(flag_tex, UV);
	ALBEDO = c.rgb;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
}
