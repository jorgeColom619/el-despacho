extends "res://scripts/ui/overlay.gd"
## El móvil del presidente: la red social «Pío» (lo que dice la gente, tendencias, publicar) y los mensajes privados.

const Widgets := preload("res://scripts/ui/widgets.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const Redes := preload("res://scripts/systems/redes.gd")
const D := preload("res://scripts/data/social_data.gd")

const PHONE := Rect2(650, 26, 600, 1028)
const SCREEN := Rect2(670, 46, 560, 988)
const BLUE := Color("1d9bf0")
const BUBBLE_THEM := Color("2a3442")
const BUBBLE_ME := Color("1d6fd6")

var tab := "inicio"
var content: Control
var tab_btns := {}
var side: VBoxContainer
var chat_open: Dictionary = {}
var sel_trend := 0
var sel_tone := "sincero"
var last_result: Dictionary = {}


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.88)
	if not Redes.on():
		Redes.start(GS.rng)
	# el teléfono
	var frame := Control.new()
	frame.position = PHONE.position
	frame.size = PHONE.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(func():
		frame.draw_style_box(UI.sb(Color("0b0c0f"), 64, Color("3a3d45"), 3, 40), Rect2(Vector2.ZERO, PHONE.size))
		frame.draw_style_box(UI.sb(Color("0f1520"), 48), Rect2(SCREEN.position - PHONE.position, SCREEN.size))
		frame.draw_rect(Rect2(PHONE.size.x / 2.0 - 70, 22, 140, 26), Color("050506"))
		frame.draw_circle(Vector2(PHONE.size.x / 2.0 + 48, 35), 6, Color("1b2230")))
	root.add_child(frame)
	# barra de estado
	var status := Control.new()
	status.position = SCREEN.position
	status.size = Vector2(SCREEN.size.x, 44)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.draw.connect(func():
		var mins := int(GS.day_progress() * 600.0) + 8 * 60
		status.draw_string(UI.f_sans_b, Vector2(40, 30), "%02d:%02d" % [int(mins / 60) % 24, mins % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		status.draw_string(UI.f_sans, Vector2(0, 30), "Valdoria Telecom  ▮▮▮▯", HORIZONTAL_ALIGNMENT_RIGHT, SCREEN.size.x - 40, 15, Color(1, 1, 1, 0.75)))
	root.add_child(status)
	content = Control.new()
	content.position = SCREEN.position + Vector2(0, 50)
	content.size = Vector2(SCREEN.size.x, SCREEN.size.y - 50 - 96)
	content.clip_contents = true
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(content)
	# pestañas abajo
	var bar := HBoxContainer.new()
	bar.position = SCREEN.position + Vector2(20, SCREEN.size.y - 92)
	bar.size = Vector2(SCREEN.size.x - 40, 80)
	bar.add_theme_constant_override("separation", 0)
	root.add_child(bar)
	for spec in [["inicio", "Inicio", "prensa"], ["tendencias", "Tendencias", "grafico"], ["publicar", "Publicar", "pluma"], ["mensajes", "Mensajes", "movil"]]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.custom_minimum_size = Vector2((SCREEN.size.x - 40) / 4.0, 76)
		b.icon = UI.icon(spec[2], 40)
		b.add_theme_constant_override("icon_max_width", 26)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = spec[1]
		b.add_theme_font_override("font", UI.f_sans_m)
		b.add_theme_font_size_override("font_size", 14)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var id: String = spec[0]
		b.pressed.connect(func():
			Sfx.play("click", -8.0, 1.4)
			chat_open = {}
			_show(id))
		bar.add_child(b)
		tab_btns[id] = b
	var x := UI.btn("✕", "ghost", 24)
	x.position = Vector2(PHONE.end.x + 16, PHONE.position.y + 10)
	x.pressed.connect(func(): close())
	root.add_child(x)
	# a la izquierda: la cuenta del presidente
	side = UI.vbox(14)
	# (más abajo que los avisos, que salen arriba a la izquierda)
	side.position = Vector2(90, 330)
	side.size = Vector2(500, 700)
	root.add_child(side)
	# a la derecha: qué es esto
	var help := UI.vbox(8)
	help.position = Vector2(1320, 140)
	help.size = Vector2(520, 600)
	root.add_child(help)
	help.add_child(UI.lbl("EL MÓVIL DEL PRESIDENTE", UI.f_sans_b, 15, UI.GOLD))
	var ht := UI.lbl("En Pío se ve lo que piensa la calle de cada noticia. Publicar sobre lo que es tendencia puede darle apoyos... o un disgusto: el tono importa más que el tema. En Mensajes le escriben sus ministros, su madre, la oposición o algún líder extranjero; si los deja en visto, a veces lo pagará.", UI.f_sans, 18, UI.DIM)
	ht.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ht.custom_minimum_size = Vector2(500, 0)
	help.add_child(ht)
	Sfx.play("notify", -10.0, 1.6)
	var start: String = data.get("tab", "mensajes" if Redes.unread() > 0 else "inicio")
	_side()
	_show(start)
	GS.social["seen_day"] = GS.day


func on_escape() -> void:
	if not chat_open.is_empty():
		chat_open = {}
		_show("mensajes")
		return
	close()


func _show(id: String) -> void:
	tab = id
	for k in tab_btns.keys():
		var b: Button = tab_btns[k]
		var on: bool = k == id
		var col := BLUE if on else Color(1, 1, 1, 0.6)
		b.add_theme_color_override("font_color", col)
		b.add_theme_color_override("font_hover_color", BLUE.lightened(0.2))
		b.add_theme_color_override("icon_normal_color", col)
		b.add_theme_color_override("icon_hover_color", BLUE.lightened(0.2))
		if k == "mensajes":
			var n := Redes.unread()
			b.text = "Mensajes (%d)" % n if n > 0 else "Mensajes"
	for c in content.get_children():
		c.queue_free()
	var scroll := ScrollContainer.new()
	scroll.size = content.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var v := UI.vbox(10)
	v.custom_minimum_size = Vector2(content.size.x - 24, 0)
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 22)
	mc.add_theme_constant_override("margin_right", 14)
	mc.add_child(v)
	scroll.add_child(mc)
	match id:
		"inicio":
			_feed(v)
		"tendencias":
			_trends(v)
		"publicar":
			_publish(v)
		"mensajes":
			if chat_open.is_empty():
				_chats(v)
			else:
				_chat(v, chat_open)


func _header(v: VBoxContainer, title: String, sub: String = "") -> void:
	var h := UI.hbox(10)
	var logo := UI.lbl("pío", UI.f_serif_b, 34, BLUE)
	h.add_child(logo)
	var tv := UI.vbox(0)
	tv.add_child(UI.lbl(title, UI.f_sans_b, 22, Color.WHITE))
	if sub != "":
		tv.add_child(UI.lbl(sub, UI.f_sans, 14, Color(1, 1, 1, 0.55)))
	h.add_child(tv)
	v.add_child(h)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.08)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)


