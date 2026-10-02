extends Control
## Barra superior de información: fecha, velocidad, indicadores, facciones y aprobación.

signal menu_pressed

const W := preload("res://scripts/data/world_data.gd")
const OfficeArt := preload("res://scripts/office/office_art.gd")

const BAR_H := 64.0
const STRIP_H := 36.0
const METER_X := 610.0
const METER_W := 122.0

var _speed_btns := []
var _flash := {}
var _prev := {}
var _t := 0.0
var _seal: Texture2D
var _hot := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1920, BAR_H + STRIP_H)
	_seal = OfficeArt.tex("seal", 0.5)
	var icons := ["pausa", "play", "ff", "fff"]
	var tips := ["Pausa (Espacio)", "Velocidad normal (1)", "Rápido (2)", "Muy rápido (3)"]
	for i in 4:
		var b := Button.new()
		b.icon = UI.icon(icons[i], 36)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(40, 34)
		b.size = Vector2(40, 34)
		b.position = Vector2(388 + i * 44, 10)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = tips[i]
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_constant_override("icon_max_width", 18)
		var idx := i
		b.pressed.connect(func():
			Sfx.play("click", -4.0)
			GS.set_speed(idx))
		add_child(b)
		_speed_btns.append(b)
	var mb := Button.new()
	mb.icon = UI.icon("ajustes", 36)
	mb.add_theme_constant_override("icon_max_width", 22)
	mb.position = Vector2(1868, 12)
	mb.size = Vector2(42, 40)
	mb.focus_mode = Control.FOCUS_NONE
	mb.tooltip_text = "Menú (Esc)"
	mb.flat = true
	mb.pressed.connect(func(): menu_pressed.emit())
	add_child(mb)
	# zonas con tooltip
	for i in GS.METERS.size():
		var m: String = GS.METERS[i]
		_hotspot(m, Rect2(METER_X + i * METER_W, 4, METER_W - 6, 56))
	_hotspot("debt", Rect2(1352, 4, 190, 56))
	_hotspot("pc", Rect2(1548, 4, 118, 56))
	_hotspot("approval", Rect2(1672, 4, 190, 56))
	var fw := 1920.0 / 6.0
	for i in GS.FACTIONS.size():
		_hotspot(GS.FACTIONS[i], Rect2(i * fw, BAR_H, fw, STRIP_H))
	GS.speed_changed.connect(_on_speed)
	GS.stats_changed.connect(_on_stats)
	GS.deltas.connect(_on_deltas)
	_refresh_speed()
	_on_stats()


func _hotspot(key: String, r: Rect2) -> void:
	var c := Control.new()
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(c)
	_hot[key] = c


func _on_speed(_s: int) -> void:
	_refresh_speed()


func _refresh_speed() -> void:
	for i in _speed_btns.size():
		var b: Button = _speed_btns[i]
		var on := GS.speed == i
		b.modulate = UI.GOLD_L if on else Color(0.75, 0.78, 0.85)
		var st := UI.sb(Color(UI.GOLD, 0.22) if on else Color(1, 1, 1, 0.04), 6, UI.GOLD if on else Color(1, 1, 1, 0.1), 1)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", UI.sb(Color(UI.GOLD, 0.3), 6, UI.GOLD, 1))


func _on_stats() -> void:
	for m in GS.METERS:
		var v: float = GS.meters.get(m, 50.0)
		var t: float = GS.mtarget.get(m, v)
		var arrow := "estable"
		if t > v + 2.0:
			arrow = "mejorando"
		elif t < v - 2.0:
			arrow = "empeorando"
		if _hot.has(m):
			_hot[m].tooltip_text = "%s: %s/100 (%s)\n%s" % [W.METER_INFO[m]["name"], UI.num(v, 0), arrow, W.METER_INFO[m]["desc"]]
	for f in GS.FACTIONS:
		if _hot.has(f):
			_hot[f].tooltip_text = "%s: %s%% satisfechos\n%s" % [W.FACTION_INFO[f]["name"], UI.num(GS.fac[f], 0), W.FACTION_INFO[f]["desc"]]
	if _hot.has("debt"):
		_hot["debt"].tooltip_text = "Deuda pública: %s del PIB (%s)\nIngresos: %s/mes · Gastos: %s/mes · Intereses: %s/mes\nSaldo mensual: %s\nPIB: %s · Crecimiento: %s · Paro: %s" % [UI.pct(GS.debt_ratio()), UI.money(GS.debt), UI.money(GS.revenue()), UI.money(GS.spending()), UI.money(GS.interest()), UI.money(GS.monthly_balance(), true), UI.money(GS.gdp), UI.pct(GS.growth()), UI.pct(GS.unemployment())]
		_hot["pc"].tooltip_text = "Capital político: %s\nSe gana cada mes según aprobación y estabilidad.\nSe gasta en leyes, presiones y decretos." % UI.num(GS.pc, 0)
		_hot["approval"].tooltip_text = "Aprobación: %s%%\nMedia ponderada de la satisfacción de los grupos sociales.\nSi cae por debajo del 15%% durante dos meses, caerá el Gobierno." % UI.num(GS.approval, 1)


