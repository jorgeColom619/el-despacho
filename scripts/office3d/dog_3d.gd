extends Node3D
## Tribuno, el perro, en 3D: sentado junto a la mesa, jadea y menea el rabo. Antes era una estampa
## plana. El origen es el punto donde se apoya (el suelo).

const Kit := preload("res://scripts/office3d/kit.gd")

var body: StaticBody3D
var happy := false
var _visual: Node3D
var _head: Node3D
var _tail: Node3D
var _tail_beads: Array = []
var _tongue: MeshInstance3D
var _ears: Array = []
var _t := 0.0


func build() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var fur := Kit.mat(Color("a8743e"), 0.8)
	var fur_d := Kit.mat(Color("7a5228"), 0.8)
	var cream := Kit.mat(Color("e8cfa8"), 0.7)
	var black := Kit.mat(Color("1a1410"), 0.25)
	var pink := Kit.mat(Color("e06a7a"), 0.45)
	# cuerpo sentado: torso erguido, algo más estrecho de cintura
	Kit.mesh(_visual, Kit.capsule_mesh(0.1, 0.17), fur, Vector3(0, 0.155, -0.01), Vector3(0.05, 0, 0))
	Kit.mesh(_visual, Kit.capsule_mesh(0.085, 0.07), cream, Vector3(0, 0.12, 0.07), Vector3.ZERO, Vector3(0.85, 1.0, 0.7))
	# ancas apoyadas en el suelo, a los lados
	for sx0 in [-1.0, 1.0]:
		Kit.mesh(_visual, Kit.sphere_mesh(0.075, 10), fur_d, Vector3(sx0 * 0.075, 0.05, -0.08), Vector3.ZERO, Vector3(1.0, 0.75, 1.1))
	# patas delanteras, rectas, apoyadas en el suelo por delante
	for sx in [-1.0, 1.0]:
		Kit.mesh(_visual, Kit.capsule_mesh(0.026, 0.19), fur, Vector3(sx * 0.052, 0.095, 0.095))
		Kit.mesh(_visual, Kit.sphere_mesh(0.03, 8), fur_d, Vector3(sx * 0.052, -0.002, 0.1), Vector3.ZERO, Vector3(1.0, 0.55, 1.3))
	# cabeza, con hocico y orejas caídas (pivote propio para menearla al idle)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.32, 0.05)
	_visual.add_child(_head)
	Kit.mesh(_head, Kit.sphere_mesh(0.072, 14), fur, Vector3.ZERO)
	var muzzle := Kit.mesh(_head, Kit.capsule_mesh(0.034, 0.03), cream, Vector3(0, -0.018, 0.065), Vector3(PI / 2.0, 0, 0))
	muzzle.scale = Vector3(1.0, 1.0, 1.15)
	Kit.mesh(_head, Kit.sphere_mesh(0.014, 8), black, Vector3(0, -0.01, 0.1))
	_tongue = Kit.mesh(_head, Kit.capsule_mesh(0.009, 0.02), pink, Vector3(0, -0.045, 0.075), Vector3(PI / 2.0 + 0.3, 0, 0))
	for sx2 in [-1.0, 1.0]:
		Kit.mesh(_head, Kit.sphere_mesh(0.011, 8), black, Vector3(sx2 * 0.032, 0.012, 0.058), Vector3.ZERO, Vector3(1.0, 1.0, 0.6))
		var ear := Node3D.new()
		ear.position = Vector3(sx2 * 0.065, 0.03, -0.01)
		ear.rotation = Vector3(0, 0, sx2 * 0.15)
		_head.add_child(ear)
		var e := Kit.mesh(ear, Kit.capsule_mesh(0.026, 0.07), fur_d, Vector3(0, -0.04, 0), Vector3(0.25, 0, 0))
		e.scale = Vector3(0.55, 1.0, 1.0)
		_ears.append(ear)
	# cola: una hilera de "cuentas" que se curva hacia arriba, no un pincho recto
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.14, -0.145)
	_visual.add_child(_tail)
	for i in 7:
		var tt := float(i) / 6.0
		var ang := 0.3 + tt * 1.75
		var p := Vector3(0, sin(ang) * 0.13, -cos(ang) * 0.1 + 0.03)
		var bd := Kit.mesh(_tail, Kit.sphere_mesh(lerpf(0.026, 0.009, tt), 8), fur, p)
		_tail_beads.append({"n": bd, "base": p, "t": tt})
	body = StaticBody3D.new()
	add_child(body)
	Kit.add_shape(body, Kit.shape_box(Vector3(0.32, 0.36, 0.38)), Vector3(0, 0.17, -0.02))


func update(delta: float) -> void:
	_t += delta
	var wag := sin(_t * (7.0 if happy else 2.2)) * (0.6 if happy else 0.22)
	_tail.rotation = Vector3(0, wag, 0)
	_head.rotation = Vector3(0, sin(_t * 0.8) * 0.12, sin(_t * 1.6) * 0.04)
	for i in _ears.size():
		var side := -1.0 if i == 0 else 1.0
		(_ears[i] as Node3D).rotation = Vector3(0, 0, side * 0.15 + sin(_t * 2.2 + i) * 0.05)
	_tongue.visible = happy
	if happy:
		_tongue.scale = Vector3.ONE * (1.0 + sin(_t * 10.0) * 0.1)
	var pant := absf(sin(_t * (9.0 if happy else 2.0))) * (0.02 if happy else 0.008)
	_visual.scale = Vector3(1.0 + pant * 0.4, 1.0 + pant, 1.0 + pant * 0.4)
