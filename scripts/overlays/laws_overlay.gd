extends "res://scripts/ui/overlay.gd"
## Libro de Leyes de la República: el libro de la mesa del despacho, abierto. En la página izquierda, el resumen de lo
## legislado y el índice (de lo más reciente a lo más antiguo); en la derecha, la ficha de la ley elegida: la
## votación y qué grupos la apoyaron, sus efectos inmediatos y permanentes, lo que cuesta cada mes y, en las leyes
## menores firmadas en la bandeja, la letra pequeña de su anexo con lo que de verdad hacía.

const Widgets := preload("res://scripts/ui/widgets.gd")
const W := preload("res://scripts/data/world_data.gd")

const BOOK := Rect2(150, 92, 1620, 900)
const LEFT := Rect2(184, 118, 770, 848)
const RIGHT := Rect2(966, 118, 770, 848)
const FILTERS := [["todas", "Todas"], ["grandes", "Grandes leyes"], ["menores", "Leyes menores"], ["fuera", "Rechazadas y vetadas"]]
const STAMP_COLS := {"vigor": Color("2f7a4a"), "rechazada": Color("a3291f"), "vetada": Color("5c5a55"), "silencio": Color("a8741a")}
const STAMP_TEXT := {"vigor": "EN VIGOR", "rechazada": "RECHAZADA", "vetada": "VETADA", "silencio": "SIN FIRMA"}

var filter := "todas"
var selected := -1
var _list: VBoxContainer
var _page: VBoxContainer
var _page_scroll: ScrollContainer
var _filter_btns := {}
## Número oficial de cada entrada aprobada («Ley Orgánica 2/2027»), por índice en GS.law_log
var _numbers := {}


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.9)
	_number_laws()
	var book := Control.new()
	UI.full(book)
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.draw.connect(_draw_book.bind(book))
	root.add_child(book)
	_build_left()
	_build_right()
	GS.law_seen = GS.law_log.size()
	Sfx.play("paper2", -4.0, 0.8)
	var newest := _entries()
	_select(newest[0] if not newest.is_empty() else -1)
	book.modulate.a = 0.0
	book.position.y = 30.0
	var t := book.create_tween().set_parallel()
	t.tween_property(book, "modulate:a", 1.0, 0.25)
	t.tween_property(book, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Numeración oficial por años: «Ley Orgánica 1/2027» para las grandes leyes y «Ley 4/2027» para las menores
func _number_laws() -> void:
	var count := {}
	for i in GS.law_log.size():
		var e: Dictionary = GS.law_log[i]
		if not e.get("ok", false) or int(e.get("day", -1)) < 0:
			continue
		var year := int(UI.date_dict(int(e["day"]))["year"])
		var key := "%s_%d" % [e["type"], year]
		count[key] = int(count.get(key, 0)) + 1
		_numbers[i] = "%s %d/%d" % ["Ley Orgánica" if e["type"] == "ley" else "Ley", count[key], year]


func _draw_book(c: Control) -> void:
	# tapas de cuero con filete dorado
	c.draw_rect(BOOK.grow(10), Color(0, 0, 0, 0.35))
	c.draw_rect(BOOK, Color("4a1a12"))
	c.draw_rect(BOOK.grow(-8), Color("5b2217"))
	c.draw_rect(BOOK.grow(-14), Color(UI.GOLD, 0.7), false, 2.0)
	# canto de las hojas y las dos páginas
	for k in 4:
		c.draw_rect(Rect2(LEFT.position + Vector2(-4 + k, 4 + k), LEFT.size), Color("d9cdb0").darkened(0.05 * k))
		c.draw_rect(Rect2(RIGHT.position + Vector2(4 - k, 4 + k), RIGHT.size), Color("d9cdb0").darkened(0.05 * k))
	c.draw_rect(LEFT, UI.PAPER)
	c.draw_rect(RIGHT, UI.PAPER)
	# sombra del lomo
	for k in 18:
		var a := 0.16 * (1.0 - k / 18.0)
		c.draw_rect(Rect2(LEFT.end.x - k - 1, LEFT.position.y, 1, LEFT.size.y), Color(0.25, 0.18, 0.1, a))
		c.draw_rect(Rect2(RIGHT.position.x + k, RIGHT.position.y, 1, RIGHT.size.y), Color(0.25, 0.18, 0.1, a))
	# cinta de lectura
	var rx := RIGHT.end.x - 70.0
	c.draw_rect(Rect2(rx, BOOK.position.y - 6, 18, 120), Color("8e2a22"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(rx, BOOK.position.y + 114), Vector2(rx + 18, BOOK.position.y + 114), Vector2(rx + 9, BOOK.position.y + 102)]), UI.PAPER)
	# filete de las páginas
	c.draw_rect(LEFT.grow(-18), Color(UI.INK, 0.25), false, 1.0)
	c.draw_rect(RIGHT.grow(-18), Color(UI.INK, 0.25), false, 1.0)


