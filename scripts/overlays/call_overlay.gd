extends "res://scripts/ui/overlay.gd"
## Videollamada: diálogo simple o negociación en tiempo real.

const Widgets := preload("res://scripts/ui/widgets.gd")
const Typewriter := preload("res://scripts/ui/typewriter.gd")
const TimerBar := preload("res://scripts/ui/timer_bar.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const Flags := preload("res://scripts/ui/flags.gd")
const W := preload("res://scripts/data/world_data.gd")

const LINES := {
	"arg_ok": ["Entiendo su punto de vista.", "Sus números son... interesantes.", "Hmm. Tiene cierta lógica, lo admito.", "Es un argumento razonable."],
	"arg_meh": ["Ya he oído eso antes.", "No me convence del todo.", "Palabras, presidente. Palabras."],
	"pres": ["¿Me está presionando, presidente?", "No me gusta ese tono.", "Está bien, está bien... lo consideraré.", "Veo que no se anda con rodeos."],
	"pres_bad": ["¡No tolero que me hablen así!", "Cuidado. Está jugando con fuego."],
	"flat_good": ["¡Por fin alguien que me entiende!", "Es usted muy amable, presidente.", "Vaya, qué gentileza. Sigamos."],
	"flat_meh": ["Gracias, pero vayamos al grano.", "Los halagos no pagan facturas."],
	"cede": ["Eso ya es otra cosa.", "Un gesto que valoro.", "Así sí podemos entendernos."],
	"threat_ok": ["...Está bien. No hace falta llegar a eso.", "Veo que va en serio. De acuerdo.", "Tranquilo, presidente. Hablemos."],
	"threat_bad": ["¿Me amenaza? ¿A mí?", "Cometerá un grave error.", "Nadie amenaza a mi país."],
	"refuse": ["Eso es inaceptable.", "Ni lo sueñe, presidente.", "Todavía estamos lejos."],
	"deal": ["Tenemos un acuerdo.", "Trato hecho. Mis equipos le llamarán.", "Un placer hacer negocios con usted."],
	"walk": ["Esta conversación ha terminado.", "Me cansa usted. Adiós.", "Lo lamento, presidente. No hay acuerdo."],
	"timeout": ["¿Presidente? ¿Sigue ahí?", "El silencio no es una respuesta.", "Mi tiempo es valioso, presidente."],
	"counter": ["Le propongo esto: %s. Es mi mejor oferta.", "Hagamos una cosa: %s. ¿Qué me dice?", "Puedo llegar hasta aquí: %s."],
	"final": ["Última oferta: %s. O lo toma o lo deja.", "Se me acaba la paciencia. %s, y cerramos."],
}

const OPENERS := {
	"orgulloso": "Presidente, espero que sepa valorar el honor de sentarse a negociar conmigo.",
	"agresivo": "Seré breve, presidente. Sé lo que quiero y sé cómo conseguirlo.",
	"pragmatico": "Buenos días, presidente. Vayamos a los números.",
	"paciente": "Tengo todo el tiempo del mundo, presidente. ¿Y usted?",
	"volatil": "¡Presidente! Hoy estoy de buen humor... de momento.",
}

var who := ""
var ch: Dictionary
var country := ""
var item: Dictionary
var ev: Dictionary
var portrait: Control
var bubble: RichTextLabel
var right: VBoxContainer
var call_time := 0.0
var time_lbl: Label
# negociación
var nego := false
var topic: Dictionary
var pers: Dictionary
var cp: Dictionary
var v := 0.0
var v_show := 0.0
var mood := 50.0
var patience := 6
var patience_max := 6
var thr := 0.0
var round_timer: Control
var meter: Control
var mood_lbl: Label
var tactics_box: HBoxContainer
var counter_box: VBoxContainer
var fx_box: Control
var counter_v := -999.0
var last_tactic := ""
var flat_count := 0
var ended := false
var busy := false
var my_power := 50.0
var est_err := 0.0


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.9)
	nego = data.get("nego", false)
	if nego:
		who = data.get("who", "")
		topic = DB.topic(who, data.get("topic", ""))
		if topic.is_empty():
			close()
			return
	else:
		item = data.get("item", {})
		ev = item.get("ev", {})
		who = ev.get("who", "")
		GS.calls.erase(item)
		GS.queue_changed.emit()
	ch = DB.character(who)
	country = ch.get("country", "")
	Sfx.play("notify", -6.0, 0.8)
	_build_feed()
	right = UI.vbox(14)
	right.position = Vector2(930, 128)
	right.size = Vector2(920, 900)
	root.add_child(right)
	if nego:
		_build_nego()
	else:
		_build_dialog()


