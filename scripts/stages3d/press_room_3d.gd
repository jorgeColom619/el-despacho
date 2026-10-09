extends "res://scripts/stages3d/stage_3d.gd"
## Sala de prensa del Palacio: tarima con atril, micrófonos de los medios y banderas, fondo institucional,
## filas de periodistas, fotógrafos con flash y cámaras de televisión al fondo.
## view = "podium": la rueda de prensa, en primera persona desde el atril. Varios periodistas alzan la mano con la
## acreditación de su medio encima y se elige a quién dar la palabra haciendo clic en él; las respuestas son tarjetas
## sobre el atril y la reacción de la opinión pública sale en el monitor de cortesía de la tarima.
## view = "tv": plano de televisión desde el fondo, con el presidente en el atril (discurso).

const Crowd3D := preload("res://scripts/stages3d/crowd_3d.gd")

const H := 4.4
const X0 := -6.5
const X1 := 6.5
const Z1 := 14.0
## Tarima: de la pared del fondo hasta DAIS_Z, a DAIS_H de altura
const DAIS_Z := 2.3
const DAIS_H := 0.25
const PODIUM := Vector3(0, DAIS_H, 1.05)
## Tablero del atril, inclinado hacia el orador: aquí van las tarjetas
const TOP_XF := Transform3D(Basis(Vector3.RIGHT, -0.24), Vector3(0, DAIS_H + 1.16, 0.98))
const TOP_SIZE := Vector3(1.04, 0.05, 0.56)
const ROW_Z := 4.3
const ROW_STEP := 1.1
const ROWS := 6
## Filas con periodistas de cuerpo entero (las de atrás son público ligero)
const NEAR_ROWS := 3
const SEATS_SIDE := 6
const RISER_Z := 10.9
const RISER_H := 0.45

var view := "podium"
## Aspecto del presidente (solo en la vista de televisión)
var pres_look: Dictionary = {}
var president: Node3D
var journalists: Array = []
var photographers: Array = []
## Monitor de cortesía de la tarima (rueda de prensa): el minijuego dibuja ahí la reacción de la opinión pública
var monitor: Control
var _cam_spots: Array = []
var _asking: Node3D
var _raised: Array = []
var _flash_cd := 1.0
var _burst := 0
var _burst_cd := 0.0
var _murmur_t := 0.0
var quiet := false
var _rng := RandomNumberGenerator.new()
var _m := {}


func build() -> void:
	_rng.seed = 41
	_m = {
		"carpet": Kit.pbr("velvet", {}, 0.9, 0.95, Color("27355e"), 0.5),
		"wall": Kit.plaster(Color("d6d8dc")),
		"panel": Kit.wood("roble"),
		"dark": Kit.wood("ebano"),
		"podium": Kit.wood("caoba"),
		"ceiling": Kit.plaster(Color("eceae4")),
		"fabric": Kit.velvet(Color("43557e")),
		"seat": Kit.velvet(Color("26365f")),
		"chrome": Kit.chrome(),
		"gold": Kit.gold(),
		"black": Kit.mat(Color("17181b"), 0.45, 0.25),
		"rubber": Kit.mat(Color("0c0c0d"), 0.8),
		"lamp": Kit.emissive(Color(1.0, 0.97, 0.9), 2.2),
		"paper": Kit.mat(Color("f4f1e8"), 0.9),
		"felt": Kit.pbr("velvet", {}, 0.3, 0.97, Color("1d2f52"), 0.25),
	}
	eye = Vector3(0, DAIS_H + 1.62, 0.42)
	_room()
	_dais()
	_backdrop()
	flag_pole(Vector3(-1.75, DAIS_H, 0.42), "valdoria", 0.0)
	flag_pole(Vector3(1.75, DAIS_H, 0.42), "valdoria", PI)
	flag_pole(Vector3(-2.55, DAIS_H, 0.42), "valdoria", 0.0)
	flag_pole(Vector3(2.55, DAIS_H, 0.42), "valdoria", PI)
	_podium()
	_audience()
	_photographers()
	_tv_cameras()
	_lights()
	if view != "tv":
		_monitor()
	b.commit(world)
	if view == "tv":
		president = person(pres_look, Vector3(0, DAIS_H, 0.5), 0.0)
		president.rest_anim = "lectern"
		president.talk_anim = "lectern_talk"
		cam.fov = 18.0
		# entre las dos cámaras centrales de la tarima del fondo
		cam_pos = Vector3(0.0, RISER_H + 1.6, RISER_Z + 0.45)
		cam_look = Vector3(0, DAIS_H + 1.5, 0.7)
		sway = 0.012
	else:
		time_strip(facing(TOP_XF * Vector3(0, 0.04, TOP_SIZE.z * 0.5 - 0.012), eye), 0.6)
		pov(false)


