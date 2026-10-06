extends RefCounted
## Utilidades para construir el despacho 3D: lotes de geometría (cajas con cantos redondeados,
## cilindros, esferas, molduras con perfil y marcos ingletados), materiales con relieve a partir de
## las texturas generadas (tex3d.gd), sombras de contacto y cuerpos físicos.

const OfficeArt := preload("res://scripts/office/office_art.gd")
const Tex := preload("res://scripts/office3d/tex3d.gd")

static var _tex_cache := {}
static var _mat_cache := {}
## Materiales de sombra de contacto (su intensidad depende del motor gráfico)
static var shadow_mats: Array = []

# Perfiles de moldura: (salida desde la pared, altura) de abajo arriba
const PROFILE_CROWN := [Vector2(0.0, 0.0), Vector2(0.018, 0.0), Vector2(0.022, 0.012), Vector2(0.03, 0.022), Vector2(0.045, 0.034), Vector2(0.07, 0.06), Vector2(0.095, 0.1), Vector2(0.11, 0.13), Vector2(0.12, 0.145), Vector2(0.128, 0.152), Vector2(0.128, 0.175), Vector2(0.0, 0.175)]
const PROFILE_RAIL := [Vector2(0.0, 0.0), Vector2(0.012, 0.0), Vector2(0.02, 0.008), Vector2(0.026, 0.02), Vector2(0.022, 0.03), Vector2(0.028, 0.04), Vector2(0.03, 0.05), Vector2(0.022, 0.062), Vector2(0.0, 0.068)]
const PROFILE_BASE := [Vector2(0.0, 0.0), Vector2(0.024, 0.0), Vector2(0.024, 0.15), Vector2(0.018, 0.158), Vector2(0.017, 0.17), Vector2(0.011, 0.18), Vector2(0.0, 0.186)]
# Perfiles de marco: (distancia hacia dentro desde el borde exterior, salida)
const FRAME_ORNATE := [Vector2(0.0, 0.0), Vector2(0.0, 0.03), Vector2(0.008, 0.044), Vector2(0.02, 0.052), Vector2(0.034, 0.046), Vector2(0.044, 0.034), Vector2(0.052, 0.036), Vector2(0.062, 0.028), Vector2(0.07, 0.018), Vector2(0.078, 0.016), Vector2(0.084, 0.006), Vector2(0.088, 0.0)]
const FRAME_PANEL := [Vector2(0.0, 0.0), Vector2(0.003, 0.01), Vector2(0.01, 0.015), Vector2(0.018, 0.012), Vector2(0.022, 0.005), Vector2(0.026, 0.0)]
const FRAME_CASING := [Vector2(0.0, 0.0), Vector2(0.0, 0.022), Vector2(0.008, 0.03), Vector2(0.02, 0.032), Vector2(0.03, 0.026), Vector2(0.04, 0.028), Vector2(0.12, 0.024), Vector2(0.13, 0.018), Vector2(0.14, 0.01), Vector2(0.15, 0.0)]


