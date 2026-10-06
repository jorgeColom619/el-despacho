extends Node3D
## Objeto interactivo del despacho 3D: brilla al apuntarlo, vibra (o salta, si es físico) cuando suena
## y muestra una insignia flotante. Mantiene la misma interfaz que el objeto 2D del despacho
## (title, status, badge, ringing, pulse, modulate...) para que la lógica del despacho no cambie.

signal activated

const Kit := preload("res://scripts/office3d/kit.gd")
const GLOW := preload("res://shaders/glow3d.gdshader")
const DIM := preload("res://shaders/dim3d.gdshader")

static var _dim_mat: ShaderMaterial

var key := ""
var title := ""
var status := ""
var badge := ""
var badge_color := UI.RED
var ringing := false
var pulse := false
var glow_color := Color(1.0, 0.85, 0.5)
var enabled := true
var animated := false
var hover := false
var locked := false
## Compatibilidad con el despacho 2D: un tono gris indica que el objeto aún no está disponible
var modulate := Color.WHITE:
	set(v):
		modulate = v
		locked = v.r < 0.9
## Cuerpo que recibe el rayo de la mira (estático o rígido)
var body: CollisionObject3D
## Nodo visual que tiembla al sonar (objetos fijos)
var shake_node: Node3D
var badge_height := 0.3
## Se llama cuando el despacho pide redibujar (texturas de periódico, calendario...)
var redraw: Callable
var _hv := 0.0
var _t := 0.0
var _meshes: Array = []
var _glow: ShaderMaterial
var _cur_overlay: Material
var _badge_root: Node3D
var _badge_lbl: Label3D
var _badge_disc: Sprite3D
var _shake_base := Vector3.ZERO
var _kick := 0.0


func setup(b: CollisionObject3D, shake: Node3D = null) -> void:
	body = b
	shake_node = shake
	if shake_node != null:
		_shake_base = shake_node.position
	b.set_meta("obj", self)
	collect(b)


## Añade al resaltado todas las mallas bajo `n` (y marca sus cuerpos para la mira)
func collect(n: Node) -> void:
	if n is MeshInstance3D:
		_meshes.append(n)
	if n is CollisionObject3D and not n.has_meta("obj"):
		n.set_meta("obj", self)
	for c in n.get_children():
		if c != self:
			collect(c)


func _ready() -> void:
	_glow = ShaderMaterial.new()
	_glow.shader = GLOW
	_glow.set_shader_parameter("glow_color", glow_color)
	if _dim_mat == null:
		_dim_mat = ShaderMaterial.new()
		_dim_mat.shader = DIM
	_badge_root = Node3D.new()
	_badge_root.top_level = true
	add_child(_badge_root)
	_badge_disc = Sprite3D.new()
	_badge_disc.texture = Kit.disc_tex()
	_badge_disc.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge_disc.fixed_size = true
	_badge_disc.no_depth_test = true
	_badge_disc.pixel_size = 0.00055
	_badge_disc.shaded = false
	_badge_disc.render_priority = 10
	_badge_root.add_child(_badge_disc)
	_badge_lbl = Label3D.new()
	_badge_lbl.font = UI.f_sans_b
	_badge_lbl.font_size = 26
	_badge_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge_lbl.fixed_size = true
	_badge_lbl.no_depth_test = true
	_badge_lbl.pixel_size = 0.00055
	_badge_lbl.outline_size = 0
	_badge_lbl.render_priority = 11
	_badge_lbl.modulate = Color.WHITE
	_badge_root.add_child(_badge_lbl)
	_badge_root.visible = false


func queue_redraw() -> void:
	if redraw.is_valid():
		redraw.call()


func _process(delta: float) -> void:
	_t += delta
	var target := 1.0 if hover else 0.0
	_hv = move_toward(_hv, target, delta * 6.0)
	var amount := _hv * 0.75
	if ringing or pulse:
		amount = maxf(amount, 0.22 + 0.2 * sin(_t * 6.0))
	var want: Material = null
	if amount > 0.01:
		want = _glow
		_glow.set_shader_parameter("amount", amount)
		_glow.set_shader_parameter("glow_color", glow_color)
	elif locked:
		want = _dim_mat
	if want != _cur_overlay:
		_cur_overlay = want
		for m in _meshes:
			if is_instance_valid(m):
				(m as MeshInstance3D).material_overlay = want
	# insignia
	_badge_root.visible = badge != ""
	if badge != "" and body != null:
		_badge_root.global_position = body.global_position + Vector3(0, badge_height + 0.02 * sin(_t * 5.0), 0)
		_badge_lbl.text = badge
		_badge_disc.modulate = badge_color
		var sc := 1.0 + 0.1 * sin(_t * 5.0)
		_badge_disc.scale = Vector3.ONE * sc
	# vibración al sonar
	var ph := fmod(_t, 1.0)
	var shaking := ringing and ph < 0.55
	if body is RigidBody3D:
		if shaking:
			_kick -= delta
			if _kick <= 0.0:
				_kick = 0.09
				var rb := body as RigidBody3D
				rb.apply_central_impulse(Vector3(randf_range(-0.04, 0.04), 0.5, randf_range(-0.04, 0.04)) * rb.mass)
				rb.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * rb.mass * 0.004)
	elif shake_node != null:
		if shaking:
			shake_node.position = _shake_base + Vector3(sin(_t * 70.0) * 0.004, absf(sin(_t * 35.0)) * 0.004, 0)
		else:
			shake_node.position = _shake_base
