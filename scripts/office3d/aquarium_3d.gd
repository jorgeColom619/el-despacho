extends Node3D
## Pecera 3D de Trámite, la tortuga: cristal con borde de latón sobre peana de madera, agua, grava, roca
## para tomar el sol, plantas que se mecen y burbujas. La tortuga nada de lado a lado; al mimarla rema más
## deprisa, sube a asomar la cabeza y echa burbujas. El origen es el centro de la base, sobre la mesa.

const Kit := preload("res://scripts/office3d/kit.gd")
const Batch := Kit.Batch

const W := 0.34
const D := 0.2
const GLASS_H := 0.24
const PLINTH := 0.03
const WATER_H := 0.165
const GRAVEL := 0.022

var body: StaticBody3D
var happy := false
var turtle: Node3D
var _head: Node3D
var _flippers: Array = []
var _plants: Array = []
var _mouth_bubbles: CPUParticles3D
var _water_top: MeshInstance3D
var _t := 0.0
var _rise := 0.0
var _yaw := 0.0
var _paddle := 0.0
var _prev := Vector3.ZERO


func build() -> void:
	var b := Batch.new()
	var gold := Kit.gold()
	var wood := Kit.wood("caoba")
	# peana de madera con filete de latón
	b.cube(Vector3(0, PLINTH * 0.5, 0), Vector3(W + 0.03, PLINTH, D + 0.03), wood, Vector3.ZERO, 1.0, 0.004, 2)
	b.cube(Vector3(0, PLINTH - 0.002, 0), Vector3(W + 0.034, 0.004, D + 0.034), gold)
	b.cube(Vector3(0, PLINTH * 0.5, (D + 0.03) * 0.5 + 0.001), Vector3(0.09, 0.016, 0.002), gold)
	# marco de latón: aristas verticales y borde superior
	var y0 := PLINTH
	var y1 := PLINTH + GLASS_H
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.cube(Vector3(sx * W * 0.5, (y0 + y1) * 0.5, sz * D * 0.5), Vector3(0.008, GLASS_H, 0.008), gold)
	for sz2 in [-1.0, 1.0]:
		b.cube(Vector3(0, y1 - 0.004, sz2 * D * 0.5), Vector3(W + 0.008, 0.008, 0.008), gold)
		b.cube(Vector3(0, y0 + 0.004, sz2 * D * 0.5), Vector3(W + 0.008, 0.008, 0.008), gold)
	for sx2 in [-1.0, 1.0]:
		b.cube(Vector3(sx2 * W * 0.5, y1 - 0.004, 0), Vector3(0.008, 0.008, D + 0.008), gold)
		b.cube(Vector3(sx2 * W * 0.5, y0 + 0.004, 0), Vector3(0.008, 0.008, D + 0.008), gold)
	# grava, guijarros y roca
	b.cube(Vector3(0, y0 + GRAVEL * 0.5, 0), Vector3(W - 0.006, GRAVEL, D - 0.006), Kit.mat(Color("b39b74"), 0.95))
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var pebble := [Kit.mat(Color("8a7656"), 0.8), Kit.mat(Color("d6c7a4"), 0.7), Kit.mat(Color("6e6a62"), 0.8)]
	for i in 34:
		var p := Vector3(rng.randf_range(-W * 0.46, W * 0.46), y0 + GRAVEL, rng.randf_range(-D * 0.44, D * 0.44))
		b.sphere(p, rng.randf_range(0.004, 0.008), pebble[i % 3], 7, 4, Vector3(1.0, 0.6, 1.0))
	var rock := Kit.mat(Color("6b645b"), 0.92)
	# roca al fondo a la derecha (la tortuga nada por delante)
	b.sphere(Vector3(W * 0.3, y0 + GRAVEL + 0.06, -D * 0.2), 0.075, rock, 12, 8, Vector3(0.95, 1.25, 0.7))
	b.sphere(Vector3(W * 0.17, y0 + GRAVEL + 0.02, -D * 0.28), 0.04, rock, 10, 6, Vector3(1.2, 0.8, 0.9))
	b.sphere(Vector3(-W * 0.36, y0 + GRAVEL + 0.012, -D * 0.25), 0.022, rock, 9, 5)
	b.commit(self)
	# cristal (las cuatro caras) y agua
	var glass := Kit.glass(Color(0.82, 0.92, 1.0, 0.1))
	for f in [[Vector3(0, 0, D * 0.5), Vector2(W, GLASS_H), 0.0], [Vector3(0, 0, -D * 0.5), Vector2(W, GLASS_H), PI],
			[Vector3(W * 0.5, 0, 0), Vector2(D, GLASS_H), PI * 0.5], [Vector3(-W * 0.5, 0, 0), Vector2(D, GLASS_H), -PI * 0.5]]:
		var q := Kit.mesh(self, Kit.quad_mesh(f[1]), glass, (f[0] as Vector3) + Vector3(0, (y0 + y1) * 0.5, 0), Vector3(0, f[2], 0))
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wm := StandardMaterial3D.new()
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color = Color(0.3, 0.62, 0.66, 0.22)
	wm.roughness = 0.05
	wm.metallic_specular = 0.7
	var water := MeshInstance3D.new()
	var wb := BoxMesh.new()
	wb.size = Vector3(W - 0.006, WATER_H, D - 0.006)
	water.mesh = wb
	water.material_override = wm
	water.position = Vector3(0, y0 + WATER_H * 0.5, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.7, 0.9, 0.95, 0.25)
	sm.roughness = 0.0
	sm.metallic_specular = 1.0
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_water_top = Kit.mesh(self, Kit.quad_mesh(Vector2(W - 0.008, D - 0.008)), sm, Vector3(0, y0 + WATER_H + 0.001, 0), Vector3(-PI * 0.5, 0, 0))
	_water_top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_plants()
	_build_turtle()
	_build_bubbles()
	body = StaticBody3D.new()
	add_child(body)
	Kit.add_shape(body, Kit.shape_box(Vector3(W + 0.03, y1 + 0.01, D + 0.03)), Vector3(0, (y1 + 0.01) * 0.5, 0))


