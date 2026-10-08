extends "res://scripts/stages3d/stage_3d.gd"
## Plató de Canal 7 para las entrevistas: tarima circular con mesa curva, la entrevistadora enfrente, pantalla
## LED con el rótulo del canal y la ciudad detrás, cámaras de estudio con sus operadores, parrilla de focos y el
## piloto de «EN EL AIRE». El presidente (la cámara) está sentado a la mesa; la pantalla de la mesa lleva
## preguntas y respuestas. Expone la misma acción que la sala de prensa: ask(), stop_asking(), react(), burst().

const W := preload("res://scripts/data/world_data.gd")

const PLAT_H := 0.15
## La entrevistadora, enfrente y un poco a un lado
const HOST := Vector3(0.38, PLAT_H, 1.78)

var interviewer: Node3D
var _onair: MeshInstance3D
var _m := {}
var _rng := RandomNumberGenerator.new()


func build() -> void:
	_rng.seed = 7
	_m = {
		"floor": Kit.mat(Color("0b0c10"), 0.18, 0.2),
		"plat": Kit.mat(Color("161a24"), 0.3, 0.3),
		"edge": Kit.emissive(Color(0.35, 0.6, 1.0), 2.2),
		"desk": Kit.mat(Color("e9eef5"), 0.25, 0.1),
		"desk_top": Kit.mat(Color("1b2233"), 0.15, 0.4),
		"black": Kit.mat(Color("121316"), 0.5, 0.3),
		"truss": Kit.mat(Color("6c7078"), 0.35, 0.85),
		"curtain": Kit.velvet(Color("12141c")),
		"chair": Kit.leather(Color("1a1a1e"), 0.35),
		"chrome": Kit.chrome(),
		"paper": Kit.mat(Color("f4f1e8"), 0.9),
	}
	_plato()
	_videowall()
	_cameras()
	_lights()
	b.commit(world)
	interviewer = person(W.CHARACTERS["periodista"]["look"], HOST, yaw_to(HOST, Vector3.ZERO), "table")
	ui = pov_screen(Vector3(0, PLAT_H + 1.2, 0.0), yaw_to(Vector3.ZERO, Vector3(HOST.x * 0.4, 0, HOST.z)), Vector2i(1400, 640), 0.73)


func _plato() -> void:
	# suelo negro brillante, tarima circular con canto luminoso
	b.cube(Vector3(0, -0.05, 1.5), Vector3(24, 0.1, 20), _m["floor"])
	b.cylinder(Transform3D(Basis(), Vector3(0, PLAT_H * 0.5, 0.9)), 3.0, 3.0, PLAT_H, _m["plat"], 64)
	b.cylinder(Transform3D(Basis(), Vector3(0, PLAT_H * 0.5, 0.9)), 3.02, 3.02, 0.03, _m["edge"], 64)
	# mesa: tablero oscuro y brillante sobre un faldón blanco con una tira de luz
	var c := Vector3(0.12, PLAT_H, 0.9)
	var dxf := Transform3D(Basis(Vector3.UP, -0.2), c)
	b.box(dxf * Transform3D(Basis(), Vector3(0, 0.68, 0)), Vector3(1.9, 0.05, 1.0), _m["desk_top"], 1.0, 0.02, 2)
	b.box(dxf * Transform3D(Basis(), Vector3(0, 0.33, 0)), Vector3(1.4, 0.64, 0.5), _m["desk"], 1.0, 0.05, 2)
	b.box(dxf * Transform3D(Basis(), Vector3(0, 0.08, 0)), Vector3(1.44, 0.03, 0.54), _m["edge"])
	# sillones
	for p in [Vector3(0, PLAT_H, 0.0), HOST]:
		var yaw := yaw_to(p, Vector3(0, PLAT_H, 0.9))
		var xf := Transform3D(Basis(Vector3.UP, yaw), p)
		b.box(xf * Transform3D(Basis(), Vector3(0, 0.42, 0.06)), Vector3(0.56, 0.12, 0.52), _m["chair"], 1.0, 0.04, 2)
		b.box(xf * Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 0.82, -0.22)), Vector3(0.56, 0.72, 0.1), _m["chair"], 1.0, 0.045, 2)
		b.cyl(p + Vector3(0, 0.18, 0), 0.03, 0.03, 0.36, _m["chrome"])
		b.cyl(p + Vector3(0, 0.015, 0), 0.26, 0.28, 0.03, _m["chrome"], Vector3.ZERO, 24)
	# guion y taza en la mesa
	b.box(Transform3D(Basis(Vector3.UP, 0.3), HOST + Vector3(-0.3, 0.71, -0.42)), Vector3(0.21, 0.01, 0.3), _m["paper"])
	b.cyl(HOST + Vector3(0.05, 0.755, -0.45), 0.04, 0.035, 0.1, Kit.mat(Color("e9e4d8"), 0.3))
	# fondo: cortinas negras con tiras de luz
	for k in 9:
		var x := -10.0 + k * 2.5
		b.box(Transform3D(Basis(), Vector3(x, 3.0, 8.0)), Vector3(2.4, 6.0, 0.2), _m["curtain"], 1.0, 0.08, 2)
	for sx in [-1.0, 1.0]:
		for k in 5:
			b.box(Transform3D(Basis(), Vector3(sx * (4.2 + k * 0.5), 2.2, 6.6 - k * 0.2)), Vector3(0.06, 4.4, 0.06), Kit.emissive(Color(0.3, 0.45, 1.0), 2.5))


