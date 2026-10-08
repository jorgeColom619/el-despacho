extends "res://scripts/stages3d/stage_3d.gd"
## Hemiciclo del Congreso de los Diputados: escaños en gradas con pupitres de caoba (la bancada azul del
## Gobierno en la primera fila), tribuna de oradores, Mesa presidencial, galería de público, pilastras con capitel
## dorado, techo artesonado con vidriera y el gran cuadro detrás de la Mesa. Unos 330 diputados: las dos primeras
## filas son personajes completos; las de atrás, público ligero (crowd_3d.gd).
## La Mesa queda en z < 0; el hemiciclo se abre hacia +z. Mirando desde la Mesa, el Gobierno se sienta a la
## izquierda de la pantalla (x > 0) y la oposición a la derecha (x < 0).

const Crowd3D := preload("res://scripts/stages3d/crowd_3d.gd")

const ROWS := 9
## Radio del asiento de la primera fila, separación entre filas y altura de cada grada
const R0 := 4.6
const STEP_R := 0.95
const STEP_H := 0.34
const H0 := 0.2
const SEAT_W := 0.64
const SECTORS := 5
const AISLE := 0.8
## Filas con diputados de cuerpo entero
const NEAR_ROWS := 2
const CEIL := 9.5
const WALL_R := 13.6
const MESA_Z := -3.6
const GALLERY_Y := 5.6
const CARPET := {"c0": "6e1820", "c1": "3d0b10"}
## Escaño del líder de la oposición (primera fila, a la derecha mirando desde la tribuna)
const OPP_A := PI - 0.8
## Tribuna de oradores y sitio del presidente detrás del atril
const TRIB_Z := -0.5
const SPEAKER := Vector3(0, 0.3, -0.8)
## Segundos del plano del contrincante preguntando, antes de volver al atril para elegir la réplica
const OPP_SHOT := 2.4

var gov_color := Color("e2574c")
var opp_color := Color("2f6fd6")
var pres_look: Dictionary = {}
var opp_look: Dictionary = {}
## El presidente (en la tribuna) y el líder de la oposición (en su escaño): exponen talking / mood / anger
var me: Node3D
var opp: Node3D
## Marcadores del hemiciclo (dos pantallas grandes con lo mismo): pregunta, quién habla, resultado
var board: Control
var _pov := []
var _turn_id := 0
var deputies_gov: Array = []
var deputies_opp: Array = []
var crowd
var _cheer_t := 0.0
var _cheer_gov := true
var _rng := RandomNumberGenerator.new()
var _m := {}


static func row_r(i: int) -> float:
	return R0 + i * STEP_R


static func row_h(i: int) -> float:
	return H0 + i * STEP_H


func build() -> void:
	_rng.seed = 77
	_m = {
		"carpet": Kit.pbr("carpet", CARPET, 3.0, 0.95, Color.WHITE, 0.8),
		"tier": Kit.pbr("velvet", {}, 0.8, 0.95, Color("6e1820"), 0.5),
		"floor": Kit.pbr("parquet", {}, 1.2, 0.45, Color(0.85, 0.78, 0.7), 0.7, 0.0, 0.2),
		"wood": Kit.wood("caoba"),
		"dark": Kit.wood("ebano"),
		"panel": Kit.wood("panel"),
		"velvet": Kit.velvet(Color("8e1c24")),
		"blue": Kit.leather(Color("1f3f8a"), 0.45),
		"gold": Kit.gold(),
		"plaster": Kit.plaster(Color("efe6d2")),
		"cream": Kit.mat(Color("eadfc6"), 0.55),
		"stone": Kit.plaster(Color("d9cdb4")),
		"leather": Kit.leather(Color("3a1a12")),
		"paper": Kit.mat(Color("f4f1e8"), 0.9),
		"black": Kit.mat(Color("141416"), 0.45, 0.3),
		"lamp": Kit.emissive(Color(1.0, 0.86, 0.62), 3.0),
	}
	_floor_and_tiers()
	_desks_and_seats()
	_walls_and_gallery()
	_mesa_and_tribune()
	_ceiling()
	_people()
	_lights()
	b.commit(world)
	_boards()
	# el atril de la tribuna lleva la pantalla del minijuego; se empieza con un plano general desde la
	# galería y la cámara baja hasta los ojos del presidente
	ui = pov_screen(SPEAKER + Vector3(0, 1.62, 0), 0.0, Vector2i(1400, 580), 0.73, 11.0)
	_pov = [cam_pos, cam_look]
	wide()
	get_tree().create_timer(1.3).timeout.connect(func():
		if is_inside_tree() and _turn_id == 0:
			cam_speed = 1.4
			pov())


# ------------------------------------------------------------------ geometría curva