func _build_plants() -> void:
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color("3f8a3a")
	leaf.roughness = 0.6
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 5:
		var pivot := Node3D.new()
		pivot.position = Vector3(-W * 0.4 + (i % 3) * 0.018, PLINTH + GRAVEL, -D * 0.22 - floorf(i / 3.0) * 0.03)
		add_child(pivot)
		var hgt := 0.1 + (i % 3) * 0.025
		var q := Kit.mesh(pivot, Kit.quad_mesh(Vector2(0.012, hgt)), leaf, Vector3(0, hgt * 0.5, 0), Vector3(0, i * 0.8, 0))
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_plants.append(pivot)


## Escudos del caparazón: placas poligonales oscuras sobre verde, con vetas
func _shell_tex() -> ImageTexture:
	if Kit._tex_cache.has("turtle_shell"):
		return Kit._tex_cache["turtle_shell"]
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var cells := [Vector2(32, 32), Vector2(32, 10), Vector2(32, 54), Vector2(12, 22), Vector2(52, 22), Vector2(12, 44), Vector2(52, 44)]
	for y in 64:
		for x in 64:
			var p := Vector2(x, y)
			var d1 := 999.0
			var d2 := 999.0
			for c in cells:
				var d := p.distance_to(c)
				if d < d1:
					d2 = d1
					d1 = d
				elif d < d2:
					d2 = d
			var edge := clampf((d2 - d1) / 3.0, 0.0, 1.0)
			var base := Color("5e8a3a").lerp(Color("3d6227"), clampf(d1 / 18.0, 0.0, 1.0))
			base = base.lerp(Color("8aa654"), 0.25 * sin(d1 * 1.3) * 0.5 + 0.1)
			img.set_pixel(x, y, Color("27381a").lerp(base, edge))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	Kit._tex_cache["turtle_shell"] = t
	return t


func _build_turtle() -> void:
	turtle = Node3D.new()
	add_child(turtle)
	var skin := Kit.mat(Color("6f8d45"), 0.55)
	var shell := StandardMaterial3D.new()
	shell.albedo_texture = _shell_tex()
	shell.roughness = 0.35
	shell.clearcoat_enabled = true
	shell.clearcoat = 0.6
	var hemi := SphereMesh.new()
	hemi.radius = 0.033
	hemi.height = 0.033
	hemi.is_hemisphere = true
	hemi.radial_segments = 24
	hemi.rings = 8
	Kit.mesh(turtle, hemi, shell, Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.0, 0.78, 1.28))
	Kit.mesh(turtle, Kit.sphere_mesh(0.032, 16), Kit.mat(Color("d4bf7a"), 0.6), Vector3(0, -0.001, 0), Vector3.ZERO, Vector3(0.95, 0.14, 1.2))
	Kit.mesh(turtle, Kit.torus_mesh(0.031, 0.035, 24), Kit.mat(Color("40602a"), 0.5), Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.0, 0.4, 1.28))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.004, -0.044)
	turtle.add_child(_head)
	Kit.mesh(_head, Kit.capsule_mesh(0.007, 0.022), skin, Vector3(0, 0, 0.004), Vector3(PI * 0.5, 0, 0))
	Kit.mesh(_head, Kit.sphere_mesh(0.011, 12), skin, Vector3(0, 0.002, -0.012), Vector3.ZERO, Vector3(0.9, 0.85, 1.25))
	var eye := Kit.mat(Color("101010"), 0.15)
	for sx in [-1.0, 1.0]:
		Kit.mesh(_head, Kit.sphere_mesh(0.0024, 8), eye, Vector3(sx * 0.0085, 0.005, -0.016))
	_mouth_bubbles = CPUParticles3D.new()
	_mouth_bubbles.position = Vector3(0, 0.004, -0.026)
	_mouth_bubbles.emitting = false
	_head.add_child(_mouth_bubbles)
	_bubble_setup(_mouth_bubbles, 12, 0.9)
	for spec in [[Vector3(-0.031, -0.002, -0.022), -1.0, 1.0], [Vector3(0.031, -0.002, -0.022), 1.0, 1.0], [Vector3(-0.026, -0.002, 0.03), -1.0, 0.7], [Vector3(0.026, -0.002, 0.03), 1.0, 0.7]]:
		var pv := Node3D.new()
		pv.position = spec[0]
		turtle.add_child(pv)
		var s: float = spec[2]
		Kit.mesh(pv, Kit.sphere_mesh(0.012, 10), skin, Vector3(spec[1] * 0.011 * s, 0, 0), Vector3.ZERO, Vector3(1.5 * s, 0.25, 0.75 * s))
		_flippers.append({"n": pv, "side": spec[1], "front": spec[2] > 0.9})
	var tail := CylinderMesh.new()
	tail.top_radius = 0.0
	tail.bottom_radius = 0.004
	tail.height = 0.016
	tail.radial_segments = 6
	Kit.mesh(turtle, tail, skin, Vector3(0, 0, 0.047), Vector3(-PI * 0.5, 0, 0))
	turtle.position = Vector3(0, PLINTH + GRAVEL + 0.05, -0.03)
	turtle.scale = Vector3.ONE * 1.35