## Pantalla LED detrás de la entrevistadora: logotipo del canal, «EN DIRECTO» y la ciudad de noche
func _videowall() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1600, 700)
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var c := Control.new()
	c.size = Vector2(1600, 700)
	c.draw.connect(func():
		for i in 20:
			c.draw_rect(Rect2(0, i * 35, 1600, 35), Color("0b1a3d").lerp(Color("2c1f5c"), i / 20.0))
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var x := 0.0
		while x < 1600:
			var w := rng.randf_range(40, 110)
			var h := rng.randf_range(120, 380)
			c.draw_rect(Rect2(x, 700 - h, w - 6, h), Color("101a33"))
			for wy in int(h / 22):
				for wx in int(w / 18):
					if rng.randf() < 0.45:
						c.draw_rect(Rect2(x + 6 + wx * 18, 700 - h + 10 + wy * 22, 8, 10), Color(1, 0.85, 0.5, 0.7))
			x += w
		c.draw_rect(Rect2(0, 0, 1600, 700), Color(0.05, 0.1, 0.3, 0.25))
		c.draw_circle(Vector2(300, 220), 120, Color("c62828"))
		c.draw_string(UI.f_sans_b, Vector2(180, 262), "7", HORIZONTAL_ALIGNMENT_CENTER, 240, 150, Color.WHITE)
		c.draw_string(UI.f_sans_b, Vector2(470, 210), "CANAL 7", HORIZONTAL_ALIGNMENT_LEFT, -1, 110, Color.WHITE)
		c.draw_rect(Rect2(474, 248, 300, 56), Color("c62828"))
		c.draw_string(UI.f_sans_b, Vector2(474, 292), "● EN DIRECTO", HORIZONTAL_ALIGNMENT_CENTER, 300, 40, Color.WHITE)
		c.draw_string(UI.f_serif_b, Vector2(470, 380), "La entrevista", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color(1, 1, 1, 0.85)))
	sv.add_child(c)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(9.0, 3.94)
	mi.mesh = q
	mi.material_override = Kit.screen_mat(sv.get_texture(), 1.25)
	world.add_child(mi)
	mi.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(1.0, 2.6, 6.2))
	b.box(Transform3D(Basis(), Vector3(1.0, 2.6, 6.26)), Vector3(9.2, 4.14, 0.1), _m["black"])