## Cuadrilátero con la cara hacia sus normales (ordena los vértices para que se vea por delante)
func _quad(st: SurfaceTool, v: Array, nrm: Array, uv: Array) -> void:
	var nn: Vector3 = (nrm[0] + nrm[1] + nrm[2] + nrm[3]) * 0.25
	var order := [0, 1, 2, 0, 2, 3]
	if ((v[1] as Vector3) - v[0]).cross((v[2] as Vector3) - v[0]).dot(nn) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for i in order:
		st.set_normal(nrm[i])
		st.set_uv(uv[i])
		st.add_vertex(v[i])


static func _p(r: float, a: float, y: float) -> Vector3:
	return Vector3(cos(a) * r, y, sin(a) * r)


## Anillo horizontal (mirando arriba, o abajo si down) entre radios ri y ro y ángulos a0..a1, a la altura y
func _ring(ri: float, ro: float, a0: float, a1: float, y: float, m: Material, tile := 1.0, down := false) -> void:
	var st: SurfaceTool = b._tool(m)
	var n := maxi(2, int((a1 - a0) * ro / 0.35))
	var up := Vector3.DOWN if down else Vector3.UP
	for k in n:
		var t0 := lerpf(a0, a1, float(k) / n)
		var t1 := lerpf(a0, a1, float(k + 1) / n)
		var v := [_p(ri, t0, y), _p(ro, t0, y), _p(ro, t1, y), _p(ri, t1, y)]
		var uv := []
		for p in v:
			uv.append(Vector2((p as Vector3).x, (p as Vector3).z) / tile)
		_quad(st, v, [up, up, up, up], uv)


## Franja vertical curva a radio r entre alturas y0..y1, mirando hacia el centro (o hacia fuera)
func _band(r: float, a0: float, a1: float, y0: float, y1: float, m: Material, inward := true, tile := 1.0) -> void:
	var st: SurfaceTool = b._tool(m)
	var n := maxi(2, int((a1 - a0) * r / 0.35))
	var sgn := -1.0 if inward else 1.0
	for k in n:
		var t0 := lerpf(a0, a1, float(k) / n)
		var t1 := lerpf(a0, a1, float(k + 1) / n)
		var n0 := Vector3(cos(t0), 0, sin(t0)) * sgn
		var n1 := Vector3(cos(t1), 0, sin(t1)) * sgn
		var u0 := t0 * r / tile
		var u1 := t1 * r / tile
		_quad(st, [_p(r, t0, y0), _p(r, t1, y0), _p(r, t1, y1), _p(r, t0, y1)], [n0, n1, n1, n0],
			[Vector2(u0, -y0 / tile), Vector2(u1, -y0 / tile), Vector2(u1, -y1 / tile), Vector2(u0, -y1 / tile)])


## Ángulo de cada escaño de la fila i
static func seat_angles(i: int) -> Array:
	var r := row_r(i)
	var out := []
	for sec in sectors(r):
		var a0: float = sec[0]
		var a1: float = sec[1]
		var n := int((a1 - a0) * r / SEAT_W)
		for k in n:
			out.append(lerpf(a0, a1, (k + 0.5) / n))
	return out


## El escaño de la fila 0 más cercano al ángulo a
static func nearest_seat(a: float) -> float:
	var best := a
	for s in seat_angles(0):
		if absf(float(s) - a) < absf(best - a) or best == a:
			best = s
	return best


## Ángulos de los sectores de escaños (entre pasillos): [[a0, a1], ...] para la fila de radio r
static func sectors(r: float) -> Array:
	var out := []
	var gap := AISLE * 0.5 / r
	for s in SECTORS:
		var a0 := PI * s / SECTORS + (gap if s > 0 else 0.12 / r)
		var a1 := PI * (s + 1) / SECTORS - (gap if s < SECTORS - 1 else 0.12 / r)
		out.append([a0, a1])
	return out


# ------------------------------------------------------------------ sala

func _floor_and_tiers() -> void:
	# suelo del hemiciclo y del estrado de la Mesa
	_ring(0.0, R0 - 0.68, 0.0, PI, 0.0, _m["carpet"], 3.0)
	b.cube(Vector3(0, -0.05, MESA_Z * 0.5), Vector3(WALL_R * 2.0, 0.1, -MESA_Z), _m["floor"])
	# escudo en la alfombra
	b.cylinder(Transform3D(Basis(), Vector3(0, 0.004, 1.9)), 1.25, 1.25, 0.004, Kit.mat(Color("c9a55c"), 0.5), 48)
	b.cylinder(Transform3D(Basis(), Vector3(0, 0.008, 1.9)), 1.13, 1.13, 0.004, Kit.mat(Color("15285a"), 0.7), 48)
	star(Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, 0.012, 1.9)), 0.9, 0.38, Kit.mat(Color("c9a55c"), 0.5), 8)
	# gradas: suelo de cada fila y su tabica
	for i in ROWS:
		var r := row_r(i)
		var h := row_h(i)
		var hp := 0.0 if i == 0 else row_h(i - 1)
		_ring(r - 0.68, r + 0.27, 0.0, PI, h, _m["tier"], 1.0)
		_band(r - 0.68, 0.0, PI, hp, h, _m["dark"], true, 1.0)
		# peldaños intermedios en los pasillos
		for s in range(1, SECTORS):
			var a := PI * s / SECTORS
			var p := _p(r - 0.84, a, hp + STEP_H * 0.25)
			b.cube(p, Vector3(0.32, STEP_H * 0.5, AISLE), _m["dark"], Vector3(0, -a, 0))
	# cierre por detrás de la última fila y laterales de las gradas
	var rl := row_r(ROWS - 1) + 0.27
	_ring(rl, WALL_R, 0.0, PI, row_h(ROWS - 1), _m["tier"], 1.0)
	for sx in [-1.0, 1.0]:
		for i in ROWS:
			var r := row_r(i)
			var h := row_h(i)
			b.cube(Vector3(sx * (r - 0.2), h * 0.5, -0.03), Vector3(0.96, h, 0.06), _m["dark"])


