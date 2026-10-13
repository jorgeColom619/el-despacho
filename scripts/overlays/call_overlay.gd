extends "res://scripts/ui/overlay.gd"
## Videollamada: conversación con un líder o personaje. Si se acepta negociar, abre nego_overlay.

const Widgets := preload("res://scripts/ui/widgets.gd")
const Typewriter := preload("res://scripts/ui/typewriter.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const Flags := preload("res://scripts/ui/flags.gd")
const W := preload("res://scripts/data/world_data.gd")
const Memoria := preload("res://scripts/systems/memoria.gd")
const Interprete := preload("res://scripts/systems/interprete.gd")

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
var busy := false
var custom_card: Control
var custom_edit: LineEdit


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.9)
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



# ------------------------------------------------------------------ diálogo

func _build_dialog() -> void:
	right.add_child(UI.lbl("LLAMADA ENTRANTE", UI.f_sans_b, 15, UI.GOLD))
	var t := UI.lbl(GS.fmt(ev.get("title", "")), UI.f_serif_b, 40, UI.CREAM)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(900, 0)
	right.add_child(t)
	right.add_child(Widgets.section("Conversación"))
	# si el líder recuerda algo (una llamada perdida, un acuerdo, una cumbre plantada...), empieza por ahí
	var pre := Memoria.call_preface(who)
	var body := GS.fmt(ev.get("text", ""))
	if pre != "":
		body = "[i]«%s»[/i]\n\n%s" % [pre, body]
	var txt := UI.rich(body, 22, UI.TEXT, UI.f_serif)
	txt.custom_minimum_size = Vector2(900, 0)
	right.add_child(txt)
	var spoken := pre if pre != "" else GS.fmt(ev.get("text", ""))
	say(spoken.left(140) + ("…" if spoken.length() > 140 else ""))
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
		var advised := GS.difficulty == 0 and i == GS.recommend(choices)
		if advised:
			cv.add_child(Widgets.advice_tag())
		var idx := i
		var card := Widgets.click_card(cv, func(): _dialog_choice(idx), 16, Color(0.07, 0.15, 0.12, 0.95) if advised else Color(0.08, 0.12, 0.19, 0.95), Color(UI.GREEN, 0.8) if advised else Color(1, 1, 1, 0.1))
		right.add_child(card)
	# o contestar con sus propias palabras
	var ch2 := UI.hbox(10)
	ch2.add_child(UI.lbl("✎", UI.f_sans_b, 22, UI.GOLD))
	ch2.add_child(UI.lbl("Contestar con sus propias palabras", UI.f_sans_m, 20, UI.GOLD_L))
	custom_card = Widgets.click_card(ch2, _open_custom, 14, Color(0.06, 0.09, 0.15, 0.95), Color(UI.GOLD, 0.35))
	right.add_child(custom_card)


func _dialog_choice(i: int, said: String = "", extra: Dictionary = {}, typed: String = "") -> void:
	if busy:
		return
	busy = true
	for c in right.get_children():
		if c is PanelContainer:
			c.set_meta("enabled", false)
			c.modulate.a = 0.4
	if custom_edit != null:
		custom_edit.editable = false
	var out := GS.resolve_choice(item, i)
	if typed != "":
		GS.log_history(GS.fmt(ev.get("title", "")), "Con sus palabras: «%s»" % typed)
	if not extra.is_empty():
		out.append_array(GS.apply_fx(extra, GS.fmt(ev.get("title", ""))))
	var s := 0.0
	for o in out:
		s += float(o["v"]) if not (o["k"] in ["money", "monthly"]) else 0.0
	portrait.mood = clampf(s / 8.0, -0.8, 0.8)
	var fx: Dictionary = ev["choices"][i].get("fx", {})
	if fx.has("nego"):
		say("Muy bien. Hablemos entonces.")
	elif said != "":
		say(said)
	else:
		say(["Entendido, presidente. Hasta pronto.", "Tomo nota. Buenas tardes.", "Muy bien. Seguiremos en contacto.", "Se lo agradezco. Saludos a su Gobierno.",
			"Así lo transmitiré. Que tenga un buen día.", "Bien. Hablaremos pronto, presidente.", "Tomo nota de su respuesta. Adiós.", "De acuerdo. Mis ministros le llamarán.",
			"Gracias por atenderme. No es habitual.", "Muy bien. Ya veremos cómo acaba esto."].pick_random())
	await get_tree().create_timer(2.2).timeout
	Sfx.play("close", -4.0)
	close()


