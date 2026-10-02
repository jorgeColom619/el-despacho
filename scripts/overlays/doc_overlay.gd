extends "res://scripts/ui/overlay.gd"
## Mesa de documentos: sellar leyes, decretos, indultos, contratos... con lupa para la letra pequeña.

const Portrait := preload("res://scripts/ui/portrait.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")
const OfficeArt := preload("res://scripts/office/office_art.gd")
const W := preload("res://scripts/data/world_data.gd")

const INK := Color("2b2319")


class Stamp extends Control:
	var label := "APROBADO"
	var col := Color(0.2, 0.6, 0.3)
	var idx := 0
	var home := Vector2.ZERO
	var dragging := false
	var lifted := 0.0

	func _ready() -> void:
		size = Vector2(190, 220)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_DRAG

	func _process(d: float) -> void:
		lifted = move_toward(lifted, 1.0 if dragging else 0.0, d * 6.0)
		queue_redraw()

	func _draw() -> void:
		var sh := 6.0 + lifted * 22.0
		draw_rect(Rect2(22 + sh, 128 + sh, 150, 76), Color(0, 0, 0, 0.3 - lifted * 0.1))
		var pts := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			pts.append(Vector2(95, 42) + Vector2(cos(a) * 42, sin(a) * 30))
		draw_colored_polygon(pts, Color("3a2012"))
		var pts2 := PackedVector2Array()
		for i in 28:
			var a2 := TAU * i / 28.0
			pts2.append(Vector2(88, 34) + Vector2(cos(a2) * 22, sin(a2) * 12))
		draw_colored_polygon(pts2, Color(1, 0.85, 0.7, 0.18))
		draw_rect(Rect2(82, 62, 26, 70), Color("4a2a18"))
		draw_rect(Rect2(86, 62, 6, 70), Color(1, 1, 1, 0.08))
		draw_rect(Rect2(16, 128, 158, 62), Color("2b2b30"))
		draw_rect(Rect2(16, 128, 158, 5), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(16, 188, 158, 16), col.darkened(0.25))
		draw_string(UI.f_cond_b, Vector2(16, 172), label, HORIZONTAL_ALIGNMENT_CENTER, 158, 24 if label.length() < 10 else 18, col.lightened(0.45))


