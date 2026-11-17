extends "res://scripts/stages3d/stage_3d.gd"
## Noche electoral en la sede del partido: escenario con atril, banderolas del color del partido, globos, militantes
## de pie mirando a una pantalla gigante con el escrutinio en directo (y dos copias en las paredes) y confeti para
## celebrarlo. Realización: plano general desde el fondo, plano cerrado de la pantalla para leer los resultados y,
## al acabar, el presidente sale al atril (con el público celebrando o en silencio).

const W := preload("res://scripts/data/world_data.gd")

const H := 7.0
const X0 := -9.0
const X1 := 9.0
const Z0 := -6.0
const Z1 := 12.0
const STAGE_H := 0.6
const SCREEN_W := 8.0
const SCREEN_C := Vector3(0, 4.2, Z0 + 0.08)
const PODIUM := Vector3(0, STAGE_H, -2.9)

## Aspecto del presidente (lo pone el panel)
var pres_look: Dictionary = {}
## Pantalla gigante con el escrutinio (el panel monta ahí sus gráficos, 1920 × 1080)
var ui_screen: Control
var president: Node3D
var crowd: Array = []
var _team: Array = []
var _confetti: CPUParticles3D
var _party := "MP"
var _col := Color.WHITE
var _phase := 0
var _clock := 0.0
var _done := false
var _m := {}
var _rng := RandomNumberGenerator.new()


func build() -> void:
	_rng.seed = 29
	_party = GS.pres["party"]
	_col = Color(W.PARTIES[_party]["color"])
	_m = {
		"floor": Kit.pbr("parquet", {}, 1.6, 0.5, Color(0.75, 0.72, 0.7), 0.7, 0.0, 0.2),
		"wall": Kit.mat(Color("1d2230"), 0.85),
		"ceiling": Kit.mat(Color("101319"), 0.9),
		"stage": Kit.mat(Color("15171c"), 0.4, 0.2),
		"party": Kit.mat(_col, 0.6),
		"party_glow": Kit.emissive(_col.lightened(0.15), 2.4),
		"white": Kit.mat(Color("f2f2f0"), 0.6),
		"truss": Kit.mat(Color("6c7078"), 0.35, 0.85),
		"black": Kit.mat(Color("0b0c0e"), 0.5, 0.2),
		"wood": Kit.wood("caoba"),
	}
	shade_top = 0.1
	shade_bottom = 0.3
	_hall()
	_stage()
	_big_screens()
	_balloons()
	_crowd()
	_lights()
	b.commit(world)
	_make_confetti()
	# primer plano: desde el fondo de la sala, el público de espaldas y la pantalla al fondo
	cam_pos = Vector3(0.6, 3.4, Z1 - 0.6)
	cam_look = Vector3(0, 3.6, Z0)
	fov_target = 52.0
	cam_speed = 0.8
	sway = 0.03


func _hall() -> void:
	b.cube(Vector3(0, -0.05, (Z0 + Z1) * 0.5), Vector3(X1 - X0, 0.1, Z1 - Z0), _m["floor"])
	b.cube(Vector3(0, H + 0.05, (Z0 + Z1) * 0.5), Vector3(X1 - X0, 0.1, Z1 - Z0), _m["ceiling"])
	b.cube(Vector3(0, H * 0.5, Z0 - 0.05), Vector3(X1 - X0, H, 0.1), _m["wall"])
	b.cube(Vector3(0, H * 0.5, Z1 + 0.05), Vector3(X1 - X0, H, 0.1), _m["wall"])
	for sx in [-1.0, 1.0]:
		b.cube(Vector3(sx * (X1 + 0.05), H * 0.5, (Z0 + Z1) * 0.5), Vector3(0.1, H, Z1 - Z0), _m["wall"])
		# banderolas verticales con el color y las siglas del partido
		for k in 3:
			var z := 3.0 + k * 3.2
			b.cube(Vector3(sx * (X1 - 0.06), 3.6, z), Vector3(0.04, 4.6, 1.3), _m["party"])
			Kit.label(world, W.PARTIES[_party]["short"], UI.f_sans_b, 160, Color.WHITE, Vector3(sx * (X1 - 0.1), 3.9, z), Vector3(0, -sx * PI / 2.0, 0), 0.004)