## Centro, normal y puntos del tablero del atril (donde se reparten las tarjetas)
func top_center() -> Vector3:
	return TOP_XF * Vector3(0, TOP_SIZE.y * 0.5, 0.04)


func top_normal() -> Vector3:
	return TOP_XF.basis.y.normalized()


## Los ojos del presidente en el atril. down: mirando las tarjetas (con la sala arriba); at: mirando a ese punto
func pov(down := true, at := Vector3.INF) -> void:
	cam_pos = eye
	if at != Vector3.INF:
		cam_look = eye + (at - eye).normalized() * 10.0
	else:
		var pitch := deg_to_rad(20.0 if down else 7.0)
		cam_look = eye + (Vector3.BACK * cos(pitch) - Vector3.UP * sin(pitch)) * 10.0
	# mirando a la sala, un poco más cerrado: los periodistas se ven más grandes
	fov_target = 62.0 if down else 54.0
	cam_speed = 2.2
	sway = 0.0
	look_range = Vector2(5.0, 3.0) if down else Vector2(9.0, 4.0)


# ------------------------------------------------------------------ sala

func _room() -> void:
	var w := X1 - X0
	# suelo, techo
	b.cube(Vector3(0, -0.05, Z1 * 0.5), Vector3(w, 0.1, Z1), _m["carpet"])
	b.cube(Vector3(0, H + 0.05, Z1 * 0.5), Vector3(w, 0.1, Z1), _m["ceiling"])
	# paredes: zócalo de roble, tela azul en los paños, yeso arriba
	for sx in [-1.0, 1.0]:
		var x: float = X0 if sx < 0 else X1
		var xf := Transform3D(Basis(Vector3.UP, -PI / 2.0 * sx), Vector3(x, 0, Z1 * 0.5))
		b.rects(xf, [Rect2(-Z1 * 0.5, 1.15, Z1, H - 1.15)], _m["wall"], 1.0)
		b.rects(xf, [Rect2(-Z1 * 0.5, 0.0, Z1, 1.15)], _m["panel"], 1.0)
		b.molding(xf * Transform3D(Basis(), Vector3(0, 1.12, 0)), -Z1 * 0.5, Z1 * 0.5, Kit.PROFILE_RAIL, _m["dark"])
		b.molding(xf, -Z1 * 0.5, Z1 * 0.5, Kit.PROFILE_BASE, _m["dark"])
		b.molding(xf * Transform3D(Basis(), Vector3(0, H - 0.175, 0)), -Z1 * 0.5, Z1 * 0.5, Kit.PROFILE_CROWN, _m["ceiling"])
		# paneles acústicos tapizados entre ventanas o cuadros
		for k in 5:
			var zc := 2.2 + k * 2.6
			var pxf := xf * Transform3D(Basis(), Vector3(zc - Z1 * 0.5, 2.55, 0.03))
			if sx > 0 and k in [1, 2, 3]:
				_window(xf, zc - Z1 * 0.5)
			else:
				b.box(pxf, Vector3(1.6, 2.2, 0.05), _m["fabric"], 1.0, 0.02)
				b.frame(pxf * Transform3D(Basis(), Vector3(0, 0, 0.025)), 1.66, 2.26, Kit.FRAME_PANEL, _m["dark"])
	# pared del fondo (detrás del atril) y la de la entrada
	var front := Transform3D(Basis(), Vector3(0, 0, 0))
	b.rects(front, [Rect2(X0, 0, w, H)], _m["wall"], 1.0)
	b.molding(front * Transform3D(Basis(), Vector3(0, H - 0.175, 0)), X0, X1, Kit.PROFILE_CROWN, _m["ceiling"])
	var back := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, Z1))
	for r in [Rect2(X0, 0, -0.95 - X0, H), Rect2(0.95, 0, X1 - 0.95, H), Rect2(-0.95, 2.5, 1.9, H - 2.5)]:
		b.rects(back, [Rect2(-(r as Rect2).end.x, r.position.y, r.size.x, r.size.y)], _m["wall"], 1.0)
	for i in 2:
		var dx := -0.475 + i * 0.95
		b.box(Transform3D(Basis(), Vector3(dx, 1.25, Z1 - 0.03)), Vector3(0.92, 2.48, 0.05), _m["podium"], 1.0, 0.01)
		b.frame(Transform3D(Basis(Vector3.UP, PI), Vector3(dx, 1.4, Z1 - 0.06)), 0.6, 1.6, Kit.FRAME_PANEL, _m["dark"])
	b.frame(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.27, Z1 - 0.01)), 2.2, 2.66, Kit.FRAME_CASING, _m["ceiling"], [false, true, true, true])
	b.cube(Vector3(0, 2.85, Z1 - 0.05), Vector3(0.5, 0.16, 0.04), Kit.emissive(Color("1f9d55"), 2.0))
	Kit.label(world, "SALIDA", UI.f_sans_b, 64, Color(0.92, 1, 0.95), Vector3(0, 2.85, Z1 - 0.075), Vector3(0, PI, 0), 0.0016)
	# plafones del techo
	for zi in 5:
		for xi in 3:
			var p := Vector3(-4.0 + xi * 4.0, H - 0.02, 2.2 + zi * 2.6)
			b.cube(p, Vector3(1.2, 0.03, 0.6), _m["lamp"])
			b.frame(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), p + Vector3(0, -0.01, 0)), 1.28, 0.68, Kit.FRAME_PANEL, _m["chrome"])
	# focos de carril sobre la tarima
	for sx in [-2.4, -0.8, 0.8, 2.4]:
		var p := Vector3(sx, H - 0.25, 3.4)
		b.cyl(Vector3(sx, H - 0.08, 3.4), 0.012, 0.012, 0.16, _m["black"])
		b.segment(p, p + (Vector3(0, DAIS_H + 1.5, 0.8) - p).normalized() * 0.28, 0.07, _m["black"], 14, true, 0.06)
		glow(p + (Vector3(0, DAIS_H + 1.5, 0.8) - p).normalized() * 0.3, 0.28, Color(1, 0.95, 0.85, 0.85))
	b.cube(Vector3(0, H - 0.015, 3.4), Vector3(6.0, 0.03, 0.06), _m["black"])


