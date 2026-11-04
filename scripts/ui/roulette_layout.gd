extends Control
## El paño de la ruleta: los 37 números, las apuestas exteriores y dos casillas impresas (repetir y borrar). Se usa
## como pantalla con ratón sobre la mesa 3D (casino_3d.gd) y sabe a qué apuesta corresponde cada punto: en el centro
## de un número es un pleno; en la raya entre dos, un caballo; en un cruce, un cuadro; en el borde de abajo de una
## columna, una transversal (o una seisena entre dos). Al pasar el ratón se iluminan los números que cubre.
## 1 píxel = 1 mm del paño.

signal place(kind: String, nums: Array, at: Vector2)
signal unplace(kind: String, nums: Array)
signal action(name: String)

const D := preload("res://scripts/data/casino_data.gd")
const Ruleta := preload("res://scripts/systems/ruleta.gd")

const SIZE := Vector2(1460, 720)
const GX := 120.0
const GY := 30.0
const CW := 95.0
const CH := 160.0
const EX := 16.0
const EY := 22.0
const FELT := Color("1d5638")
const LINE := Color("e9dcb4")

var enabled := true
## Ruleta (para dibujar las fichas en 2D y el historial)
var game: Ruleta
var draw_chips := false
## Número ganador resaltado (-1: ninguno)
var win := -1
var _hover := {}
var _t := 0.0


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	if win >= 0:
		queue_redraw()


static func n_at(c: int, r: int) -> int:
	return 3 * c + (3 - r)


## Centro de la casilla del número n en el paño
static func cell_center(n: int) -> Vector2:
	if n == 0:
		return Vector2((20.0 + GX) * 0.5, GY + CH * 1.5)
	var c := (n - 1) / 3
	var r := 2 - (n - 1) % 3
	return Vector2(GX + (c + 0.5) * CW, GY + (r + 0.5) * CH)


const BTN_REPEAT := Rect2(1270, 520, 175, 80)
const BTN_CLEAR := Rect2(1270, 610, 175, 80)


## La apuesta que hay en el punto p del paño: {"kind", "nums", "at"} o {} si no hay ninguna
func spot_at(p: Vector2) -> Dictionary:
	var gy1 := GY + 3.0 * CH
	var gx1 := GX + 12.0 * CW
	# números (con las rayas del cero)
	if p.y >= GY - 4.0 and p.y <= gy1 + EY and p.x >= GX - EX and p.x <= gx1:
		var col := clampi(int(floor((p.x - GX) / CW)), 0, 11)
		var row := clampi(int(floor((p.y - GY) / CH)), 0, 2)
		var lx := p.x - GX - col * CW
		var ly := p.y - GY - row * CH
		var nl := lx < EX
		var nr := lx > CW - EX
		var nt := ly < EY
		var nb := ly > CH - EY
		if (nl or nr) and (nt or nb):
			var c1 := col - 1 if nl else col
			var c2 := c1 + 1
			var r1 := row - 1 if nt else row
			var r2 := r1 + 1
			var at := Vector2(GX + c2 * CW, GY + r2 * CH)
			if c1 < 0:
				if r1 >= 0 and r2 <= 2:
					return {"kind": "transversal", "nums": [0, n_at(0, r1), n_at(0, r2)], "at": at}
				if r2 > 2:
					return {"kind": "cuadro", "nums": [0, 1, 2, 3], "at": at}
				return {"kind": "caballo", "nums": [0, 3], "at": Vector2(GX, GY + CH * 0.5)}
			if c2 > 11:
				return _pleno(n_at(col, row))
			if r1 < 0:
				return {"kind": "caballo", "nums": [n_at(c1, 0), n_at(c2, 0)], "at": Vector2(GX + c2 * CW, GY + CH * 0.5)}
			if r2 > 2:
				return {"kind": "seisena", "nums": [3 * c1 + 1, 3 * c1 + 2, 3 * c1 + 3, 3 * c2 + 1, 3 * c2 + 2, 3 * c2 + 3], "at": at}
			return {"kind": "cuadro", "nums": [n_at(c1, r1), n_at(c2, r1), n_at(c1, r2), n_at(c2, r2)], "at": at}
		if nl or nr:
			var c1b := col - 1 if nl else col
			if c1b < 0:
				return {"kind": "caballo", "nums": [0, n_at(0, row)], "at": Vector2(GX, GY + (row + 0.5) * CH)}
			if c1b + 1 > 11:
				return _pleno(n_at(col, row))
			return {"kind": "caballo", "nums": [n_at(c1b, row), n_at(c1b + 1, row)], "at": Vector2(GX + (c1b + 1) * CW, GY + (row + 0.5) * CH)}
		if nt or nb:
			var r1b := row - 1 if nt else row
			if r1b < 0:
				return _pleno(n_at(col, row))
			if r1b + 1 > 2:
				return {"kind": "transversal", "nums": [3 * col + 1, 3 * col + 2, 3 * col + 3], "at": Vector2(GX + (col + 0.5) * CW, gy1)}
			return {"kind": "caballo", "nums": [n_at(col, r1b), n_at(col, r1b + 1)], "at": Vector2(GX + (col + 0.5) * CW, GY + (r1b + 1) * CH)}
		if p.x >= GX:
			return _pleno(n_at(col, row))
	if Rect2(20, GY, GX - 20, 3 * CH).has_point(p):
		return _pleno(0)
	# columnas «2 a 1»
	if p.x >= gx1 and p.x < gx1 + 100.0 and p.y >= GY and p.y < gy1:
		var row2 := int((p.y - GY) / CH)
		var arg := 2 - row2
		return {"kind": "columna", "nums": Ruleta.outside_nums("columna", arg), "at": Vector2(gx1 + 50.0, GY + (row2 + 0.5) * CH)}
	# docenas
	if p.y >= gy1 + EY and p.y < gy1 + 90.0 and p.x >= GX and p.x < gx1:
		var dz := int((p.x - GX) / (4.0 * CW))
		return {"kind": "docena", "nums": Ruleta.outside_nums("docena", dz), "at": Vector2(GX + (dz + 0.5) * 4.0 * CW, gy1 + 45.0)}
	# sencillas
	if p.y >= gy1 + 90.0 and p.y < gy1 + 180.0 and p.x >= GX and p.x < gx1:
		var k := int((p.x - GX) / 190.0)
		var kind: String = ["falta", "par", "rojo", "negro", "impar", "pasa"][clampi(k, 0, 5)]
		return {"kind": kind, "nums": Ruleta.outside_nums(kind), "at": Vector2(GX + (k + 0.5) * 190.0, gy1 + 135.0)}
	return {}