class Impression extends Control:
	var label := ""
	var col := Color.RED
	var wax := false

	func _draw() -> void:
		if wax:
			var pts := PackedVector2Array()
			for i in 36:
				var a := TAU * i / 36.0
				pts.append(Vector2(cos(a), sin(a)) * (62.0 + sin(i * 2.7) * 4.0))
			draw_colored_polygon(pts, Color(col, 1.0))
			draw_arc(Vector2.ZERO, 46, 0, TAU, 48, Color(col.lightened(0.25), 0.9), 3.0, true)
			draw_circle(Vector2(-18, -20), 14, Color(1, 1, 1, 0.12))
			draw_string(UI.f_cond_b, Vector2(-60, 8), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 18 if label.length() < 10 else 14, col.lightened(0.45))
			return
		var fs := 46
		var tw := UI.f_cond_b.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var r := Rect2(-tw / 2.0 - 22, -38, tw + 44, 76)
		draw_rect(r, col, false, 5.0)
		draw_rect(r.grow(-8), col, false, 2.0)
		draw_string(UI.f_cond_b, Vector2(-tw / 2.0, 17), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


var paper: Control
var paper_box: VBoxContainer
var stamps := []
var tray: Control
var lens_on := false
var lens: Control
var reveal_mat: ShaderMaterial
var invert_mat: ShaderMaterial
var hidden_nodes := []
var revealed := false
var reveal_t := 0.0
var effects_holder: VBoxContainer
var zones := []
var busy := false
var drag: Stamp = null
var drag_off := Vector2.ZERO
var cur := 0
var item: Dictionary
var ev: Dictionary
var info_lbl: Label
var note_lbl: Label
var lens_btn: Button


func build() -> void:
	reveal_mat = ShaderMaterial.new()
	reveal_mat.shader = load("res://shaders/reveal.gdshader")
	invert_mat = ShaderMaterial.new()
	invert_mat.shader = load("res://shaders/reveal.gdshader")
	invert_mat.set_shader_parameter("invert", true)
	# cabecera
	var head := title_bar("Mesa de firmas", "Documentos pendientes", "documento")
	head.position = Vector2(70, 130)
	root.add_child(head)
	var hint := UI.lbl("Arrastre un sello sobre el documento para decidir.  Use la lupa (L) para leer la letra pequeña.", UI.f_sans, 17, UI.DIM)
	hint.position = Vector2(70, 1030)
	root.add_child(hint)
	# bandeja de sellos
	tray = Control.new()
	tray.position = Vector2(80, 330)
	tray.size = Vector2(380, 560)
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.draw.connect(func():
		tray.draw_rect(Rect2(0, 0, tray.size.x, tray.size.y), Color(0.12, 0.2, 0.16, 0.9))
		tray.draw_rect(Rect2(0, 0, tray.size.x, tray.size.y), Color(UI.GOLD, 0.5), false, 2.0)
		tray.draw_string(UI.f_sans_b, Vector2(0, 30), "SELLOS OFICIALES", HORIZONTAL_ALIGNMENT_CENTER, tray.size.x, 14, UI.GOLD))
	root.add_child(tray)
	# panel derecho
	var right := UI.vbox(16)
	right.position = Vector2(1450, 150)
	right.size = Vector2(400, 800)
	root.add_child(right)
	info_lbl = UI.lbl("", UI.f_sans_m, 18, UI.TEXT)
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_lbl.custom_minimum_size = Vector2(400, 0)
	right.add_child(info_lbl)
	lens_btn = UI.btn("  Lupa  (L)", "normal", 20)
	lens_btn.icon = UI.icon("lupa", 40)
	lens_btn.add_theme_constant_override("icon_max_width", 26)
	lens_btn.toggle_mode = true
	lens_btn.toggled.connect(func(on): _set_lens(on))
	right.add_child(lens_btn)
	# nota del gabinete (post-it)
	var note := PanelContainer.new()
	var nst := UI.sb(Color("f2dc6b"), 3, Color(0, 0, 0, 0), 0, 10, 20)
	note.add_theme_stylebox_override("panel", nst)
	note.rotation = deg_to_rad(2.0)
	note_lbl = UI.lbl("", UI.f_hand, 28, Color("2a2a60"))
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_lbl.custom_minimum_size = Vector2(340, 0)
	note.add_child(note_lbl)
	right.add_child(note)
	right.add_child(UI.spacer(0, 20))
	var nb := UI.btn("Siguiente documento  ▶", "normal", 18)
	nb.pressed.connect(func():
		if busy or GS.inbox.size() < 2:
			return
		cur = (cur + 1) % GS.inbox.size()
		Sfx.play("paper", -4.0)
		_show(cur))
	right.add_child(nb)
	var later := UI.btn("Dejar para más tarde", "ghost", 18)
	later.pressed.connect(func(): close())
	right.add_child(later)
	# lupa
	lens = Control.new()
	lens.size = Vector2(10, 10)
	lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lens.visible = false
	lens.draw.connect(_draw_lens)
	add_child(lens)
	_show(0)


func _draw_lens() -> void:
	lens.draw_circle(Vector2.ZERO, 108, Color(0.8, 0.9, 1.0, 0.06))
	lens.draw_arc(Vector2.ZERO, 108, 0, TAU, 64, Color("8a6a2c"), 9.0, true)
	lens.draw_arc(Vector2.ZERO, 112, 0, TAU, 64, Color("f0d58f"), 2.0, true)
	lens.draw_arc(Vector2.ZERO, 92, PI * 1.1, PI * 1.45, 16, Color(1, 1, 1, 0.35), 5.0, true)
	var hdir := Vector2(0.72, 0.7).normalized()
	lens.draw_line(hdir * 116, hdir * 220, Color("3a2012"), 22.0, true)
	lens.draw_line(hdir * 116, hdir * 136, Color("c9a55c"), 24.0, true)


func _set_lens(on: bool) -> void:
	lens_on = on
	lens.visible = on
	lens_btn.set_pressed_no_signal(on)
	Sfx.play("click", -2.0, 1.3 if on else 0.9)
	if not on:
		reveal_mat.set_shader_parameter("lens_pos", Vector2(-1000, -1000))
		invert_mat.set_shader_parameter("lens_pos", Vector2(-1000, -1000))


func _input(event: InputEvent) -> void:
	if closing:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		_set_lens(not lens_on)
		get_viewport().set_input_as_handled()
	if drag != null:
		if event is InputEventMouseMotion:
			drag.global_position = get_global_mouse_position() - drag_off
		elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_drop()


func on_escape() -> void:
	close()


func _process(delta: float) -> void:
	if lens_on:
		var mp := get_global_mouse_position()
		lens.position = mp
		lens.queue_redraw()
		reveal_mat.set_shader_parameter("lens_pos", mp)
		invert_mat.set_shader_parameter("lens_pos", mp)
		if not revealed:
			var near := false
			for n in hidden_nodes:
				if is_instance_valid(n):
					var r: Rect2 = n.get_global_rect()
					var closest := Vector2(clampf(mp.x, r.position.x, r.end.x), clampf(mp.y, r.position.y, r.end.y))
					if closest.distance_to(mp) < 60.0:
						near = true
			if near:
				reveal_t += delta
				if reveal_t > 0.5:
					_on_revealed()
			else:
				reveal_t = maxf(0.0, reveal_t - delta)


func _on_revealed() -> void:
	revealed = true
	Sfx.play("notify", -4.0, 0.9)
	GS.toast.emit("Ha descubierto una cláusula oculta", "warn", "lupa")
	if Perfil.add_stat("clausulas") >= 5:
		Perfil.unlock("lupa")
	_rebuild_effects()


# ------------------------------------------------------------------ documento

func _show(i: int) -> void:
	if GS.inbox.is_empty():
		close()
		return
	cur = clampi(i, 0, GS.inbox.size() - 1)
	item = GS.inbox[cur]
	ev = item["ev"]
	revealed = false
	reveal_t = 0.0
	hidden_nodes.clear()
	zones.clear()
	if paper != null:
		paper.queue_free()
	_build_paper()
	_build_stamps()
	var left := int(item.get("deadline", GS.day)) - GS.day
	info_lbl.text = "Documento %d de %d\nPlazo para decidir: %d días\n%s" % [cur + 1, GS.inbox.size(), maxi(0, left), _kind_name(ev.get("kind", "")).capitalize()]
	note_lbl.text = _advice()
	paper.position.y = 1100
	create_tween().tween_property(paper, "position:y", 122.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("paper", -3.0)


func _kind_name(k: String) -> String:
	return {"ley": "PROYECTO DE LEY", "decreto": "REAL DECRETO", "indulto": "SOLICITUD DE INDULTO", "informe": "INFORME CONFIDENCIAL", "carta": "CORRESPONDENCIA", "contrato": "CONTRATACIÓN PÚBLICA", "nombramiento": "NOMBRAMIENTO"}.get(k, "DOCUMENTO OFICIAL")


func _build_paper() -> void:
	paper = Control.new()
	paper.size = Vector2(840, 940)
	paper.position = Vector2(540, 122)
	paper.pivot_offset = paper.size * 0.5
	paper.rotation = deg_to_rad(randf_range(-1.0, 1.0))
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(paper)
	var shadow := Panel.new()
	var sst := StyleBoxFlat.new()
	sst.bg_color = Color(0, 0, 0, 0.0)
	sst.shadow_color = Color(0, 0, 0, 0.55)
	sst.shadow_size = 30
	sst.shadow_offset = Vector2(10, 16)
	shadow.add_theme_stylebox_override("panel", sst)
	shadow.size = paper.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(shadow)
	var bg := ColorRect.new()
	bg.size = paper.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/paper.gdshader")
	if ev.get("kind", "") == "carta":
		pm.set_shader_parameter("tint", Color(0.97, 0.95, 0.9))
	bg.material = pm
	paper.add_child(bg)
	var wm := TextureRect.new()
	wm.texture = OfficeArt.tex("seal", 1.5)
	wm.position = Vector2(220, 300)
	wm.size = Vector2(400, 400)
	wm.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wm.modulate = Color(1, 1, 1, 0.05)
	wm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(wm)
	var kind: String = ev.get("kind", "")
	if kind == "carta":
		var lines := Control.new()
		lines.size = paper.size
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lines.draw.connect(func():
			var y := 250.0
			while y < 900.0:
				lines.draw_line(Vector2(60, y), Vector2(780, y), Color(0.4, 0.55, 0.8, 0.25), 1.0)
				y += 44.0
			lines.draw_line(Vector2(100, 0), Vector2(100, 960), Color(0.85, 0.3, 0.3, 0.25), 1.5))
		paper.add_child(lines)
	paper_box = UI.vbox(12)
	paper_box.position = Vector2(60, 50)
	paper_box.size = Vector2(720, 850)
	paper.add_child(paper_box)
	# membrete
	var hh := UI.hbox(16)
	var seal := TextureRect.new()
	seal.texture = OfficeArt.tex("seal", 0.5)
	seal.custom_minimum_size = Vector2(64, 64)
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hh.add_child(seal)
	var hv := UI.vbox(0)
	hv.add_child(UI.lbl("REPÚBLICA DE VALDORIA", UI.f_sans_b, 13, INK))
	hv.add_child(UI.lbl("Presidencia del Gobierno", UI.f_serif_b, 22, INK))
	hh.add_child(hv)
	hh.add_child(UI.spacer(0, 0, true))
	var kp := PanelContainer.new()
	var kcol := Color("a3261d") if kind in ["informe", "indulto"] else Color("1d3557")
	var kst := UI.sb(Color(0, 0, 0, 0), 2, kcol, 2, 0, 8)
	kp.add_theme_stylebox_override("panel", kst)
	kp.add_child(UI.lbl(_kind_name(kind), UI.f_cond_b, 18, kcol))
	kp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kp.rotation = deg_to_rad(-2.0)
	hh.add_child(kp)
	paper_box.add_child(hh)
	var rule := ColorRect.new()
	rule.color = Color(INK, 0.7)
	rule.custom_minimum_size = Vector2(0, 2)
	paper_box.add_child(rule)
	paper_box.add_child(UI.lbl("Ref. PR-%d/%04d   ·   Santa Aurora, %s" % [UI.date_dict(GS.day)["year"], int(item["uid"]) * 7 + 113, UI.date_mid(GS.day)], UI.f_type, 15, Color(INK, 0.75)))
	var title := UI.lbl(GS.fmt(ev.get("title", "")), UI.f_serif_b, 34 if kind != "carta" else 30, INK)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(720, 0)
	paper_box.add_child(title)
	var body_text := GS.fmt(ev.get("text", ""))
	if ev.has("redacted"):
		body_text = body_text.replace("████████████", "[CLASIFICADO]")
	if kind == "indulto":
		var bh := UI.hbox(24)
		var body := _body(body_text, 480)
		bh.add_child(body)
		bh.add_child(_mugshot())
		paper_box.add_child(bh)
	elif kind == "carta":
		var b2 := UI.lbl(body_text, UI.f_hand, 31, Color("1d2a6b"))
		b2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b2.custom_minimum_size = Vector2(700, 0)
		paper_box.add_child(b2)
	else:
		paper_box.add_child(_body(body_text, 720))
	if ev.has("redacted"):
		for rtext in ev["redacted"]:
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(720, 36)
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var lab := UI.lbl("Objetivo: " + rtext, UI.f_type, 20, Color("7a1a14"))
			lab.position = Vector2(0, 4)
			holder.add_child(lab)
			var bar := ColorRect.new()
			bar.color = Color(0.05, 0.05, 0.05)
			bar.position = Vector2(100, 2)
			bar.size = Vector2(UI.f_type.get_string_size(rtext, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 16, 30)
			bar.material = invert_mat
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(bar)
			paper_box.add_child(holder)
			hidden_nodes.append(bar)
	if ev.has("options"):
		var oh := UI.hbox(14)
		for opt in ev["options"]:
			oh.add_child(_option_card(opt))
		paper_box.add_child(oh)
	else:
		effects_holder = UI.vbox(6)
		paper_box.add_child(effects_holder)
		_rebuild_effects()
	# letra pequeña
	var smalls: Array = ev.get("small", [])
	if smalls.size() > 0 and not ev.has("options"):
		paper_box.add_child(UI.spacer(0, 6))
		paper_box.add_child(UI.lbl("ANEXO · Disposiciones adicionales", UI.f_sans_b, 11, Color(INK, 0.55)))
		for st in smalls:
			var sl := UI.lbl(GS.fmt(st), UI.f_type, 17, Color("5a1a10"))
			sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sl.custom_minimum_size = Vector2(720, 0)
			sl.material = reveal_mat
			paper_box.add_child(sl)
			hidden_nodes.append(sl)
	paper_box.add_child(UI.spacer(0, 0, true))
	# firma
	var sig := Control.new()
	sig.custom_minimum_size = Vector2(720, 80)
	sig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sig.draw.connect(func():
		sig.draw_line(Vector2(420, 60), Vector2(720, 60), Color(INK, 0.6), 1.5)
		sig.draw_string(UI.f_type, Vector2(420, 78), "El Presidente de la República", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(INK, 0.7)))
	sig.name = "Sig"
	paper_box.add_child(sig)


func _body(t: String, w: float) -> RichTextLabel:
	var r := UI.rich(t, 21, INK, UI.f_type, UI.f_type)
	r.custom_minimum_size = Vector2(w, 0)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


func _mugshot() -> Control:
	var f := Control.new()
	f.custom_minimum_size = Vector2(210, 260)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.clip_contents = true
	f.draw.connect(func():
		f.draw_rect(Rect2(0, 0, 210, 260), Color(0.72, 0.73, 0.72))
		for i in 8:
			f.draw_line(Vector2(0, 30 + i * 28), Vector2(24, 30 + i * 28), Color(0.2, 0.2, 0.2, 0.6), 2.0)
			f.draw_string(UI.f_mono, Vector2(26, 34 + i * 28), str(200 - i * 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.2, 0.2, 0.2, 0.7)))
	var p := Portrait.new()
	p.position = Vector2(10, 20)
	p.size = Vector2(200, 240)
	p.track_mouse = false
	f.add_child(p)
	var look: Dictionary = ev.get("prisoner", {})
	var l2: Dictionary = look.duplicate()
	l2["suit"] = "c7772a"
	l2["shirt"] = "d9d0bf"
	l2["tie"] = ""
	p.setup(l2, false)
	p.mood = -0.3
	var board := Control.new()
	board.position = Vector2(30, 214)
	board.size = Vector2(150, 40)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.draw.connect(func():
		board.draw_rect(Rect2(0, 0, 150, 40), Color(0.1, 0.1, 0.1))
		board.draw_string(UI.f_mono, Vector2(0, 26), "Nº %06d" % (int(item["uid"]) * 3719 % 999999), HORIZONTAL_ALIGNMENT_CENTER, 150, 18, Color(0.9, 0.9, 0.9)))
	f.add_child(board)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0), 0, Color(0.2, 0.2, 0.2), 3, 0, 0))
	frame.add_child(f)
	frame.rotation = deg_to_rad(2.5)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return frame