## Ventanal con persiana de lamas entreabierta y la luz del día detrás (pared derecha)
func _window(xf: Transform3D, u: float) -> void:
	var c := xf * Transform3D(Basis(), Vector3(u, 2.45, 0.0))
	b.box(c * Transform3D(Basis(), Vector3(0, 0, 0.012)), Vector3(1.5, 2.3, 0.01), Kit.emissive(Color(0.82, 0.9, 1.0), 1.6))
	b.frame(c * Transform3D(Basis(), Vector3(0, 0, 0.0)), 1.66, 2.46, Kit.FRAME_CASING, _m["ceiling"])
	for k in 20:
		var y := -1.1 + k * 0.115
		b.box(c * Transform3D(Basis(Vector3.RIGHT, -0.7), Vector3(0, y, 0.07)), Vector3(1.48, 0.07, 0.006), Kit.mat(Color("d9d6cf"), 0.6))
	b.box(c * Transform3D(Basis(), Vector3(0, -1.22, 0.1)), Vector3(1.66, 0.04, 0.22), _m["ceiling"])


func _dais() -> void:
	var w := 7.2
	b.cube(Vector3(0, DAIS_H * 0.5, DAIS_Z * 0.5), Vector3(w, DAIS_H, DAIS_Z), _m["carpet"])
	b.cube(Vector3(0, DAIS_H * 0.5, DAIS_Z + 0.01), Vector3(w, DAIS_H, 0.03), _m["dark"])
	b.cube(Vector3(0, DAIS_H + 0.01, DAIS_Z - 0.02), Vector3(w, 0.02, 0.04), _m["gold"])
	Kit.blob(world, Vector3(0, DAIS_H, 1.0), 1.6, 1.2, 0.5)