func _desks_and_seats() -> void:
	for i in ROWS:
		var r := row_r(i)
		var h := row_h(i)
		for sec in sectors(r):
			var a0: float = sec[0]
			var a1: float = sec[1]
			# pupitre corrido: frente de caoba con cuarterones, tablero y canto dorado
			var rf := r - 0.66
			_band(rf, a0, a1, h, h + 0.74, _m["wood"], true, 0.8)
			_ring(rf, r - 0.3, a0, a1, h + 0.74, _m["wood"], 0.8)
			_band(rf - 0.005, a0, a1, h + 0.7, h + 0.74, _m["gold"], true, 0.5)
			_band(r - 0.3, a0, a1, h + 0.52, h + 0.74, _m["dark"], false, 0.8)
			for k in int((a1 - a0) * rf / 0.9):
				var a := lerpf(a0, a1, (k + 0.5) / int((a1 - a0) * rf / 0.9))
				var p := _p(rf - 0.008, a, h + 0.36)
				b.frame(Transform3D(Basis(Vector3.UP, -a - PI / 2.0), p), 0.62, 0.5, Kit.FRAME_PANEL, _m["dark"])
		# escaños
		for a in seat_angles(i):
			_seat(_p(r, a, h), a, i == 0 and a < PI * 0.5)


## Escaño de terciopelo (o de cuero azul en la bancada del Gobierno) mirando al centro del hemiciclo
func _seat(pos: Vector3, a: float, blue: bool) -> void:
	var yaw := atan2(-cos(a), -sin(a))
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	var mt: Material = _m["blue"] if blue else _m["velvet"]
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.42, 0.06)), Vector3(0.54, 0.1, 0.5), mt, 1.0, 0.035, 1)
	b.box(xf * Transform3D(Basis(Vector3.RIGHT, -0.14), Vector3(0, 0.84, -0.2)), Vector3(0.54, 0.74, 0.1), mt, 1.0, 0.04, 1)
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.18, 0.02)), Vector3(0.12, 0.36, 0.12), _m["black"])


