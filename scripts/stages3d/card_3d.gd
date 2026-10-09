extends Node3D
## Tarjeta de elección de los escenarios 3D (réplicas del Congreso, respuestas a la prensa, empezar o marcharse): una
## cartulina sobre el atril o la mesa con la cara dibujada en un SubViewport. Al señalarla con el ratón se levanta
## hacia los ojos para que se lea bien; al elegirla sale disparada hacia delante y las demás se retiran.
## Ejes locales: la cara mira a +Y, el texto se lee con su parte de arriba hacia -Z y la derecha hacia +X.

const Kit := preload("res://scripts/office3d/kit.gd")
## Píxeles de la cara por metro de cartulina
const PX_PER_M := 3200.0

## Medidas en metros
var size := Vector2(0.2, 0.13)
## Donde reposa y desde dónde se mira (los ojos del presidente)
var rest := Transform3D()
var eye := Vector3.ZERO
var hovered := false
## "deal" (va a su sitio), "rest", "picked" (la elegida), "gone" (se retira)
var state := "deal"
var _from := Transform3D()
var _delay := 0.0
var _t := 0.0
var _face_mat: StandardMaterial3D
var _body_mat: StandardMaterial3D


## spec: {"title", "desc", "tag", "col" (color de la franja), "icon" (opcional), "key" (tecla, 0 = ninguna)}
func setup(spec: Dictionary, rest_xf: Transform3D, eye_pos: Vector3, from_xf: Transform3D, delay := 0.0, card_size := Vector2(0.2, 0.13)) -> void:
	size = card_size
	rest = rest_xf
	eye = eye_pos
	_from = from_xf
	_delay = delay
	transform = from_xf
	visible = delay <= 0.0
	_build(spec)


func _build(spec: Dictionary) -> void:
	var px := Vector2i(int(size.x * PX_PER_M), int(size.y * PX_PER_M))
	var sv := SubViewport.new()
	sv.size = px
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var face := Control.new()
	face.size = Vector2(px)
	face.theme = UI.theme
	sv.add_child(face)
	_draw_face(face, spec)
	# cartulina: canto de papel y la cara impresa encima
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, 0.004, size.y)
	body.mesh = bm
	_body_mat = Kit.mat(Color("e8dcc2"), 0.85).duplicate()
	body.material_override = _body_mat
	add_child(body)
	var top := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	top.mesh = q
	_face_mat = StandardMaterial3D.new()
	_face_mat.albedo_texture = sv.get_texture()
	_face_mat.roughness = 0.82
	# un poco de luz propia: la tarjeta se lee aunque el atril quede en penumbra
	_face_mat.emission_enabled = true
	_face_mat.emission_texture = sv.get_texture()
	_face_mat.emission_energy_multiplier = 0.32
	_face_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	top.material_override = _face_mat
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, 0.0022, 0))
	add_child(top)


func _draw_face(face: Control, spec: Dictionary) -> void:
	var w := face.size.x
	var h := face.size.y
	var col: Color = spec.get("col", UI.GOLD)
	var ink := Color("2b2319")
	var bg := ColorRect.new()
	bg.color = Color("f4ecda")
	bg.size = face.size
	face.add_child(bg)
	var band := ColorRect.new()
	band.color = col
	band.size = Vector2(w, h * 0.17)
	face.add_child(band)
	var light := col.get_luminance() > 0.55
	var tag := UI.lbl(String(spec.get("tag", "")).to_upper(), UI.f_sans_b, int(h * 0.085), ink if light else Color.WHITE)
	tag.position = Vector2(w * 0.05, h * 0.035)
	face.add_child(tag)
	var key := int(spec.get("key", 0))
	if key > 0:
		var kl := UI.lbl(str(key), UI.f_cond_b, int(h * 0.11), ink if light else Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		kl.size = Vector2(w * 0.12, h * 0.15)
		kl.position = Vector2(w * 0.83, h * 0.0)
		face.add_child(kl)
	var v := UI.vbox(int(h * 0.02))
	v.position = Vector2(w * 0.06, h * 0.22)
	v.size = Vector2(w * 0.88, h * 0.74)
	face.add_child(v)
	var th := UI.hbox(int(w * 0.02))
	if String(spec.get("icon", "")) != "":
		var ic := UI.icon_rect(spec["icon"], int(h * 0.14), col.darkened(0.25))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		th.add_child(ic)
	var title := UI.lbl(String(spec.get("title", "")), UI.f_serif_b, int(h * float(spec.get("title_k", 0.13))), ink)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(w * 0.88 - (h * 0.16 if String(spec.get("icon", "")) != "" else 0.0), 0)
	th.add_child(title)
	v.add_child(th)
	var desc := String(spec.get("desc", ""))
	if desc != "":
		var d := UI.lbl(desc, UI.f_sans_m if spec.get("big_desc", false) else UI.f_sans, int(h * float(spec.get("desc_k", 0.075))), Color("4a3f33"))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(w * 0.88, 0)
		v.add_child(d)
	# marco fino de tinta
	var fr := Panel.new()
	fr.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0), 0, Color(ink, 0.35), 3))
	fr.size = face.size
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(fr)


