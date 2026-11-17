extends "res://scripts/stages3d/stage_3d.gd"
## Plató de Canal 7 para el debate: tarima circular con dos atriles enfrentados (el presidente a la izquierda y el
## líder de la oposición a la derecha, con su nombre y el color de su partido), la moderadora en su mesa delante de
## ellos, de espaldas al público, la pantalla LED del canal al fondo, dos marcadores colgados (el «¿quién va ganando?»
## que dibuja el minijuego, uno detrás de cada candidato), cámaras con sus operadores y el público en sus butacas.
## El presidente (la cámara) está en su atril: las réplicas son tarjetas sobre el tablero, con la luz del tiempo en el
## canto. Planos: pov(), wide(), shot_opp(), shot_me() y shot_mod(); acción: opp_attack(), me_reply(), react() y finish().

const Crowd3D := preload("res://scripts/stages3d/crowd_3d.gd")
const W := preload("res://scripts/data/world_data.gd")

const PLAT_H := 0.2
const ME_POS := Vector3(-1.7, PLAT_H, -0.3)
const OPP_POS := Vector3(1.7, PLAT_H, -0.3)
## La moderadora, sentada a su mesa entre los dos atriles y de cara a ellos
const MOD_POS := Vector3(0, PLAT_H, 1.35)
## Tablero del atril en el espacio del orador (de cara a +Z), inclinado hacia él
const TOP_LOCAL := Transform3D(Basis(Vector3.RIGHT, -0.26), Vector3(0, 1.15, 0.5))
const TOP_SIZE := Vector3(0.95, 0.04, 0.5)
const TRUSS_Y := 5.0
const AUD_Z := 5.0
const AUD_ROWS := 7

var pres_look: Dictionary = {}
var opp_look: Dictionary = {}
var pres_name := ""
var opp_name := ""
var own_color := Color("e2574c")
var opp_color := Color("2f6fd6")
## Rótulo de la pantalla del fondo
var wall_title := "El debate"

var me: Node3D
var opp: Node3D
var moderator: Node3D
## Marcador del «¿quién va ganando?» (lo dibuja el minijuego; sale detrás de cada candidato)
var board: Control
var crowd
var audience: Array = []
var top_xf := Transform3D()
var opp_eye := Vector3.ZERO
var _yaw_me := 0.0
var _yaw_opp := 0.0
var _cheer_t := 0.0
var _m := {}
var _rng := RandomNumberGenerator.new()


func build() -> void:
	_rng.seed = 23
	_m = {
		"floor": Kit.mat(Color("0b0c10"), 0.18, 0.2),
		"plat": Kit.mat(Color("161a24"), 0.3, 0.3),
		"edge": Kit.emissive(Color(0.35, 0.6, 1.0), 2.2),
		"desk": Kit.mat(Color("e9eef5"), 0.25, 0.1),
		"desk_top": Kit.mat(Color("1b2233"), 0.4, 0.15),
		"lectern": Kit.mat(Color("1d2433"), 0.32, 0.25),
		"lectern_top": Kit.mat(Color("141a26"), 0.45, 0.15),
		"black": Kit.mat(Color("121316"), 0.5, 0.3),
		"truss": Kit.mat(Color("6c7078"), 0.35, 0.85),
		"curtain": Kit.velvet(Color("12141c")),
		"chair": Kit.leather(Color("1a1a1e"), 0.35),
		"seat": Kit.velvet(Color("2a2f45")),
		"chrome": Kit.chrome(),
		"paper": Kit.mat(Color("f4f1e8"), 0.9),
	}
	_yaw_me = yaw_to(ME_POS, Vector3(OPP_POS.x, 0, 0.6))
	_yaw_opp = yaw_to(OPP_POS, Vector3(ME_POS.x, 0, 0.6))
	eye = ME_POS + Vector3(0, 1.62, 0)
	opp_eye = OPP_POS + Vector3(0, 1.62, 0)
	top_xf = Transform3D(Basis(Vector3.UP, _yaw_me), ME_POS) * TOP_LOCAL
	_plato()
	_lectern(ME_POS, _yaw_me, pres_name, own_color)
	_lectern(OPP_POS, _yaw_opp, opp_name, opp_color)
	_mod_desk()
	_videowall()
	_boards()
	_cameras()
	_audience()
	_lights()
	b.commit(world)
	me = person(pres_look, ME_POS, _yaw_me)
	me.rest_anim = "lectern"
	me.talk_anim = "lectern_talk"
	opp = person(opp_look, OPP_POS, _yaw_opp)
	opp.rest_anim = "lectern"
	opp.talk_anim = "lectern_talk"
	moderator = person(W.CHARACTERS["periodista"]["look"], MOD_POS, PI, "table")
	time_strip(facing(top_xf * Vector3(0, 0.035, TOP_SIZE.z * 0.5 - 0.012), eye), 0.6)
	shade_top = 0.4
	shade_bottom = 0.5
	wide()