func _option_card(opt: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.sb(Color(1, 1, 1, 0.35), 4, Color(INK, 0.35), 1, 0, 12))
	card.custom_minimum_size = Vector2(230, 330)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UI.vbox(6)
	card.add_child(v)
	if opt.has("look"):
		var pf := Control.new()
		pf.custom_minimum_size = Vector2(206, 110)
		pf.clip_contents = true
		pf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var p := Portrait.new()
		p.position = Vector2(50, 0)
		p.size = Vector2(106, 128)
		p.track_mouse = false
		pf.add_child(p)
		p.setup(Portrait._defaults(opt["look"]), false)
		v.add_child(pf)
	var nm := UI.lbl(opt["name"], UI.f_serif_b, 21, INK)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(206, 0)
	v.add_child(nm)
	for ln in opt.get("lines", []):
		var l := UI.lbl(ln, UI.f_type, 16, Color(INK, 0.85))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(206, 0)
		v.add_child(l)
	var prev := GS.preview(opt.get("fx", {}))
	var vis := []
	for pv in prev:
		if pv["k"] != "corr":
			vis.append(pv)
	var chips := Widgets.effect_chips(vis, 14, 5)
	chips.custom_minimum_size = Vector2(206, 0)
	v.add_child(chips)
	if opt.has("small"):
		var sl := UI.lbl(opt["small"], UI.f_type, 14, Color("5a1a10"))
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(206, 0)
		sl.material = reveal_mat
		v.add_child(sl)
		hidden_nodes.append(sl)
	zones.append({"node": card, "opt": opt})
	return card


