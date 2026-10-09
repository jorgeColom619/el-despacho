extends "res://scripts/ui/overlay.gd"
## Negociación simple y clara: arrastra tu oferta, mira la franja donde está su límite,
## tienes 3 intentos y 3 comodines. En las cumbres, la oferta debe convencer a todos los líderes.
## Con el despacho 3D se juega sentado a la mesa y sin ventanas: la oferta se fija con la pluma sobre la regla del
## tratado (un papel en la mesa) mientras el otro líder reacciona en directo; se propone con el sello, se firma su
## propuesta con un clic en su cartel y los comodines son objetos de la mesa (la condecoración, el dosier y el regalo).

const Widgets := preload("res://scripts/ui/widgets.gd")
const Typewriter := preload("res://scripts/ui/typewriter.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const Flags := preload("res://scripts/ui/flags.gd")
const W := preload("res://scripts/data/world_data.gd")
const NegoRoom := preload("res://scripts/stages3d/nego_room_3d.gd")

const MAX_ATTEMPTS := 3
## Tinta del papel del tratado
const INK := Color("2b2319")
const INK_DIM := Color("6b5a44")
const INK_GOLD := Color("8a6d33")

const OPENERS := {
	"orgulloso": "Presidente, espero que sepa valorar el honor de sentarse a negociar conmigo.",
	"agresivo": "Seré breve, presidente. Sé lo que quiero y sé cómo conseguirlo.",
	"pragmatico": "Buenos días, presidente. Vayamos a los números.",
	"paciente": "Tengo todo el tiempo del mundo, presidente. ¿Y usted?",
	"volatil": "¡Presidente! Hoy estoy de buen humor... de momento.",
}
const LINES := {
	"close": ["Se acerca... pero todavía no.", "Casi, presidente. Un poco más de generosidad.", "Estamos cerca. Pero no tanto."],
	"far": ["Ni hablar.", "Eso es una provocación.", "¿Me está tomando el pelo, presidente?"],
	"accept": ["Trato hecho.", "Tenemos un acuerdo.", "De acuerdo. Firmemos."],
	"flat_good": ["¡Por fin alguien que me entiende!", "Es usted muy amable, presidente."],
	"flat_meh": ["Gracias... pero vayamos al grano.", "Los halagos no pagan facturas."],
	"press_ok": ["Está bien, está bien. Lo pensaré mejor.", "Veo que va en serio."],
	"press_bad": ["¿Me amenaza? Esto no lo olvidaré.", "Grave error, presidente."],
	"gift": ["Eso ya es otra cosa.", "Un gesto que valoro."],
	"walk": ["Se acabó. No hay acuerdo.", "Me levanto de la mesa, presidente."],
}

var summit := ""
var topic: Dictionary
var parties := []
var sel := 0
var offer := 50.0
var attempts := MAX_ATTEMPTS
var used := {}
var ended := false
var my_power := 50.0
var meter: Control
var offer_lbl: Label
var status_lbl: Label
var fx_box: HFlowContainer
var lines_lbl: RichTextLabel
var wild_box: HBoxContainer
var attempts_lbl: Label
var safe_btn: Button
var propose_btn: Button
var panel_v: VBoxContainer
var _drag := false
var bar_w := 860.0
var _t := 0.0
## Salón de negociaciones 3D (con el despacho 3D): primera persona en la mesa, el tratado en papel y los objetos de la
## mesa. Si no, la bandera y los retratos 2D de siempre
var stage
## Columna del tema y los líderes (en 2D es el mismo panel_v)
var info_v: VBoxContainer
var leave_btn: Button
var _col_w := 900.0
var _wild_w := 280.0
## En 3D: la cifra del cartel de su propuesta, las marcas del sello en el tratado y si hay una propuesta en el aire
var _prop_lbl: Label
var _stamps: Control
var _busy := false


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.92)
	summit = data.get("summit", "")
	if summit != "":
		topic = DB.SUMMITS.get(summit, {})
		for w in topic.get("leaders", []):
			parties.append(_make_party(w))
	else:
		topic = DB.topic(data.get("who", ""), data.get("topic", ""))
		if not topic.is_empty():
			parties.append(_make_party(data.get("who", "")))
	if topic.is_empty() or parties.is_empty():
		close()
		return
	my_power = GS.meters["economia"] * 0.35 + GS.meters["prestigio"] * 0.35 + GS.budget["defensa"] * 20.0 + GS.treaty_count() * 3.0
	offer = clampf(round(_min_of("lo") - 2.0), 0.0, 95.0)
	Sfx.play("notify", -6.0, 0.8)
	if NegoRoom.enabled():
		stage = NegoRoom.new()
		stage.summit = summit != ""
		for p in parties:
			stage.parties.append({"look": p["ch"].get("look", {}), "country": p["country"], "name": p["ch"].get("name", ""), "role": p["ch"].get("role", "")})
		root.add_child(stage)
		_build_3d()
	else:
		if summit == "":
			_build_feed(parties[0])
			panel_v = UI.vbox(14)
			panel_v.position = Vector2(930, 124)
			panel_v.size = Vector2(920, 900)
			root.add_child(panel_v)
		else:
			bar_w = 1480.0
			_build_summit_row()
			panel_v = UI.vbox(12)
			panel_v.position = Vector2(70, 420)
			panel_v.size = Vector2(1780, 580)
			root.add_child(panel_v)
		info_v = panel_v
		_build_panel()
	if summit == "":
		var opener: String = OPENERS.get(parties[0]["pers_id"], "Hablemos, presidente.")
		# en la mesa, el saludo llega cuando se va el rótulo de arriba (los subtítulos salen en el mismo sitio)
		if stage != null:
			_after(3.8, func(): _say(parties[0], opener))
		else:
			_say(parties[0], opener)
	else:
		_line("Los tres líderes toman asiento. El acuerdo solo se firmará si convence a todos.")
	_refresh()


