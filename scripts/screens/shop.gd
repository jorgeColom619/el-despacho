extends Control
## Tienda del Palacio: escaparate diario, lingotes (pago), colección y logros.

const Backdrop := preload("res://scripts/screens/backdrop.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")
const ItemPreview := preload("res://scripts/ui/item_preview.gd")
const S := preload("res://scripts/data/shop_data.gd")

const DISCOUNT := 0.3

var main: Node
var content: Control
var tabs := {}
var current := ""
var bal_lbl: Label
var timer_lbl: Label
var modal: Control
var coll_slot := "bandera"


func _ready() -> void:
	UI.full(self)
	add_child(Backdrop.new())
	var dimr := ColorRect.new()
	dimr.color = Color(0.01, 0.02, 0.04, 0.78)
	UI.full(dimr)
	dimr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dimr)
	var head := UI.vbox(0)
	head.position = Vector2(110, 46)
	add_child(head)
	head.add_child(UI.lbl("PALACIO DE GOBIERNO", UI.f_sans_b, 15, UI.GOLD))
	var th := UI.hbox(14)
	th.add_child(UI.icon_rect("shop", 44, UI.GOLD_L))
	th.add_child(UI.lbl("Tienda del Palacio", UI.f_serif_b, 52, UI.CREAM))
	head.add_child(th)
	bal_lbl = UI.lbl("", UI.f_cond_b, 30, UI.GOLD_L, HORIZONTAL_ALIGNMENT_RIGHT)
	bal_lbl.position = Vector2(1100, 70)
	bal_lbl.size = Vector2(710, 40)
	add_child(bal_lbl)
	var bal_icons := Control.new()
	bal_icons.position = Vector2(1100, 66)
	bal_icons.size = Vector2(710, 48)
	bal_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bal_icons)
	var tb := UI.hbox(8)
	tb.position = Vector2(110, 168)
	add_child(tb)
	for spec in [["escaparate", "Escaparate del día", "shop"], ["lingotes", "Lingotes", "lingote"], ["coleccion", "Colección", "bandera"], ["logros", "Logros", "trofeo"]]:
		var b := UI.btn("  " + spec[1], "ghost", 20)
		b.icon = UI.icon(spec[2], 36)
		b.add_theme_constant_override("icon_max_width", 22)
		var id: String = spec[0]
		b.pressed.connect(func(): _show(id))
		tb.add_child(b)
		tabs[id] = b
	timer_lbl = UI.lbl("", UI.f_sans_m, 17, UI.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	timer_lbl.position = Vector2(1210, 180)
	timer_lbl.size = Vector2(600, 30)
	add_child(timer_lbl)
	content = Control.new()
	content.position = Vector2(110, 230)
	content.size = Vector2(1700, 770)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	var back := UI.btn("← Volver al menú", "ghost", 20)
	back.position = Vector2(110, 1010)
	back.pressed.connect(func(): main.transition(func(): main.show_menu()))
	add_child(back)
	Perfil.changed.connect(_refresh_balance)
	Payments.purchase_completed.connect(_on_paid)
	Payments.purchase_failed.connect(_on_pay_failed)
	_refresh_balance()
	_show("escaparate")
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)


func _process(_d: float) -> void:
	var s := Perfil.seconds_to_rotation()
	timer_lbl.text = "Nueva selección en %02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60] if current == "escaparate" else ""


func _refresh_balance() -> void:
	bal_lbl.text = "%s Laureles     %s Lingotes" % [UI.num(Perfil.laureles), UI.num(Perfil.lingotes)]


func _show(id: String) -> void:
	current = id
	for k in tabs.keys():
		var b: Button = tabs[k]
		b.add_theme_color_override("font_color", UI.GOLD_L if k == id else UI.TEXT)
		b.add_theme_stylebox_override("normal", UI.sb(Color(UI.GOLD, 0.14), 6, Color(UI.GOLD, 0.45), 1) if k == id else StyleBoxEmpty.new())
	for c in content.get_children():
		c.queue_free()
	match id:
		"escaparate":
			_escaparate()
		"lingotes":
			_lingotes()
		"coleccion":
			_coleccion()
		"logros":
			_logros()