func _pleno(n: int) -> Dictionary:
	return {"kind": "pleno", "nums": [n], "at": cell_center(n)}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := spot_at(event.position) if enabled else {}
		var on_btn := enabled and (BTN_REPEAT.has_point(event.position) or BTN_CLEAR.has_point(event.position))
		if on_btn:
			h = {"btn": "repetir" if BTN_REPEAT.has_point(event.position) else "borrar"}
		if h.hash() != _hover.hash():
			_hover = h
			queue_redraw()
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not h.is_empty() else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and enabled:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if BTN_REPEAT.has_point(event.position):
				action.emit("repetir")
				return
			if BTN_CLEAR.has_point(event.position):
				action.emit("borrar")
				return
			var s := spot_at(event.position)
			if not s.is_empty():
				place.emit(s["kind"], s["nums"], s["at"])
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var s2 := spot_at(event.position)
			if not s2.is_empty():
				unplace.emit(s2["kind"], s2["nums"])


func clear_hover() -> void:
	_hover = {}
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		clear_hover()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), FELT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 500:
		draw_circle(Vector2(rng.randf() * SIZE.x, rng.randf() * SIZE.y), rng.randf_range(2, 5), Color(0, 0, 0, 0.06))
	var covered: Array = _hover.get("nums", [])
	var gy1 := GY + 3.0 * CH
	var gx1 := GX + 12.0 * CW
	# cero
	var zr := Rect2(20, GY, GX - 20, 3 * CH)
	var zpts := PackedVector2Array([Vector2(GX, GY), Vector2(GX, gy1), Vector2(60, gy1), Vector2(20, gy1 - 60), Vector2(20, GY + 60), Vector2(60, GY)])
	draw_colored_polygon(zpts, Color("1d7a3c").lerp(Color.WHITE, 0.25 if 0 in covered else 0.0))
	zpts.append(zpts[0])
	draw_polyline(zpts, LINE, 4.0)
	_txt("0", zr.position + Vector2(0, zr.size.y * 0.5 + 26), 64, Color("f4efe2"), zr.size.x)
	# números
	for c in 12:
		for r in 3:
			var n := n_at(c, r)
			var cell := Rect2(GX + c * CW, GY + r * CH, CW, CH)
			if n in covered:
				draw_rect(cell, Color(1, 0.95, 0.7, 0.28))
			var red := n in D.REDS
			var oc := cell.get_center()
			_oval(oc, Vector2(34, 44), Color("a3161c") if red else Color("141416"))
			_txt(str(n), Vector2(cell.position.x, oc.y + 18), 48, Color("f4efe2"), CW)
			draw_rect(cell, LINE, false, 3.0)
	# 2 a 1
	for r in 3:
		var cell2 := Rect2(gx1, GY + r * CH, 100, CH)
		if not covered.is_empty() and _hover.get("kind", "") == "columna" and Ruleta.outside_nums("columna", 2 - r) == covered:
			draw_rect(cell2, Color(1, 0.95, 0.7, 0.28))
		draw_rect(cell2, LINE, false, 3.0)
		_txt("2 a 1", Vector2(gx1, GY + (r + 0.5) * CH + 14), 34, LINE, 100)
	# docenas
	var dn := ["1.ª DOCENA", "2.ª DOCENA", "3.ª DOCENA"]
	for k in 3:
		var dr := Rect2(GX + k * 4 * CW, gy1, 4 * CW, 90)
		if _hover.get("kind", "") == "docena" and Ruleta.outside_nums("docena", k) == covered:
			draw_rect(dr, Color(1, 0.95, 0.7, 0.28))
		draw_rect(dr, LINE, false, 3.0)
		_txt(dn[k], Vector2(dr.position.x, dr.position.y + 58), 36, LINE, dr.size.x)
	# sencillas
	var kinds := ["falta", "par", "rojo", "negro", "impar", "pasa"]
	var labels := ["1-18", "PAR", "", "", "IMPAR", "19-36"]
	for k in 6:
		var orr := Rect2(GX + k * 190, gy1 + 90, 190, 90)
		if _hover.get("kind", "") == kinds[k]:
			draw_rect(orr, Color(1, 0.95, 0.7, 0.28))
		draw_rect(orr, LINE, false, 3.0)
		if labels[k] != "":
			_txt(labels[k], Vector2(orr.position.x, orr.position.y + 60), 40, LINE, orr.size.x)
		else:
			var dc := orr.get_center()
			draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -32), dc + Vector2(60, 0), dc + Vector2(0, 32), dc + Vector2(-60, 0)]), Color("a3161c") if kinds[k] == "rojo" else Color("141416"))
			draw_polyline(PackedVector2Array([dc + Vector2(0, -32), dc + Vector2(60, 0), dc + Vector2(0, 32), dc + Vector2(-60, 0), dc + Vector2(0, -32)]), LINE, 2.0)
	# casillas impresas: repetir y borrar
	for b in [[BTN_REPEAT, "REPETIR", "repetir"], [BTN_CLEAR, "BORRAR", "borrar"]]:
		var br: Rect2 = b[0]
		draw_rect(br, Color(LINE, 0.18 if _hover.get("btn", "") == b[2] else 0.06))
		draw_rect(br, LINE, false, 3.0)
		_txt(b[1], Vector2(br.position.x, br.position.y + 54), 32, LINE, br.size.x)
	# marcador: los últimos números
	if game != null:
		var y := GY
		var hist: Array = game.history.duplicate()
		hist.reverse()
		_txt("ÚLTIMOS", Vector2(1370, GY - 6), 18, Color(LINE, 0.8), 80)
		for i in mini(hist.size(), 9):
			var n2: int = hist[i]
			var col := Color("1d7a3c") if n2 == 0 else (Color("a3161c") if n2 in D.REDS else Color("141416"))
			var rr := Rect2(1374, y + 4 + i * 52, 72, 46)
			draw_rect(rr, col)
			draw_rect(rr, LINE if i == 0 else Color(LINE, 0.5), false, 3.0 if i == 0 else 1.5)
			_txt(str(n2), Vector2(rr.position.x, rr.position.y + 36), 34, Color("f4efe2"), rr.size.x)
	# número ganador
	if win >= 0:
		var wc := cell_center(win)
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		draw_arc(wc, 58.0 + pulse * 6.0, 0, TAU, 48, Color(1, 0.86, 0.4, 0.9), 6.0)
	# punto exacto de la apuesta señalada
	if _hover.has("at"):
		draw_circle(_hover["at"], 14, Color(1, 0.95, 0.7, 0.85))
		draw_arc(_hover["at"], 20, 0, TAU, 24, Color(0, 0, 0, 0.5), 3.0)
	if draw_chips and game != null:
		for k in game.bets:
			var bt: Dictionary = game.bets[k]
			draw_circle(bt["at"], 22, Color("b81c2a"))
			draw_arc(bt["at"], 22, 0, TAU, 24, Color("f2efe6"), 4.0)
			_txt(str(int(bt["amount"])), Vector2(bt["at"].x - 40, bt["at"].y + 8), 20, Color.WHITE, 80)


func _oval(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _txt(t: String, pos: Vector2, fs: int, col: Color, w: float) -> void:
	draw_string(UI.f_serif_b, pos, t, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)
