extends "res://scripts/stages3d/stage_3d.gd"
## Salón de negociaciones del Palacio: mesa larga de caoba con placas, banderitas, agua y carpetas, sillones de
## cuero capitoné, lámpara de araña, tapiz y ventanales. El presidente (la cámara, en primera persona) se sienta a
## un lado con una tableta delante (la interfaz de la negociación); enfrente, el otro líder con dos asesores y las
## banderas de su país detrás. En las cumbres, mesa redonda con tres líderes: se elige a uno haciendo clic en él.

signal leader_clicked(index: int)

const H := 4.3
const X0 := -5.5
const X1 := 5.5
const Z0 := -3.0
const Z1 := 4.6
const TABLE_H := 0.76
## Los de enfrente se sientan aquí; el presidente en z = 0
const FAR_Z := 2.05
const WALLPAPER := {"c0": "e7dcc4", "c1": "dccfb2", "acc": "b89a5a"}
const RUG := {"c0": "6e1820", "c1": "3d0b10"}

## [{"look": Dictionary, "country": String, "name": String, "role": String}]; tres en las cumbres
var parties: Array = []
var summit := false
## Personajes 3D de cada parte (mismo orden que parties): exponen talking / mood / anger
var leaders: Array = []
var _sel_light: SpotLight3D
var _rng := RandomNumberGenerator.new()
var _m := {}


func build() -> void:
	_rng.seed = 23
	_m = {
		"wall": Kit.pbr("wallpaper", WALLPAPER, 0.9, 0.78, Color.WHITE, 0.8),
		"panel": Kit.wood("panel"),
		"floor": Kit.pbr("parquet", {}, 1.4, 0.45, Color(0.9, 0.86, 0.82), 0.7, 0.0, 0.25),
		"rug": Kit.pbr("carpet", RUG, 3.2, 0.95, Color.WHITE, 0.8),
		"ceiling": Kit.plaster(Color("efe9dc")),
		"wood": Kit.wood("caoba"),
		"dark": Kit.wood("ebano"),
		"gold": Kit.gold(),
		"leather": Kit.tufted(Color("4a1c16"), 0.24),
		"leather_s": Kit.leather(Color("4a1c16")),
		"inlay": Kit.leather(Color("1f3a2a"), 0.5),
		"curtain": Kit.velvet(Color("5a1a22")),
		"cream": Kit.mat(Color("efe7d6"), 0.5),
		"paper": Kit.mat(Color("f4f1e8"), 0.9),
		"glass": Kit.glass(Color(0.85, 0.92, 1.0, 0.22)),
		"water": Kit.glass(Color(0.75, 0.86, 0.95, 0.35)),
		"crystal": Kit.crystal(),
		"lamp": Kit.emissive(Color(1.0, 0.85, 0.6), 3.0),
	}
	_room()
	if summit:
		_round_table()
	else:
		_long_table()
	_lights()
	b.commit(world)
	# primera persona en la mesa con la tableta delante; el líder (o los tres) por encima de ella
	var eye := Vector3(0, 1.3, 0.08 if summit else 0.0)
	ui = pov_screen(eye, 0.0, Vector2i(1240, 580 if summit else 500), 0.95, 12.0, 24.0 if summit else 25.0, 0.78, 1.6)
	if summit:
		_sel_light = spot(Vector3(0, 3.6, 1.0), Vector3(0, 1.2, 3.0), 2.2, 14.0, Color(1.0, 0.9, 0.7), false, 8.0)


## El líder con quien se habla (cumbres): un foco cálido sobre él
func select(i: int) -> void:
	if _sel_light == null or i < 0 or i >= leaders.size():
		return
	var t: Vector3 = (leaders[i] as Node3D).global_position + Vector3(0, 1.1, 0)
	_sel_light.look_at_from_position(t + Vector3(0, 2.6, -1.2), t, Vector3.UP)


