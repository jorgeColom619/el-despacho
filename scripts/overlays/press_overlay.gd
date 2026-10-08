extends "res://scripts/ui/overlay.gd"
## Rueda de prensa / entrevista: preguntas con tiempo límite y reacción de la sala.

const Widgets := preload("res://scripts/ui/widgets.gd")
const Typewriter := preload("res://scripts/ui/typewriter.gd")
const TimerBar := preload("res://scripts/ui/timer_bar.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const OfficeArt := preload("res://scripts/office/office_art.gd")
const W := preload("res://scripts/data/world_data.gd")
const PressRoom := preload("res://scripts/stages3d/press_room_3d.gd")
const Studio := preload("res://scripts/stages3d/studio_3d.gd")

const TONE_NAMES := {"honesto": "Sincero", "evasivo": "Evasivo", "firme": "Firme", "humor": "Con humor", "ataque": "Al ataque"}
const TONE_COLS := {"honesto": Color("5fb4e0"), "evasivo": Color("9aa4b5"), "firme": Color("e5a93a"), "humor": Color("7ed27e"), "ataque": Color("e2574c")}

var mode := "rueda"
var scene: Control
var questions := []
var qi := -1
## Retrato 2D o periodista 3D que pregunta: los dos exponen talking / mood
var journalist
var j_name: Label
var j_outlet: Label
var q_text: RichTextLabel
var answers: VBoxContainer
var timer: Control
var worm := []
var score := 0.0
var total_fx := {}
var flashes := []
var raised := -1
var heads := []
var answered := false
var outlet: Dictionary
var _t := 0.0
var worm_ctrl: Control
var feedback: Label
var intro_panel: Control
var qpanel: Control
## Con el despacho 3D: la sala de prensa (o el plató de Canal 7) en primera persona, y toda la interfaz en la
## pantalla del atril (o de la mesa). Si no, el dibujo 2D de siempre
var stage
## Donde van los paneles: la pantalla 3D o la superposición 2D
var host: Control
var _ans_font := 20
var _ans_w := 840.0


func build() -> void:
	mode = data.get("mode", "rueda")
	dim.color = Color(0.01, 0.015, 0.03, 0.94)
	worm = [50.0]
	if PressRoom.enabled():
		stage = PressRoom.new() if mode == "rueda" else Studio.new()
		root.add_child(stage)
		_build_screen(stage.ui)
	else:
		_build_2d()
	var n_q := 4 if mode == "rueda" else 5
	questions = DB.press_questions(n_q)
	_intro()


## La interfaz en la pantalla 3D: quién pregunta y la pregunta arriba, el tiempo, las respuestas y la reacción
func _build_screen(scr: Control) -> void:
	host = scr
	var w := scr.size.x
	_ans_font = 29
	_ans_w = w - 250.0
	scr.add_child(_at(UI.lbl("RUEDA DE PRENSA · PALACIO DE GOBIERNO" if mode == "rueda" else "ENTREVISTA EN DIRECTO · CANAL 7", UI.f_sans_b, 21, UI.GOLD), Vector2(36, 16)))
	worm_ctrl = Control.new()
	worm_ctrl.position = Vector2(w - 360, 10)
	worm_ctrl.size = Vector2(330, 96)
	worm_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	worm_ctrl.draw.connect(_draw_worm)
	scr.add_child(worm_ctrl)
	var qv := UI.vbox(2)
	qv.position = Vector2(36, 46)
	qv.visible = false
	qpanel = qv
	scr.add_child(qv)
	j_outlet = UI.lbl("", UI.f_sans_b, 21, UI.GOLD)
	qv.add_child(j_outlet)
	j_name = UI.lbl("", UI.f_serif_b, 32, UI.CREAM)
	qv.add_child(j_name)
	q_text = Typewriter.new()
	q_text.custom_minimum_size = Vector2(w - 72, 0)
	q_text.add_theme_font_override("normal_font", UI.f_serif)
	q_text.add_theme_font_size_override("normal_font_size", 33)
	q_text.add_theme_color_override("default_color", UI.TEXT)
	qv.add_child(UI.spacer(0, 6))
	qv.add_child(q_text)
	feedback = UI.lbl("", UI.f_sans_b, 27, UI.GOLD_L)
	feedback.position = Vector2(36, 252)
	scr.add_child(feedback)
	timer = TimerBar.new()
	timer.position = Vector2(36, 298)
	timer.size = Vector2(w - 72, 12)
	scr.add_child(timer)
	timer.timeout.connect(_on_timeout)
	answers = UI.vbox(10)
	answers.position = Vector2(36, 322)
	answers.size = Vector2(w - 72, 0)
	scr.add_child(answers)


static func _at(c: Control, p: Vector2) -> Control:
	c.position = p
	return c


## Pone un panel en el centro de la pantalla 3D (o donde iba en 2D)
func _place(p: Control, pos2d: Vector2) -> void:
	if host != null:
		# en la pantalla 3D el panel se ve más grande (va dentro de un contenedor escalado: pop_in anima su escala)
		var k := 1.3
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.scale = Vector2(k, k)
		host.add_child(holder)
		holder.add_child(p)
		holder.position = ((host.size - p.get_combined_minimum_size() * k) * 0.5).floor()
	else:
		p.position = pos2d
		root.add_child(p)


func _build_2d() -> void:
	scene = Control.new()
	UI.full(scene)
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.draw.connect(_draw_scene)
	root.add_child(scene)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for row in 3:
		var y := 560.0 + row * 120.0
		var n := 11 + row * 2
		for k in n:
			var x := 60.0 + (1800.0 / n) * (k + 0.5) + rng.randf_range(-14, 14)
			heads.append({"p": Vector2(x, y + rng.randf_range(-8, 8)), "s": 1.0 + row * 0.22, "c": Color.from_hsv(rng.randf(), rng.randf_range(0.1, 0.4), rng.randf_range(0.18, 0.4)), "hair": Color(W.HAIR_COL[rng.randi() % 7]).darkened(0.3), "cam": rng.randf() < 0.18})
	var pod := TextureRect.new()
	pod.texture = OfficeArt.tex("podium")
	pod.position = Vector2(610, 780)
	pod.size = Vector2(700, 420)
	pod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pod)
	# panel de la pregunta
	var qp := UI.panel(Color(0.035, 0.05, 0.085, 0.95), 12, Color(UI.GOLD, 0.5), 22)
	qp.position = Vector2(60, 130)
	qp.custom_minimum_size = Vector2(860, 0)
	qp.visible = false
	qpanel = qp
	root.add_child(qp)
	var qv := UI.vbox(12)
	qp.add_child(qv)
	var jh := UI.hbox(16)
	var jf := Control.new()
	jf.custom_minimum_size = Vector2(110, 110)
	jf.clip_contents = true
	jf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	journalist = Portrait.new()
	journalist.position = Vector2(-10, -4)
	journalist.size = Vector2(130, 156)
	journalist.track_mouse = false
	jf.add_child(journalist)
	jh.add_child(jf)
	var jv := UI.vbox(2)
	j_outlet = UI.lbl("", UI.f_sans_b, 14, UI.GOLD)
	jv.add_child(j_outlet)
	j_name = UI.lbl("", UI.f_serif_b, 28, UI.CREAM)
	jv.add_child(j_name)
	jh.add_child(jv)
	qv.add_child(jh)
	q_text = Typewriter.new()
	q_text.custom_minimum_size = Vector2(810, 0)
	q_text.add_theme_font_override("normal_font", UI.f_serif)
	q_text.add_theme_font_size_override("normal_font_size", 27)
	q_text.add_theme_color_override("default_color", UI.TEXT)
	qv.add_child(q_text)
	feedback = UI.lbl("", UI.f_sans_b, 20, UI.GOLD_L)
	qv.add_child(feedback)
	# respuestas
	var ap := UI.vbox(10)
	ap.position = Vector2(980, 130)
	ap.size = Vector2(880, 500)
	root.add_child(ap)
	ap.add_child(UI.lbl("RUEDA DE PRENSA · PALACIO DE GOBIERNO" if mode == "rueda" else "ENTREVISTA EN DIRECTO · CANAL 7", UI.f_sans_b, 15, UI.GOLD))
	timer = TimerBar.new()
	timer.custom_minimum_size = Vector2(880, 8)
	ap.add_child(UI.spacer(0, 12))
	ap.add_child(timer)
	timer.timeout.connect(_on_timeout)
	answers = UI.vbox(10)
	ap.add_child(answers)
	# medidor de la sala
	worm_ctrl = Control.new()
	worm_ctrl.position = Vector2(1330, 860)
	worm_ctrl.size = Vector2(540, 160)
	worm_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	worm_ctrl.draw.connect(_draw_worm)
	root.add_child(worm_ctrl)


