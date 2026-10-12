extends "res://scripts/ui/overlay.gd"
## Sesión de control al Gobierno: duelo rápido con la oposición. Réplicas cronometradas y combos.
## Con el despacho 3D se juega en el hemiciclo, sin ventanas: el líder de la oposición se levanta y ataca (subtítulos),
## las réplicas son tarjetas sobre el atril de la tribuna (clic o teclas 1-3) antes de que se apague la luz del tiempo,
## y las bancadas aplauden, se ponen en pie o abuchean. Sin el despacho 3D, el dibujo 2D de siempre.

const Widgets := preload("res://scripts/ui/widgets.gd")
const TimerBar := preload("res://scripts/ui/timer_bar.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const P := preload("res://scripts/data/press_data.gd")
const W := preload("res://scripts/data/world_data.gd")
const Congress := preload("res://scripts/stages3d/congress_3d.gd")

const ROUNDS := 5
const ROWS := 7
const HEMI_C := Vector2(960, 1010)
const HEMI_SX := 1.5
## Color de la franja de cada tarjeta de réplica
const REPLY_COLS := {"datos": Color("3f7fd0"), "empatia": Color("3f9f6a"), "elegancia": Color("c9a55c"), "realismo": Color("d98b2b"), "contraataque": Color("c8443a")}
const ORDER_LINES := ["¡Silencio, señorías!", "Señorías, guarden silencio, por favor.", "¡Orden! Les ruego que respeten el turno de palabra.", "Señorías, esto no es un campo de fútbol."]

var opp_ch: Dictionary
## Retratos 2D o personajes 3D en el hemiciclo: todos exponen talking / mood / anger
var me
var opp
var scene: Control
## Hemiciclo 3D (con el despacho 3D): las réplicas son tarjetas del atril y los marcadores llevan la pregunta, quién
## habla y el aplausómetro. Si no, el dibujo 2D de siempre
var stage
var speaker_lbl: Label
var rounds := []
var ri := -1
var combo := 0
var best_combo := 0
var points := 0.0
var answered := false
var q_lbl: Label
var topic_lbl: Label
var replies: HBoxContainer
var timer: Control
var combo_lbl: Label
var feedback: Label
var seats := []
var cheer_side := 0
var cheer_t := 0.0
var _t := 0.0
## Presentación (en 3D, un nodo vacío: al borrarlo con queue_free() las pruebas empiezan la sesión directamente)
var intro: Node
## Aplausómetro de los marcadores: -1 (gana la oposición) .. 1 (gana el Gobierno)
var applause := 0.0
var _applause_now := 0.0
var _meter: Control
## Turno en curso: los avisos de un turno anterior que lleguen tarde se descartan
var _gen := 0


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.96)
	opp_ch = DB.character("opo")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# escaños en gradas (izquierda: Gobierno, derecha: oposición)
	for row in ROWS:
		var r := 250.0 + row * 44.0
		var n := 26 + row * 6
		for k in n:
			var a := PI + PI * (k + 0.5) / n
			var pos := HEMI_C + Vector2(cos(a) * r * HEMI_SX, sin(a) * r)
			var side := 0 if pos.x < 960 else 1
			seats.append({"p": pos, "side": side, "ph": rng.randf() * TAU})
	if Congress.enabled():
		stage = Congress.new()
		stage.pres_look = Perfil.apply_outfit(GS.pres["look"])
		stage.opp_look = opp_ch["look"]
		root.add_child(stage)
		me = stage.me
		opp = stage.opp
		_build_3d()
	else:
		_build_2d()
	rounds = DB.opposition_attacks(ROUNDS)
	_intro()


## f dentro de sec segundos, si la sesión sigue abierta
func _after(sec: float, f: Callable) -> void:
	get_tree().create_timer(sec).timeout.connect(func():
		if not closing:
			f.call())


func _opp_name() -> String:
	return String(opp_ch["name"])


# ------------------------------------------------------------------ hemiciclo 3D

