extends "res://scripts/ui/overlay.gd"
## Discurso a la nación / mitin: elegir frases y leerlas en el teleprompter... que el becario de comunicación ha
## llenado de erratas. Mientras el presidente lee (la palabra en curso va subrayada), hay que hacer clic en las
## palabras cambiadas o en las coletillas que sobran antes de que lleguen a su boca: si no, las dice en directo.

const Widgets := preload("res://scripts/ui/widgets.gd")
const TimerBar := preload("res://scripts/ui/timer_bar.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const Flags := preload("res://scripts/ui/flags.gd")
const P := preload("res://scripts/data/press_data.gd")
const W := preload("res://scripts/data/world_data.gd")
const PressRoom := preload("res://scripts/stages3d/press_room_3d.gd")

const PROMPT_Y := 822.0
const PROMPT_H := 176.0
## Segundos por palabra en cada parte del discurso (se lee cada vez más deprisa)
const READ_BASE := [0.42, 0.38, 0.35, 0.32, 0.3]
## Erratas por frase en cada parte
const ERRORS := [1, 2, 2, 3, 3]

var occasion := "nacion"
var sections := []
var si := -1
var scene: Control
## Retrato 2D o presidente 3D en el atril: ambos exponen talking / mood
var pres
var choice_box: HBoxContainer
var timer: Control
var prompt: Control
var phase := "idle"
## Palabras de la frase en el teleprompter: {t, orig, bad ("", "swap", "insert"), fixed, said, rect, flash, wrong}
var tokens := []
## Siguiente palabra que va a leer el presidente
var cursor := 0
var _word_t := 0.0
var _preview := 0.0
var _fsize := 40
var cur_fx := {}
var totals := {}
var qualities := []
var _stumble := false
## Recuento de la frase en curso: erratas, corregidas, clics en palabras buenas
var _e := 0
var _c := 0
var _f := 0
## Recuento de todo el discurso
var errors_total := 0
var errors_fixed := 0
var false_clicks := 0
var clean_phrases := 0
## Lo que llegó a decir en directo («... un chollo que venderé ...»)
var gaffes := []
var worm := [50.0]
var worm_ctrl: Control
var judge_lbl: Label
var _t := 0.0
var crowd := []
var sec_lbl: Label
## Sala de prensa 3D vista por televisión (con el despacho 3D; el mitin sigue en 2D)
var stage


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
	if occasion != "campana" and PressRoom.enabled():
		stage = PressRoom.new()
		stage.view = "tv"
		stage.pres_look = Perfil.apply_outfit(GS.pres["look"])
		stage.quiet = occasion == "tragedia"
		root.add_child(stage)
		pres = stage.president
	else:
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
	prompt.position = Vector2(0, PROMPT_Y)
	prompt.size = Vector2(1920, PROMPT_H)
	prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	prompt.draw.connect(_draw_prompt)
	prompt.gui_input.connect(_on_prompt_input)
	root.add_child(prompt)
	judge_lbl = UI.lbl("", UI.f_cond_b, 44, UI.GOLD_L, HORIZONTAL_ALIGNMENT_CENTER)
	judge_lbl.position = Vector2(760, PROMPT_Y - 64)
	judge_lbl.size = Vector2(400, 60)
	root.add_child(judge_lbl)
	worm_ctrl = Control.new()
	worm_ctrl.position = Vector2(1400, 130)
	worm_ctrl.size = Vector2(460, 180)
	worm_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	worm_ctrl.draw.connect(_draw_worm)
	root.add_child(worm_ctrl)
	var help := UI.lbl("El becario ha llenado el teleprompter de erratas: haga clic en las palabras que estén mal o sobren antes de que las lea en voz alta.", UI.f_sans, 17, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
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
	tokens.clear()
	if si >= sections.size():
		_finish()
		return
	var sec: Array = sections[si]
	sec_lbl.text = "PARTE %d DE %d · %s" % [si + 1, sections.size(), String(sec[1]).to_upper()]
	var pool: Array = DB.speech_pool(sec[0])
	if GS.mode == "meme":
		# En el modo meme, las frases de chiste van primero
		var memes: Array = DB.E_MEME.SPEECH.get(sec[0], []).duplicate()
		memes.shuffle()
		memes.append_array(pool)
		pool = memes
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
	_stumble = not manual
	if not manual:
		_judge("¡Titubeo!", UI.RED, -3.0)
	cur_fx = ph["fx"]
	DB.mark_speech(ph)
	_prepare_tokens(str(ph["t"]))
	phase = "deliver"
	# un momento para echar un vistazo a la frase antes de empezar a leer
	_preview = 1.4 if si == 0 else 1.0
	_word_t = 0.0
	cursor = 0
	Sfx.play("paper2", -8.0)


## Palabra limpia y en minúsculas (sin «¡», comas ni puntos) para buscarla en las erratas
func _clean(w: String) -> String:
	var s := w.strip_edges()
	while s.length() > 0 and s[0] in "¡¿«\"(":
		s = s.substr(1)
	while s.length() > 0 and s[s.length() - 1] in ",.:;!?»\")":
		s = s.substr(0, s.length() - 1)
	return s.to_lower()


## Cambia la palabra por la errata respetando mayúscula inicial y signos («¡Valdoria,» -> «¡Norland,»)
func _swap_word(w: String, rep: String) -> String:
	var core := _clean(w)
	var start := w.to_lower().find(core)
	if start < 0:
		return rep
	var orig_core := w.substr(start, core.length())
	if orig_core.length() > 0 and orig_core[0] != orig_core[0].to_lower():
		rep = rep[0].to_upper() + rep.substr(1)
	return w.substr(0, start) + rep + w.substr(start + core.length())


func _prepare_tokens(text: String) -> void:
	tokens.clear()
	var parts := text.split(" ", false)
	for w in parts:
		tokens.append({"t": w, "orig": w, "bad": "", "fixed": false, "said": false, "rect": Rect2(), "flash": 0.0, "wrong": 0.0})
	var n_err: int = ERRORS[mini(si, ERRORS.size() - 1)]
	if GS.difficulty == 0:
		n_err = maxi(1, n_err - 1)
	n_err = mini(n_err, maxi(1, parts.size() / 4))
	# primero cambia palabras que tengan una errata graciosa; lo que falte, coletillas que sobran
	var cands := []
	for i in parts.size():
		if DB.C.TELEPROMPTER_SWAPS.has(_clean(parts[i])):
			cands.append(i)
	cands.shuffle()
	var swaps := mini(cands.size(), n_err - (1 if n_err >= 2 and randf() < 0.4 else 0))
	var taken := {}
	for i in cands:
		if taken.size() >= swaps:
			break
		if taken.has(i - 1) or taken.has(i + 1):
			continue
		taken[i] = true
		var opts: Array = DB.C.TELEPROMPTER_SWAPS[_clean(parts[i])]
		tokens[i]["t"] = _swap_word(parts[i], str(opts.pick_random()))
		tokens[i]["bad"] = "swap"
	var inserts := n_err - taken.size()
	var pool: Array = DB.C.TELEPROMPTER_INSERTS.duplicate()
	pool.shuffle()
	var tries := 0
	while inserts > 0 and tries < 30:
		tries += 1
		var at := randi_range(1, tokens.size())
		# ni pegada a otra errata ni al principio
		if (at - 1 >= 0 and tokens[at - 1]["bad"] != "") or (at < tokens.size() and tokens[at]["bad"] != ""):
			continue
		tokens.insert(at, {"t": str(pool.pop_back()), "orig": "", "bad": "insert", "fixed": false, "said": false, "rect": Rect2(), "flash": 0.0, "wrong": 0.0})
		inserts -= 1
	_e = 0
	_c = 0
	_f = 0
	for tk in tokens:
		if tk["bad"] != "":
			_e += 1
	errors_total += _e
	_layout()


## Coloca las palabras en el teleprompter (hasta tres líneas, centradas) y guarda dónde está cada una
func _layout() -> void:
	_fsize = 40
	var lines := _wrap(_fsize)
	if lines.size() > 2:
		_fsize = 33
		lines = _wrap(_fsize)
	var lh := _fsize * 1.45
	var top := 26.0 + (PROMPT_H - 26.0 - lh * lines.size()) * 0.5
	var sp := UI.f_serif_b.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, _fsize).x
	for li in lines.size():
		var row: Array = lines[li]
		var total := -sp
		for i in row:
			total += _slot_w(tokens[i], _fsize) + sp
		var x := (1920.0 - total) * 0.5
		for i in row:
			var w := _slot_w(tokens[i], _fsize)
			tokens[i]["rect"] = Rect2(x - 6, top + li * lh, w + 12, lh)
			x += w + sp


func _word_w(t: String, fs: int) -> float:
	return UI.f_serif_b.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## Hueco de la palabra: en las cambiadas, el de la más larga de las dos, para que al corregirla no se mueva nada
func _slot_w(tk: Dictionary, fs: int) -> float:
	var w := _word_w(tk["t"], fs)
	if tk["bad"] == "swap":
		w = maxf(w, _word_w(tk["orig"], fs))
	return w


func _wrap(fs: int) -> Array:
	var sp := UI.f_serif_b.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var lines := [[]]
	var x := 0.0
	for i in tokens.size():
		var w := _slot_w(tokens[i], fs)
		if x > 0.0 and x + w > 1720.0:
			lines.append([])
			x = 0.0
		lines.back().append(i)
		x += w + sp
	return lines


func _on_prompt_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	for i in tokens.size():
		if (tokens[i]["rect"] as Rect2).grow(4).has_point(event.position):
			click_token(i)
			prompt.accept_event()
			return


## Clic en una palabra del teleprompter (también lo usan las pruebas)
func click_token(i: int) -> void:
	if phase != "deliver" or i < 0 or i >= tokens.size():
		return
	var tk: Dictionary = tokens[i]
	# lo ya dicho, dicho está
	if tk["said"] or tk["fixed"] or i < cursor:
		return
	if tk["bad"] != "":
		tk["fixed"] = true
		tk["flash"] = 1.0
		_c += 1
		errors_fixed += 1
		if tk["bad"] == "swap":
			tk["t"] = tk["orig"]
			_judge("¡Corregido!", UI.GREEN, 3.0)
		else:
			_judge("¡Fuera!", UI.GREEN, 3.0)
		Sfx.play("click", -2.0, 1.25)
	else:
		tk["wrong"] = 0.5
		_f += 1
		false_clicks += 1
		_judge("¡Esa estaba bien!", UI.AMBER, -2.0)
		Sfx.play("click", -4.0, 0.6)


func _process(delta: float) -> void:
	_t += delta
	if phase == "deliver":
		if _preview > 0.0:
			_preview -= delta
		else:
			pres.talking = true
			_word_t += delta
			while cursor < tokens.size() and _word_t >= _word_dur(tokens[cursor]):
				_word_t -= _word_dur(tokens[cursor])
				_say_token(cursor)
				cursor += 1
			if cursor >= tokens.size():
				_end_phrase()
	for tk in tokens:
		tk["flash"] = maxf(0.0, float(tk["flash"]) - delta * 1.6)
		tk["wrong"] = maxf(0.0, float(tk["wrong"]) - delta)
	prompt.queue_redraw()
	if scene != null:
		scene.queue_redraw()
	worm_ctrl.queue_redraw()


## Lo que tarda en leer una palabra (las coletillas quitadas se saltan)
func _word_dur(tk: Dictionary) -> float:
	if tk["bad"] == "insert" and tk["fixed"]:
		return 0.0
	var base: float = READ_BASE[mini(si, READ_BASE.size() - 1)] * [1.2, 1.0, 0.88][GS.difficulty]
	if GS.has_trait("orador"):
		base *= 1.15
	if GS.stress > 75:
		base *= 0.9
	return base * (0.55 + 0.05 * String(tk["t"]).length())


## El presidente lee la palabra: si era una errata sin corregir, la dice en directo
func _say_token(i: int) -> void:
	var tk: Dictionary = tokens[i]
	tk["said"] = true
	if tk["bad"] != "" and not tk["fixed"]:
		var a := maxi(0, i - 3)
		var b := mini(tokens.size(), i + 3)
		var bits := PackedStringArray()
		for k in range(a, b):
			if not (tokens[k]["bad"] == "insert" and tokens[k]["fixed"]):
				bits.append(str(tokens[k]["t"]))
		gaffes.append(("..." if a > 0 else "") + " ".join(bits) + ("..." if b < tokens.size() else ""))
		_judge("¡LAPSUS!", UI.RED, -14.0 if occasion == "tragedia" else -9.0)
		Sfx.play("crowd", -6.0, 1.15)
		pres.mood = -0.5
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(pres) and phase != "done":
				pres.mood = 0.2 if occasion != "tragedia" else -0.4)


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
	var aired := _e - _c
	var q := 0.45 + 0.6 * (float(_c) / maxf(1.0, _e)) - 0.08 * _f
	if aired == 0 and _f == 0:
		q += 0.15
		clean_phrases += 1
		_judge("¡IMPECABLE!", UI.GOLD_L, 6.0)
		Sfx.play("applause", -12.0 if occasion != "campana" else -6.0)
		if stage != null:
			stage.burst(3)
	if occasion == "tragedia":
		q -= 0.1 * aired
	if _stumble:
		q -= 0.1
	q = clampf(q, 0.3, 1.25)
	qualities.append(q)
	var sum := 0.0
	for key in cur_fx.keys():
		totals[key] = totals.get(key, 0.0) + float(cur_fx[key]) * q
		sum += float(cur_fx[key])
	worm.append(clampf(worm.back() + sum * q * 2.0, 0.0, 100.0))
	await get_tree().create_timer(0.9).timeout
	if not closing:
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
	if data.has("region"):
		var rid := int(data["region"])
		var boost := snappedf(1.5 + avg * 3.5, 0.1)
		GS.add_region_boost(rid, boost)
		GS.toast.emit("Mitin en %s: +%s de intención de voto en la región" % [W.REGIONS[rid]["name"], UI.num(boost, 1)], "good", "votar")
	else:
		GS.speech_until = GS.day + (12 if GS.campaign else 45)
	if GS.campaign:
		GS.campaign_bonus += avg * (0.6 if data.has("region") else 1.8)
	var out := GS.apply_fx(fx, "Discurso")
	var verdict := "Discurso memorable" if avg >= 1.05 else ("Discurso correcto" if avg >= 0.8 else "Discurso para olvidar")
	GS.push_news("%s del presidente %s" % [{"nacion": "Mensaje a la nación", "tragedia": "Declaración institucional", "campana": "Mitin"}.get(occasion, "Discurso"), GS.pres["name"]] + (": «%s»" % verdict.to_lower()), 2)
	if not gaffes.is_empty():
		GS.push_news("Lapsus en directo: el presidente dice «%s»" % str(gaffes.pick_random()).strip_edges(), 2)
	GS.log_history("Discurso", verdict)
	var pnl := UI.panel(Color(0.03, 0.05, 0.09, 0.97), 12, Color(UI.GOLD, 0.6), 30)
	pnl.position = Vector2(560, 300)
	pnl.custom_minimum_size = Vector2(800, 0)
	var v := UI.vbox(14)
	pnl.add_child(v)
	v.add_child(UI.lbl(verdict.to_upper(), UI.f_cond_b, 48, UI.GREEN if avg >= 1.05 else (UI.AMBER if avg >= 0.8 else UI.RED)))
	v.add_child(UI.lbl("Erratas corregidas: %d de %d · Frases impecables: %d de %d · Lapsus en directo: %d" % [errors_fixed, errors_total, clean_phrases, qualities.size(), gaffes.size()], UI.f_sans_m, 19, UI.TEXT))
	if false_clicks > 0:
		v.add_child(UI.lbl("Corrigió %d palabra%s que estaba%s bien: el público notó los titubeos." % [false_clicks, "" if false_clicks == 1 else "s", "" if false_clicks == 1 else "n"], UI.f_sans, 16, UI.DIM))
	for g in gaffes.slice(0, 2):
		var gl := UI.lbl("En directo: «%s»" % str(g).strip_edges(), UI.f_serif, 19, UI.RED.lightened(0.25))
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gl.custom_minimum_size = Vector2(740, 0)
		v.add_child(gl)
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
	prompt.draw_rect(Rect2(0, 0, 1920, PROMPT_H), Color(0.02, 0.03, 0.05, 0.93))
	prompt.draw_rect(Rect2(0, 0, 1920, 2), Color(UI.GOLD, 0.5))
	prompt.draw_rect(Rect2(0, PROMPT_H - 2, 1920, 2), Color(UI.GOLD, 0.5))
	prompt.draw_string(UI.f_sans_b, Vector2(24, 22), "TELEPROMPTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.3))
	if phase != "deliver" and phase != "idle":
		var msg := "Elija la frase de esta parte del discurso" if phase == "choose" else ""
		prompt.draw_string(UI.f_sans_m, Vector2(0, PROMPT_H * 0.5 + 8), msg, HORIZONTAL_ALIGNMENT_CENTER, 1920, 20, Color(1, 1, 1, 0.25))
		return
	if phase == "deliver" and _preview > 0.0:
		prompt.draw_string(UI.f_sans_b, Vector2(0, 22), "REVÍSELO ANTES DE EMPEZAR A LEER...", HORIZONTAL_ALIGNMENT_CENTER, 1920, 14, UI.GOLD)
	var asc := UI.f_serif_b.get_ascent(_fsize)
	for i in tokens.size():
		var tk: Dictionary = tokens[i]
		var r: Rect2 = tk["rect"]
		var col := Color(1, 1, 1, 0.92)
		var off := Vector2.ZERO
		if tk["said"]:
			col = Color(1, 1, 1, 0.3)
		if tk["fixed"]:
			col = Color(UI.GREEN, 0.95 if not tk["said"] else 0.45)
		if tk["said"] and tk["bad"] != "" and not tk["fixed"]:
			# lo dijo en directo
			col = UI.RED.lightened(0.15)
			prompt.draw_rect(Rect2(r.position + Vector2(4, r.size.y - 10), Vector2(r.size.x - 8, 4)), Color(UI.RED, 0.8))
		if float(tk["wrong"]) > 0.0:
			col = UI.AMBER
			off.x = sin(_t * 60.0) * 4.0 * float(tk["wrong"]) * 2.0
		if float(tk["flash"]) > 0.0:
			prompt.draw_rect(r, Color(UI.GREEN, 0.25 * float(tk["flash"])))
		# centrada en su hueco
		var pos := r.position + Vector2(6 + (r.size.x - 12 - _word_w(tk["t"], _fsize)) * 0.5, (r.size.y - _fsize * 1.1) * 0.5 + asc) + off
		if tk["bad"] == "insert" and tk["fixed"]:
			# coletilla tachada que ya no se lee
			var a := 0.5 * (1.0 - clampf(1.0 - float(tk["flash"]), 0.0, 1.0)) + 0.18
			prompt.draw_string(UI.f_serif_b, pos, tk["t"], HORIZONTAL_ALIGNMENT_LEFT, -1, _fsize, Color(0.6, 0.62, 0.66, a))
			prompt.draw_line(Vector2(r.position.x + 4, r.get_center().y), Vector2(r.end.x - 4, r.get_center().y), Color(UI.GREEN, 0.7), 3.0)
			continue
		# la palabra que está leyendo ahora, subrayada en dorado
		if phase == "deliver" and _preview <= 0.0 and i == cursor:
			prompt.draw_rect(Rect2(r.position + Vector2(4, r.size.y - 8), Vector2(r.size.x - 8, 5)), UI.GOLD)
			col = UI.GOLD_L if not tk["fixed"] else col
		prompt.draw_string(UI.f_serif_b, pos, tk["t"], HORIZONTAL_ALIGNMENT_LEFT, -1, _fsize, col)


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