## Clic sobre un líder (cumbres): el más cercano al rayo, a la altura del pecho o la cabeza
func _click_world(from: Vector3, dir: Vector3) -> bool:
	var best := -1
	var best_d := 0.45
	for i in leaders.size():
		var c: Vector3 = (leaders[i] as Node3D).global_position + Vector3(0, 1.05, 0)
		var t := maxf(0.0, (c - from).dot(dir))
		var d := (from + dir * t).distance_to(c)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return false
	leader_clicked.emit(best)
	return true


func _room() -> void:
	var w := X1 - X0
	var d := Z1 - Z0
	var cz := (Z0 + Z1) * 0.5
	b.cube(Vector3(0, -0.05, cz), Vector3(w, 0.1, d), _m["floor"], Vector3.ZERO, 1.0)
	b.cube(Vector3(0, H + 0.05, cz), Vector3(w, 0.1, d), _m["ceiling"])
	var rug := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(7.0, 4.6)
	rug.mesh = pm
	rug.material_override = _m["rug"]
	world.add_child(rug)
	rug.position = Vector3(0, 0.006, 1.0)
	# cuatro paredes con zócalo, papel de damasco y moldura de techo
	var walls := [
		[Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, Z1)), w],
		[Transform3D(Basis(), Vector3(0, 0, Z0)), w],
		[Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(X0, 0, cz)), d],
		[Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(X1, 0, cz)), d],
	]
	for wl in walls:
		var xf: Transform3D = wl[0]
		var hl: float = wl[1] * 0.5
		b.rects(xf, [Rect2(-hl, 1.0, hl * 2.0, H - 1.0)], _m["wall"], 1.0)
		b.rects(xf, [Rect2(-hl, 0.0, hl * 2.0, 1.0)], _m["panel"], 1.0)
		b.molding(xf * Transform3D(Basis(), Vector3(0, 0.965, 0)), -hl, hl, Kit.PROFILE_RAIL, _m["dark"])
		b.molding(xf, -hl, hl, Kit.PROFILE_BASE, _m["dark"])
		b.molding(xf * Transform3D(Basis(), Vector3(0, H - 0.175, 0)), -hl, hl, Kit.PROFILE_CROWN, _m["cream"])
		var px := -hl + 0.7
		while px < hl - 0.5:
			b.box(xf * Transform3D(Basis(), Vector3(px, 0.5, 0.008)), Vector3(0.8, 0.6, 0.02), _m["panel"], 1.0, 0.01)
			b.frame(xf * Transform3D(Basis(), Vector3(px, 0.5, 0.0)), 0.9, 0.7, Kit.FRAME_PANEL, _m["dark"])
			px += 1.1
	# pared del fondo: tapiz en el centro, ventanales con cortinas a los lados
	var back := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, Z1))
	_tapestry(back * Transform3D(Basis(), Vector3(0, 2.45, 0.04)))
	for sx in [-1.0, 1.0]:
		_window(back * Transform3D(Basis(), Vector3(sx * 3.6, 2.35, 0.0)))
	# paredes laterales: cuadros con marco dorado y apliques
	for sx in [-1.0, 1.0]:
		var side := Transform3D(Basis(Vector3.UP, -PI / 2.0 * sx), Vector3(X0 if sx < 0 else X1, 0, cz))
		for u in [-2.2, 2.2]:
			var pxf := side * Transform3D(Basis(), Vector3(u, 2.3, 0.03))
			b.box(pxf, Vector3(1.3, 0.95, 0.02), Kit.mat(Color("5d6b4a").lerp(Color("8a6a4a"), 0.5 + 0.5 * sx), 0.8))
			b.frame(pxf, 1.46, 1.11, Kit.FRAME_ORNATE, _m["gold"])
		for u in [-4.0, 0.0, 4.0]:
			var sp := side * Transform3D(Basis(), Vector3(u * 0.85, 2.35, 0.0))
			b.lathe(sp * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0, 0.02)), [Vector2(0.07, 0.0), Vector2(0.06, 0.02), Vector2(0.0, 0.03)], _m["gold"], 16)
			b.segment(sp.origin + sp.basis.z * 0.03, sp.origin + sp.basis.z * 0.22 + Vector3(0, 0.1, 0), 0.01, _m["gold"], 8)
			b.lathe(Transform3D(Basis(), sp.origin + sp.basis.z * 0.22 + Vector3(0, 0.1, 0)), [Vector2(0.055, 0.0), Vector2(0.085, 0.14), Vector2(0.0, 0.14)], Kit.mat(Color("f3e6c8"), 0.6), 16)
			glow(sp.origin + sp.basis.z * 0.22 + Vector3(0, 0.17, 0), 0.32, Color(1, 0.8, 0.55, 0.6))
	# lámpara de araña sobre la mesa
	_chandelier(Vector3(0, H, 1.0))