func _build_3d() -> void:
	# la cuenta atrás no se ve: la sigue la luz del atril
	timer = TimerBar.new()
	timer.modulate.a = 0.0
	timer.position = Vector2(-500, -500)
	root.add_child(timer)
	timer.timeout.connect(func():
		if not answered:
			_answer(null))
	stage.timer_src = timer
	_build_board(stage.board)
	# chuleta del gabinete en una esquina del atril (se lee al pasar el ratón)
	stage.note_card({"tag": "Chuleta del gabinete", "title": "Según el ataque",
		"desc": "Cifras → Datos y gestión\nEmoción → Empatía\nPersonal → Elegancia\nPromesas → ¿Quién lo paga?",
		"col": Color("4a4036"), "title_k": 0.115, "desc_k": 0.074}, stage.top_point(0.462, 0.02), stage.top_normal(), Vector2(0.17, 0.17), 7.0)


## Marcadores del hemiciclo: la pregunta en curso, quién tiene la palabra, el aplausómetro y el combo
func _build_board(bd: Control) -> void:
	var bw := bd.size.x
	var v := UI.vbox(0)
	v.position = Vector2(0, 12)
	v.size = Vector2(bw, 0)
	bd.add_child(v)
	v.add_child(UI.lbl("CONGRESO DE LOS DIPUTADOS · SESIÓN DE CONTROL AL GOBIERNO", UI.f_sans_b, 24, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	topic_lbl = UI.lbl("Sesión de control", UI.f_serif_b, 48, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(topic_lbl)
	speaker_lbl = UI.lbl("", UI.f_sans_m, 30, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(speaker_lbl)
	_meter = Control.new()
	_meter.position = Vector2(130, 186)
	_meter.size = Vector2(bw - 260, 84)
	_meter.draw.connect(_draw_applause)
	bd.add_child(_meter)
	feedback = UI.lbl("", UI.f_cond_b, 46, UI.GOLD_L, HORIZONTAL_ALIGNMENT_CENTER)
	feedback.position = Vector2(0, 288)
	feedback.size = Vector2(bw * 0.6, 70)
	bd.add_child(feedback)
	combo_lbl = UI.lbl("", UI.f_cond_b, 60, UI.GOLD_L, HORIZONTAL_ALIGNMENT_CENTER)
	combo_lbl.position = Vector2(bw * 0.6, 280)
	combo_lbl.size = Vector2(bw * 0.4, 80)
	combo_lbl.pivot_offset = Vector2(bw * 0.2, 40)
	bd.add_child(combo_lbl)


## Aplausómetro: el Gobierno a la izquierda (como su bancada vista desde la tribuna), la oposición a la derecha
func _draw_applause() -> void:
	var w := _meter.size.x
	var y := 34.0
	var h := 28.0
	var own_c := Color(W.PARTIES[GS.pres["party"]]["color"])
	var opp_c := Color(W.PARTIES[W.PLAYER_PARTIES[GS.pres["party"]]["opp"]]["color"])
	_meter.draw_string(UI.f_sans_b, Vector2(0, 22), "GOBIERNO", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, own_c.lightened(0.3))
	_meter.draw_string(UI.f_sans_b, Vector2(0, 22), "APLAUSÓMETRO", HORIZONTAL_ALIGNMENT_CENTER, w, 20, UI.DIM)
	_meter.draw_string(UI.f_sans_b, Vector2(0, 22), "OPOSICIÓN", HORIZONTAL_ALIGNMENT_RIGHT, w, 22, opp_c.lightened(0.3))
	var mid := w * 0.5 - _applause_now * w * 0.5
	_meter.draw_rect(Rect2(0, y, mid, h), own_c.darkened(0.15))
	_meter.draw_rect(Rect2(mid, y, w - mid, h), opp_c.darkened(0.15))
	for k in 9:
		var x := w * (k + 1) / 10.0
		_meter.draw_line(Vector2(x, y), Vector2(x, y + h), Color(0, 0, 0, 0.25), 2.0)
	_meter.draw_rect(Rect2(0, y, w, h), Color(UI.GOLD, 0.7), false, 2.0)
	_meter.draw_rect(Rect2(mid - 6, y - 10, 12, h + 20), Color.WHITE)


func _intro() -> void:
	if stage == null:
		_intro_2d()
		return
	intro = Node.new()
	add_child(intro)
	stage.title_card("Miércoles · Pleno del Congreso", "Sesión de control al Gobierno",
		"%s le hará %d preguntas. Elija su réplica entre las tarjetas del atril antes de que se apague la luz del tiempo. Encadenar aciertos multiplica el efecto." % [_opp_name(), ROUNDS], 0.0)
	speaker_lbl.text = "Pregunta del líder de la oposición al presidente del Gobierno"
	# del plano general a la tribuna: en el atril esperan dos tarjetas
	_after(1.6, func():
		if ri >= 0 or not is_instance_valid(intro):
			return
		stage.pov(true)
		stage.cam_speed = 1.3
		stage.notice("Haga clic en una tarjeta del atril")
		stage.deal_cards([
			{"tag": "Sesión de control", "title": "Tomar la palabra", "desc": "Subir a la tribuna y contestar a las preguntas de la oposición.", "col": UI.GOLD, "icon": "microfono"},
			{"tag": "Escurrir el bulto", "title": "Delegar en la vicepresidenta", "desc": "Estabilidad −2 · Clase media −1. La prensa lo notará.", "col": Color("6b7280"), "icon": "salir"},
		], stage.top_center(), stage.top_normal(), 0.27, _on_intro_card, Vector2(0.235, 0.15), 0.9))


func _on_intro_card(i: int) -> void:
	if i == 0:
		if is_instance_valid(intro):
			intro.queue_free()
		Sfx.play("gavel", -2.0)
		stage.hide_title()
		stage.notice("")
		_next()
	else:
		_delegate()


func _delegate() -> void:
	GS.apply_fx({"estabilidad": -2, "clase_media": -1}, "Sesión de control")
	GS.push_news("El presidente esquiva la sesión de control", 1)
	close()


func _seconds() -> float:
	var s := 7.5
	if GS.has_trait("orador"):
		s += 3.0
	if GS.stress > 75:
		s -= 1.5
	# en el hemiciclo hay que leer las tarjetas (la pregunta ya se ha oído entera)
	if stage != null:
		s += 1.0
	return s


## La réplica que mejor funciona contra la pregunta en curso (para las capturas de prueba)
func best_reply() -> Dictionary:
	var r: Dictionary = rounds[clampi(ri, 0, rounds.size() - 1)]
	var best: Dictionary = P.DEBATE_REPLIES[0]
	for rep in P.DEBATE_REPLIES:
		if float(rep["vs"].get(r["kind"], 0.0)) > float(best["vs"].get(r["kind"], 0.0)):
			best = rep
	return best


## Tres réplicas: la mejor para este ataque y dos al azar
func _options(r: Dictionary) -> Array:
	var best: Dictionary = P.DEBATE_REPLIES[0]
	for rep in P.DEBATE_REPLIES:
		if float(rep["vs"].get(r["kind"], 0.0)) > float(best["vs"].get(r["kind"], 0.0)):
			best = rep
	var opts := [best]
	var others: Array = P.DEBATE_REPLIES.duplicate()
	others.erase(best)
	others.shuffle()
	opts.append(others[0])
	opts.append(others[1])
	opts.shuffle()
	return opts


## Cómo cae una réplica (null: se ha quedado callado)
func _score(rep, r: Dictionary) -> float:
	if rep == null:
		return 0.1
	var s := float(rep["vs"].get(r["kind"], 0.5))
	if rep.get("uses_meter", false):
		var mval: float = clampf(150.0 - GS.debt_ratio(), 0.0, 100.0) if r["meter"] == "deuda" else GS.meters.get(r["meter"], 50.0)
		s *= clampf(mval / 55.0, 0.3, 1.4)
	if rep.get("risky", false):
		s += randf_range(-0.3, 0.3)
	s += randf_range(-0.05, 0.05)
	return s


func _next() -> void:
	ri += 1
	answered = false
	_gen += 1
	if stage == null:
		_next_2d()
		return
	if ri >= rounds.size():
		_finish()
		return
	var r: Dictionary = rounds[ri]
	var gen := _gen
	stage.clear_cards()
	stage.hide_title()
	stage.caption("", "")
	stage.notice("")
	topic_lbl.text = "Pregunta %d de %d · %s" % [ri + 1, rounds.size(), r["topic"]]
	speaker_lbl.text = "Tiene la palabra %s, líder de la oposición" % _opp_name()
	feedback.text = ""
	# el líder de la oposición se levanta en su escaño, señala a la tribuna y pregunta
	stage.opp_ask()
	stage.shot_opp()
	if ri == 0:
		var trat := "la señora" if String(opp_ch.get("look", {}).get("g", "m")) == "f" else "el señor"
		stage.say(stage.order(), "Tiene la palabra %s %s." % [trat, _opp_name().split(" ")[-1]], UI.GOLD, stage.chair_pres, 0.2)
	stage.say(_opp_name() + " · Líder de la oposición", r["attack"], UI.RED.lightened(0.3), opp, 0.5, true)
	stage.after_lines(_deal_replies.bind(gen))


## Vuelta a la tribuna: la pregunta queda arriba y las tres réplicas, en el atril
func _deal_replies(gen: int) -> void:
	if gen != _gen or answered or closing or ri >= rounds.size():
		return
	var r: Dictionary = rounds[ri]
	stage.caption(_opp_name() + " pregunta · " + String(r["topic"]), r["attack"])
	stage.pov(true)
	stage.cut()
	var opts := _options(r)
	var specs := []
	for rep in opts:
		specs.append({"tag": "Réplica", "title": rep["name"], "desc": rep["desc"], "icon": rep["icon"], "col": REPLY_COLS.get(rep["id"], UI.GOLD), "title_k": 0.14, "desc_k": 0.088})
	stage.deal_cards(specs, stage.top_center(), stage.top_normal(), 0.243, func(i: int): _answer(opts[i]), Vector2(0.225, 0.145))
	stage.notice("Elija su réplica: haga clic en una tarjeta o pulse 1, 2 o 3")
	speaker_lbl.text = "Turno de réplica del presidente del Gobierno"
	timer.start(_seconds(), "SU TURNO")


func _answer(rep) -> void:
	if answered or ri < 0 or ri >= rounds.size():
		return
	answered = true
	timer.stop()
	if stage == null:
		_answer_2d(rep)
		return
	var gen := _gen
	var r: Dictionary = rounds[ri]
	var s := _score(rep, r)
	stage.notice("")
	stage.clear_cards()
	speaker_lbl.text = "Tiene la palabra el presidente del Gobierno, %s" % GS.pres["name"]
	# contraplano: el presidente en el atril, mirando al hemiciclo
	stage.me_reply()
	stage.shot_me()
	var who: String = GS.pres["name"] + " · Presidente del Gobierno"
	# (si contesta antes de que acabe la pregunta, le corta)
	stage.clear_lines()
	if rep != null:
		stage.say(who, (P.DEBATE_LINES.get(rep["id"], ["..."]) as Array).pick_random(), UI.GOLD_L, me, 0.25)
	else:
		stage.say(who, "Eh... Señorías, yo... Bueno, como iba diciendo...", UI.GOLD_L, me, 0.25)
	stage.after_lines(_react.bind(s, rep != null, gen))


## La réplica cae en el hemiciclo: ¡zasca!, murmullos o abucheos; luego, la siguiente pregunta
func _react(s: float, replied: bool, gen: int) -> void:
	if gen != _gen or closing:
		return
	stage.caption("", "")
	var loud := false
	if s >= 0.75:
		combo += 1
		best_combo = maxi(best_combo, combo)
		var mult := 1.0 + 0.5 * (combo - 1)
		points += s * mult
		applause = clampf(applause + 0.28 + 0.06 * combo, -1.0, 1.0)
		feedback.text = ["¡Zasca!", "¡Directo a la línea de flotación!", "Su bancada se pone en pie"].pick_random()
		feedback.add_theme_color_override("font_color", UI.GREEN)
		# plano de su bancada, en pie
		stage.react("zasca")
		stage.shot_bench(true)
		stage.big_text(["¡ZASCA!", "¡TOMA YA!", "¡ZASCA EN TODA REGLA!"][mini(combo - 1, 2)], UI.GOLD_L, 150)
		stage.shake(0.6)
		Sfx.play("applause", -4.0)
		if combo >= 2:
			_after(0.45, func(): stage.big_text("COMBO x%d" % combo, Color("ffd66b"), 92, Vector2(960, 560), 0.9))
		_after(0.9, func(): stage.say(_opp_name(), (P.OPP_REACTIONS["good"] as Array).pick_random(), UI.RED.lightened(0.3), opp, 0.3))
		loud = true
	elif s >= 0.5:
		points += s
		applause = clampf(applause + 0.1, -1.0, 1.0)
		feedback.text = "Réplica correcta. La oposición murmura."
		feedback.add_theme_color_override("font_color", UI.AMBER)
		stage.react("ok")
		stage.big_text("RÉPLICA CORRECTA", UI.AMBER, 84)
		Sfx.play("applause", -14.0)
	else:
		combo = 0
		points += s * 0.5
		applause = clampf(applause - 0.32, -1.0, 1.0)
		feedback.text = "¡Abucheos en la bancada de la oposición!" if replied else "Silencio... ¡le han pillado sin respuesta!"
		feedback.add_theme_color_override("font_color", UI.RED)
		# el líder de la oposición se ríe en su escaño, con su bancada
		stage.react("boo" if replied else "silence")
		stage.shot_opp()
		stage.big_text("¡ABUCHEOS!" if replied else "¡SE HA QUEDADO EN BLANCO!", UI.RED.lightened(0.15), 120 if replied else 96)
		stage.shake(0.25)
		Sfx.play("crowd", -4.0, 1.2)
		_after(0.7, func(): stage.say(_opp_name(), (P.OPP_REACTIONS["bad"] as Array).pick_random(), UI.RED.lightened(0.3), opp, 0.3))
		loud = true
	combo_lbl.text = ("COMBO x%d" % combo) if combo >= 2 else ""
	if combo >= 2:
		combo_lbl.scale = Vector2(1.5, 1.5)
		combo_lbl.create_tween().tween_property(combo_lbl, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# tras el alboroto, la presidenta pide silencio
	if loud and randf() < 0.65:
		_after(2.2, func(): stage.say(stage.order(), ORDER_LINES.pick_random(), UI.GOLD, stage.chair_pres, 0.2))
	_after(3.0 if loud else 2.2, func():
		if gen == _gen:
			stage.after_lines(_next_if.bind(gen)))


func _next_if(gen: int) -> void:
	if gen == _gen and not closing:
		_next()


func _finish() -> void:
	var avg := points / float(rounds.size())
	var won := avg >= 0.62
	var fx := {"approval": snappedf((avg - 0.55) * 7.0, 0.1), "estabilidad": 3 if won else -3}
	var opp_party: String = W.PLAYER_PARTIES[GS.pres["party"]]["opp"]
	fx["party"] = {GS.pres["party"]: 2.0 if won else -1.0, opp_party: -2.0 if won else 1.0}
	var out := GS.apply_fx(fx, "Sesión de control")
	GS.push_news(("El presidente se impone a %s en la sesión de control" % _opp_name()) if won else ("%s acorrala al presidente en el Congreso" % _opp_name()), 2)
	GS.log_history("Sesión de control", "Victoria" if won else "Derrota")
	if won:
		Perfil.earn(Perfil.S.EARN["control"], "Sesión de control ganada")
	if best_combo >= 3:
		Perfil.unlock("martillo")
	var title := "HA GANADO EL CARA A CARA" if won else "LE HAN GANADO EL CARA A CARA"
	var stats := "Mejor combo: x%d · Valoración: %d/100" % [maxi(best_combo, 1), int(clampf(avg, 0.0, 1.5) / 1.5 * 100)]
	Sfx.play("gavel", -2.0)
	if stage == null:
		_finish_2d(title, stats, won, out)
		return
	timer.stop()
	stage.clear_cards()
	stage.caption("", "")
	stage.notice("")
	stage.finish(won)
	applause = 0.8 if won else -0.8
	topic_lbl.text = "Fin de la sesión de control"
	speaker_lbl.text = "Se levanta la sesión"
	feedback.text = "Victoria del Gobierno" if won else "Victoria de la oposición"
	feedback.add_theme_color_override("font_color", UI.GREEN if won else UI.RED)
	combo_lbl.text = ""
	Sfx.play("applause", -4.0)
	stage.say(stage.order(), "Se levanta la sesión.", UI.GOLD, stage.chair_pres, 0.5)
	stage.end_card(title, UI.GREEN if won else UI.RED, stats, Widgets.effect_chips(out, 16, 8), "Abandonar el hemiciclo", func(): close())


func _process(delta: float) -> void:
	_t += delta
	cheer_t = maxf(0.0, cheer_t - delta)
	if scene != null:
		scene.queue_redraw()
	if _meter != null:
		_applause_now = lerpf(_applause_now, applause, minf(1.0, delta * 3.0))
		_meter.queue_redraw()


func on_escape() -> void:
	pass


# ------------------------------------------------------------------ hemiciclo 2D (sin el despacho 3D)

func _build_2d() -> void:
	scene = Control.new()
	UI.full(scene)
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.draw.connect(_draw_scene)
	root.add_child(scene)
	me = Portrait.new()
	me.position = Vector2(160, 292)
	me.size = Vector2(360, 432)
	me.track_mouse = false
	root.add_child(me)
	me.setup(GS.pres["look"], true)
	opp = Portrait.new()
	opp.position = Vector2(1400, 292)
	opp.size = Vector2(360, 432)
	opp.track_mouse = false
	root.add_child(opp)
	opp.setup(opp_ch["look"], true)
	# atriles con el nombre de cada orador
	var lect := Control.new()
	UI.full(lect)
	lect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var own_name: String = GS.pres["name"]
	var opp_name: String = opp_ch["name"]
	lect.draw.connect(func():
		for i in 2:
			var x := 150.0 if i == 0 else 1390.0
			var rr := Rect2(x, 690, 380, 92)
			lect.draw_rect(rr, Color("3b2416"))
			lect.draw_rect(Rect2(x, 690, 380, 10), Color("5a3a22"))
			lect.draw_rect(Rect2(x + 14, 712, 352, 56), Color(0, 0, 0, 0.25))
			lect.draw_rect(rr, Color(UI.GOLD, 0.5), false, 2.0)
			lect.draw_string(UI.f_sans_b, Vector2(x, 734), "PRESIDENTE DEL GOBIERNO" if i == 0 else "LÍDER DE LA OPOSICIÓN", HORIZONTAL_ALIGNMENT_CENTER, 380, 13, UI.GOLD)
			lect.draw_string(UI.f_serif_b, Vector2(x, 760), own_name if i == 0 else opp_name, HORIZONTAL_ALIGNMENT_CENTER, 380, 20, UI.CREAM))
	root.add_child(lect)
	var head := UI.vbox(0)
	head.position = Vector2(0, 116)
	head.size = Vector2(1920, 80)
	root.add_child(head)
	head.add_child(UI.lbl("CONGRESO DE LOS DIPUTADOS · SESIÓN DE CONTROL AL GOBIERNO", UI.f_sans_b, 15, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	topic_lbl = UI.lbl("", UI.f_serif_b, 34, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	head.add_child(topic_lbl)
	var qp := UI.panel(Color(0.035, 0.05, 0.085, 0.94), 10, Color(UI.RED, 0.5), 18)
	qp.position = Vector2(560, 220)
	qp.custom_minimum_size = Vector2(800, 0)
	root.add_child(qp)
	var qv := UI.vbox(6)
	qp.add_child(qv)
	qv.add_child(UI.lbl(opp_ch["name"].to_upper() + " PREGUNTA:", UI.f_sans_b, 14, UI.RED.lightened(0.3)))
	q_lbl = UI.lbl("", UI.f_serif, 25, UI.TEXT)
	q_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_lbl.custom_minimum_size = Vector2(760, 0)
	qv.add_child(q_lbl)
	combo_lbl = UI.lbl("", UI.f_cond_b, 52, UI.GOLD_L, HORIZONTAL_ALIGNMENT_CENTER)
	combo_lbl.position = Vector2(660, 470)
	combo_lbl.size = Vector2(600, 70)
	combo_lbl.pivot_offset = Vector2(300, 35)
	root.add_child(combo_lbl)
	feedback = UI.lbl("", UI.f_sans_b, 24, UI.GOLD_L, HORIZONTAL_ALIGNMENT_CENTER)
	feedback.position = Vector2(560, 545)
	feedback.size = Vector2(800, 40)
	root.add_child(feedback)
	timer = TimerBar.new()
	timer.position = Vector2(260, 808)
	timer.size = Vector2(1400, 10)
	root.add_child(timer)
	timer.timeout.connect(func():
		if not answered:
			_answer(null))
	replies = UI.hbox(14)
	replies.position = Vector2(240, 830)
	replies.size = Vector2(1440, 0)
	root.add_child(replies)


func _intro_2d() -> void:
	intro = UI.panel(Color(0.03, 0.05, 0.09, 0.97), 12, Color(UI.GOLD, 0.6), 30)
	var ip := intro as PanelContainer
	ip.custom_minimum_size = Vector2(800, 0)
	var v := UI.vbox(14)
	ip.add_child(v)
	v.add_child(UI.lbl("MIÉRCOLES · PLENO DEL CONGRESO", UI.f_sans_b, 15, UI.GOLD))
	v.add_child(UI.lbl("Sesión de control", UI.f_serif_b, 40, UI.CREAM))
	var t := UI.lbl("%s le hará %d preguntas rápidas. Elija la réplica adecuada antes de que se acabe el tiempo: datos contra cifras, empatía contra emoción, elegancia contra ataques personales y realismo contra promesas. Encadenar aciertos multiplica el efecto." % [opp_ch["name"], ROUNDS], UI.f_sans, 18, UI.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(740, 0)
	v.add_child(t)
	var h := UI.hbox(14)
	var go := UI.btn("Subir al estrado", "gold", 22)
	go.pressed.connect(func():
		intro.queue_free()
		Sfx.play("gavel", -2.0)
		_next())
	h.add_child(go)
	var no := UI.btn("Delegar en la vicepresidenta", "ghost", 18)
	no.pressed.connect(_delegate)
	h.add_child(no)
	v.add_child(h)
	ip.position = Vector2(560, 380)
	root.add_child(ip)
	UI.pop_in(ip)


func _next_2d() -> void:
	feedback.text = ""
	for c in replies.get_children():
		c.queue_free()
	if ri >= rounds.size():
		_finish()
		return
	var r: Dictionary = rounds[ri]
	topic_lbl.text = "Pregunta %d de %d · %s" % [ri + 1, rounds.size(), r["topic"]]
	q_lbl.text = "«" + r["attack"] + "»"
	opp.talking = true
	opp.mood = -0.2
	get_tree().create_timer(1.0).timeout.connect(func(): opp.talking = false)
	for rep in _options(r):
		var v := UI.vbox(4)
		v.custom_minimum_size = Vector2(440, 76)
		var h := UI.hbox(8)
		h.add_child(UI.icon_rect(rep["icon"], 26, UI.GOLD_L))
		h.add_child(UI.lbl(rep["name"], UI.f_sans_b, 20, UI.TEXT))
		v.add_child(h)
		var d := UI.lbl(rep["desc"], UI.f_sans, 15, UI.DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(420, 0)
		v.add_child(d)
		var rr: Dictionary = rep
		var card := Widgets.click_card(v, func(): _answer(rr), 14)
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		replies.add_child(card)
		UI.pop_in(card, 0.2)
	timer.start(_seconds(), "SU TURNO")


func _answer_2d(rep) -> void:
	for c in replies.get_children():
		c.set_meta("enabled", false)
		c.modulate.a = 0.35
	var s := _score(rep, rounds[ri])
	if rep != null:
		me.talking = true
		get_tree().create_timer(1.0).timeout.connect(func(): me.talking = false)
	if s >= 0.75:
		combo += 1
		best_combo = maxi(best_combo, combo)
		var mult := 1.0 + 0.5 * (combo - 1)
		points += s * mult
		feedback.text = ["¡Zasca!", "¡Directo a la línea de flotación!", "Su bancada se pone en pie"].pick_random()
		feedback.add_theme_color_override("font_color", UI.GREEN)
		cheer_side = 0
		cheer_t = 1.6
		Sfx.play("applause", -6.0)
		me.mood = 0.7
		opp.mood = -0.6
		opp.anger = 0.5
	elif s >= 0.5:
		points += s
		feedback.text = "Réplica correcta. La oposición murmura."
		feedback.add_theme_color_override("font_color", UI.AMBER)
		me.mood = 0.2
	else:
		combo = 0
		points += s * 0.5
		feedback.text = "¡Abucheos en la bancada de la oposición!" if rep != null else "Silencio... ¡le han pillado sin respuesta!"
		feedback.add_theme_color_override("font_color", UI.RED)
		cheer_side = 1
		cheer_t = 1.6
		Sfx.play("crowd", -6.0, 1.2)
		me.mood = -0.5
		opp.mood = 0.6
	combo_lbl.text = ("COMBO x%d" % combo) if combo >= 2 else ""
	if combo >= 2:
		combo_lbl.scale = Vector2(1.5, 1.5)
		combo_lbl.create_tween().tween_property(combo_lbl, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	UI.pop_in(feedback, 0.2)
	var gen := _gen
	_after(1.8, func():
		opp.anger = 0.0
		if gen == _gen:
			_next())


func _finish_2d(title: String, stats: String, won: bool, out: Array) -> void:
	var p := UI.panel(Color(0.03, 0.05, 0.09, 0.97), 12, Color(UI.GOLD, 0.6), 30)
	p.custom_minimum_size = Vector2(800, 0)
	var v := UI.vbox(14)
	p.add_child(v)
	v.add_child(UI.lbl(title, UI.f_cond_b, 46, UI.GREEN if won else UI.RED))
	v.add_child(UI.lbl(stats, UI.f_sans_m, 19, UI.TEXT))
	var chips := Widgets.effect_chips(out, 16, 8)
	chips.custom_minimum_size = Vector2(740, 0)
	v.add_child(chips)
	var b := UI.btn("Abandonar el hemiciclo", "gold", 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.pressed.connect(func(): close())
	v.add_child(b)
	p.position = Vector2(560, 360)
	root.add_child(p)
	UI.pop_in(p)


func _draw_scene() -> void:
	scene.draw_rect(Rect2(0, 100, 1920, 980), Color("140d10"))
	for i in 12:
		scene.draw_rect(Rect2(i * 160 + 40, 100, 70, 360), Color(0.55, 0.12, 0.14, 0.07))
	scene.draw_rect(Rect2(0, 440, 1920, 4), Color(UI.GOLD, 0.12))
	# bancadas del hemiciclo
	for row in ROWS:
		var r := 250.0 + row * 44.0
		var pts := PackedVector2Array()
		for k in 49:
			var a := PI + PI * k / 48.0
			pts.append(HEMI_C + Vector2(cos(a) * r * HEMI_SX, sin(a) * r + 10.0))
		scene.draw_polyline(pts, Color("2b1a14"), 20.0, true)
		scene.draw_polyline(pts, Color("4a2e20"), 3.0, true)
	var own_c := Color(W.PARTIES[GS.pres["party"]]["color"])
	var opp_c := Color(W.PARTIES[W.PLAYER_PARTIES[GS.pres["party"]]["opp"]]["color"])
	for s in seats:
		var jump := 0.0
		if cheer_t > 0.0 and s["side"] == cheer_side:
			jump = absf(sin(_t * 12.0 + s["ph"])) * 6.0
		var c: Color = own_c if s["side"] == 0 else opp_c
		var p: Vector2 = s["p"] - Vector2(0, jump)
		scene.draw_circle(p, 8.0, c.darkened(0.3))
		scene.draw_circle(p - Vector2(0, 10), 5.5, Color(0.86, 0.72, 0.6).darkened(0.35))
	# tribuna de oradores
	scene.draw_rect(Rect2(880, 930, 160, 90), Color("3b2416"))
	scene.draw_rect(Rect2(880, 930, 160, 90), Color(UI.GOLD, 0.35), false, 2.0)
	scene.draw_rect(Rect2(0, 1040, 1920, 40), Color(0, 0, 0, 0.4))