static func _count(n: int) -> String:
	if n >= 1000000:
		return "%s M" % UI.num(n / 1000000.0, 1)
	if n >= 1000:
		return "%s mil" % UI.num(n / 1000.0, 1 if n < 10000 else 0)
	return str(n)


# ------------------------------------------------------------------ inicio: lo que dice la gente

func _feed(v: VBoxContainer) -> void:
	_header(v, "Inicio", "Lo que se dice en Valdoria")
	var feed: Array = GS.social.get("feed", [])
	if feed.is_empty():
		v.add_child(UI.lbl("Todavía no hay nada. Vuelva cuando haya noticias.", UI.f_sans, 17, UI.DIM))
		return
	for p in feed.slice(0, 30):
		v.add_child(_post_card(p))


func _post_card(p: Dictionary) -> Control:
	var pc := PanelContainer.new()
	var mood: String = p.get("mood", "neu")
	var stripe: Color = {"pos": UI.GREEN, "neg": UI.RED, "humor": UI.AMBER, "pres": BLUE}.get(mood, Color(1, 1, 1, 0.25))
	var st := UI.sb(Color("151d2b") if mood != "pres" else Color("12233b"), 14, Color(stripe, 0.5), 0, 0, 14)
	st.border_width_left = 4
	pc.add_theme_stylebox_override("panel", st)
	var v := UI.vbox(4)
	pc.add_child(v)
	var h := UI.hbox(8)
	h.add_child(UI.lbl(str(p.get("n", "")), UI.f_sans_b, 16, Color.WHITE))
	if p.get("k", "") in ["medio", "influencer", "pres"]:
		h.add_child(UI.lbl("✓", UI.f_sans_b, 14, BLUE))
	var ago := GS.day - int(p.get("day", GS.day))
	h.add_child(UI.lbl("%s · %s" % [p.get("h", ""), "hoy" if ago <= 0 else ("hace %d d" % ago)], UI.f_sans, 14, Color(1, 1, 1, 0.45)))
	v.add_child(h)
	var t := UI.lbl(str(p.get("t", "")), UI.f_sans, 17, Color(1, 1, 1, 0.92))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(480, 0)
	v.add_child(t)
	v.add_child(UI.lbl("%s me gusta  ·  %s repíos" % [_count(int(p.get("likes", 0))), _count(int(p.get("rt", 0)))], UI.f_sans, 13, Color(1, 1, 1, 0.4)))
	return pc


