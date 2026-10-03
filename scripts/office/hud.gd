extends Control
## Barra superior de información: fecha, velocidad, indicadores, facciones y aprobación.
## Estilo de despacho clásico: madera de nogal, filetes de latón y tipografía con serifa.

signal menu_pressed

const W := preload("res://scripts/data/world_data.gd")
const OfficeArt := preload("res://scripts/office/office_art.gd")

const BAR_H := 64.0
const STRIP_H := 36.0
const METER_X := 610.0
const METER_W := 122.0

## Paleta del despacho
const WOOD_T := Color("2b1b10")
const WOOD_B := Color("1a100a")
const LEATHER_T := Color("173024")
const LEATHER_B := Color("10221a")
const BRASS := Color("c29a55")
const BRASS_L := Color("e9cd92")
const BRASS_D := Color("7d5f2e")
const PARCH := Color("efe3c6")
const PARCH_DIM := Color("bba985")
const GOOD := Color("9cbf6e")
const MID := Color("e0aa52")
const BAD := Color("d0604f")

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
		b.position = Vector2(388 + i * 44, 6)
		b.size = Vector2(40, 32)
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
	mb.modulate = BRASS_L
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
		b.modulate = BRASS_L if on else Color(PARCH_DIM, 0.85)
		var st := UI.sb(Color(BRASS, 0.28) if on else Color(0, 0, 0, 0.22), 5, BRASS if on else Color(BRASS_D, 0.6), 1)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", UI.sb(Color(BRASS, 0.35), 5, BRASS_L, 1))
		b.add_theme_stylebox_override("pressed", st)


## Color apagado según el valor (oliva / ocre / burdeos)
static func tone(v: float) -> Color:
	if v >= 55.0:
		return GOOD
	if v >= 40.0:
		return MID
	return BAD


func _on_stats() -> void:
	for m in GS.METERS:
		var v: float = GS.meters.get(m, 50.0)
		var t: float = GS.mtarget.get(m, v)
		var arrow := "estable"
		if t > v + 2.0:
			arrow = "mejorando"
		elif t < v - 2.0:
			arrow = "empeorando"
		if GS.difficulty >= 2:
			arrow = "tendencia desconocida en difícil"
		if _hot.has(m):
			_hot[m].tooltip_text = "%s: %s/100 (%s)\n%s" % [W.METER_INFO[m]["name"], UI.num(v, 0), arrow, W.METER_INFO[m]["desc"]]
	for f in GS.FACTIONS:
		if _hot.has(f):
			_hot[f].tooltip_text = "%s: %s%% satisfechos\n%s" % [W.FACTION_INFO[f]["name"], UI.num(GS.fac[f], 0), W.FACTION_INFO[f]["desc"]]
	if _hot.has("debt"):
		_hot["debt"].tooltip_text = "Deuda pública: %s del PIB (%s)\nIngresos: %s/mes · Gastos: %s/mes · Intereses: %s/mes\nSaldo mensual: %s\nPIB: %s · Crecimiento: %s · Paro: %s\nQuiebra si la deuda supera el %s del PIB." % [UI.pct(GS.debt_ratio()), UI.money(GS.debt), UI.money(GS.revenue()), UI.money(GS.spending()), UI.money(GS.interest()), UI.money(GS.monthly_balance(), true), UI.money(GS.gdp), UI.pct(GS.growth()), UI.pct(GS.unemployment()), UI.pct(GS.bankruptcy_limit(), 0)]
		var risk := _scandal_risk()
		_hot["pc"].tooltip_text = "Capital político: %s\nSe gana cada mes según aprobación y estabilidad.\nSe gasta en leyes, presiones y decretos.%s" % [UI.num(GS.pc, 0), ("\n\nRiesgo de escándalo: %s. Las decisiones turbias acaban saliendo a la luz." % risk) if risk != "" else ""]
		_hot["approval"].tooltip_text = "Aprobación: %s%%\nMedia ponderada de la satisfacción de los grupos sociales.\nSi cae por debajo del 15%% durante dos meses, caerá el Gobierno.%s" % [UI.num(GS.approval, 1), ("\n%s legislatura · %s años en el poder" % [GS.ordinal(GS.term_index).capitalize(), UI.num(float(GS.day) / 365.0, 1)]) if GS.mode == "infinito" else ""]


