extends RefCounted
## Dibujos del casino hechos por código (se pintan en un SubViewport y se usan como textura en 3D o en 2D):
## la baraja (caras y dorso), los símbolos de la tragaperras (y sus versiones del modo meme), el aro de números de la
## ruleta, el paño del blackjack, el centro de las fichas y los letreros de la máquina.

const D := preload("res://scripts/data/casino_data.gd")

const RED := Color("b8182a")
const INK := Color("15151a")
const CARD := Color("fbf7ee")
const GOLD := Color("d9b25a")
const GOLD_D := Color("8a6a2a")
const FELT := Color("1d5638")
const FELT_D := Color("12402a")


# ------------------------------------------------------------------ palos

## Palo s (0 picas, 1 corazones, 2 diamantes, 3 tréboles) centrado en c, de alto aproximado size
static func suit(ci: CanvasItem, s: int, c: Vector2, size: float, col: Color = Color(0, 0, 0, 0)) -> void:
	if col.a == 0.0:
		col = RED if s in [1, 2] else INK
	var k := size
	match s:
		0:
			ci.draw_circle(c + Vector2(-0.24, 0.1) * k, 0.25 * k, col)
			ci.draw_circle(c + Vector2(0.24, 0.1) * k, 0.25 * k, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.48, 0.06) * k, c + Vector2(0, -0.52) * k, c + Vector2(0.48, 0.06) * k]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0.1) * k, c + Vector2(0.17, 0.5) * k, c + Vector2(-0.17, 0.5) * k]), col)
		1:
			ci.draw_circle(c + Vector2(-0.24, -0.16) * k, 0.26 * k, col)
			ci.draw_circle(c + Vector2(0.24, -0.16) * k, 0.26 * k, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.49, -0.1) * k, c + Vector2(0.49, -0.1) * k, c + Vector2(0, 0.5) * k]), col)
		2:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.52) * k, c + Vector2(0.38, 0) * k, c + Vector2(0, 0.52) * k, c + Vector2(-0.38, 0) * k]), col)
		_:
			ci.draw_circle(c + Vector2(0, -0.24) * k, 0.21 * k, col)
			ci.draw_circle(c + Vector2(-0.23, 0.08) * k, 0.21 * k, col)
			ci.draw_circle(c + Vector2(0.23, 0.08) * k, 0.21 * k, col)
			ci.draw_circle(c, 0.12 * k, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0.0) * k, c + Vector2(0.16, 0.5) * k, c + Vector2(-0.16, 0.5) * k]), col)


static func _round_rect(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	sb.draw(ci.get_canvas_item(), r)


static func _round_border(ci: CanvasItem, r: Rect2, rad: float, col: Color, w: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(w)
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	sb.draw(ci.get_canvas_item(), r)


static func _text(ci: CanvasItem, font: Font, pos: Vector2, text: String, size: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT, outline := 0, ocol := Color.BLACK) -> void:
	if outline > 0:
		ci.draw_string_outline(font, pos, text, align, width, size, outline, ocol)
	ci.draw_string(font, pos, text, align, width, size, col)


# ------------------------------------------------------------------ cartas

const PIPS := {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.5, 0.22), Vector2(0.5, 0.78)],
	3: [Vector2(0.5, 0.22), Vector2(0.5, 0.5), Vector2(0.5, 0.78)],
	4: [Vector2(0.3, 0.22), Vector2(0.7, 0.22), Vector2(0.3, 0.78), Vector2(0.7, 0.78)],
	5: [Vector2(0.3, 0.22), Vector2(0.7, 0.22), Vector2(0.5, 0.5), Vector2(0.3, 0.78), Vector2(0.7, 0.78)],
	6: [Vector2(0.3, 0.22), Vector2(0.7, 0.22), Vector2(0.3, 0.5), Vector2(0.7, 0.5), Vector2(0.3, 0.78), Vector2(0.7, 0.78)],
	7: [Vector2(0.3, 0.22), Vector2(0.7, 0.22), Vector2(0.5, 0.36), Vector2(0.3, 0.5), Vector2(0.7, 0.5), Vector2(0.3, 0.78), Vector2(0.7, 0.78)],
	8: [Vector2(0.3, 0.22), Vector2(0.7, 0.22), Vector2(0.5, 0.36), Vector2(0.3, 0.5), Vector2(0.7, 0.5), Vector2(0.5, 0.64), Vector2(0.3, 0.78), Vector2(0.7, 0.78)],
	9: [Vector2(0.3, 0.22), Vector2(0.7, 0.22), Vector2(0.3, 0.41), Vector2(0.7, 0.41), Vector2(0.5, 0.5), Vector2(0.3, 0.59), Vector2(0.7, 0.59), Vector2(0.3, 0.78), Vector2(0.7, 0.78)],
	10: [Vector2(0.3, 0.22), Vector2(0.7, 0.22), Vector2(0.5, 0.32), Vector2(0.3, 0.41), Vector2(0.7, 0.41), Vector2(0.3, 0.59), Vector2(0.7, 0.59), Vector2(0.5, 0.68), Vector2(0.3, 0.78), Vector2(0.7, 0.78)],
}