func _walls_and_gallery() -> void:
	var top := row_h(ROWS - 1)
	# muro curvo: zócalo de caoba hasta la galería, estuco arriba
	_band(WALL_R, 0.0, PI, top, GALLERY_Y - 0.4, _m["panel"], true, 1.0)
	_band(WALL_R, 0.0, PI, GALLERY_Y, CEIL, _m["plaster"], true, 2.0)
	# galería de público: voladizo, antepecho con balaustres y público
	var gi := WALL_R - 1.3
	_ring(gi, WALL_R, 0.0, PI, GALLERY_Y, _m["tier"], 1.0)
	_ring(gi, WALL_R, 0.0, PI, GALLERY_Y - 0.4, _m["plaster"], 2.0, true)
	_band(gi, 0.0, PI, GALLERY_Y - 0.4, GALLERY_Y, _m["gold"], true, 0.5)
	_band(gi, 0.0, PI, GALLERY_Y + 0.92, GALLERY_Y + 1.0, _m["wood"], true, 0.5)
	_ring(gi - 0.06, gi + 0.06, 0.0, PI, GALLERY_Y + 1.0, _m["wood"], 0.5)
	var nb := int(PI * gi / 0.32)
	for k in nb:
		var a := PI * (k + 0.5) / nb
		b.lathe(Transform3D(Basis(), _p(gi, a, GALLERY_Y)), [Vector2(0.045, 0.0), Vector2(0.03, 0.12), Vector2(0.055, 0.42), Vector2(0.025, 0.78), Vector2(0.04, 0.92), Vector2(0.0, 0.92)], _m["cream"], 10)
	# pilastras con capitel dorado entre la galería y el techo
	for k in 13:
		var a := PI * (k + 0.5) / 13.0
		var yaw := -a - PI / 2.0
		var pxf := Transform3D(Basis(Vector3.UP, yaw), _p(WALL_R - 0.12, a, 0.0))
		b.box(pxf * Transform3D(Basis(), Vector3(0, GALLERY_Y + 1.9, 0)), Vector3(0.6, 3.6, 0.2), _m["cream"], 1.0, 0.02)
		b.box(pxf * Transform3D(Basis(), Vector3(0, GALLERY_Y + 3.8, 0.03)), Vector3(0.78, 0.3, 0.28), _m["gold"], 1.0, 0.04, 2)
		b.box(pxf * Transform3D(Basis(), Vector3(0, top + 1.2, 0.0)), Vector3(0.5, 2.0, 0.16), _m["dark"], 1.0, 0.02)
		# aplique de bronce entre pilastras, bajo la galería
		var lp := _p(WALL_R - 0.25, a + PI / 26.0, GALLERY_Y - 1.15)
		b.sphere(lp, 0.09, Kit.mat(Color("f6e7c8"), 0.4), 10, 6, Vector3(1, 1.3, 1))
		glow(lp, 0.6, Color(1, 0.82, 0.55, 0.55))
	# cornisa del techo
	_band(WALL_R - 0.25, 0.0, PI, CEIL - 0.35, CEIL, _m["gold"], true, 0.5)
	_ring(WALL_R - 0.25, WALL_R, 0.0, PI, CEIL - 0.35, _m["cream"], 1.0, true)
	# muro de la Mesa (recto), con el cuadro, el escudo y las banderas
	var mw := Transform3D(Basis(), Vector3(0, 0, MESA_Z))
	b.rects(mw, [Rect2(-WALL_R, 0, WALL_R * 2.0, 2.2)], _m["panel"], 1.0)
	b.rects(mw, [Rect2(-WALL_R, 2.2, WALL_R * 2.0, CEIL - 2.2)], _m["plaster"], 2.0)
	b.molding(mw * Transform3D(Basis(), Vector3(0, 2.17, 0)), -WALL_R, WALL_R, Kit.PROFILE_RAIL, _m["gold"])
	_painting(Transform3D(Basis(), Vector3(0, 5.3, MESA_Z + 0.06)))
	for sx in [-1.0, 1.0]:
		flag_pole(Vector3(sx * 4.4, 0.6, MESA_Z + 0.5), "valdoria", 0.0 if sx > 0 else PI, 3.0)
		# columnas pareadas a los lados del cuadro
		for dx in [5.6, 6.4]:
			b.lathe(Transform3D(Basis(), Vector3(sx * dx, 0, MESA_Z + 0.35)), [Vector2(0.34, 0.0), Vector2(0.34, 0.3), Vector2(0.27, 0.42), Vector2(0.24, 0.5), Vector2(0.22, CEIL - 1.0), Vector2(0.3, CEIL - 0.7), Vector2(0.36, CEIL - 0.5), Vector2(0.0, CEIL - 0.5)], _m["cream"], 24)
			b.lathe(Transform3D(Basis(), Vector3(sx * dx, CEIL - 0.9, MESA_Z + 0.35)), [Vector2(0.24, 0.0), Vector2(0.32, 0.2), Vector2(0.36, 0.42), Vector2(0.0, 0.42)], _m["gold"], 24)
		# puertas a los lados del estrado
		var dxf := Transform3D(Basis(), Vector3(sx * 9.8, 1.4, MESA_Z + 0.04))
		b.box(dxf, Vector3(1.8, 2.8, 0.06), _m["wood"], 1.0, 0.01)
		b.frame(dxf * Transform3D(Basis(), Vector3(0, 0, 0.03)), 2.1, 3.1, Kit.FRAME_CASING, _m["gold"])