## "" si no hay riesgo apreciable (en difícil nunca se muestra)
func _scandal_risk() -> String:
	if GS.difficulty >= 2:
		return ""
	if GS.corruption >= 22.0:
		return "muy alto"
	if GS.corruption >= 14.0:
		return "alto"
	if GS.corruption >= 8.0:
		return "moderado"
	return ""


func _on_deltas(items: Array) -> void:
	for it in items:
		_flash[it["k"]] = 1.0


func anchor_for(key: String) -> Vector2:
	var i := GS.METERS.find(key)
	if i >= 0:
		return global_position + Vector2(METER_X + i * METER_W + 50, BAR_H + STRIP_H + 18)
	i = GS.FACTIONS.find(key)
	if i >= 0:
		return global_position + Vector2(1920.0 / 6.0 * (i + 0.5) + 60, BAR_H + STRIP_H + 18)
	match key:
		"money", "monthly":
			return global_position + Vector2(1446, BAR_H + STRIP_H + 18)
		"pc":
			return global_position + Vector2(1606, BAR_H + STRIP_H + 18)
		"approval":
			return global_position + Vector2(1766, BAR_H + STRIP_H + 18)
	return global_position + Vector2(1600, 150)


func _process(delta: float) -> void:
	_t += delta
	for k in _flash.keys():
		_flash[k] = maxf(0.0, _flash[k] - delta * 0.8)
	queue_redraw()


