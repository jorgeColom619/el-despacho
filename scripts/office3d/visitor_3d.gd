extends Node3D
## Visitante del despacho 3D: cuerpo sencillo hecho con piezas y, como busto, el retrato vectorial
## animado del personaje (parpadea, habla y cambia de humor igual que en la versión 2D).

const Portrait := preload("res://scripts/ui/portrait.gd")
const Kit := preload("res://scripts/office3d/kit.gd")
const W := preload("res://scripts/data/world_data.gd")
const BUST_PX := 0.00134

## Retrato que anima el panel del asesor (talking, mood, anger)
var portrait: Control
var vp: SubViewport
var bust: Sprite3D
var cam: Camera3D
var walking := false
var _legs: Array = []
var _arms: Array = []
var _parts := {}
var _phase := 0.0
var _body: Node3D


func _ready() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(400, 480)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	portrait = Portrait.new()
	portrait.position = Vector2.ZERO
	portrait.size = Vector2(400, 480)
	portrait.track_mouse = false
	vp.add_child(portrait)
	_body = Node3D.new()
	add_child(_body)
	bust = Sprite3D.new()
	bust.texture = vp.get_texture()
	bust.pixel_size = BUST_PX
	bust.position = Vector3(0, 1.1 + 480 * BUST_PX * 0.5, 0)
	bust.double_sided = true
	bust.shaded = true
	bust.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	_body.add_child(bust)
	# torso, cadera y piernas
	_parts["torso"] = Kit.mesh(_body, _box(Vector3(0.42, 0.3, 0.22)), null, Vector3(0, 0.98, -0.02))
	_parts["belt"] = Kit.mesh(_body, _box(Vector3(0.43, 0.04, 0.23)), Kit.mat(Color("15110e"), 0.5), Vector3(0, 0.86, -0.02))
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.1 * side, 0.86, -0.02)
		_body.add_child(hip)
		var leg := Kit.mesh(hip, _box(Vector3(0.155, 0.8, 0.17)), null, Vector3(0, -0.4, 0))
		leg.set_meta("part", "leg")
		Kit.mesh(hip, _box(Vector3(0.13, 0.07, 0.27)), Kit.mat(Color("0d0b0a"), 0.35), Vector3(0, -0.83, 0.04))
		_legs.append(hip)
		var sh := Node3D.new()
		sh.position = Vector3(0.205 * side, 1.16, -0.05)
		_body.add_child(sh)
		var arm := Kit.mesh(sh, _box(Vector3(0.085, 0.44, 0.11)), null, Vector3(0, -0.22, 0))
		arm.set_meta("part", "arm")
		var hand := Kit.mesh(sh, Kit.sphere_mesh(0.045, 12), null, Vector3(0, -0.48, 0))
		hand.set_meta("part", "hand")
		_arms.append(sh)
	visible = false


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func dress(look: Dictionary) -> void:
	portrait.setup(look, true)
	portrait.mood = 0.0
	portrait.talking = false
	var l: Dictionary = Portrait._defaults(look)
	var suit := Color(l["suit"])
	var skin := Color(W.SKIN[clampi(int(l["skin"]), 0, 5)])
	var suit_m := Kit.mat(suit.darkened(0.08), 0.75)
	var trouser_m := Kit.mat(suit.darkened(0.2), 0.75)
	var skin_m := Kit.mat(skin, 0.6)
	(_parts["torso"] as MeshInstance3D).material_override = suit_m
	for n in _body.find_children("*", "MeshInstance3D", true, false):
		match n.get_meta("part", ""):
			"leg":
				n.material_override = trouser_m
			"arm":
				n.material_override = suit_m
			"hand":
				n.material_override = skin_m


func show_at(p: Vector3) -> void:
	global_position = p
	visible = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func hide_away() -> void:
	visible = false
	walking = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func walk_to(p: Vector3, dur: float) -> Tween:
	walking = true
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		rotation.y = atan2(d.x, d.z)
	var t := create_tween()
	t.tween_property(self, "global_position", p, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func(): walking = false)
	return t


func _process(delta: float) -> void:
	if not visible:
		return
	if walking:
		_phase += delta * 7.5
	else:
		_phase = move_toward(_phase, round(_phase / PI) * PI, delta * 6.0)
		if cam != null:
			var d := cam.global_position - global_position
			rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(1.0, delta * 6.0))
	var sw := sin(_phase) * (0.45 if walking else 0.0)
	for i in _legs.size():
		(_legs[i] as Node3D).rotation.x = sw * (1.0 if i == 0 else -1.0)
		(_arms[i] as Node3D).rotation.x = -sw * 0.6 * (1.0 if i == 0 else -1.0)
	_body.position.y = absf(sin(_phase)) * 0.03 if walking else 0.0