func _rarity_chip(r: String) -> Control:
	var rd: Dictionary = S.RARITY[r]
	return Widgets.chip("", rd["name"].to_upper(), Color(rd["color"]), 13)


func _preview(id: String, sz: Vector2) -> Control:
	var p := ItemPreview.new()
	p.setup(id)
	p.custom_minimum_size = sz
	p.size = sz
	return p


func _price_text(cost: Dictionary) -> String:
	if cost.has("laureles"):
		return "%s Laureles" % UI.num(cost["laureles"])
	return "%s Lingotes" % UI.num(cost.get("lingotes", 0))


func _buy_button(id: String, discount: float) -> Button:
	var it: Dictionary = S.ITEMS[id]
	var b: Button
	if Perfil.is_owned(id):
		var eq: bool = Perfil.equipped.get(it["slot"], "") == id
		b = UI.btn("Equipado" if eq else "Equipar", "normal", 17)
		b.disabled = eq
		b.pressed.connect(func():
			Perfil.equip(id)
			Sfx.play("click", -2.0)
			_show(current))
	else:
		var cost := Perfil.price_for(id, discount)
		b = UI.btn("Comprar · " + _price_text(cost), "gold", 17)
		b.icon = UI.icon("laurel" if cost.has("laureles") else "lingote", 32)
		b.add_theme_constant_override("icon_max_width", 20)
		if not Perfil.can_afford(cost):
			b.disabled = true
			var lau: bool = cost.has("laureles")
			var missing: int = int(cost["laureles"]) - Perfil.laureles if lau else int(cost.get("lingotes", 0)) - Perfil.lingotes
			b.text = "%s · te faltan %s" % [_price_text(cost), UI.num(missing)]
			b.add_theme_color_override("font_disabled_color", Color(0.9, 0.84, 0.7))
			b.tooltip_text = "No tienes suficientes %s" % ("laureles" if lau else "lingotes")
		b.pressed.connect(func():
			if Perfil.buy(id, discount):
				Sfx.play("coin", 0.0)
				Sfx.play("success", -6.0)
				GS.toast.emit("¡Comprado: %s! Ya está equipado." % it["name"], "good", "shop")
				_show(current))
	return b