func _rebuild_effects() -> void:
	if effects_holder == null or not is_instance_valid(effects_holder):
		return
	for c in effects_holder.get_children():
		c.queue_free()
	if ev.has("options"):
		return
	effects_holder.add_child(UI.lbl("EFECTOS PREVISTOS SEGÚN EL GABINETE", UI.f_sans_b, 11, Color(INK, 0.55)))
	var labels := _stamp_labels()
	for i in mini(2, ev["choices"].size()):
		var ch: Dictionary = ev["choices"][i]
		var h := UI.hbox(10)
		var l := UI.lbl("Si %s:" % labels[i].to_lower(), UI.f_type, 16, INK)
		l.custom_minimum_size = Vector2(150, 0)
		h.add_child(l)
		var items := GS.preview(ch.get("fx", {}))
		if revealed and ch.has("hidden"):
			items.append_array(GS.preview(ch["hidden"]))
		if items.is_empty():
			h.add_child(UI.lbl("Sin efectos relevantes", UI.f_type, 15, Color(INK, 0.6)))
		else:
			var chips := Widgets.effect_chips(items, 15, 7)
			chips.custom_minimum_size = Vector2(560, 0)
			h.add_child(chips)
		effects_holder.add_child(h)
		if revealed and ch.has("hidden"):
			var warn := UI.lbl("   ⚠ Incluye efectos de la letra pequeña", UI.f_sans_b, 13, Color("a3261d"))
			effects_holder.add_child(warn)


