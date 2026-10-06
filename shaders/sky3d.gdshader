shader_type sky;

// Cielo que se ve por el ventanal del despacho 3D: degradado según la hora, sol (o luna) de la luz
// direccional, nubes, estrellas, tormenta y relámpagos. Para los reflejos del interior (paso del
// cubemap) devuelve los tonos cálidos del despacho, no el cielo de fuera.

uniform float tod = 0.0;     // 0 día · 0.5 atardecer · 1 noche
uniform float clouds = 0.3;
uniform float storm = 0.0;
uniform float flash = 0.0;
// desplazamiento de las nubes (lo avanza el despacho; sin TIME para no recalcular el cielo cada fotograma
// en el motor compatible)
uniform float cloud_shift = 0.0;
uniform vec3 room_top : source_color = vec3(0.5, 0.42, 0.34);
uniform vec3 room_horizon : source_color = vec3(0.85, 0.7, 0.5);
uniform vec3 room_ground : source_color = vec3(0.16, 0.1, 0.07);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(13.7, 7.1);
		a *= 0.5;
	}
	return v;
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		float hc = EYEDIR.y;
		vec3 c = hc > 0.0 ? mix(room_horizon, room_top, clamp(hc * 1.5, 0.0, 1.0)) : mix(room_horizon * 0.6, room_ground, clamp(-hc * 2.0, 0.0, 1.0));
		COLOR = c;
	} else {
		float night = clamp((tod - 0.45) * 2.0, 0.0, 1.0);
		float sunset = clamp(1.0 - abs(tod - 0.5) * 3.0, 0.0, 1.0);
		vec3 zen = mix(mix(vec3(0.16, 0.36, 0.72), vec3(0.22, 0.22, 0.42), sunset), vec3(0.008, 0.012, 0.035), night);
		vec3 hor = mix(mix(vec3(0.66, 0.78, 0.9), vec3(1.0, 0.52, 0.28), sunset), vec3(0.04, 0.06, 0.11), night);
		vec3 grey = vec3(0.34, 0.36, 0.4) * (1.0 - night * 0.85);
		zen = mix(zen, grey * 0.75, storm);
		hor = mix(hor, grey, storm);
		float h = EYEDIR.y;
		vec3 col = mix(hor, zen, pow(clamp(h, 0.0, 1.0), 0.55));
		if (h < 0.0) {
			col = mix(hor, hor * 0.45, clamp(-h * 4.0, 0.0, 1.0));
		}
		// nubes: capa proyectada sobre una bóveda, se desplazan despacio
		float cover = 0.0;
		vec3 cloud_col = vec3(1.0);
		if (h > 0.0) {
			vec2 uv = EYEDIR.xz / (h + 0.12) * 0.9 + vec2(cloud_shift, cloud_shift * 0.42);
			float n = fbm(uv * 1.6);
			float thr = mix(0.72, 0.36, clamp(clouds, 0.0, 1.0));
			cover = smoothstep(thr, thr + 0.22, n) * smoothstep(0.0, 0.12, h);
			cloud_col = mix(vec3(1.0, 0.99, 0.97), vec3(1.0, 0.68, 0.5), sunset) * mix(1.0, 0.07, night);
			cloud_col = mix(cloud_col, grey * 0.95, storm);
			cloud_col *= 0.82 + 0.18 * n;
		}
		// sol o luna (la luz direccional)
		if (LIGHT0_ENABLED) {
			float d = dot(normalize(LIGHT0_DIRECTION), EYEDIR);
			float disc = smoothstep(0.99972, 0.99985, d);
			float halo = pow(max(d, 0.0), 900.0) * 0.8 + pow(max(d, 0.0), 60.0) * 0.22;
			vec3 sc = mix(mix(vec3(1.0, 0.95, 0.85), vec3(1.0, 0.55, 0.3), sunset), vec3(0.82, 0.88, 1.0), night);
			float vis = (1.0 - storm * 0.92) * (1.0 - cover * 0.85);
			col += sc * disc * mix(60.0, 2.5, night) * vis;
			col += sc * halo * mix(1.3, 0.12, night) * (1.0 - storm * 0.8);
		}
		// estrellas
		if (night > 0.0 && h > 0.0) {
			vec2 sp = vec2(atan(EYEDIR.x, EYEDIR.z) * 120.0, h * 240.0);
			float s = step(0.992, hash(floor(sp)));
			col += vec3(0.9, 0.92, 1.0) * s * night * (1.0 - cover) * (1.0 - storm) * smoothstep(0.0, 0.2, h);
		}
		col = mix(col, cloud_col, cover * 0.92);
		col += vec3(0.85, 0.88, 1.0) * flash;
		COLOR = col;
	}
}
