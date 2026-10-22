extends "res://scripts/ui/overlay.gd"
## Debate televisado contra el líder de la oposición.

const Widgets := preload("res://scripts/ui/widgets.gd")
const Typewriter := preload("res://scripts/ui/typewriter.gd")
const TimerBar := preload("res://scripts/ui/timer_bar.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const P := preload("res://scripts/data/press_data.gd")
const W := preload("res://scripts/data/world_data.gd")

var electoral := false
var me: Control
var opp: Control
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


func build() -> void:
	electoral = data.get("electoral", false)
	dim.color = Color(0.01, 0.015, 0.03, 0.97)
	opp_ch = DB.character("opo")
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
	rounds = DB.opposition_attacks(4)
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


func _next() -> void:
	ri += 1
	answered = false
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
	timer.start(12.0, "SU TURNO DE RÉPLICA")


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


func _reply(rep) -> void:
	if answered:
		return
	answered = true
	timer.stop()
	for c in replies.get_children():
		c.set_meta("enabled", false)
		c.modulate.a = 0.35
	var r: Dictionary = rounds[ri]
	var s := 0.15
	var line := "..."
	if rep != null:
		s = float(rep["vs"].get(r["kind"], 0.5))
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
		line = DB.fresh_line(DB.debate_lines(rep["id"]), "rl_" + str(rep["id"]))
	scores.append(s)
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
	var p := UI.panel(Color(0.03, 0.05, 0.09, 0.97), 12, Color(UI.GOLD, 0.6), 30)
	p.position = Vector2(560, 360)
	p.custom_minimum_size = Vector2(800, 0)
	var v := UI.vbox(14)
	p.add_child(v)
	v.add_child(UI.lbl("HA GANADO EL DEBATE" if won else "HA PERDIDO EL DEBATE", UI.f_cond_b, 50, UI.GREEN if won else UI.RED))
	v.add_child(UI.lbl("Encuesta flash: %d%% le da la victoria" % int(clampf(avg * 90.0, 10.0, 90.0)), UI.f_sans_m, 19, UI.TEXT))
	var chips := Widgets.effect_chips(out, 16, 8)
	chips.custom_minimum_size = Vector2(740, 0)
	v.add_child(chips)
	var b := UI.btn("Salir del plató", "gold", 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.pressed.connect(func(): close())
	v.add_child(b)
	root.add_child(p)
	UI.pop_in(p)
	Sfx.play("sting_win" if won else "sting_lose", -6.0)


func _process(delta: float) -> void:
	_t += delta
	worm_ctrl.queue_redraw()


func _draw_worm() -> void:
	var w := worm_ctrl.size.x
	var h := worm_ctrl.size.y
	worm_ctrl.draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.05, 0.09, 0.9))
	worm_ctrl.draw_rect(Rect2(0, 0, w, h), Color(UI.GOLD, 0.4), false, 1.0)
	worm_ctrl.draw_string(UI.f_sans_b, Vector2(14, 22), "¿QUIÉN VA GANANDO?", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)
	var series := worm.duplicate()
	if series.size() < 2:
		series.append(series[0])
	var last: float = series.back()
	worm_ctrl.draw_line(Vector2(14, 34 + (h - 48) * 0.5), Vector2(w - 14, 34 + (h - 48) * 0.5), Color(1, 1, 1, 0.2), 1.0)
	Widgets.draw_line_chart(worm_ctrl, Rect2(14, 34, w - 28, h - 48), series, UI.color_for(last), 0.0, 100.0, 3.0)
	worm_ctrl.draw_string(UI.f_cond_b, Vector2(0, h - 8), "%d%%" % int(last), HORIZONTAL_ALIGNMENT_RIGHT, w - 14, 22, UI.color_for(last))


func on_escape() -> void:
	pass
