extends "res://scripts/ui/overlay.gd"
## Debate televisado contra el líder de la oposición.
## Con los minijuegos en 3D se juega en el plató de Canal 7: dos atriles enfrentados, la moderadora en su mesa y el
## público. La moderadora abre cada bloque, el líder de la oposición ataca (subtítulos) y las réplicas son tarjetas
## sobre el atril del presidente (clic o teclas 1-4) antes de que se apague la luz del tiempo; el «¿quién va ganando?»
## sale en los marcadores del plató. Sin ellos, el dibujo 2D de siempre.

const Widgets := preload("res://scripts/ui/widgets.gd")
const Typewriter := preload("res://scripts/ui/typewriter.gd")
const TimerBar := preload("res://scripts/ui/timer_bar.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const P := preload("res://scripts/data/press_data.gd")
const W := preload("res://scripts/data/world_data.gd")
const Debate3D := preload("res://scripts/stages3d/debate_3d.gd")

## Color de la franja de cada tarjeta de réplica (los de la sesión de control)
const REPLY_COLS := {"datos": Color("3f7fd0"), "empatia": Color("3f9f6a"), "elegancia": Color("c9a55c"), "realismo": Color("d98b2b"), "contraataque": Color("c8443a")}
const SECONDS := 12.0

var electoral := false
## Retratos 2D o personajes 3D en el plató: todos exponen talking / mood / anger
var me
var opp
var opp_ch: Dictionary
var rounds := []
var ri := -1
var bubble_opp: RichTextLabel
var bubble_me: RichTextLabel
var topic_lbl: Label
var replies: HBoxContainer
var timer: Control
var worm := [50.0]
var worm_ctrl: Control
var scores := []
var answered := false
var _t := 0.0
var result_lbl: Label
## Plató 3D (con los minijuegos en 3D)
var stage
## Presentación (en 3D, un nodo vacío: al borrarlo con queue_free() las pruebas empiezan el debate directamente)
var intro: Node
## Turno en curso: los avisos de un turno anterior que lleguen tarde se descartan
var _gen := 0


func build() -> void:
	electoral = data.get("electoral", false)
	dim.color = Color(0.01, 0.015, 0.03, 0.97)
	opp_ch = DB.character("opo")
	rounds = DB.opposition_attacks(4)
	if Debate3D.enabled():
		stage = Debate3D.new()
		stage.pres_look = Perfil.apply_outfit(GS.pres["look"])
		stage.opp_look = opp_ch["look"]
		stage.pres_name = GS.pres["name"]
		stage.opp_name = opp_ch["name"]
		stage.own_color = Color(W.PARTIES[GS.pres["party"]]["color"])
		stage.opp_color = Color(W.PARTIES[_opp_party()]["color"])
		stage.wall_title = "Debate electoral" if electoral else "El debate"
		root.add_child(stage)
		me = stage.me
		opp = stage.opp
		_build_3d()
		_intro_3d()
	else:
		_build_2d()


func _opp_party() -> String:
	return W.PLAYER_PARTIES[GS.pres["party"]]["opp"]


## f dentro de sec segundos, si el debate sigue abierto
func _after(sec: float, f: Callable) -> void:
	get_tree().create_timer(sec).timeout.connect(func():
		if not closing:
			f.call())


## Cómo cae una réplica (null: se ha quedado callado)
func _score(rep, r: Dictionary) -> float:
	if rep == null:
		return 0.15
	var s := float(rep["vs"].get(r["kind"], 0.5))
	if rep.get("uses_meter", false):
		var mval := 50.0
		if r["meter"] == "deuda":
			mval = clampf(150.0 - GS.debt_ratio(), 0.0, 100.0)
		else:
			mval = GS.meters.get(r["meter"], 50.0)
		s *= clampf(mval / 55.0, 0.3, 1.4)
	if rep.get("risky", false):
		s += randf_range(-0.35, 0.35)
	s += randf_range(-0.1, 0.1)
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
	topic_lbl.text = "Bloque %d de %d · %s" % [ri + 1, rounds.size(), r["topic"]]
	result_lbl.text = ""
	# la moderadora abre el bloque y da la palabra al líder de la oposición
	stage.shot_mod()
	var lead := "Empezamos. Primer bloque" if ri == 0 else ("Último bloque" if ri == rounds.size() - 1 else "Pasamos al siguiente bloque")
	stage.say(_mod_who(), "%s: %s. Tiene la palabra %s." % [lead, String(r["topic"]).to_lower(), opp_ch["name"]], UI.GOLD, stage.moderator, 0.2)
	stage.after_lines(func():
		if gen != _gen or closing or answered:
			return
		stage.opp_attack()
		stage.shot_opp()
		stage.say(_opp_who(), r["attack"], UI.RED.lightened(0.3), opp, 0.5, true)
		stage.after_lines(_deal_replies.bind(gen)))


func _mod_who() -> String:
	return String(W.CHARACTERS["periodista"]["name"]) + " · Moderadora"


func _opp_who() -> String:
	return String(opp_ch["name"]) + " · " + String(W.PARTIES[_opp_party()]["short"])


func _reply(rep) -> void:
	if answered or ri < 0 or ri >= rounds.size():
		return
	answered = true
	timer.stop()
	var r: Dictionary = rounds[ri]
	var s := _score(rep, r)
	scores.append(s)
	var line := "..."
	if rep != null:
		line = DB.fresh_line(DB.debate_lines(rep["id"]), "rl_" + str(rep["id"]))
	if stage == null:
		_reply_2d(s, line)
		return
	var gen := _gen
	stage.notice("")
	stage.clear_cards()
	stage.me_reply()
	stage.shot_me()
	# (si contesta antes de que acabe el ataque, le corta)
	stage.clear_lines()
	stage.say(GS.pres["name"] + " · " + String(W.PARTIES[GS.pres["party"]]["short"]), line if rep != null else "Eh... Bueno, yo... Como decía antes...", UI.GOLD_L, me, 0.25)
	stage.after_lines(_react.bind(s, rep != null, gen))


func _finish() -> void:
	var avg := 0.0
	for s in scores:
		avg += s
	avg /= maxf(1.0, scores.size())
	var won := avg >= 0.6
	var fx := {}
	if electoral:
		GS.campaign_bonus += (avg - 0.55) * 14.0
		fx["approval"] = (avg - 0.55) * 8.0
	else:
		fx["approval"] = (avg - 0.55) * 10.0
		fx["estabilidad"] = 3 if won else -3
	var out := GS.apply_fx(fx, "Debate")
	GS.push_news(("%s gana el debate frente a %s" % [GS.pres["name"], opp_ch["name"]]) if won else ("%s se impone en el debate a %s" % [opp_ch["name"], GS.pres["name"]]), 3)
	GS.log_history("Debate televisado", "Victoria" if won else "Derrota")
	GS.remember("debate_ganado" if won else "debate_perdido", {})
	if won:
		Perfil.earn(Perfil.S.EARN["debate"], "Debate ganado")
		Perfil.unlock("orador")
	var title := "HA GANADO EL DEBATE" if won else "HA PERDIDO EL DEBATE"
	var poll := "Encuesta flash: %d%% le da la victoria" % int(clampf(avg * 90.0, 10.0, 90.0))
	Sfx.play("sting_win" if won else "sting_lose", -6.0)
	if stage == null:
		_finish_2d(title, poll, won, out)
		return
	timer.stop()
	stage.clear_cards()
	stage.caption("", "")
	stage.notice("")
	stage.finish(won)
	topic_lbl.text = "Fin del debate"
	result_lbl.text = poll
	result_lbl.add_theme_color_override("font_color", UI.GREEN if won else UI.RED)
	Sfx.play("applause", -4.0)
	stage.say(_mod_who(), "Hasta aquí el debate. Gracias a los dos candidatos y a ustedes por acompañarnos. Buenas noches.", UI.GOLD, stage.moderator, 0.5)
	stage.end_card(title, UI.GREEN if won else UI.RED, poll, Widgets.effect_chips(out, 16, 8), "Salir del plató", func(): close())


func _process(delta: float) -> void:
	_t += delta
	if worm_ctrl != null:
		worm_ctrl.queue_redraw()


func _draw_worm() -> void:
	var w := worm_ctrl.size.x
	var h := worm_ctrl.size.y
	var big := stage != null
	worm_ctrl.draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.05, 0.09, 0.9))
	worm_ctrl.draw_rect(Rect2(0, 0, w, h), Color(UI.GOLD, 0.4), false, 2.0 if big else 1.0)
	var top := 46.0 if big else 34.0
	worm_ctrl.draw_string(UI.f_sans_b, Vector2(18 if big else 14, 32 if big else 22), "¿QUIÉN VA GANANDO?", HORIZONTAL_ALIGNMENT_LEFT, -1, 24 if big else 13, UI.DIM)
	var series := worm.duplicate()
	if series.size() < 2:
		series.append(series[0])
	var last: float = series.back()
	var ch := Rect2(14, top, w - 28, h - top - 14)
	worm_ctrl.draw_line(Vector2(14, ch.position.y + ch.size.y * 0.5), Vector2(w - 14, ch.position.y + ch.size.y * 0.5), Color(1, 1, 1, 0.2), 1.0)
	Widgets.draw_line_chart(worm_ctrl, ch, series, UI.color_for(last), 0.0, 100.0, 5.0 if big else 3.0)
	worm_ctrl.draw_string(UI.f_cond_b, Vector2(0, 40 if big else h - 8), "%d%%" % int(last), HORIZONTAL_ALIGNMENT_RIGHT, w - 18, 40 if big else 22, UI.color_for(last))