func _intro() -> void:
	intro_panel = UI.panel(Color(0.03, 0.05, 0.09, 0.97), 12, Color(UI.GOLD, 0.6), 30)
	intro_panel.custom_minimum_size = Vector2(800, 0)
	var v := UI.vbox(16)
	intro_panel.add_child(v)
	v.add_child(UI.lbl("LA PRENSA LE ESPERA", UI.f_sans_b, 15, UI.GOLD))
	v.add_child(UI.lbl("Rueda de prensa" if mode == "rueda" else "Entrevista en Canal 7", UI.f_serif_b, 40, UI.CREAM))
	var t := UI.lbl("Responderá a %d preguntas. Cada respuesta tiene un tono y un efecto en la opinión pública; tiene unos segundos para contestar. El silencio se paga caro." % questions.size(), UI.f_sans, 19, UI.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(740, 0)
	v.add_child(t)
	var h := UI.hbox(14)
	var go := UI.btn("Salir a la sala", "gold", 22)
	go.pressed.connect(func():
		intro_panel.queue_free()
		Sfx.loop_start("crowd", "crowd", -16.0)
		Sfx.play("applause", -10.0)
		_next())
	h.add_child(go)
	var no := UI.btn("Cancelar la comparecencia", "ghost", 18)
	no.pressed.connect(func():
		GS.apply_fx({"clase_media": -2, "estabilidad": -2}, "Rueda de prensa")
		GS.push_news("El presidente cancela su comparecencia ante los medios", 2)
		close())
	h.add_child(no)
	v.add_child(h)
	_place(intro_panel, Vector2(560, 360))
	UI.pop_in(intro_panel)


func _next() -> void:
	qpanel.visible = true
	qi += 1
	answered = false
	for c in answers.get_children():
		c.queue_free()
	feedback.text = ""
	if qi >= questions.size():
		_finish()
		return
	var q: Dictionary = questions[qi]
	if mode == "rueda":
		outlet = W.OUTLETS.pick_random()
		var g := "m" if randf() < 0.5 else "f"
		if stage != null:
			# alza la mano un periodista de la sala: el nombre va con su aspecto
			journalist = stage.ask()
			g = journalist.get_meta("g", g)
		else:
			journalist.setup(DB.rand_look(g), false)
			raised = randi() % heads.size()
		j_name.text = DB.rand_name(g)
	else:
		outlet = {"name": "Canal 7", "bias": 0.0, "tag": "Televisión"}
		if stage != null:
			journalist = stage.ask()
		else:
			journalist.setup(W.CHARACTERS["periodista"]["look"], false)
		j_name.text = W.CHARACTERS["periodista"]["name"]
	j_outlet.text = "%s · %s" % [outlet["name"].to_upper(), outlet["tag"]]
	journalist.talking = true
	q_text.play(GS.fmt(q["q"]), 50.0)
	await q_text.typed
	journalist.talking = false
	if stage != null:
		stage.stop_asking()
	_show_answers(q)


func _show_answers(q: Dictionary) -> void:
	var opts: Array = q["a"].duplicate()
	opts = opts.filter(func(a): return not a.has("req_policy") or a["req_policy"] in GS.policies)
	for i in opts.size():
		var a: Dictionary = opts[i]
		var tone: String = a.get("tone", "honesto")
		var l := UI.lbl(GS.fmt(a["t"]), UI.f_sans_m, _ans_font, UI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(_ans_w, 0)
		# en la pantalla 3D el tono va a la izquierda de la frase (una línea por respuesta); en 2D, encima
		var v: BoxContainer = UI.vbox(6) if host == null else UI.hbox(16)
		var chip := Widgets.chip("", TONE_NAMES.get(tone, tone), TONE_COLS.get(tone, UI.GOLD), 14 if host == null else 19)
		if host != null:
			chip.custom_minimum_size = Vector2(150, 0)
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			v.add_child(chip)
		else:
			var th := UI.hbox(10)
			th.add_child(chip)
			v.add_child(th)
		v.add_child(l)
		var idx := i
		var card := Widgets.click_card(v, func(): _answer(opts[idx]), 14)
		answers.add_child(card)
		UI.pop_in(card, 0.25)
	timer.start(13.0 * (0.8 if GS.stress > 75 else 1.0), "TIEMPO PARA RESPONDER")
	timer.visible = true


func _answer(a: Dictionary) -> void:
	if answered:
		return
	answered = true
	timer.stop()
	# en la pantalla del atril la reacción ocupa el sitio del reloj
	timer.visible = host == null
	for c in answers.get_children():
		c.set_meta("enabled", false)
		c.modulate.a = 0.4
	var s := float(a.get("s", 0))
	var tone: String = a.get("tone", "honesto")
	var bias: float = outlet.get("bias", 0.0)
	var my_ideo: float = W.PARTIES[GS.pres["party"]]["ideo"]
	var hostile := signf(bias) != signf(my_ideo) and absf(bias) > 20.0
	if tone == "ataque" and hostile:
		s += 2.0
	if tone == "honesto" and absf(bias) < 15.0:
		s += 1.0
	if tone == "humor":
		s += randf_range(-3.0, 3.0)
	if GS.flags.has("ley_medios"):
		s += 1.0
	s += randf_range(-1.0, 1.0)
	score += s
	worm.append(clampf(worm.back() + s * 3.5, 0.0, 100.0))
	var fx: Dictionary = a.get("fx", {})
	GS.apply_fx(fx, "Rueda de prensa")
	if s >= 4:
		feedback.text = "La sala asiente. Buena respuesta."
		Sfx.play("applause", -8.0)
		journalist.mood = 0.3
	elif s >= 0:
		feedback.text = "Respuesta correcta, sin más."
		journalist.mood = 0.0
	else:
		feedback.text = "Murmullos en la sala. No ha convencido."
		Sfx.play("crowd", -6.0, 1.2)
		journalist.mood = -0.4
	if stage != null:
		stage.react(s)
	else:
		for i in 4:
			flashes.append({"p": Vector2(randf_range(80, 1840), randf_range(520, 900)), "t": -i * 0.12})
	Sfx.play("flash", -6.0)
	UI.pop_in(feedback)
	await get_tree().create_timer(1.8).timeout
	_next()


func _on_timeout() -> void:
	if answered:
		return
	answered = true
	timer.visible = host == null
	score -= 5.0
	worm.append(clampf(worm.back() - 16.0, 0.0, 100.0))
	feedback.text = "Silencio incómodo... La prensa lo destrozará mañana."
	Sfx.play("fail", -4.0)
	GS.apply_fx({"clase_media": -2}, "Rueda de prensa")
	await get_tree().create_timer(1.8).timeout
	_next()


func _finish() -> void:
	Sfx.loop_stop("crowd")
	timer.stop()
	var n := maxf(1.0, questions.size())
	var avg := score / n
	var fx := {"approval": clampf(avg * 0.9, -5.0, 5.0)}
	if avg >= 3.0:
		fx["estabilidad"] = 2
	elif avg < 0.0:
		fx["estabilidad"] = -2
	var out := GS.apply_fx(fx, "Rueda de prensa")
	var verdict := "Comparecencia brillante" if avg >= 3.5 else ("Comparecencia correcta" if avg >= 1.0 else "Comparecencia desastrosa")
	GS.push_news("%s: %s" % ["Rueda de prensa del presidente" if mode == "rueda" else "Entrevista al presidente en Canal 7", verdict.to_lower()], 2)
	GS.log_history("Rueda de prensa", verdict)
	if host != null:
		qpanel.visible = false
		timer.visible = false
		feedback.text = ""
	var p := UI.panel(Color(0.03, 0.05, 0.09, 0.97), 12, Color(UI.GOLD, 0.6), 30)
	p.custom_minimum_size = Vector2(800, 0)
	var v := UI.vbox(14)
	p.add_child(v)
	v.add_child(UI.lbl(verdict.to_upper(), UI.f_cond_b, 48, UI.GREEN if avg >= 3.0 else (UI.AMBER if avg >= 1.0 else UI.RED)))
	v.add_child(UI.lbl("Valoración media de sus respuestas: %s" % UI.num(avg, 1), UI.f_sans_m, 19, UI.TEXT))
	var chips := Widgets.effect_chips(out, 16, 8)
	chips.custom_minimum_size = Vector2(740, 0)
	v.add_child(chips)
	var b := UI.btn("Volver al despacho", "gold", 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.pressed.connect(func(): close())
	v.add_child(b)
	_place(p, Vector2(560, 360))
	UI.pop_in(p)


func _process(delta: float) -> void:
	_t += delta
	worm_ctrl.queue_redraw()
	if scene == null:
		return
	for f in flashes:
		f["t"] += delta
	flashes = flashes.filter(func(f): return f["t"] < 0.4)
	if randf() < delta * 0.6:
		flashes.append({"p": Vector2(randf_range(80, 1840), randf_range(520, 900)), "t": 0.0})
		if randf() < 0.3:
			Sfx.play("flash", -14.0)
	scene.queue_redraw()


func _draw_scene() -> void:
	# fondo: cortina azul con logotipo
	var top := Color("13254a") if mode == "rueda" else Color("1a1030")
	for i in 40:
		var x := i * 48.0
		var shade := 0.85 + 0.15 * sin(i * 1.7)
		scene.draw_rect(Rect2(x, 100, 48, 520), top * shade)
	scene.draw_rect(Rect2(0, 100, 1920, 520), Color(0, 0, 0, 0.25))
	var logo_c := Vector2(960, 330)
	scene.draw_circle(logo_c, 90, Color(UI.GOLD, 0.08))
	scene.draw_string(UI.f_serif_b, Vector2(0, 470), "GOBIERNO DE VALDORIA" if mode == "rueda" else "CANAL 7 · EN DIRECTO", HORIZONTAL_ALIGNMENT_CENTER, 1920, 34, Color(UI.GOLD, 0.25))
	# suelo
	scene.draw_rect(Rect2(0, 600, 1920, 480), Color("0c0f16"))
	# periodistas
	for i in heads.size():
		var h: Dictionary = heads[i]
		var p: Vector2 = h["p"]
		var s: float = h["s"]
		var bob := sin(_t * 1.3 + i) * 2.0
		scene.draw_rect(Rect2(p + Vector2(-34, -10 + bob) * s, Vector2(68, 90) * s), h["c"])
		scene.draw_circle(p + Vector2(0, -32 + bob) * s, 22 * s, Color(0.55, 0.45, 0.38).darkened(0.35))
		scene.draw_circle(p + Vector2(0, -40 + bob) * s, 20 * s, h["hair"])
		if h["cam"]:
			scene.draw_rect(Rect2(p + Vector2(-26, -58) * s, Vector2(52, 34) * s), Color(0.08, 0.08, 0.09))
			scene.draw_circle(p + Vector2(0, -41) * s, 11 * s, Color(0.2, 0.22, 0.26))
		if i == raised and not answered:
			scene.draw_line(p + Vector2(26, -10) * s, p + Vector2(40, -86) * s, h["c"].lightened(0.2), 12 * s)
			scene.draw_circle(p + Vector2(40, -90) * s, 9 * s, Color(0.55, 0.45, 0.38).darkened(0.2))
	for f in flashes:
		var ft: float = f["t"]
		if ft < 0.0:
			continue
		var a := 1.0 - ft / 0.4
		scene.draw_circle(f["p"], 90 * a + 10, Color(1, 1, 1, 0.12 * a))
		scene.draw_circle(f["p"], 16, Color(1, 1, 1, 0.9 * a))
	# oscurecer abajo
	scene.draw_rect(Rect2(0, 900, 1920, 180), Color(0, 0, 0, 0.3))


func _draw_worm() -> void:
	var w := worm_ctrl.size.x
	var h := worm_ctrl.size.y
	worm_ctrl.draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.05, 0.09, 0.9))
	worm_ctrl.draw_rect(Rect2(0, 0, w, h), Color(UI.GOLD, 0.4), false, 1.0)
	worm_ctrl.draw_string(UI.f_sans_b, Vector2(14, 22), "REACCIÓN DE LA OPINIÓN PÚBLICA", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)
	worm_ctrl.draw_line(Vector2(14, h * 0.58), Vector2(w - 14, h * 0.58), Color(1, 1, 1, 0.15), 1.0)
	var series := worm.duplicate()
	if series.size() < 2:
		series.append(series[0])
	var last: float = series.back()
	Widgets.draw_line_chart(worm_ctrl, Rect2(14, 34, w - 28, h - 50), series, UI.color_for(last), 0.0, 100.0, 3.0)


func on_escape() -> void:
	pass