func _stamp_labels() -> Array:
	if ev.has("stamps"):
		var out := []
		for s in ev["stamps"]:
			out.append(s)
		return out
	match ev.get("kind", ""):
		"indulto":
			return ["CONCEDIDO", "DENEGADO"]
		"informe":
			return ["AUTORIZADO", "DENEGADO"]
	return ["APROBADO", "VETADO"]


func _build_stamps() -> void:
	for s in stamps:
		s.queue_free()
	stamps.clear()
	if ev.has("options"):
		var st := Stamp.new()
		st.label = "NOMBRADO" if ev.get("kind", "") == "nombramiento" else "ADJUDICADO"
		st.col = Color("b8913f")
		st.idx = -1
		_add_stamp(st, Vector2(175, 470))
	else:
		var labels := _stamp_labels()
		var ink: Dictionary = Perfil.equipped_data("tinta")
		var cols := [Color(ink.get("ok", "2e8b57")), Color(ink.get("no", "b3261e"))]
		for i in mini(2, ev["choices"].size()):
			var st2 := Stamp.new()
			st2.label = labels[i]
			st2.col = cols[i]
			st2.idx = i
			_add_stamp(st2, Vector2(175, 380 + i * 250))


func _add_stamp(st: Stamp, pos: Vector2) -> void:
	st.position = pos
	st.home = pos
	root.add_child(st)
	stamps.append(st)
	st.gui_input.connect(func(e):
		if busy:
			return
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			drag = st
			st.dragging = true
			drag_off = get_global_mouse_position() - st.global_position
			st.move_to_front()
			Sfx.play("paper2", -8.0, 1.3))