## Fondo institucional: paño azul con el emblema y el nombre repetido (como un photocall)
func _backdrop() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1600, 800)
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var c := Control.new()
	c.size = Vector2(1600, 800)
	c.draw.connect(func():
		c.draw_rect(Rect2(0, 0, 1600, 800), Color("122347"))
		for row in 9:
			for col in 6:
				var p := Vector2(col * 290.0 + (145.0 if row % 2 == 1 else 0.0) - 40.0, 40.0 + row * 92.0)
				c.draw_circle(p + Vector2(0, -10), 16, Color(UI.GOLD, 0.22))
				c.draw_string(UI.f_sans_b, p + Vector2(26, -2), "GOBIERNO DE VALDORIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.1))
		c.draw_rect(Rect2(380, 190, 840, 330), Color("0d1a38"))
		c.draw_rect(Rect2(380, 190, 840, 330), Color(UI.GOLD, 0.8), false, 4.0)
		c.draw_colored_polygon(Flags.star_points(Vector2(800, 300), 62, 26, 8), UI.GOLD)
		c.draw_arc(Vector2(800, 300), 84, 0, TAU, 64, UI.GOLD, 4.0)
		c.draw_string(UI.f_serif_b, Vector2(380, 448), "GOBIERNO DE VALDORIA", HORIZONTAL_ALIGNMENT_CENTER, 840, 40, Color("f4ead2"))
		c.draw_string(UI.f_sans_b, Vector2(380, 496), "PRESIDENCIA  ·  SALA DE PRENSA", HORIZONTAL_ALIGNMENT_CENTER, 840, 24, Color(UI.GOLD, 0.9)))
	sv.add_child(c)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(6.4, 3.2)
	mi.mesh = q
	var m := Kit.tex_mat(sv.get_texture(), 0.75)
	mi.material_override = m
	world.add_child(mi)
	mi.position = Vector3(0, DAIS_H + 0.15 + 1.6, 0.03)
	b.frame(Transform3D(Basis(), Vector3(0, DAIS_H + 1.75, 0.02)), 6.5, 3.3, Kit.FRAME_PANEL, _m["gold"])


func _podium() -> void:
	var p := PODIUM
	var xf := Transform3D(Basis(), p)
	# cuerpo de caoba con frontal en ligera pendiente y el tablero inclinado hacia el orador
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.03, 0)), Vector3(0.86, 0.06, 0.6), _m["dark"], 1.0, 0.01)
	b.box(xf * Transform3D(Basis(Vector3.RIGHT, -0.06), Vector3(0, 0.58, 0.02)), Vector3(0.74, 1.04, 0.46), _m["podium"], 1.0, 0.015, 2)
	b.box(xf * Transform3D(Basis(), Vector3(0, 1.12, 0.2)), Vector3(0.8, 0.12, 0.06), _m["podium"], 1.0, 0.01)
	b.box(TOP_XF, TOP_SIZE, _m["podium"], 1.0, 0.012, 2)
	b.box(TOP_XF * Transform3D(Basis(), Vector3(0, TOP_SIZE.y * 0.5 + 0.001, 0.0)), Vector3(0.92, 0.002, 0.46), _m["felt"])
	b.box(TOP_XF * Transform3D(Basis(), Vector3(0, TOP_SIZE.y * 0.5 + 0.012, -TOP_SIZE.z * 0.5 + 0.02)), Vector3(0.96, 0.022, 0.016), _m["gold"], 1.0, 0.006)
	# escudo en el frontal
	var front := xf * Transform3D(Basis(Vector3.RIGHT, -0.06), Vector3(0, 0.66, 0.26))
	b.cylinder(front * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO), 0.15, 0.15, 0.02, _m["gold"], 32)
	b.cylinder(front * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0, 0.012)), 0.125, 0.125, 0.012, Kit.mat(Color("15285a"), 0.4), 32)
	star(front * Transform3D(Basis(), Vector3(0, 0, 0.0195)), 0.09, 0.038, _m["gold"], 8)
	Kit.label(world, "PRESIDENCIA DEL GOBIERNO", UI.f_sans_b, 30, Color("e9d9a8"), (front * Transform3D(Basis(), Vector3(0, -0.24, 0.0))).origin + Vector3(0, 0, 0.012), Vector3(-0.06, 0, 0), 0.0012)
	# micrófonos de los medios y papeles del discurso (solo en el plano de televisión: en primera persona
	# estarían delante de las tarjetas)
	if view != "tv":
		return
	var top := TOP_XF * Transform3D(Basis(), Vector3(0, TOP_SIZE.y * 0.5 + 0.003, -0.02))
	b.box(top * Transform3D(Basis(Vector3.UP, 0.05), Vector3(-0.05, 0.0, 0.0)), Vector3(0.21, 0.004, 0.297), _m["paper"])
	b.box(top * Transform3D(Basis(Vector3.UP, -0.08), Vector3(0.1, 0.004, 0.02)), Vector3(0.21, 0.004, 0.297), _m["paper"])
	var cols := ["c62828", "1d4ed8", "f2c230", "eeeeee", "1f9d55", "15171b", "e5641a", "7a1fa2"]
	for i in cols.size():
		var ang := lerpf(-0.55, 0.55, float(i) / (cols.size() - 1))
		var root_p := p + Vector3(sin(ang) * 0.22, 1.17 + 0.02 * (i % 2), 0.2)
		var head := p + Vector3(sin(ang) * 0.13, 1.3 + 0.025 * ((i + 1) % 3), 0.06)
		b.segment(root_p, head, 0.005, _m["black"], 6)
		b.sphere(head, 0.022, Kit.mat(Color("101012"), 0.9), 10, 6, Vector3(1, 1, 1.5))
		b.cube(head.lerp(root_p, 0.4), Vector3(0.04, 0.04, 0.04), Kit.mat(Color(cols[i]), 0.5), Vector3(0, ang, 0))
	# dos micros oficiales de cuello de cisne
	for sx in [-0.16, 0.16]:
		var a := p + Vector3(sx, 1.17, 0.06)
		var mid := a + Vector3(sx * 0.15, 0.1, -0.03)
		var tip := a + Vector3(sx * 0.05, 0.16, -0.12)
		b.segment(a, mid, 0.007, _m["black"], 8)
		b.segment(mid, tip, 0.007, _m["black"], 8)
		b.cyl(tip, 0.012, 0.012, 0.06, _m["black"], Vector3(PI / 2.0 - 0.4, 0, 0), 10)
		glow(a + Vector3(0, 0.012, 0.01), 0.02, Color(1, 0.2, 0.15, 0.9))