## Tapiz con escena y orla dorada (fondo de las fotos oficiales)
func _tapestry(xf: Transform3D) -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(800, 520)
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var c := Control.new()
	c.size = Vector2(800, 520)
	c.draw.connect(func():
		c.draw_rect(Rect2(0, 0, 800, 520), Color("3b4a2e"))
		for i in 7:
			c.draw_rect(Rect2(0, 300 + i * 32, 800, 32), Color("4a5a36").lerp(Color("6a5a3a"), i / 7.0))
		for i in 9:
			var x := 40.0 + i * 92.0
			c.draw_circle(Vector2(x, 290 + sin(i * 1.7) * 30), 70 + (i % 3) * 18, Color("2c3a24").lerp(Color("4c5a32"), (i % 4) / 4.0))
		c.draw_circle(Vector2(560, 120), 46, Color("d8c38a"))
		for i in 5:
			c.draw_rect(Rect2(150 + i * 110, 330 - i * 6, 26, 120), Color("6b4a2a"))
		c.draw_rect(Rect2(0, 0, 800, 520), Color("b8954a"), false, 26.0)
		c.draw_rect(Rect2(20, 20, 760, 480), Color("7a1f22"), false, 8.0))
	sv.add_child(c)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3.6, 2.34)
	mi.mesh = q
	mi.material_override = Kit.tex_mat(sv.get_texture(), 0.95)
	world.add_child(mi)
	mi.global_transform = xf
	b.box(xf * Transform3D(Basis(), Vector3(0, 1.22, 0.02)), Vector3(3.9, 0.06, 0.06), _m["gold"], 1.0, 0.02)


func _window(xf: Transform3D) -> void:
	b.box(xf * Transform3D(Basis(), Vector3(0, 0, 0.012)), Vector3(1.3, 2.8, 0.01), Kit.emissive(Color(0.8, 0.88, 1.0), 1.4))
	for k in 2:
		b.box(xf * Transform3D(Basis(), Vector3(0, -0.7 + k * 1.4, 0.03)), Vector3(1.3, 0.05, 0.04), _m["cream"])
	b.box(xf * Transform3D(Basis(), Vector3(0, 0, 0.03)), Vector3(0.05, 2.8, 0.04), _m["cream"])
	b.frame(xf, 1.46, 2.96, Kit.FRAME_CASING, _m["cream"])
	for sx in [-1.0, 1.0]:
		b.box(xf * Transform3D(Basis(), Vector3(sx * 0.85, -0.15, 0.14)), Vector3(0.5, 3.5, 0.12), _m["curtain"], 1.0, 0.05, 2)
	b.box(xf * Transform3D(Basis(), Vector3(0, 1.65, 0.16)), Vector3(2.4, 0.4, 0.14), _m["curtain"], 1.0, 0.04, 2)
	b.box(xf * Transform3D(Basis(), Vector3(0, 1.86, 0.2)), Vector3(2.5, 0.04, 0.06), _m["gold"], 1.0, 0.015)