func _make_party(who: String) -> Dictionary:
	var ch := DB.character(who)
	var cp := DB.counterpart(who)
	var pid: String = cp["pers"]
	var pers: Dictionary = W.PERSONALITIES.get(pid, W.PERSONALITIES["pragmatico"])
	var pthr := {"orgulloso": -3.0, "agresivo": -8.0, "pragmatico": 5.0, "paciente": 2.0, "volatil": 0.0}
	var rel: float = cp["rel"]
	var lim: float = 45.0 + rel * 0.25 + float(pthr.get(pid, 0.0)) + (GS.meters["prestigio"] - 50.0) * 0.25 - (GS.difficulty - 1) * 6.0 + randf_range(-8.0, 8.0)
	var negociador := GS.has_trait("negociador")
	if negociador:
		lim += 6.0
	if summit != "":
		lim += 6.0
	lim = clampf(lim, 12.0, 88.0)
	var width := 22.0 if negociador else 32.0
	var lo := clampf(lim - randf_range(4.0, width - 4.0), 0.0, 100.0)
	var hi := clampf(lo + width, 0.0, 100.0)
	return {"who": who, "ch": ch, "country": ch.get("country", ""), "pers_id": pid, "pers": pers, "power": float(cp["power"]), "rel": rel,
		"L": lim, "lo": lo, "hi": maxf(hi, lim + 1.0), "status": "", "portrait": null, "say": null}


func _min_of(key: String) -> float:
	var m := 100.0
	for p in parties:
		m = minf(m, float(p[key]))
	return m


## f dentro de sec segundos, si la negociación sigue abierta
func _after(sec: float, f: Callable) -> void:
	get_tree().create_timer(sec).timeout.connect(func():
		if not closing:
			f.call())


func _who_text(p: Dictionary) -> String:
	return W.COUNTRIES[p["country"]]["full"] if p["country"] != "" else String(p["ch"].get("role", ""))


# ------------------------------------------------------------------ mesa 3D

