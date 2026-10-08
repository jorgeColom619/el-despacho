shader_type spatial;
render_mode cull_disabled;

// Diputados lejanos del hemiciclo (MultiMesh de art/characters/crowd.glb). Cada superficie es un tipo de
// pieza (cat) y se pinta con los datos de la instancia: INSTANCE_CUSTOM.rgb = traje (sRGB),
// .a = piel + pelo * 8. Cuando su bancada aplaude (x < 0: cheer_left; x > 0: cheer_right), botan en el asiento.
uniform int cat = 0;
uniform vec4 skin_tones[6];
uniform vec4 hair_tones[7];
uniform float cheer_left = 0.0;
uniform float cheer_right = 0.0;

varying vec3 col;

void vertex() {
	int packed = int(INSTANCE_CUSTOM.a + 0.5);
	int skin = packed % 8;
	int hair = packed / 8;
	vec3 suit = pow(INSTANCE_CUSTOM.rgb, vec3(2.2));
	if (cat == 0) {
		col = suit;
	} else if (cat == 1) {
		col = suit * 0.62;
	} else if (cat == 2) {
		col = skin_tones[clamp(skin, 0, 5)].rgb;
	} else if (cat == 3) {
		col = hair_tones[clamp(hair, 0, 6)].rgb;
	} else if (cat == 4) {
		col = vec3(0.8);
	} else if (cat == 5) {
		col = vec3(0.015);
	} else if (cat == 6) {
		col = mix(vec3(0.32, 0.02, 0.04), suit, 0.3);
	} else {
		col = vec3(0.85);
	}
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float amt = wp.x < 0.0 ? cheer_left : cheer_right;
	float up = smoothstep(0.55, 1.0, VERTEX.y);
	VERTEX.y += amt * abs(sin(TIME * 8.5 + float(INSTANCE_ID) * 2.39)) * 0.05 * up;
}

void fragment() {
	ALBEDO = col;
	ROUGHNESS = cat == 3 ? 0.6 : 0.78;
	SPECULAR = 0.35;
}