# ------------------------------------------------------------------ plató

func _plato() -> void:
	b.cube(Vector3(0, -0.05, 2.0), Vector3(26, 0.1, 24), _m["floor"])
	var c := Vector3(0, PLAT_H * 0.5, -0.9)
	b.cylinder(Transform3D(Basis(), c), 3.6, 3.6, PLAT_H, _m["plat"], 72)
	b.cylinder(Transform3D(Basis(), c), 3.62, 3.62, 0.03, _m["edge"], 72)
	# anillo de luz embutido en la tarima
	b.cylinder(Transform3D(Basis(), Vector3(0, PLAT_H + 0.001, -0.9)), 2.3, 2.3, 0.002, Kit.emissive(Color(0.3, 0.5, 1.0), 1.2), 64)
	b.cylinder(Transform3D(Basis(), Vector3(0, PLAT_H + 0.002, -0.9)), 2.26, 2.26, 0.002, _m["plat"], 64)
	# fondo: cortinas negras con tiras de luz
	for k in 9:
		b.box(Transform3D(Basis(), Vector3(-10.0 + k * 2.5, 3.0, -5.6)), Vector3(2.4, 6.0, 0.2), _m["curtain"], 1.0, 0.08, 2)
	for sx in [-1.0, 1.0]:
		for k in 5:
			b.box(Transform3D(Basis(), Vector3(sx * (5.6 + k * 0.5), 2.2, -4.6 + k * 0.2)), Vector3(0.06, 4.4, 0.06), Kit.emissive(Color(0.3, 0.45, 1.0), 2.5))
		# cortinas a los lados
		b.box(Transform3D(Basis(), Vector3(sx * 8.2, 3.0, 2.0)), Vector3(0.2, 6.0, 16.0), _m["curtain"], 1.0, 0.08, 2)


## Atril de un candidato en pos, de cara a yaw: cuerpo oscuro con canto de luz del color del partido, el nombre
## en el frontal y el tablero inclinado (en el del presidente se reparten las tarjetas)
func _lectern(pos: Vector3, yaw: float, who: String, col: Color) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	var glow_m := Kit.emissive(col.lightened(0.15), 2.2)
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.02, 0.56)), Vector3(0.82, 0.04, 0.56), _m["black"], 1.0, 0.01)
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.56, 0.58)), Vector3(0.66, 1.0, 0.42), _m["lectern"], 1.0, 0.02, 2)
	# cantos de luz a los lados y franja del partido en el frontal
	for sx in [-0.335, 0.335]:
		b.box(xf * Transform3D(Basis(), Vector3(sx, 0.56, 0.79)), Vector3(0.014, 0.96, 0.014), glow_m)
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.9, 0.792)), Vector3(0.6, 0.07, 0.01), glow_m)
	b.box(xf * TOP_LOCAL, TOP_SIZE, _m["lectern_top"], 1.0, 0.012, 2)
	b.box(xf * TOP_LOCAL * Transform3D(Basis(), Vector3(0, TOP_SIZE.y * 0.5 + 0.012, -TOP_SIZE.z * 0.5 + 0.02)), Vector3(0.9, 0.022, 0.016), _m["chrome"], 1.0, 0.006)
	# micrófono de cuello de cisne
	var a := xf * TOP_LOCAL * Vector3(0.34, TOP_SIZE.y * 0.5, 0.18)
	var mid := a + xf.basis * Vector3(-0.03, 0.12, 0.0)
	var tip := a + xf.basis * Vector3(-0.1, 0.17, -0.1)
	b.segment(a, mid, 0.005, _m["black"], 8)
	b.segment(mid, tip, 0.005, _m["black"], 8)
	b.sphere(tip, 0.014, Kit.mat(Color("101012"), 0.9), 10, 6, Vector3(1, 1, 1.6))
	glow(a + Vector3(0, 0.02, 0), 0.025, Color(1, 0.2, 0.15, 0.9))
	if who != "":
		Kit.label(world, who.to_upper(), UI.f_sans_b, 44, Color.WHITE, (xf * Transform3D(Basis(), Vector3(0, 0.72, 0.795))).origin, Vector3(0, yaw, 0), 0.0011)
	Kit.blob(world, pos + xf.basis * Vector3(0, 0, 0.5), 1.1, 0.9, 0.5, yaw)


