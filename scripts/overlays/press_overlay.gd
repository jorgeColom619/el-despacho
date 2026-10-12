extends "res://scripts/ui/overlay.gd"
## Rueda de prensa / entrevista: preguntas con tiempo límite y reacción de la sala.
## Con el despacho 3D se juega en primera persona y sin ventanas: en la rueda de prensa varios periodistas alzan la
## mano con la acreditación de su medio (hostil, afín o neutral) y se elige a quién dar la palabra haciendo clic en
## él; la pregunta se oye en subtítulos y las respuestas son tarjetas sobre el atril (o sobre la mesa del plató), cada
## una con su tono. La reacción de la opinión pública sale en el monitor de la sala. Sin el despacho 3D, el dibujo 2D.

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
const LEAN_COLS := {"hostil": Color("c8443a"), "afín": Color("3f9f6a"), "neutral": Color("5f6f86")}
const LEAN_TIPS := {
	"hostil": "Medio hostil: castiga las evasivas y aplaude que vaya al ataque.",
	"afín": "Medio afín: le pondrá las cosas fáciles si no se va por las ramas.",
	"neutral": "Medio neutral: valora sobre todo la sinceridad.",
}

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
## Presentación (en 3D, un nodo vacío: al borrarlo con queue_free() las pruebas empiezan directamente)
var intro_panel: Node
var qpanel: Control
## Con el despacho 3D: la sala de prensa (o el plató de Canal 7) en primera persona. Si no, el dibujo 2D de siempre
var stage
## Rueda de prensa en 3D: los periodistas que alzan la mano [{"j", "outlet", "name", "tag", "pick"}]
var _offer: Array = []
var _who := ""
## Mano alzada de la periodista incómoda en la rueda de prensa 3D (-1 si no está)
var _cast_idx := -1
var _chosen_tag: Node3D
## Pregunta en curso: los avisos de una pregunta anterior que lleguen tarde se descartan
var _gen := 0


func build() -> void:
	mode = data.get("mode", "rueda")
	dim.color = Color(0.01, 0.015, 0.03, 0.94)
	worm = [50.0]
	var n_q := 4 if mode == "rueda" else 5
	questions = DB.press_questions(n_q, mode)
	if PressRoom.enabled():
		stage = PressRoom.new() if mode == "rueda" else Studio.new()
		root.add_child(stage)
		_build_3d()
	else:
		_build_2d()
	_intro()


## f dentro de sec segundos, si la comparecencia sigue abierta
func _after(sec: float, f: Callable) -> void:
	get_tree().create_timer(sec).timeout.connect(func():
		if not closing:
			f.call())


## Cómo ve el medio al presidente: "hostil", "afín" o "neutral"
func _lean(o: Dictionary) -> String:
	var bias := float(o.get("bias", 0.0))
	if absf(bias) <= 20.0:
		return "neutral"
	return "afín" if signf(bias) == signf(float(W.PARTIES[GS.pres["party"]]["ideo"])) else "hostil"


## Cómo cae una respuesta según su tono y el medio que pregunta
func _score(a: Dictionary) -> float:
	var s := float(a.get("s", 0))
	var tone: String = a.get("tone", "honesto")
	var bias: float = outlet.get("bias", 0.0)
	var lean := _lean(outlet)
	if tone == "ataque" and lean == "hostil":
		s += 2.0
	if tone == "evasivo" and lean == "hostil":
		s -= 2.0
	if lean == "afín" and tone != "evasivo":
		s += 1.0
	if tone == "honesto" and absf(bias) < 15.0:
		s += 1.0
	if tone == "humor":
		s += randf_range(-3.0, 3.0)
	if GS.flags.has("ley_medios"):
		s += 1.0
	s += randf_range(-1.0, 1.0)
	return s


# ------------------------------------------------------------------ sala 3D