## Cuadro de la sala: la proclamación de la República, con marco dorado
func _painting(xf: Transform3D) -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1200, 680)
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var c := Control.new()
	c.size = Vector2(1200, 680)
	c.draw.connect(func():
		c.draw_rect(Rect2(0, 0, 1200, 680), Color("3a2a1c"))
		for i in 12:
			c.draw_rect(Rect2(0, i * 30, 1200, 30), Color("6a5236").lerp(Color("2a1e14"), i / 12.0))
		c.draw_rect(Rect2(0, 420, 1200, 260), Color("2c2016"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in 46:
			var x := rng.randf_range(30, 1170)
			var y := rng.randf_range(400, 560)
			var col := Color.from_hsv(rng.randf_range(0.0, 0.12), rng.randf_range(0.3, 0.7), rng.randf_range(0.15, 0.45))
			c.draw_rect(Rect2(x - 14, y - 10, 28, 120), col)
			c.draw_circle(Vector2(x, y - 22), 13, Color("c9a07a").darkened(rng.randf_range(0.0, 0.4)))
		c.draw_rect(Rect2(520, 160, 160, 260), Color("1d2b4a"))
		c.draw_circle(Vector2(600, 140), 22, Color("d8b08a"))
		Flags.draw_flag(c, "valdoria", Rect2(700, 120, 180, 120))
		c.draw_rect(Rect2(0, 0, 1200, 680), Color(1.0, 0.85, 0.6, 0.06)))
	sv.add_child(c)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(7.0, 3.97)
	mi.mesh = q
	mi.material_override = Kit.tex_mat(sv.get_texture(), 0.8)
	world.add_child(mi)
	mi.global_transform = xf
	b.frame(xf, 7.5, 4.47, Kit.FRAME_ORNATE, _m["gold"])
	b.frame(xf, 7.36, 4.33, Kit.FRAME_ORNATE, _m["gold"])
	glow(xf.origin + Vector3(0, 2.6, 0.5), 2.0, Color(1, 0.85, 0.6, 0.25))


func _mesa_and_tribune() -> void:
	# estrado de dos alturas con la Mesa (presidencia y secretarios)
	b.cube(Vector3(0, 0.3, MESA_Z + 1.25), Vector3(10.0, 0.6, 2.5), _m["dark"])
	b.cube(Vector3(0, 0.6 + 0.3, MESA_Z + 0.85), Vector3(6.0, 0.6, 1.7), _m["dark"])
	b.cube(Vector3(0, 1.205, MESA_Z + 0.85), Vector3(6.0, 0.01, 1.7), _m["tier"])
	b.cube(Vector3(0, 0.605, MESA_Z + 1.25), Vector3(10.0, 0.01, 2.5), _m["tier"])
	# mesa corrida
	var dz := MESA_Z + 1.35
	b.box(Transform3D(Basis(), Vector3(0, 1.2 + 0.37, dz)), Vector3(5.6, 0.74, 0.7), _m["wood"], 1.0, 0.02, 2)
	b.box(Transform3D(Basis(), Vector3(0, 1.2 + 0.75, dz)), Vector3(5.8, 0.05, 0.8), _m["wood"], 1.0, 0.012, 2)
	for k in 7:
		b.frame(Transform3D(Basis(), Vector3(-2.4 + k * 0.8, 1.57, dz + 0.355)), 0.6, 0.5, Kit.FRAME_PANEL, _m["gold"])
	# tribuna de oradores, delante de la Mesa: el presidente habla desde aquí
	var tz := TRIB_Z
	b.cube(Vector3(0, 0.15, tz - 0.1), Vector3(1.6, 0.3, 1.2), _m["dark"])
	b.box(Transform3D(Basis(), Vector3(0, 0.3 + 0.55, tz + 0.25)), Vector3(1.0, 1.1, 0.5), _m["wood"], 1.0, 0.02, 2)
	b.box(Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 1.43, tz + 0.2)), Vector3(1.1, 0.05, 0.6), _m["wood"], 1.0, 0.012, 2)
	star(Transform3D(Basis(), Vector3(0, 0.9, tz + 0.505)), 0.16, 0.07, _m["gold"], 8)
	# micrófonos a los lados de la pantalla del atril
	for sx in [-0.48, 0.48]:
		var a := Vector3(sx, 1.45, tz + 0.3)
		b.segment(a, a + Vector3(-sx * 0.12, 0.26, -0.16), 0.008, _m["black"], 8)
	# mesa de los taquígrafos
	b.box(Transform3D(Basis(), Vector3(0, 0.36, 0.75)), Vector3(1.8, 0.72, 0.7), _m["wood"], 1.0, 0.015, 2)
	b.box(Transform3D(Basis(), Vector3(0, 0.74, 0.75)), Vector3(1.9, 0.04, 0.78), _m["wood"], 1.0, 0.01)
	b.box(Transform3D(Basis(Vector3.UP, 0.1), Vector3(-0.4, 0.765, 0.72)), Vector3(0.3, 0.01, 0.4), _m["paper"])
	b.box(Transform3D(Basis(Vector3.UP, -0.08), Vector3(0.45, 0.765, 0.75)), Vector3(0.3, 0.01, 0.4), _m["paper"])