## Mesa de la moderadora, delante de los atriles y de cara a ellos
func _mod_desk() -> void:
	var c := Vector3(0, PLAT_H, 0.66)
	b.box(Transform3D(Basis(), c + Vector3(0, 0.72, 0)), Vector3(1.7, 0.05, 0.72), _m["desk_top"], 1.0, 0.02, 2)
	b.box(Transform3D(Basis(), c + Vector3(0, 0.35, -0.1)), Vector3(1.4, 0.66, 0.36), _m["desk"], 1.0, 0.05, 2)
	b.box(Transform3D(Basis(), c + Vector3(0, 0.08, -0.1)), Vector3(1.44, 0.03, 0.4), _m["edge"])
	Kit.label(world, "CANAL 7", UI.f_sans_b, 64, Color("c62828"), c + Vector3(0, 0.42, -0.285), Vector3(0, PI, 0), 0.0016)
	# guion, tableta y taza
	b.box(Transform3D(Basis(Vector3.UP, 0.15), c + Vector3(0.28, 0.75, 0.12)), Vector3(0.21, 0.01, 0.3), _m["paper"])
	b.box(Transform3D(Basis(Vector3.UP, -0.1), c + Vector3(-0.3, 0.752, 0.1)), Vector3(0.24, 0.012, 0.17), _m["black"], 1.0, 0.004)
	b.cyl(c + Vector3(-0.62, 0.795, 0.15), 0.04, 0.035, 0.1, Kit.mat(Color("e9e4d8"), 0.3))
	# sillón
	var xf := Transform3D(Basis(Vector3.UP, PI), MOD_POS)
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.42, 0.06)), Vector3(0.56, 0.12, 0.52), _m["chair"], 1.0, 0.04, 2)
	b.box(xf * Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 0.82, -0.22)), Vector3(0.56, 0.72, 0.1), _m["chair"], 1.0, 0.045, 2)
	b.cyl(MOD_POS + Vector3(0, 0.18, 0), 0.03, 0.03, 0.36, _m["chrome"])
	b.cyl(MOD_POS + Vector3(0, 0.015, 0), 0.26, 0.28, 0.03, _m["chrome"], Vector3.ZERO, 24)


## Pantalla LED del fondo: logotipo del canal, «EN DIRECTO» y el nombre del programa sobre la ciudad de noche
func _videowall() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1600, 700)
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var c := Control.new()
	c.size = Vector2(1600, 700)
	var title := wall_title
	c.draw.connect(func():
		for i in 20:
			c.draw_rect(Rect2(0, i * 35, 1600, 35), Color("0b1a3d").lerp(Color("3a1630"), i / 20.0))
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var x := 0.0
		while x < 1600:
			var w := rng.randf_range(40, 110)
			var h := rng.randf_range(120, 330)
			c.draw_rect(Rect2(x, 700 - h, w - 6, h), Color("101a33"))
			for wy in int(h / 22):
				for wx in int(w / 18):
					if rng.randf() < 0.45:
						c.draw_rect(Rect2(x + 6 + wx * 18, 700 - h + 10 + wy * 22, 8, 10), Color(1, 0.85, 0.5, 0.7))
			x += w
		c.draw_rect(Rect2(0, 0, 1600, 700), Color(0.05, 0.1, 0.3, 0.3))
		c.draw_circle(Vector2(800, 170), 100, Color("c62828"))
		c.draw_string(UI.f_sans_b, Vector2(700, 214), "7", HORIZONTAL_ALIGNMENT_CENTER, 200, 130, Color.WHITE)
		c.draw_string(UI.f_serif_b, Vector2(0, 390), title.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 1600, 110, Color.WHITE)
		c.draw_rect(Rect2(650, 430, 300, 52), Color("c62828"))
		c.draw_string(UI.f_sans_b, Vector2(650, 470), "● EN DIRECTO", HORIZONTAL_ALIGNMENT_CENTER, 300, 36, Color.WHITE))
	sv.add_child(c)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(9.0, 3.94)
	mi.mesh = q
	mi.material_override = Kit.screen_mat(sv.get_texture(), 1.2)
	world.add_child(mi)
	mi.global_transform = Transform3D(Basis(), Vector3(0, 2.75, -5.0))
	b.box(Transform3D(Basis(), Vector3(0, 2.75, -5.06)), Vector3(9.2, 4.14, 0.1), _m["black"])