func _ink(text: String, font: Font, size: int, alpha := 1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return UI.lbl(text, font, size, Color(UI.INK, alpha), align)


func _wrap(l: Label, w: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	return l


func _rule(w: float) -> Control:
	var r := ColorRect.new()
	r.color = Color(UI.INK, 0.25)
	r.custom_minimum_size = Vector2(w, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ------------------------------------------------------------------ página izquierda: resumen e índice

func _build_left() -> void:
	var w := LEFT.size.x - 80.0
	var v := UI.vbox(8)
	v.position = LEFT.position + Vector2(40, 34)
	# alto fijo: el índice (que se expande) llena hasta el pie de la página
	v.size = Vector2(w, LEFT.size.y - 74)
	root.add_child(v)
	v.add_child(_ink("REPÚBLICA DE VALDORIA", UI.f_sans_b, 13, 0.6, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_ink("Libro de Leyes", UI.f_goth, 50, 1.0, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_ink("%s legislatura · presidente %s" % [GS.ordinal(GS.term_index).capitalize(), GS.pres["name"]], UI.f_serif_k, 17, 0.7, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer(0, 4))
	v.add_child(_rule(w))
	# resumen de lo legislado
	var big := 0
	var small := 0
	var out := 0
	var monthly := 0.0
	for e in GS.law_log:
		if e.get("ok", false):
			if e["type"] == "ley":
				big += 1
				monthly += float(W.LAWS.get(e["id"], {}).get("monthly", 0.0))
			else:
				small += 1
				monthly += float(e.get("fx", {}).get("monthly", 0.0)) + float(e.get("rfx", {}).get("monthly", 0.0))
		else:
			out += 1
	var sv := UI.vbox(2)
	v.add_child(sv)
	sv.add_child(_ink("En vigor: %d gran%s ley%s y %d ley%s menor%s" % [big, "" if big == 1 else "des", "" if big == 1 else "es", small, "" if small == 1 else "es", "" if small == 1 else "es"], UI.f_sans_b, 18))
	if out > 0:
		sv.add_child(_ink("Rechazadas en el Congreso o vetadas por usted: %d" % out, UI.f_sans_m, 16, 0.8))
	var ml := _ink("Lo que cuestan sus leyes a las arcas: %s al mes" % UI.money(monthly, true) if absf(monthly) >= 1.0 else "Sus leyes no tienen coste mensual para las arcas", UI.f_sans_m, 16, 0.8)
	if monthly <= -1.0:
		ml.add_theme_color_override("font_color", STAMP_COLS["rechazada"])
	elif monthly >= 1.0:
		ml.add_theme_color_override("font_color", STAMP_COLS["vigor"])
	sv.add_child(ml)
	sv.add_child(_wrap(_ink("Cada gran ley aprobada en esta legislatura encarece la siguiente un 20 %% de capital político (ya lleva %d)." % GS.laws_term, UI.f_sans, 15, 0.65), w))
	v.add_child(UI.spacer(0, 2))
	# filtros del índice
	var fh := UI.hbox(6)
	v.add_child(fh)
	for f in FILTERS:
		var b := UI.btn(f[1], "normal", 14)
		b.custom_minimum_size = Vector2(0, 34)
		var fid: String = f[0]
		b.pressed.connect(func():
			filter = fid
			Sfx.play("paper2", -10.0, 1.3)
			_fill_list())
		fh.add_child(b)
		_filter_btns[fid] = b
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(w, 120)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	_list = UI.vbox(6)
	_list.custom_minimum_size = Vector2(w - 14, 0)
	sc.add_child(_list)


## Índices de GS.law_log que se ven con el filtro actual, de lo más reciente a lo más antiguo
func _entries() -> Array:
	var out := []
	for i in range(GS.law_log.size() - 1, -1, -1):
		var e: Dictionary = GS.law_log[i]
		var ok: bool = e.get("ok", false)
		match filter:
			"grandes":
				if e["type"] != "ley" or not ok:
					continue
			"menores":
				if e["type"] != "menor" or not ok:
					continue
			"fuera":
				if ok:
					continue
		out.append(i)
	return out


func _stamp(e: Dictionary) -> String:
	if not e.get("ok", false):
		return "rechazada" if e["type"] == "ley" else "vetada"
	if e.get("auto", false):
		return "silencio"
	return "vigor"


func _name_of(e: Dictionary) -> String:
	if e["type"] == "ley":
		return str(W.LAWS.get(e.get("id", ""), {}).get("name", e.get("id", "")))
	return str(e.get("t", "Ley"))


func _fill_list() -> void:
	for k in _filter_btns.keys():
		(_filter_btns[k] as Button).modulate = Color.WHITE if k == filter else Color(1, 1, 1, 0.55)
	for c in _list.get_children():
		c.queue_free()
	var ids := _entries()
	if ids.is_empty():
		var msg := "Todavía no hay nada escrito en el libro." if GS.law_log.is_empty() else "No hay leyes en esta sección."
		_list.add_child(UI.spacer(0, 20))
		_list.add_child(_ink(msg, UI.f_serif_k, 20, 0.6, HORIZONTAL_ALIGNMENT_CENTER))
		return
	for i in ids:
		var e: Dictionary = GS.law_log[i]
		var st := _stamp(e)
		var h := UI.hbox(12)
		h.custom_minimum_size = Vector2(_list.custom_minimum_size.x - 34, 0)
		h.add_child(UI.icon_rect(str(W.LAWS.get(e.get("id", ""), {}).get("icon", "ley")) if e["type"] == "ley" else "documento", 22, Color(UI.INK, 0.7)))
		var tv := UI.vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kick: String = _numbers.get(i, "Gran ley" if e["type"] == "ley" else "Ley menor")
		var d := int(e.get("day", -1))
		tv.add_child(_ink("%s · %s" % [kick, UI.date_short(d) if d >= 0 else "fecha sin registrar"], UI.f_sans_b, 12, 0.55))
		tv.add_child(_wrap(_ink(_name_of(e), UI.f_serif_b, 19), 470))
		h.add_child(tv)
		var sl := UI.lbl(STAMP_TEXT[st], UI.f_sans_b, 12, STAMP_COLS[st], HORIZONTAL_ALIGNMENT_CENTER)
		sl.custom_minimum_size = Vector2(96, 0)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sl)
		var sel: bool = i == selected
		var card := Widgets.click_card(h, _select.bind(i), 10, Color("e4d6b6") if sel else Color("ebdfc4"), Color(UI.INK, 0.5) if sel else Color(UI.INK, 0.12))
		card.set_meta("law", i)
		_list.add_child(card)


func _select(i: int) -> void:
	if i != selected and selected != -1:
		Sfx.play("paper2", -8.0, 1.15)
	selected = i
	_fill_list()
	_fill_page()


# ------------------------------------------------------------------ página derecha: la ficha de la ley

func _build_right() -> void:
	_page_scroll = ScrollContainer.new()
	_page_scroll.position = RIGHT.position + Vector2(40, 34)
	_page_scroll.size = Vector2(RIGHT.size.x - 66, RIGHT.size.y - 130)
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_page_scroll)
	_page = UI.vbox(10)
	_page.custom_minimum_size = Vector2(RIGHT.size.x - 90, 0)
	_page_scroll.add_child(_page)
	var bh := UI.hbox(14)
	bh.position = Vector2(RIGHT.position.x + 40, RIGHT.end.y - 84)
	bh.size = Vector2(RIGHT.size.x - 80, 50)
	root.add_child(bh)
	var ag := UI.btn("Presentar leyes · Agenda legislativa", "normal", 16)
	ag.pressed.connect(func():
		close()
		if main != null:
			main.open_overlay("dashboard", {"tab": "leyes"}))
	bh.add_child(ag)
	bh.add_child(UI.spacer(0, 0, true))
	var cb := UI.btn("Cerrar el libro", "gold", 18)
	cb.pressed.connect(func(): close())
	bh.add_child(cb)


func _fill_page() -> void:
	for c in _page.get_children():
		c.queue_free()
	_page_scroll.scroll_vertical = 0
	var w := _page.custom_minimum_size.x
	if selected < 0 or selected >= GS.law_log.size():
		_page.add_child(UI.spacer(0, 140))
		_page.add_child(_ink("Páginas en blanco", UI.f_serif_b, 34, 0.75, HORIZONTAL_ALIGNMENT_CENTER))
		_page.add_child(UI.spacer(0, 8))
		_page.add_child(_wrap(_ink("Aquí quedarán escritas las grandes leyes que el Congreso vote (preséntelas desde el ordenador, en la Agenda legislativa) y las leyes menores que firme o vete en la bandeja de documentos: con la votación, sus efectos, lo que cuestan cada mes y la letra pequeña de cada anexo.", UI.f_serif, 19, 0.75, HORIZONTAL_ALIGNMENT_CENTER), w))
		return
	var e: Dictionary = GS.law_log[selected]
	if e["type"] == "ley":
		_page_big(e, w)
	else:
		_page_small(e, w)


func _date_line(e: Dictionary, verb: String) -> String:
	var d := int(e.get("day", -1))
	if d < 0:
		return verb + " antes de que se abriera este libro"
	var s := "%s el %s" % [verb, UI.date_mid(d)]
	var ago := GS.day - d
	if e.get("ok", false):
		s += " · en vigor desde hoy" if ago <= 0 else " · en vigor desde hace %d día%s" % [ago, "" if ago == 1 else "s"]
	return s


func _head(kicker: String, title: String, w: float) -> void:
	_page.add_child(_ink(kicker.to_upper(), UI.f_sans_b, 14, 0.6))
	_page.add_child(_wrap(_ink(title, UI.f_serif_b, 34), w))


func _section(text: String, w: float) -> void:
	_page.add_child(UI.spacer(0, 4))
	var h := UI.hbox(10)
	h.add_child(_ink(text.to_upper(), UI.f_sans_b, 13, 0.75))
	var line := _rule(10)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(line)
	h.custom_minimum_size = Vector2(w, 0)
	_page.add_child(h)


## Fichas de efectos en tinta (las de siempre son claras, pensadas para fondo oscuro)
func _ink_chips(items: Array, w: float) -> Control:
	var box := HFlowContainer.new()
	box.add_theme_constant_override("h_separation", 6)
	box.add_theme_constant_override("v_separation", 6)
	box.custom_minimum_size = Vector2(w, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for it in items:
		var k: String = it["k"]
		var v: float = float(it["v"])
		var txt := ""
		match k:
			"money":
				txt = "Tesoro " + UI.money(v, true)
			"monthly":
				txt = UI.money(v, true) + " al mes"
			"pc":
				txt = UI.signed(v) + " CP"
			_:
				if absf(v) < 0.5:
					continue
				txt = "%s %s" % [GS.label_of(k), Widgets.arrows(v)]
		var col := STAMP_COLS["vigor"] if v > 0 else STAMP_COLS["rechazada"]
		var p := PanelContainer.new()
		var st := UI.sb(Color(col, 0.1), 5, Color(col, 0.5), 1)
		st.content_margin_left = 7
		st.content_margin_right = 8
		st.content_margin_top = 3
		st.content_margin_bottom = 3
		p.add_theme_stylebox_override("panel", st)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := UI.hbox(5)
		h.add_child(UI.icon_rect(GS.icon_of(k), 15, col))
		h.add_child(UI.lbl(txt, UI.f_sans_m, 15, col.darkened(0.25)))
		p.add_child(h)
		box.add_child(p)
	if box.get_child_count() == 0:
		return _ink("Sin efectos apreciables.", UI.f_serif_k, 16, 0.6)
	return box


func _party_line(label: String, parties: Array, w: float) -> void:
	if parties.is_empty():
		return
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 6)
	h.custom_minimum_size = Vector2(w, 0)
	var l := _ink(label, UI.f_sans_b, 15, 0.8)
	h.add_child(l)
	for p in parties:
		var pd: Dictionary = W.PARTIES.get(str(p), {})
		if pd.is_empty():
			continue
		var col := Color(pd["color"])
		var chip := PanelContainer.new()
		var st := UI.sb(Color(col, 0.18), 4, Color(col, 0.8), 1)
		st.content_margin_left = 7
		st.content_margin_right = 7
		chip.add_theme_stylebox_override("panel", st)
		chip.tooltip_text = str(pd["name"])
		chip.add_child(UI.lbl(str(pd["short"]), UI.f_sans_b, 14, col.darkened(0.35)))
		h.add_child(chip)
	_page.add_child(h)


func _page_big(e: Dictionary, w: float) -> void:
	var id := str(e.get("id", ""))
	var law: Dictionary = W.LAWS.get(id, {})
	var ok: bool = e.get("ok", false)
	_head(_numbers.get(selected, "Gran ley") if ok else "Proyecto de ley rechazado", str(law.get("name", id)), w)
	_page.add_child(_ink(_date_line(e, "Aprobada por el Congreso" if ok else "Rechazada por el Congreso"), UI.f_serif_k, 17, 0.75))
	_page.add_child(_wrap(_ink(str(law.get("desc", "")), UI.f_serif, 20, 0.9), w))
	if e.has("yes"):
		_section("La votación", w)
		var need := int(e.get("needed", 176))
		_page.add_child(_ink("%d votos a favor · %d en contra · %d abstenciones" % [int(e["yes"]), int(e.get("no", 0)), int(e.get("abst", 0))], UI.f_sans_b, 18))
		var margin := int(e["yes"]) - need
		var ml := "Mayoría necesaria: %d. " % need
		ml += ("Salió con %d voto%s de margen." % [margin, "" if margin == 1 else "s"]) if margin >= 0 else ("Le faltaron %d voto%s." % [-margin, "" if margin == -1 else "s"])
		_page.add_child(_ink(ml, UI.f_sans, 16, 0.75))
		_party_line("A favor:", e.get("favor", []), w)
		_party_line("En contra:", e.get("contra", []), w)
	elif e.has("via"):
		_section("Cómo salió adelante", w)
		_page.add_child(_wrap(_ink("Se aprobó a raíz de: %s." % GS.fmt(str(e["via"])), UI.f_serif, 18, 0.85), w))
	if ok:
		_section("Efectos al aprobarla", w)
		_page.add_child(_ink_chips(GS.preview(law.get("fx", {})), w))
		_section("Efectos permanentes mientras siga en vigor", w)
		var mods := []
		for mk in law.get("mods", {}).keys():
			var lv := float(law["mods"][mk])
			mods.append({"k": mk, "v": lv * (GS.LAW_STRENGTH if lv > 0.0 else 1.0)})
		_page.add_child(_ink_chips(mods, w))
		_page.add_child(_wrap(_ink("Los perjudicados por una ley se movilizan más que los beneficiados: lo que pierde un grupo pesa más que lo que gana otro.", UI.f_sans, 14, 0.6), w))
		_section("Las cuentas", w)
		if law.has("monthly"):
			var m := float(law["monthly"])
			# lo acumulado, solo cuando ya ha pasado al menos un mes
			var days := GS.day - int(e.get("day", -1)) if int(e.get("day", -1)) >= 0 else 0
			var acc := "" if days < 30 else " (unos %s en total hasta hoy)" % UI.money(m * days / 30.0, true)
			var cl := _ink("%s al mes para las arcas del Estado%s." % [UI.money(m, true), acc], UI.f_sans_b, 17)
			cl.add_theme_color_override("font_color", STAMP_COLS["vigor"] if m > 0 else STAMP_COLS["rechazada"])
			_page.add_child(_wrap(cl, w))
		else:
			_page.add_child(_ink("No cambia el saldo mensual del Estado.", UI.f_sans, 16, 0.75))
		if float(law.get("fx", {}).get("money", 0.0)) != 0.0:
			_page.add_child(_ink("Pago o ingreso único al aprobarla: %s." % UI.money(float(law["fx"]["money"]), true), UI.f_sans, 16, 0.75))
		if law.has("term"):
			_page.add_child(_wrap(_ink("Amplía su mandato %d días." % int(law["term"]), UI.f_sans_b, 16, 0.85), w))
		# lo que puede echarle en cara la oposición
		var ammo := 0
		for a in DB.P.DEBATE + DB.C.DEBATE:
			if str(a.get("cond", {}).get("policy", "")) == id:
				ammo += 1
		if ammo > 0:
			_section("En el Congreso", w)
			_page.add_child(_wrap(_ink("La oposición tiene argumentos preparados contra esta ley: puede salir en la sesión de control o en el debate electoral.", UI.f_serif, 17, 0.85), w))
	else:
		_section("¿Y ahora?", w)
		var again := "Puede volver a presentarla desde la Agenda legislativa, con más apoyos negociados." if GS.law_available(id) else "Ya está en vigor o en trámite."
		_page.add_child(_wrap(_ink("El Gobierno perdió estabilidad y capital político con la derrota. " + again, UI.f_serif, 18, 0.85), w))


func _page_small(e: Dictionary, w: float) -> void:
	var ok: bool = e.get("ok", false)
	var auto: bool = e.get("auto", false)
	_head(_numbers.get(selected, "Ley menor") if ok else "Ley menor vetada", _name_of(e), w)
	var verb := "Entró en vigor sin su firma (se le pasó el plazo)" if auto and ok else ("Vetada" if not ok else "Sancionada con su firma")
	_page.add_child(_ink(_date_line(e, verb), UI.f_serif_k, 17, 0.75))
	var desc := str(e.get("desc", ""))
	if desc != "":
		_page.add_child(_wrap(_ink(desc, UI.f_serif, 18, 0.85), w))
	_section("Efectos al firmarla" if ok else "Efectos del veto", w)
	_page.add_child(_ink_chips(GS.preview(e.get("fx", {})), w))
	var rider := str(e.get("rider", ""))
	_section("La letra pequeña", w)
	if rider == "":
		_page.add_child(_ink("Sin anexos ni sorpresas.", UI.f_serif_k, 17, 0.7))
		return
	var rl := _wrap(_ink("«%s»" % rider, UI.f_type, 17, 0.9), w)
	_page.add_child(rl)
	var rfx: Dictionary = e.get("rfx", {})
	if ok:
		_page.add_child(_ink("Lo que de verdad hacía el anexo (ya aplicado):", UI.f_sans_b, 15, 0.8))
		_page.add_child(_ink_chips(GS.preview(rfx), w))
		if float(rfx.get("corr", 0.0)) > 0.0:
			_page.add_child(_ink("Además, olía a corrupción.", UI.f_sans_b, 15, 1.0))
	else:
		_page.add_child(_wrap(_ink("Al vetarla se libró de este anexo.", UI.f_serif_k, 17, 0.75), w))


func on_escape() -> void:
	close()