## El tratado (en el papel de la mesa), el cartel con su propuesta, los objetos de la mesa y el botón de levantarse
func _build_3d() -> void:
	var pp: Control = stage.paper
	var w := pp.size.x
	bar_w = 880.0 if summit == "" else 780.0
	_col_w = w - 80.0
	# membrete
	var head := UI.vbox(0)
	head.position = Vector2(40, 12)
	head.size = Vector2(w - 80, 0)
	pp.add_child(head)
	var kicker := "Cumbre internacional · Tratado multilateral" if summit != "" else "Tratado · Negociación con " + _who_text(parties[0])
	head.add_child(UI.lbl(kicker.to_upper(), UI.f_sans_b, 24, INK_GOLD))
	var tn := UI.lbl(topic["name"], UI.f_serif_b, 48, INK)
	head.add_child(tn)
	var line := ColorRect.new()
	line.color = Color(INK_GOLD, 0.6)
	line.position = Vector2(40, 104)
	line.size = Vector2(w - 80, 2)
	pp.add_child(line)
	# la oferta: cifra grande y cómo la recibirían
	var oh := UI.hbox(26)
	oh.position = Vector2(40, 108)
	pp.add_child(oh)
	offer_lbl = UI.lbl("", UI.f_cond_b, 58, INK)
	oh.add_child(offer_lbl)
	status_lbl = UI.lbl("", UI.f_sans_b, 34, UI.GREEN)
	status_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	oh.add_child(status_lbl)
	# la regla de colores
	meter = Control.new()
	meter.position = Vector2(30, 180)
	meter.size = Vector2(w - 60, 185 if parties.size() == 1 else 215)
	meter.mouse_filter = Control.MOUSE_FILTER_STOP
	meter.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	meter.draw.connect(_draw_meter)
	meter.gui_input.connect(_meter_input)
	pp.add_child(meter)
	# lo que pasaría si se firma (en un recuadro oscuro, para que se lean los efectos)
	var fp := PanelContainer.new()
	fp.add_theme_stylebox_override("panel", UI.sb(Color(0.08, 0.07, 0.06, 0.88), 10, Color(INK_GOLD, 0.7), 2, 0, 12))
	fp.position = Vector2(40, meter.position.y + meter.size.y + 4)
	fp.custom_minimum_size = Vector2(w - 80, 0)
	pp.add_child(fp)
	var fh := UI.hbox(12)
	fp.add_child(fh)
	fh.add_child(UI.lbl("Si se firma:", UI.f_sans_m, 24, UI.DIM))
	fx_box = HFlowContainer.new()
	fx_box.custom_minimum_size = Vector2(w - 280, 0)
	fx_box.add_theme_constant_override("h_separation", 8)
	fx_box.add_theme_constant_override("v_separation", 6)
	fh.add_child(fx_box)
	# pie: intentos e instrucciones (la esquina de abajo a la derecha queda para las marcas del sello)
	attempts_lbl = UI.lbl("", UI.f_sans_b, 32, INK)
	attempts_lbl.position = Vector2(40, pp.size.y - 56)
	pp.add_child(attempts_lbl)
	var hint := UI.lbl("Arrastre por la regla · rueda del ratón o ← →", UI.f_sans_m, 22, INK_DIM)
	hint.position = Vector2(330, pp.size.y - 48)
	pp.add_child(hint)
	# marcas del sello (cada propuesta rechazada deja una)
	_stamps = Control.new()
	_stamps.size = pp.size
	_stamps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pp.add_child(_stamps)
	# el cartel de su propuesta, de su lado de la mesa
	var cp: Control = stage.proposal
	var cv := UI.vbox(2)
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.position = Vector2(14, 10)
	cv.size = cp.size - Vector2(28, 20)
	cp.add_child(cv)
	var who_c: String = ("PROPUESTA DE " + (String(W.COUNTRIES[parties[0]["country"]]["name"]).to_upper() if parties[0]["country"] != "" else String(parties[0]["ch"].get("name", "")).to_upper())) if summit == "" else "PROPUESTA DE LA CUMBRE"
	cv.add_child(UI.lbl(who_c, UI.f_sans_b, 30, INK_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_prop_lbl = UI.lbl("", UI.f_cond_b, 64, INK, HORIZONTAL_ALIGNMENT_CENTER)
	cv.add_child(_prop_lbl)
	cv.add_child(UI.lbl("Firma segura · clic para aceptarla", UI.f_sans_m, 24, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	# levantarse de la mesa (abajo a la izquierda, discreto)
	leave_btn = UI.btn("Levantarse de la mesa", "ghost", 18)
	leave_btn.pressed.connect(func(): _end(false, LINES["walk"].pick_random()))
	stage.hud.add_child(leave_btn)
	leave_btn.position = Vector2(26, 1080 - 70)
	if summit != "":
		stage.leader_clicked.connect(_select)
		for i in parties.size():
			parties[i]["portrait"] = stage.leaders[i]
	else:
		parties[0]["portrait"] = stage.leaders[0]
	stage.title_card(_who_text(parties[0]) if summit == "" else "Cumbre internacional", topic["name"],
		"Arrastre la pluma por la regla del tratado y proponga con el sello. Verde: la aceptarán; ámbar: su límite está en esa franja; rojo: la rechazarán.", 2.8)


## Teclas: flechas para la oferta e Intro para proponer
func _propose_input() -> void:
	if not _busy:
		_propose()


func _select(i: int) -> void:
	if ended or i == sel:
		return
	sel = i
	Sfx.play("click", -8.0)
	_refresh()


## Pistas y acciones de los objetos de la mesa (cambian con el líder elegido y los comodines usados)
func _props_3d() -> void:
	var target: Dictionary = parties[sel]
	var tn: String = (" → " + String(target["ch"].get("name", ""))) if summit != "" else ""
	var chance := clampf(0.45 + (my_power - float(target["power"])) / 90.0, 0.2, 0.9)
	var gift := "−6 CP" if target["country"] == "" else "−400 M€"
	var specs := {
		"halagar": "Halagar%s: concederle la Gran Cruz de Valdoria\nSube su límite. Muy eficaz con los orgullosos." % tn,
		"presionar": "Presionar%s con un dosier confidencial\n%d%% de éxito: +12 a su límite. Si falla, −8 y se enfada." % [tn, int(chance * 100)],
		"regalo": "Ofrecer algo a cambio%s (%s)\n+10 a su límite (más con los pragmáticos)." % [tn, gift],
	}
	for id in specs:
		var on: bool = not used.has(id) and not ended
		stage.set_prop(id, specs[id] if on else "", _wildcard.bind(id), on)
	stage.set_prop("stamp", "Proponer esta oferta (Intro)\nLe quedan %d intentos. Si la rechazan, ya sabrá que su límite está por debajo." % attempts, _propose_input, not ended)
	stage.set_prop("proposal", "Aceptar su propuesta: %s\nFirma segura, aunque saca menos para Valdoria." % _term_text(_safe()), _accept_safe, not ended)


func _safe() -> float:
	return maxf(0.0, _min_of("lo") - 4.0)


## Marca roja del sello en la esquina del tratado
func _stamp_mark(text: String) -> void:
	var pp: Control = stage.paper
	var m := Panel.new()
	m.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0), 12, Color(0.66, 0.12, 0.1, 0.85), 5))
	m.size = Vector2(250, 92)
	m.position = Vector2(pp.size.x * 0.83 - 125 - _stamps.get_child_count() * 18, pp.size.y * 0.86 - 46 - _stamps.get_child_count() * 8)
	m.pivot_offset = m.size * 0.5
	m.rotation = deg_to_rad(randf_range(-14.0, -6.0))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.lbl(text, UI.f_cond_b, 40, Color(0.66, 0.12, 0.1, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	l.size = m.size
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	m.add_child(l)
	_stamps.add_child(m)


# ------------------------------------------------------------------ interfaz 2D (sin el despacho 3D)

func _build_feed(p: Dictionary) -> void:
	var feed := Control.new()
	feed.position = Vector2(70, 124)
	feed.size = Vector2(820, 880)
	feed.clip_contents = true
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(feed)
	var country: String = p["country"]
	var bg := Control.new()
	bg.size = feed.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(func():
		if country != "":
			Flags.draw_flag(bg, country, Rect2(-60, 0, 940, 620))
		else:
			bg.draw_rect(Rect2(0, 0, 820, 880), Color("24324a"))
		bg.draw_rect(Rect2(0, 0, 820, 880), Color(0.02, 0.03, 0.06, 0.5)))
	feed.add_child(bg)
	var por := Portrait.new()
	por.position = Vector2(80, 110)
	por.size = Vector2(660, 792)
	feed.add_child(por)
	por.setup(p["ch"].get("look", {}), true)
	p["portrait"] = por
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
	feed.add_child(grad)
	var lower := UI.vbox(0)
	lower.position = Vector2(32, 680)
	feed.add_child(lower)
	lower.add_child(UI.lbl(p["ch"].get("role", "").to_upper(), UI.f_sans_b, 15, UI.GOLD))
	lower.add_child(UI.lbl(p["ch"].get("name", ""), UI.f_serif_b, 44, UI.CREAM))
	lower.add_child(UI.lbl("Carácter: %s · %s" % [p["pers"]["name"], p["pers"]["desc"]], UI.f_sans, 16, UI.DIM))
	var say := Typewriter.new()
	say.position = Vector2(32, 800)
	say.custom_minimum_size = Vector2(756, 0)
	say.size = Vector2(756, 60)
	say.add_theme_font_override("normal_font", UI.f_serif)
	say.add_theme_font_size_override("normal_font_size", 24)
	feed.add_child(say)
	p["say"] = say
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0), 4, Color(UI.GOLD, 0.6), 2))
	frame.size = feed.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed.add_child(frame)