# ------------------------------------------------------------------ vídeo

func _build_feed() -> void:
	var feed := Control.new()
	feed.position = Vector2(70, 128)
	feed.size = Vector2(820, 880)
	feed.clip_contents = true
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(feed)
	var bg := Control.new()
	bg.size = feed.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(func():
		if country != "":
			Flags.draw_flag(bg, country, Rect2(-60, 0, 940, 620))
		else:
			bg.draw_rect(Rect2(0, 0, 820, 880), Color("24324a"))
			for i in 8:
				bg.draw_rect(Rect2(i * 110, 0, 50, 880), Color(1, 1, 1, 0.025))
		bg.draw_rect(Rect2(0, 0, 820, 880), Color(0.02, 0.03, 0.06, 0.5))
		for i in 14:
			var c := Vector2(fmod(i * 173.0, 820.0), fmod(i * 97.0, 500.0))
			bg.draw_circle(c, 20 + (i % 4) * 14, Color(1, 0.95, 0.8, 0.04)))
	feed.add_child(bg)
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0))
	gr.set_color(1, Color(0.01, 0.015, 0.03, 0.95))
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0.35)
	gt.fill_to = Vector2(0, 1)
	grad.texture = gt
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.size = feed.size
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait = Portrait.new()
	portrait.position = Vector2(80, 110)
	portrait.size = Vector2(660, 792)
	feed.add_child(portrait)
	portrait.setup(ch.get("look", {}), true)
	feed.add_child(grad)
	# rótulos
	var live := Control.new()
	live.position = Vector2(24, 20)
	live.size = Vector2(760, 40)
	live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	live.draw.connect(func():
		live.draw_rect(Rect2(0, 0, 330, 34), Color(0, 0, 0, 0.55))
		live.draw_circle(Vector2(18, 17), 6, Color(1, 0.2, 0.2, 0.6 + 0.4 * sin(call_time * 5.0)))
		live.draw_string(UI.f_sans_b, Vector2(32, 23), "EN DIRECTO · LÍNEA SEGURA CIFRADA", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE))
	feed.add_child(live)
	time_lbl = UI.lbl("00:00", UI.f_mono, 20, Color.WHITE)
	time_lbl.position = Vector2(700, 24)
	feed.add_child(time_lbl)
	var lower := UI.vbox(0)
	lower.position = Vector2(32, 700)
	feed.add_child(lower)
	lower.add_child(UI.lbl(ch.get("role", "").to_upper(), UI.f_sans_b, 15, UI.GOLD))
	lower.add_child(UI.lbl(ch.get("name", ""), UI.f_serif_b, 44, UI.CREAM))
	bubble = Typewriter.new()
	bubble.position = Vector2(32, 790)
	bubble.custom_minimum_size = Vector2(756, 0)
	bubble.size = Vector2(756, 60)
	bubble.add_theme_font_override("normal_font", UI.f_serif)
	bubble.add_theme_font_size_override("normal_font_size", 24)
	bubble.add_theme_color_override("default_color", Color(1, 1, 1, 0.92))
	feed.add_child(bubble)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0), 4, Color(UI.GOLD, 0.6), 2))
	frame.size = feed.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed.add_child(frame)


func say(t: String) -> void:
	bubble.play("«" + GS.fmt(t) + "»", 48.0)


func _process(delta: float) -> void:
	call_time += delta
	if time_lbl != null:
		time_lbl.text = "%02d:%02d" % [int(call_time) / 60, int(call_time) % 60]
	if portrait != null and bubble != null:
		portrait.talking = bubble.is_running()
	if nego:
		v_show = lerpf(v_show, v, minf(1.0, delta * 6.0))
		if meter != null:
			meter.queue_redraw()
		if portrait != null:
			portrait.mood = clampf((mood - 50.0) / 35.0, -1.0, 1.0)
			portrait.anger = clampf((35.0 - mood) / 30.0, 0.0, 1.0)


# ------------------------------------------------------------------ diálogo