## Lote de geometría estática: acumula piezas por material y las convierte en una malla por material.
class Batch:
	extends RefCounted
	var _st := {}
	var _mats := {}

	func _tool(m: Material) -> SurfaceTool:
		var k := m.get_instance_id()
		if not _st.has(k):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_st[k] = st
			_mats[k] = m
		return _st[k]

	func _v(st: SurfaceTool, xf: Transform3D, p: Vector3, n: Vector3, uv: Vector2) -> void:
		st.set_normal((xf.basis * n).normalized())
		st.set_uv(uv)
		st.add_vertex(xf * p)

	## Cara rectangular: centro c, ejes u (derecha) y v (arriba) vistos desde delante, n = u × v
	func _face(st: SurfaceTool, xf: Transform3D, c: Vector3, u: Vector3, v: Vector3, hu: float, hv: float, uvs: float, uv_off := Vector2.ZERO, unit := false) -> void:
		var n := u.cross(v)
		var tl := c - u * hu + v * hv
		var tr := c + u * hu + v * hv
		var br := c + u * hu - v * hv
		var bl := c - u * hu - v * hv
		var w := 1.0 if unit else hu * 2.0 * uvs
		var h := 1.0 if unit else hv * 2.0 * uvs
		var pts := [tl, tr, br, tl, br, bl]
		var uvp := [Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, 0), Vector2(w, h), Vector2(0, h)]
		for i in 6:
			_v(st, xf, pts[i], n, uvp[i] + uv_off)

	const FACES := [
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]

	## Caja; con bevel > 0 tiene los cantos redondeados (seg = segmentos por cuarto de curva)
	func box(xf: Transform3D, size: Vector3, m: Material, uvs := 1.0, bevel := 0.0, seg := 1, unit := false) -> void:
		var st := _tool(m)
		var h := size * 0.5
		if bevel <= 0.0005:
			for f in FACES:
				var n: Vector3 = f[0]
				var u: Vector3 = f[1]
				var v: Vector3 = f[2]
				_face(st, xf, n * absf(n.dot(h)), u, v, absf(u.dot(h)), absf(v.dot(h)), uvs, Vector2.ZERO, unit)
			return
		var r := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.95)
		var inner := h - Vector3(r, r, r)
		for f in FACES:
			var n: Vector3 = f[0]
			var u: Vector3 = f[1]
			var v: Vector3 = f[2]
			var hu := absf(u.dot(h))
			var hv := absf(v.dot(h))
			var iu := absf(u.dot(inner))
			var iv := absf(v.dot(inner))
			var su := _samples(iu, r, seg)
			var sv := _samples(iv, r, seg)
			var grid := []
			for j in sv.size():
				var row := []
				for i in su.size():
					var p: Vector3 = n * absf(n.dot(h)) + u * su[i] + v * sv[j]
					var pc := p.clamp(-inner, inner)
					var nn := (p - pc).normalized()
					var uv := Vector2((su[i] + hu) * uvs, (hv - sv[j]) * uvs)
					if unit:
						uv = Vector2((su[i] + hu) / (2.0 * hu), (hv - sv[j]) / (2.0 * hv))
					row.append([pc + nn * r, nn, uv])
				grid.append(row)
			for j in sv.size() - 1:
				for i in su.size() - 1:
					var bl: Array = grid[j][i]
					var br: Array = grid[j][i + 1]
					var tr: Array = grid[j + 1][i + 1]
					var tl: Array = grid[j + 1][i]
					for q in [tl, tr, br, tl, br, bl]:
						_v(st, xf, q[0], q[1], q[2])

	static func basis_y(d: Vector3) -> Basis:
		var y := d.normalized()
		var x := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var z := x.cross(y).normalized()
		x = y.cross(z).normalized()
		return Basis(x, y, z)

	static func _samples(inner: float, r: float, seg: int) -> Array:
		var out := []
		for k in range(seg, -1, -1):
			out.append(-(inner + r * tan(PI / 4.0 * k / seg)))
		for k in seg + 1:
			out.append(inner + r * tan(PI / 4.0 * k / seg))
		return out

	## Caja colocada por su centro (atajo)
	func cube(pos: Vector3, size: Vector3, m: Material, rot := Vector3.ZERO, uvs := 1.0, bevel := 0.0, seg := 1) -> void:
		box(Transform3D(Basis.from_euler(rot), pos), size, m, uvs, bevel, seg)

	## Cilindro vertical (eje Y) centrado en xf.origin
	func cylinder(xf: Transform3D, r_top: float, r_bot: float, h: float, m: Material, seg := 16, caps := true) -> void:
		var st := _tool(m)
		var hy := h * 0.5
		var slope := (r_bot - r_top) / maxf(h, 0.0001)
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var n0 := (d0 + Vector3(0, slope, 0)).normalized()
			var n1 := (d1 + Vector3(0, slope, 0)).normalized()
			var u0 := float(i) / seg
			var u1 := float(i + 1) / seg
			var tl := d1 * r_top + Vector3(0, hy, 0)
			var tr := d0 * r_top + Vector3(0, hy, 0)
			var br := d0 * r_bot - Vector3(0, hy, 0)
			var bl := d1 * r_bot - Vector3(0, hy, 0)
			for vv in [[tl, n1, Vector2(u1, 0)], [tr, n0, Vector2(u0, 0)], [br, n0, Vector2(u0, h)], [tl, n1, Vector2(u1, 0)], [br, n0, Vector2(u0, h)], [bl, n1, Vector2(u1, h)]]:
				_v(st, xf, vv[0], vv[1], vv[2])
			if caps:
				for p in [Vector3(0, hy, 0), d0 * r_top + Vector3(0, hy, 0), d1 * r_top + Vector3(0, hy, 0)]:
					_v(st, xf, p, Vector3.UP, Vector2(p.x, p.z))
				for p2 in [Vector3(0, -hy, 0), d1 * r_bot - Vector3(0, hy, 0), d0 * r_bot - Vector3(0, hy, 0)]:
					_v(st, xf, p2, Vector3.DOWN, Vector2(p2.x, p2.z))

	func cyl(pos: Vector3, r_top: float, r_bot: float, h: float, m: Material, rot := Vector3.ZERO, seg := 16) -> void:
		cylinder(Transform3D(Basis.from_euler(rot), pos), r_top, r_bot, h, m, seg)

	## Cilindro entre dos puntos
	func segment(a: Vector3, b: Vector3, r: float, m: Material, seg := 10, caps := true, r_b := -1.0) -> void:
		var d := b - a
		if d.length() < 0.0001:
			return
		cylinder(Transform3D(Batch.basis_y(d), (a + b) * 0.5), r if r_b < 0.0 else r_b, r, d.length(), m, seg, caps)

	## Pieza torneada: perfil de radios (r, y) girado alrededor del eje Y
	func lathe(xf: Transform3D, prof: Array, m: Material, seg := 20) -> void:
		var st := _tool(m)
		for k in prof.size() - 1:
			var p0: Vector2 = prof[k]
			var p1: Vector2 = prof[k + 1]
			var dv := p1 - p0
			var nrm2 := Vector2(dv.y, -dv.x).normalized()
			for i in seg:
				var a0 := TAU * i / seg
				var a1 := TAU * (i + 1) / seg
				var c0 := Vector3(cos(a0), 0, sin(a0))
				var c1 := Vector3(cos(a1), 0, sin(a1))
				var q00 := c0 * p0.x + Vector3(0, p0.y, 0)
				var q10 := c1 * p0.x + Vector3(0, p0.y, 0)
				var q01 := c0 * p1.x + Vector3(0, p1.y, 0)
				var q11 := c1 * p1.x + Vector3(0, p1.y, 0)
				var n0 := c0 * nrm2.x + Vector3(0, nrm2.y, 0)
				var n1 := c1 * nrm2.x + Vector3(0, nrm2.y, 0)
				var u0 := float(i) / seg
				var u1 := float(i + 1) / seg
				for vv in [[q11, n1, Vector2(u1, p1.y)], [q01, n0, Vector2(u0, p1.y)], [q00, n0, Vector2(u0, p0.y)], [q11, n1, Vector2(u1, p1.y)], [q00, n0, Vector2(u0, p0.y)], [q10, n1, Vector2(u1, p0.y)]]:
					_v(st, xf, vv[0], vv[1], vv[2])

	## Esfera de pocos polígonos (remaches, cuentas, cristales)
	func sphere(pos: Vector3, r: float, m: Material, seg := 8, rings := 5, scl := Vector3.ONE) -> void:
		var st := _tool(m)
		var xf := Transform3D(Basis.from_scale(scl), pos)
		for j in rings:
			var t0 := PI * j / rings
			var t1 := PI * (j + 1) / rings
			for i in seg:
				var a0 := TAU * i / seg
				var a1 := TAU * (i + 1) / seg
				var p00 := Vector3(sin(t0) * cos(a0), cos(t0), sin(t0) * sin(a0))
				var p10 := Vector3(sin(t0) * cos(a1), cos(t0), sin(t0) * sin(a1))
				var p01 := Vector3(sin(t1) * cos(a0), cos(t1), sin(t1) * sin(a0))
				var p11 := Vector3(sin(t1) * cos(a1), cos(t1), sin(t1) * sin(a1))
				for p in [p10, p00, p01, p10, p01, p11]:
					st.set_normal((xf.basis * (p as Vector3)).normalized())
					st.set_uv(Vector2(float(i) / seg, float(j) / rings))
					st.add_vertex(xf * ((p as Vector3) * r))

	## Pared con huecos: rectángulos en el plano XY local, mirando a +Z, con UV continuas (en metros / tile)
	func rects(xf: Transform3D, list: Array, m: Material, tile := 1.0) -> void:
		var st := _tool(m)
		for rr in list:
			var r: Rect2 = rr
			var c := Vector3(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5, 0)
			_face(st, xf, c, Vector3.RIGHT, Vector3.UP, r.size.x * 0.5, r.size.y * 0.5, 1.0 / tile, Vector2(r.position.x, -r.end.y) / tile)

	## Moldura recta: perfil (salida z, altura y) extruido a lo largo de X local, de x0 a x1
	func molding(xf: Transform3D, x0: float, x1: float, prof: Array, m: Material, caps := false) -> void:
		var st := _tool(m)
		if caps:
			# tapas en los extremos (abanico desde el centro del perfil, por las dos caras)
			var ctr := Vector2.ZERO
			for p in prof:
				ctr += p
			ctr /= prof.size()
			for ex in [[x0, Vector3.LEFT], [x1, Vector3.RIGHT]]:
				var xx: float = ex[0]
				var nn: Vector3 = ex[1]
				for k in prof.size():
					var a2: Vector2 = prof[k]
					var b2: Vector2 = prof[(k + 1) % prof.size()]
					var pc := Vector3(xx, ctr.y, ctr.x)
					var pa := Vector3(xx, a2.y, a2.x)
					var pb := Vector3(xx, b2.y, b2.x)
					for q in [pc, pa, pb, pc, pb, pa]:
						_v(st, xf, q, nn, Vector2(q.z, q.y))
		var normals := _profile_normals(prof, false)
		for k in prof.size() - 1:
			var a: Vector2 = prof[k]
			var b: Vector2 = prof[k + 1]
			var na: Vector3 = normals[k][1]
			var nb: Vector3 = normals[k + 1][0]
			var pa0 := Vector3(x0, a.y, a.x)
			var pa1 := Vector3(x1, a.y, a.x)
			var pb0 := Vector3(x0, b.y, b.x)
			var pb1 := Vector3(x1, b.y, b.x)
			var la := a.y
			var lb := b.y
			for vv in [[pb0, nb, Vector2(x0, lb)], [pb1, nb, Vector2(x1, lb)], [pa1, na, Vector2(x1, la)], [pb0, nb, Vector2(x0, lb)], [pa1, na, Vector2(x1, la)], [pa0, na, Vector2(x0, la)]]:
				_v(st, xf, vv[0], vv[1], vv[2])

	## Normales suavizadas de un perfil: para cada punto, [normal hacia el tramo anterior, hacia el siguiente]
	static func _profile_normals(prof: Array, frame: bool) -> Array:
		var seg_n := []
		for k in prof.size() - 1:
			var d: Vector2 = prof[k + 1] - prof[k]
			if frame:
				seg_n.append(Vector2(-d.y, d.x).normalized())
			else:
				seg_n.append(Vector3(0, -d.x, d.y).normalized())
		var out := []
		for k in prof.size():
			var prev = seg_n[k - 1] if k > 0 else seg_n[0]
			var next = seg_n[k] if k < seg_n.size() else seg_n[seg_n.size() - 1]
			var avg = (prev + next).normalized()
			var dot: float = prev.dot(next)
			if dot < 0.5:
				out.append([prev, next])
			else:
				out.append([avg, avg])
		return out

	## Marco ingletado alrededor de un rectángulo (ancho w, alto h, plano XY local, saliendo hacia +Z).
	## Perfil: (distancia hacia dentro desde el borde exterior, salida). sides: abajo, derecha, arriba, izquierda
	func frame(xf: Transform3D, w: float, h: float, prof: Array, m: Material, sides := [true, true, true, true]) -> void:
		var st := _tool(m)
		var normals := _profile_normals(prof, true)
		var defs := [[Vector3(0, -h / 2.0, 0), Vector3.UP, w / 2.0], [Vector3(w / 2.0, 0, 0), Vector3.LEFT, h / 2.0],
			[Vector3(0, h / 2.0, 0), Vector3.DOWN, w / 2.0], [Vector3(-w / 2.0, 0, 0), Vector3.RIGHT, h / 2.0]]
		for s in 4:
			if not sides[s]:
				continue
			var c: Vector3 = defs[s][0]
			var inw: Vector3 = defs[s][1]
			var hl: float = defs[s][2]
			var along := inw.cross(Vector3.BACK)
			for k in prof.size() - 1:
				var a: Vector2 = prof[k]
				var b: Vector2 = prof[k + 1]
				var na2: Vector2 = normals[k][1]
				var nb2: Vector2 = normals[k + 1][0]
				var na := (inw * na2.x + Vector3.BACK * na2.y).normalized()
				var nb := (inw * nb2.x + Vector3.BACK * nb2.y).normalized()
				var la_l := hl - (a.x if sides[(s + 3) % 4] else 0.0)
				var la_r := hl - (a.x if sides[(s + 1) % 4] else 0.0)
				var lb_l := hl - (b.x if sides[(s + 3) % 4] else 0.0)
				var lb_r := hl - (b.x if sides[(s + 1) % 4] else 0.0)
				var pa0 := c + inw * a.x - along * la_l + Vector3.BACK * a.y
				var pa1 := c + inw * a.x + along * la_r + Vector3.BACK * a.y
				var pb0 := c + inw * b.x - along * lb_l + Vector3.BACK * b.y
				var pb1 := c + inw * b.x + along * lb_r + Vector3.BACK * b.y
				for vv in [[pb0, nb, Vector2(-lb_l, b.x)], [pb1, nb, Vector2(lb_r, b.x)], [pa1, na, Vector2(la_r, a.x)], [pb0, nb, Vector2(-lb_l, b.x)], [pa1, na, Vector2(la_r, a.x)], [pa0, na, Vector2(-la_l, a.x)]]:
					_v(st, xf, vv[0], vv[1], vv[2])

	func commit(parent: Node, shadows := true) -> Array:
		var out := []
		for k in _st.keys():
			var st: SurfaceTool = _st[k]
			st.generate_tangents()
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = _mats[k]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
			out.append(mi)
		_st.clear()
		_mats.clear()
		return out