func _build_summit_row() -> void:
	var head := UI.vbox(0)
	head.position = Vector2(70, 112)
	root.add_child(head)
	head.add_child(UI.lbl("CUMBRE INTERNACIONAL", UI.f_sans_b, 15, UI.GOLD))
	head.add_child(UI.lbl(topic["name"], UI.f_serif_b, 40, UI.CREAM))
	var row := UI.hbox(18)
	row.position = Vector2(70, 196)
	root.add_child(row)
	for i in parties.size():
		var p: Dictionary = parties[i]
		var v := UI.vbox(4)
		v.custom_minimum_size = Vector2(560, 170)
		var h := UI.hbox(12)
		var pf := Control.new()
		pf.custom_minimum_size = Vector2(150, 160)
		pf.clip_contents = true
		pf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var country: String = p["country"]
		pf.draw.connect(func():
			Flags.draw_flag(pf, country, Rect2(0, 0, 150, 170))
			pf.draw_rect(Rect2(0, 0, 150, 170), Color(0, 0, 0, 0.45)))
		var por := Portrait.new()
		por.position = Vector2(-10, 4)
		por.size = Vector2(170, 204)
		por.track_mouse = false
		pf.add_child(por)
		por.setup(p["ch"].get("look", {}), false)
		p["portrait"] = por
		h.add_child(pf)
		var nv := UI.vbox(2)
		nv.add_child(UI.lbl(p["ch"].get("name", ""), UI.f_serif_b, 24, UI.CREAM))
		nv.add_child(UI.lbl(W.COUNTRIES[country]["name"] if country != "" else "", UI.f_sans_b, 14, UI.GOLD))
		nv.add_child(UI.lbl("Carácter: " + p["pers"]["name"], UI.f_sans, 15, UI.DIM))
		var say := UI.lbl("", UI.f_serif, 19, UI.TEXT)
		say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		say.custom_minimum_size = Vector2(360, 0)
		nv.add_child(say)
		p["say"] = say
		h.add_child(nv)
		v.add_child(h)
		var idx := i
		var card := Widgets.click_card(v, func():
			sel = idx
			_refresh(), 12)
		card.set_meta("party", i)
		p["card"] = card
		row.add_child(card)


