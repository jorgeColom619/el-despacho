extends Node3D
## Visitante del despacho 3D: modelo low-poly hecho en Blender (tools/blender/gen_characters.py genera
## art/characters/visitor.glb). Enseña las piezas y colorea los materiales según el `look` del personaje,
## y anima la cara con blend shapes (parpadea, habla y cambia de humor igual que el retrato 2D).

const Portrait := preload("res://scripts/ui/portrait.gd")
const Kit := preload("res://scripts/office3d/kit.gd")
const W := preload("res://scripts/data/world_data.gd")
const Flags := preload("res://scripts/ui/flags.gd")
const MODEL := preload("res://art/characters/visitor.glb")
const FEMALE_SCALE := 0.96
## Altura de la cara (a la que mira la cámara cuando entra)
const FACE_H := 1.6
## Velocidad (m/s) a la que la animación de paso no patina
const WALK_ANIM_SPEED := 1.2

var cam: Camera3D
var walking := false
## Mismos controles que el retrato 2D (los usa advisor_overlay)
var talking := false
var mood := 0.0
var anger := 0.0
var surprise := 0.0
## Animación en reposo y al hablar: de pie (idle / talk), sentado (sit / sit_talk) o en la mesa
## (sit_table / sit_table_talk). Las pone seat().
var rest_anim := "idle"
var talk_anim := "talk"
## Gesto que sustituye a la postura mientras no esté vacío (sit_clap, clap, sit_raise, photo...)
var gesture := ""
var anim_speed := 1.0

var _model: Node3D
var _anim: AnimationPlayer
var _parts := {}
var _face: MeshInstance3D
var _t := 0.0
var _blink := 0.0
var _blink_timer := 2.5
var _mouth := 0.0
var _mood := 0.0
var _anger := 0.0
var _walk_speed := 1.0


func _ready() -> void:
	_model = MODEL.instantiate()
	add_child(_model)
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		_parts[String(n.name)] = n
		n.visible = false
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		_anim = players[0]
		for a in _anim.get_animation_list():
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	visible = false


func dress(look: Dictionary) -> void:
	var l: Dictionary = Portrait._defaults(look)
	var g: String = l["g"]
	var gu := g.to_upper()
	var show := {"Body_" + gu: true, "Head_" + gu: true, "Face_" + gu: true}
	var hair := "Hair_" + String(l["hair"])
	if g == "f" and _parts.has(hair + "_f"):
		hair += "_f"
	show[hair] = true
	var beard: String = l.get("beard", "none")
	if g == "m" and beard != "none":
		show["Beard_" + beard] = true
	var gl := int(l.get("glasses", 0))
	if gl > 0:
		show["Glasses_%d" % gl] = true
	var tie: String = l.get("tie", "")
	var uniform: bool = l.get("uniform", false)
	if tie != "":
		show["Tie"] = true
	if g == "f" and tie == "" and int(l["age"]) >= 1 and not uniform:
		show["Pearls"] = true
	if uniform:
		show["Uniform"] = true
	var acc: String = l.get("acc", "")
	if acc != "":
		show["Acc_%s_%s" % [acc, gu]] = true
	var mats := _materials(l)
	for n in _parts:
		var mi: MeshInstance3D = _parts[n]
		mi.visible = show.has(n)
		if mi.visible:
			_paint(mi, mats)
	_face = _parts.get("Face_" + gu)
	_model.scale = Vector3.ONE * (FEMALE_SCALE if g == "f" else 1.0)
	talking = false
	mood = 0.0
	anger = 0.0
	surprise = 0.0


func _materials(l: Dictionary) -> Dictionary:
	var skin := Color(W.SKIN[clampi(int(l["skin"]), 0, 5)])
	var hair := Color(W.HAIR_COL[clampi(int(l["hc"]), 0, 6)])
	var suit := Color(l["suit"])
	var f: bool = l["g"] == "f"
	var uniform: bool = l.get("uniform", false)
	var brow := hair.darkened(0.15)
	if l["hair"] in ["bald", "balding"] and int(l["hc"]) >= 5:
		brow = Color(W.HAIR_COL[5]).darkened(0.2)
	var tie: String = l.get("tie", "")
	var gold := Kit.mat(Color("c9a55c"), 0.35, 0.8)
	var flag: Array = Flags.palette(Flags.current_style())
	return {
		"Flag0": Kit.mat(flag[0], 0.6),
		"Flag1": Kit.mat(flag[1], 0.6),
		"Flag2": Kit.mat(flag[2], 0.6),
		"Skin": Kit.mat(skin, 0.6),
		"Suit": Kit.mat(suit.darkened(0.08), 0.75),
		"Trousers": Kit.mat(suit.darkened(0.2), 0.75),
		"Lapel": Kit.mat(suit.darkened(0.25), 0.7),
		"Shirt": Kit.mat(Color(l["shirt"]), 0.6),
		"Tie": Kit.mat(Color(tie) if tie != "" else Color("7a1f2b"), 0.5),
		"Shoes": Kit.mat(Color("0d0b0a"), 0.35),
		"Button": gold if uniform else Kit.mat(Color("15110e"), 0.5),
		"Hair": _hair_mat(hair, 0.45 if l["hair"] == "slick" else 0.8),
		"HairTie": Kit.mat(Color("1a1716"), 0.6),
		"Stubble": Kit.mat(skin.lerp(hair.darkened(0.3), 0.22), 0.8),
		"Brow": Kit.mat(brow, 0.8),
		"Sclera": Kit.mat(Color("f4f1ea"), 0.4),
		"Iris": Kit.mat(Color(l["eyes"]), 0.3),
		"Pupil": Kit.mat(Color("0d0a09"), 0.3),
		"Glint": Kit.mat(Color.WHITE, 0.2),
		"Lid": Kit.mat(Color("1f1512"), 0.6),
		"Lip": Kit.mat(skin.darkened(0.28).lerp(Color("b0504f"), 0.45 if f else 0.2), 0.5),
		"MouthIn": Kit.mat(Color("3a1414"), 0.8),
		"Teeth": Kit.mat(Color("eeeae0"), 0.4),
		"Frame": Kit.mat(Color("1f1a1a"), 0.4, 0.3),
		"Gold": gold,
		"Pearl": Kit.mat(Color("f3ead6"), 0.3),
		"Cap": Kit.mat(suit, 0.75),
		"CapBand": Kit.mat(Color("1f2419"), 0.7),
		"Visor": Kit.mat(Color("141611"), 0.25),
	}


