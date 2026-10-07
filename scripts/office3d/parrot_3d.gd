extends Node3D
## Senador, el loro, posado en lo alto del reloj de pie: cuerpo, alas, cola y cabeza en 3D (antes
## era una estampa plana). Se balancea posado y, al mimarlo, ladea la cabeza y aletea.

const Kit := preload("res://scripts/office3d/kit.gd")
const Batch := Kit.Batch

var body: StaticBody3D
var happy := false
var _visual: Node3D
var _head: Node3D
var _wings: Array = []
var _t := 0.0


func build() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var green := Kit.mat(Color("2fae4a"), 0.55)
	var green_d := Kit.mat(Color("228038"), 0.55)
	var blue := Kit.mat(Color("2a7ad0"), 0.5)
	var red := Kit.mat(Color("d8322e"), 0.4)
	var yellow := Kit.mat(Color("f2d24a"), 0.3, 0.3)
	var black := Kit.mat(Color("101010"), 0.2)
	# cuerpo y cola
	Kit.mesh(_visual, Kit.capsule_mesh(0.028, 0.08), green, Vector3(0, 0.042, 0.03), Vector3(0.35, 0, 0))
	var tail := CylinderMesh.new()
	tail.top_radius = 0.0
	tail.bottom_radius = 0.018
	tail.height = 0.09
	tail.radial_segments = 8
	Kit.mesh(_visual, tail, green_d, Vector3(0, 0.014, -0.07), Vector3(-PI * 0.38, 0, 0))
	# alas, aplanadas a cada lado (pivote propio para el aleteo)
	for side in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(side * 0.026, 0.057, 0.02)
		_visual.add_child(w)
		Kit.mesh(w, Kit.capsule_mesh(0.016, 0.065), blue, Vector3(0, -0.02, -0.012), Vector3(0.55, 0, 0), Vector3(1.0, 1.0, 0.55))
		_wings.append(w)
	# cabeza: pivote propio para ladearla
	_head = Node3D.new()
	_head.position = Vector3(0, 0.09, 0.055)
	_visual.add_child(_head)
	Kit.mesh(_head, Kit.sphere_mesh(0.024, 14), red, Vector3.ZERO)
	Kit.mesh(_head, Kit.sphere_mesh(0.023, 12), green, Vector3(0, -0.012, 0.012), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
	var beak := CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.012
	beak.height = 0.02
	beak.radial_segments = 10
	Kit.mesh(_head, beak, yellow, Vector3(0, -0.012, 0.03), Vector3(PI / 2.0, 0, 0))
	var eye_white := Kit.mat(Color("f5f3ea"), 0.2)
	for sx in [-1.0, 1.0]:
		Kit.mesh(_head, Kit.sphere_mesh(0.0065, 8), eye_white, Vector3(sx * 0.017, 0.005, 0.016))
		Kit.mesh(_head, Kit.sphere_mesh(0.0035, 6), black, Vector3(sx * 0.0185, 0.005, 0.019))
	# patas, agarradas a la cúpula del reloj
	for sx2 in [-1.0, 1.0]:
		Kit.mesh(_visual, Kit.capsule_mesh(0.004, 0.018), yellow, Vector3(sx2 * 0.012, 0.0, 0.03))
	body = StaticBody3D.new()
	add_child(body)
	Kit.add_shape(body, Kit.shape_box(Vector3(0.22, 0.2, 0.18)), Vector3(0, 0.05, 0))


func update(delta: float) -> void:
	_t += delta
	var bob := sin(_t * 2.2) * 0.006 + (sin(_t * 16.0) * 0.01 if happy else 0.0)
	_visual.position.y = bob
	_head.rotation = Vector3(0, sin(_t * 1.1) * 0.12, (sin(_t * 1.7) * 0.08) + (sin(_t * 9.0) * 0.18 if happy else 0.0))
	var flap := (absf(sin(_t * 14.0)) * 0.9) if happy else (0.05 + sin(_t * 1.4) * 0.03)
	for i in _wings.size():
		var side := -1.0 if i == 0 else 1.0
		(_wings[i] as Node3D).rotation = Vector3(0, 0, side * flap)