func _on_deltas(items: Array) -> void:
	for it in items:
		_flash[it["k"]] = 1.0


func anchor_for(key: String) -> Vector2:
	var i := GS.METERS.find(key)
	if i >= 0:
		return global_position + Vector2(METER_X + i * METER_W + 60, 50)
	i = GS.FACTIONS.find(key)
	if i >= 0:
		return global_position + Vector2(1920.0 / 6.0 * (i + 0.5), BAR_H + 26)
	match key:
		"money", "monthly":
			return global_position + Vector2(1446, 52)
		"pc":
			return global_position + Vector2(1606, 52)
		"approval":
			return global_position + Vector2(1766, 52)
	return global_position + Vector2(1600, 150)


func _process(delta: float) -> void:
	_t += delta
	for k in _flash.keys():
		_flash[k] = maxf(0.0, _flash[k] - delta * 0.8)
	queue_redraw()


func _draw() -> void:
	if not GS.active and GS.day == 0 and GS.meters.is_empty():
		return
	# fondo
	var bg := PackedVector2Array([Vector2(0, 0), Vector2(1920, 0), Vector2(1920, BAR_H), Vector2(0, BAR_H)])
	draw_polygon(bg, PackedColorArray([Color(0.035, 0.05, 0.085, 0.96), Color(0.035, 0.05, 0.085, 0.96), Color(0.06, 0.08, 0.13, 0.96), Color(0.06, 0.08, 0.13, 0.96)]))
	draw_rect(Rect2(0, BAR_H, 1920, STRIP_H), Color(0.02, 0.03, 0.05, 0.82))
	draw_rect(Rect2(0, BAR_H - 1, 1920, 1), Color(UI.GOLD, 0.55))
	draw_rect(Rect2(0, BAR_H + STRIP_H, 1920, 1), Color(UI.GOLD, 0.25))
	for i in 6:
		draw_rect(Rect2(0, BAR_H + STRIP_H + 1 + i, 1920, 1), Color(0, 0, 0, 0.25 - i * 0.04))
	# sello y fecha
	draw_texture_rect(_seal, Rect2(12, 4, 56, 56), false)
	draw_string(UI.f_sans_b, Vector2(74, 24), "PRESIDENCIA DE LA REPÚBLICA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.GOLD)
	draw_string(UI.f_serif_b, Vector2(74, 50), UI.date_long(GS.day), HORIZONTAL_ALIGNMENT_LEFT, 300, 19, UI.TEXT)
	# progreso del día
	draw_rect(Rect2(388, 50, 172, 3), Color(1, 1, 1, 0.1))
	draw_rect(Rect2(388, 50, 172 * GS.day_progress(), 3), UI.GOLD)
	var left := GS.term_days - GS.day
	draw_string(UI.f_sans_m, Vector2(388, 62), "Elecciones en %d días" % maxi(0, left) if left > 0 else "Jornada electoral", HORIZONTAL_ALIGNMENT_LEFT, 180, 10, UI.GOLD_L if left < 60 else UI.DIM)
	# indicadores
	for i in GS.METERS.size():
		var m: String = GS.METERS[i]
		var x := METER_X + i * METER_W
		var v: float = GS.meters[m]
		var t: float = GS.mtarget.get(m, v)
		var col := UI.color_for(v)
		var fl: float = _flash.get(m, 0.0)
		if fl > 0.0:
			draw_rect(Rect2(x - 4, 4, METER_W - 4, 56), Color(1, 1, 1, fl * 0.08))
		draw_texture_rect(UI.icon(W.METER_INFO[m]["icon"], 40), Rect2(x, 12, 20, 20), false, col)
		draw_string(UI.f_sans_b, Vector2(x + 26, 20), W.METER_INFO[m]["name"].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, METER_W - 30, 9, UI.DIM)
		draw_string(UI.f_cond_b, Vector2(x + 26, 40), UI.num(v, 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, UI.TEXT)
		var arrow := ""
		var acol := UI.DIM
		if t > v + 2.0:
			arrow = "▲"
			acol = UI.GREEN
		elif t < v - 2.0:
			arrow = "▼"
			acol = UI.RED
		draw_string(UI.f_sans_b, Vector2(x + 58, 38), arrow, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, acol)
		var bw := METER_W - 18.0
		draw_rect(Rect2(x, 48, bw, 4), Color(1, 1, 1, 0.1))
		draw_rect(Rect2(x, 48, bw * v / 100.0, 4), col)
		draw_rect(Rect2(x + bw * clampf(t, 0, 100) / 100.0 - 1, 45, 2, 10), Color(1, 1, 1, 0.7))
	# deuda
	var dx := 1352.0
	var dr := GS.debt_ratio()
	var dcol := UI.GREEN if dr < 90.0 else (UI.AMBER if dr < 115.0 else UI.RED)
	if _flash.get("money", 0.0) > 0.0 or _flash.get("monthly", 0.0) > 0.0:
		draw_rect(Rect2(dx - 4, 4, 190, 56), Color(1, 1, 1, maxf(_flash.get("money", 0.0), _flash.get("monthly", 0.0)) * 0.08))
	draw_texture_rect(UI.icon("dinero", 40), Rect2(dx, 12, 20, 20), false, dcol)
	draw_string(UI.f_sans_b, Vector2(dx + 26, 20), "DEUDA / PIB", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.DIM)
	draw_string(UI.f_cond_b, Vector2(dx + 26, 40), UI.pct(dr), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, UI.TEXT)
	var bal := GS.monthly_balance()
	draw_string(UI.f_sans_m, Vector2(dx, 58), "Saldo " + UI.money(bal, true) + "/mes", HORIZONTAL_ALIGNMENT_LEFT, 186, 11, UI.GREEN if bal >= 0 else UI.RED)
	# capital político
	var px := 1552.0
	draw_texture_rect(UI.icon("capital", 40), Rect2(px, 12, 20, 20), false, UI.GOLD_L)
	draw_string(UI.f_sans_b, Vector2(px + 26, 20), "CAPITAL POL.", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.DIM)
	draw_string(UI.f_cond_b, Vector2(px + 26, 42), UI.num(GS.pc, 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.GOLD_L)
	# aprobación
	var ax := 1676.0
	var ap := GS.approval
	var apc := UI.color_for(ap)
	draw_rect(Rect2(ax - 6, 6, 186, 52), Color(apc, 0.08 + _flash.get("approval", 0.0) * 0.1))
	draw_rect(Rect2(ax - 6, 6, 3, 52), apc)
	draw_string(UI.f_sans_b, Vector2(ax + 4, 20), "APROBACIÓN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI.DIM)
	draw_string(UI.f_cond_b, Vector2(ax + 4, 54), UI.num(ap, 0) + "%", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, apc)
	var hist: Array = GS.stat_hist.get("approval", [])
	if hist.size() >= 1:
		var series := hist.slice(maxi(0, hist.size() - 8))
		series.append(ap)
		var pts := PackedVector2Array()
		for i in series.size():
			pts.append(Vector2(ax + 92 + 80.0 * i / maxf(1.0, series.size() - 1), 50 - float(series[i]) * 0.3))
		if pts.size() >= 2:
			draw_polyline(pts, Color(apc, 0.8), 2.0, true)
	# facciones
	var fw := 1920.0 / 6.0
	for i in GS.FACTIONS.size():
		var f: String = GS.FACTIONS[i]
		var x2 := i * fw + 20.0
		var v2: float = GS.fac[f]
		var c2 := UI.color_for(v2)
		var fl2: float = _flash.get(f, 0.0)
		if fl2 > 0.0:
			draw_rect(Rect2(i * fw, BAR_H, fw, STRIP_H), Color(1, 1, 1, fl2 * 0.08))
		draw_texture_rect(UI.icon(W.FACTION_INFO[f]["icon"], 36), Rect2(x2, BAR_H + 9, 18, 18), false, c2)
		draw_string(UI.f_sans_m, Vector2(x2 + 26, BAR_H + 23), W.FACTION_INFO[f]["name"], HORIZONTAL_ALIGNMENT_LEFT, 130, 13, UI.TEXT)
		var bx := x2 + 150.0
		draw_rect(Rect2(bx, BAR_H + 15, 100, 6), Color(1, 1, 1, 0.1))
		draw_rect(Rect2(bx, BAR_H + 15, v2, 6), c2)
		var ft: float = GS.ftarget.get(f, v2)
		draw_rect(Rect2(bx + clampf(ft, 0, 100) - 1, BAR_H + 12, 2, 12), Color(1, 1, 1, 0.6))
		draw_string(UI.f_cond_b, Vector2(bx + 106, BAR_H + 24), UI.num(v2, 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, c2)
		if i > 0:
			draw_rect(Rect2(i * fw, BAR_H + 8, 1, 20), Color(1, 1, 1, 0.08))