func _draw() -> void:
	if not GS.active and GS.day == 0 and GS.meters.is_empty():
		return
	var hard := GS.difficulty >= 2
	# --- franja de madera
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1920, 0), Vector2(1920, BAR_H), Vector2(0, BAR_H)]),
		PackedColorArray([WOOD_T, WOOD_T, WOOD_B, WOOD_B]))
	for i in 9:
		var y := 4.0 + i * 7.0 + sin(i * 2.3) * 2.0
		var pts := PackedVector2Array()
		for k in 25:
			pts.append(Vector2(k * 80.0, y + sin(k * 0.7 + i * 1.3) * 1.6))
		draw_polyline(pts, Color(0, 0, 0, 0.12 + 0.05 * (i % 2)), 1.0)
	draw_rect(Rect2(0, 0, 1920, 1), Color(BRASS_L, 0.25))
	# --- franja de cuero verde (grupos sociales)
	draw_polygon(PackedVector2Array([Vector2(0, BAR_H), Vector2(1920, BAR_H), Vector2(1920, BAR_H + STRIP_H), Vector2(0, BAR_H + STRIP_H)]),
		PackedColorArray([LEATHER_T, LEATHER_T, LEATHER_B, LEATHER_B]))
	# filetes de latón (doble línea, como el cuero repujado del escritorio)
	draw_rect(Rect2(0, BAR_H - 2, 1920, 2), BRASS)
	draw_rect(Rect2(0, BAR_H, 1920, 1), Color(BRASS_L, 0.45))
	draw_rect(Rect2(0, BAR_H + 4, 1920, 1), Color(BRASS, 0.25))
	draw_rect(Rect2(0, BAR_H + STRIP_H - 5, 1920, 1), Color(BRASS, 0.25))
	draw_rect(Rect2(0, BAR_H + STRIP_H - 1, 1920, 2), BRASS_D)
	for i in 6:
		draw_rect(Rect2(0, BAR_H + STRIP_H + 1 + i, 1920, 1), Color(0, 0, 0, 0.3 - i * 0.05))
	# separadores de latón con remaches
	for x in [376.0, 596.0, 1342.0]:
		_brass_divider(x)
	# --- sello y fecha
	draw_texture_rect(_seal, Rect2(12, 4, 56, 56), false)
	draw_string(UI.f_sans_b, Vector2(74, 22), "PRESIDENCIA DE LA REPÚBLICA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, BRASS)
	draw_string(UI.f_num, Vector2(74, 48), UI.date_long(GS.day), HORIZONTAL_ALIGNMENT_LEFT, 300, 19, PARCH)
	# progreso del día
	draw_rect(Rect2(388, 45, 172, 2), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(388, 45, 172 * GS.day_progress(), 2), BRASS)
	var left := GS.term_days - GS.day
	var etxt := ("Elecciones en %d días" % left) if left > 0 else "Jornada electoral"
	if GS.mode == "infinito":
		etxt = "%s legislatura · %s" % [GS.ordinal(GS.term_index).capitalize(), etxt.to_lower()]
	draw_string(UI.f_num_r, Vector2(388, 58), etxt, HORIZONTAL_ALIGNMENT_LEFT, 205, 11, BRASS_L if left < 60 else PARCH_DIM)
	# --- indicadores
	for i in GS.METERS.size():
		var m: String = GS.METERS[i]
		var x := METER_X + i * METER_W
		var v: float = GS.meters[m]
		var t: float = GS.mtarget.get(m, v)
		var col := tone(v)
		var fl: float = _flash.get(m, 0.0)
		if fl > 0.0:
			draw_rect(Rect2(x - 4, 3, METER_W - 4, 58), Color(BRASS_L, fl * 0.12))
		draw_texture_rect(UI.icon(W.METER_INFO[m]["icon"], 40), Rect2(x, 9, 18, 18), false, Color(BRASS_L, 0.9))
		draw_string(UI.f_serif, Vector2(x + 24, 22), W.METER_INFO[m]["name"], HORIZONTAL_ALIGNMENT_LEFT, METER_W - 28, 12, PARCH_DIM)
		draw_string(UI.f_num, Vector2(x + 2, 46), UI.num(v, 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, PARCH)
		if not hard:
			var arrow := ""
			var acol := PARCH_DIM
			if t > v + 2.0:
				arrow = "▲"
				acol = GOOD
			elif t < v - 2.0:
				arrow = "▼"
				acol = BAD
			draw_string(UI.f_sans_b, Vector2(x + 34, 44), arrow, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, acol)
		_gauge(Rect2(x + 52, 36, METER_W - 66, 6), v, col, -1.0 if hard else t)
	# --- deuda
	var dx := 1356.0
	var dr := GS.debt_ratio()
	var dcol := GOOD if dr < 90.0 else (MID if dr < 115.0 else BAD)
	var mf := maxf(_flash.get("money", 0.0), _flash.get("monthly", 0.0))
	if mf > 0.0:
		draw_rect(Rect2(dx - 6, 3, 190, 58), Color(BRASS_L, mf * 0.12))
	draw_texture_rect(UI.icon("dinero", 40), Rect2(dx, 9, 18, 18), false, Color(BRASS_L, 0.9))
	draw_string(UI.f_serif, Vector2(dx + 24, 22), "Deuda / PIB", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PARCH_DIM)
	draw_string(UI.f_num, Vector2(dx + 2, 45), UI.pct(dr), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, dcol.lightened(0.15))
	var bal := GS.monthly_balance()
	draw_string(UI.f_num_r, Vector2(dx + 2, 57), "Saldo " + UI.money(bal, true) + "/mes", HORIZONTAL_ALIGNMENT_LEFT, 180, 11, GOOD if bal >= 0 else BAD)
	# --- capital político
	var px := 1552.0
	draw_texture_rect(UI.icon("capital", 40), Rect2(px, 9, 18, 18), false, BRASS_L)
	draw_string(UI.f_serif, Vector2(px + 24, 22), "Capital pol.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PARCH_DIM)
	draw_string(UI.f_num, Vector2(px + 2, 45), UI.num(GS.pc, 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 23, BRASS_L)
	var risk := _scandal_risk()
	if risk != "":
		var pulse := 0.6 + 0.4 * sin(_t * 3.0) if risk == "muy alto" else 1.0
		draw_string(UI.f_sans_b, Vector2(px + 2, 57), "⚠ Escándalo: " + risk, HORIZONTAL_ALIGNMENT_LEFT, 120, 10, Color(BAD.lightened(0.15), pulse))
	# --- aprobación (placa de latón)
	var ax := 1676.0
	var ap := GS.approval
	var apc := tone(ap)
	var plate := Rect2(ax - 6, 6, 186, 52)
	draw_rect(plate, Color(0, 0, 0, 0.28 + _flash.get("approval", 0.0) * 0.15))
	draw_rect(plate, BRASS, false, 1.0)
	draw_rect(plate.grow(-3), Color(BRASS, 0.35), false, 1.0)
	for c in [plate.position + Vector2(5, 5), plate.position + Vector2(plate.size.x - 5, 5), plate.position + Vector2(5, plate.size.y - 5), plate.end - Vector2(5, 5)]:
		draw_circle(c, 1.6, BRASS_L)
	draw_string(UI.f_serif, Vector2(ax + 6, 22), "Aprobación", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PARCH_DIM)
	draw_string(UI.f_num, Vector2(ax + 4, 51), UI.num(ap, 0) + "%", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, apc.lightened(0.1))
	var hist: Array = GS.stat_hist.get("approval", [])
	if hist.size() >= 1:
		var series := hist.slice(maxi(0, hist.size() - 8))
		series.append(ap)
		var pts2 := PackedVector2Array()
		for i in series.size():
			pts2.append(Vector2(ax + 96 + 72.0 * i / maxf(1.0, series.size() - 1), 50 - float(series[i]) * 0.3))
		if pts2.size() >= 2:
			draw_polyline(pts2, Color(BRASS_L, 0.85), 1.6, true)
			draw_circle(pts2[pts2.size() - 1], 2.5, BRASS_L)
	# --- grupos sociales
	var fw := 1920.0 / 6.0
	for i in GS.FACTIONS.size():
		var f: String = GS.FACTIONS[i]
		var x2 := i * fw + 22.0
		var v2: float = GS.fac[f]
		var c2 := tone(v2)
		var fl2: float = _flash.get(f, 0.0)
		if fl2 > 0.0:
			draw_rect(Rect2(i * fw, BAR_H + 2, fw, STRIP_H - 4), Color(BRASS_L, fl2 * 0.1))
		draw_texture_rect(UI.icon(W.FACTION_INFO[f]["icon"], 36), Rect2(x2, BAR_H + 9, 17, 17), false, Color(BRASS_L, 0.85))
		draw_string(UI.f_serif, Vector2(x2 + 26, BAR_H + 24), W.FACTION_INFO[f]["name"], HORIZONTAL_ALIGNMENT_LEFT, 130, 14, PARCH)
		var bx := x2 + 154.0
		_gauge(Rect2(bx, BAR_H + 15, 96, 6), v2, c2, -1.0 if hard else float(GS.ftarget.get(f, v2)))
		draw_string(UI.f_num, Vector2(bx + 104, BAR_H + 25), UI.num(v2, 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, c2.lightened(0.15))
		if i > 0:
			draw_rect(Rect2(i * fw, BAR_H + 9, 1, STRIP_H - 18), Color(BRASS, 0.3))


## Barra fina de latón con relleno de color apagado y marca de tendencia (si target >= 0)
func _gauge(r: Rect2, v: float, col: Color, target: float) -> void:
	draw_rect(r, Color(0, 0, 0, 0.4))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(v / 100.0, 0.0, 1.0), r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(v / 100.0, 0.0, 1.0), 1)), Color(1, 1, 1, 0.18))
	draw_rect(r, Color(BRASS_D, 0.9), false, 1.0)
	if target >= 0.0:
		var tx := r.position.x + r.size.x * clampf(target / 100.0, 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(tx - 3, r.position.y - 4), Vector2(tx + 3, r.position.y - 4), Vector2(tx, r.position.y)]), BRASS_L)


func _brass_divider(x: float) -> void:
	draw_rect(Rect2(x, 8, 1, BAR_H - 16), Color(BRASS, 0.5))
	draw_rect(Rect2(x + 1, 8, 1, BAR_H - 16), Color(0, 0, 0, 0.4))
	draw_circle(Vector2(x + 0.5, 8), 2.0, BRASS_L)
	draw_circle(Vector2(x + 0.5, BAR_H - 8), 2.0, BRASS_L)