# ------------------------------------------------------------------ tendencias

func _trends(v: VBoxContainer) -> void:
	_header(v, "Tendencias", "Lo más comentado en Valdoria")
	var trends: Array = GS.social.get("trends", [])
	for i in trends.size():
		var tr: Dictionary = trends[i]
		var box := UI.vbox(2)
		box.add_child(UI.lbl("%d · Tendencia%s" % [i + 1, " · " + _kind_name(str(tr.get("kind", ""))) if tr.get("kind", "") != "" else ""], UI.f_sans, 13, Color(1, 1, 1, 0.45)))
		box.add_child(UI.lbl(str(tr["tag"]), UI.f_sans_b, 21, Color.WHITE))
		box.add_child(UI.lbl("%s píos" % _count(int(tr.get("n", 0))), UI.f_sans, 13, Color(1, 1, 1, 0.45)))
		var idx := i
		var card := Widgets.click_card(box, func():
			sel_trend = idx
			_show("publicar"), 12, Color("151d2b"), Color(1, 1, 1, 0.06))
		card.tooltip_text = "Publicar sobre %s" % tr["tag"]
		v.add_child(card)
	var note := UI.lbl("Haga clic en una tendencia para publicar sobre ella.", UI.f_sans, 14, Color(1, 1, 1, 0.45))
	v.add_child(note)


static func _kind_name(k: String) -> String:
	return {"crisis": "crisis", "ley": "leyes", "escandalo": "escándalo", "oposicion": "política", "orgullo": "país", "meme": "humor",
		"evento": "actualidad", "promesa": "promesas", "economia": "economía", "internacional": "internacional"}.get(k, "")


# ------------------------------------------------------------------ publicar

