extends RefCounted
## Fábrica de componentes de interfaz reutilizables.

const W := preload("res://scripts/data/world_data.gd")


static func chip(icon_name: String, text: String, col: Color, size: int = 17) -> PanelContainer:
	var p := PanelContainer.new()
	var st := UI.sb(Color(col, 0.14), 5, Color(col, 0.55), 1)
	st.content_margin_left = 7
	st.content_margin_right = 8
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := UI.hbox(5)
	if icon_name != "":
		h.add_child(UI.icon_rect(icon_name, size, col))
	var l := UI.lbl(text, UI.f_sans_m, size - 1, col.lightened(0.25))
	h.add_child(l)
	p.add_child(h)
	return p


static func arrows(v: float) -> String:
	var ch := "▲" if v > 0 else "▼"
	# En difícil solo se conoce la dirección del efecto, no su tamaño
	if GS.difficulty >= 2:
		return ch
	var n := 1
	var a := absf(v)
	if a >= 7.0:
		n = 3
	elif a >= 3.0:
		n = 2
	return ch.repeat(n)


## Etiqueta "consejo del gabinete" (modo fácil)
static func advice_tag() -> Control:
	var h := UI.hbox(6)
	h.add_child(UI.spacer(32, 0))
	h.add_child(UI.icon_rect("check", 16, UI.GREEN))
	h.add_child(UI.lbl("Consejo del gabinete: la opción más favorable para su electorado", UI.f_sans_b, 14, UI.GREEN))
	return h



static func effect_chips(items: Array, size: int = 17, max_items: int = 8) -> HFlowContainer:
	var box := HFlowContainer.new()
	box.add_theme_constant_override("h_separation", 6)
	box.add_theme_constant_override("v_separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := 0
	for it in items:
		if n >= max_items:
			break
		var k: String = it["k"]
		var v: float = it["v"]
		var c: Control = null
		match k:
			"money":
				c = chip("dinero", UI.money(v, true), UI.GREEN if v > 0 else UI.RED, size)
			"monthly":
				c = chip("dinero", UI.money(v, true) + "/mes", UI.GREEN if v > 0 else UI.RED, size)
			"pc":
				c = chip("capital", UI.signed(v) + " CP", UI.GOLD_L if v > 0 else UI.RED, size)
			"risk":
				c = chip("alerta", "Riesgo · %d%%" % int(v * 100), UI.AMBER, size)
			"nego":
				c = chip("mediador", "Negociación", UI.BLUE, size)
			"speech":
				c = chip("microfono", "Discurso", UI.BLUE, size)
			"debate":
				c = chip("mediador", "Debate en directo", UI.BLUE, size)
			"press":
				c = chip("prensa", "Comparecencia ante la prensa", UI.BLUE, size)
			"control":
				c = chip("mazo", "Sesión de control", UI.BLUE, size)
			"crisis":
				c = chip("alerta", "Crisis", UI.RED, size)
			_:
				if absf(v) < 0.5:
					continue
				var good := v > 0
				c = chip(GS.icon_of(k), "%s %s" % [GS.label_of(k), arrows(v)], UI.GREEN if good else UI.RED, size)
		if c != null:
			var exact := not (k in ["risk", "nego", "speech", "debate", "press", "crisis", "control"])
			if GS.difficulty >= 2 and not (k in ["money", "monthly", "pc"]):
				c.tooltip_text = "%s: efecto aproximado (en difícil no se conoce la cifra exacta)" % GS.label_of(k) if exact else ""
			else:
				c.tooltip_text = "%s: %s" % [GS.label_of(k), UI.signed(v, 0)] if exact else ""
			box.add_child(c)
			n += 1
	return box


static func click_card(content: Control, on_click: Callable, pad: int = 16, bg: Color = Color(0.08, 0.12, 0.19, 0.95), border: Color = Color(1, 1, 1, 0.1)) -> PanelContainer:
	var card := PanelContainer.new()
	var st := UI.sb(bg, 8, border, 1 if border.a < 0.5 else 2, 0, pad)
	var sth := UI.sb(bg.lightened(0.08), 8, UI.GOLD, 1, 0, pad)
	card.add_theme_stylebox_override("panel", st)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_child(content)
	card.set_meta("enabled", true)
	card.mouse_entered.connect(func():
		if card.get_meta("enabled"):
			card.add_theme_stylebox_override("panel", sth)
			Sfx.play("hover", -10.0))
	card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", st))
	card.gui_input.connect(func(e):
		if card.get_meta("enabled") and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Sfx.play("click", -3.0)
			on_click.call())
	return card


static func section(text: String, size: int = 14) -> Control:
	var h := UI.hbox(12)
	var l := UI.lbl(text.to_upper(), UI.f_sans_b, size, UI.GOLD)
	h.add_child(l)
	var line := ColorRect.new()
	line.color = Color(UI.GOLD, 0.35)
	line.custom_minimum_size = Vector2(10, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(line)
	return h


static func bar(value: float, width: float, height: float, col: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(1, 1, 1, 0.08))
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(c.size.x * clampf(value / 100.0, 0.0, 1.0), c.size.y)), col))
	return c


static func draw_line_chart(ci: CanvasItem, r: Rect2, series: Array, col: Color, lo: float, hi: float, width: float = 2.5, fill: bool = true) -> void:
	if series.size() < 2:
		return
	var pts := PackedVector2Array()
	for i in series.size():
		var x := r.position.x + r.size.x * i / float(series.size() - 1)
		var y := r.position.y + r.size.y * (1.0 - clampf((float(series[i]) - lo) / maxf(0.001, hi - lo), 0.0, 1.0))
		pts.append(Vector2(x, y))
	if fill:
		var poly := PackedVector2Array(pts)
		poly.append(Vector2(r.end.x, r.end.y))
		poly.append(Vector2(r.position.x, r.end.y))
		var cols := PackedColorArray()
		for p in poly:
			var t := (p.y - r.position.y) / maxf(1.0, r.size.y)
			cols.append(Color(col, 0.28 * (1.0 - t)))
		ci.draw_polygon(poly, cols)
	ci.draw_polyline(pts, col, width, true)
	ci.draw_circle(pts[pts.size() - 1], width * 1.6, col)