## Cara de la carta c (0..51) en el rectángulo r (fuera de las esquinas redondeadas queda transparente)
static func card_face(ci: CanvasItem, c: int, r: Rect2) -> void:
	var s := c / 13
	var rank := c % 13
	var w := r.size.x
	var h := r.size.y
	var col := RED if s in [1, 2] else INK
	_round_rect(ci, r, w * 0.07, CARD)
	_round_border(ci, r.grow(-1.0), w * 0.07, Color(0.6, 0.58, 0.52), 2)
	var lbl: String = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"][rank]
	var fs := int(w * 0.2)
	# índices en las esquinas (el de abajo, girado)
	for flip in [false, true]:
		if flip:
			ci.draw_set_transform(r.position + r.size, PI, Vector2.ONE)
		else:
			ci.draw_set_transform(r.position, 0.0, Vector2.ONE)
		_text(ci, UI.f_serif_b, Vector2(w * 0.04, h * 0.17), lbl, fs, col, w * 0.2, HORIZONTAL_ALIGNMENT_CENTER)
		suit(ci, s, Vector2(w * 0.14, h * 0.26), w * 0.14, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var inner := Rect2(r.position + Vector2(w * 0.2, h * 0.1), Vector2(w * 0.6, h * 0.8))
	if rank >= 10:
		# figuras: marco de color, la letra grande y el palo
		var fc: Color = [Color("2a4a8a"), Color("8a1f2b"), Color("b8862a")][rank - 10]
		_round_rect(ci, inner, 10, fc.lightened(0.55))
		_round_border(ci, inner, 10, fc, 4)
		for k in 6:
			var yy := inner.position.y + inner.size.y * (0.08 + k * 0.17)
			ci.draw_line(Vector2(inner.position.x + 8, yy), Vector2(inner.end.x - 8, yy), Color(fc, 0.12), 6.0)
		if rank >= 11:
			# corona
			var cc := inner.position + Vector2(inner.size.x * 0.5, inner.size.y * 0.2)
			var cw := inner.size.x * 0.32
			ci.draw_colored_polygon(PackedVector2Array([cc + Vector2(-cw, cw * 0.4), cc + Vector2(-cw, -cw * 0.3), cc + Vector2(-cw * 0.5, cw * 0.05),
				cc + Vector2(0, -cw * 0.5), cc + Vector2(cw * 0.5, cw * 0.05), cc + Vector2(cw, -cw * 0.3), cc + Vector2(cw, cw * 0.4)]), GOLD)
		_text(ci, UI.f_serif_b, inner.position + Vector2(0, inner.size.y * 0.66), lbl, int(w * 0.36), fc.darkened(0.2), inner.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		suit(ci, s, inner.position + Vector2(inner.size.x * 0.5, inner.size.y * 0.82), w * 0.16, col)
	elif rank == 0:
		suit(ci, s, r.position + r.size * 0.5, w * 0.42, col)
	else:
		for p in PIPS[rank + 1]:
			suit(ci, s, inner.position + Vector2(p.x, p.y) * inner.size, w * 0.15, col)


## Dorso de las cartas: granate con orla dorada, celosía y el sello de Valdoria
static func card_back(ci: CanvasItem, r: Rect2) -> void:
	var w := r.size.x
	_round_rect(ci, r, w * 0.07, CARD)
	var inner := r.grow(-w * 0.06)
	_round_rect(ci, inner, w * 0.05, Color("6e1622"))
	var step := w * 0.09
	var x := inner.position.x - inner.size.y
	while x < inner.end.x:
		ci.draw_line(Vector2(x, inner.position.y), Vector2(x + inner.size.y, inner.end.y), Color(GOLD, 0.35), 2.0)
		ci.draw_line(Vector2(x + inner.size.y, inner.position.y), Vector2(x, inner.end.y), Color(GOLD, 0.35), 2.0)
		x += step
	_round_border(ci, inner.grow(-6), w * 0.04, GOLD, 3)
	var c := r.position + r.size * 0.5
	ci.draw_circle(c, w * 0.2, Color("6e1622"))
	ci.draw_arc(c, w * 0.2, 0, TAU, 48, GOLD, 4.0)
	ci.draw_arc(c, w * 0.16, 0, TAU, 48, GOLD, 2.0)
	_text(ci, UI.f_serif_b, c + Vector2(-w * 0.2, w * 0.09), "V", int(w * 0.24), GOLD, w * 0.4, HORIZONTAL_ALIGNMENT_CENTER)


# ------------------------------------------------------------------ tragaperras

static func symbol_name(sym: String, meme: bool) -> String:
	return (D.MEME_NAMES if meme else D.SYMBOL_NAMES).get(sym, sym)


## Símbolo sym en el rectángulo r (en el modo meme: tortilla, paloma, plasma y Galbana)
static func symbol(ci: CanvasItem, sym: String, r: Rect2, meme: bool) -> void:
	var c := r.position + r.size * 0.5
	var k := minf(r.size.x, r.size.y)
	match sym:
		"cereza":
			ci.draw_line(c + Vector2(-0.18, 0.12) * k, c + Vector2(0.04, -0.34) * k, Color("3d7a2a"), k * 0.04)
			ci.draw_line(c + Vector2(0.2, 0.08) * k, c + Vector2(0.04, -0.34) * k, Color("3d7a2a"), k * 0.04)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.04, -0.34) * k, c + Vector2(0.3, -0.42) * k, c + Vector2(0.22, -0.28) * k]), Color("4f9a34"))
			for p in [Vector2(-0.2, 0.18), Vector2(0.2, 0.14)]:
				ci.draw_circle(c + p * k, 0.17 * k, Color("c4142a"))
				ci.draw_circle(c + (p + Vector2(-0.06, -0.06)) * k, 0.05 * k, Color(1, 1, 1, 0.55))
		"limon":
			if meme:
				# la tortilla (con cebolla)
				ci.draw_circle(c, 0.36 * k, Color("b8741e"))
				ci.draw_circle(c, 0.32 * k, Color("f2c64a"))
				ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(0.4, -0.12) * k, c + Vector2(0.4, 0.18) * k]), Color(0, 0, 0, 0))
				for p in [Vector2(-0.12, -0.08), Vector2(0.1, 0.12), Vector2(-0.05, 0.18), Vector2(0.16, -0.14)]:
					ci.draw_circle(c + p * k, 0.035 * k, Color("e8e0b0"))
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.02, 0.0) * k, c + Vector2(0.34, -0.14) * k, c + Vector2(0.34, 0.14) * k]), Color("f6eed8"))
			else:
				var pts := PackedVector2Array()
				for i in 32:
					var a := TAU * i / 32.0
					var rr := 0.3 + 0.07 * pow(absf(cos(a)), 6.0)
					pts.append(c + Vector2(cos(a) * rr * 1.2, sin(a) * 0.26) * k)
				ci.draw_colored_polygon(pts, Color("f2d43a"))
				ci.draw_circle(c + Vector2(-0.1, -0.08) * k, 0.06 * k, Color(1, 1, 1, 0.4))
		"campana":
			if meme:
				# la paloma
				var g := Color("8a8f98")
				ci.draw_circle(c + Vector2(0.0, 0.06) * k, 0.24 * k, g)
				ci.draw_circle(c + Vector2(0.22, -0.16) * k, 0.12 * k, g.lightened(0.1))
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.32, -0.18) * k, c + Vector2(0.44, -0.14) * k, c + Vector2(0.32, -0.1) * k]), Color("e0a030"))
				ci.draw_circle(c + Vector2(0.25, -0.19) * k, 0.025 * k, INK)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.1, -0.02) * k, c + Vector2(-0.42, -0.3) * k, c + Vector2(-0.3, 0.06) * k]), g.darkened(0.25))
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.2, 0.12) * k, c + Vector2(-0.42, 0.3) * k, c + Vector2(-0.12, 0.26) * k]), g.darkened(0.15))
				ci.draw_circle(c + Vector2(0.14, -0.04) * k, 0.06 * k, Color("6a8a7a"))
			else:
				var pts := PackedVector2Array([c + Vector2(-0.34, 0.22) * k, c + Vector2(-0.26, 0.12) * k, c + Vector2(-0.22, -0.12) * k,
					c + Vector2(-0.12, -0.3) * k, c + Vector2(0.12, -0.3) * k, c + Vector2(0.22, -0.12) * k, c + Vector2(0.26, 0.12) * k, c + Vector2(0.34, 0.22) * k])
				ci.draw_colored_polygon(pts, Color("e2b23a"))
				ci.draw_circle(c + Vector2(0, 0.28) * k, 0.07 * k, Color("b8862a"))
				ci.draw_circle(c + Vector2(0, -0.34) * k, 0.05 * k, Color("b8862a"))
				ci.draw_line(c + Vector2(-0.12, -0.2) * k, c + Vector2(-0.16, 0.1) * k, Color(1, 1, 1, 0.45), k * 0.04)
		"bar":
			if meme:
				# el plasma: una pantalla con el presidente dentro
				_round_rect(ci, Rect2(c - Vector2(0.4, 0.28) * k, Vector2(0.8, 0.5) * k), k * 0.04, Color("2a2c32"))
				ci.draw_rect(Rect2(c - Vector2(0.35, 0.23) * k, Vector2(0.7, 0.4) * k), Color("4a6a9a"))
				ci.draw_circle(c + Vector2(0, -0.08) * k, 0.1 * k, Color("e6bc98"))
				ci.draw_rect(Rect2(c + Vector2(-0.16, 0.03) * k, Vector2(0.32, 0.14) * k), Color("22283a"))
				ci.draw_rect(Rect2(c + Vector2(-0.06, 0.22) * k, Vector2(0.12, 0.08) * k), Color("2a2c32"))
			else:
				_round_rect(ci, Rect2(c - Vector2(0.4, 0.17) * k, Vector2(0.8, 0.34) * k), k * 0.06, INK)
				_text(ci, UI.f_cond_b, c + Vector2(-0.4, 0.12) * k, "BAR", int(k * 0.3), Color("f2efe6"), 0.8 * k, HORIZONTAL_ALIGNMENT_CENTER)
		"siete":
			_text(ci, UI.f_serif_k, c + Vector2(-0.4, 0.3) * k, "7", int(k * 0.86), Color("d81c2a"), 0.8 * k, HORIZONTAL_ALIGNMENT_CENTER, int(k * 0.05), Color("8a1010"))
		_:
			if meme:
				# Galbana: calvo, gafas y bigote
				ci.draw_circle(c, 0.32 * k, Color("e6bc98"))
				ci.draw_arc(c + Vector2(0, -0.04) * k, 0.33 * k, PI * 0.95, PI * 2.05, 24, Color("9a9a98"), k * 0.06)
				for sx in [-1.0, 1.0]:
					ci.draw_arc(c + Vector2(sx * 0.12, -0.04) * k, 0.08 * k, 0, TAU, 20, INK, k * 0.025)
				ci.draw_line(c + Vector2(-0.04, -0.04) * k, c + Vector2(0.04, -0.04) * k, INK, k * 0.02)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.18, 0.12) * k, c + Vector2(0, 0.06) * k, c + Vector2(0.18, 0.12) * k, c + Vector2(0, 0.16) * k]), Color("4a3a2a"))
			else:
				# el sello presidencial
				ci.draw_circle(c, 0.38 * k, GOLD_D)
				ci.draw_circle(c, 0.34 * k, GOLD)
				ci.draw_arc(c, 0.28 * k, 0, TAU, 40, GOLD_D, k * 0.02)
				var pts := PackedVector2Array()
				for i in 10:
					var a := -PI / 2 + TAU * i / 10.0
					var rr := 0.2 if i % 2 == 0 else 0.09
					pts.append(c + Vector2(cos(a), sin(a)) * rr * k)
				ci.draw_colored_polygon(pts, Color("b22a2a"))


