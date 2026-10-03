extends "res://scripts/ui/overlay.gd"
## El Diario de la República: portada mensual generada a partir de lo ocurrido.

const Portrait := preload("res://scripts/ui/portrait.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")
const W := preload("res://scripts/data/world_data.gd")

const INK := Color("1a1a1c")
var page: Control
var intro := false
var new_term := false


func build() -> void:
	intro = data.get("intro", false)
	new_term = data.get("new_term", false)
	var items: Array = []
	if new_term:
		items = GS.news_feed.slice(0, 6)
	elif intro:
		items = [{"t": "%s jura su cargo como presidente de Valdoria" % GS.pres["name"], "imp": 3}]
		var sc: Dictionary = GS.SC.SCENARIOS.get(GS.scenario, {})
		if sc.has("headline"):
			items.append({"t": sc["headline"], "imp": 2})
		items.append({"t": "Lo que le espera al nuevo Gobierno: %s" % String(sc.get("name", "")).to_lower(), "imp": 1})
	else:
		items = GS.month_log.duplicate()
		if items.is_empty():
			items = GS.news_feed.slice(0, 6)
	items.sort_custom(func(a, b): return int(a.get("imp", 1)) > int(b.get("imp", 1)))
	var main_head := "Semana tranquila en el Palacio"
	if items.size() > 0:
		main_head = items[0]["t"]
	if intro:
		main_head = "¡%s, PRESIDENTE!" % GS.pres["name"].to_upper()
	if new_term:
		main_head = "¡%s REVALIDA! COMIENZA SU %s LEGISLATURA" % [GS.pres["name"].to_upper(), GS.ordinal(GS.term_index).to_upper()]
	page = Control.new()
	page.size = Vector2(1180, 940)
	page.position = Vector2(370, 120)
	page.pivot_offset = page.size * 0.5
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(page)
	var shadow := Panel.new()
	var sst := StyleBoxFlat.new()
	sst.bg_color = Color(0.93, 0.9, 0.82)
	sst.shadow_color = Color(0, 0, 0, 0.6)
	sst.shadow_size = 30
	sst.shadow_offset = Vector2(8, 14)
	shadow.add_theme_stylebox_override("panel", sst)
	shadow.size = page.size
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(shadow)
	var bg := ColorRect.new()
	bg.size = page.size
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/paper.gdshader")
	pm.set_shader_parameter("tint", Color(0.93, 0.9, 0.82))
	bg.material = pm
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(bg)
	var v := UI.vbox(8)
	v.position = Vector2(46, 26)
	v.size = Vector2(1088, 880)
	page.add_child(v)
	# cabecera
	var top := UI.hbox(0)
	top.add_child(UI.lbl("EDICIÓN NACIONAL", UI.f_sans_b, 12, INK))
	top.add_child(UI.spacer(0, 0, true))
	top.add_child(UI.lbl("FUNDADO EN 1911 · INDEPENDIENTE", UI.f_sans_b, 12, INK))
	v.add_child(top)
	v.add_child(UI.lbl("El Diario de la República", UI.f_goth, 86, INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_rule(3))
	var d := UI.date_dict(GS.day)
	var ed := UI.hbox(0)
	ed.add_child(UI.lbl("Año CXVI · Nº %s" % UI.num(34512 + GS.day, 0), UI.f_serif, 16, INK))
	ed.add_child(UI.spacer(0, 0, true))
	ed.add_child(UI.lbl("Santa Aurora, %s" % UI.date_long(GS.day), UI.f_serif_b, 16, INK))
	ed.add_child(UI.spacer(0, 0, true))
	ed.add_child(UI.lbl("Precio: 1,80 €", UI.f_serif, 16, INK))
	v.add_child(ed)
	v.add_child(_rule(1))
	# titular
	var hl := UI.lbl(main_head, UI.f_serif_k, 58 if main_head.length() < 48 else 46, INK, HORIZONTAL_ALIGNMENT_CENTER)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.custom_minimum_size = Vector2(1088, 0)
	v.add_child(hl)
	var sub := UI.lbl(_subhead(intro), UI.f_serif, 22, Color(INK, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(1088, 0)
	v.add_child(sub)
	v.add_child(_rule(1))
	# cuerpo: foto + columnas
	var body := UI.hbox(22)
	v.add_child(body)
	var left := UI.vbox(8)
	left.custom_minimum_size = Vector2(620, 0)
	body.add_child(left)
	left.add_child(_photo(main_head))
	var cap := UI.lbl(_caption(main_head), UI.f_serif, 15, Color(INK, 0.8))
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.custom_minimum_size = Vector2(620, 0)
	left.add_child(cap)
	var lead := UI.lbl(_lead(main_head), UI.f_serif, 17, INK)
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lead.custom_minimum_size = Vector2(620, 0)
	left.add_child(lead)
	var vr := ColorRect.new()
	vr.color = Color(INK, 0.5)
	vr.custom_minimum_size = Vector2(1, 420)
	body.add_child(vr)
	var right := UI.vbox(10)
	right.custom_minimum_size = Vector2(420, 0)
	body.add_child(right)
	right.add_child(UI.lbl("OTRAS NOTICIAS", UI.f_sans_b, 14, INK))
	var shown := 0
	for it in items.slice(1):
		if shown >= 4:
			break
		var t := UI.lbl(it["t"], UI.f_serif_b, 19, INK)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(420, 0)
		right.add_child(t)
		right.add_child(_rule(1))
		shown += 1
	if shown == 0:
		var t2 := UI.lbl("La oposición promete una legislatura \"de máxima exigencia\"", UI.f_serif_b, 19, INK)
		t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t2.custom_minimum_size = Vector2(420, 0)
		right.add_child(t2)
	right.add_child(_poll_box())
	# cierre
	var close_btn := UI.btn("Dejar el periódico" if not intro else "Empezar a gobernar", "gold", 20)
	close_btn.position = Vector2(1580, 980)
	close_btn.pressed.connect(func(): close())
	root.add_child(close_btn)
	# animación giratoria
	page.scale = Vector2(0.05, 0.05)
	page.rotation = TAU * 2.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(page, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(page, "rotation", deg_to_rad(-1.2), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh", -4.0)
	if intro:
		Sfx.play("news", -6.0)


func _rule(th: int) -> Control:
	var r := ColorRect.new()
	r.color = INK
	r.custom_minimum_size = Vector2(0, th)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _subhead(is_intro: bool) -> String:
	if new_term:
		var own: String = GS.pres["party"]
		return "%s obtiene %d escaños. Tras %s en el Palacio, el presidente promete «no caer en la rutina». La oposición, con %s al frente, anuncia una legislatura sin tregua." % [W.PARTIES[own]["name"], int(GS.parties[own]["seats"]), _years_txt(), GS.opo_name()]
	if is_intro:
		var ctx: String = GS.SC.SCENARIOS.get(GS.scenario, {}).get("context", "")
		return "El líder de %s promete \"un Gobierno para todos\". %s" % [W.PARTIES[GS.pres["party"]]["name"], ctx]
	var ap := GS.approval
	var mood := "se mantiene"
	var hist: Array = GS.stat_hist["approval"]
	if hist.size() >= 2:
		var diff: float = float(hist[hist.size() - 1]) - float(hist[hist.size() - 2])
		if diff > 2.0:
			mood = "sube"
		elif diff < -2.0:
			mood = "cae"
	return "La aprobación del Gobierno %s hasta el %s%% según la encuesta de El Diario. La deuda pública roza el %s%% del PIB." % [mood, UI.num(ap, 0), UI.num(GS.debt_ratio(), 0)]


func _years_txt() -> String:
	var y := int(floor(float(GS.day) / 365.0))
	return "%d año%s" % [y, "" if y == 1 else "s"]


func _caption(h: String) -> String:
	if intro:
		return "El nuevo presidente, %s, a su llegada al Palacio de Gobierno. (Foto: Agencia VNP)" % GS.pres["name"]
	return "Imagen de archivo. (Foto: Agencia VNP)"


func _lead(h: String) -> String:
	if intro:
		return "SANTA AURORA · %s asumió ayer la Presidencia de Valdoria con un discurso en el que prometió estabilidad, reformas y mano tendida. Su partido, %s, cuenta con %d escaños y necesitará socios para sacar adelante sus leyes. Los mercados reaccionaron con prudencia y los sindicatos ya han pedido una reunión." % [GS.pres["name"], W.PARTIES[GS.pres["party"]]["name"], int(GS.parties[GS.pres["party"]]["seats"])]
	var parts := ["SANTA AURORA · ", h, ". Fuentes del Palacio aseguran que el presidente sigue de cerca la situación. "]
	if GS.approval < 40:
		parts.append("El malestar social crece y la oposición huele la sangre. ")
	elif GS.approval > 60:
		parts.append("El Gobierno vive un momento dulce en las encuestas. ")
	parts.append("El paro se sitúa en el %s%% y la economía crece a un ritmo del %s%%." % [UI.num(GS.unemployment(), 1), UI.num(GS.growth(), 1)])
	return "".join(parts)


func _photo(h: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(620, 380)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.size = Vector2i(620, 380)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(vp)
	var scene := Control.new()
	scene.size = Vector2(620, 380)
	vp.add_child(scene)
	var hl := h.to_lower()
	var kind := "portrait"
	for k in ["incend", "fuego", "arde"]:
		if k in hl:
			kind = "fire"
	for k in ["huelga", "disturb", "protest", "calle", "manifest", "revuelta"]:
		if k in hl:
			kind = "crowd"
	for k in ["congreso", "ley", "moción", "presupuesto"]:
		if k in hl:
			kind = "parliament"
	for k in ["acuerdo", "cumbre", "norland", "unión", "kharovia", "tsaing", "sarvenia", "qadar", "aldora"]:
		if k in hl:
			kind = "handshake"
	scene.draw.connect(func(): _draw_scene(scene, kind))
	if kind == "portrait":
		var p := Portrait.new()
		p.position = Vector2(150, 0)
		p.size = Vector2(320, 384)
		p.track_mouse = false
		p.breathe = false
		scene.add_child(p)
		p.setup(GS.pres["look"], true)
		p.mood = 0.5
	var tr := TextureRect.new()
	tr.texture = vp.get_texture()
	tr.size = Vector2(620, 380)
	var hm := ShaderMaterial.new()
	hm.shader = load("res://shaders/halftone.gdshader")
	tr.material = hm
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tr)
	var fr := Panel.new()
	fr.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0), 0, INK, 2))
	fr.size = Vector2(620, 380)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fr)
	return holder


func _draw_scene(c: Control, kind: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GS.day
	c.draw_rect(Rect2(0, 0, 620, 380), Color(0.75, 0.75, 0.75))
	match kind:
		"portrait":
			c.draw_rect(Rect2(0, 0, 620, 380), Color(0.6, 0.62, 0.65))
			for i in 6:
				c.draw_rect(Rect2(i * 110, 0, 50, 380), Color(1, 1, 1, 0.08))
		"fire":
			c.draw_rect(Rect2(0, 0, 620, 380), Color(0.35, 0.33, 0.32))
			for i in 30:
				c.draw_circle(Vector2(rng.randf_range(0, 620), rng.randf_range(0, 200)), rng.randf_range(30, 80), Color(0.2, 0.2, 0.2, 0.3))
			for i in 16:
				var x := rng.randf_range(0, 620)
				c.draw_colored_polygon(PackedVector2Array([Vector2(x - 30, 380), Vector2(x, rng.randf_range(160, 280)), Vector2(x + 30, 380)]), Color(0.95, 0.9, 0.8))
			for i in 12:
				var x2 := rng.randf_range(0, 620)
				c.draw_rect(Rect2(x2, 250, 6, 130), Color(0.05, 0.05, 0.05))
				c.draw_circle(Vector2(x2 + 3, 250), 20, Color(0.05, 0.05, 0.05))
		"crowd", "parliament", "handshake":
			c.draw_rect(Rect2(0, 0, 620, 380), Color(0.7, 0.72, 0.75) if kind != "parliament" else Color(0.5, 0.45, 0.4))
			if kind == "parliament":
				for i in 7:
					c.draw_rect(Rect2(40 + i * 82, 40, 30, 200), Color(0.85, 0.82, 0.78))
				c.draw_rect(Rect2(20, 30, 580, 24), Color(0.8, 0.78, 0.74))
			if kind == "handshake":
				c.draw_rect(Rect2(0, 0, 620, 380), Color(0.55, 0.57, 0.6))
				for sx in [180, 440]:
					c.draw_circle(Vector2(sx, 120), 44, Color(0.85, 0.8, 0.75))
					c.draw_rect(Rect2(sx - 70, 170, 140, 210), Color(0.15, 0.15, 0.18))
				c.draw_line(Vector2(250, 260), Vector2(370, 260), Color(0.85, 0.8, 0.75), 30.0)
				return
			for i in 90:
				var x3 := rng.randf_range(-10, 630)
				var y3 := rng.randf_range(200, 380)
				var s := 0.6 + (y3 - 200.0) / 180.0
				c.draw_circle(Vector2(x3, y3 - 30 * s), 14 * s, Color(0.1, 0.1, 0.1))
				c.draw_rect(Rect2(x3 - 16 * s, y3 - 16 * s, 32 * s, 60 * s), Color(0.12, 0.12, 0.12))
				if kind == "crowd" and rng.randf() < 0.2:
					c.draw_rect(Rect2(x3 - 20 * s, y3 - 90 * s, 50 * s, 30 * s), Color(0.95, 0.95, 0.95))


func _poll_box() -> Control:
	var box := UI.vbox(6)
	box.add_child(UI.lbl("ENCUESTA DE EL DIARIO", UI.f_sans_b, 13, INK))
	var ch := Control.new()
	ch.custom_minimum_size = Vector2(420, 130)
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.draw.connect(func():
		var hist: Array = GS.stat_hist["approval"].slice(maxi(0, GS.stat_hist["approval"].size() - 8))
		hist.append(GS.approval)
		var n := hist.size()
		var bw := 420.0 / maxf(1.0, n) - 8.0
		for i in n:
			var hgt := float(hist[i]) / 100.0 * 100.0
			ch.draw_rect(Rect2(i * (bw + 8), 110 - hgt, bw, hgt), Color(0.15, 0.15, 0.17) if i < n - 1 else Color("8e2a22"))
		ch.draw_line(Vector2(0, 110), Vector2(420, 110), INK, 1.5)
		ch.draw_string(UI.f_serif_b, Vector2(0, 128), "Aprobación del Gobierno: %s%%" % UI.num(GS.approval, 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK))
	box.add_child(ch)
	return box


func on_escape() -> void:
	close()