func _build_panel() -> void:
	if summit == "":
		panel_v.add_child(UI.lbl("NEGOCIACIÓN · " + (W.COUNTRIES[parties[0]["country"]]["full"].to_upper() if parties[0]["country"] != "" else parties[0]["ch"].get("role", "").to_upper()), UI.f_sans_b, 15, UI.GOLD))
		panel_v.add_child(UI.lbl(topic["name"], UI.f_serif_b, 40, UI.CREAM))
	var d := UI.lbl(GS.fmt(topic.get("desc", "")), UI.f_sans, 18, UI.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(900, 0)
	panel_v.add_child(d)
	var how := UI.lbl("Arrastra el marcador para elegir tu oferta. Verde: la aceptarán. Ámbar: su límite está en esa franja. Rojo: la rechazarán.", UI.f_sans_m, 16, Color(UI.GOLD_L, 0.9))
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(_col_w, 0)
	panel_v.add_child(how)
	meter = Control.new()
	meter.custom_minimum_size = Vector2(bar_w + (140.0 if parties.size() > 1 else 40.0), 120 + (parties.size() - 1) * 26)
	meter.mouse_filter = Control.MOUSE_FILTER_STOP
	meter.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	meter.draw.connect(_draw_meter)
	meter.gui_input.connect(_meter_input)
	panel_v.add_child(meter)
	var oh := UI.hbox(20)
	offer_lbl = UI.lbl("", UI.f_cond_b, 34, UI.TEXT)
	oh.add_child(offer_lbl)
	status_lbl = UI.lbl("", UI.f_sans_b, 20, UI.GREEN)
	status_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	oh.add_child(status_lbl)
	panel_v.add_child(oh)
	var fh := UI.hbox(10)
	fh.add_child(UI.lbl("Si firmas esto:", UI.f_sans_m, 15, UI.DIM))
	fx_box = HFlowContainer.new()
	fx_box.custom_minimum_size = Vector2(_col_w - 140.0, 0)
	fh.add_child(fx_box)
	panel_v.add_child(fh)
	var ah := UI.hbox(16)
	propose_btn = UI.btn("PROPONER ESTA OFERTA", "gold", 22)
	propose_btn.pressed.connect(_propose)
	ah.add_child(propose_btn)
	safe_btn = UI.btn("", "normal", 17)
	safe_btn.pressed.connect(_accept_safe)
	ah.add_child(safe_btn)
	attempts_lbl = UI.lbl("", UI.f_sans_b, 18, UI.TEXT)
	attempts_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ah.add_child(attempts_lbl)
	panel_v.add_child(ah)
	panel_v.add_child(Widgets.section("Comodines · un solo uso cada uno" + (" · se aplican al líder seleccionado" if summit != "" else "")))
	wild_box = UI.hbox(12)
	panel_v.add_child(wild_box)
	if summit != "":
		lines_lbl = UI.rich("", 18, UI.TEXT, UI.f_serif)
		lines_lbl.custom_minimum_size = Vector2(_col_w, 0)
		info_v.add_child(lines_lbl)
	leave_btn = UI.btn("Levantarse de la mesa", "ghost", 16)
	leave_btn.pressed.connect(func(): _end(false, LINES["walk"].pick_random()))
	leave_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel_v.add_child(leave_btn)


func _wild_cards() -> void:
	for c in wild_box.get_children():
		c.queue_free()
	var target: Dictionary = parties[sel]
	var tn: String = String(target["ch"].get("name", "")).split(" ")[0] if summit != "" else ""
	var chance := clampf(0.45 + (my_power - float(target["power"])) / 90.0, 0.2, 0.9)
	var gift_cost := "−6 CP" if target["country"] == "" else "−400 M€"
	var specs := [
		["halagar", "Halagar", "sonrisa", "Sube su límite. Muy eficaz con los orgullosos."],
		["presionar", "Presionar", "presion", "%d%% de éxito: +12 a su límite. Si falla, −8 y se enfada." % int(chance * 100)],
		["regalo", "Ofrecer algo a cambio", "dinero", "%s · +10 a su límite (más con los pragmáticos)." % gift_cost],
	]
	for s in specs:
		var v := UI.vbox(4)
		v.custom_minimum_size = Vector2(_wild_w, 86)
		var h := UI.hbox(8)
		h.add_child(UI.icon_rect(s[2], 24, UI.GOLD_L))
		h.add_child(UI.lbl(s[1] + ((" → " + tn) if tn != "" else ""), UI.f_sans_b, 17, UI.TEXT))
		v.add_child(h)
		var dl := UI.lbl(s[3], UI.f_sans, 14, UI.DIM)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(_wild_w - 10.0, 0)
		v.add_child(dl)
		var wid: String = s[0]
		var card := Widgets.click_card(v, func(): _wildcard(wid), 12)
		if used.has(wid) or ended:
			card.set_meta("enabled", false)
			card.modulate.a = 0.4
		wild_box.add_child(card)


# ------------------------------------------------------------------ estado

func _refresh() -> void:
	if ended:
		return
	offer_lbl.text = ("Su oferta: " if stage != null else "Tu oferta: ") + _term_text(offer)
	var any_red := false
	var any_amber := false
	var zones := []
	for p in parties:
		var st := "seguro"
		if offer > float(p["hi"]):
			st = "rechazo"
			any_red = true
		elif offer > float(p["lo"]):
			st = "riesgo"
			any_amber = true
		p["preview"] = st
		zones.append({"seguro": "green", "riesgo": "amber", "rechazo": "red"}[st])
	var paper := stage != null
	if any_red:
		status_lbl.text = "Lo rechazarán" if summit == "" else "Alguien lo rechazará"
		status_lbl.add_theme_color_override("font_color", UI.RED.darkened(0.25) if paper else UI.RED)
	elif any_amber:
		status_lbl.text = "Arriesgado: puede que lo rechacen"
		status_lbl.add_theme_color_override("font_color", UI.AMBER.darkened(0.35) if paper else UI.AMBER)
	else:
		status_lbl.text = "Lo aceptarán"
		status_lbl.add_theme_color_override("font_color", UI.GREEN.darkened(0.3) if paper else UI.GREEN)
	for c in fx_box.get_children():
		c.queue_free()
	var chips := Widgets.effect_chips(GS.preview(_deal_fx(offer)), 20 if paper else 14, 8)
	for c in chips.get_children():
		chips.remove_child(c)
		fx_box.add_child(c)
	chips.queue_free()
	var safe := _safe()
	attempts_lbl.text = "Intentos: " + "●".repeat(attempts) + "○".repeat(MAX_ATTEMPTS - attempts)
	if paper:
		_prop_lbl.text = _term_text(safe)
		stage.moods(zones)
		if summit != "":
			stage.select(sel)
		_props_3d()
		# la pluma, sobre la marca de la oferta en la regla
		var r := _bar_rect()
		var rows := parties.size()
		var cy := r.position.y + (r.size.y if rows == 1 else rows * 34.0) * 0.5
		var px := meter.position + Vector2(r.position.x + r.size.x * offer / 100.0, cy)
		stage.set_pen(px / Vector2(stage.paper.size))
	else:
		safe_btn.text = "Aceptar su propuesta: " + _term_text(safe)
		if summit != "":
			for i in parties.size():
				var card: PanelContainer = parties[i]["card"]
				card.add_theme_stylebox_override("panel", UI.sb(Color(0.08, 0.12, 0.19, 0.95), 8, UI.GOLD if i == sel else Color(1, 1, 1, 0.1), 2 if i == sel else 1, 0, 12))
		_wild_cards()
	meter.queue_redraw()


func _bar_rect() -> Rect2:
	if stage != null:
		return Rect2(40, 54, bar_w, 40)
	return Rect2(20, 40, bar_w, 30)


func _draw_meter() -> void:
	var paper := stage != null
	var ink := INK if paper else UI.TEXT
	var dimc := INK_DIM if paper else UI.DIM
	var row_h := 34.0 if paper else 26.0
	var fs := 26 if paper else 13
	var r := _bar_rect()
	var term: Array = topic["term"]
	meter.draw_string(UI.f_sans_b, Vector2(r.position.x, r.position.y - 22), String(term[0]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dimc)
	meter.draw_rect(r, Color(0, 0, 0, 0.06) if paper else Color(1, 1, 1, 0.06))
	var rows := parties.size()
	for i in rows:
		var p: Dictionary = parties[i]
		var y := r.position.y + (0.0 if rows == 1 else i * row_h)
		var hgt := r.size.y if rows == 1 else row_h - 6.0
		var x_lo := r.position.x + r.size.x * float(p["lo"]) / 100.0
		var x_hi := r.position.x + r.size.x * float(p["hi"]) / 100.0
		meter.draw_rect(Rect2(r.position.x, y, x_lo - r.position.x, hgt), Color(0.24, 0.6, 0.36, 0.9) if paper else Color(0.28, 0.7, 0.42, 0.85))
		meter.draw_rect(Rect2(x_lo, y, x_hi - x_lo, hgt), Color(0.88, 0.62, 0.16, 0.9) if paper else Color(0.9, 0.66, 0.2, 0.85))
		meter.draw_rect(Rect2(x_hi, y, r.end.x - x_hi, hgt), Color(0.74, 0.22, 0.17, 0.9) if paper else Color(0.8, 0.25, 0.2, 0.85))
		for k in 6:
			var sx := x_lo + (x_hi - x_lo) * k / 5.0
			meter.draw_line(Vector2(sx, y), Vector2(sx, y + hgt), Color(1, 1, 1, 0.18), 1.0)
		if rows > 1:
			var nm: String = String(p["ch"].get("name", "")).split(" ")[-1]
			meter.draw_string(UI.f_sans_b, Vector2(r.end.x + 12, y + hgt * 0.5 + fs * 0.38), nm + (" ✓" if p["status"] == "si" else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, (INK_GOLD if paper else UI.GOLD_L) if i == sel else ink)
		else:
			meter.draw_string(UI.f_sans_m, Vector2((x_lo + x_hi) / 2.0 - 120, y + hgt + fs + 4), "su límite está aquí", HORIZONTAL_ALIGNMENT_CENTER, 240, fs, Color("8a5a10") if paper else Color(1, 0.85, 0.5))
	var total_h := r.size.y if rows == 1 else rows * row_h - 6.0
	var mx := r.position.x + r.size.x * offer / 100.0
	var mark := Color(0.08, 0.06, 0.05) if paper else Color.WHITE
	meter.draw_rect(Rect2(mx - 3, r.position.y - 8, 6, total_h + 16), mark)
	meter.draw_colored_polygon(PackedVector2Array([Vector2(mx, r.position.y - 8), Vector2(mx - 10, r.position.y - 22), Vector2(mx + 10, r.position.y - 22)]), mark)
	var ly := r.position.y + total_h + (fs * 2.6 if rows == 1 else fs * 1.6) + 8
	meter.draw_string(UI.f_sans_m, Vector2(r.position.x, ly), "◀ Lo que quieren ellos: " + _term_text(0), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, dimc)
	meter.draw_string(UI.f_sans_m, Vector2(r.position.x, ly), "Lo que quiere Valdoria: " + _term_text(100) + " ▶", HORIZONTAL_ALIGNMENT_RIGHT, r.size.x, fs, INK_GOLD if paper else UI.GOLD_L)


func _meter_input(e: InputEvent) -> void:
	if ended:
		return
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_drag = e.pressed
			if e.pressed:
				_set_offer_from(e.position.x)
		elif e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			# rueda del ratón: un punto cada vez
			offer = clampf(offer + (1.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0), 0.0, 100.0)
			Sfx.play("tick", -18.0, 1.4)
			_refresh()
	elif e is InputEventMouseMotion and _drag:
		_set_offer_from(e.position.x)


func _set_offer_from(x: float) -> void:
	var r := _bar_rect()
	var v := clampf((x - r.position.x) / r.size.x * 100.0, 0.0, 100.0)
	v = round(v)
	if v != offer:
		offer = v
		if int(v) % 4 == 0:
			Sfx.play("tick", -18.0, 1.4)
		_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if ended or not (event is InputEventKey) or not event.pressed:
		return
	if event.keycode == KEY_LEFT:
		offer = maxf(0.0, offer - 1.0)
		_refresh()
	elif event.keycode == KEY_RIGHT:
		offer = minf(100.0, offer + 1.0)
		_refresh()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_propose_input()


# ------------------------------------------------------------------ lógica

func _term_value(pos: float) -> float:
	var term: Array = topic["term"]
	return lerpf(float(term[1]), float(term[2]), pos / 100.0)


func _term_text(pos: float) -> String:
	var term: Array = topic["term"]
	var val := _term_value(pos)
	var unit: String = term[3]
	if unit.begins_with(" M€"):
		return "%s%s" % [UI.money(val), unit.substr(3)]
	if unit == "%":
		return "%s%%" % UI.num(val, 0 if (absf(val) >= 10 or absf(val - round(val)) < 0.05) else 1)
	return UI.num(val, 0) + unit


func _deal_fx(pos: float) -> Dictionary:
	return _lerp_fx(topic.get("fx_min", {}), topic.get("fx_max", {}), pos / 100.0)


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


func _say(p: Dictionary, text: String) -> void:
	if stage != null:
		# en la mesa: subtítulos con su nombre, y el personaje mueve la boca mientras se lee
		var nm := String(p["ch"].get("name", ""))
		stage.say(nm + (" · " + W.COUNTRIES[p["country"]]["name"] if p["country"] != "" else ""), GS.fmt(text), UI.GOLD_L.lerp(UI.CREAM, 0.4), p["portrait"], 0.7)
		return
	var s = p["say"]
	if s == null:
		return
	if s is RichTextLabel:
		s.play("«" + GS.fmt(text) + "»", 48.0)
		if p["portrait"] != null:
			p["portrait"].talking = true
	else:
		s.text = "«" + GS.fmt(text) + "»"
		UI.pop_in(s, 0.25)


func _line(text: String) -> void:
	if stage != null:
		# en la mesa, como un subtítulo más (abajo está el tratado)
		stage.say("", text, UI.DIM, null, 0.4)
	elif lines_lbl != null:
		lines_lbl.text = text


func _shift(p: Dictionary, d: float) -> void:
	p["L"] = clampf(float(p["L"]) + d, 2.0, 98.0)
	p["lo"] = clampf(float(p["lo"]) + d, 0.0, 100.0)
	p["hi"] = clampf(float(p["hi"]) + d, 0.0, 100.0)
	if float(p["hi"]) < float(p["L"]):
		p["hi"] = float(p["L"]) + 1.0
	if float(p["lo"]) > float(p["L"]):
		p["lo"] = float(p["L"])


func _mood(p: Dictionary, m: float, anger: float) -> void:
	if p["portrait"] != null:
		p["portrait"].mood = m
		p["portrait"].anger = anger


func _wildcard(id: String) -> void:
	if used.has(id) or ended:
		return
	used[id] = true
	var p: Dictionary = parties[sel]
	var react := ""
	match id:
		"halagar":
			var g: float = {"orgulloso": 10.0, "pragmatico": 2.0, "agresivo": 3.0}.get(p["pers_id"], 5.0)
			if p["pers_id"] == "volatil":
				g = randf_range(0.0, 10.0)
			_shift(p, float(g))
			_say(p, LINES["flat_good" if float(g) >= 5.0 else "flat_meh"].pick_random())
			_mood(p, 0.5 if float(g) >= 5.0 else 0.1, 0.0)
			react = "laugh" if float(g) >= 5.0 else "yes"
			Sfx.play("click", -2.0, 1.3)
		"presionar":
			var chance := clampf(0.45 + (my_power - float(p["power"])) / 90.0, 0.2, 0.9)
			if randf() < chance:
				_shift(p, 9.0 if p["pers_id"] == "agresivo" else 12.0)
				_say(p, LINES["press_ok"].pick_random())
				_mood(p, -0.2, 0.3)
				react = "yes"
				Sfx.play("stamp", -6.0)
			else:
				_shift(p, -8.0)
				_rel(p, -5.0)
				_say(p, LINES["press_bad"].pick_random())
				_mood(p, -0.7, 0.8)
				react = "cross"
				Sfx.play("fail", -4.0)
		"regalo":
			if p["country"] == "":
				if GS.pc < 6:
					used.erase(id)
					GS.toast.emit("No tiene capital político suficiente (6 CP)", "warn", "capital")
					return
				GS.pc -= 6
			else:
				GS.apply_fx({"money": -400}, "Concesión", false)
			_shift(p, 14.0 if p["pers_id"] == "pragmatico" else 10.0)
			_say(p, LINES["gift"].pick_random())
			_mood(p, 0.4, 0.0)
			react = "yes"
			Sfx.play("coin", -4.0)
	if stage != null:
		# el objeto pasa al otro lado de la mesa y el líder reacciona
		stage.give_prop(id, sel)
		stage.react_leader(sel, react, 2.2 if react == "cross" else 1.6)
	_refresh()


func _rel(p: Dictionary, d: float) -> void:
	var c: String = p["country"]
	if c != "":
		GS.countries[c]["rel"] = clampf(GS.countries[c]["rel"] + d, -100.0, 100.0)


func _propose() -> void:
	if ended:
		return
	var rejecters := []
	for p in parties:
		if offer <= float(p["L"]):
			p["status"] = "si"
		else:
			p["status"] = "no"
			rejecters.append(p)
	if stage != null:
		# el sello cae sobre el tratado; luego leen la propuesta y contestan
		_busy = true
		var n := MAX_ATTEMPTS - attempts + 1
		stage.stamp_down(func(): _stamp_mark("PROPUESTA %d" % n), func(): pass)
		for i in parties.size():
			stage.react_leader(i, "read", 1.1)
		_after(1.4, func(): _busy = false)
	if rejecters.is_empty():
		for p in parties:
			_say(p, LINES["accept"].pick_random())
		_end(true, "")
		return
	attempts -= 1
	Sfx.play("fail", -8.0)
	for p in parties:
		if p["status"] == "si" and summit != "":
			_say(p, "Por mi parte, de acuerdo.")
			_mood(p, 0.4, 0.0)
	var names := []
	for p in rejecters:
		var gap := offer - float(p["L"])
		_say(p, LINES["close" if gap <= 6.0 else "far"].pick_random())
		_mood(p, -0.3 if gap <= 6.0 else -0.6, 0.0 if gap <= 6.0 else 0.5)
		# ahora sabes que su límite está por debajo de tu oferta; y se molestan un poco
		_shift(p, -3.0)
		p["hi"] = clampf(minf(float(p["hi"]), offer - 4.0), float(p["L"]) + 1.0, 100.0)
		names.append(String(p["ch"].get("name", "")).split(" ")[-1])
	if stage != null:
		for i in parties.size():
			var yes: bool = parties[i]["status"] == "si"
			_after(1.15, func(): stage.react_leader(i, "yes" if yes else "no", 1.6))
	if summit != "":
		_line("Rechazan la propuesta: %s. Intentos restantes: %d." % [", ".join(PackedStringArray(names)), attempts])
	if attempts <= 0:
		_end(false, LINES["walk"].pick_random())
		return
	offer = clampf(offer, 0.0, 100.0)
	_refresh()


func _accept_safe() -> void:
	if ended:
		return
	offer = _safe()
	for p in parties:
		p["status"] = "si"
		_say(p, LINES["accept"].pick_random())
	_end(true, "")


func _end(deal: bool, line: String) -> void:
	if ended:
		return
	ended = true
	if line != "":
		for p in parties:
			_say(p, line)
	var fx := {}
	var who_names := []
	for p in parties:
		who_names.append(W.COUNTRIES[p["country"]]["name"] if p["country"] != "" else p["ch"].get("name", ""))
	var label: String = ", ".join(PackedStringArray(who_names))
	if deal:
		fx = _deal_fx(offer)
		Sfx.play("success", -2.0)
		for p in parties:
			_mood(p, 0.7, 0.0)
		if stage != null:
			stage.deal()
		if summit != "":
			var rel := {}
			for p in parties:
				if p["country"] != "":
					rel[p["country"]] = float(topic.get("deal_rel", 5))
			fx["rel"] = rel
			fx["prestigio"] = float(fx.get("prestigio", 0.0)) + 3.0
		if topic.has("treaty"):
			for p in parties:
				if p["country"] != "":
					GS.add_treaty(p["country"], topic["treaty"])
		if topic.has("flag"):
			fx["flag"] = topic["flag"]
		GS.push_news("%s: acuerdo en %s (%s)" % [topic.get("name", "Acuerdo"), label, _term_text(offer)] if summit != "" else "Acuerdo con %s: %s (%s)" % [label, String(topic["name"]).to_lower(), _term_text(offer)], 3)
		if summit != "":
			Perfil.earn(Perfil.S.EARN["cumbre"], "Acuerdo en la cumbre")
			Perfil.unlock("estadista")
		else:
			Perfil.earn(Perfil.S.EARN["acuerdo"], "Acuerdo firmado")
		if offer >= 85.0:
			Perfil.unlock("tiburon")
	else:
		Sfx.play("fail", -2.0)
		for p in parties:
			_mood(p, -0.5, 0.4)
		if stage != null:
			stage.walk_out()
		if summit != "":
			var rel2 := {}
			for p in parties:
				if p["country"] != "":
					rel2[p["country"]] = -3.0
			fx = {"rel": rel2, "prestigio": -3}
		else:
			var p0: Dictionary = parties[0]
			fx = topic.get("nodeal", {"rel": {p0["country"]: -4.0}} if p0["country"] != "" else {"estabilidad": -2}).duplicate(true)
		GS.push_news("Fracasan las negociaciones con %s" % label, 2)
	for p in parties:
		if p["country"] != "" and summit == "":
			GS.countries[p["country"]]["cd"][topic["id"]] = GS.day + 150
		elif summit == "":
			GS.cooldowns["nego_%s_%s" % [p["who"], topic["id"]]] = GS.day + 150
	var out := GS.apply_fx(fx, topic.get("name", "Negociación"))
	GS.log_history(topic.get("name", "Negociación"), ("Acuerdo: " + _term_text(offer)) if deal else "Sin acuerdo")
	if leave_btn != null:
		leave_btn.visible = false
	if stage != null:
		# el rótulo final, cuando han firmado y se han dado la mano (o se han ido)
		stage.notice("")
		var title := "ACUERDO FIRMADO" if deal else "SIN ACUERDO"
		var res_line := ""
		if deal:
			var q := int(offer)
			res_line = "%s: %s · Resultado para Valdoria: %d/100 · %s" % [String(topic["term"][0]), _term_text(offer), q, "magistral" if q >= 85 else ("muy bueno" if q >= 65 else ("razonable" if q >= 40 else "modesto"))]
		# (los efectos se montan al sacar el rótulo: si se cierra antes, no queda nada suelto en memoria)
		_after(2.6 if deal else 2.2, func():
			if deal:
				stage.big_text("¡TRATO HECHO!", UI.GOLD_L, 120, Vector2(960, 470))
			stage.end_card(title, UI.GREEN if deal else UI.RED, res_line, Widgets.effect_chips(out, 16, 10), "Terminar", func(): close()))
		return
	for c in panel_v.get_children():
		c.queue_free()
	var res := UI.vbox(12)
	var st := UI.lbl("ACUERDO FIRMADO" if deal else "SIN ACUERDO", UI.f_cond_b, 60, UI.GREEN if deal else UI.RED)
	st.rotation = deg_to_rad(-2.5)
	res.add_child(st)
	if deal:
		res.add_child(UI.lbl(String(topic["term"][0]) + ": " + _term_text(offer), UI.f_sans_b, 24, UI.TEXT))
		var q2 := int(offer)
		res.add_child(UI.lbl("Resultado para Valdoria: %d/100 · %s" % [q2, "magistral" if q2 >= 85 else ("muy bueno" if q2 >= 65 else ("razonable" if q2 >= 40 else "modesto"))], UI.f_sans_m, 18, UI.GOLD_L))
	var chips2 := Widgets.effect_chips(out, 16, 10)
	chips2.custom_minimum_size = Vector2(minf(880.0, _col_w - 20.0), 0)
	res.add_child(chips2)
	var b := UI.btn("Terminar", "gold", 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func(): close())
	res.add_child(b)
	panel_v.add_child(res)
	UI.pop_in(res)


func _process(delta: float) -> void:
	_t += delta
	if stage != null:
		return
	for p in parties:
		var s = p["say"]
		if s is RichTextLabel and p["portrait"] != null:
			p["portrait"].talking = s.is_running()


func on_escape() -> void:
	if ended:
		close()
