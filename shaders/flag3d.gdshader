shader_type spatial;
render_mode cull_disabled;

// Bandera colgada del mástil: ondea suavemente, más cuanto más lejos del mástil.
// flip_u: el mástil está al otro lado (se invierte la tela en vez de usar escala negativa, que la dejaba
// vista por detrás y a oscuras)
uniform sampler2D flag_tex : source_color, filter_linear;
uniform float wind = 1.0;
uniform bool flip_u = false;

void vertex() {
	float k = flip_u ? 1.0 - UV.x : UV.x;
	float ph = k * 6.0 - TIME * 1.6 + UV.y * 1.2;
	VERTEX.z += (sin(ph) * 0.05 + sin(k * 13.0 - TIME * 2.3) * 0.012) * k * wind;
	VERTEX.y -= k * k * 0.06;
	NORMAL = normalize(vec3(-cos(ph) * 0.3 * k * wind * (flip_u ? -1.0 : 1.0), 0.0, 1.0));
}

void fragment() {
	vec2 uv = vec2(flip_u ? 1.0 - UV.x : UV.x, UV.y);
	vec4 c = texture(flag_tex, uv);
	ALBEDO = c.rgb;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
}