func _publish(v: VBoxContainer) -> void:
	_header(v, "Publicar", "Desde @Presidencia · %s seguidores" % _count(int(GS.social.get("followers", 0))))
	if not last_result.is_empty():
		_result_card(v, last_result)
		return
	if not Redes.can_post():
		var n := Redes.days_to_post()
		var l := UI.lbl("Su equipo de comunicación le aconseja no publicar todavía: demasiados mensajes seguidos cansan. Podrá volver a hacerlo en %d día%s." % [n, "" if n == 1 else "s"], UI.f_sans, 18, Color(1, 1, 1, 0.75))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(480, 0)
		v.add_child(l)
		return
	var trends: Array = GS.social.get("trends", [])
	if trends.is_empty():
		v.add_child(UI.lbl("No hay de qué hablar ahora mismo.", UI.f_sans, 17, UI.DIM))
		return
	sel_trend = clampi(sel_trend, 0, trends.size() - 1)
	v.add_child(UI.lbl("1 · ¿SOBRE QUÉ?", UI.f_sans_b, 13, BLUE))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.custom_minimum_size = Vector2(500, 0)
	for i in trends.size():
		var b := _pill(str(trends[i]["tag"]), i == sel_trend)
		var idx := i
		b.pressed.connect(func():
			sel_trend = idx
			Sfx.play("click", -8.0, 1.3)
			_show("publicar"))
		flow.add_child(b)
	v.add_child(flow)
	v.add_child(UI.lbl("2 · ¿EN QUÉ TONO?", UI.f_sans_b, 13, BLUE))
	var tf := HFlowContainer.new()
	tf.add_theme_constant_override("h_separation", 6)
	tf.add_theme_constant_override("v_separation", 6)
	tf.custom_minimum_size = Vector2(500, 0)
	for tone in D.TONES.keys():
		var b2 := _pill(D.TONES[tone]["name"], tone == sel_tone)
		b2.tooltip_text = D.TONES[tone]["desc"]
		var tn: String = tone
		b2.pressed.connect(func():
			sel_tone = tn
			Sfx.play("click", -8.0, 1.3)
			_show("publicar"))
		tf.add_child(b2)
	v.add_child(tf)
	var dsc := UI.lbl(D.TONES[sel_tone]["desc"], UI.f_sans, 14, Color(1, 1, 1, 0.5))
	v.add_child(dsc)
	v.add_child(UI.lbl("3 · ASÍ QUEDARÍA", UI.f_sans_b, 13, BLUE))
	var tr: Dictionary = trends[sel_trend]
	var text := Redes.post_text(tr, sel_tone)
	v.add_child(_post_card({"n": GS.pres["name"], "h": "@Presidencia", "k": "pres", "t": text, "mood": "pres", "day": GS.day, "likes": 0, "rt": 0}))
	var go := UI.btn("Publicar", "gold", 20)
	go.custom_minimum_size = Vector2(500, 52)
	go.pressed.connect(func():
		Sfx.play("whoosh", -6.0, 1.4)
		last_result = Redes.publish(tr, sel_tone, text)
		_side()
		_show("publicar"))
	v.add_child(go)