func _escaparate() -> void:
	var items := Perfil.shop_today()
	var feat := Perfil.featured_today()
	# destacado
	if feat != "":
		var it: Dictionary = S.ITEMS[feat]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.sb(Color(0.08, 0.07, 0.04, 0.96), 12, UI.GOLD, 2, 18, 22))
		card.position = Vector2(0, 0)
		card.custom_minimum_size = Vector2(540, 760)
		content.add_child(card)
		var v := UI.vbox(12)
		card.add_child(v)
		var rib := UI.hbox(10)
		rib.add_child(Widgets.chip("capital", "OFERTA DEL DÍA · −%d%%" % int(DISCOUNT * 100), UI.GOLD_L, 16))
		rib.add_child(_rarity_chip(it["rarity"]))
		v.add_child(rib)
		v.add_child(_preview(feat, Vector2(496, 360)))
		v.add_child(UI.lbl(it["name"], UI.f_serif_b, 32, UI.CREAM))
		v.add_child(UI.lbl(S.SLOTS[it["slot"]].to_upper(), UI.f_sans_b, 14, UI.GOLD))
		var d := UI.lbl(it["desc"], UI.f_sans, 18, UI.DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(490, 0)
		v.add_child(d)
		v.add_child(UI.spacer(0, 0, true))
		if not Perfil.is_owned(feat):
			var old := UI.lbl("Antes: " + _price_text(Perfil.price_for(feat)), UI.f_sans, 16, Color(UI.DIM, 0.7))
			v.add_child(old)
		var bb := _buy_button(feat, DISCOUNT)
		bb.custom_minimum_size = Vector2(490, 56)
		v.add_child(bb)
	# rejilla
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(570, 0)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	content.add_child(grid)
	for id in items:
		if id == feat:
			continue
		grid.add_child(_item_card(id))


func _item_card(id: String) -> Control:
	var it: Dictionary = S.ITEMS[id]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.sb(Color(0.05, 0.08, 0.13, 0.96), 10, Color(S.RARITY[it["rarity"]]["color"]), 1, 0, 14))
	card.custom_minimum_size = Vector2(366, 372)
	var v := UI.vbox(8)
	card.add_child(v)
	v.add_child(_preview(id, Vector2(338, 170)))
	var h := UI.hbox(8)
	var n := UI.lbl(it["name"], UI.f_serif_b, 21, UI.CREAM)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	h.add_child(_rarity_chip(it["rarity"]))
	v.add_child(h)
	v.add_child(UI.lbl(S.SLOTS[it["slot"]].to_upper(), UI.f_sans_b, 12, UI.GOLD))
	var d := UI.lbl(it["desc"], UI.f_sans, 15, UI.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(330, 40)
	v.add_child(d)
	var bb := _buy_button(id, 0.0)
	bb.custom_minimum_size = Vector2(338, 44)
	v.add_child(bb)
	return card


# ------------------------------------------------------------------ lingotes

func _lingotes() -> void:
	var v := UI.vbox(18)
	content.add_child(v)
	if Payments.is_test_mode():
		var warn := PanelContainer.new()
		warn.add_theme_stylebox_override("panel", UI.sb(Color(0.25, 0.18, 0.04, 0.95), 8, UI.AMBER, 1, 0, 14))
		var wl := UI.lbl("MODO DE PRUEBA · Las compras con dinero real están simuladas: no se realiza ningún cargo. Para cobrar de verdad hay que conectar Steam o Stripe (ver scripts/autoload/payments.gd).", UI.f_sans_m, 17, UI.AMBER.lightened(0.3))
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wl.custom_minimum_size = Vector2(1640, 0)
		warn.add_child(wl)
		v.add_child(warn)
	var h := UI.hbox(18)
	v.add_child(h)
	for p in S.PACKS:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.sb(Color(0.08, 0.07, 0.04, 0.96), 12, UI.GOLD_D, 1, 0, 20))
		card.custom_minimum_size = Vector2(400, 440)
		var cv := UI.vbox(12)
		card.add_child(cv)
		var art := Control.new()
		art.custom_minimum_size = Vector2(360, 190)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var n_bars := 1 if p["amount"] < 300 else (3 if p["amount"] < 1000 else 6)
		art.draw.connect(func():
			for i in n_bars:
				var row := i / 3
				var col := i % 3
				var base := Vector2(180 - minf(n_bars, 3) * 45 + col * 90 + row * 45, 150 - row * 44)
				art.draw_colored_polygon(PackedVector2Array([base + Vector2(-40, 0), base + Vector2(40, 0), base + Vector2(28, -38), base + Vector2(-28, -38)]), Color("c9a55c"))
				art.draw_colored_polygon(PackedVector2Array([base + Vector2(-28, -38), base + Vector2(28, -38), base + Vector2(20, -46), base + Vector2(-20, -46)]), Color("f0d58f"))
				art.draw_line(base + Vector2(-24, -30), base + Vector2(10, -30), Color(1, 1, 1, 0.5), 2.0))
		cv.add_child(art)
		cv.add_child(UI.lbl(p["name"], UI.f_serif_b, 28, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(UI.lbl("%s Lingotes" % UI.num(p["amount"]), UI.f_cond_b, 34, UI.GOLD_L, HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(UI.lbl(p["bonus"] if p["bonus"] != "" else " ", UI.f_sans_b, 15, UI.GREEN, HORIZONTAL_ALIGNMENT_CENTER))
		var b := UI.btn("Comprar · " + p["price"], "gold", 20)
		var pid: String = p["id"]
		b.pressed.connect(func(): _confirm_pack(pid))
		cv.add_child(b)
		h.add_child(card)
	var ex := PanelContainer.new()
	ex.add_theme_stylebox_override("panel", UI.sb(Color(0.05, 0.08, 0.13, 0.96), 12, Color(1, 1, 1, 0.12), 1, 0, 20))
	ex.custom_minimum_size = Vector2(440, 440)
	var ev := UI.vbox(14)
	ex.add_child(ev)
	ev.add_child(UI.lbl("Cambio de moneda", UI.f_serif_b, 28, UI.CREAM))
	var el := UI.lbl("Los lingotes compran objetos legendarios exclusivos. También puedes cambiarlos por laureles.", UI.f_sans, 17, UI.DIM)
	el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	el.custom_minimum_size = Vector2(400, 0)
	ev.add_child(el)
	ev.add_child(UI.lbl("%d Lingotes  →  %d Laureles" % [S.EXCHANGE["lingotes"], S.EXCHANGE["laureles"]], UI.f_cond_b, 28, UI.GOLD_L))
	var xb := UI.btn("Cambiar", "normal", 20)
	xb.disabled = Perfil.lingotes < int(S.EXCHANGE["lingotes"])
	xb.pressed.connect(func():
		if Perfil.exchange():
			Sfx.play("coin", 0.0)
			_show("lingotes"))
	ev.add_child(xb)
	ev.add_child(UI.spacer(0, 20))
	ev.add_child(UI.lbl("Cómo ganar laureles jugando", UI.f_sans_b, 17, UI.GOLD))
	var hl := UI.lbl("Aprobar leyes, superar crisis, cerrar acuerdos, ganar debates y sesiones de control, firmar cumbres, hacer campaña, desbloquear logros y, sobre todo, terminar partidas con buena nota.", UI.f_sans, 15, UI.DIM)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.custom_minimum_size = Vector2(400, 0)
	ev.add_child(hl)
	h.add_child(ex)


func _confirm_pack(pid: String) -> void:
	var pack: Dictionary = {}
	for p in S.PACKS:
		if p["id"] == pid:
			pack = p
	var v := UI.vbox(16)
	v.add_child(UI.lbl("Confirmar compra", UI.f_serif_b, 34, UI.CREAM))
	v.add_child(UI.lbl("%s · %s Lingotes" % [pack["name"], UI.num(pack["amount"])], UI.f_sans_b, 20, UI.GOLD_L))
	v.add_child(UI.lbl("Precio: %s · Pago con: %s" % [pack["price"], Payments.provider_name()], UI.f_sans_m, 18, UI.TEXT))
	if Payments.is_test_mode():
		var w := UI.lbl("Modo de prueba: no se realizará ningún cargo real.", UI.f_sans_b, 16, UI.AMBER)
		v.add_child(w)
	var h := UI.hbox(14)
	var no := UI.btn("Cancelar", "ghost", 18)
	no.pressed.connect(_close_modal)
	h.add_child(no)
	var ok := UI.btn("Pagar " + pack["price"], "gold", 20)
	ok.pressed.connect(func():
		_close_modal()
		_modal_msg("Procesando el pago...", false)
		Payments.buy(pid))
	h.add_child(ok)
	v.add_child(h)
	_open_modal(v)


func _on_paid(pid: String, _r: Dictionary) -> void:
	_close_modal()
	for p in S.PACKS:
		if p["id"] == pid:
			GS.toast.emit("+%s Lingotes añadidos a tu cuenta" % UI.num(p["amount"]), "good", "lingote")
	Sfx.play("success", -2.0)
	_refresh_balance()
	if current == "lingotes":
		_show("lingotes")


func _on_pay_failed(_pid: String, reason: String) -> void:
	_close_modal()
	_modal_msg("No se pudo completar el pago: " + reason, true)


func _open_modal(c: Control) -> void:
	_close_modal()
	modal = Control.new()
	UI.full(modal)
	var dimr := ColorRect.new()
	dimr.color = Color(0, 0, 0, 0.65)
	UI.full(dimr)
	modal.add_child(dimr)
	var cc := CenterContainer.new()
	UI.full(cc)
	var p := UI.panel(Color(0.035, 0.05, 0.085, 0.98), 12, Color(UI.GOLD, 0.6), 30)
	p.add_child(c)
	cc.add_child(p)
	modal.add_child(cc)
	add_child(modal)
	UI.pop_in(p)


func _modal_msg(text: String, closable: bool) -> void:
	var v := UI.vbox(14)
	var l := UI.lbl(text, UI.f_sans_m, 20, UI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	v.add_child(l)
	if closable:
		var b := UI.btn("Cerrar", "gold", 18)
		b.pressed.connect(_close_modal)
		v.add_child(b)
	_open_modal(v)


func _close_modal() -> void:
	if modal != null and is_instance_valid(modal):
		modal.queue_free()
	modal = null


# ------------------------------------------------------------------ colección

func _coleccion() -> void:
	var nav := UI.vbox(4)
	nav.position = Vector2(0, 0)
	nav.size = Vector2(320, 760)
	content.add_child(nav)
	var total := 0
	var have := 0
	for id in S.ITEMS.keys():
		total += 1
		if Perfil.is_owned(id):
			have += 1
	nav.add_child(UI.lbl("%d de %d objetos" % [have, total], UI.f_sans_b, 17, UI.GOLD))
	for cat in S.CATEGORIES.keys():
		nav.add_child(UI.lbl(S.CATEGORY_NAMES[cat].to_upper(), UI.f_sans_b, 13, UI.DIM))
		for slot in S.CATEGORIES[cat]:
			var b := UI.btn("  " + S.SLOTS[slot], "ghost", 17)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if slot == coll_slot:
				b.add_theme_color_override("font_color", UI.GOLD_L)
			var sl: String = slot
			b.pressed.connect(func():
				coll_slot = sl
				_show("coleccion"))
			nav.add_child(b)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(350, 0)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	content.add_child(grid)
	for id in S.ITEMS.keys():
		if S.ITEMS[id]["slot"] != coll_slot:
			continue
		var it: Dictionary = S.ITEMS[id]
		var owned := Perfil.is_owned(id)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.sb(Color(0.05, 0.08, 0.13, 0.96), 10, Color(S.RARITY[it["rarity"]]["color"]) if owned else Color(1, 1, 1, 0.08), 1, 0, 12))
		card.custom_minimum_size = Vector2(430, 300)
		var v := UI.vbox(8)
		card.add_child(v)
		var pv := _preview(id, Vector2(404, 170))
		if not owned:
			pv.modulate = Color(0.45, 0.45, 0.5)
		v.add_child(pv)
		var h := UI.hbox(8)
		var n := UI.lbl(it["name"], UI.f_serif_b, 20, UI.CREAM if owned else UI.DIM)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(_rarity_chip(it["rarity"]))
		v.add_child(h)
		if owned:
			var b2 := _buy_button(id, 0.0)
			v.add_child(b2)
		else:
			var inshop: bool = id in Perfil.shop_today()
			v.add_child(UI.lbl("A la venta hoy en el escaparate" if inshop else "Aparecerá en el escaparate algún día", UI.f_sans_m, 15, UI.GREEN if inshop else UI.DIM))
		grid.add_child(card)


# ------------------------------------------------------------------ logros

func _logros() -> void:
	var scroll := ScrollContainer.new()
	scroll.size = content.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	for id in S.ACHIEVEMENTS.keys():
		var a: Dictionary = S.ACHIEVEMENTS[id]
		var done := Perfil.achievements.has(id)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.sb(Color(0.08, 0.07, 0.04, 0.96) if done else Color(0.05, 0.07, 0.11, 0.9), 10, UI.GOLD if done else Color(1, 1, 1, 0.08), 1, 0, 16))
		card.custom_minimum_size = Vector2(550, 120)
		var h := UI.hbox(16)
		card.add_child(h)
		h.add_child(UI.icon_rect("trofeo", 44, UI.GOLD_L if done else Color(1, 1, 1, 0.2)))
		var v := UI.vbox(2)
		v.add_child(UI.lbl(a["name"], UI.f_serif_b, 22, UI.CREAM if done else UI.DIM))
		var d := UI.lbl(a["desc"], UI.f_sans, 15, UI.DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(360, 0)
		v.add_child(d)
		v.add_child(UI.lbl(("Conseguido el %s" % Perfil.achievements[id]) if done else "+%d Laureles" % int(a["reward"]), UI.f_sans_b, 14, UI.GREEN if done else UI.GOLD))
		h.add_child(v)
		grid.add_child(card)