## Tira de un rodillo: los 12 símbolos de arriba abajo (w × 12·cell)
static func reel_strip(ci: CanvasItem, reel: int, w: float, cell: float, meme: bool) -> void:
	var strip: Array = D.STRIPS[reel]
	for i in strip.size():
		var r := Rect2(0, i * cell, w, cell)
		ci.draw_rect(r, Color("f4efe2"))
		ci.draw_line(Vector2(0, r.position.y), Vector2(w, r.position.y), Color(0, 0, 0, 0.18), 3.0)
		symbol(ci, strip[i], Rect2(r.position + Vector2(w * 0.14, cell * 0.08), Vector2(w * 0.72, cell * 0.84)), meme)
	# sombra hacia los bordes (el cilindro)
	for k in 8:
		var a := 0.06 * (8 - k) / 8.0
		ci.draw_rect(Rect2(k * 3, 0, 3, strip.size() * cell), Color(0, 0, 0, a))
		ci.draw_rect(Rect2(w - (k + 1) * 3, 0, 3, strip.size() * cell), Color(0, 0, 0, a))


## Letrero de arriba de la máquina: título, una línea y el bote
static func slot_sign(ci: CanvasItem, size: Vector2, title: String, line: String, lit: float) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color("1a0a12"))
	for i in 18:
		var x := size.x * (i + 0.5) / 18.0
		ci.draw_circle(Vector2(x, 14), 6, GOLD.lerp(Color("fff2c0"), lit if i % 2 == 0 else 1.0 - lit))
		ci.draw_circle(Vector2(x, size.y - 14), 6, GOLD.lerp(Color("fff2c0"), 1.0 - lit if i % 2 == 0 else lit))
	_text(ci, UI.f_serif_k, Vector2(0, size.y * 0.5), title, int(size.y * 0.3), Color("ffd45a"), size.x, HORIZONTAL_ALIGNMENT_CENTER, 8, Color("7a1a10"))
	_text(ci, UI.f_cond_b, Vector2(0, size.y * 0.82), line, int(size.y * 0.17), Color("f2efe6"), size.x, HORIZONTAL_ALIGNMENT_CENTER)


