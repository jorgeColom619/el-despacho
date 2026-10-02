extends "res://scripts/ui/overlay.gd"
## Sesión de control al Gobierno: duelo rápido con la oposición. Réplicas cronometradas y combos.

const Widgets := preload("res://scripts/ui/widgets.gd")
const TimerBar := preload("res://scripts/ui/timer_bar.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const P := preload("res://scripts/data/press_data.gd")
const W := preload("res://scripts/data/world_data.gd")

const ROUNDS := 5
const ROWS := 7
const HEMI_C := Vector2(960, 1010)
const HEMI_SX := 1.5

var opp_ch: Dictionary
var me: Control
var opp: Control
var scene: Control
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
var intro: Control


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
	var pool: Array = P.DEBATE.duplicate()
	pool.shuffle()
	for i in ROUNDS:
		rounds.append(pool[i % pool.size()])
	_intro()


func _intro() -> void:
	intro = UI.panel(Color(0.03, 0.05, 0.09, 0.97), 12, Color(UI.GOLD, 0.6), 30)
	intro.position = Vector2(560, 380)
	intro.custom_minimum_size = Vector2(800, 0)
	var v := UI.vbox(14)
	intro.add_child(v)
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
	no.pressed.connect(func():
		GS.apply_fx({"estabilidad": -2, "clase_media": -1}, "Sesión de control")
		GS.push_news("El presidente esquiva la sesión de control", 1)
		close())
	h.add_child(no)
	v.add_child(h)
	root.add_child(intro)
	UI.pop_in(intro)


func _seconds() -> float:
	var s := 7.5
	if GS.has_trait("orador"):
		s += 3.0
	if GS.stress > 75:
		s -= 1.5
	return s


func _next() -> void:
	ri += 1
	answered = false
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
	# tres réplicas: la mejor para este ataque + dos al azar
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
	for rep in opts:
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


func _answer(rep) -> void:
	if answered:
		return
	answered = true
	timer.stop()
	for c in replies.get_children():
		c.set_meta("enabled", false)
		c.modulate.a = 0.35
	var r: Dictionary = rounds[ri]
	var s := 0.1
	if rep != null:
		s = float(rep["vs"].get(r["kind"], 0.5))
		if rep.get("uses_meter", false):
			var mval: float = clampf(150.0 - GS.debt_ratio(), 0.0, 100.0) if r["meter"] == "deuda" else GS.meters.get(r["meter"], 50.0)
			s *= clampf(mval / 55.0, 0.3, 1.4)
		if rep.get("risky", false):
			s += randf_range(-0.3, 0.3)
		s += randf_range(-0.05, 0.05)
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
	await get_tree().create_timer(1.8).timeout
	opp.anger = 0.0
	_next()


func _finish() -> void:
	var avg := points / float(rounds.size())
	var won := avg >= 0.62
	var fx := {"approval": snappedf((avg - 0.55) * 7.0, 0.1), "estabilidad": 3 if won else -3}
	var opp_party: String = W.PLAYER_PARTIES[GS.pres["party"]]["opp"]
	fx["party"] = {GS.pres["party"]: 2.0 if won else -1.0, opp_party: -2.0 if won else 1.0}
	var out := GS.apply_fx(fx, "Sesión de control")
	GS.push_news(("El presidente se impone a %s en la sesión de control" % opp_ch["name"]) if won else ("%s acorrala al presidente en el Congreso" % opp_ch["name"]), 2)
	GS.log_history("Sesión de control", "Victoria" if won else "Derrota")
	if won:
		Perfil.earn(Perfil.S.EARN["control"], "Sesión de control ganada")
	if best_combo >= 3:
		Perfil.unlock("martillo")
	var p := UI.panel(Color(0.03, 0.05, 0.09, 0.97), 12, Color(UI.GOLD, 0.6), 30)
	p.position = Vector2(560, 360)
	p.custom_minimum_size = Vector2(800, 0)
	var v := UI.vbox(14)
	p.add_child(v)
	v.add_child(UI.lbl("HA GANADO EL CARA A CARA" if won else "LE HAN GANADO EL CARA A CARA", UI.f_cond_b, 46, UI.GREEN if won else UI.RED))
	v.add_child(UI.lbl("Mejor combo: x%d · Valoración: %d/100" % [maxi(best_combo, 1), int(clampf(avg, 0.0, 1.5) / 1.5 * 100)], UI.f_sans_m, 19, UI.TEXT))
	var chips := Widgets.effect_chips(out, 16, 8)
	chips.custom_minimum_size = Vector2(740, 0)
	v.add_child(chips)
	var b := UI.btn("Abandonar el hemiciclo", "gold", 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.pressed.connect(func(): close())
	v.add_child(b)
	root.add_child(p)
	UI.pop_in(p)
	Sfx.play("gavel", -2.0)


func _process(delta: float) -> void:
	_t += delta
	cheer_t = maxf(0.0, cheer_t - delta)
	scene.queue_redraw()


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


func on_escape() -> void:
	pass