## Monitor de cortesía en un pie, a la izquierda del orador, con la reacción de la opinión pública en directo
func _monitor() -> void:
	var c := Vector3(1.08, DAIS_H + 1.32, 2.3)
	var xf := facing(c, eye)
	b.box(xf * Transform3D(Basis(), Vector3(0, 0, -0.035)), Vector3(0.58, 0.36, 0.05), _m["black"], 1.0, 0.012)
	b.segment(xf * Vector3(0, -0.15, -0.05), Vector3(c.x, DAIS_H, c.z + 0.05), 0.025, _m["black"], 10)
	b.cyl(Vector3(c.x, DAIS_H + 0.02, c.z + 0.05), 0.2, 0.22, 0.04, _m["black"], Vector3.ZERO, 20)
	monitor = screen(Vector2i(800, 460), xf, 0.54, Color(0.02, 0.03, 0.06), 1.15)


# ------------------------------------------------------------------ público

func _chair(pos: Vector3, yaw: float) -> void:
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.42, 0.08)), Vector3(0.5, 0.07, 0.46), _m["seat"], 1.0, 0.025, 2)
	b.box(xf * Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 0.78, -0.17)), Vector3(0.5, 0.52, 0.06), _m["seat"], 1.0, 0.025, 2)
	for sx in [-0.22, 0.22]:
		b.segment(pos + xf.basis * Vector3(sx, 0.0, 0.28), pos + xf.basis * Vector3(sx, 0.4, 0.26), 0.012, _m["chrome"], 6)
		b.segment(pos + xf.basis * Vector3(sx, 0.0, -0.14), pos + xf.basis * Vector3(sx, 1.02, -0.22), 0.012, _m["chrome"], 6)
	Kit.blob(world, pos + fwd * 0.05, 0.6, 0.6, 0.35, yaw)


