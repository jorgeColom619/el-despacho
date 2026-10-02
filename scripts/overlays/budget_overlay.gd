extends "res://scripts/ui/overlay.gd"
## Presupuestos Generales: gasto por partidas e impuestos, con proyección en tiempo real.

const Widgets := preload("res://scripts/ui/widgets.gd")
const W := preload("res://scripts/data/world_data.gd")

var budget := {}
var taxes := {}
var sliders := {}
var val_lbls := {}
var proj: Control
var faces: Control
var preview_f := {}
var preview_m := {}


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.93)
	budget = GS.budget.duplicate()
	taxes = GS.taxes.duplicate()
	var head := title_bar("Presupuestos Generales del Estado", "Ministerio de Hacienda · Ejercicio %d" % UI.date_dict(GS.day)["year"], "dinero")
	head.position = Vector2(80, 120)
	root.add_child(head)
	var book := Panel.new()
	book.add_theme_stylebox_override("panel", UI.sb(Color("2a140c"), 14, Color("8a6a2c"), 2, 30))
	book.position = Vector2(70, 210)
	book.size = Vector2(1780, 790)
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(book)
	var left := Panel.new()
	left.add_theme_stylebox_override("panel", UI.sb(Color("efe5cf"), 6))
	left.position = Vector2(96, 234)
	left.size = Vector2(860, 742)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)
	var rightp := Panel.new()
	rightp.add_theme_stylebox_override("panel", UI.sb(Color("efe5cf"), 6))
	rightp.position = Vector2(964, 234)
	rightp.size = Vector2(860, 742)
	rightp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rightp)
	var ink := Color("2b2319")
	var lv := UI.vbox(6)
	lv.position = Vector2(126, 254)
	lv.size = Vector2(800, 700)
	root.add_child(lv)
	lv.add_child(UI.lbl("GASTO PÚBLICO MENSUAL POR PARTIDAS", UI.f_sans_b, 14, Color(ink, 0.7)))
	for k in W.BUDGET.keys():
		lv.add_child(_row(k, W.BUDGET[k]["name"], W.BUDGET[k]["icon"], 0.6, 1.5, budget[k], true))
	lv.add_child(UI.spacer(0, 8))
	lv.add_child(UI.lbl("IMPUESTOS", UI.f_sans_b, 14, Color(ink, 0.7)))
	for t in W.TAXES.keys():
		lv.add_child(_row(t, W.TAXES[t]["name"], "dinero", W.TAXES[t]["min"], W.TAXES[t]["max"], taxes[t], false))
	var rv := UI.vbox(12)
	rv.position = Vector2(994, 254)
	rv.size = Vector2(800, 700)
	root.add_child(rv)
	rv.add_child(UI.lbl("PROYECCIÓN", UI.f_sans_b, 14, Color(ink, 0.7)))
	proj = Control.new()
	proj.custom_minimum_size = Vector2(800, 300)
	proj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proj.draw.connect(_draw_proj)
	rv.add_child(proj)
	rv.add_child(UI.lbl("REACCIÓN PREVISTA", UI.f_sans_b, 14, Color(ink, 0.7)))
	faces = Control.new()
	faces.custom_minimum_size = Vector2(800, 200)
	faces.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faces.draw.connect(_draw_faces)
	rv.add_child(faces)
	var bh := UI.hbox(12)
	rv.add_child(bh)
	var cancel := UI.btn("Cerrar sin cambios", "ghost", 17)
	cancel.add_theme_color_override("font_color", ink)
	cancel.pressed.connect(func(): close())
	bh.add_child(cancel)
	bh.add_child(UI.spacer(0, 0, true))
	var dec := UI.btn("Aprobar por decreto (25 CP)", "normal", 17)
	dec.tooltip_text = "Evita el Congreso, pero cuesta capital político y estabilidad."
	dec.disabled = GS.pc < 25
	dec.pressed.connect(_decree)
	bh.add_child(dec)
	var cong := UI.btn("Presentar al Congreso", "gold", 18)
	cong.pressed.connect(_to_congress)
	bh.add_child(cong)
	_recalc()