func _drop() -> void:
	var st := drag
	drag = null
	st.dragging = false
	var mp := get_global_mouse_position()
	var target = null
	if st.idx == -1:
		for z in zones:
			if (z["node"] as Control).get_global_rect().has_point(mp + Vector2(0, 100)):
				target = z
				break
	else:
		var pr := Rect2(paper.global_position, paper.size)
		if pr.has_point(mp + Vector2(0, 100)):
			target = st.idx
	if target == null:
		var t := create_tween()
		t.tween_property(st, "position", st.home, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	_commit(st, target, mp + Vector2(0, 100))


func _commit(st: Stamp, target, at: Vector2) -> void:
	busy = true
	# golpe del sello
	var t := create_tween()
	t.tween_property(st, "scale", Vector2(0.9, 0.9), 0.07)
	t.tween_property(st, "scale", Vector2.ONE, 0.12)
	Sfx.play("stamp", 0.0, randf_range(0.95, 1.05))
	_shake()
	var imp := Impression.new()
	imp.label = st.label
	imp.col = Color(st.col, 0.85)
	imp.wax = Perfil.equipped_data("tinta").get("wax", false) and st.idx >= 0
	if not imp.wax:
		var im := ShaderMaterial.new()
		im.shader = load("res://shaders/ink.gdshader")
		im.set_shader_parameter("seed", randf() * 100.0)
		imp.material = im
	imp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(imp)
	imp.position = paper.get_global_transform().affine_inverse() * at
	imp.rotation = deg_to_rad(randf_range(-12, 12))
	imp.scale = Vector2(1.4, 1.4)
	imp.create_tween().tween_property(imp, "scale", Vector2.ONE, 0.08)
	# firma presidencial al aprobar
	if (target is int and target == 0) or not (target is int):
		var sig := paper_box.get_node_or_null("Sig")
		if sig != null:
			var sl := UI.lbl(GS.pres["name"], UI.f_sign, 58, Color("1d2a6b"))
			sl.position = Vector2(430, -8)
			sl.visible_ratio = 0.0
			sig.add_child(sl)
			sl.create_tween().tween_property(sl, "visible_ratio", 1.0, 0.6)
			Sfx.play("scribble", -8.0)
	await get_tree().create_timer(0.85).timeout
	st.position = st.home
	if target is int:
		GS.resolve_choice(item, target)
	else:
		GS.resolve_option(item, target["opt"])
	# el papel sale volando
	var dir := 1.0 if (target is int and target == 1) else -1.0
	var t2 := create_tween().set_parallel(true)
	t2.tween_property(paper, "position", paper.position + Vector2(1300 * -dir, -80), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t2.tween_property(paper, "rotation", paper.rotation + 0.35 * -dir, 0.5)
	Sfx.play("paper", -2.0)
	await get_tree().create_timer(0.5).timeout
	busy = false
	if GS.inbox.is_empty():
		close()
	else:
		_show(mini(cur, GS.inbox.size() - 1))


func _shake() -> void:
	var t := create_tween()
	for i in 5:
		t.tween_property(root, "position", Vector2(randf_range(-7, 7), randf_range(-7, 7)), 0.03)
	t.tween_property(root, "position", Vector2.ZERO, 0.04)


func _advice() -> String:
	if ev.has("options"):
		return "Mire bien las tres ofertas... y lo que no se ve a simple vista."
	var best := 0
	var best_s := -9999.0
	var scores := []
	for i in ev["choices"].size():
		var s := _score(ev["choices"][i].get("fx", {}))
		scores.append(s)
		if s > best_s:
			best_s = s
			best = i
	var labels := _stamp_labels()
	var diff := absf(float(scores[0]) - float(scores[scores.size() - 1])) if scores.size() > 1 else 0.0
	var who: String = GS.ministers["jefa"]["name"].split(" ")[0]
	if diff < 1.5:
		return "Presidente: es una decisión menor. Lo que usted vea.\n— %s" % who
	var top_k := ""
	var top_v := 0.0
	var fx: Dictionary = ev["choices"][best].get("fx", {})
	for k in fx.keys():
		if (GS.fac.has(k) or GS.meters.has(k)) and absf(float(fx[k])) > absf(top_v):
			top_v = float(fx[k])
			top_k = k
	var why := ""
	var subj := {"trabajadores": "Los trabajadores lo agradecerán", "empresarios": "Los empresarios lo agradecerán", "clase_media": "La clase media lo agradecerá",
		"jovenes": "Los jóvenes lo agradecerán", "jubilados": "Los jubilados lo agradecerán", "militares": "El Ejército lo agradecerá",
		"economia": "Es lo mejor para la economía", "bienestar": "Es lo mejor para el bienestar", "seguridad": "Ganaremos en seguridad",
		"estabilidad": "Nos dará estabilidad", "prestigio": "Mejorará nuestra imagen", "ambiente": "Es lo mejor para el medio ambiente"}
	if top_k != "" and top_v > 0:
		why = " " + subj.get(top_k, "") + "."
	var verb: String = {"APROBADO": "aprobarlo", "VETADO": "vetarlo", "CONCEDIDO": "concederlo", "DENEGADO": "denegarlo", "AUTORIZADO": "autorizarlo",
		"FINANCIAR": "financiarlo", "ARCHIVAR": "archivarlo", "FINANCIAR PLAN": "financiar el plan"}.get(labels[best], String(labels[best]).to_lower())
	return "Mi consejo: %s.%s\n— %s" % [verb, why, who]


func _score(fx: Dictionary) -> float:
	var s := 0.0
	for k in fx.keys():
		var v = fx[k]
		if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
			continue
		if GS.fac.has(k):
			s += float(v) * (W.FACTION_INFO[k]["w"] * 4.0 + 0.2)
		elif GS.meters.has(k):
			s += float(v) * 0.6
		elif k == "money":
			s += float(v) / 700.0
		elif k == "monthly":
			s += float(v) / 60.0
		elif k == "pc":
			s += float(v) * 0.3
	return s