func _pill(text: String, on: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", UI.f_sans_m)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color.WHITE if on else Color(1, 1, 1, 0.75))
	var st := UI.sb(BLUE if on else Color("1b2433"), 18, BLUE if on else Color(1, 1, 1, 0.12), 1)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 7
	st.content_margin_bottom = 7
	b.add_theme_stylebox_override("normal", st)
	var sh := st.duplicate()
	sh.border_color = BLUE.lightened(0.3)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	return b


func _result_card(v: VBoxContainer, post: Dictionary) -> void:
	var res: String = post["result"]
	var col: Color = {"viral": UI.GREEN, "bien": UI.GREEN.lightened(0.2), "nada": Color(1, 1, 1, 0.6), "polemica": UI.AMBER, "desastre": UI.RED}[res]
	v.add_child(_post_card({"n": GS.pres["name"], "h": "@Presidencia", "k": "pres", "t": post["t"], "mood": "pres", "day": GS.day, "likes": post["likes"], "rt": post["rt"]}))
	var big := UI.lbl({"viral": "¡VIRAL!", "bien": "BUENA ACOGIDA", "nada": "SIN PENA NI GLORIA", "polemica": "POLÉMICA", "desastre": "INCENDIO EN LAS REDES"}[res], UI.f_cond_b, 34, col)
	v.add_child(big)
	var msg := UI.lbl(str(post["msg"]), UI.f_sans, 17, Color(1, 1, 1, 0.8))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(480, 0)
	v.add_child(msg)
	var chips := Widgets.effect_chips(post.get("out", []), 15, 6)
	chips.custom_minimum_size = Vector2(480, 0)
	v.add_child(chips)
	v.add_child(UI.lbl("RESPUESTAS", UI.f_sans_b, 13, BLUE))
	for r in post.get("replies", []):
		v.add_child(_post_card({"n": Redes.random_handle()[1], "h": Redes.random_handle()[0], "k": "persona", "t": r, "mood": "neu", "day": GS.day, "likes": randi_range(1, 900), "rt": randi_range(0, 60)}))
	UI.pop_in(big, 0.4)
	Sfx.play("success" if res in ["viral", "bien"] else ("fail" if res in ["polemica", "desastre"] else "click"), -6.0)
	last_result = {}


# ------------------------------------------------------------------ mensajes

func _chats(v: VBoxContainer) -> void:
	_header(v, "Mensajes", "Conversaciones privadas")
	var chats: Array = GS.social.get("chats", [])
	if chats.is_empty():
		v.add_child(UI.lbl("No tiene mensajes. Disfrútelo mientras dure.", UI.f_sans, 17, UI.DIM))
		return
	for c in chats:
		var h := UI.hbox(12)
		var pcx := Control.new()
		pcx.custom_minimum_size = Vector2(56, 56)
		pcx.clip_contents = true
		pcx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mp := Portrait.new()
		mp.position = Vector2(-6, -4)
		mp.size = Vector2(68, 82)
		mp.track_mouse = false
		mp.breathe = false
		pcx.add_child(mp)
		mp.setup(DB.character(str(c["who"])).get("look", {}), false)
		h.add_child(pcx)
		var tv := UI.vbox(2)
		tv.custom_minimum_size = Vector2(330, 0)
		tv.add_child(UI.lbl(str(c["name"]), UI.f_sans_b, 17, Color.WHITE))
		var last_msg: Dictionary = (c["msgs"] as Array).back()
		var prev := UI.lbl(("Usted: " if last_msg["me"] else "") + str(last_msg["t"]).left(48) + ("…" if str(last_msg["t"]).length() > 48 else ""), UI.f_sans, 14, Color(1, 1, 1, 0.55))
		tv.add_child(prev)
		h.add_child(tv)
		var st: String = c["state"]
		var badge := UI.lbl({"nuevo": "NUEVO", "respondido": "", "visto": "VISTO"}[st], UI.f_sans_b, 13, BLUE if st == "nuevo" else Color(1, 1, 1, 0.35))
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(badge)
		var chat: Dictionary = c
		v.add_child(Widgets.click_card(h, func():
			chat_open = chat
			Sfx.play("click", -8.0, 1.3)
			_show("mensajes"), 10, Color("151d2b") if st != "nuevo" else Color("17263d"), Color(1, 1, 1, 0.06)))


func _chat(v: VBoxContainer, c: Dictionary) -> void:
	var back := UI.btn("← Mensajes", "ghost", 16)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func():
		chat_open = {}
		_show("mensajes"))
	v.add_child(back)
	var hh := UI.vbox(0)
	hh.add_child(UI.lbl(str(c["name"]), UI.f_sans_b, 22, Color.WHITE))
	hh.add_child(UI.lbl(str(c.get("role", "")), UI.f_sans, 14, Color(1, 1, 1, 0.5)))
	v.add_child(hh)
	for m in c["msgs"]:
		var row := HBoxContainer.new()
		var bubble := PanelContainer.new()
		bubble.add_theme_stylebox_override("panel", UI.sb(BUBBLE_ME if m["me"] else BUBBLE_THEM, 16, Color(0, 0, 0, 0), 0, 0, 12))
		var t := UI.lbl(str(m["t"]), UI.f_sans, 17, Color.WHITE)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(360, 0)
		bubble.add_child(t)
		if m["me"]:
			row.add_child(UI.spacer(0, 0, true))
		row.add_child(bubble)
		v.add_child(row)
	if c["state"] == "nuevo":
		v.add_child(UI.lbl("RESPONDER", UI.f_sans_b, 13, BLUE))
		var d := Redes.chat_def(str(c["id"]))
		var reps: Array = d.get("replies", [])
		for i in reps.size():
			var rp: Dictionary = reps[i]
			var rv := UI.vbox(6)
			var rt := UI.lbl(Redes._fmt(str(rp["t"])), UI.f_sans_m, 17, Color.WHITE)
			rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rt.custom_minimum_size = Vector2(460, 0)
			rv.add_child(rt)
			var chips := Widgets.effect_chips(GS.preview(rp.get("fx", {})), 13, 4)
			chips.custom_minimum_size = Vector2(460, 0)
			rv.add_child(chips)
			var idx := i
			v.add_child(Widgets.click_card(rv, func():
				Sfx.play("whoosh", -10.0, 1.6)
				Redes.answer_chat(c, idx)
				_side()
				_show("mensajes"), 10, Color("1b2a40"), Color(BLUE, 0.4)))
	elif c["state"] == "visto":
		v.add_child(UI.lbl("Lo dejó en visto.", UI.f_sans, 14, Color(1, 1, 1, 0.4)))


