extends Control
## Configuración de la partida: retrato, nombre, partido, dificultad y duración.

const Backdrop := preload("res://scripts/screens/backdrop.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const Flags := preload("res://scripts/ui/flags.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")
const W := preload("res://scripts/data/world_data.gd")

var main: Node
var look := {"g": "m", "skin": 1, "hair": "side", "hc": 1, "glasses": 0, "beard": "none", "suit": "1b2436", "shirt": "f4f6fa", "tie": "8e2a22", "age": 1, "eyes": "3b2a20"}
var party := "MP"
var difficulty := 1
var years := 2
var portrait: Control
var name_edit: LineEdit
var party_cards := {}
var diff_btns := []
var year_btns := []
var labels := {}

const HAIR_M := ["side", "short", "slick", "wavy", "curly", "buzz", "balding", "bald"]
const HAIR_F := ["bob", "long", "wavy", "bun", "curly", "ponytail"]
const BEARDS := ["none", "stubble", "mustache", "goatee", "full"]


func _ready() -> void:
	UI.full(self)
	var bd := Backdrop.new()
	add_child(bd)
	var dimr := ColorRect.new()
	dimr.color = Color(0.01, 0.02, 0.04, 0.6)
	UI.full(dimr)
	dimr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dimr)
	var head := UI.vbox(0)
	head.position = Vector2(120, 50)
	add_child(head)
	head.add_child(UI.lbl("TOMA DE POSESIÓN", UI.f_sans_b, 16, UI.GOLD))
	head.add_child(UI.lbl("Forme su Gobierno", UI.f_serif_b, 56, UI.CREAM))
	# --- columna izquierda: retrato
	var frame := Control.new()
	frame.position = Vector2(120, 190)
	frame.size = Vector2(440, 520)
	frame.draw.connect(func():
		frame.draw_rect(Rect2(Vector2.ZERO, frame.size), Color(0.05, 0.08, 0.14))
		Flags.draw_flag(frame, "valdoria", Rect2(0, 0, frame.size.x, frame.size.y * 0.8))
		frame.draw_rect(Rect2(Vector2.ZERO, frame.size), Color(0.02, 0.03, 0.06, 0.55))
		frame.draw_rect(Rect2(Vector2.ZERO, frame.size), UI.GOLD, false, 3.0))
	add_child(frame)
	portrait = Portrait.new()
	portrait.position = Vector2(10, 20)
	portrait.size = Vector2(420, 500)
	frame.add_child(portrait)
	frame.clip_contents = true
	name_edit = LineEdit.new()
	name_edit.text = "Alejandro Ríos"
	name_edit.placeholder_text = "Nombre del presidente"
	name_edit.position = Vector2(120, 726)
	name_edit.size = Vector2(440, 50)
	name_edit.max_length = 28
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.add_theme_font_override("font", UI.f_serif_b)
	add_child(name_edit)
	var opts := UI.vbox(6)
	opts.position = Vector2(120, 790)
	opts.size = Vector2(440, 250)
	add_child(opts)
	_row(opts, "Aspecto", "g")
	_row(opts, "Tono de piel", "skin")
	_row(opts, "Peinado", "hair")
	_row(opts, "Color de pelo", "hc")
	_row(opts, "Gafas", "glasses")
	_row(opts, "Barba", "beard")
	# --- columna derecha
	var right := UI.vbox(22)
	right.position = Vector2(660, 190)
	right.size = Vector2(1160, 820)
	add_child(right)
	right.add_child(Widgets.section("Su partido"))
	var ph := UI.hbox(18)
	right.add_child(ph)
	for p in ["MP", "CC", "AR"]:
		var card := _party_card(p)
		ph.add_child(card)
		party_cards[p] = card
	right.add_child(Widgets.section("Dificultad"))
	var dh := UI.hbox(14)
	right.add_child(dh)
	var dnames := [["Fácil", "Más capital político, eventos más amables."], ["Normal", "La experiencia equilibrada."], ["Difícil", "Menos margen, más crisis, deuda más alta."]]
	for i in 3:
		var b := _option_btn(dnames[i][0], dnames[i][1])
		var idx := i
		b.pressed.connect(func():
			difficulty = idx
			_refresh())
		dh.add_child(b)
		diff_btns.append(b)
	right.add_child(Widgets.section("Duración de la legislatura"))
	var yh := UI.hbox(14)
	right.add_child(yh)
	var ynames := [[1, "1 año", "Partida rápida · ~40 min"], [2, "2 años", "Recomendado · ~1 h 20 min"], [4, "4 años", "Legislatura completa · ~2 h 30 min"]]
	for yn in ynames:
		var b2 := _option_btn(yn[1], yn[2])
		var yv: int = yn[0]
		b2.pressed.connect(func():
			years = yv
			_refresh())
		yh.add_child(b2)
		year_btns.append([yv, b2])
	right.add_child(UI.spacer(0, 10))
	var bottom := UI.hbox(20)
	right.add_child(bottom)
	var back := UI.btn("← Volver", "ghost", 22)
	back.pressed.connect(func(): main.transition(func(): main.show_menu()))
	bottom.add_child(back)
	bottom.add_child(UI.spacer(0, 0, true))
	var go := UI.btn("JURAR EL CARGO", "gold", 26)
	go.custom_minimum_size = Vector2(380, 66)
	go.pressed.connect(_start)
	bottom.add_child(go)
	_refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