## Techo artesonado con una vidriera semicircular en el centro
func _ceiling() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1024, 512)
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var c := Control.new()
	c.size = Vector2(1024, 512)
	c.draw.connect(func():
		c.draw_rect(Rect2(0, 0, 1024, 512), Color("e9dcb8"))
		var ctr := Vector2(512, 0)
		var cols := [Color("d7c48a"), Color("c9d6e0"), Color("e8d9a8"), Color("b9c9a0"), Color("dcc2a0")]
		for ring in 6:
			var r0 := 80.0 + ring * 72.0
			for k in 12 + ring * 4:
				var n := 12 + ring * 4
				var a0 := PI * k / n
				var a1 := PI * (k + 1) / n
				var pts := PackedVector2Array([ctr + Vector2(cos(a0), sin(a0)) * r0, ctr + Vector2(cos(a1), sin(a1)) * r0, ctr + Vector2(cos(a1), sin(a1)) * (r0 + 72), ctr + Vector2(cos(a0), sin(a0)) * (r0 + 72)])
				c.draw_colored_polygon(pts, cols[(k + ring) % cols.size()])
				c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color("3a2c1c"), 4.0)
		c.draw_circle(ctr, 80, Color("f2e2a8"))
		c.draw_colored_polygon(Flags.star_points(ctr + Vector2(0, 40), 46, 20, 8), Color("b8954a")))
	sv.add_child(c)
	var glass := StandardMaterial3D.new()
	glass.albedo_texture = sv.get_texture()
	glass.emission_enabled = true
	glass.emission_texture = sv.get_texture()
	glass.emission_energy_multiplier = 1.6
	glass.roughness = 0.6
	var gr := 6.2
	var st: SurfaceTool = b._tool(glass)
	var n := 48
	for k in n:
		var a0 := PI * k / n
		var a1 := PI * (k + 1) / n
		var v := [Vector3(0, CEIL, 0), _p(gr, a0, CEIL), _p(gr, a1, CEIL), Vector3(0, CEIL, 0)]
		var uv := [Vector2(0.5, 0.0), Vector2(0.5 + cos(a0) * 0.5, sin(a0)), Vector2(0.5 + cos(a1) * 0.5, sin(a1)), Vector2(0.5, 0.0)]
		_quad(st, v, [Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN], uv)
	# artesonado alrededor: casetones entre vigas radiales y anillos dorados
	_ring(gr, WALL_R, 0.0, PI, CEIL, _m["plaster"], 2.0, true)
	for rr in [gr, gr + 2.4, gr + 4.8]:
		_band(rr, 0.0, PI, CEIL - 0.32, CEIL, _m["gold"], false, 0.5)
		_ring(rr - 0.12, rr + 0.12, 0.0, PI, CEIL - 0.32, _m["cream"], 1.0, true)
	for k in 15:
		var a := PI * (k + 0.5) / 15.0
		var p := _p((gr + WALL_R) * 0.5, a, CEIL - 0.16)
		b.cube(p, Vector3(WALL_R - gr, 0.32, 0.22), _m["cream"], Vector3(0, -a, 0))
	b.cube(Vector3(0, CEIL - 0.16, 0.0), Vector3(WALL_R * 2.0, 0.32, 0.3), _m["cream"])
	# techo plano sobre el estrado de la Mesa
	b.cube(Vector3(0, CEIL + 0.05, MESA_Z * 0.5), Vector3(WALL_R * 2.0, 0.1, -MESA_Z), _m["plaster"])
	# lámparas de araña colgando de la vidriera
	for sx in [-1.0, 0.0, 1.0]:
		_chandelier(Vector3(sx * 4.6, CEIL, 3.4 if sx != 0.0 else 4.6))


func _chandelier(top: Vector3) -> void:
	var c := top - Vector3(0, 2.2, 0)
	b.segment(top, c + Vector3(0, 0.3, 0), 0.02, _m["gold"], 8)
	b.lathe(Transform3D(Basis(), c), [Vector2(0.0, -0.3), Vector2(0.1, -0.2), Vector2(0.18, 0.0), Vector2(0.08, 0.2), Vector2(0.05, 0.35), Vector2(0.0, 0.4)], _m["gold"], 18)
	for ring in 2:
		var rr := 0.7 + ring * 0.45
		var nk := 8 + ring * 4
		for i in nk:
			var a := TAU * i / nk
			var tip := c + Vector3(cos(a) * rr, 0.1 - ring * 0.25, sin(a) * rr)
			b.segment(c + Vector3(0, -0.06, 0), tip - Vector3(0, 0.05, 0), 0.012, _m["gold"], 6)
			b.cyl(tip + Vector3(0, 0.04, 0), 0.016, 0.016, 0.1, _m["cream"])
			b.sphere(tip + Vector3(0, 0.12, 0), 0.02, _m["lamp"], 8, 5, Vector3(1, 1.6, 1))
	glow(c + Vector3(0, 0.05, 0), 3.0, Color(1, 0.8, 0.5, 0.3))


# ------------------------------------------------------------------ personas