# ------------------------------------------------------------------ la cuenta del presidente (izquierda)

func _side() -> void:
	for c in side.get_children():
		c.queue_free()
	side.add_child(UI.lbl("SU CUENTA", UI.f_sans_b, 15, UI.GOLD))
	var h := UI.hbox(14)
	var pcx := Control.new()
	pcx.custom_minimum_size = Vector2(90, 90)
	pcx.clip_contents = true
	pcx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mp := Portrait.new()
	mp.position = Vector2(-10, -6)
	mp.size = Vector2(110, 132)
	mp.track_mouse = false
	mp.breathe = false
	pcx.add_child(mp)
	mp.setup(GS.pres["look"], false)
	h.add_child(pcx)
	var nv := UI.vbox(2)
	nv.add_child(UI.lbl(GS.pres["name"], UI.f_serif_b, 28, UI.CREAM))
	nv.add_child(UI.lbl("@Presidencia  ✓", UI.f_sans_m, 16, BLUE))
	nv.add_child(UI.lbl("%s seguidores" % _count(int(GS.social.get("followers", 0))), UI.f_sans_b, 18, UI.TEXT))
	h.add_child(nv)
	side.add_child(h)
	# ánimo en las redes: lo que dice la gente de las últimas noticias
	var pos := 0
	var neg := 0
	for p in (GS.social.get("feed", []) as Array).slice(0, 25):
		if p.get("mood", "") == "pos":
			pos += 1
		elif p.get("mood", "") == "neg":
			neg += 1
	var mood := 50.0 if pos + neg == 0 else 100.0 * pos / float(pos + neg)
	side.add_child(Widgets.section("Ánimo en las redes"))
	var ml := UI.lbl("%d %% de mensajes a favor" % int(mood), UI.f_cond_b, 30, UI.color_for(mood))
	side.add_child(ml)
	side.add_child(Widgets.bar(mood, 480, 10, UI.color_for(mood)))
	side.add_child(Widgets.section("Sus últimas publicaciones"))
	var posts: Array = GS.social.get("posts", [])
	if posts.is_empty():
		side.add_child(UI.lbl("Todavía no ha publicado nada.", UI.f_sans, 17, UI.DIM))
	for p in posts.slice(0, 3):
		var pv := UI.vbox(2)
		var tl := UI.lbl("«%s»" % str(p["t"]), UI.f_serif, 17, UI.TEXT)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.custom_minimum_size = Vector2(480, 0)
		pv.add_child(tl)
		var rc: Color = {"viral": UI.GREEN, "bien": UI.GREEN, "nada": UI.DIM, "polemica": UI.AMBER, "desastre": UI.RED}.get(p["result"], UI.DIM)
		pv.add_child(UI.lbl("%s · %s me gusta · %s" % [UI.date_short(int(p["day"])), _count(int(p["likes"])), {"viral": "viral", "bien": "buena acogida", "nada": "sin más", "polemica": "polémica", "desastre": "desastre"}.get(p["result"], "")], UI.f_sans, 14, rc))
		side.add_child(pv)