## Base cuyo eje Y apunta en la dirección d
static func basis_y(d: Vector3) -> Basis:
	return Batch.basis_y(d)


# ------------------------------------------------------------------ materiales

static func mat(col: Color, rough := 0.7, metal := 0.0, key := "") -> StandardMaterial3D:
	var k := key if key != "" else "c%s_%s_%s" % [col.to_html(), rough, metal]
	if _mat_cache.has(k):
		return _mat_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if metal > 0.5:
		m.metallic_specular = 0.8
	_mat_cache[k] = m
	return m


## Material con textura de tex3d.gd (albedo + relieve). tile = metros que cubre la textura
static func pbr(kind: String, p: Dictionary, tile: float, rough: float, tint := Color.WHITE, normal_scale := 1.0, metal := 0.0, clearcoat := 0.0) -> StandardMaterial3D:
	var k := "pbr_%s_%s_%s_%s_%s_%s" % [kind, JSON.stringify(p), tile, rough, tint.to_html(), metal]
	if _mat_cache.has(k):
		return _mat_cache[k]
	var s := Tex.get_set(kind, p)
	var m := StandardMaterial3D.new()
	m.albedo_texture = s["albedo"]
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = metal
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_scale = Vector3(1.0 / tile, 1.0 / tile, 1.0)
	if s["normal"] != null:
		m.normal_enabled = true
		m.normal_texture = s["normal"]
		m.normal_scale = normal_scale
	if clearcoat > 0.0:
		m.clearcoat_enabled = true
		m.clearcoat = clearcoat
		m.clearcoat_roughness = 0.15
	_mat_cache[k] = m
	return m