func _row(key: String, label: String, icon_name: String, lo: float, hi: float, val: float, is_budget: bool) -> Control:
	var ink := Color("2b2319")
	var h := UI.hbox(12)
	h.add_child(UI.icon_rect(icon_name, 22, ink))
	var l := UI.lbl(label, UI.f_sans_m, 17, ink)
	l.custom_minimum_size = Vector2(250, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05 if is_budget else 0.5
	s.value = val
	s.custom_minimum_size = Vector2(300, 26)
	s.focus_mode = Control.FOCUS_NONE
	h.add_child(s)
	var vl := UI.lbl("", UI.f_cond_b, 18, ink)
	vl.custom_minimum_size = Vector2(190, 0)
	h.add_child(vl)
	sliders[key] = s
	val_lbls[key] = vl
	s.value_changed.connect(func(v):
		if is_budget:
			budget[key] = v
		else:
			taxes[key] = v
		_recalc())
	return h


func _recalc() -> void:
	for k in W.BUDGET.keys():
		var m: float = budget[k]
		val_lbls[k].text = "%s  (%s%%)" % [UI.money(W.BUDGET[k]["base"] * m), UI.signed((m - 1.0) * 100.0, 0)]
		val_lbls[k].add_theme_color_override("font_color", Color("2b2319") if absf(m - 1.0) < 0.01 else (Color("25704a") if m > 1.0 else Color("8e2a22")))
	for t in W.TAXES.keys():
		val_lbls[t].text = "%s%%" % UI.num(taxes[t], 1)
	# vista previa: aplicar temporalmente y leer objetivos
	var ob := GS.budget.duplicate()
	var ot := GS.taxes.duplicate()
	var of := GS.ftarget.duplicate()
	var om := GS.mtarget.duplicate()
	GS.budget = budget.duplicate()
	GS.taxes = taxes.duplicate()
	GS._update_targets()
	preview_f = GS.ftarget.duplicate()
	preview_m = GS.mtarget.duplicate()
	var bal := GS.monthly_balance()
	GS.budget = ob
	GS.taxes = ot
	GS.ftarget = of
	GS.mtarget = om
	proj.set_meta("bal", bal)
	proj.queue_redraw()
	faces.queue_redraw()


func _draw_proj() -> void:
	var ink := Color("2b2319")
	var bal: float = proj.get_meta("bal", 0.0)
	var rev := 0.0
	var ob := GS.budget.duplicate()
	var ot := GS.taxes.duplicate()
	GS.budget = budget.duplicate()
	GS.taxes = taxes.duplicate()
	rev = GS.revenue()
	var sp := GS.spending()
	GS.budget = ob
	GS.taxes = ot
	var rows := [["Ingresos", UI.money(rev) + "/mes", ink], ["Gasto", UI.money(sp) + "/mes", ink], ["Intereses", UI.money(GS.interest()) + "/mes", ink], ["Saldo mensual", UI.money(bal, true), Color("25704a") if bal >= 0 else Color("8e2a22")]]
	for i in rows.size():
		proj.draw_string(UI.f_sans_m, Vector2(0, 26 + i * 32), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
		proj.draw_string(UI.f_cond_b, Vector2(0, 26 + i * 32), rows[i][1], HORIZONTAL_ALIGNMENT_RIGHT, 360, 22, rows[i][2])
	# deuda proyectada a 12 meses
	var r := Rect2(420, 10, 370, 200)
	proj.draw_rect(r, Color(0, 0, 0, 0.04))
	proj.draw_string(UI.f_sans_b, Vector2(r.position.x, r.position.y + 16), "DEUDA / PIB · PRÓXIMOS 12 MESES", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(ink, 0.7))
	var debt := GS.debt
	var gdp := GS.gdp
	var pts := []
	var now_ratio := debt / gdp * 100.0
	for m in 13:
		pts.append(debt / gdp * 100.0)
		debt -= bal
		gdp *= 1.0 + (GS.growth() + 2.0) / 1200.0
	var lo := minf(now_ratio, pts.back()) - 3.0
	var hi := maxf(now_ratio, pts.back()) + 3.0
	Widgets.draw_line_chart(proj, Rect2(r.position.x + 10, r.position.y + 30, r.size.x - 20, r.size.y - 50), pts, Color("8e2a22") if pts.back() > now_ratio else Color("25704a"), lo, hi, 3.0, true)
	proj.draw_string(UI.f_cond_b, Vector2(r.position.x + 10, r.end.y - 2), "Hoy %s%%  →  %s%%" % [UI.num(now_ratio, 1), UI.num(pts.back(), 1)], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
	proj.draw_string(UI.f_sans, Vector2(0, 170), "Con estos presupuestos, la deuda", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(ink, 0.7))
	proj.draw_string(UI.f_sans_b, Vector2(0, 192), "sube" if pts.back() > now_ratio + 0.2 else ("baja" if pts.back() < now_ratio - 0.2 else "se estabiliza"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("8e2a22") if pts.back() > now_ratio + 0.2 else Color("25704a"))


func _draw_faces() -> void:
	var ink := Color("2b2319")
	var i := 0
	for f in GS.FACTIONS:
		var d: float = preview_f.get(f, 50.0) - GS.ftarget.get(f, 50.0)
		var x := (i % 3) * 266.0
		var y := (i / 3) * 90.0
		var col := Color("25704a") if d > 0.5 else (Color("8e2a22") if d < -0.5 else Color(ink, 0.6))
		faces.draw_texture_rect(UI.icon(W.FACTION_INFO[f]["icon"], 48), Rect2(x, y + 10, 30, 30), false, col)
		faces.draw_string(UI.f_sans_m, Vector2(x + 40, y + 26), W.FACTION_INFO[f]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
		var txt := ("▲ " if d > 0.5 else ("▼ " if d < -0.5 else "= ")) + UI.signed(d, 1)
		faces.draw_string(UI.f_cond_b, Vector2(x + 40, y + 52), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
		# carita
		var c := Vector2(x + 220, y + 32)
		faces.draw_circle(c, 18, Color(col, 0.18))
		faces.draw_circle(c + Vector2(-6, -4), 2.5, ink)
		faces.draw_circle(c + Vector2(6, -4), 2.5, ink)
		var curve := clampf(d / 4.0, -1.0, 1.0) * 5.0
		faces.draw_polyline(PackedVector2Array([c + Vector2(-8, 6 - curve * 0.2), c + Vector2(0, 6 + curve), c + Vector2(8, 6 - curve * 0.2)]), ink, 2.0, true)
		i += 1


func _ideology() -> float:
	var social: float = (budget["sanidad"] + budget["educacion"] + budget["social"] + budget["pensiones"] + budget["ambiente"]) / 5.0 - 1.0
	var hard: float = (budget["defensa"] + budget["seguridad"]) / 2.0 - 1.0
	var tax: float = (taxes["renta"] - 22.0) + (taxes["sociedades"] - 25.0)
	return clampf(-social * 180.0 + hard * 120.0 - tax * 3.0, -80.0, 80.0)


func _apply() -> void:
	for k in budget.keys():
		GS.budget[k] = budget[k]
	for t in taxes.keys():
		GS.taxes[t] = taxes[t]
	GS.flags.erase("presupuesto_pendiente")
	GS._update_targets()
	GS.stats_changed.emit()


func _decree() -> void:
	if GS.pc < 25:
		return
	GS.pc -= 25
	_apply()
	GS.apply_fx({"estabilidad": -5}, "Presupuestos por decreto")
	GS.push_news("El Gobierno aprueba los presupuestos por decreto ley", 2)
	Sfx.play("stamp", -2.0)
	close()


func _to_congress() -> void:
	var desc := "Saldo mensual previsto: %s. " % UI.money(float(proj.get_meta("bal", 0.0)), true)
	var ideo := _ideology()
	desc += "Orientación: %s." % ("expansiva y social" if ideo < -15 else ("de ajuste y orden" if ideo > 15 else "continuista"))
	close()
	if main != null:
		main.call_deferred("open_overlay", "vote", {"mode": "budget", "budget": budget.duplicate(), "taxes": taxes.duplicate(), "ideo": ideo, "desc": desc})


func on_escape() -> void:
	close()
