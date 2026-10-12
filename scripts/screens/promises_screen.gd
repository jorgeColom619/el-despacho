extends Control
## Programa electoral: antes de jurar el cargo se eligen hasta tres promesas de las seis que se ofrecen.
## Se abre encima de la pantalla de nueva partida («Volver» la cierra sin perder lo elegido allí).

signal confirmed(ids: Array)
signal cancelled

const Promesas := preload("res://scripts/systems/promesas.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")
const Backdrop := preload("res://scripts/screens/backdrop.gd")

const MAX := 3

var offered := []
var party := "MP"
var mode := "clasico"
var seed_value := 0
var chosen := []
var cards := {}
var counter: Label
var note: Label


func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(Backdrop.new())
	var dimr := ColorRect.new()
	dimr.color = Color(0.01, 0.02, 0.04, 0.72)
	UI.full(dimr)
	add_child(dimr)
	var rng := RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	if offered.is_empty():
		offered = Promesas.offer(rng, party, mode)
	var head := UI.vbox(2)
	head.position = Vector2(120, 46)
	add_child(head)
	head.add_child(UI.lbl("PROGRAMA ELECTORAL", UI.f_sans_b, 16, UI.GOLD))
	head.add_child(UI.lbl("Sus promesas", UI.f_serif_b, 56, UI.CREAM))
	var sub := UI.lbl("Elija hasta tres. Cada promesa le da apoyo desde hoy y, si la cumple, votos el día de las elecciones. Si la rompe, lo pagará en las encuestas y la oposición se lo recordará en cada sesión de control.", UI.f_sans, 19, UI.DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(1640, 0)
	head.add_child(sub)
	var rows := [["nunca", "NUNCA LO HARÉ", "Se rompen en cuanto lo haga."], ["meta", "LO CONSEGUIRÉ", "Se juzgan al empezar la campaña electoral."]]
	var y := 236.0
	for r in rows:
		var hdr := UI.hbox(14)
		hdr.position = Vector2(120, y)
		add_child(hdr)
		hdr.add_child(UI.lbl(r[1], UI.f_sans_b, 18, UI.GOLD_L))
		hdr.add_child(UI.lbl(r[2], UI.f_sans, 17, UI.DIM))
		var x := 120.0
		for id in offered:
			var p := Promesas.def(id)
			if p.get("kind", "") != r[0]:
				continue
			var c := _card(id, p)
			c.position = Vector2(x, y + 36)
			add_child(c)
			cards[id] = c
			x += 568.0
		y += 352.0
	var bottom := UI.hbox(20)
	bottom.position = Vector2(120, 968)
	bottom.size = Vector2(1680, 70)
	add_child(bottom)
	var back := UI.btn("← Volver", "ghost", 22)
	back.pressed.connect(func():
		Sfx.play("click", -3.0)
		cancelled.emit()
		queue_free())
	bottom.add_child(back)
	bottom.add_child(UI.spacer(30, 0))
	var cv := UI.vbox(0)
	counter = UI.lbl("", UI.f_sans_b, 22, UI.TEXT)
	cv.add_child(counter)
	note = UI.lbl("", UI.f_sans, 16, UI.DIM)
	cv.add_child(note)
	bottom.add_child(cv)
	bottom.add_child(UI.spacer(0, 0, true))
	var go := UI.btn("JURAR EL CARGO", "gold", 26)
	go.custom_minimum_size = Vector2(380, 66)
	go.pressed.connect(func():
		Sfx.play("stamp", -2.0)
		confirmed.emit(chosen.duplicate()))
	bottom.add_child(go)
	_refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)


func _card(id: String, p: Dictionary) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(548, 290)
	b.size = Vector2(548, 290)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v := UI.vbox(10)
	v.position = Vector2(24, 20)
	v.size = Vector2(500, 280)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var top := UI.hbox(12)
	top.add_child(UI.icon_rect(p.get("icon", "info"), 34, UI.GOLD))
	var tag := UI.lbl("NUNCA" if p["kind"] == "nunca" else "OBJETIVO", UI.f_sans_b, 13, UI.GOLD)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(tag)
	top.add_child(UI.spacer(0, 0, true))
	var tick := UI.lbl("", UI.f_sans_b, 26, UI.GREEN)
	tick.name = "Tick"
	top.add_child(tick)
	v.add_child(top)
	var q := UI.lbl("«%s»" % p["name"], UI.f_serif_b, 27, UI.CREAM)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.custom_minimum_size = Vector2(500, 0)
	v.add_child(q)
	var d := UI.lbl(p.get("desc", ""), UI.f_sans, 17, UI.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(500, 0)
	v.add_child(d)
	var fx_row := UI.hbox(8)
	fx_row.add_child(UI.lbl("Al prometerlo:", UI.f_sans_m, 15, UI.TEXT))
	# (antes de empezar la partida GS.preview no sirve: todavía no hay grupos ni indicadores)
	var items := []
	var fx: Dictionary = p.get("fx", {})
	for k in fx.keys():
		items.append({"k": k, "v": float(fx[k])})
	var chips := Widgets.effect_chips(items, 14, 4)
	chips.custom_minimum_size = Vector2(380, 0)
	fx_row.add_child(chips)
	v.add_child(fx_row)
	var names := []
	for g in p.get("groups", []):
		names.append(GS.label_of(g).to_lower())
	var risk := UI.lbl("Si la rompe: aprobación y %s a la baja." % " y ".join(names), UI.f_sans, 15, Color(UI.RED, 0.85).lightened(0.2))
	risk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	risk.custom_minimum_size = Vector2(500, 0)
	v.add_child(risk)
	b.pressed.connect(func(): _toggle(id))
	return b


func _toggle(id: String) -> void:
	if id in chosen:
		chosen.erase(id)
		Sfx.play("click", -4.0, 0.9)
	elif chosen.size() >= MAX:
		Sfx.play("fail", -8.0)
		note.text = "Ya tiene tres. Quite una para elegir otra."
		note.add_theme_color_override("font_color", UI.AMBER)
		return
	else:
		chosen.append(id)
		Sfx.play("scribble", -4.0)
	_refresh()


func _refresh() -> void:
	for id in cards.keys():
		var b: Button = cards[id]
		var on: bool = id in chosen
		var st := UI.sb(Color(UI.GOLD, 0.16) if on else Color(0.06, 0.09, 0.15, 0.9), 12, UI.GOLD if on else Color(1, 1, 1, 0.12), 2 if on else 1)
		var sh := UI.sb(Color(UI.GOLD, 0.22) if on else Color(0.1, 0.14, 0.22, 0.95), 12, UI.GOLD, 2 if on else 1)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		var tick: Label = b.find_child("Tick", true, false)
		if tick != null:
			tick.text = "✓" if on else ""
	counter.text = "%d de %d promesas elegidas" % [chosen.size(), MAX]
	note.add_theme_color_override("font_color", UI.DIM)
	note.text = "Puede gobernar sin promesas, pero cumplirlas da votos." if chosen.is_empty() else "Haga clic en una promesa para quitarla."