func _audience() -> void:
	var far_seats := []
	var suits := ["22252c", "1b2c52", "3a3d44", "2a2c30", "4a3a5a", "2b3e66", "5a1f2a", "2f4a3a", "6b6e74", "1d2b4a"]
	for r in ROWS:
		var z := ROW_Z + r * ROW_STEP
		for sx in [-1.0, 1.0]:
			for i in SEATS_SIDE:
				var x: float = sx * (1.0 + i * 0.62)
				var pos := Vector3(x, 0, z)
				_chair(pos, PI)
				# algún asiento libre, más hacia los extremos
				if _rng.randf() < 0.12 + 0.05 * i:
					continue
				if r < NEAR_ROWS:
					var j := person(rand_look(_rng), pos, PI, "sit", r == 0, 2 + mini(r, 1))
					j.rest_anim = "sit_write" if _rng.randf() < 0.55 else "sit"
					journalists.append(j)
				else:
					far_seats.append({"xf": Transform3D(Basis(Vector3.UP, PI), pos), "suit": Color(suits[_rng.randi() % suits.size()]), "f": _rng.randf() < 0.45})
	var crowd := Crowd3D.new()
	world.add_child(crowd)
	crowd.build(far_seats, _rng)


func _photographers() -> void:
	var spots := [[Vector3(-1.5, 0, 3.05), "kneel_photo"], [Vector3(0.95, 0, 3.15), "kneel_photo"], [Vector3(2.35, 0, 2.95), "kneel_photo"],
		[Vector3(-3.3, 0, 3.4), "photo"], [Vector3(3.6, 0, 3.55), "photo"], [Vector3(-4.6, 0, 2.7), "photo"]]
	for s in spots:
		var pos: Vector3 = s[0]
		var face := Vector3(0, DAIS_H + 1.5, 0.6)
		var yaw := yaw_to(pos, face)
		var look := rand_look(_rng)
		look["tie"] = ""
		var ph := person(look, pos, yaw, "", true, 2)
		ph.rest_anim = s[1]
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var cam_p: Vector3 = pos + fwd * 0.27 + Vector3(0, 1.5 if s[1] == "photo" else 1.08, 0) + right * 0.02
		var cxf := Transform3D(Basis(Vector3.UP, yaw), cam_p)
		b.box(cxf, Vector3(0.15, 0.1, 0.08), _m["black"], 1.0, 0.012)
		b.cylinder(cxf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, -0.005, 0.09)), 0.035, 0.038, 0.11, _m["rubber"], 14)
		b.box(cxf * Transform3D(Basis(), Vector3(0.0, 0.085, -0.005)), Vector3(0.07, 0.06, 0.06), _m["black"], 1.0, 0.008)
		photographers.append(ph)
		_cam_spots.append(cam_p + fwd * 0.05 + Vector3(0, 0.09, 0))