func _build_3d() -> void:
	# la cuenta atrás no se ve: la sigue la luz del atril
	timer = TimerBar.new()
	timer.modulate.a = 0.0
	timer.position = Vector2(-500, -500)
	root.add_child(timer)
	timer.timeout.connect(_on_timeout)
	stage.timer_src = timer
	# la reacción de la opinión pública, en el monitor de la sala
	var mon: Control = stage.monitor
	worm_ctrl = Control.new()
	worm_ctrl.position = Vector2(16, 16)
	worm_ctrl.size = mon.size - Vector2(32, 92)
	worm_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	worm_ctrl.draw.connect(_draw_worm)
	mon.add_child(worm_ctrl)
	feedback = UI.lbl("", UI.f_sans_b, 30, UI.GOLD_L, HORIZONTAL_ALIGNMENT_CENTER)
	feedback.position = Vector2(0, mon.size.y - 66)
	feedback.size = Vector2(mon.size.x, 50)
	mon.add_child(feedback)


func _intro() -> void:
	if stage == null:
		_intro_2d()
		return
	intro_panel = Node.new()
	add_child(intro_panel)
	var rueda := mode == "rueda"
	stage.title_card("La prensa le espera" if rueda else "Canal 7 · En directo", "Rueda de prensa" if rueda else "Entrevista en Canal 7",
		("Responderá a %d preguntas. Elija a qué periodista da la palabra y conteste con una de las tarjetas del atril antes de que se apague la luz. El silencio se paga caro." if rueda
		else "Responderá a %d preguntas de Laura Vidal. Conteste con una de las tarjetas de la mesa antes de que se apague la luz. El silencio se paga caro.") % questions.size(), 0.0)
	_after(1.0, func():
		if qi >= 0 or not is_instance_valid(intro_panel):
			return
		stage.pov(true)
		stage.notice("Haga clic en una tarjeta")
		stage.deal_cards([
			{"tag": "Comparecencia", "title": "Empezar la rueda de prensa" if rueda else "Empezar la entrevista", "desc": "Contestar a las preguntas de los periodistas." if rueda else "Contestar en directo ante toda Valdoria.", "col": UI.GOLD, "icon": "microfono"},
			{"tag": "Escurrir el bulto", "title": "Cancelar la comparecencia", "desc": "Clase media −2 · Estabilidad −2. La prensa lo contará.", "col": Color("6b7280"), "icon": "salir"},
		], stage.top_center(), stage.top_normal(), 0.25, _on_intro_card, Vector2(0.22, 0.14), 0.4))


func _on_intro_card(i: int) -> void:
	if i == 0:
		if is_instance_valid(intro_panel):
			intro_panel.queue_free()
		Sfx.loop_start("crowd", "crowd", -18.0)
		Sfx.play("applause", -10.0)
		_next()
	else:
		_cancel()


func _cancel() -> void:
	GS.apply_fx({"clase_media": -2, "estabilidad": -2}, "Rueda de prensa")
	GS.push_news("El presidente cancela su comparecencia ante los medios", 2)
	close()


func _next() -> void:
	qi += 1
	answered = false
	_gen += 1
	if stage == null:
		_next_2d()
		return
	stage.clear_cards()
	stage.caption("", "")
	stage.notice("")
	stage.hide_title()
	_clear_offer()
	feedback.text = ""
	if qi >= questions.size():
		_finish()
		return
	if mode == "rueda":
		_offer_floor()
	else:
		outlet = {"name": "Canal 7", "bias": 0.0, "tag": "Televisión"}
		journalist = stage.ask()
		_who = W.CHARACTERS["periodista"]["name"] + " · Canal 7"
		_ask()