func _stage() -> void:
	b.cube(Vector3(0, STAGE_H * 0.5, (Z0 + -2.2) * 0.5), Vector3(10.0, STAGE_H, -2.2 - Z0), _m["stage"])
	b.cube(Vector3(0, STAGE_H - 0.02, -2.2), Vector3(10.0, 0.04, 0.05), _m["party_glow"])
	# atril con el logo del partido
	var px := Transform3D(Basis(), PODIUM)
	b.box(px * Transform3D(Basis(), Vector3(0, 0.55, 0)), Vector3(0.7, 1.1, 0.45), _m["wood"], 1.0, 0.03, 2)
	b.box(px * Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 1.14, -0.05)), Vector3(0.76, 0.05, 0.5), _m["wood"], 1.0, 0.02)
	b.box(px * Transform3D(Basis(), Vector3(0, 0.62, 0.23)), Vector3(0.5, 0.36, 0.02), _m["party"])
	Kit.label(world, W.PARTIES[_party]["short"], UI.f_sans_b, 110, Color.WHITE, PODIUM + Vector3(0, 0.62, 0.245), Vector3.ZERO, 0.0025)
	b.segment(PODIUM + Vector3(0, 1.15, 0.0), PODIUM + Vector3(0, 1.38, 0.12), 0.008, Kit.mat(Color("2a2a2a"), 0.4, 0.6))
	# banderas a los lados
	for sx in [-1.0, 1.0]:
		flag_pole(Vector3(sx * 4.7, STAGE_H, -3.4), "valdoria", 0.0 if sx < 0.0 else PI, 3.0)
	# el presidente y su equipo, ocultos hasta el final
	president = person(pres_look, PODIUM + Vector3(0, 0, -0.42), 0.0, "", true, 1)
	president.rest_anim = "lectern"
	president.talk_anim = "lectern_talk"
	president.visible = false
	for spec in [["vice", Vector3(-1.5, STAGE_H, -3.7)], ["jefa", Vector3(1.5, STAGE_H, -3.7)]]:
		if GS.ministers.has(spec[0]):
			var t := person(GS.ministers[spec[0]]["look"], spec[1], 0.0, "", true, 2)
			t.visible = false
			_team.append(t)


## Pantalla gigante (la que monta el panel) y dos copias en las paredes
func _big_screens() -> void:
	ui_screen = screen(Vector2i(1920, 1080), Transform3D(Basis(), SCREEN_C), SCREEN_W, Color(0.02, 0.03, 0.06), 1.15)
	b.box(Transform3D(Basis(), SCREEN_C + Vector3(0, 0, -0.05)), Vector3(SCREEN_W + 0.3, SCREEN_W * 1080.0 / 1920.0 + 0.3, 0.06), _m["black"])
	for sx in [-1.0, 1.0]:
		var p := Vector3(sx * (X1 - 0.08), 4.3, -1.6)
		var xf := Transform3D(Basis(Vector3.UP, -sx * PI / 2.0), p)
		screen_copy(ui_screen, xf, 3.4, 1.1)
		b.box(xf * Transform3D(Basis(), Vector3(0, 0, -0.03)), Vector3(3.55, 2.06, 0.05), _m["black"])


func _balloons() -> void:
	var cols := [_m["party"], _m["white"], Kit.mat(Color("d8b45a"), 0.35, 0.4)]
	for k in 60:
		var p := Vector3(_rng.randf_range(X0 + 0.6, X1 - 0.6), H - _rng.randf_range(0.25, 0.6), _rng.randf_range(-1.0, Z1 - 0.6))
		b.sphere(p, 0.22, cols[k % cols.size()], 10, 7, Vector3(1, 1.15, 1))


## Militantes de pie, mirando al escenario
func _crowd() -> void:
	var rows := 8
	for r in rows:
		var z := 0.4 + r * 0.95
		var n := 11
		for i in n:
			var x := -6.0 + i * 1.2 + _rng.randf_range(-0.3, 0.3) + (0.6 if r % 2 == 1 else 0.0)
			if absf(x) > 7.5 or _rng.randf() < 0.18 + 0.05 * absf(x) / 6.0:
				continue
			var pos := Vector3(x, 0, z + _rng.randf_range(-0.2, 0.2))
			var v := person(rand_look(_rng), pos, PI + _rng.randf_range(-0.25, 0.25), "", r < 2, 3)
			crowd.append(v)
			if crowd.size() >= 46:
				return