## Los dos marcadores colgados de la parrilla: el de la derecha (detrás del líder de la oposición) mira al presidente
## y su copia, a la izquierda, mira al líder de la oposición
func _boards() -> void:
	var bw := 3.4
	var xr := facing(Vector3(5.0, 2.6, -2.2), eye)
	var xl := facing(Vector3(-5.0, 2.6, -2.2), opp_eye)
	for xf: Transform3D in [xr, xl]:
		b.box(xf * Transform3D(Basis(), Vector3(0, 0, -0.05)), Vector3(bw + 0.16, bw * 0.5 + 0.16, 0.08), _m["black"], 1.0, 0.02)
		b.box(xf * Transform3D(Basis(), Vector3(0, -bw * 0.25 - 0.1, -0.05)), Vector3(bw + 0.16, 0.03, 0.1), _m["edge"])
		for sx in [-1.3, 1.3]:
			var top := (xf * Transform3D(Basis(), Vector3(sx, bw * 0.25 + 0.08, -0.05))).origin
			b.segment(top, Vector3(top.x, TRUSS_Y, top.z), 0.012, _m["truss"], 6)
	board = screen(Vector2i(1280, 640), xr, bw, Color(0.02, 0.03, 0.06), 1.2)
	screen_copy(board, xl, bw, 1.2)


func _cameras() -> void:
	for spec in [[Vector3(-3.4, 0, 2.9), "1", OPP_POS], [Vector3(3.4, 0, 2.9), "2", ME_POS], [Vector3(1.6, 0, 3.5), "3", Vector3(0, 0, -0.3)]]:
		var base: Vector3 = spec[0]
		var target: Vector3 = spec[2] + Vector3(0, 1.6, 0)
		var head := base + Vector3(0, 1.35, 0)
		var yaw := yaw_to(head, target) + PI
		b.cyl(base + Vector3(0, 0.05, 0), 0.45, 0.5, 0.1, _m["black"], Vector3.ZERO, 24)
		b.cyl(base + Vector3(0, 0.65, 0), 0.07, 0.09, 1.2, _m["truss"])
		var cxf := Transform3D(Basis(Vector3.UP, yaw), head)
		b.box(cxf, Vector3(0.3, 0.34, 0.6), Kit.mat(Color("2b2d31"), 0.4, 0.3), 1.0, 0.03, 2)
		b.cylinder(cxf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0, -0.45)), 0.12, 0.12, 0.32, _m["black"], 20)
		b.box(cxf * Transform3D(Basis(), Vector3(0, 0.02, 0.34)), Vector3(0.3, 0.24, 0.06), Kit.emissive(Color(0.25, 0.3, 0.45), 0.6))
		Kit.label(world, spec[1], UI.f_sans_b, 120, Color(1, 1, 1, 0.9), (cxf * Transform3D(Basis(), Vector3(0.152, 0.02, 0.0))).origin, Vector3(0, yaw + PI / 2.0, 0), 0.0015)
		glow((cxf * Transform3D(Basis(), Vector3(0, 0.2, -0.28))).origin, 0.1, Color(1, 0.1, 0.05, 0.95))
		var op_pos := base + Vector3(sin(yaw), 0, cos(yaw)) * 0.75
		var op := person(rand_look(_rng), op_pos, yaw_to(op_pos, target), "", false, 3)
		op.rest_anim = "operate"


func _chair(pos: Vector3) -> void:
	var xf := Transform3D(Basis(Vector3.UP, PI), pos)
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.42, 0.06)), Vector3(0.52, 0.08, 0.48), _m["seat"], 1.0, 0.025, 2)
	b.box(xf * Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 0.78, -0.2)), Vector3(0.52, 0.56, 0.07), _m["seat"], 1.0, 0.025, 2)
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.19, 0.0)), Vector3(0.4, 0.38, 0.36), _m["black"])