func _build_dialog() -> void:
	right.add_child(UI.lbl("LLAMADA ENTRANTE", UI.f_sans_b, 15, UI.GOLD))
	var t := UI.lbl(GS.fmt(ev.get("title", "")), UI.f_serif_b, 40, UI.CREAM)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(900, 0)
	right.add_child(t)
	right.add_child(Widgets.section("Conversación"))
	var txt := UI.rich(GS.fmt(ev.get("text", "")), 22, UI.TEXT, UI.f_serif)
	txt.custom_minimum_size = Vector2(900, 0)
	right.add_child(txt)
	say(ev.get("text", "").left(140) + ("…" if ev.get("text", "").length() > 140 else ""))
	right.add_child(UI.spacer(0, 10))
	var choices: Array = ev.get("choices", [])
	for i in choices.size():
		var c: Dictionary = choices[i]
		var cv := UI.vbox(8)
		var l := UI.lbl(GS.fmt(c["t"]), UI.f_sans_m, 21, UI.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(860, 0)
		cv.add_child(l)
		var chips := Widgets.effect_chips(GS.preview(c.get("fx", {})), 15, 7)
		chips.custom_minimum_size = Vector2(860, 0)
		cv.add_child(chips)
		var idx := i
		var card := Widgets.click_card(cv, func(): _dialog_choice(idx), 16)
		right.add_child(card)


func _dialog_choice(i: int) -> void:
	if busy:
		return
	busy = true
	for c in right.get_children():
		if c is PanelContainer:
			c.set_meta("enabled", false)
			c.modulate.a = 0.4
	var out := GS.resolve_choice(item, i)
	var s := 0.0
	for o in out:
		s += float(o["v"]) if not (o["k"] in ["money", "monthly"]) else 0.0
	portrait.mood = clampf(s / 8.0, -0.8, 0.8)
	var fx: Dictionary = ev["choices"][i].get("fx", {})
	if fx.has("nego"):
		say("Muy bien. Hablemos entonces.")
	else:
		say(["Entendido, presidente. Hasta pronto.", "Tomo nota. Buenas tardes.", "Muy bien. Seguiremos en contacto."].pick_random())
	await get_tree().create_timer(2.2).timeout
	Sfx.play("close", -4.0)
	close()


# ------------------------------------------------------------------ negociación

func _build_nego() -> void:
	cp = DB.counterpart(who)
	pers = W.PERSONALITIES.get(cp["pers"], W.PERSONALITIES["pragmatico"])
	my_power = GS.meters["economia"] * 0.35 + GS.meters["prestigio"] * 0.35 + GS.budget["defensa"] * 20.0 + GS.treaty_count() * 3.0
	var rel: float = cp["rel"]
	mood = clampf(50.0 + rel * 0.3, 15.0, 85.0)
	patience_max = int(pers["patience"]) + (1 if GS.difficulty == 0 else 0)
	patience = patience_max
	est_err = randf_range(-9.0, 9.0) * (0.6 if GS.ministers.has("exteriores") else 1.0)
	thr = -32.0 + rel * 0.22 + float(pers["thr"]) + (GS.meters["prestigio"] - 50.0) * 0.2 - (GS.difficulty - 1) * 6.0 + randf_range(-6, 6)
	right.add_child(UI.lbl("NEGOCIACIÓN · " + (W.COUNTRIES[country]["full"].to_upper() if country != "" else ch.get("role", "").to_upper()), UI.f_sans_b, 15, UI.GOLD))
	var t := UI.lbl(topic["name"], UI.f_serif_b, 40, UI.CREAM)
	right.add_child(t)
	var d := UI.lbl(GS.fmt(topic.get("desc", "")), UI.f_sans, 19, UI.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(900, 0)
	right.add_child(d)
	# perfil
	var prof := UI.hbox(26)
	var pv := UI.vbox(2)
	pv.add_child(UI.lbl("CARÁCTER", UI.f_sans_b, 12, UI.DIM))
	pv.add_child(UI.lbl(pers["name"], UI.f_sans_b, 20, UI.TEXT))
	var pd := UI.lbl(pers["desc"], UI.f_sans, 15, UI.DIM)
	pd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pd.custom_minimum_size = Vector2(330, 0)
	pv.add_child(pd)
	prof.add_child(pv)
	var pw := UI.vbox(2)
	pw.add_child(UI.lbl("PODER NEGOCIADOR", UI.f_sans_b, 12, UI.DIM))
	pw.add_child(UI.lbl("Valdoria %d  vs  %d" % [int(my_power), int(cp["power"])], UI.f_sans_b, 20, UI.GREEN if my_power >= cp["power"] else UI.AMBER))
	pw.add_child(UI.lbl("Relación: %s" % UI.signed(rel, 0), UI.f_sans, 15, UI.color_for(50.0 + rel * 0.5)))
	prof.add_child(pw)
	var mv := UI.vbox(2)
	mv.add_child(UI.lbl("ESTADO DE ÁNIMO", UI.f_sans_b, 12, UI.DIM))
	mood_lbl = UI.lbl("", UI.f_sans_b, 20, UI.TEXT)
	mv.add_child(mood_lbl)
	prof.add_child(mv)
	right.add_child(prof)
	# medidor del acuerdo
	meter = Control.new()
	meter.custom_minimum_size = Vector2(900, 150)
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.draw.connect(_draw_meter)
	right.add_child(meter)
	fx_box = UI.vbox(4)
	right.add_child(fx_box)
	round_timer = TimerBar.new()
	round_timer.custom_minimum_size = Vector2(900, 8)
	right.add_child(UI.spacer(0, 6))
	right.add_child(round_timer)
	round_timer.timeout.connect(_on_round_timeout)
	counter_box = UI.vbox(6)
	right.add_child(counter_box)
	tactics_box = UI.hbox(10)
	right.add_child(tactics_box)
	_build_tactics()
	var hang := UI.btn("Colgar el teléfono", "ghost", 17)
	hang.size_flags_horizontal = Control.SIZE_SHRINK_END
	hang.pressed.connect(func(): _end(false, "Ha colgado usted."))
	right.add_child(hang)
	_update_mood()
	_update_fx()
	say(OPENERS.get(cp["pers"], "Hablemos, presidente."))
	round_timer.start(_round_seconds(), "TIEMPO PARA RESPONDER")


func _round_seconds() -> float:
	return 16.0 * (0.8 if GS.stress > 75 else 1.0)


func _term_value(pos: float) -> float:
	var term: Array = topic["term"]
	return lerpf(float(term[1]), float(term[2]), (pos + 100.0) / 200.0)


func _term_text(pos: float) -> String:
	var term: Array = topic["term"]
	var val := _term_value(pos)
	var unit: String = term[3]
	if unit.begins_with(" M€"):
		return "%s%s" % [UI.money(val), unit.substr(3)]
	if unit == "%":
		return "%s%%" % UI.num(val, 0 if absf(val) >= 10 else 1)
	if unit == "":
		return UI.num(val, 0)
	return UI.num(val, 0) + unit


func _draw_meter() -> void:
	var w := meter.size.x
	var y := 62.0
	var term: Array = topic["term"]
	meter.draw_string(UI.f_sans_b, Vector2(0, 16), String(term[0]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)
	var their_c := Color(W.COUNTRIES[country]["color"]) if country != "" else UI.RED
	var pts := PackedVector2Array([Vector2(0, y - 14), Vector2(w, y - 14), Vector2(w, y + 14), Vector2(0, y + 14)])
	meter.draw_polygon(pts, PackedColorArray([their_c.darkened(0.2), UI.GOLD_D, UI.GOLD_D, their_c.darkened(0.2)]))
	# zona probable de acuerdo (estimación del Ministerio de Exteriores)
	var est := _thr_now() + est_err
	var zx := (est + 100.0) / 200.0 * w
	meter.draw_rect(Rect2(0, y - 14, zx, 28), Color(0.3, 1.0, 0.5, 0.18))
	meter.draw_line(Vector2(zx, y - 22), Vector2(zx, y + 22), Color(0.4, 1.0, 0.6, 0.5), 2.0)
	meter.draw_string(UI.f_sans_m, Vector2(maxf(0.0, zx - 150), y - 26), "zona probable de acuerdo", HORIZONTAL_ALIGNMENT_RIGHT, 146, 12, Color(0.5, 1.0, 0.65, 0.8))
	for i in 11:
		var tx := w * i / 10.0
		meter.draw_line(Vector2(tx, y + 14), Vector2(tx, y + 20), Color(1, 1, 1, 0.3), 1.0)
	meter.draw_string(UI.f_sans_m, Vector2(0, y + 42), "Lo que quieren ellos: " + _term_text(-100), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, their_c.lightened(0.4))
	meter.draw_string(UI.f_sans_m, Vector2(0, y + 42), "Lo que quiere Valdoria: " + _term_text(100), HORIZONTAL_ALIGNMENT_RIGHT, w, 15, UI.GOLD_L)
	var mx := (v_show + 100.0) / 200.0 * w
	meter.draw_colored_polygon(PackedVector2Array([Vector2(mx, y + 16), Vector2(mx - 12, y + 34), Vector2(mx + 12, y + 34)]), Color.WHITE)
	meter.draw_rect(Rect2(mx - 3, y - 22, 6, 44), Color.WHITE)
	var label := _term_text(v_show)
	var lw := UI.f_cond_b.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	var lx := clampf(mx - lw / 2.0, 0.0, w - lw)
	meter.draw_string(UI.f_cond_b, Vector2(lx, y - 28), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	# paciencia
	meter.draw_string(UI.f_sans_b, Vector2(0, y + 76), "PACIENCIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
	for i in patience_max:
		var on := i < patience
		meter.draw_rect(Rect2(96 + i * 34, y + 64, 28, 12), (UI.GOLD if patience > 2 else UI.RED) if on else Color(1, 1, 1, 0.1))
	meter.draw_string(UI.f_sans_b, Vector2(0, y + 76), "ÁNIMO", HORIZONTAL_ALIGNMENT_RIGHT, w - 210, 12, UI.DIM)
	meter.draw_rect(Rect2(w - 200, y + 64, 200, 12), Color(1, 1, 1, 0.1))
	meter.draw_rect(Rect2(w - 200, y + 64, 2.0 * mood, 12), UI.color_for(mood))


func _update_mood() -> void:
	var m := "Cordial"
	var c := UI.GREEN
	if mood < 20:
		m = "Furioso"
		c = UI.RED
	elif mood < 38:
		m = "Irritado"
		c = UI.RED.lerp(UI.AMBER, 0.4)
	elif mood < 55:
		m = "Tenso"
		c = UI.AMBER
	elif mood < 72:
		m = "Receptivo"
		c = UI.GREEN.lerp(UI.AMBER, 0.3)
	mood_lbl.text = m
	mood_lbl.add_theme_color_override("font_color", c)


func _deal_fx(pos: float) -> Dictionary:
	var t := (pos + 100.0) / 200.0
	return _lerp_fx(topic.get("fx_min", {}), topic.get("fx_max", {}), t)


func _lerp_fx(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	var keys := a.keys()
	for k in b.keys():
		if not (k in keys):
			keys.append(k)
	for k in keys:
		var va = a.get(k, null)
		var vb = b.get(k, null)
		if (va is Dictionary) or (vb is Dictionary):
			out[k] = _lerp_fx(va if va is Dictionary else {}, vb if vb is Dictionary else {}, t)
		elif (va is float or va is int or va == null) and (vb is float or vb is int or vb == null):
			out[k] = snappedf(lerpf(float(va if va != null else 0.0), float(vb if vb != null else 0.0), t), 0.1)
		else:
			out[k] = vb if vb != null else va
	return out


func _update_fx() -> void:
	for c in fx_box.get_children():
		c.queue_free()
	var h := UI.hbox(10)
	h.add_child(UI.lbl("Si se cierra ahora:", UI.f_sans_m, 15, UI.DIM))
	var chips := Widgets.effect_chips(GS.preview(_deal_fx(v)), 14, 7)
	chips.custom_minimum_size = Vector2(740, 0)
	h.add_child(chips)
	fx_box.add_child(h)


func _build_tactics() -> void:
	var specs := [
		["argumentar", "Argumentar", "libro", "Datos y razones. Avance moderado."],
		["presionar", "Presionar", "presion", "Gran avance. Irrita."],
		["halagar", "Halagar", "sonrisa", "Mejora el ánimo."],
		["ceder", "Ceder", "ceder", "Retrocede, pero calma."],
		["amenazar", "Amenazar", "rayo", "Todo o nada. Daña la relación."],
		["cerrar", "Cerrar trato", "acuerdo", "Propone firmar en el punto actual."],
	]
	for s in specs:
		var card := _tactic_card(s[0], s[1], s[2], s[3])
		tactics_box.add_child(card)


func _tactic_card(id: String, title: String, icon_name: String, desc: String) -> Control:
	var v2 := UI.vbox(6)
	v2.custom_minimum_size = Vector2(120, 150)
	var ic := UI.icon_rect(icon_name, 34, UI.GOLD_L if id == "cerrar" else UI.TEXT)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v2.add_child(ic)
	var t := UI.lbl(title, UI.f_sans_b, 17, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	v2.add_child(t)
	var d := UI.lbl(desc, UI.f_sans, 13, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(118, 0)
	v2.add_child(d)
	var bg := Color(0.2, 0.16, 0.08, 0.95) if id == "cerrar" else Color(0.08, 0.12, 0.19, 0.95)
	var card := Widgets.click_card(v2, func(): _tactic(id), 12, bg)
	return card


func _set_cards(on: bool) -> void:
	for c in tactics_box.get_children():
		c.set_meta("enabled", on)
		c.modulate.a = 1.0 if on else 0.45
	for c in counter_box.get_children():
		if c is PanelContainer:
			c.set_meta("enabled", on)


func _tactic(id: String) -> void:
	if busy or ended:
		return
	busy = true
	round_timer.stop()
	_set_cards(false)
	var ratio := clampf(my_power / maxf(10.0, cp["power"]), 0.5, 1.6)
	var line := ""
	match id:
		"argumentar":
			var dv: float = randf_range(8, 16) * float(pers["arg"]) * (0.8 + GS.meters["prestigio"] / 250.0)
			if last_tactic == "argumentar":
				dv *= 0.7
			v += dv
			mood -= 2.0
			line = (LINES["arg_ok"] if dv > 10 else LINES["arg_meh"]).pick_random()
		"presionar":
			var dv2 := randf_range(14, 26) * float(pers["pres"]) * ratio
			v += dv2
			var ml := 10.0 * (1.5 if cp["pers"] == "orgulloso" else 1.0)
			mood -= ml
			_rel(-1.0)
			line = (LINES["pres_bad"] if mood < 35 else LINES["pres"]).pick_random()
		"halagar":
			flat_count += 1
			var gain := 11.0 * float(pers["flat"]) / flat_count
			mood += gain
			v += 2.0
			line = (LINES["flat_good"] if gain > 8 else LINES["flat_meh"]).pick_random()
		"ceder":
			v -= 15.0
			mood += 12.0
			line = LINES["cede"].pick_random()
		"amenazar":
			var chance := clampf(0.3 + (my_power - float(cp["power"])) / 100.0, 0.1, 0.8)
			_rel(-4.0)
			if randf() < chance:
				v += 34.0
				mood -= 12.0 * float(pers["threat_mood"])
				line = LINES["threat_ok"].pick_random()
			else:
				mood -= 28.0 * float(pers["threat_mood"])
				_rel(-5.0)
				line = LINES["threat_bad"].pick_random()
		"cerrar":
			if v <= _thr_now():
				_end(true, LINES["deal"].pick_random())
				return
			mood -= 8.0
			line = LINES["refuse"].pick_random()
	last_tactic = id
	v = clampf(v, -100.0, 100.0)
	mood = clampf(mood, 0.0, 100.0)
	patience -= 1
	Sfx.play("paper2", -10.0, 1.4)
	_update_mood()
	_update_fx()
	say(line)
	await get_tree().create_timer(1.3).timeout
	_ai_turn()


func _thr_now() -> float:
	return thr + (mood - 50.0) * 0.8


func _rel(d: float) -> void:
	if country != "":
		GS.countries[country]["rel"] = clampf(GS.countries[country]["rel"] + d, -100.0, 100.0)


func _ai_turn() -> void:
	if ended:
		return
	if mood <= 4.0:
		_end(false, LINES["walk"].pick_random())
		return
	var t := _thr_now()
	for c in counter_box.get_children():
		c.queue_free()
	counter_v = -999.0
	if cp["pers"] in ["agresivo", "volatil"] and randf() < 0.35 and v > t:
		v -= randf_range(3, 9)
	if patience <= 0:
		counter_v = clampf(t - randf_range(0, 5), -100.0, 100.0)
		say(LINES["final"].pick_random() % _term_text(counter_v))
		_show_counter(true)
		busy = false
		return
	if (patience % 2 == 0 or v > t + 12.0) and t > -95.0:
		counter_v = clampf(t - randf_range(2, 10), -100.0, v)
		if counter_v > v - 1.0:
			counter_v = -999.0
		else:
			pass
	if counter_v > -999.0:
		say(LINES["counter"].pick_random() % _term_text(counter_v))
		_show_counter(false)
	busy = false
	_set_cards(true)
	round_timer.start(_round_seconds(), "TIEMPO PARA RESPONDER")


func _show_counter(final: bool) -> void:
	var h := UI.hbox(14)
	var ic := UI.icon_rect("mediador", 28, UI.GOLD_L)
	h.add_child(ic)
	var l := UI.lbl(("ÚLTIMA OFERTA: " if final else "CONTRAOFERTA: ") + _term_text(counter_v) + "  —  Aceptar", UI.f_sans_b, 19, UI.GOLD_L)
	h.add_child(l)
	var card := Widgets.click_card(h, func():
		if ended:
			return
		v = counter_v
		_end(true, LINES["deal"].pick_random()), 12, Color(0.18, 0.14, 0.06, 0.95))
	counter_box.add_child(card)
	UI.pop_in(card)
	if final:
		_set_cards(false)
		var no := UI.btn("Rechazar y colgar", "danger", 17)
		no.pressed.connect(func(): _end(false, "Entonces no hay nada más que hablar."))
		counter_box.add_child(no)
		round_timer.start(12.0, "ÚLTIMA OPORTUNIDAD")


func _on_round_timeout() -> void:
	if ended or busy:
		return
	if patience <= 0:
		_end(false, LINES["walk"].pick_random())
		return
	mood -= 9.0
	patience -= 1
	_update_mood()
	say(LINES["timeout"].pick_random())
	Sfx.play("fail", -10.0)
	busy = true
	_set_cards(false)
	await get_tree().create_timer(1.2).timeout
	_ai_turn()


func _end(deal: bool, line: String) -> void:
	if ended:
		return
	ended = true
	round_timer.stop()
	_set_cards(false)
	say(line)
	var fx := {}
	if deal:
		fx = _deal_fx(v)
		portrait.mood = 0.7
		Sfx.play("success", -2.0)
		if topic.has("treaty") and country != "":
			GS.add_treaty(country, topic["treaty"])
		if topic.has("flag"):
			fx["flag"] = topic["flag"]
		GS.push_news("Acuerdo con %s: %s (%s)" % [W.COUNTRIES[country]["name"] if country != "" else ch.get("name", ""), topic["name"].to_lower(), _term_text(v)], 3)
	else:
		fx = topic.get("nodeal", {"rel": {country: -4.0}} if country != "" else {"estabilidad": -2}).duplicate(true)
		portrait.mood = -0.5
		portrait.anger = 0.5
		Sfx.play("fail", -2.0)
		GS.push_news("Fracasan las negociaciones con %s sobre %s" % [W.COUNTRIES[country]["name"] if country != "" else ch.get("name", ""), topic["name"].to_lower()], 2)
	if country != "":
		GS.countries[country]["cd"][topic["id"]] = GS.day + 150
	else:
		GS.cooldowns["nego_%s_%s" % [who, topic["id"]]] = GS.day + 150
	var out := GS.apply_fx(fx, topic["name"])
	GS.log_history(topic["name"], ("Acuerdo: " + _term_text(v)) if deal else "Sin acuerdo")
	# resultado
	for c in counter_box.get_children():
		c.queue_free()
	var res := UI.vbox(10)
	var st := UI.lbl("ACUERDO ALCANZADO" if deal else "SIN ACUERDO", UI.f_cond_b, 54, UI.GREEN if deal else UI.RED)
	st.rotation = deg_to_rad(-2.5)
	res.add_child(st)
	if deal:
		res.add_child(UI.lbl(String(topic["term"][0]) + ": " + _term_text(v), UI.f_sans_b, 22, UI.TEXT))
	var chips := Widgets.effect_chips(out, 16, 9)
	chips.custom_minimum_size = Vector2(880, 0)
	res.add_child(chips)
	var b := UI.btn("Colgar", "gold", 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.pressed.connect(func():
		Sfx.play("close", -4.0)
		close())
	res.add_child(b)
	tactics_box.queue_free()
	right.add_child(res)
	UI.pop_in(res)


func on_escape() -> void:
	if nego and ended:
		close()
