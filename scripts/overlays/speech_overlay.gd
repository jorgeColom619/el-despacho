extends "res://scripts/ui/overlay.gd"
## Discurso a la nación / mitin: elegir frases y darles énfasis con el teleprompter (minijuego de ritmo).

const Widgets := preload("res://scripts/ui/widgets.gd")
const TimerBar := preload("res://scripts/ui/timer_bar.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const Flags := preload("res://scripts/ui/flags.gd")
const P := preload("res://scripts/data/press_data.gd")
const W := preload("res://scripts/data/world_data.gd")

const TARGET_X := 700.0
const PROMPT_Y := 900.0
const SPEED := 250.0

var occasion := "nacion"
var sections := []
var si := -1
var scene: Control
var pres: Control
var choice_box: HBoxContainer
var timer: Control
var prompt: Control
var phase := "idle"
var words := []
var offset := 0.0
var cur_fx := {}
var totals := {}
var qualities := []
var hits := 0
var keys_total := 0
var perfects := 0
var worm := [50.0]
var worm_ctrl: Control
var judge_lbl: Label
var _t := 0.0
var crowd := []
var sec_lbl: Label


func build() -> void:
	occasion = data.get("occasion", "nacion")
	dim.color = Color(0.01, 0.015, 0.03, 0.96)
	match occasion:
		"tragedia":
			sections = [["apertura", "Apertura"], ["tragedia", "El dolor"], ["tragedia", "La respuesta"], ["cierre", "Cierre"]]
		"campana":
			sections = [["apertura", "Apertura"], ["campana", "Arenga"], ["promesa", "Promesa"], ["campana", "Remate"]]
		_:
			sections = [["apertura", "Apertura"], ["economia", "Economía"], ["social", "Sociedad"], ["promesa", "Promesa"], ["cierre", "Cierre"]]
	scene = Control.new()
	UI.full(scene)
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.draw.connect(_draw_scene)
	root.add_child(scene)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	if occasion == "campana":
		for i in 90:
			crowd.append({"p": Vector2(rng.randf_range(0, 1920), rng.randf_range(560, 820)), "c": Color.from_hsv(rng.randf(), 0.4, rng.randf_range(0.2, 0.5)), "ph": rng.randf() * TAU, "flag": rng.randf() < 0.3})
	pres = Portrait.new()
	pres.position = Vector2(560, 150) if occasion != "campana" else Vector2(690, 250)
	pres.size = Vector2(560, 672) if occasion != "campana" else Vector2(540, 648)
	pres.track_mouse = false
	root.add_child(pres)
	pres.setup(GS.pres["look"], true)
	pres.mood = 0.2 if occasion != "tragedia" else -0.4
	var lower := Control.new()
	lower.position = Vector2(0, 740)
	lower.size = Vector2(1920, 60)
	lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lower.draw.connect(func():
		var txt: String = {"nacion": "MENSAJE A LA NACIÓN", "tragedia": "DECLARACIÓN INSTITUCIONAL", "campana": "MITIN DE CAMPAÑA"}.get(occasion, "EN DIRECTO")
		lower.draw_rect(Rect2(420, 0, 180, 28), Color("c62828"))
		lower.draw_string(UI.f_sans_b, Vector2(420, 20), "● EN DIRECTO", HORIZONTAL_ALIGNMENT_CENTER, 180, 15, Color.WHITE)
		lower.draw_rect(Rect2(420, 28, 1080, 30), Color(0.96, 0.96, 0.97, 0.95))
		lower.draw_string(UI.f_sans_b, Vector2(436, 50), "%s · %s, Presidente de la República" % [txt, GS.pres["name"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("101828")))
	root.add_child(lower)
	sec_lbl = UI.lbl("", UI.f_sans_b, 16, UI.GOLD)
	sec_lbl.position = Vector2(70, 130)
	root.add_child(sec_lbl)
	var tl := UI.lbl({"nacion": "Discurso a la nación", "tragedia": "Declaración institucional", "campana": "Mitin de campaña"}.get(occasion, "Discurso"), UI.f_serif_b, 40, UI.CREAM)
	tl.position = Vector2(70, 150)
	root.add_child(tl)
	choice_box = UI.hbox(14)
	choice_box.position = Vector2(70, 420)
	choice_box.size = Vector2(1780, 300)
	root.add_child(choice_box)
	timer = TimerBar.new()
	timer.position = Vector2(70, 400)
	timer.size = Vector2(1780, 8)
	timer.visible = false
	root.add_child(timer)
	timer.timeout.connect(func():
		if phase == "choose":
			var opts := choice_box.get_children()
			if opts.size() > 0:
				_choose(opts[0].get_meta("phrase"), false))
	prompt = Control.new()
	prompt.position = Vector2(0, PROMPT_Y - 70)
	prompt.size = Vector2(1920, 150)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.draw.connect(_draw_prompt)
	root.add_child(prompt)
	judge_lbl = UI.lbl("", UI.f_cond_b, 44, UI.GOLD_L, HORIZONTAL_ALIGNMENT_CENTER)
	judge_lbl.position = Vector2(TARGET_X - 200, PROMPT_Y - 150)
	judge_lbl.size = Vector2(400, 60)
	root.add_child(judge_lbl)
	worm_ctrl = Control.new()
	worm_ctrl.position = Vector2(1400, 130)
	worm_ctrl.size = Vector2(460, 180)
	worm_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	worm_ctrl.draw.connect(_draw_worm)
	root.add_child(worm_ctrl)
	var help := UI.lbl("Pulse ESPACIO (o clic) cuando una palabra dorada cruce la línea para darle énfasis.", UI.f_sans, 17, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	help.position = Vector2(0, 1030)
	help.size = Vector2(1920, 30)
	root.add_child(help)
	if occasion == "campana":
		Sfx.loop_start("crowd", "crowd", -12.0)
	_next_section()


func _next_section() -> void:
	si += 1
	for c in choice_box.get_children():
		c.queue_free()
	if si >= sections.size():
		_finish()
		return
	var sec: Array = sections[si]
	sec_lbl.text = "PARTE %d DE %d · %s" % [si + 1, sections.size(), String(sec[1]).to_upper()]
	var pool: Array = P.SPEECH[sec[0]].duplicate()
	pool.shuffle()
	var shown := 0
	for ph in pool:
		if shown >= 3:
			break
		if ph.has("need") and not GS.check(ph["need"]):
			continue
		choice_box.add_child(_phrase_card(ph))
		shown += 1
	phase = "choose"
	timer.visible = true
	timer.start(9.0, "ELIJA LA FRASE")


func _phrase_card(ph: Dictionary) -> Control:
	var v := UI.vbox(10)
	v.custom_minimum_size = Vector2(560, 150)
	var l := UI.lbl("«" + ph["t"] + "»", UI.f_serif, 23, UI.CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(540, 0)
	v.add_child(l)
	var items := []
	for k in ph["fx"].keys():
		items.append({"k": k, "v": float(ph["fx"][k]) * 3.0})
	var chips := Widgets.effect_chips(items, 14, 5)
	chips.custom_minimum_size = Vector2(540, 0)
	v.add_child(chips)
	var card := Widgets.click_card(v, func(): _choose(ph, true), 16)
	card.set_meta("phrase", ph)
	UI.pop_in(card, 0.3)
	return card


func _choose(ph: Dictionary, manual: bool) -> void:
	if phase != "choose":
		return
	timer.stop()
	timer.visible = false
	for c in choice_box.get_children():
		c.queue_free()
	if not manual:
		judge_lbl.text = "¡Titubeo!"
		judge_lbl.add_theme_color_override("font_color", UI.RED)
	cur_fx = ph["fx"]
	_prepare_words(ph["t"])
	phase = "deliver"
	pres.talking = true
	Sfx.play("paper2", -8.0)


func _prepare_words(text: String) -> void:
	words.clear()
	var parts := text.split(" ", false)
	var x := 0.0
	var cands := []
	for i in parts.size():
		var w: String = parts[i]
		var clean := w.strip_edges().trim_suffix(",").trim_suffix(".").trim_suffix("!").trim_suffix(":").trim_prefix("¡")
		var wd := UI.f_serif_b.get_string_size(w + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
		words.append({"t": w, "x": x, "w": wd, "key": false, "judged": false, "res": ""})
		if clean.length() >= 5:
			cands.append(i)
		x += wd
	cands.sort_custom(func(a, b): return parts[a].length() > parts[b].length())
	var chosen := []
	for c in cands:
		var ok := true
		for ch in chosen:
			if absi(ch - c) < 2:
				ok = false
		if ok:
			chosen.append(c)
		if chosen.size() >= 3:
			break
	for c in chosen:
		words[c]["key"] = true
	keys_total += chosen.size()
	offset = 1920.0 - TARGET_X + 80.0
	offset = TARGET_X + 300.0


func _process(delta: float) -> void:
	_t += delta
	if phase == "deliver":
		offset -= SPEED * delta
		var all_past := true
		for w in words:
			var cx: float = offset + w["x"] + w["w"] * 0.5
			if w["key"] and not w["judged"] and cx < TARGET_X - 110.0:
				w["judged"] = true
				w["res"] = "miss"
				_judge("Fallo", UI.RED, -4.0)
			if offset + w["x"] + w["w"] > TARGET_X - 260.0:
				all_past = false
		if all_past and words.size() > 0:
			_end_phrase()
	prompt.queue_redraw()
	scene.queue_redraw()
	worm_ctrl.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		pressed = true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if not pressed or phase != "deliver":
		return
	get_viewport().set_input_as_handled()
	var best = null
	var bd := 9999.0
	for w in words:
		if not w["key"] or w["judged"]:
			continue
		var cx: float = offset + w["x"] + w["w"] * 0.5
		var d := absf(cx - TARGET_X)
		if d < bd:
			bd = d
			best = w
	if best == null or bd > 130.0:
		_judge("¡A destiempo!", UI.RED, -3.0)
		return
	best["judged"] = true
	if bd < 32.0:
		best["res"] = "perfect"
		hits += 1
		perfects += 1
		_judge("¡PERFECTO!", UI.GOLD_L, 7.0)
		Sfx.play("applause", -12.0 if occasion != "campana" else -6.0)
	elif bd < 80.0:
		best["res"] = "good"
		hits += 1
		_judge("Bien", UI.GREEN, 4.0)
		Sfx.play("click", -2.0, 1.2)
	else:
		best["res"] = "miss"
		_judge("Flojo", UI.AMBER, -1.0)


func _judge(text: String, col: Color, delta_worm: float) -> void:
	judge_lbl.text = text
	judge_lbl.add_theme_color_override("font_color", col)
	judge_lbl.pivot_offset = judge_lbl.size * 0.5
	judge_lbl.scale = Vector2(1.4, 1.4)
	judge_lbl.modulate.a = 1.0
	var t := judge_lbl.create_tween()
	t.tween_property(judge_lbl, "scale", Vector2.ONE, 0.2)
	t.tween_property(judge_lbl, "modulate:a", 0.0, 0.6).set_delay(0.4)
	worm.append(clampf(worm.back() + delta_worm, 0.0, 100.0))


func _end_phrase() -> void:
	phase = "idle"
	pres.talking = false
	var k := 0
	var h := 0
	var p := 0
	for w in words:
		if w["key"]:
			k += 1
			if w["res"] in ["perfect", "good"]:
				h += 1
			if w["res"] == "perfect":
				p += 1
	var q := 0.5 + 0.5 * (float(h) / maxf(1.0, k)) + 0.15 * p
	qualities.append(q)
	var sum := 0.0
	for key in cur_fx.keys():
		totals[key] = totals.get(key, 0.0) + float(cur_fx[key]) * q
		sum += float(cur_fx[key])
	worm.append(clampf(worm.back() + sum * q * 2.0, 0.0, 100.0))
	await get_tree().create_timer(0.6).timeout
	_next_section()


func _finish() -> void:
	phase = "done"
	Sfx.loop_stop("crowd")
	var avg := 0.0
	for q in qualities:
		avg += q
	avg /= maxf(1.0, qualities.size())
	var fx := {}
	for k in totals.keys():
		fx[k] = snappedf(float(totals[k]) * 1.6, 0.1)
	fx["approval"] = snappedf((avg - 0.75) * 8.0, 0.1)
	if occasion == "tragedia":
		fx["estabilidad"] = float(fx.get("estabilidad", 0.0)) + 2.0 * avg
	GS.speech_until = GS.day + (12 if GS.campaign else 45)
	if GS.campaign:
		GS.campaign_bonus += avg * 1.8
	var out := GS.apply_fx(fx, "Discurso")
	var verdict := "Discurso memorable" if avg >= 1.05 else ("Discurso correcto" if avg >= 0.8 else "Discurso para olvidar")
	GS.push_news("%s del presidente %s" % [{"nacion": "Mensaje a la nación", "tragedia": "Declaración institucional", "campana": "Mitin"}.get(occasion, "Discurso"), GS.pres["name"]] + (": «%s»" % verdict.to_lower()), 2)
	GS.log_history("Discurso", verdict)
	var pnl := UI.panel(Color(0.03, 0.05, 0.09, 0.97), 12, Color(UI.GOLD, 0.6), 30)
	pnl.position = Vector2(560, 380)
	pnl.custom_minimum_size = Vector2(800, 0)
	var v := UI.vbox(14)
	pnl.add_child(v)
	v.add_child(UI.lbl(verdict.to_upper(), UI.f_cond_b, 48, UI.GREEN if avg >= 1.05 else (UI.AMBER if avg >= 0.8 else UI.RED)))
	v.add_child(UI.lbl("Énfasis acertados: %d de %d · Perfectos: %d" % [hits, keys_total, perfects], UI.f_sans_m, 19, UI.TEXT))
	var chips := Widgets.effect_chips(out, 16, 10)
	chips.custom_minimum_size = Vector2(740, 0)
	v.add_child(chips)
	var b := UI.btn("Terminar la emisión", "gold", 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.pressed.connect(func(): close())
	v.add_child(b)
	root.add_child(pnl)
	UI.pop_in(pnl)
	Sfx.play("applause" if avg >= 0.8 else "crowd", -4.0)


func _draw_scene() -> void:
	if occasion == "campana":
		scene.draw_rect(Rect2(0, 100, 1920, 980), Color("0c1020"))
		for i in 8:
			scene.draw_circle(Vector2(240 * i + 120, 140), 220, Color(1, 0.85, 0.5, 0.035))
		Flags.draw_flag(scene, "valdoria", Rect2(760, 150, 400, 240))
		for p in crowd:
			var bob := absf(sin(_t * 3.0 + p["ph"])) * 6.0
			var pos: Vector2 = p["p"] - Vector2(0, bob)
			scene.draw_rect(Rect2(pos + Vector2(-22, 0), Vector2(44, 200)), p["c"])
			scene.draw_circle(pos + Vector2(0, -16), 18, (p["c"] as Color).lightened(0.2))
			if p["flag"]:
				scene.draw_line(pos + Vector2(18, 0), pos + Vector2(26, -70), Color(0.3, 0.3, 0.3), 3.0)
				Flags.draw_flag(scene, "valdoria", Rect2(pos + Vector2(26, -70), Vector2(50, 30)))
	else:
		scene.draw_rect(Rect2(0, 100, 1920, 980), Color("0d1320"))
		Flags.draw_flag(scene, "valdoria", Rect2(440, 150, 380, 600))
		scene.draw_rect(Rect2(440, 150, 380, 600), Color(0, 0, 0, 0.35))
		for i in 12:
			var bx := 1150.0 + i * 38.0
			scene.draw_rect(Rect2(bx, 420, 30, 150 + (i % 3) * 20), Color.from_hsv(0.05 + i * 0.07, 0.4, 0.3))
		scene.draw_rect(Rect2(1130, 580, 480, 20), Color("3a2012"))
		scene.draw_rect(Rect2(0, 760, 1920, 320), Color("241510"))
		scene.draw_rect(Rect2(0, 760, 1920, 6), Color("5a3522"))


func _draw_prompt() -> void:
	var y := 70.0
	prompt.draw_rect(Rect2(0, 0, 1920, 140), Color(0.02, 0.03, 0.05, 0.92))
	prompt.draw_rect(Rect2(0, 0, 1920, 2), Color(UI.GOLD, 0.5))
	prompt.draw_rect(Rect2(0, 138, 1920, 2), Color(UI.GOLD, 0.5))
	prompt.draw_rect(Rect2(TARGET_X - 32, 6, 64, 128), Color(UI.GOLD, 0.08))
	prompt.draw_line(Vector2(TARGET_X, 4), Vector2(TARGET_X, 136), UI.GOLD, 3.0)
	if phase != "deliver":
		prompt.draw_string(UI.f_sans_m, Vector2(0, y + 10), "TELEPROMPTER", HORIZONTAL_ALIGNMENT_CENTER, 1920, 18, Color(1, 1, 1, 0.2))
		return
	for w in words:
		var x: float = offset + w["x"]
		if x > 1920 or x + w["w"] < 0:
			continue
		var col := Color(1, 1, 1, 0.85)
		if w["key"]:
			col = UI.GOLD_L
			match w["res"]:
				"perfect":
					col = Color(1, 0.95, 0.5)
				"good":
					col = UI.GREEN
				"miss":
					col = UI.RED
			prompt.draw_rect(Rect2(x - 4, y - 42, w["w"] - 6, 58), Color(col, 0.1))
		prompt.draw_string(UI.f_serif_b, Vector2(x, y + 12), w["t"], HORIZONTAL_ALIGNMENT_LEFT, -1, 46, col)


func _draw_worm() -> void:
	var w := worm_ctrl.size.x
	var h := worm_ctrl.size.y
	worm_ctrl.draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.05, 0.09, 0.9))
	worm_ctrl.draw_rect(Rect2(0, 0, w, h), Color(UI.GOLD, 0.4), false, 1.0)
	worm_ctrl.draw_string(UI.f_sans_b, Vector2(14, 22), "AUDIENCIA · REACCIÓN EN DIRECTO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)
	var series := worm.duplicate()
	if series.size() < 2:
		series.append(series[0])
	Widgets.draw_line_chart(worm_ctrl, Rect2(14, 34, w - 28, h - 48), series, UI.color_for(series.back()), 0.0, 100.0, 3.0)


func on_escape() -> void:
	pass