func _cameras() -> void:
	for spec in [[Vector3(-3.0, 0, 3.3), "1"], [Vector3(3.6, 0, 2.9), "2"], [Vector3(-1.0, 0, 4.6), "3"]]:
		var base: Vector3 = spec[0]
		var target := Vector3(0, PLAT_H + 1.2, 0.0)
		var head := base + Vector3(0, 1.35, 0)
		var yaw := yaw_to(head, target) + PI
		b.cyl(base + Vector3(0, 0.05, 0), 0.45, 0.5, 0.1, _m["black"], Vector3.ZERO, 24)
		b.cyl(base + Vector3(0, 0.65, 0), 0.07, 0.09, 1.2, _m["truss"])
		var cxf := Transform3D(Basis(Vector3.UP, yaw), head)
		b.box(cxf, Vector3(0.3, 0.34, 0.6), Kit.mat(Color("2b2d31"), 0.4, 0.3), 1.0, 0.03, 2)
		b.cylinder(cxf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0, -0.45)), 0.12, 0.12, 0.32, _m["black"], 20)
		b.box(cxf * Transform3D(Basis(), Vector3(0, 0.02, 0.34)), Vector3(0.3, 0.24, 0.06), Kit.emissive(Color(0.25, 0.3, 0.45), 0.6))
		b.box(cxf * Transform3D(Basis(), Vector3(0, 0.27, 0.12)), Vector3(0.2, 0.16, 0.22), _m["black"], 1.0, 0.01)
		Kit.label(world, spec[1], UI.f_sans_b, 120, Color(1, 1, 1, 0.9), (cxf * Transform3D(Basis(), Vector3(0.152, 0.02, 0.0))).origin, Vector3(0, yaw + PI / 2.0, 0), 0.0015)
		glow((cxf * Transform3D(Basis(), Vector3(0, 0.2, -0.28))).origin, 0.1, Color(1, 0.1, 0.05, 0.95))
		var op_pos := base + Vector3(sin(yaw), 0, cos(yaw)) * 0.75
		var op := person(rand_look(_rng), op_pos, yaw_to(op_pos, target), "", false)
		op.rest_anim = "operate"


func _lights() -> void:
	env.background_color = Color(0.01, 0.012, 0.02)
	env.ambient_light_color = Color(0.45, 0.5, 0.75)
	env.ambient_light_energy = 0.35
	env.volumetric_fog_density = 0.012
	# parrilla de focos colgada
	for z in [-0.4, 2.0, 4.2]:
		b.box(Transform3D(Basis(), Vector3(0, 4.6, z)), Vector3(9.0, 0.12, 0.12), _m["truss"])
	for k in 6:
		var p := Vector3(-3.0 + k * 1.2, 4.4, 2.0)
		b.cyl(p, 0.11, 0.13, 0.28, _m["black"], Vector3(0.6, 0, 0), 14)
		glow(p + Vector3(0, -0.12, -0.08), 0.35, Color(1, 0.92, 0.8, 0.7))
	# luz principal sobre la entrevistadora (desde detrás del presidente), relleno y contraluces de color
	spot(Vector3(-0.8, 4.4, -0.6), HOST + Vector3(0, 1.2, 0), 5.0, 22.0, Color(1, 0.95, 0.88), true, 10.0)
	spot(Vector3(2.0, 4.4, 2.0), Vector3(0, 1.3, 0.2), 2.5, 30.0, Color(0.95, 0.95, 1.0), false, 10.0)
	spot(Vector3(1.5, 4.0, 5.0), HOST + Vector3(0, 1.4, 0), 3.0, 18.0, Color(0.45, 0.6, 1.0), false, 9.0)
	omni(Vector3(1.0, 2.0, 5.2), 1.6, 6.0, Color(0.45, 0.4, 1.0), false)
	# piloto «EN EL AIRE»
	b.box(Transform3D(Basis(), Vector3(-3.4, 3.3, 6.0)), Vector3(1.0, 0.32, 0.08), _m["black"])
	_onair = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.92, 0.26)
	_onair.mesh = q
	_onair.material_override = Kit.emissive(Color(1, 0.12, 0.1), 3.0)
	world.add_child(_onair)
	_onair.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-3.4, 3.3, 5.955))
	Kit.label(world, "EN EL AIRE", UI.f_sans_b, 64, Color.WHITE, Vector3(-3.4, 3.3, 5.94), Vector3(0, PI, 0), 0.002)


# ------------------------------------------------------------------ acción (la misma que la sala de prensa)

func ask() -> Node3D:
	return interviewer


func stop_asking() -> void:
	interviewer.talking = false


## La entrevistadora reacciona a la respuesta (en el plató no hay fotógrafos)
func react(s: float) -> void:
	interviewer.mood = 0.3 if s >= 4 else (-0.3 if s < 0 else 0.0)


func burst(_n: int) -> void:
	pass