## Varios periodistas alzan la mano, cada uno con la acreditación de su medio encima: el jugador elige a uno
func _offer_floor() -> void:
	var hands: Array = stage.raise_hands(3)
	if hands.is_empty():
		outlet = W.OUTLETS.pick_random()
		journalist = stage.ask()
		_who = DB.rand_name("m") + " · " + String(outlet["name"])
		_ask()
		return
	var outs := _pick_outlets(hands.size())
	# si toca la pregunta de la periodista incómoda, ella está entre las manos alzadas
	_cast_idx = -1
	var cast_q: bool = questions[qi].get("cast", "") == "periodista_inc"
	var pj: Dictionary = GS.cast.get("periodista_inc", {})
	if cast_q and not pj.is_empty():
		_cast_idx = randi() % hands.size()
		for o2 in W.OUTLETS:
			if o2["name"] == pj.get("outlet", ""):
				outs[_cast_idx] = o2
	for i in hands.size():
		var j: Node3D = hands[i]
		var o: Dictionary = outs[i]
		var lean := _lean(o)
		var nm := DB.rand_name(j.get_meta("g", "m"))
		if i == _cast_idx:
			nm = str(pj.get("name", nm))
		var tag: Node3D = stage.tag3d("%d · %s" % [i + 1, o["name"]], "%s · %s" % [o["tag"], lean], LEAN_COLS[lean], j.global_position + Vector3(0, 1.78, 0), 1.15)
		# se elige pulsando en el periodista o en su acreditación (o con las teclas 1, 2, 3)
		var pk = stage.add_pick_sphere(j, 0.72, Vector3(0, 1.3, 0), "%s · %s (%s)\n%s" % [nm, o["name"], String(o["tag"]).to_lower(), LEAN_TIPS[lean]], _give_floor.bind(i))
		pk.key = i + 1
		_offer.append({"j": j, "outlet": o, "name": nm, "tag": tag, "pick": pk})
	stage.pov(false)
	stage.notice("¿A quién da la palabra? Haga clic en un periodista con la mano alzada (o pulse 1, 2 o 3)")
	# si tarda mucho, el jefe de prensa elige por él
	var gen := _gen
	_after(12.0, func():
		if gen == _gen and not _offer.is_empty():
			_give_floor(randi() % _offer.size()))


## Tres medios distintos, a ser posible uno hostil, uno afín y uno neutral
func _pick_outlets(n: int) -> Array:
	var pool: Array = W.OUTLETS.duplicate()
	pool.shuffle()
	var out := []
	for want in ["hostil", "afín", "neutral"]:
		for o in pool:
			if out.size() < n and not (o in out) and _lean(o) == want:
				out.append(o)
				break
	for o in pool:
		if out.size() < n and not (o in out):
			out.append(o)
	out.shuffle()
	return out


func _clear_offer() -> void:
	for e in _offer:
		stage.remove_pick(e["pick"])
		stage.untag(e["tag"])
	_offer.clear()
	if is_instance_valid(_chosen_tag):
		stage.untag(_chosen_tag)
	_chosen_tag = null


## Da la palabra al periodista i de los que alzan la mano
func _give_floor(i: int) -> void:
	if stage == null or i < 0 or i >= _offer.size():
		return
	var e: Dictionary = _offer[i]
	for k in _offer.size():
		stage.remove_pick(_offer[k]["pick"])
		if k != i:
			stage.untag(_offer[k]["tag"])
	_chosen_tag = e["tag"]
	_offer.clear()
	# la periodista incómoda se queda con la mano alzada: su pregunta, para el siguiente turno
	if questions[qi].get("cast", "") != "" and i != _cast_idx:
		if qi + 1 < questions.size():
			var tmp: Dictionary = questions[qi + 1]
			questions[qi + 1] = questions[qi]
			questions[qi] = tmp
		else:
			questions[qi] = DB.plain_question()
	journalist = stage.give_floor(e["j"])
	outlet = e["outlet"]
	_who = String(e["name"]) + " · " + String(outlet["name"])
	stage.notice("")
	stage.say(GS.pres["name"], ["Adelante.", "Sí, usted.", "Adelante, por favor."].pick_random(), UI.GOLD_L, null, 0.1)
	_ask()


## El periodista (o la entrevistadora) pregunta; la cámara le mira
func _ask() -> void:
	var q: Dictionary = questions[qi]
	var gen := _gen
	if is_instance_valid(journalist):
		stage.pov(false, (journalist as Node3D).global_position + Vector3(0, 1.0, 0))
	stage.say(_who, GS.fmt(q["q"]), LEAN_COLS[_lean(outlet)].lightened(0.35), journalist, 0.45, true)
	stage.after_lines(_deal_answers.bind(gen))