func _tv_cameras() -> void:
	# tarima de las cámaras
	b.cube(Vector3(0, RISER_H * 0.5, RISER_Z + 1.15), Vector3(9.0, RISER_H, 2.3), _m["carpet"])
	b.cube(Vector3(0, RISER_H * 0.5, RISER_Z + 0.01), Vector3(9.0, RISER_H, 0.03), _m["dark"])
	var target := Vector3(0, DAIS_H + 1.5, 0.8)
	for i in 4:
		var x := -3.0 + i * 2.0
		var base := Vector3(x, RISER_H, RISER_Z + 0.55)
		var head := base + Vector3(0, 1.45, 0)
		var yaw := yaw_to(head, target) + PI
		# trípode
		for k in 3:
			var a := TAU * k / 3.0 + 0.3
			b.segment(head - Vector3(0, 0.1, 0), base + Vector3(cos(a) * 0.42, 0.0, sin(a) * 0.42), 0.014, _m["black"], 6)
		b.cyl(head - Vector3(0, 0.06, 0), 0.06, 0.07, 0.1, _m["black"])
		# cuerpo, objetivo, visor y piloto rojo
		var cxf := Transform3D(Basis(Vector3.UP, yaw), head + Vector3(0, 0.14, 0))
		b.box(cxf, Vector3(0.22, 0.26, 0.48), Kit.mat(Color("2b2d31"), 0.4, 0.3), 1.0, 0.02, 2)
		b.cylinder(cxf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0.0, -0.36)), 0.08, 0.075, 0.26, _m["rubber"], 18)
		b.cylinder(cxf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0.0, -0.5)), 0.09, 0.09, 0.03, _m["black"], 18)
		b.box(cxf * Transform3D(Basis(), Vector3(-0.15, 0.06, 0.16)), Vector3(0.08, 0.09, 0.14), _m["black"], 1.0, 0.01)
		b.cube((cxf * Transform3D(Basis(), Vector3(0.0, 0.0, 0.3))).origin + Vector3(0, -0.06, 0), Vector3(0.04, 0.04, 0.04), _m["black"])
		b.segment((cxf * Transform3D(Basis(), Vector3(0.1, -0.12, 0.25))).origin, (cxf * Transform3D(Basis(), Vector3(0.3, -0.25, 0.55))).origin, 0.012, _m["black"], 6)
		Kit.label(world, ["C7", "TVN", "24H", "RNV"][i], UI.f_sans_b, 48, Color(1, 1, 1, 0.85), (cxf * Transform3D(Basis(), Vector3(0.112, 0.06, 0.0))).origin, Vector3(0, yaw + PI / 2.0, 0), 0.0015)
		glow((cxf * Transform3D(Basis(), Vector3(0, 0.15, -0.2))).origin, 0.07, Color(1, 0.1, 0.05, 0.9))
		# operador detrás
		var op_pos := Vector3(x, RISER_H, RISER_Z + 1.12)
		var op := person(rand_look(_rng), op_pos, yaw_to(op_pos, target), "", false, 3)
		op.rest_anim = "operate"
	# mangueras de cable por el suelo de la tarima
	for i in 3:
		var x0 := -2.0 + i * 2.0
		b.segment(Vector3(x0, RISER_H + 0.01, RISER_Z + 0.6), Vector3(x0 + 0.6, RISER_H + 0.01, RISER_Z + 1.9), 0.012, _m["rubber"], 6)


func _lights() -> void:
	env.ambient_light_color = Color(0.62, 0.66, 0.78)
	env.ambient_light_energy = 0.35
	# focos principales sobre el atril y el fondo
	spot(Vector3(-2.4, H - 0.3, 3.6), Vector3(0, DAIS_H + 1.5, 0.7), 4.2, 24.0, Color(1, 0.95, 0.86), true)
	spot(Vector3(2.4, H - 0.3, 3.6), Vector3(0, DAIS_H + 1.4, 0.7), 2.8, 24.0, Color(1, 0.95, 0.88), false)
	spot(Vector3(0, H - 0.2, 3.0), Vector3(0, 1.8, 0.0), 3.0, 40.0, Color(0.95, 0.96, 1.0), false)
	# luz general de la sala (plafones) y la que entra por las ventanas
	for z in [3.5, 7.5, 11.5]:
		omni(Vector3(0, H - 0.6, z), 1.4, 9.0, Color(1.0, 0.97, 0.92), false)
	if not low:
		for z in [4.8, 7.4, 10.0]:
			spot(Vector3(X1 - 0.3, 3.6, z), Vector3(2.0, 0.0, z + 1.2), 2.2, 38.0, Color(0.88, 0.93, 1.0), false, 10.0)
	# en primera persona, una luz suave sobre el tablero del atril para leer las tarjetas
	if view != "tv":
		spot(eye + Vector3(0, 1.0, 0.1), top_center(), 0.7, 34.0, Color(1.0, 0.95, 0.86), false, 3.2)