static func tex_mat(tex: Texture2D, rough := 0.7, tint := Color.WHITE, triplanar := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if triplanar > 0.0:
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * triplanar
	return m


static func emissive(col: Color, energy := 1.0) -> StandardMaterial3D:
	var k := "e%s_%s" % [col.to_html(), energy]
	if _mat_cache.has(k):
		return _mat_cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	_mat_cache[k] = m
	return m


static func screen_mat(tex: Texture2D, energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = Color(energy, energy, energy)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return m


static func glass(tint := Color(0.75, 0.88, 1.0, 0.12)) -> StandardMaterial3D:
	var k := "glass%s" % tint.to_html()
	if _mat_cache.has(k):
		return _mat_cache[k]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = tint
	m.roughness = 0.03
	m.metallic_specular = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[k] = m
	return m


## Cristal tallado de la lámpara de araña: brillante y algo emisivo
static func crystal() -> StandardMaterial3D:
	if _mat_cache.has("crystal"):
		return _mat_cache["crystal"]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.95, 0.97, 1.0, 0.45)
	m.roughness = 0.0
	m.metallic = 0.3
	m.metallic_specular = 1.0
	m.emission_enabled = true
	m.emission = Color(1.0, 0.92, 0.8)
	m.emission_energy_multiplier = 0.35
	m.rim_enabled = true
	m.rim = 1.0
	_mat_cache["crystal"] = m
	return m


static func gold() -> StandardMaterial3D:
	if _mat_cache.has("gold"):
		return _mat_cache["gold"]
	var m := pbr("brushed", {}, 0.25, 0.28, Color("d4a656"), 0.35, 0.92).duplicate()
	m.metallic_specular = 0.9
	_mat_cache["gold"] = m
	return m


static func chrome() -> StandardMaterial3D:
	return mat(Color("d0d2d8"), 0.12, 0.95, "chrome")


static func velvet(col: Color) -> StandardMaterial3D:
	var k := "velvet" + col.to_html()
	if _mat_cache.has(k):
		return _mat_cache[k]
	var m := pbr("velvet", {}, 0.5, 0.88, col.lightened(0.08), 0.8).duplicate()
	m.rim_enabled = true
	m.rim = 0.65
	m.rim_tint = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[k] = m
	return m


static func leather(col: Color, rough := 0.42) -> StandardMaterial3D:
	return pbr("leather", {}, 0.35, rough, col.lightened(0.18), 0.6)


## Cuero capitoné; tile = metros que ocupan dos rombos
static func tufted(col: Color, tile := 0.26) -> StandardMaterial3D:
	return pbr("tufted", {}, tile, 0.4, col.lightened(0.3), 1.0)


static func wood(name: String) -> StandardMaterial3D:
	if name == "marmol":
		return pbr("wood", Tex.wood_params("marmol"), 0.8, 0.12, Color.WHITE, 0.4, 0.0, 0.5)
	if name == "panel":
		return pbr("wood", Tex.wood_params("panel"), 0.6, 0.42, Color.WHITE, 0.8)
	return pbr("wood", Tex.wood_params(name), 0.6, 0.3, Color.WHITE, 0.8, 0.0, 0.6)


static func panel_wood() -> StandardMaterial3D:
	return wood("panel")


static func plaster(col: Color) -> StandardMaterial3D:
	return pbr("plaster", {}, 1.2, 0.85, col, 0.5)


# ------------------------------------------------------------------ texturas sencillas

## Disco blanco suavizado (fondo de las insignias)
static func disc_tex() -> ImageTexture:
	if _tex_cache.has("disc"):
		return _tex_cache["disc"]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length()
			var a := clampf(30.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["disc"] = t
	return t


## Degradado radial para sombras de contacto (negro con alfa)
static func blob_tex() -> ImageTexture:
	if _tex_cache.has("blob"):
		return _tex_cache["blob"]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2((x - 31.5) / 31.5, (y - 31.5) / 31.5).length()
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * a * (3.0 - 2.0 * a)))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["blob"] = t
	return t