## Público en butacas, de cara al plató: la primera fila, de cuerpo entero (aplaude o murmura); el resto, ligero
func _audience() -> void:
	var far := []
	var suits := ["22252c", "1b2c52", "3a3d44", "2a2c30", "4a3a5a", "2b3e66", "5a1f2a", "2f4a3a", "6b6e74", "1d2b4a", "7a2f2f", "3e5a7a"]
	for r in AUD_ROWS:
		var z := AUD_Z + r * 0.95
		var y := r * 0.12
		if r > 0:
			b.cube(Vector3(0, y * 0.5 - 0.02, z), Vector3(12.0, y + 0.04, 0.95), _m["black"])
		var k := 0
		var x := -5.2
		while x <= 5.21:
			if absf(x) > 0.5:
				var pos := Vector3(x, y, z)
				_chair(pos)
				if _rng.randf() > 0.1:
					if r == 0:
						var a := person(rand_look(_rng), pos, PI, "sit", false, 2)
						a.rest_anim = "sit"
						audience.append(a)
					else:
						far.append({"xf": Transform3D(Basis(Vector3.UP, PI), pos), "suit": Color(suits[_rng.randi() % suits.size()]), "f": _rng.randf() < 0.5})
			x += 0.65
			k += 1
	crowd = Crowd3D.new()
	world.add_child(crowd)
	crowd.build(far, _rng)


func _lights() -> void:
	env.background_color = Color(0.01, 0.012, 0.02)
	env.ambient_light_color = Color(0.45, 0.5, 0.75)
	env.ambient_light_energy = 0.4
	env.volumetric_fog_density = 0.012
	# parrilla de focos
	for z in [-2.2, 0.6, 3.0]:
		b.box(Transform3D(Basis(), Vector3(0, TRUSS_Y, z)), Vector3(12.0, 0.12, 0.12), _m["truss"])
	for k in 8:
		var p := Vector3(-4.2 + k * 1.2, TRUSS_Y - 0.2, 0.6)
		b.cyl(p, 0.11, 0.13, 0.28, _m["black"], Vector3(0.6, 0, 0), 14)
		glow(p + Vector3(0, -0.12, -0.08), 0.35, Color(1, 0.92, 0.8, 0.7))
	# luz principal sobre cada candidato (desde el público), contraluces de color y la moderadora (desde el fondo)
	spot(Vector3(-0.8, TRUSS_Y - 0.2, 3.0), OPP_POS + Vector3(0, 1.4, 0), 4.5, 20.0, Color(1, 0.95, 0.88), not low, 10.0)
	spot(Vector3(0.8, TRUSS_Y - 0.2, 3.0), ME_POS + Vector3(0, 1.4, 0), 4.5, 20.0, Color(1, 0.95, 0.88), not low, 10.0)
	spot(Vector3(0, TRUSS_Y - 0.2, -2.2), MOD_POS + Vector3(0, 1.1, 0), 3.2, 22.0, Color(1, 0.95, 0.9), false, 9.0)
	spot(Vector3(-3.0, TRUSS_Y - 0.4, -3.2), ME_POS + Vector3(0, 1.5, 0), 2.4, 18.0, own_color.lightened(0.3), false, 9.0)
	spot(Vector3(3.0, TRUSS_Y - 0.4, -3.2), OPP_POS + Vector3(0, 1.5, 0), 2.4, 18.0, opp_color.lightened(0.3), false, 9.0)
	omni(Vector3(0, 2.2, -4.2), 1.4, 6.0, Color(0.45, 0.4, 1.0), false)
	omni(Vector3(0, 4.0, AUD_Z + 2.5), 1.3, 9.0, Color(0.7, 0.75, 1.0), false)
	# flexo sobre el atril del presidente: las tarjetas se leen bien
	spot(eye + Vector3(0, 1.0, 0) + Transform3D(Basis(Vector3.UP, _yaw_me), Vector3.ZERO) * Vector3(0, 0, 0.15), top_center(), 0.8, 34.0, Color(1.0, 0.94, 0.84), false, 3.2)


# ------------------------------------------------------------------ tablero del atril

## Centro y normal del tablero del atril del presidente (donde se reparten las tarjetas)
func top_center() -> Vector3:
	return top_xf * Vector3(0, TOP_SIZE.y * 0.5, 0.04)


func top_normal() -> Vector3:
	return top_xf.basis.y.normalized()


## Punto del tablero (x: hacia la izquierda del orador; z: hacia delante)
func top_point(x: float, z: float) -> Vector3:
	return top_xf * Vector3(x, TOP_SIZE.y * 0.5, z)


# ------------------------------------------------------------------ cámara

## Plano general desde el fondo del público: los dos atriles, la moderadora de espaldas y la pantalla del canal
func wide() -> void:
	cam_pos = Vector3(0.4, 3.1, AUD_Z + 3.2)
	cam_look = Vector3(0, 1.5, -1.2)
	fov_target = 50.0
	cam_speed = 1.1
	sway = 0.04
	look_range = Vector2.ZERO
	me.visible = true