func on_escape() -> void:
	pass


# ------------------------------------------------------------------ plató 3D

func _build_3d() -> void:
	# la cuenta atrás no se ve: la sigue la luz del atril
	timer = TimerBar.new()
	timer.modulate.a = 0.0
	timer.position = Vector2(-500, -500)
	root.add_child(timer)
	timer.timeout.connect(func():
		if not answered:
			_reply(null))
	stage.timer_src = timer
	_build_board(stage.board)


## Marcador del plató: el rótulo del programa, el bloque, los dos candidatos y el «¿quién va ganando?»
func _build_board(bd: Control) -> void:
	var bw := bd.size.x
	var head := Control.new()
	head.size = Vector2(bw, 60)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.draw.connect(func():
		head.draw_rect(Rect2(0, 0, bw, 60), Color(0.06, 0.08, 0.14))
		head.draw_circle(Vector2(44, 30), 22, Color("c62828"))
		head.draw_string(UI.f_sans_b, Vector2(22, 44), "7", HORIZONTAL_ALIGNMENT_CENTER, 44, 32, Color.WHITE)
		head.draw_string(UI.f_sans_b, Vector2(80, 41), ("CANAL 7 · DEBATE ELECTORAL" if electoral else "CANAL 7 · EL DEBATE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UI.GOLD)
		head.draw_rect(Rect2(bw - 230, 12, 210, 36), Color("c62828"))
		head.draw_string(UI.f_sans_b, Vector2(bw - 230, 40), "● EN DIRECTO", HORIZONTAL_ALIGNMENT_CENTER, 210, 24, Color.WHITE))
	bd.add_child(head)
	topic_lbl = UI.lbl("", UI.f_serif_b, 46, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	topic_lbl.position = Vector2(0, 70)
	topic_lbl.size = Vector2(bw, 60)
	bd.add_child(topic_lbl)
	var names := Control.new()
	names.position = Vector2(0, 140)
	names.size = Vector2(bw, 56)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.draw.connect(func():
		var own_c := Color(W.PARTIES[GS.pres["party"]]["color"])
		var opp_c := Color(W.PARTIES[_opp_party()]["color"])
		names.draw_rect(Rect2(40, 0, 560, 50), Color(0, 0, 0, 0.6))
		names.draw_rect(Rect2(40, 0, 10, 50), own_c)
		names.draw_string(UI.f_sans_b, Vector2(64, 35), GS.pres["name"].to_upper() + " · " + W.PARTIES[GS.pres["party"]]["short"], HORIZONTAL_ALIGNMENT_LEFT, 530, 24, Color.WHITE)
		names.draw_rect(Rect2(bw - 600, 0, 560, 50), Color(0, 0, 0, 0.6))
		names.draw_rect(Rect2(bw - 50, 0, 10, 50), opp_c)
		names.draw_string(UI.f_sans_b, Vector2(bw - 600, 35), String(opp_ch["name"]).to_upper() + " · " + W.PARTIES[_opp_party()]["short"], HORIZONTAL_ALIGNMENT_RIGHT, 535, 24, Color.WHITE))
	bd.add_child(names)
	worm_ctrl = Control.new()
	worm_ctrl.position = Vector2(40, 212)
	worm_ctrl.size = Vector2(bw - 80, 340)
	worm_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	worm_ctrl.draw.connect(_draw_worm)
	bd.add_child(worm_ctrl)
	result_lbl = UI.lbl("", UI.f_cond_b, 44, UI.GOLD_L, HORIZONTAL_ALIGNMENT_CENTER)
	result_lbl.position = Vector2(0, 568)
	result_lbl.size = Vector2(bw, 60)
	bd.add_child(result_lbl)


func _intro_3d() -> void:
	intro = Node.new()
	add_child(intro)
	topic_lbl.text = "Debate electoral" if electoral else "El debate"
	stage.title_card("Canal 7 · En directo", "Debate electoral" if electoral else "El debate",
		"Cara a cara con %s: %d bloques. Elija su réplica entre las tarjetas del atril antes de que se apague la luz del tiempo. Al final, la encuesta flash dirá quién ha ganado." % [opp_ch["name"], rounds.size()], 0.0)
	Sfx.play("news", -6.0)
	stage.say(_mod_who(), "Buenas noches y bienvenidos a %s de Canal 7. Esta noche, cara a cara, %s y %s." % ["este debate electoral" if electoral else "el debate", GS.pres["name"], opp_ch["name"]], UI.GOLD, stage.moderator, 0.4)
	stage.after_lines(func():
		if ri >= 0 or not is_instance_valid(intro) or closing:
			return
		stage.pov(true)
		stage.cam_speed = 1.3
		stage.notice("Haga clic en la tarjeta del atril cuando esté listo")
		stage.deal_cards([
			{"tag": "Debate", "title": "Empezar el debate", "desc": "Cuatro bloques cara a cara. Las réplicas, en las tarjetas del atril.", "col": UI.GOLD, "icon": "microfono"},
		], stage.top_center(), stage.top_normal(), 0.27, _on_intro_card, Vector2(0.22, 0.145), 0.3))


func _on_intro_card(_i: int) -> void:
	if is_instance_valid(intro):
		intro.queue_free()
	stage.hide_title()
	stage.notice("")
	_next()


## Cuatro réplicas: la mejor para este ataque y tres al azar
func _options(r: Dictionary) -> Array:
	var best: Dictionary = P.DEBATE_REPLIES[0]
	for rep in P.DEBATE_REPLIES:
		if float(rep["vs"].get(r["kind"], 0.0)) > float(best["vs"].get(r["kind"], 0.0)):
			best = rep
	var others: Array = P.DEBATE_REPLIES.duplicate()
	others.erase(best)
	others.shuffle()
	var opts := [best] + others.slice(0, 3)
	opts.shuffle()
	return opts


## Vuelta al atril: el ataque queda arriba y las réplicas, en las tarjetas
func _deal_replies(gen: int) -> void:
	if gen != _gen or answered or closing or ri >= rounds.size():
		return
	var r: Dictionary = rounds[ri]
	stage.caption(String(opp_ch["name"]) + " · " + String(r["topic"]), r["attack"])
	stage.pov(true)
	stage.cut()
	var opts := _options(r)
	var specs := []
	for rep in opts:
		specs.append({"tag": "Réplica", "title": rep["name"], "desc": rep["desc"], "icon": rep["icon"], "col": REPLY_COLS.get(rep["id"], UI.GOLD), "title_k": 0.14, "desc_k": 0.09})
	stage.deal_cards(specs, stage.top_center(), stage.top_normal(), 0.212, func(i: int): _reply(opts[i]), Vector2(0.198, 0.13))
	stage.notice("Elija su réplica: haga clic en una tarjeta o pulse 1, 2, 3 o 4")
	timer.start(SECONDS + 1.0, "SU TURNO DE RÉPLICA")


## La réplica cae en el plató: aplausos, murmullos o risas; el rival contesta y, luego, el bloque siguiente
func _react(s: float, replied: bool, gen: int) -> void:
	if gen != _gen or closing:
		return
	stage.caption("", "")
	worm.append(clampf(worm.back() + (s - 0.55) * 30.0, 0.0, 100.0))
	var loud := false
	if s >= 0.75:
		result_lbl.text = "¡Golpe maestro!"
		result_lbl.add_theme_color_override("font_color", UI.GREEN)
		stage.react("good")
		stage.big_text("¡GOLPE MAESTRO!", UI.GOLD_L, 130)
		stage.shake(0.5)
		Sfx.play("applause", -6.0)
		_after(0.9, func():
			stage.shot_opp()
			stage.say(_opp_who(), DB.fresh_line(DB.opp_reactions("good"), "orx_good"), UI.RED.lightened(0.3), opp, 0.3))
		loud = true
	elif s >= 0.5:
		result_lbl.text = "Réplica aceptable"
		result_lbl.add_theme_color_override("font_color", UI.AMBER)
		stage.react("ok")
		stage.big_text("RÉPLICA ACEPTABLE", UI.AMBER, 84)
		Sfx.play("applause", -14.0)
	else:
		result_lbl.text = "Le han pillado" if replied else "Se ha quedado en blanco"
		result_lbl.add_theme_color_override("font_color", UI.RED)
		stage.react("bad")
		stage.big_text("¡LE HAN PILLADO!" if replied else "¡SE HA QUEDADO EN BLANCO!", UI.RED.lightened(0.15), 110 if replied else 96)
		stage.shake(0.25)
		Sfx.play("crowd", -8.0, 1.2)
		_after(0.7, func():
			stage.shot_opp()
			stage.say(_opp_who(), DB.fresh_line(DB.opp_reactions("bad"), "orx_bad"), UI.RED.lightened(0.3), opp, 0.3))
		loud = true
	_after(2.6 if loud else 2.0, func():
		if gen == _gen:
			stage.after_lines(_next_if.bind(gen)))


func _next_if(gen: int) -> void:
	if gen == _gen and not closing:
		_next()


# ------------------------------------------------------------------ plató 2D (sin los minijuegos en 3D)

func _build_2d() -> void:
	var set_ctrl := Control.new()
	UI.full(set_ctrl)
	set_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_ctrl.draw.connect(func():
		set_ctrl.draw_rect(Rect2(0, 100, 1920, 980), Color("0a0f1e"))
		for i in 16:
			set_ctrl.draw_rect(Rect2(i * 120, 100, 60, 620), Color(0.15, 0.3, 0.7, 0.05))
		set_ctrl.draw_circle(Vector2(960, 420), 360, Color(0.2, 0.4, 0.9, 0.06))
		set_ctrl.draw_string(UI.f_cond_b, Vector2(0, 250), "EL DEBATE", HORIZONTAL_ALIGNMENT_CENTER, 1920, 120, Color(1, 1, 1, 0.05))
		set_ctrl.draw_rect(Rect2(0, 700, 1920, 380), Color("070a14"))
		for x in [300, 1380]:
			set_ctrl.draw_colored_polygon(PackedVector2Array([Vector2(x, 700), Vector2(x + 240, 700), Vector2(x + 220, 900), Vector2(x + 20, 900)]), Color("1a2a4a"))
			set_ctrl.draw_rect(Rect2(x, 700, 240, 8), UI.GOLD))
	root.add_child(set_ctrl)
	me = Portrait.new()
	me.position = Vector2(140, 150)
	me.size = Vector2(560, 672)
	me.track_mouse = false
	root.add_child(me)
	me.setup(GS.pres["look"], true)
	opp = Portrait.new()
	opp.position = Vector2(1220, 150)
	opp.size = Vector2(560, 672)
	opp.track_mouse = false
	root.add_child(opp)
	opp.setup(opp_ch["look"], true)
	var names := Control.new()
	names.position = Vector2(0, 640)
	names.size = Vector2(1920, 60)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.draw.connect(func():
		var own_c := Color(W.PARTIES[GS.pres["party"]]["color"])
		var opp_party: String = W.PLAYER_PARTIES[GS.pres["party"]]["opp"]
		var opp_c := Color(W.PARTIES[opp_party]["color"])
		names.draw_rect(Rect2(200, 0, 440, 44), Color(0, 0, 0, 0.7))
		names.draw_rect(Rect2(200, 0, 8, 44), own_c)
		names.draw_string(UI.f_sans_b, Vector2(220, 30), GS.pres["name"].to_upper() + " · " + W.PARTIES[GS.pres["party"]]["short"], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.WHITE)
		names.draw_rect(Rect2(1280, 0, 440, 44), Color(0, 0, 0, 0.7))
		names.draw_rect(Rect2(1712, 0, 8, 44), opp_c)
		names.draw_string(UI.f_sans_b, Vector2(1280, 30), opp_ch["name"].to_upper() + " · " + W.PARTIES[opp_party]["short"], HORIZONTAL_ALIGNMENT_RIGHT, 420, 19, Color.WHITE))
	root.add_child(names)
	var head := UI.vbox(0)
	head.position = Vector2(0, 118)
	head.size = Vector2(1920, 80)
	root.add_child(head)
	head.add_child(UI.lbl("DEBATE ELECTORAL · CARA A CARA" if electoral else "DEBATE EN DIRECTO · CANAL 7", UI.f_sans_b, 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	topic_lbl = UI.lbl("", UI.f_serif_b, 40, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	head.add_child(topic_lbl)
	bubble_opp = _bubble(Vector2(1110, 240))
	bubble_me = _bubble(Vector2(90, 240))
	timer = TimerBar.new()
	timer.position = Vector2(260, 770)
	timer.size = Vector2(1400, 8)
	root.add_child(timer)
	timer.timeout.connect(func():
		if not answered:
			_reply(null))
	replies = UI.hbox(12)
	replies.position = Vector2(110, 800)
	replies.size = Vector2(1700, 200)
	root.add_child(replies)
	worm_ctrl = Control.new()
	worm_ctrl.position = Vector2(760, 440)
	worm_ctrl.size = Vector2(400, 180)
	worm_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	worm_ctrl.draw.connect(_draw_worm)
	root.add_child(worm_ctrl)
	result_lbl = UI.lbl("", UI.f_cond_b, 30, UI.GOLD_L, HORIZONTAL_ALIGNMENT_CENTER)
	result_lbl.position = Vector2(660, 630)
	result_lbl.size = Vector2(600, 40)
	root.add_child(result_lbl)
	Sfx.play("news", -6.0)
	await get_tree().create_timer(1.0).timeout
	_next()


func _bubble(pos: Vector2) -> RichTextLabel:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sb(Color(0.03, 0.05, 0.09, 0.9), 10, Color(UI.GOLD, 0.4), 1, 0, 16))
	p.position = pos
	p.custom_minimum_size = Vector2(720, 0)
	var t := Typewriter.new()
	t.custom_minimum_size = Vector2(688, 0)
	t.add_theme_font_override("normal_font", UI.f_serif)
	t.add_theme_font_size_override("normal_font_size", 24)
	p.add_child(t)
	p.visible = false
	root.add_child(p)
	return t


func _next_2d() -> void:
	for c in replies.get_children():
		c.queue_free()
	bubble_me.get_parent().visible = false
	result_lbl.text = ""
	if ri >= rounds.size():
		_finish()
		return
	var r: Dictionary = rounds[ri]
	topic_lbl.text = "Bloque %d · %s" % [ri + 1, r["topic"]]
	bubble_opp.get_parent().visible = true
	opp.talking = true
	opp.mood = -0.2
	bubble_opp.play("«" + r["attack"] + "»", 55.0)
	await bubble_opp.typed
	opp.talking = false
	for rep in P.DEBATE_REPLIES:
		replies.add_child(_reply_card(rep))
	timer.start(SECONDS, "SU TURNO DE RÉPLICA")


func _reply_card(rep: Dictionary) -> Control:
	var v := UI.vbox(6)
	v.custom_minimum_size = Vector2(318, 150)
	var h := UI.hbox(8)
	h.add_child(UI.icon_rect(rep["icon"], 26, UI.GOLD_L))
	h.add_child(UI.lbl(rep["name"], UI.f_sans_b, 19, UI.TEXT))
	v.add_child(h)
	var d := UI.lbl(rep["desc"], UI.f_sans, 15, UI.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(300, 0)
	v.add_child(d)
	var card := Widgets.click_card(v, func(): _reply(rep), 14)
	UI.pop_in(card, 0.25)
	return card


func _reply_2d(s: float, line: String) -> void:
	for c in replies.get_children():
		c.set_meta("enabled", false)
		c.modulate.a = 0.35
	bubble_me.get_parent().visible = true
	me.talking = true
	bubble_me.play("«" + line + "»", 60.0)
	await bubble_me.typed
	me.talking = false
	var delta := (s - 0.55) * 30.0
	worm.append(clampf(worm.back() + delta, 0.0, 100.0))
	if s >= 0.75:
		result_lbl.text = "¡Golpe maestro!"
		result_lbl.add_theme_color_override("font_color", UI.GREEN)
		me.mood = 0.7
		opp.mood = -0.6
		opp.anger = 0.5
		Sfx.play("applause", -8.0)
		bubble_opp.play("«" + DB.fresh_line(DB.opp_reactions("good"), "orx_good") + "»", 60.0)
	elif s >= 0.5:
		result_lbl.text = "Réplica aceptable"
		result_lbl.add_theme_color_override("font_color", UI.AMBER)
		me.mood = 0.2
	else:
		result_lbl.text = "Le han pillado"
		result_lbl.add_theme_color_override("font_color", UI.RED)
		me.mood = -0.5
		opp.mood = 0.6
		Sfx.play("crowd", -8.0, 1.2)
		bubble_opp.play("«" + DB.fresh_line(DB.opp_reactions("bad"), "orx_bad") + "»", 60.0)
	UI.pop_in(result_lbl)
	await get_tree().create_timer(2.6).timeout
	opp.anger = 0.0
	_next()


func _finish_2d(title: String, poll: String, won: bool, out: Array) -> void:
	var p := UI.panel(Color(0.03, 0.05, 0.09, 0.97), 12, Color(UI.GOLD, 0.6), 30)
	p.position = Vector2(560, 360)
	p.custom_minimum_size = Vector2(800, 0)
	var v := UI.vbox(14)
	p.add_child(v)
	v.add_child(UI.lbl(title, UI.f_cond_b, 50, UI.GREEN if won else UI.RED))
	v.add_child(UI.lbl(poll, UI.f_sans_m, 19, UI.TEXT))
	var chips := Widgets.effect_chips(out, 16, 8)
	chips.custom_minimum_size = Vector2(740, 0)
	v.add_child(chips)
	var b := UI.btn("Salir del plató", "gold", 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.pressed.connect(func(): close())
	v.add_child(b)
	root.add_child(p)
	UI.pop_in(p)