func _open_custom() -> void:
	if busy or custom_edit != null:
		return
	var h := UI.hbox(10)
	custom_edit = LineEdit.new()
	custom_edit.placeholder_text = "¿Qué le contesta? Escríbalo como lo diría de verdad."
	custom_edit.custom_minimum_size = Vector2(740, 50)
	custom_edit.max_length = 200
	custom_edit.add_theme_font_override("font", UI.f_sans_m)
	custom_edit.add_theme_font_size_override("font_size", 19)
	custom_edit.text_submitted.connect(_submit_custom)
	h.add_child(custom_edit)
	var b := UI.btn("Decir", "gold", 18)
	b.pressed.connect(func(): _submit_custom(custom_edit.text))
	h.add_child(b)
	var box := UI.panel(Color(0.06, 0.09, 0.15, 0.97), 10, Color(UI.GOLD, 0.6), 14)
	box.add_child(h)
	var at := custom_card.get_index()
	custom_card.queue_free()
	right.add_child(box)
	right.move_child(box, at)
	custom_card = box
	custom_edit.grab_focus()


func _submit_custom(text: String) -> void:
	if busy:
		return
	var r := Interprete.interpret(text, ev)
	var choices: Array = ev.get("choices", [])
	var typed := text.strip_edges()
	var extra := {}
	if r["tone"] == "brusco" and country != "":
		extra = {"rel": {country: -3}}
	match r["kind"]:
		"vacio":
			return
		"elige":
			_dialog_choice(int(r["idx"]), ["Entendido, presidente.", "Bien. Tomo nota.", "Así se lo transmitiré a mi Gobierno.", "De acuerdo. Hablaremos pronto."].pick_random(), extra, typed)
		"delegar":
			_dialog_choice(GS.recommend(choices), "¿Que decidan sus ministros? Muy bien, hablaré con ellos.", {"prestigio": -1}, typed)
		"insulto":
			GS.remember("insulto", {"name": str(ch.get("name", "")), "who": who})
			portrait.anger = 1.0
			var fx := {"estabilidad": -1}
			if country != "":
				fx = {"rel": {country: -10}, "prestigio": -2}
			_dialog_choice(int(ev.get("default", choices.size() - 1)), "¿Cómo se atreve? Esta conversación ha terminado.", fx, typed)
		"corrupcion":
			GS.remember("orden_turbia", {"name": str(ch.get("name", "")), "t": typed})
			_dialog_choice(int(ev.get("default", choices.size() - 1)), "...No he oído nada de eso, presidente. Por esta línea, nunca.", {"corr": 2}, typed)
		"aplazar", "investigar":
			if ev.get("gen", false) or ev.get("urgent", false):
				_say_only("No puedo esperar, presidente. Necesito una respuesta ahora.")
				return
			busy = true
			GS.schedule(str(ev.get("id", "")), 4)
			GS.log_history(GS.fmt(ev.get("title", "")), "Con sus palabras: «%s» (aplazado)" % typed)
			say("De acuerdo. Le vuelvo a llamar dentro de unos días.")
			await get_tree().create_timer(2.2).timeout
			Sfx.play("close", -4.0)
			close()
		"humor":
			_say_only(["Ja, ja. Muy gracioso. ¿Y bien?", "Me gusta su sentido del humor, presidente. Pero necesito una respuesta."].pick_random())
		_:
			_say_only(["¿Perdón? La línea va mal... ¿Qué decide?", "No le he entendido bien, presidente. ¿Puede repetirlo?"].pick_random())


func _say_only(line: String) -> void:
	say(line)
	if custom_edit != null:
		custom_edit.text = ""
		custom_edit.grab_focus()


func on_escape() -> void:
	pass