## Los ojos del presidente en su atril. down: mirando las tarjetas (con el rival delante); at: mirando a ese punto
func pov(down := true, at := Vector3.INF) -> void:
	cam_pos = eye
	if at != Vector3.INF:
		cam_look = eye + (at - eye).normalized() * 10.0
	else:
		var fwd := Vector3(sin(_yaw_me), 0, cos(_yaw_me))
		var pitch := deg_to_rad(21.0 if down else 4.0)
		cam_look = eye + (fwd * cos(pitch) - Vector3.UP * sin(pitch)) * 10.0
	fov_target = 62.0
	cam_speed = 2.2
	sway = 0.0
	look_range = Vector2(5.0, 3.0) if down else Vector2(8.0, 4.0)
	me.visible = false


## Primer plano del líder de la oposición desde la cámara de su lado, con su marcador detrás
func shot_opp() -> void:
	var head := opp_eye
	var to := (ME_POS - OPP_POS).normalized()
	cam_pos = head + to * 2.3 + Vector3(0, 0, 0.75) + Vector3(0, -0.05, 0)
	cam_look = head - Vector3(0, 0.25, 0)
	fov_target = 40.0
	sway = 0.015
	look_range = Vector2.ZERO
	me.visible = true
	cut()


## Primer plano del presidente, desde el otro lado
func shot_me() -> void:
	var to := (OPP_POS - ME_POS).normalized()
	cam_pos = eye + to * 2.3 + Vector3(0, 0, 0.75) + Vector3(0, -0.05, 0)
	cam_look = eye - Vector3(0, 0.25, 0)
	fov_target = 40.0
	sway = 0.015
	look_range = Vector2.ZERO
	me.visible = true
	cut()


## La moderadora de frente, desde detrás de los atriles, con el público al fondo
func shot_mod() -> void:
	cam_pos = Vector3(0.55, PLAT_H + 1.45, -0.6)
	cam_look = MOD_POS + Vector3(0, 1.05, 0)
	fov_target = 42.0
	sway = 0.012
	look_range = Vector2.ZERO
	me.visible = true
	cut()


# ------------------------------------------------------------------ acción

## El líder de la oposición ataca: señala al presidente
func opp_attack() -> void:
	opp.mood = -0.2
	opp.anger = 0.25
	gesture(opp, "point", 2.2)
	me.mood = 0.0


func me_reply() -> void:
	me.mood = 0.1
	opp.gesture = ""
	opp.anger = 0.0


## Reacción del plató a una réplica: "good" (golpe maestro: aplausos), "ok" (algún aplauso) o "bad" (risas y murmullos)
func react(kind: String) -> void:
	_cheer_t = 2.6
	match kind:
		"good":
			crowd_cheer(0.8)
			me.mood = 0.7
			opp.mood = -0.6
			opp.anger = 0.5
			for a in audience:
				if _rng.randf() < 0.6:
					gesture(a, "sit_clap", randf_range(1.4, 2.4))
		"ok":
			crowd_cheer(0.25)
			me.mood = 0.25
			for a in audience:
				if _rng.randf() < 0.25:
					gesture(a, "sit_clap", randf_range(1.0, 1.8))
		_:
			me.mood = -0.5
			opp.mood = 0.6
			opp.anger = 0.0
			gesture(opp, "laugh", 1.8)
			for a in audience:
				var r := _rng.randf()
				if r < 0.35:
					gesture(a, "sit_laugh", randf_range(1.2, 2.0))
				elif r < 0.7:
					a.talking = true


## Al acabar: plano general, el ganador saluda y el público aplaude
func finish(won: bool) -> void:
	_cheer_t = 4.0
	crowd_cheer(1.0)
	for a in audience:
		if _rng.randf() < 0.75:
			gesture(a, "sit_clap", randf_range(2.0, 3.5))
	var winner := me if won else opp
	var loser := opp if won else me
	gesture(winner, "cheer", 2.6)
	winner.mood = 0.8
	loser.mood = -0.4
	wide()
	cam_speed = 0.8


func crowd_cheer(a: float) -> void:
	if crowd != null:
		crowd.cheer(a, a)


func _process(delta: float) -> void:
	super(delta)
	if _cheer_t > 0.0:
		_cheer_t -= delta
		if _cheer_t <= 0.0:
			crowd_cheer(0.0)
			for a in audience:
				a.talking = false