## Panel de la barriga: la tabla de premios
static func slot_belly(ci: CanvasItem, size: Vector2, meme: bool) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color("18183a"))
	ci.draw_rect(Rect2(Vector2(8, 8), size - Vector2(16, 16)), GOLD, false, 4.0)
	_text(ci, UI.f_serif_b, Vector2(0, 62), "TABLA DE PREMIOS", 40, Color("ffd45a"), size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var y := 96.0
	var row := (size.y - 120.0) / D.PAYTABLE.size()
	for p in D.PAYTABLE:
		var x := size.x * 0.08
		for s in p["combo"]:
			if s == "*":
				_text(ci, UI.f_cond_b, Vector2(x, y + row * 0.72), "?", int(row * 0.6), Color(1, 1, 1, 0.5), row, HORIZONTAL_ALIGNMENT_CENTER)
			else:
				ci.draw_rect(Rect2(x, y + 4, row - 8, row - 8), Color("f4efe2"))
				symbol(ci, s, Rect2(x + 2, y + 6, row - 12, row - 12), meme)
			x += row + 6.0
		_text(ci, UI.f_cond_b, Vector2(size.x * 0.58, y + row * 0.68), "× %d" % int(p["x"]), int(row * 0.5), Color("f2efe6"), size.x * 0.36, HORIZONTAL_ALIGNMENT_RIGHT)
		y += row


## Escudo del remate de la máquina (media luna)
static func slot_crest(ci: CanvasItem, size: Vector2, meme: bool) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color("7a1220"))
	var c := Vector2(size.x * 0.5, size.y)
	for i in 14:
		var a := PI + PI * (i + 0.5) / 14.0
		ci.draw_line(c, c + Vector2(cos(a), sin(a)) * size.x, Color(GOLD, 0.25 if i % 2 == 0 else 0.1), 18.0)
	ci.draw_circle(c + Vector2(0, -size.y * 0.42), size.y * 0.3, GOLD)
	_text(ci, UI.f_serif_k, c + Vector2(-size.x * 0.5, -size.y * 0.3), "G" if meme else "V", int(size.y * 0.42), Color("7a1220"), size.x, HORIZONTAL_ALIGNMENT_CENTER)