## Las melenas se ven por dentro (detrás del cuello), así que el pelo es de doble cara
func _hair_mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := Kit.mat(c, rough, 0.0, "hair_%s_%s" % [c.to_html(), rough])
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _paint(mi: MeshInstance3D, mats: Dictionary) -> void:
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m != null and mats.has(m.resource_name):
			mi.set_surface_override_material(i, mats[m.resource_name])


func show_at(p: Vector3) -> void:
	global_position = p
	visible = true
	_play(rest_anim, 0.0)


## Postura: "sit" (silla), "table" (sentado con los brazos en la mesa) o de pie (cualquier otro valor)
func seat(mode := "sit") -> void:
	match mode:
		"sit":
			rest_anim = "sit"
			talk_anim = "sit_talk"
		"table":
			rest_anim = "sit_table"
			talk_anim = "sit_table_talk"
		_:
			rest_anim = "idle"
			talk_anim = "talk"


## Empieza la animación en un punto al azar y a un ritmo algo distinto, para que un grupo no se mueva a la vez
func desync() -> void:
	anim_speed = randf_range(0.85, 1.15)
	if _anim != null and _anim.current_animation != "":
		_anim.seek(randf() * _anim.current_animation_length, true)


func hide_away() -> void:
	visible = false
	walking = false
	talking = false


func walk_to(p: Vector3, dur: float) -> Tween:
	walking = true
	var d := p - global_position
	var dist := Vector2(d.x, d.z).length()
	if dist > 0.05:
		rotation.y = atan2(d.x, d.z)
	_walk_speed = clampf(dist / maxf(dur, 0.1) / WALK_ANIM_SPEED, 0.8, 2.2)
	var t := create_tween()
	t.tween_property(self, "global_position", p, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func(): walking = false)
	return t


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if walking:
		_play("walk", 0.15, _walk_speed)
	else:
		_play(gesture if gesture != "" else (talk_anim if talking else rest_anim), 0.35, anim_speed)
		if cam != null:
			var d := cam.global_position - global_position
			rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(1.0, delta * 6.0))
	_update_face(delta)


func _play(anim: String, blend: float, speed := 1.0) -> void:
	if _anim == null:
		return
	_anim.speed_scale = speed
	if _anim.current_animation != anim:
		_anim.play(anim, blend)


func _update_face(delta: float) -> void:
	if _face == null:
		return
	_mood = lerpf(_mood, mood, minf(1.0, delta * 5.0))
	_anger = lerpf(_anger, anger, minf(1.0, delta * 4.0))
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 1.0
		_blink_timer = randf_range(2.0, 5.5)
	_blink = maxf(0.0, _blink - delta * 7.0)
	if talking:
		_mouth = clampf(absf(sin(_t * 17.0)) * 0.7 + absf(sin(_t * 7.3)) * 0.3, 0.0, 1.0)
	else:
		_mouth = lerpf(_mouth, 0.0, minf(1.0, delta * 12.0))
	var happy := clampf(_mood, 0.0, 1.0)
	var sad := clampf(-_mood, 0.0, 1.0)
	_shape(&"blink", _blink)
	_shape(&"talk", _mouth * 0.8 + happy * 0.15)
	_shape(&"smile", happy)
	_shape(&"frown", maxf(sad, _anger * 0.6))
	_shape(&"sad", sad)
	_shape(&"angry", _anger)
	_shape(&"surprise", surprise)


func _shape(n: StringName, v: float) -> void:
	var i := _face.find_blend_shape_by_name(n)
	if i >= 0:
		_face.set_blend_shape_value(i, v)