## Vuelta al atril: la pregunta queda arriba y las respuestas, en tarjetas
func _deal_answers(gen: int) -> void:
	if gen != _gen or answered or closing or qi >= questions.size():
		return
	var q: Dictionary = questions[qi]
	if is_instance_valid(_chosen_tag):
		stage.untag(_chosen_tag)
	stage.stop_asking()
	stage.caption(_who, GS.fmt(q["q"]), LEAN_COLS[_lean(outlet)].lightened(0.35))
	stage.pov(true)
	var opts: Array = q["a"].duplicate()
	opts = opts.filter(func(a): return not a.has("req_policy") or a["req_policy"] in GS.policies)
	var specs := []
	for a in opts:
		var tone: String = a.get("tone", "honesto")
		specs.append({"tag": TONE_NAMES.get(tone, tone), "title": GS.fmt(a["t"]), "col": TONE_COLS.get(tone, UI.GOLD), "title_k": 0.098 if opts.size() > 3 else 0.105})
	var four := opts.size() > 3
	stage.deal_cards(specs, stage.top_center(), stage.top_normal(), 0.212 if four else 0.245, func(i: int): _answer(opts[i]), Vector2(0.2, 0.135) if four else Vector2(0.225, 0.145))
	stage.notice("Elija su respuesta: haga clic en una tarjeta o pulse 1-%d" % opts.size())
	timer.start(13.0 * (0.8 if GS.stress > 75 else 1.0), "TIEMPO PARA RESPONDER")


func _answer(a: Dictionary) -> void:
	if answered or qi < 0 or qi >= questions.size():
		return
	answered = true
	timer.stop()
	if stage == null:
		_answer_2d(a)
		return
	var gen := _gen
	var s := _score(a)
	_note_answer(a, s)
	score += s
	worm.append(clampf(worm.back() + s * 3.5, 0.0, 100.0))
	GS.apply_fx(a.get("fx", {}), "Rueda de prensa")
	stage.clear_cards()
	stage.caption("", "")
	stage.notice("")
	stage.clear_lines()
	stage.pov(false)
	stage.say(GS.pres["name"] + " · Presidente del Gobierno", GS.fmt(a["t"]), UI.GOLD_L, null, 0.4)
	stage.after_lines(_react.bind(s, String(a.get("tone", "")), gen))


## La sala reacciona: asiente, se ríe o murmura; flashes; luego, la siguiente pregunta
func _react(s: float, tone: String, gen: int) -> void:
	if gen != _gen or closing:
		return
	if s >= 4:
		feedback.text = "La sala asiente. Buena respuesta."
		feedback.add_theme_color_override("font_color", UI.GREEN)
		stage.big_text("¡SE RÍEN CON USTED!" if tone == "humor" else "LA SALA ASIENTE", UI.GREEN.lightened(0.2), 100)
		Sfx.play("applause", -8.0)
	elif s >= 0:
		feedback.text = "Respuesta correcta, sin más."
		feedback.add_theme_color_override("font_color", UI.AMBER)
		stage.big_text("RESPUESTA CORRECTA", UI.AMBER, 80)
	else:
		feedback.text = "Murmullos en la sala. No ha convencido."
		feedback.add_theme_color_override("font_color", UI.RED)
		stage.big_text("MURMULLOS EN LA SALA", UI.RED.lightened(0.15), 92)
		stage.shake(0.2)
		Sfx.play("crowd", -6.0, 1.2)
	stage.react(s, tone)
	Sfx.play("flash", -6.0)
	_after(2.3, func():
		if gen == _gen:
			stage.after_lines(_next_if.bind(gen)))


func _next_if(gen: int) -> void:
	if gen == _gen and not closing:
		_next()


## Lo que contesta queda en la hemeroteca: la periodista incómoda puede recordárselo meses después
func _note_answer(a: Dictionary, s: float) -> void:
	if qi < 0 or qi >= questions.size():
		return
	var q: Dictionary = questions[qi]
	if q.get("memo", false) or q.get("promise", false):
		return
	var tone := str(a.get("tone", ""))
	if tone in ["evasivo", "ataque", "humor"] or s < 0.0 or randf() < 0.25:
		GS.remember("prensa", {"q": GS.fmt(q["q"]), "a": GS.fmt(a["t"]), "tone": tone, "outlet": str(outlet.get("name", ""))})


