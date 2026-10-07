extends Node3D
## El pez dorado en su pecera redonda, en 3D: nada en círculos y asoma a comer si se le mima.
## Antes era una estampa plana. El origen es el centro de la base, sobre la mesa.

const Kit := preload("res://scripts/office3d/kit.gd")

const R := 0.1

var body: StaticBody3D
var happy := false
var _fish: Node3D
var _tail_fin: MeshInstance3D
var _water_top: MeshInstance3D
var _t := 0.0
var _rise := 0.0


func build() -> void:
	var wood := Kit.wood("caoba")
	var gold := Kit.gold()
	# peana de madera con filete de latón
	Kit.mesh(self, Kit.sphere_mesh(R + 0.03, 20), wood, Vector3(0, -0.02, 0), Vector3.ZERO, Vector3(1.0, 0.1, 1.0))
	Kit.mesh(self, Kit.torus_mesh(R + 0.025, R + 0.033, 28), gold, Vector3(0, 0.0, 0), Vector3(PI / 2.0, 0, 0))
	# cristal de la pecera: solo la cara que mira a la cámara (si se ven las dos, el cristal
	# se queda casi invisible de tan fino que parece un simple aro de alambre)
	var gm2 := StandardMaterial3D.new()
	gm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm2.albedo_color = Color(0.84, 0.93, 1.0, 0.22)
	gm2.roughness = 0.05
	gm2.metallic_specular = 0.7
	var gm := Kit.mesh(self, Kit.sphere_mesh(R, 24), gm2, Vector3(0, R + 0.01, 0))
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# agua: una esfera algo más pequeña y achatada por arriba (línea de flotación)
	var wm := StandardMaterial3D.new()
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color = Color(0.3, 0.62, 0.66, 0.3)
	wm.roughness = 0.05
	wm.metallic_specular = 0.6
	var water := Kit.mesh(self, Kit.sphere_mesh(R - 0.012, 22), wm, Vector3(0, R + 0.005, 0), Vector3.ZERO, Vector3(1.0, 0.92, 1.0))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.7, 0.9, 0.95, 0.3)
	sm.roughness = 0.0
	sm.metallic_specular = 1.0
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_water_top = Kit.mesh(self, Kit.quad_mesh(Vector2(R * 1.6, R * 1.6)), sm, Vector3(0, R + R * 0.78, 0), Vector3(-PI / 2.0, 0, 0))
	_water_top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# grava en el fondo
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pebble := [Kit.mat(Color("b39b74"), 0.9), Kit.mat(Color("8a7656"), 0.85), Kit.mat(Color("d6c7a4"), 0.8)]
	for i in 26:
		var a := rng.randf_range(0.0, TAU)
		var rr := sqrt(rng.randf()) * (R - 0.03)
		Kit.mesh(self, Kit.sphere_mesh(rng.randf_range(0.004, 0.009), 6), pebble[i % 3], Vector3(cos(a) * rr, R - R * 0.86, sin(a) * rr), Vector3.ZERO, Vector3(1.0, 0.6, 1.0))
	# plantita
	var leaf := Kit.mat(Color("3f8a3a"), 0.6)
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 4:
		var hgt := 0.03 + (i % 2) * 0.012
		var q := Kit.mesh(self, Kit.quad_mesh(Vector2(0.012, hgt)), leaf, Vector3(R * 0.5, R - R * 0.84 + hgt * 0.5, -R * 0.35 + i * 0.012), Vector3(0, i * 0.7, 0.2))
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_fish()
	body = StaticBody3D.new()
	add_child(body)
	Kit.add_shape(body, Kit.shape_box(Vector3(R * 2.3, R * 2.3, R * 2.3)), Vector3(0, R, 0))


func _build_fish() -> void:
	_fish = Node3D.new()
	add_child(_fish)
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color("ff8c1a")
	orange.roughness = 0.35
	orange.emission_enabled = true
	orange.emission = Color("ff8c1a")
	orange.emission_energy_multiplier = 0.25
	var orange_l := Kit.mat(Color("ffb14d"), 0.35)
	Kit.mesh(_fish, Kit.capsule_mesh(0.026, 0.048), orange, Vector3.ZERO, Vector3(0, 0, PI / 2.0))
	for sx in [-1.0, 1.0]:
		Kit.mesh(_fish, Kit.sphere_mesh(0.006, 6), Kit.mat(Color("1a1410"), 0.2), Vector3(0.026, 0.009, sx * 0.019))
	_tail_fin = Kit.mesh(_fish, Kit.quad_mesh(Vector2(0.035, 0.041)), orange_l, Vector3(-0.038, 0, 0), Vector3(0, PI / 2.0, 0))
	Kit.mesh(_fish, Kit.quad_mesh(Vector2(0.025, 0.019)), orange_l, Vector3(0, 0.019, 0), Vector3(0.2, 0, 0))
	for sx2 in [-1.0, 1.0]:
		var fin := Kit.mesh(_fish, Kit.quad_mesh(Vector2(0.019, 0.013)), orange_l, Vector3(0.006, -0.013, sx2 * 0.019), Vector3(0, 0, sx2 * 0.5))
		fin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fish.position = Vector3(0, R + 0.0, R * 0.4)


func update(delta: float) -> void:
	_t += delta
	_rise = move_toward(_rise, 1.0 if happy else 0.0, delta * 1.2)
	var speed := 1.6 if happy else 0.55
	var rad := R * 0.55
	var phase := _t * speed
	var y := R + R * 0.1 + sin(_t * 0.7) * R * 0.1 + _rise * R * 0.5
	var target := Vector3(cos(phase) * rad, y, sin(phase) * rad)
	var prev: Vector3 = _fish.position
	_fish.position = target
	var vdir := target - prev
	if Vector2(vdir.x, vdir.z).length() > 0.00001:
		_fish.rotation.y = lerp_angle(_fish.rotation.y, atan2(vdir.x, vdir.z) + PI / 2.0, minf(1.0, delta * 6.0))
	_fish.rotation.z = sin(_t * 9.0) * 0.12
	_tail_fin.rotation.y = PI / 2.0 + sin(_t * 10.0) * 0.5
	_water_top.position.y = R + R * 0.78 + sin(_t * 1.8) * 0.0015