func _row(parent: Control, label: String, key: String) -> void:
	var h := UI.hbox(10)
	var l := UI.lbl(label, UI.f_sans_m, 18, UI.DIM)
	l.custom_minimum_size = Vector2(160, 0)
	h.add_child(l)
	var prev := UI.btn("◀", "normal", 16)
	prev.custom_minimum_size = Vector2(44, 34)
	var val := UI.lbl("", UI.f_sans_b, 18, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	val.custom_minimum_size = Vector2(150, 0)
	var nxt := UI.btn("▶", "normal", 16)
	nxt.custom_minimum_size = Vector2(44, 34)
	prev.pressed.connect(func(): _cycle(key, -1))
	nxt.pressed.connect(func(): _cycle(key, 1))
	h.add_child(prev)
	h.add_child(val)
	h.add_child(nxt)
	labels[key] = val
	parent.add_child(h)


func _cycle(key: String, d: int) -> void:
	match key:
		"g":
			look["g"] = "f" if look["g"] == "m" else "m"
			look["hair"] = HAIR_F[0] if look["g"] == "f" else HAIR_M[0]
			look["tie"] = "" if look["g"] == "f" else "8e2a22"
			look["beard"] = "none"
			look["suit"] = "5a1f2a" if look["g"] == "f" else "1b2436"
		"skin":
			look["skin"] = wrapi(int(look["skin"]) + d, 0, 6)
		"hair":
			var list: Array = HAIR_F if look["g"] == "f" else HAIR_M
			look["hair"] = list[wrapi(list.find(look["hair"]) + d, 0, list.size())]
		"hc":
			look["hc"] = wrapi(int(look["hc"]) + d, 0, 7)
		"glasses":
			look["glasses"] = wrapi(int(look["glasses"]) + d, 0, 3)
		"beard":
			if look["g"] == "m":
				look["beard"] = BEARDS[wrapi(BEARDS.find(look["beard"]) + d, 0, BEARDS.size())]
	_refresh()


func _party_card(p: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(368, 250)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var pd: Dictionary = W.PARTIES[p]
	var col := Color(pd["color"])
	var v := UI.vbox(8)
	v.position = Vector2(22, 18)
	v.size = Vector2(324, 220)
	b.add_child(v)
	var strip := ColorRect.new()
	strip.color = col
	strip.custom_minimum_size = Vector2(60, 5)
	strip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(strip)
	v.add_child(UI.lbl(pd["name"], UI.f_serif_b, 26, UI.TEXT))
	var ideo := "Centro-izquierda" if pd["ideo"] < -10 else ("Centro-derecha" if pd["ideo"] > 10 else "Centro")
	v.add_child(UI.lbl("%s · %s · %d escaños" % [pd["short"], ideo, W.SEATS[p][p]], UI.f_sans_m, 16, col.lightened(0.3)))
	var d := UI.lbl(W.PLAYER_PARTIES[p]["desc"], UI.f_sans, 17, UI.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(320, 0)
	v.add_child(d)
	b.pressed.connect(func():
		Sfx.play("click", -3.0)
		party = p
		_refresh())
	return b


func _option_btn(title: String, desc: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(368, 84)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v := UI.vbox(2)
	v.position = Vector2(20, 12)
	b.add_child(v)
	v.add_child(UI.lbl(title, UI.f_sans_b, 22, UI.TEXT))
	v.add_child(UI.lbl(desc, UI.f_sans, 15, UI.DIM))
	b.pressed.connect(func(): Sfx.play("click", -3.0))
	return b


func _style(b: Button, on: bool, col: Color = UI.GOLD) -> void:
	var st := UI.sb(Color(col, 0.16) if on else Color(0.06, 0.09, 0.15, 0.85), 10, col if on else Color(1, 1, 1, 0.12), 2 if on else 1)
	var sh := UI.sb(Color(col, 0.22) if on else Color(0.1, 0.14, 0.22, 0.9), 10, col, 2 if on else 1)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)


func _refresh() -> void:
	portrait.setup(look, true)
	portrait.mood = 0.35
	labels["g"].text = "Masculino" if look["g"] == "m" else "Femenino"
	labels["skin"].text = "Tono %d" % (int(look["skin"]) + 1)
	labels["hair"].text = {"side": "Raya al lado", "short": "Corto", "slick": "Engominado", "wavy": "Ondulado", "curly": "Rizado", "buzz": "Rapado", "balding": "Entradas", "bald": "Calvo", "bob": "Media melena", "long": "Largo", "bun": "Moño", "ponytail": "Coleta"}.get(look["hair"], look["hair"])
	labels["hc"].text = ["Negro", "Castaño oscuro", "Castaño", "Pelirrojo", "Rubio", "Canoso", "Blanco"][int(look["hc"])]
	labels["glasses"].text = ["Sin gafas", "Redondas", "Rectangulares"][int(look["glasses"])]
	labels["beard"].text = {"none": "Afeitado", "stubble": "Barba de 3 días", "mustache": "Bigote", "goatee": "Perilla", "full": "Barba poblada"}.get(look["beard"], "")
	for p in party_cards.keys():
		_style(party_cards[p], p == party, Color(W.PARTIES[p]["color"]))
	for i in diff_btns.size():
		_style(diff_btns[i], i == difficulty)
	for yb in year_btns:
		_style(yb[1], yb[0] == years)


func _start() -> void:
	var nm := name_edit.text.strip_edges()
	if nm == "":
		nm = "Alejandro Ríos"
	Sfx.play("whoosh", -2.0)
	main.start_new({"name": nm, "party": party, "difficulty": difficulty, "years": years, "look": look.duplicate()})