# ------------------------------------------------------------------ acción

## Alzan la mano n periodistas de las primeras filas, repartidos por la sala para que sus acreditaciones no se
## tapen: uno por zona (izquierda y derecha, cerca y lejos del pasillo). Devuelve quiénes, de izquierda a derecha
func raise_hands(n: int) -> Array:
	stop_asking()
	var zones := {}
	for j in journalists:
		var x: float = (j as Node3D).global_position.x
		var k := ("L" if x > 0.0 else "R") + ("far" if absf(x) > 2.4 else "near")
		if not zones.has(k):
			zones[k] = []
		zones[k].append(j)
	var keys := zones.keys()
	keys.shuffle()
	var out := []
	for k in keys:
		if out.size() >= n:
			break
		var pool: Array = zones[k]
		# antes las dos primeras filas (se ven mejor)
		pool.sort_custom(func(a, b2): return (a as Node3D).global_position.z < (b2 as Node3D).global_position.z)
		out.append(pool[_rng.randi() % mini(pool.size(), 4)])
	# de izquierda a derecha en la pantalla (la izquierda es +X mirando desde el atril)
	out.sort_custom(func(a, b2): return (a as Node3D).global_position.x > (b2 as Node3D).global_position.x)
	for j in out:
		j.gesture = "sit_raise"
	_raised = out
	return out


## El periodista al que se da la palabra (los demás bajan la mano); lo devuelve
func give_floor(j: Node3D) -> Node3D:
	for o in _raised:
		if is_instance_valid(o) and o != j:
			o.gesture = ""
	_raised = []
	_asking = j
	if is_instance_valid(j):
		j.gesture = ""
		j.mood = 0.0
	return j


## Un periodista de las primeras filas pregunta (para el discurso y las pruebas)
func ask() -> Node3D:
	if journalists.is_empty():
		return null
	return give_floor(journalists[_rng.randi() % journalists.size()])


func stop_asking() -> void:
	if _asking != null:
		_asking.talking = false
		_asking.gesture = ""
	for o in _raised:
		if is_instance_valid(o):
			o.gesture = ""
	_raised = []
	_asking = null


## Reacción de la sala a una respuesta (s: valoración; > 0 buena, < 0 mala; tone: el tono de la respuesta)
func react(s: float, tone := "") -> void:
	burst(3 if s < 0 else 5)
	if s < 0:
		_murmur_t = 2.4
		for j in journalists:
			if _rng.randf() < 0.4 and j != _asking:
				j.talking = true
	elif tone == "humor" and s >= 3:
		# el chiste funciona: se ríen
		_murmur_t = 2.0
		for j in journalists:
			if _rng.randf() < 0.45:
				gesture(j, "sit_laugh", randf_range(1.2, 2.0))
	else:
		for j in journalists:
			if _rng.randf() < 0.35:
				gesture(j, "sit_write", 2.0)
	if is_instance_valid(_asking):
		_asking.mood = 0.3 if s >= 4 else (-0.4 if s < 0 else 0.0)


## Ráfaga de flashes de los fotógrafos
func burst(n: int) -> void:
	_burst += n


func _process(delta: float) -> void:
	super(delta)
	if _murmur_t > 0.0:
		_murmur_t -= delta
		if _murmur_t <= 0.0:
			for j in journalists:
				if j != _asking:
					j.talking = false
	if _cam_spots.is_empty():
		return
	_burst_cd -= delta
	if _burst > 0 and _burst_cd <= 0.0:
		_burst -= 1
		_burst_cd = randf_range(0.06, 0.16)
		flash(_cam_spots[randi() % _cam_spots.size()])
	_flash_cd -= delta
	if _flash_cd <= 0.0:
		_flash_cd = randf_range(2.5, 5.0) if quiet else randf_range(0.6, 2.4)
		flash(_cam_spots[randi() % _cam_spots.size()], 0.8)