func _people() -> void:
	var gov_suits := ["22252c", "1b2c52", "3a3d44", "2a2c30", "4a3a5a", "2b3e66", "1d2b4a", "5a1f2a"]
	var far := []
	var opp_a := nearest_seat(OPP_A)
	for i in ROWS:
		var r := row_r(i)
		var h := row_h(i)
		for a in seat_angles(i):
			var pos := _p(r, a, h)
			var yaw := atan2(-cos(a), -sin(a))
			# el escaño del líder de la oposición se queda para él
			if i == 0 and a == opp_a:
				continue
			if _rng.randf() < 0.07:
				continue
			var gov: bool = a < PI * 0.5
			if i < NEAR_ROWS:
				var d := person(rand_look(_rng), pos, yaw, "sit", false)
				d.rest_anim = ["sit", "sit_table", "sit_write", "sit"][_rng.randi() % 4]
				(deputies_gov if gov else deputies_opp).append(d)
			else:
				far.append({"xf": Transform3D(Basis(Vector3.UP, yaw), pos), "suit": Color(gov_suits[_rng.randi() % gov_suits.size()]), "f": _rng.randf() < 0.42})
	# público en la galería (sin tapar la cámara del plano general)
	var gr := WALL_R - 0.75
	var ng := int(PI * gr / 0.62)
	var cam_a := atan2(WALL_R - 1.0, 1.2)
	for k in ng:
		var a := PI * (k + 0.5) / ng
		if _rng.randf() < 0.35 or absf(a - cam_a) < 0.14:
			continue
		far.append({"xf": Transform3D(Basis(Vector3.UP, atan2(-cos(a), -sin(a))), _p(gr, a, GALLERY_Y)), "suit": Color(gov_suits[_rng.randi() % gov_suits.size()]).lightened(0.15), "f": _rng.randf() < 0.5})
	crowd = Crowd3D.new()
	world.add_child(crowd)
	crowd.build(far, _rng)
	# el presidente en la tribuna y el líder de la oposición en su escaño de la primera fila
	me = person(pres_look, SPEAKER, 0.0, "")
	opp = person(opp_look, _p(row_r(0), opp_a, row_h(0)), atan2(-cos(opp_a), -sin(opp_a)), "sit")
	# la Mesa: presidenta de la Cámara y secretarios, con sus sillones
	for k in 5:
		var x := -2.0 + k * 1.0
		var y := 1.2 if absi(k - 2) <= 1 else 0.6
		var z := MESA_Z + 0.75 if y > 1.0 else MESA_Z + 1.6
		_seat(Vector3(x, y, z), -PI / 2.0, false)
		var p := person(rand_look(_rng), Vector3(x, y, z), 0.0, "table", k == 2)
		if absi(k - 2) > 1:
			p.rest_anim = "sit_write"
	# taquígrafos (de espaldas al hemiciclo, mirando a la tribuna) y ujieres
	for sx in [-0.45, 0.45]:
		_seat(Vector3(sx, 0, 1.45), PI / 2.0, false)
		person(rand_look(_rng), Vector3(sx, 0, 1.45), PI, "table", false).rest_anim = "sit_write"
	for sx in [-1.0, 1.0]:
		var ul := rand_look(_rng)
		ul["suit"] = "15171b"
		ul["tie"] = "c9a55c"
		var u := person(ul, Vector3(sx * 3.4, 0, -1.6), atan2(-sx, 1.0), "", false)
		u.rest_anim = "idle"


func _lights() -> void:
	env.ambient_light_color = Color(0.82, 0.7, 0.56)
	env.ambient_light_energy = 0.42
	# luz de la vidriera
	var sky := DirectionalLight3D.new()
	world.add_child(sky)
	sky.rotation = Vector3(deg_to_rad(-72), deg_to_rad(12), 0)
	sky.light_energy = 0.75
	sky.light_color = Color(0.95, 0.96, 1.0)
	sky.shadow_enabled = advanced and hi
	sky.directional_shadow_max_distance = 40.0
	omni(Vector3(0, CEIL - 1.6, 3.0), 2.4, 13.0, Color(1.0, 0.95, 0.85), false)
	# arañas y apliques
	for sx in [-1.0, 0.0, 1.0]:
		omni(Vector3(sx * 4.6, CEIL - 2.4, 3.4 if sx != 0.0 else 4.6), 1.8, 9.0, Color(1.0, 0.82, 0.58), false)
	for k in 5:
		var a := PI * (k + 0.5) / 5.0
		omni(_p(WALL_R - 1.0, a, GALLERY_Y - 1.0), 1.0, 6.0, Color(1.0, 0.8, 0.55), false)
	# focos sobre los dos oradores (la tribuna y el escaño del líder de la oposición) y la Mesa
	var opp_t := _p(row_r(0), nearest_seat(OPP_A), row_h(0) + 1.5)
	spot(Vector3(opp_t.x * 0.4, CEIL - 0.6, opp_t.z * 0.4 - 1.0), opp_t, 3.2, 14.0, Color(1.0, 0.95, 0.86), not low, 16.0)
	spot(Vector3(0, CEIL - 0.6, 3.0), SPEAKER + Vector3(0, 1.5, 0), 3.0, 14.0, Color(1.0, 0.95, 0.86), not low, 16.0)
	spot(Vector3(0, CEIL - 0.6, 5.0), Vector3(0, 1.4, MESA_Z + 1.0), 2.4, 40.0, Color(1.0, 0.93, 0.82), false, 16.0)
	spot(Vector3(0, CEIL - 0.6, 3.0), Vector3(0, 5.0, MESA_Z), 1.8, 40.0, Color(1.0, 0.9, 0.75), false, 16.0)