# ------------------------------------------------------------------ ruleta y fichas

## Aro de números de la ruleta: u = ángulo (antihorario desde +X), arriba de la imagen = hacia el centro
static func number_ring(ci: CanvasItem, size: Vector2) -> void:
	var da := TAU / 37.0
	var pw := size.x / 37.0
	for i in 37:
		var n: int = D.WHEEL[i]
		var col := Color("1d7a3c") if n == 0 else (Color("a3161c") if n in D.REDS else Color("141416"))
		var center := fposmod(PI / 2.0 - i * da, TAU) / TAU * size.x
		for shift: float in [-size.x, 0.0, size.x]:
			var x0: float = center - pw * 0.5 + shift
			if x0 + pw < 0.0 or x0 > size.x:
				continue
			ci.draw_rect(Rect2(x0, 0, pw, size.y), col)
			ci.draw_line(Vector2(x0, 0), Vector2(x0, size.y), GOLD, 3.0)
			_text(ci, UI.f_serif_b, Vector2(x0, size.y * 0.7), str(n), int(size.y * 0.5), Color("f4efe2"), pw, HORIZONTAL_ALIGNMENT_CENTER)


## Centro de una ficha: el valor en millones
static func chip_face(ci: CanvasItem, size: float, value: int, col: Color) -> void:
	var c := Vector2(size, size) * 0.5
	ci.draw_rect(Rect2(0, 0, size, size), Color("f2efe6"))
	ci.draw_arc(c, size * 0.44, 0, TAU, 40, col, size * 0.05)
	_text(ci, UI.f_cond_b, Vector2(0, size * 0.6), str(value), int(size * (0.42 if value < 100 else 0.34)), col, size, HORIZONTAL_ALIGNMENT_CENTER)
	_text(ci, UI.f_sans_b, Vector2(0, size * 0.8), "M€", int(size * 0.13), col.darkened(0.2), size, HORIZONTAL_ALIGNMENT_CENTER)