func _on_timeout() -> void:
	if answered:
		return
	answered = true
	score -= 5.0
	worm.append(clampf(worm.back() - 16.0, 0.0, 100.0))
	GS.apply_fx({"clase_media": -2}, "Rueda de prensa")
	Sfx.play("fail", -4.0)
	if stage == null:
		timer.visible = true
		feedback.text = "Silencio incómodo... La prensa lo destrozará mañana."
		_after(1.8, _next)
		return
	var gen := _gen
	stage.dim_cards()
	stage.clear_cards()
	stage.caption("", "")
	stage.notice("")
	stage.pov(false)
	stage.say(GS.pres["name"], "Eh... Bueno... Eso... Siguiente pregunta.", UI.GOLD_L, null, 0.3)
	stage.after_lines(func():
		if gen != _gen or closing:
			return
		feedback.text = "Silencio incómodo..."
		feedback.add_theme_color_override("font_color", UI.RED)
		stage.big_text("SILENCIO INCÓMODO", UI.RED.lightened(0.15), 96)
		stage.react(-5.0)
		_after(2.3, func():
			if gen == _gen:
				stage.after_lines(_next_if.bind(gen))))


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
	var col := UI.GREEN if avg >= 3.0 else (UI.AMBER if avg >= 1.0 else UI.RED)
	var line := "Valoración media de sus respuestas: %s" % UI.num(avg, 1)
	if stage == null:
		_finish_2d(verdict, col, line, out)
		return
	stage.clear_cards()
	stage.caption("", "")
	stage.notice("")
	_clear_offer()
	stage.pov(false)
	stage.react(avg)
	if avg >= 1.0:
		Sfx.play("applause", -6.0)
	stage.say(_who if mode != "rueda" else "Jefe de prensa", "Muchas gracias, presidente." if mode != "rueda" else "Muchas gracias. Se acabaron las preguntas.", UI.GOLD, journalist if mode != "rueda" else null, 0.5)
	stage.end_card(verdict.to_upper(), col, line, Widgets.effect_chips(out, 16, 8), "Volver al despacho", func(): close())


func _process(delta: float) -> void:
	_t += delta
	if worm_ctrl != null:
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