func _chandelier(top: Vector3) -> void:
	var c := top - Vector3(0, 1.0, 0)
	b.segment(top, c + Vector3(0, 0.25, 0), 0.012, _m["gold"], 8)
	b.lathe(Transform3D(Basis(), c), [Vector2(0.0, -0.18), Vector2(0.06, -0.12), Vector2(0.1, 0.0), Vector2(0.05, 0.12), Vector2(0.03, 0.26), Vector2(0.0, 0.3)], _m["gold"], 18)
	for i in 8:
		var a := TAU * i / 8.0
		var tip := c + Vector3(cos(a) * 0.55, 0.06, sin(a) * 0.55)
		b.segment(c + Vector3(0, -0.04, 0), tip - Vector3(0, 0.05, 0), 0.01, _m["gold"], 6)
		b.lathe(Transform3D(Basis(), tip - Vector3(0, 0.05, 0)), [Vector2(0.04, 0.0), Vector2(0.05, 0.03), Vector2(0.0, 0.04)], _m["gold"], 12)
		b.cyl(tip + Vector3(0, 0.05, 0), 0.012, 0.012, 0.1, _m["cream"])
		b.sphere(tip + Vector3(0, 0.12, 0), 0.016, _m["lamp"], 8, 5, Vector3(1, 1.5, 1))
		b.sphere(c + Vector3(cos(a + 0.4) * 0.3, -0.22, sin(a + 0.4) * 0.3), 0.025, _m["crystal"], 8, 5, Vector3(1, 1.6, 1))
	glow(c + Vector3(0, 0.15, 0), 1.6, Color(1, 0.82, 0.55, 0.35))


# ------------------------------------------------------------------ mesas

func _armchair(pos: Vector3, yaw: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.38, 0.06)), Vector3(0.62, 0.14, 0.56), _m["leather_s"], 1.0, 0.04, 2)
	b.box(xf * Transform3D(Basis(Vector3.RIGHT, -0.1), Vector3(0, 0.88, -0.24)), Vector3(0.62, 0.95, 0.12), _m["leather"], 1.0, 0.05, 2)
	for sx in [-0.33, 0.33]:
		b.box(xf * Transform3D(Basis(), Vector3(sx, 0.56, 0.02)), Vector3(0.08, 0.1, 0.5), _m["leather_s"], 1.0, 0.035, 2)
		b.box(xf * Transform3D(Basis(), Vector3(sx, 0.2, 0.02)), Vector3(0.06, 0.4, 0.5), _m["wood"], 1.0, 0.01)
	for sz in [-0.2, 0.28]:
		for sx in [-0.28, 0.28]:
			b.cyl((xf * Transform3D(Basis(), Vector3(sx, 0.06, sz))).origin, 0.025, 0.02, 0.12, _m["wood"])
	Kit.blob(world, pos, 0.8, 0.8, 0.4, yaw)


## Placa con el nombre sobre la mesa, mirando hacia dir
func _plate(pos: Vector3, yaw: float, text: String) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	b.box(xf * Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.035, 0)), Vector3(0.34, 0.08, 0.006), _m["dark"])
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.005, -0.02)), Vector3(0.34, 0.01, 0.06), _m["gold"])
	var l := Kit.label(world, text, UI.f_serif_b, 34, Color("f2e6c8"), (xf * Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.037, 0.01))).origin, Vector3(-0.5, yaw, 0), 0.0011)
	l.shaded = false


## Banderita de mesa con su mástil
func _desk_flag(pos: Vector3, id: String) -> void:
	b.cyl(pos + Vector3(0, 0.01, 0), 0.03, 0.035, 0.02, _m["gold"])
	b.cyl(pos + Vector3(0, 0.2, 0), 0.004, 0.004, 0.38, _m["gold"])
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.15)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = flag_tex(id)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.8
	mi.material_override = m
	world.add_child(mi)
	# la textura de flag_tex() va en vertical (vaina arriba): girada un cuarto, la vaina queda junto al mástil
	mi.global_transform = Transform3D(Basis(Vector3.BACK, PI / 2.0), pos + Vector3(0.075, 0.33, 0))


func _water(pos: Vector3) -> void:
	b.cyl(pos + Vector3(0, 0.11, 0), 0.03, 0.033, 0.22, _m["water"])
	b.cyl(pos + Vector3(0, 0.235, 0), 0.012, 0.03, 0.03, _m["water"])
	b.cyl(pos + Vector3(0, 0.255, 0), 0.014, 0.014, 0.012, Kit.mat(Color("2d5aa0"), 0.4))
	b.cyl(pos + Vector3(0.09, 0.05, 0.03), 0.032, 0.028, 0.1, _m["glass"])