func _bubble_setup(p: CPUParticles3D, amount: int, lifetime: float) -> void:
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 8.0
	p.gravity = Vector3(0, 0.05, 0)
	p.initial_velocity_min = 0.06
	p.initial_velocity_max = 0.1
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var bm := StandardMaterial3D.new()
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(0.9, 0.97, 1.0, 0.45)
	bm.roughness = 0.0
	bm.metallic_specular = 1.0
	var s := Kit.sphere_mesh(0.0028, 8)
	s.material = bm
	p.mesh = s


func _build_bubbles() -> void:
	var stone := Kit.mat(Color("8c8f94"), 0.9)
	Kit.mesh(self, Kit.sphere_mesh(0.008, 8), stone, Vector3(-W * 0.32, PLINTH + GRAVEL + 0.004, -D * 0.28), Vector3.ZERO, Vector3(1.4, 0.6, 1.0))
	var p := CPUParticles3D.new()
	p.position = Vector3(-W * 0.32, PLINTH + GRAVEL + 0.01, -D * 0.28)
	add_child(p)
	# suben hasta la superficie: velocidad × vida ≈ altura del agua
	_bubble_setup(p, 10, 1.7)


func update(delta: float) -> void:
	_t += delta
	_paddle += delta * (9.0 if happy else 3.2)
	# trayectoria: va y viene a lo ancho, algo de vaivén en profundidad; feliz, sube a asomar la cabeza
	_rise = move_toward(_rise, 1.0 if happy else 0.0, delta * 0.8)
	var base_y := PLINTH + GRAVEL + 0.05 + sin(_t * 0.8) * 0.012
	var top_y := PLINTH + WATER_H - 0.012
	var phase := _t * 0.42 * (1.0 + 0.5 * _rise)
	var target := Vector3(sin(phase) * (W * 0.5 - 0.075), lerpf(base_y, top_y, _rise), 0.035 + sin(phase * 0.7 + 1.0) * 0.015)
	turtle.position = target
	var v := target - _prev
	_prev = target
	if Vector2(v.x, v.z).length() > 0.00002:
		_yaw = lerp_angle(_yaw, atan2(-v.x, -v.z), minf(1.0, delta * 3.0))
	turtle.rotation = Vector3(-_rise * 0.25, _yaw, sin(_paddle * 0.5) * 0.06)
	for f in _flippers:
		var n: Node3D = f["n"]
		var amp := 0.55 if f["front"] else 0.35
		var ph := 0.0 if f["front"] else 1.4
		n.rotation = Vector3(0, sin(_paddle + ph) * amp * f["side"], sin(_paddle + ph) * 0.4 * f["side"])
	_head.rotation = Vector3(0.25 * _rise + sin(_t * 1.3) * 0.05, sin(_t * 0.9) * 0.2, 0)
	_mouth_bubbles.emitting = happy
	for i in _plants.size():
		(_plants[i] as Node3D).rotation = Vector3(sin(_t * 1.1 + i) * 0.12, 0, sin(_t * 0.8 + i * 1.7) * 0.15)
	_water_top.position.y = PLINTH + WATER_H + 0.001 + sin(_t * 2.0) * 0.0006
