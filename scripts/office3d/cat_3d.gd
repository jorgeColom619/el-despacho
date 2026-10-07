extends Node3D
## Decreto, el gato, en 3D: sentado sobre la mesa, se lame una pata y mueve la cola. Antes era una
## estampa plana. El origen es el punto donde se apoya (la mesa).

const Kit := preload("res://scripts/office3d/kit.gd")

var body: StaticBody3D
var happy := false
var _visual: Node3D
var _tail_beads: Array = []
var _ears: Array = []
var _t := 0.0
var _breathe := 0.0


func build() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var fur := Kit.mat(Color("c98a4b"), 0.75)
	var fur_d := Kit.mat(Color("8a5a2c"), 0.75)
	var pink := Kit.mat(Color("d46a6a"), 0.4)
	var green := Kit.mat(Color("2a8a3a"), 0.25)
	var dark := Kit.mat(Color("18120d"), 0.3)
	# cuerpo sentado: un bulto ovalado, compacto y redondeado ("pan de gato")
	Kit.mesh(_visual, Kit.capsule_mesh(0.08, 0.06), fur, Vector3(0, 0.088, 0), Vector3(0.1, 0, 0))
	# pecho/pechera algo más clara, por delante
	Kit.mesh(_visual, Kit.sphere_mesh(0.054, 12), fur, Vector3(0, 0.09, 0.045), Vector3.ZERO, Vector3(0.85, 1.0, 0.7))
	# patas delanteras, cortas y juntas por delante
	for sx in [-1.0, 1.0]:
		Kit.mesh(_visual, Kit.capsule_mesh(0.019, 0.045), fur_d, Vector3(sx * 0.03, 0.03, 0.062))
		Kit.mesh(_visual, Kit.sphere_mesh(0.021, 8), fur_d, Vector3(sx * 0.03, 0.004, 0.068), Vector3.ZERO, Vector3(1.0, 0.6, 1.2))
	# cabeza, con hocico y orejas (pivote propio para que gire un poco al idle)
	var head := Node3D.new()
	head.position = Vector3(0, 0.198, 0.03)
	_visual.add_child(head)
	Kit.mesh(head, Kit.sphere_mesh(0.05, 14), fur, Vector3.ZERO)
	Kit.mesh(head, Kit.sphere_mesh(0.026, 10), fur, Vector3(0, -0.01, 0.042), Vector3.ZERO, Vector3(1.0, 0.8, 0.9))
	Kit.mesh(head, Kit.sphere_mesh(0.006, 6), pink, Vector3(0, -0.015, 0.064))
	for sx2 in [-1.0, 1.0]:
		Kit.mesh(head, Kit.sphere_mesh(0.009, 8), green, Vector3(sx2 * 0.023, 0.005, 0.044), Vector3.ZERO, Vector3(1.0, 1.0, 0.6))
		var ear := Node3D.new()
		ear.position = Vector3(sx2 * 0.032, 0.042, -0.005)
		ear.rotation = Vector3(0, 0, sx2 * 0.35)
		head.add_child(ear)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.02
		cone.height = 0.034
		cone.radial_segments = 8
		Kit.mesh(ear, cone, fur, Vector3(0, 0.017, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.45))
		Kit.mesh(ear, cone, dark, Vector3(0, 0.015, 0.003), Vector3.ZERO, Vector3(0.6, 0.72, 0.3))
		_ears.append(ear)
	# cola: una hilera de "cuentas" que se curva por detrás y a un lado
	for i in 10:
		var tt := float(i) / 9.0
		var ang := tt * 1.9
		var p := Vector3(sin(ang) * 0.1, 0.08 + tt * 0.07, -0.075 - cos(ang) * 0.02 + tt * 0.02)
		var bd := Kit.mesh(_visual, Kit.sphere_mesh(lerpf(0.026, 0.01, tt), 8), fur_d if i % 3 == 0 else fur, p)
		_tail_beads.append({"n": bd, "base": p, "t": tt})
	body = StaticBody3D.new()
	add_child(body)
	Kit.add_shape(body, Kit.shape_box(Vector3(0.22, 0.22, 0.26)), Vector3(0, 0.1, -0.02))


func update(delta: float) -> void:
	_t += delta
	_breathe = sin(_t * 2.6) * 0.012
	_visual.scale = Vector3(1.0 + _breathe * 0.5, 1.0 + _breathe, 1.0 + _breathe * 0.5)
	var wag := sin(_t * (5.0 if happy else 1.4)) * (0.35 if happy else 0.12)
	for b in _tail_beads:
		var base: Vector3 = b["base"]
		var t: float = b["t"]
		(b["n"] as Node3D).position = base + Vector3(sin(_t * 2.0 + t * 3.0) * 0.006 * t, 0, cos(wag * t * 2.0) * 0.012 * t)
	var twitch := sin(_t * 1.3) * 0.08
	for i in _ears.size():
		var side := -1.0 if i == 0 else 1.0
		(_ears[i] as Node3D).rotation = Vector3(twitch * 0.5, 0, side * 0.35 + twitch * (1.0 if happy else 0.3))