## Distancia por el rayo hasta la tarjeta (INF si no la toca). Cuenta su sitio de reposo y donde está ahora, para que
## no parpadee al levantarse por debajo del ratón
func hit(from: Vector3, dir: Vector3) -> float:
	if not visible or state in ["picked", "gone"]:
		return INF
	var pad := Vector3(size.x * 0.5 + 0.004, 0.03, size.y * 0.5 + 0.004)
	var box := AABB(-pad, pad * 2.0)
	return minf(_hit_box(rest, box, from, dir), _hit_box(global_transform, box, from, dir))


static func _hit_box(xf: Transform3D, box: AABB, from: Vector3, dir: Vector3) -> float:
	var inv := xf.affine_inverse()
	var o := inv * from
	var d := inv.basis * dir
	var t0 := -INF
	var t1 := INF
	for i in 3:
		if absf(d[i]) < 1e-8:
			if o[i] < box.position[i] or o[i] > box.end[i]:
				return INF
			continue
		var a := (box.position[i] - o[i]) / d[i]
		var b := (box.end[i] - o[i]) / d[i]
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
	if t1 < maxf(t0, 0.0):
		return INF
	return (xf * (o + d * maxf(t0, 0.0))).distance_to(from)


## Levantada hacia los ojos, mirándolos de frente
func lifted() -> Transform3D:
	var p := rest.origin.lerp(eye, 0.3) + Vector3(0, 0.025, 0)
	var n := (eye - p).normalized()
	var up := Vector3.UP - n * n.dot(Vector3.UP)
	var z := -up.normalized()
	return Transform3D(Basis(n.cross(z), n, z).scaled(Vector3.ONE * 1.1), p)


func set_hover(on: bool) -> void:
	hovered = on


## Apagada (se acabó el tiempo o ya se ha elegido otra)
func dim() -> void:
	if _face_mat != null:
		_face_mat.albedo_color = Color(0.55, 0.55, 0.55)
		_face_mat.emission_energy_multiplier = 0.1


## La elegida: sube hacia delante, gira un poco y desaparece
func pick() -> void:
	state = "picked"
	var start := transform
	var up := lifted()
	var away := Transform3D(up.basis.rotated(Vector3.UP, randf_range(-0.3, 0.3)).scaled(Vector3.ONE * 0.05),
		up.origin + (rest.origin - eye).normalized() * 0.5 + Vector3(0, 0.25, 0))
	var t := create_tween()
	t.tween_method(func(k: float): transform = start.interpolate_with(up, k), 0.0, 1.0, 0.14).set_trans(Tween.TRANS_SINE)
	t.tween_method(func(k: float): transform = up.interpolate_with(away, k), 0.0, 1.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


## Las demás: se deslizan hacia el presidente y caen por el borde
func discard(delay := 0.0) -> void:
	state = "gone"
	dim()
	var start := transform
	var to_eye := (eye - rest.origin) * Vector3(1, 0, 1)
	var end := Transform3D(rest.basis.rotated(rest.basis.y.normalized(), randf_range(-0.4, 0.4)), rest.origin + to_eye.normalized() * 0.3 - Vector3(0, 0.35, 0))
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_method(func(k: float): transform = start.interpolate_with(end, k), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	match state:
		"deal":
			var k := clampf((_t - _delay) / 0.36, 0.0, 1.0)
			if k <= 0.0:
				return
			if not visible:
				visible = true
				Sfx.play("paper", -14.0, randf_range(1.0, 1.25))
			transform = _from.interpolate_with(rest, 1.0 - pow(1.0 - k, 3.0))
			if k >= 1.0:
				state = "rest"
		"rest":
			transform = transform.interpolate_with(lifted() if hovered else rest, minf(1.0, delta * 11.0))