func _lights() -> void:
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_color = Color(0.7, 0.62, 0.55)
	env.ambient_light_energy = 0.75
	env.volumetric_fog_density = 0.008
	for z in [-3.0, 2.0, 7.0]:
		b.box(Transform3D(Basis(), Vector3(0, H - 0.6, z)), Vector3(14.0, 0.14, 0.14), _m["truss"])
	spot(Vector3(0, H - 0.7, 1.0), PODIUM + Vector3(0, 1.4, 0), 5.0, 18.0, Color(1, 0.95, 0.88), true, 12.0)
	for sx in [-1.0, 1.0]:
		spot(Vector3(sx * 4.0, H - 0.7, -3.0), Vector3(sx * 1.0, STAGE_H, -3.2), 3.0, 30.0, _col.lightened(0.3), false, 10.0)
		spot(Vector3(sx * 5.0, H - 0.7, 7.0), Vector3(sx * 1.5, 0.0, 3.0), 2.4, 40.0, Color(1, 0.88, 0.75), false, 14.0)
	omni(SCREEN_C + Vector3(0, 0, 1.5), 1.2, 8.0, Color(0.6, 0.7, 1.0), false)
	# focos desde el escenario hacia el público
	for sx in [-1.0, 1.0]:
		spot(Vector3(sx * 3.0, H - 0.7, -2.0), Vector3(sx * 2.0, 1.2, 4.5), 2.6, 45.0, Color(1, 0.9, 0.78), false, 16.0)
	for k in 9:
		glow(Vector3(-6.0 + k * 1.5, H - 0.75, 2.0), 0.3, Color(1, 0.9, 0.75, 0.6))


func _make_confetti() -> void:
	_confetti = CPUParticles3D.new()
	_confetti.amount = 700
	_confetti.lifetime = 7.0
	_confetti.emitting = false
	_confetti.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_confetti.emission_box_extents = Vector3(7.5, 0.2, 5.0)
	_confetti.direction = Vector3(0, -1, 0)
	_confetti.spread = 25.0
	_confetti.gravity = Vector3(0, -1.1, 0)
	_confetti.initial_velocity_min = 0.2
	_confetti.initial_velocity_max = 1.0
	_confetti.angular_velocity_min = -360.0
	_confetti.angular_velocity_max = 360.0
	_confetti.particle_flag_rotate_y = true
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.04)
	var mt := StandardMaterial3D.new()
	mt.vertex_color_use_as_albedo = true
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mt.roughness = 0.6
	q.material = mt
	_confetti.mesh = q
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	g.colors = PackedColorArray([_col, Color("f2f2f0"), Color("e8c25a"), _col.lightened(0.3)])
	_confetti.color_initial_ramp = g
	world.add_child(_confetti)
	_confetti.position = Vector3(0, H - 0.4, 3.5)


## Plano cerrado de la pantalla (para leer el escrutinio)
func _screen_shot() -> void:
	cam_pos = Vector3(0, 4.15, 4.2)
	cam_look = SCREEN_C
	fov_target = 31.0
	cam_speed = 1.2
	sway = 0.012


## Resultado: el presidente sale al atril; si ha ganado, el público lo celebra y cae confeti
func finish(won: bool) -> void:
	_done = true
	president.visible = true
	for t in _team:
		t.visible = true
		gesture(t, "clap" if won else "", 6.0 if won else 0.0)
	president.talking = true
	president.mood = 0.8 if won else -0.4
	get_tree().create_timer(4.5).timeout.connect(func():
		if is_instance_valid(president):
			president.talking = false)
	for v in crowd:
		if won:
			gesture(v, "cheer" if _rng.randf() < 0.55 else "clap", randf_range(4.0, 9.0))
			v.mood = 0.8
		else:
			v.mood = -0.6
	if won:
		_confetti.emitting = true
		Sfx.play("cheer", -2.0)
		Sfx.play("applause", -4.0)
	# desde el público, hacia el atril
	cam_pos = Vector3(2.6, 2.25, 2.6)
	cam_look = PODIUM + Vector3(0, 1.45, -0.3)
	fov_target = 40.0
	cam_speed = 1.6
	cut()
	sway = 0.02


func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	if not _done and _phase == 0 and _clock > 3.6:
		_phase = 1
		_screen_shot()