# ------------------------------------------------------------------ cámara y acción

## Marcadores colgados bajo la galería, a los dos lados, mirando a la tribuna
func _boards() -> void:
	var eye := SPEAKER + Vector3(0, 1.6, 0)
	var xfs := []
	for a in [0.96, PI - 0.96]:
		var p := _p(WALL_R - 1.55, a, GALLERY_Y - 0.85)
		var xf := facing(p, eye)
		xfs.append(xf)
		b.box(xf * Transform3D(Basis(), Vector3(0, 0, -0.06)), Vector3(3.95, 1.25, 0.1), _m["black"], 1.0, 0.02)
		b.frame(xf * Transform3D(Basis(), Vector3(0, 0, -0.02)), 4.0, 1.3, Kit.FRAME_PANEL, _m["gold"])
		for sx in [-1.4, 1.4]:
			var top := (xf * Transform3D(Basis(), Vector3(sx, 0.6, -0.06))).origin
			b.segment(top, top + Vector3(0, GALLERY_Y - 0.4 - top.y, 0), 0.015, _m["gold"], 6)
	b.commit(world)
	board = screen(Vector2i(1280, 384), xfs[0], 3.8, Color(0.02, 0.03, 0.06), 1.25)
	screen_copy(board, xfs[1], 3.8, 1.25)


## Plano general desde la galería: la Mesa, la tribuna y los diputados de espaldas
func wide() -> void:
	cam_pos = Vector3(1.2, GALLERY_Y + 1.5, WALL_R - 1.0)
	cam_look = Vector3(0, 2.4, MESA_Z + 0.6)
	cam.fov = 58.0
	cam_speed = 1.1
	sway = 0.04
	me.visible = true


## Los ojos del presidente en la tribuna, con la pantalla del atril y el hemiciclo delante
func pov() -> void:
	cam_pos = _pov[0]
	cam_look = _pov[1]
	cam.fov = 66.0
	sway = 0.0
	me.visible = false


## Contraplano: el líder de la oposición de pie en su escaño, con su bancada detrás
func shot_opp() -> void:
	var head: Vector3 = opp.global_position + Vector3(0, 1.62, 0)
	var to_trib := (SPEAKER - opp.global_position) * Vector3(1, 0, 1)
	var side := to_trib.normalized().cross(Vector3.UP)
	cam_pos = head + to_trib.normalized() * 2.5 + side * 0.7 + Vector3(0, 0.05, 0)
	cam_look = head - Vector3(0, 0.25, 0)
	cam.fov = 40.0
	sway = 0.015
	me.visible = true
	cut()


## El presidente en el atril mirando al hemiciclo, por encima del hombro
func shot_me() -> void:
	cam_pos = Vector3(0.75, 2.25, SPEAKER.z - 1.2)
	cam_look = Vector3(-0.9, 1.2, 4.5)
	cam.fov = 50.0
	sway = 0.015
	me.visible = true
	cut()


## Turno de palabra. "opp": el líder de la oposición se levanta y pregunta (plano de él) y luego se vuelve
## a la tribuna para elegir la réplica. "me": el presidente responde desde el atril; el otro se sienta.
func turn(who: String) -> void:
	_turn_id += 1
	var id := _turn_id
	cam_speed = 2.5
	if who == "opp":
		opp.seat("")
		opp.rotation.y = yaw_to(opp.global_position, SPEAKER)
		me.rotation.y = yaw_to(SPEAKER, opp.global_position)
		shot_opp()
		get_tree().create_timer(OPP_SHOT).timeout.connect(func():
			if id == _turn_id and is_inside_tree():
				pov()
				cut())
	else:
		me.rotation.y = 0.0
		shot_me()
		get_tree().create_timer(0.7).timeout.connect(func():
			if is_instance_valid(opp):
				opp.seat("sit")
				opp.rotation.y = yaw_to(opp.global_position, Vector3.ZERO))


## Al acabar: de vuelta a la tribuna para ver el resultado en el atril
func finish() -> void:
	_turn_id += 1
	pov()
	cut()


## Una bancada aplaude (gov = la del Gobierno) y la otra protesta
func cheer(gov: bool) -> void:
	_cheer_t = 1.8
	_cheer_gov = gov
	for d in deputies_gov:
		d.gesture = "sit_clap" if gov else ""
		d.talking = not gov and randf() < 0.4
	for d in deputies_opp:
		d.gesture = "" if gov else "sit_clap"
		d.talking = gov and randf() < 0.4
	if crowd != null:
		crowd.cheer(0.0 if gov else 1.0, 1.0 if gov else 0.0)


func _process(delta: float) -> void:
	super(delta)
	if _cheer_t > 0.0:
		_cheer_t -= delta
		if _cheer_t <= 0.0:
			for d in deputies_gov + deputies_opp:
				d.gesture = ""
				d.talking = false
			if crowd != null:
				crowd.cheer(0.0, 0.0)