# ------------------------------------------------------------------ blackjack

## Paño del blackjack (UV del .glb: x de -1,08 a 1,08 m; arriba el lado del crupier, abajo la curva de los jugadores).
## px: píxeles por metro
static func bj_felt(ci: CanvasItem, size: Vector2, px: float) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), FELT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 900:
		ci.draw_circle(Vector2(rng.randf() * size.x, rng.randf() * size.y), rng.randf_range(2, 6), Color(FELT_D, 0.25))
	# centro del arco: en el lado del crupier
	var cy := 0.0
	var c := Vector2(size.x * 0.5, cy)
	var ink := Color("e9d9a8")
	for rr in [0.62, 0.64]:
		ci.draw_arc(c, rr * px, deg_to_rad(28), deg_to_rad(152), 96, ink, 4.0)
	_arc_text(ci, c, 0.69 * px, "BLACKJACK PAGA 3 A 2", 46, ink, 92.0)
	_arc_text(ci, c, 0.55 * px, "LA BANCA PIDE CON 16 Y SE PLANTA CON 17", 28, Color(ink, 0.85), 70.0)
	for rr in [0.43, 0.48]:
		ci.draw_arc(c, rr * px, deg_to_rad(40), deg_to_rad(140), 80, Color(ink, 0.8), 3.0)
	_arc_text(ci, c, 0.455 * px, "EL SEGURO PAGA 2 A 1", 24, Color(ink, 0.8), 40.0)
	# la casilla de apuesta del presidente (a 0,8 m del centro del arco; ver BJ_BET en casino_3d.gd)
	var p := c + Vector2(0, 0.8 * px)
	ci.draw_arc(p, 0.075 * px, 0, TAU, 48, ink, 5.0)
	ci.draw_arc(p, 0.088 * px, 0, TAU, 48, Color(ink, 0.6), 2.0)
	_text(ci, UI.f_serif_b, Vector2(0, size.y * 0.24), "GRAN CASINO DE SANTA AURORA", 34, Color(ink, 0.45), size.x, HORIZONTAL_ALIGNMENT_CENTER)


## Texto a lo largo de un arco (centrado abajo del todo del arco, leído desde fuera)
static func _arc_text(ci: CanvasItem, c: Vector2, r: float, text: String, fs: int, col: Color, span_deg: float) -> void:
	var font: Font = UI.f_serif_b
	var n := text.length()
	var a0 := deg_to_rad(90.0 + span_deg * 0.5)
	for i in n:
		var a := a0 - deg_to_rad(span_deg) * (i + 0.5) / n
		var p := c + Vector2(cos(a), sin(a)) * r
		ci.draw_set_transform(p, a - PI / 2.0, Vector2.ONE)
		var ch := text.substr(i, 1)
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(font, Vector2(-w * 0.5, fs * 0.35), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