func _draw_worm() -> void:
	var w := worm_ctrl.size.x
	var h := worm_ctrl.size.y
	var big := stage != null
	worm_ctrl.draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.05, 0.09, 0.9))
	worm_ctrl.draw_rect(Rect2(0, 0, w, h), Color(UI.GOLD, 0.4), false, 1.0)
	var title := "REACCIÓN DE LA OPINIÓN PÚBLICA"
	if big:
		title = ("24H · EN DIRECTO · " if mode == "rueda" else "CANAL 7 · AUDIENCIA · ") + "REACCIÓN"
	worm_ctrl.draw_string(UI.f_sans_b, Vector2(14, 34 if big else 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26 if big else 13, UI.RED.lightened(0.25) if big else UI.DIM)
	worm_ctrl.draw_line(Vector2(14, h * 0.58), Vector2(w - 14, h * 0.58), Color(1, 1, 1, 0.15), 1.0)
	var series := worm.duplicate()
	if series.size() < 2:
		series.append(series[0])
	var last: float = series.back()
	Widgets.draw_line_chart(worm_ctrl, Rect2(14, 50 if big else 34, w - 28, h - (70 if big else 50)), series, UI.color_for(last), 0.0, 100.0, 6.0 if big else 3.0)


func on_escape() -> void:
	pass


# ------------------------------------------------------------------ sala 2D (sin el despacho 3D)

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


func _intro_2d() -> void:
	var ip := UI.panel(Color(0.03, 0.05, 0.09, 0.97), 12, Color(UI.GOLD, 0.6), 30)
	intro_panel = ip
	ip.custom_minimum_size = Vector2(800, 0)
	var v := UI.vbox(16)
	ip.add_child(v)
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
	no.pressed.connect(_cancel)
	h.add_child(no)
	v.add_child(h)
	ip.position = Vector2(560, 360)
	root.add_child(ip)
	UI.pop_in(ip)


func _next_2d() -> void:
	qpanel.visible = true
	for c in answers.get_children():
		c.queue_free()
	feedback.text = ""
	if qi >= questions.size():
		_finish()
		return
	var q: Dictionary = questions[qi]
	var gen := _gen
	if mode == "rueda" and q.get("cast", "") != "" and GS.cast.has(str(q["cast"])):
		# la periodista incómoda de la partida
		var pj: Dictionary = GS.cast[str(q["cast"])]
		outlet = {"name": pj.get("outlet", "El Heraldo"), "bias": pj.get("bias", 40.0), "tag": pj.get("tag", "")}
		journalist.setup(pj.get("look", {}), false)
		raised = randi() % heads.size()
		j_name.text = str(pj.get("name", ""))
	elif mode == "rueda":
		outlet = W.OUTLETS.pick_random()
		var g := "m" if randf() < 0.5 else "f"
		journalist.setup(DB.rand_look(g), false)
		raised = randi() % heads.size()
		j_name.text = DB.rand_name(g)
	else:
		outlet = {"name": "Canal 7", "bias": 0.0, "tag": "Televisión"}
		journalist.setup(W.CHARACTERS["periodista"]["look"], false)
		j_name.text = W.CHARACTERS["periodista"]["name"]
	j_outlet.text = "%s · %s" % [outlet["name"].to_upper(), outlet["tag"]]
	journalist.talking = true
	q_text.play(GS.fmt(q["q"]), 50.0)
	await q_text.typed
	if gen != _gen or closing:
		return
	journalist.talking = false
	_show_answers_2d(q)


func _show_answers_2d(q: Dictionary) -> void:
	var opts: Array = q["a"].duplicate()
	opts = opts.filter(func(a): return not a.has("req_policy") or a["req_policy"] in GS.policies)
	for i in opts.size():
		var a: Dictionary = opts[i]
		var tone: String = a.get("tone", "honesto")
		var l := UI.lbl(GS.fmt(a["t"]), UI.f_sans_m, 20, UI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(840, 0)
		var v := UI.vbox(6)
		var th := UI.hbox(10)
		th.add_child(Widgets.chip("", TONE_NAMES.get(tone, tone), TONE_COLS.get(tone, UI.GOLD), 14))
		v.add_child(th)
		v.add_child(l)
		var idx := i
		var card := Widgets.click_card(v, func(): _answer(opts[idx]), 14)
		answers.add_child(card)
		UI.pop_in(card, 0.25)
	timer.start(13.0 * (0.8 if GS.stress > 75 else 1.0), "TIEMPO PARA RESPONDER")
	timer.visible = true


func _answer_2d(a: Dictionary) -> void:
	for c in answers.get_children():
		c.set_meta("enabled", false)
		c.modulate.a = 0.4
	var s := _score(a)
	_note_answer(a, s)
	score += s
	worm.append(clampf(worm.back() + s * 3.5, 0.0, 100.0))
	GS.apply_fx(a.get("fx", {}), "Rueda de prensa")
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
	for i in 4:
		flashes.append({"p": Vector2(randf_range(80, 1840), randf_range(520, 900)), "t": -i * 0.12})
	Sfx.play("flash", -6.0)
	UI.pop_in(feedback)
	var gen := _gen
	_after(1.8, func():
		if gen == _gen:
			_next())


func _finish_2d(verdict: String, col: Color, line: String, out: Array) -> void:
	qpanel.visible = false
	var p := UI.panel(Color(0.03, 0.05, 0.09, 0.97), 12, Color(UI.GOLD, 0.6), 30)
	p.custom_minimum_size = Vector2(800, 0)
	var v := UI.vbox(14)
	p.add_child(v)
	v.add_child(UI.lbl(verdict.to_upper(), UI.f_cond_b, 48, col))
	v.add_child(UI.lbl(line, UI.f_sans_m, 19, UI.TEXT))
	var chips := Widgets.effect_chips(out, 16, 8)
	chips.custom_minimum_size = Vector2(740, 0)
	v.add_child(chips)
	var b := UI.btn("Volver al despacho", "gold", 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.pressed.connect(func(): close())
	v.add_child(b)
	p.position = Vector2(560, 360)
	root.add_child(p)
	UI.pop_in(p)


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