func _folder(pos: Vector3, yaw: float, col: Color) -> void:
	b.box(Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0, 0.008, 0)), Vector3(0.26, 0.016, 0.34), Kit.leather(col))
	b.box(Transform3D(Basis(Vector3.UP, yaw + 0.05), pos + Vector3(0.02, 0.018, 0.0)), Vector3(0.21, 0.004, 0.29), _m["paper"])
	b.segment(pos + Vector3(0.16, 0.022, -0.08), pos + Vector3(0.17, 0.022, 0.06), 0.006, _m["gold"], 6)


func _long_table() -> void:
	var p: Dictionary = parties[0] if parties.size() > 0 else {}
	var country: String = p.get("country", "")
	var flag_id := country if country != "" else "valdoria"
	# tablero de caoba con un paño de cuero verde, faldón y patas torneadas
	var tw := 4.6
	var td := FAR_Z - 0.62
	var tz := FAR_Z * 0.5
	b.box(Transform3D(Basis(), Vector3(0, TABLE_H - 0.025, tz)), Vector3(tw, 0.05, td), _m["wood"], 1.0, 0.012, 2)
	b.box(Transform3D(Basis(), Vector3(0, TABLE_H + 0.001, tz)), Vector3(tw - 0.3, 0.002, td - 0.3), _m["inlay"])
	b.box(Transform3D(Basis(), Vector3(0, TABLE_H - 0.12, tz)), Vector3(tw - 0.2, 0.14, td - 0.2), _m["wood"], 1.0, 0.01)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.lathe(Transform3D(Basis(), Vector3(sx * (tw * 0.5 - 0.22), 0, tz + sz * (td * 0.5 - 0.2))), [Vector2(0.05, 0.0), Vector2(0.04, 0.08), Vector2(0.06, 0.16), Vector2(0.035, 0.32), Vector2(0.045, 0.56), Vector2(0.06, 0.62), Vector2(0.06, TABLE_H - 0.19), Vector2(0.0, TABLE_H - 0.19)], _m["wood"], 16)
	Kit.blob(world, Vector3(0, 0, tz), tw + 0.6, td + 0.6, 0.45)
	# el otro líder y sus dos asesores enfrente (las placas miran hacia el presidente)
	var face := PI
	var lead := person(p.get("look", {}), Vector3(0, 0, FAR_Z), face, "table")
	leaders.append(lead)
	_armchair(Vector3(0, 0, FAR_Z), face)
	for sx in [-1.0, 1.0]:
		var ap := Vector3(sx * 1.15, 0, FAR_Z)
		_armchair(ap, face)
		person(rand_look(_rng), ap, face, "table", false)
		_plate(Vector3(sx * 1.15, TABLE_H, FAR_Z - 0.42), PI, "Delegación")
		_folder(Vector3(sx * 1.15, TABLE_H, FAR_Z - 0.6), 0.1 * sx, Color("2a2a2e"))
		_water(Vector3(sx * 0.62, TABLE_H, FAR_Z - 0.55))
		_folder(Vector3(sx * 1.15, TABLE_H, 0.6), -0.1 * sx, Color("1f2a44"))
	_plate(Vector3(0, TABLE_H, FAR_Z - 0.42), PI, String(p.get("name", "")))
	_folder(Vector3(0.05, TABLE_H, FAR_Z - 0.62), 0.06, Color("3a1a12"))
	# delante del presidente, bajo la tableta: su carpeta de cuero
	_folder(Vector3(-0.05, TABLE_H, 0.52), -0.04, Color("1f2a44"))
	# banderitas de las dos delegaciones, a un lado del centro de la mesa (sin tapar al líder)
	_desk_flag(Vector3(-0.72, TABLE_H, tz + 0.1), flag_id)
	_desk_flag(Vector3(-0.5, TABLE_H, tz + 0.1), "valdoria")
	# banderas grandes detrás de cada parte
	flag_pole(Vector3(-0.85, 0, Z1 - 0.7), flag_id, PI)
	flag_pole(Vector3(0.85, 0, Z1 - 0.7), "valdoria" if country == "" else flag_id, 0.0)
	flag_pole(Vector3(-2.2, 0, Z1 - 0.75), "valdoria", PI)
	flag_pole(Vector3(2.2, 0, Z1 - 0.75), "valdoria", 0.0)