## Degradado lineal (oscuro abajo) para el sombreado de rincones
static func ramp_tex() -> ImageTexture:
	if _tex_cache.has("ramp"):
		return _tex_cache["ramp"]
	var img := Image.create(4, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		var a := pow(float(y) / 63.0, 2.2)
		for x in 4:
			img.set_pixel(x, y, Color(0, 0, 0, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["ramp"] = t
	return t


static func _shadow_mat(tex: Texture2D, strength: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.albedo_color = Color(0, 0, 0, strength)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = -1
	m.set_meta("base_strength", strength)
	shadow_mats.append(m)
	return m


## Sombra de contacto suave bajo un mueble u objeto (rectángulo de sx × sz en el suelo o una superficie)
static func blob(parent: Node, pos: Vector3, sx: float, sz: float, strength := 0.55, rot_y := 0.0) -> MeshInstance3D:
	var k := "blobmat%s" % strength
	if not _mat_cache.has(k):
		_mat_cache[k] = _shadow_mat(blob_tex(), strength)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(sx, sz)
	mi.mesh = pm
	mi.material_override = _mat_cache[k]
	mi.position = pos + Vector3(0, 0.003, 0)
	mi.rotation = Vector3(0, rot_y, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Franja de sombreado de rincón (oclusión ambiental falsa) sobre un plano: xf mira a +Z, oscuro en y=0
static func corner_ao(parent: Node, xf: Transform3D, length: float, height: float, strength := 0.45) -> void:
	var k := "aomat%s" % strength
	if not _mat_cache.has(k):
		_mat_cache[k] = _shadow_mat(ramp_tex(), strength)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(length, height)
	mi.mesh = q
	mi.material_override = _mat_cache[k]
	mi.transform = xf * Transform3D(Basis(), Vector3(0, height * 0.5, 0.004))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# ------------------------------------------------------------------ cuerpos

static func shape_box(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s


static func shape_cyl(r: float, h: float) -> CylinderShape3D:
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	return s


## Colisión estática invisible
static func solid(parent: Node, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation = rot
	var cs := CollisionShape3D.new()
	cs.shape = shape_box(size)
	b.add_child(cs)
	parent.add_child(b)
	return b


static func add_shape(body: CollisionObject3D, shape: Shape3D, pos := Vector3.ZERO, rot := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	cs.rotation = rot
	body.add_child(cs)
	return cs


## Objeto físico: cuerpo rígido con forma y masa. La geometría se añade después como hijos.
static func rigid(parent: Node, pos: Vector3, shape: Shape3D, mass: float, rot := Vector3.ZERO, shape_pos := Vector3.ZERO) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.mass = mass
	b.position = pos
	b.rotation = rot
	b.collision_layer = 2
	b.collision_mask = 1 | 2 | 8
	b.continuous_cd = mass < 0.3
	b.angular_damp = 0.6
	b.linear_damp = 0.08
	var pm := PhysicsMaterial.new()
	pm.friction = 0.75
	pm.bounce = 0.12
	b.physics_material_override = pm
	add_shape(b, shape, shape_pos)
	parent.add_child(b)
	return b


static func mesh(parent: Node, m: Mesh, mt: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mt
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func sphere_mesh(r: float, seg := 24) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s


static func torus_mesh(inner: float, outer: float, seg := 32) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = seg
	t.ring_segments = 12
	return t


static func capsule_mesh(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 20
	c.rings = 8
	return c


static func quad_mesh(size: Vector2) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	return q


## Texto 3D fijo (rótulos, placas)
static func label(parent: Node, text: String, font: Font, size: int, col: Color, pos: Vector3, rot := Vector3.ZERO, px := 0.0012) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = size
	l.modulate = col
	l.outline_size = 0
	l.pixel_size = px
	l.position = pos
	l.rotation = rot
	l.double_sided = false
	l.shaded = true
	parent.add_child(l)
	return l