func _round_table() -> void:
	var c := Vector3(0, 0, 1.75)
	var r := 1.35
	b.cylinder(Transform3D(Basis(), c + Vector3(0, TABLE_H - 0.025, 0)), r, r, 0.05, _m["wood"], 48)
	b.cylinder(Transform3D(Basis(), c + Vector3(0, TABLE_H + 0.001, 0)), r - 0.18, r - 0.18, 0.002, _m["inlay"], 48)
	b.lathe(Transform3D(Basis(), c), [Vector2(0.55, 0.0), Vector2(0.5, 0.06), Vector2(0.18, 0.14), Vector2(0.13, 0.4), Vector2(0.2, TABLE_H - 0.06), Vector2(0.0, TABLE_H - 0.06)], _m["wood"], 32)
	Kit.blob(world, c, r * 2.4, r * 2.4, 0.45)
	# de izquierda a derecha vistos desde el presidente, en el mismo orden que sus tarjetas
	var angs := [0.95, 0.0, -0.95]
	for i in parties.size():
		var p: Dictionary = parties[i]
		var a: float = angs[i % angs.size()]
		var dir := Vector3(sin(a), 0, cos(a))
		var pos := c + dir * (r + 0.32)
		var yaw := atan2(-dir.x, -dir.z)
		_armchair(pos, yaw)
		leaders.append(person(p.get("look", {}), pos, yaw, "table"))
		var country: String = p.get("country", "")
		_plate(c + dir * (r - 0.2) + Vector3(0, TABLE_H, 0), yaw, String(p.get("name", "")))
		_desk_flag(c + dir * (r - 0.45) + Vector3(0, TABLE_H, 0) + Vector3(dir.z, 0, -dir.x) * 0.2, country if country != "" else "valdoria")
		_water(c + dir * (r - 0.35) + Vector3(0, TABLE_H, 0) - Vector3(dir.z, 0, -dir.x) * 0.25)
		flag_pole(c + dir * (r + 1.45) + Vector3(dir.z, 0, -dir.x) * 0.55, country if country != "" else "valdoria", yaw + PI)
	_armchair(c - Vector3(0, 0, r + 0.32), 0.0)
	_folder(c - Vector3(0, 0, r - 0.32) + Vector3(0, TABLE_H, 0), 0.0, Color("1f2a44"))


func _lights() -> void:
	env.ambient_light_color = Color(0.78, 0.66, 0.52)
	env.ambient_light_energy = 0.4
	omni(Vector3(0, H - 1.1, 1.0), 2.6, 9.0, Color(1.0, 0.84, 0.62), hi)
	spot(Vector3(0, H - 0.2, -1.6), Vector3(0, 1.1, FAR_Z), 3.0, 32.0, Color(1.0, 0.92, 0.8), true, 12.0)
	for sx in [-1.0, 1.0]:
		spot(Vector3(sx * 3.6, 3.2, Z1 - 0.4), Vector3(sx * 1.0, 0.6, 0.6), 1.6, 40.0, Color(0.85, 0.9, 1.0), false, 9.0)
		omni(Vector3(sx * (X1 - 0.4), 2.5, 1.0), 0.8, 4.0, Color(1.0, 0.78, 0.5), false)


## Acuerdo: la foto oficial (flashes de los fotógrafos, detrás del presidente)
func celebrate() -> void:
	for i in 6:
		get_tree().create_timer(0.3 + i * 0.16).timeout.connect(func(): flash(Vector3(randf_range(-2.6, 2.6), randf_range(1.5, 1.9), -1.8)))


## Sin acuerdo: los de enfrente se levantan de la mesa y se van hacia un lado
func walk_out() -> void:
	for l in leaders:
		l.seat("")
		var dest: Vector3 = l.global_position + Vector3(1.8 if l.global_position.x >= 0.0 else -1.8, 0, 0.8)
		get_tree().create_timer(0.8).timeout.connect(func():
			if is_instance_valid(l):
				l.walk_to(dest, 2.6))
