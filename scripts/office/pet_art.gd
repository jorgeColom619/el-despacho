extends RefCounted
## Dibujo procedural de las mascotas del despacho (también usado en la tienda).


static func _ell(c: Vector2, r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


## Elipse girada `rot` alrededor de `off`, con la x escalada por `f` respecto a `c` (f < 0 la refleja).
static func _fell(c: Vector2, f: float, off: Vector2, r: Vector2, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		var p := Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot) + off
		pts.append(c + Vector2(p.x * f, p.y))
	return pts


## Dibuja la mascota en el espacio local de `o` (tamaños de referencia del despacho).
static func draw(o: CanvasItem, kind: String, t: float, happy: bool, parrot_line: String = "") -> void:
	match kind:
		"gato":
			var fur := Color("c98a4b")
			var dark := Color("8a5a2c")
			var breath := sin(t * 1.6) * 2.0
			o.draw_colored_polygon(_ell(Vector2(110, 82), Vector2(92, 34 + breath * 0.3)), Color(0, 0, 0, 0.25))
			o.draw_colored_polygon(_ell(Vector2(105, 70), Vector2(80, 32 + breath * 0.4)), fur)
			for i in 4:
				o.draw_arc(Vector2(70 + i * 22, 62), 14, PI * 1.1, PI * 1.9, 8, dark, 3.0, true)
			var tail := PackedVector2Array()
			for i in 12:
				var tt := float(i) / 11.0
				tail.append(Vector2(180 - tt * 60.0, 88 + sin(tt * PI) * 14.0 + sin(t * 2.0 + tt * 3.0) * (6.0 if happy else 2.0)))
			o.draw_polyline(tail, fur, 10.0, true)
			var hc := Vector2(40, 64)
			o.draw_circle(hc, 26, fur)
			o.draw_colored_polygon(PackedVector2Array([hc + Vector2(-22, -10), hc + Vector2(-18, -36), hc + Vector2(-4, -22)]), fur)
			o.draw_colored_polygon(PackedVector2Array([hc + Vector2(22, -10), hc + Vector2(18, -36), hc + Vector2(4, -22)]), fur)
			o.draw_colored_polygon(PackedVector2Array([hc + Vector2(-18, -14), hc + Vector2(-16, -30), hc + Vector2(-8, -20)]), Color("e8a8a0"))
			if happy:
				o.draw_circle(hc + Vector2(-9, -2), 4, Color("2a8a3a"))
				o.draw_circle(hc + Vector2(9, -2), 4, Color("2a8a3a"))
			else:
				o.draw_arc(hc + Vector2(-9, -2), 5, 0, PI, 8, dark, 2.0, true)
				o.draw_arc(hc + Vector2(9, -2), 5, 0, PI, 8, dark, 2.0, true)
				if int(t) % 4 < 2:
					o.draw_string(UI.f_hand, hc + Vector2(14, -40 - fmod(t, 2.0) * 6.0), "z z", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.7))
			o.draw_circle(hc + Vector2(0, 6), 3, Color("d46a6a"))
		"perro":
			var fur2 := Color("a8743e")
			var hc2 := Vector2(105, 70 + sin(t * 2.0) * 3.0)
			o.draw_circle(hc2 + Vector2(0, 30), 56, fur2.darkened(0.1))
			o.draw_circle(hc2, 48, fur2)
			o.draw_colored_polygon(_ell(hc2 + Vector2(-46, 6), Vector2(16, 34)), fur2.darkened(0.35))
			o.draw_colored_polygon(_ell(hc2 + Vector2(46, 6), Vector2(16, 34)), fur2.darkened(0.35))
			o.draw_colored_polygon(_ell(hc2 + Vector2(0, 22), Vector2(26, 18)), Color("e8cfa8"))
			o.draw_circle(hc2 + Vector2(-17, -8), 6, Color("1a1410"))
			o.draw_circle(hc2 + Vector2(17, -8), 6, Color("1a1410"))
			o.draw_circle(hc2 + Vector2(-15, -10), 2, Color.WHITE)
			o.draw_circle(hc2 + Vector2(19, -10), 2, Color.WHITE)
			o.draw_colored_polygon(_ell(hc2 + Vector2(0, 12), Vector2(10, 7)), Color("1a1410"))
			if happy:
				o.draw_colored_polygon(_ell(hc2 + Vector2(4, 36), Vector2(8, 12)), Color("e06a7a"))
			for px in [60.0, 150.0]:
				o.draw_colored_polygon(_ell(Vector2(px, 140), Vector2(26, 14)), fur2)
				for k in 3:
					o.draw_line(Vector2(px - 10 + k * 10, 134), Vector2(px - 10 + k * 10, 146), fur2.darkened(0.3), 2.0)
		"loro":
			var bob := sin(t * 3.0) * 2.0 + (sin(t * 18.0) * 3.0 if happy else 0.0)
			var b := Vector2(48, 50 + bob)
			o.draw_line(Vector2(10, 92), Vector2(86, 92), Color("6a3c24"), 4.0)
			o.draw_colored_polygon(PackedVector2Array([b + Vector2(4, 20), b + Vector2(18, 48), b + Vector2(8, 46)]), Color("2a7ad0"))
			o.draw_colored_polygon(_ell(b + Vector2(0, 12), Vector2(18, 26)), Color("2fae4a"))
			o.draw_circle(b + Vector2(0, -16), 15, Color("d8322e"))
			o.draw_circle(b + Vector2(6, -18), 4, Color.WHITE)
			o.draw_circle(b + Vector2(7, -18), 2, Color.BLACK)
			o.draw_colored_polygon(PackedVector2Array([b + Vector2(12, -14), b + Vector2(24, -8), b + Vector2(12, -4)]), Color("f2d24a"))
			if parrot_line != "":
				var tw := UI.f_sans_b.get_string_size(parrot_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20
				var bp := Vector2(-tw - 4, -30)
				o.draw_rect(Rect2(bp, Vector2(tw, 30)), Color(0.98, 0.97, 0.92))
				o.draw_colored_polygon(PackedVector2Array([bp + Vector2(tw - 16, 30), bp + Vector2(tw, 30), bp + Vector2(tw + 10, 44)]), Color(0.98, 0.97, 0.92))
				o.draw_string(UI.f_sans_b, bp + Vector2(10, 21), parrot_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("1a1a1a"))
		"pez":
			var c := Vector2(43, 46)
			o.draw_colored_polygon(_ell(c + Vector2(0, 38), Vector2(30, 6)), Color(0, 0, 0, 0.3))
			o.draw_circle(c, 38, Color(0.75, 0.9, 1.0, 0.18))
			o.draw_colored_polygon(_ell(c + Vector2(0, 8), Vector2(34, 26)), Color(0.3, 0.6, 0.85, 0.35))
			var sp := 2.5 if happy else 0.8
			var fx := c + Vector2(sin(t * sp) * 16.0, 6 + sin(t * 1.3) * 5.0)
			var dir := 1.0 if cos(t * sp) > 0 else -1.0
			o.draw_colored_polygon(_ell(fx, Vector2(10, 6)), Color("f28c28"))
			o.draw_colored_polygon(PackedVector2Array([fx + Vector2(-9 * dir, 0), fx + Vector2(-17 * dir, -6), fx + Vector2(-17 * dir, 6)]), Color("f2a848"))
			o.draw_arc(c, 38, 0, TAU, 40, Color(1, 1, 1, 0.45), 2.0, true)
			o.draw_arc(c, 30, PI * 1.1, PI * 1.4, 10, Color(1, 1, 1, 0.5), 3.0, true)
			o.draw_line(c + Vector2(-26, -26), c + Vector2(26, -26), Color(1, 1, 1, 0.4), 2.0)
		"tortuga":
			# pecera rectangular: grava, planta, roca para tomar el sol y la tortuga nadando
			var wt := 50.0
			o.draw_colored_polygon(_ell(Vector2(85, 119), Vector2(84, 5)), Color(0, 0, 0, 0.3))
			o.draw_rect(Rect2(10, 16, 150, 94), Color(0.75, 0.9, 1.0, 0.1))
			var water := PackedVector2Array()
			for i in 16:
				water.append(Vector2(10.0 + 150.0 * i / 15.0, wt + sin(t * 1.6 + i * 0.8) * 1.2))
			water.append(Vector2(160, 110))
			water.append(Vector2(10, 110))
			o.draw_colored_polygon(water, Color(0.28, 0.6, 0.62, 0.35))
			o.draw_rect(Rect2(10, 98, 150, 12), Color("b89a6a"))
			for i in 22:
				o.draw_circle(Vector2(13.0 + fmod(i * 37.0, 144.0), 100.0 + fmod(i * 13.0, 8.0)), 2.0 + fmod(i * 7.0, 3.0) * 0.5, [Color("8a7350"), Color("d8c49a"), Color("6f6a60")][i % 3])
			for k in 3:
				var leaf := PackedVector2Array()
				for j in 8:
					var u := float(j) / 7.0
					leaf.append(Vector2(22.0 + k * 7.0 + sin(t * 1.2 + k + u * 3.0) * 3.0 * u, 100.0 - u * (38.0 + k * 5.0)))
				o.draw_polyline(leaf, Color("3f8a3a").lightened(k * 0.1), 3.0, true)
			o.draw_colored_polygon(PackedVector2Array([Vector2(104, 100), Vector2(108, 70), Vector2(118, 50), Vector2(132, 40), Vector2(148, 42), Vector2(158, 54), Vector2(158, 100)]), Color("6e665c"))
			o.draw_colored_polygon(PackedVector2Array([Vector2(104, 100), Vector2(108, 70), Vector2(118, 50), Vector2(125, 46), Vector2(119, 72), Vector2(117, 100)]), Color("5c554c"))
			o.draw_circle(Vector2(140, 66), 2.5, Color("5c554c"))
			o.draw_circle(Vector2(148, 82), 2.0, Color("5c554c"))
			o.draw_polyline(PackedVector2Array([Vector2(118, 50), Vector2(132, 40), Vector2(148, 42), Vector2(158, 54)]), Color("8f877b"), 3.0, true)
			for i in 4:
				var ph := fmod(t * 0.5 + i * 0.25, 1.0)
				o.draw_arc(Vector2(48 + sin(ph * 12.0 + i) * 2.0, 98.0 - ph * (96.0 - wt)), 1.5 + ph * 1.2, 0, TAU, 10, Color(1, 1, 1, 0.5 - ph * 0.25), 1.2, true)
			# la tortuga: va y viene despacio y se "estrecha" al dar la vuelta
			var swim := 0.4
			var fl := 7.0 if happy else 3.0
			var tc := Vector2(64 + sin(t * swim) * 20.0, 76 + sin(t * 0.9) * 4.0)
			var fc := clampf(cos(t * swim) * 2.5, -1.0, 1.0)
			var f := (1.0 if fc >= 0.0 else -1.0) * maxf(absf(fc), 0.2)
			var skin := Color("7fa64a")
			o.draw_colored_polygon(_fell(tc, f, Vector2(-14, 8), Vector2(8, 3.5), 0.5 + sin(t * fl + 1.5) * 0.35), skin.darkened(0.2))
			o.draw_colored_polygon(PackedVector2Array([tc + Vector2(-20 * f, 3), tc + Vector2(-28 * f, 7), tc + Vector2(-20 * f, 9)]), skin.darkened(0.2))
			o.draw_colored_polygon(_fell(tc, f, Vector2(18, 0), Vector2(7, 4.5)), skin)
			o.draw_colored_polygon(_fell(tc, f, Vector2(26, -2), Vector2(8, 6.5)), skin)
			o.draw_colored_polygon(_fell(tc, f, Vector2(0, 5), Vector2(20, 5)), Color("d8c27a"))
			var dome := PackedVector2Array()
			var inner := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				dome.append(tc + Vector2(cos(a) * 22.0 * f, 4.0 + sin(a) * 15.0))
				inner.append(tc + Vector2(cos(a) * 13.0 * f, 4.0 + sin(a) * 8.5))
			o.draw_colored_polygon(dome, Color("4a7a32"))
			var scute := Color("35592a")
			o.draw_polyline(inner, scute, 1.5, true)
			for a in [PI * 1.25, PI * 1.5, PI * 1.75]:
				o.draw_line(tc + Vector2(cos(a) * 13.0 * f, 4.0 + sin(a) * 8.5), tc + Vector2(cos(a) * 22.0 * f, 4.0 + sin(a) * 15.0), scute, 1.5)
			o.draw_line(tc + Vector2(-22 * f, 4), tc + Vector2(22 * f, 4), scute, 3.0)
			var shine := PackedVector2Array()
			for i in 5:
				var a := PI * (1.32 + 0.07 * i)
				shine.append(tc + Vector2(cos(a) * 17.0 * f, 4.0 + sin(a) * 11.5))
			o.draw_polyline(shine, Color(1, 1, 1, 0.25), 2.0, true)
			o.draw_colored_polygon(_fell(tc, f, Vector2(12, 8), Vector2(10, 4), 0.6 + sin(t * fl) * 0.45), skin.darkened(0.08))
			var eye := tc + Vector2(29 * f, -4)
			if happy:
				o.draw_arc(eye, 2.2, PI, TAU, 6, Color("1a1410"), 1.5, true)
				for i in 3:
					var ph := fmod(t * 1.2 + i / 3.0, 1.0)
					var mouth := tc + Vector2(33 * f, 0)
					o.draw_arc(mouth + Vector2(sin(ph * 9.0 + i) * 2.0, -ph * (mouth.y - wt - 2.0)), 1.6 + ph * 1.4, 0, TAU, 10, Color(1, 1, 1, 0.75 - ph * 0.4), 1.2, true)
			else:
				o.draw_circle(eye, 1.8, Color("1a1410"))
				o.draw_circle(eye + Vector2(0.6 * f, -0.6), 0.6, Color.WHITE)
			o.draw_line(tc + Vector2(30 * f, 1.5), tc + Vector2(33 * f, 1), skin.darkened(0.45), 1.0)
			# agua por delante (tiñe lo sumergido), cristal, borde de latón y peana de madera
			o.draw_colored_polygon(water, Color(0.28, 0.6, 0.62, 0.12))
			o.draw_line(Vector2(10, 16), Vector2(10, 108), Color(1, 1, 1, 0.35), 2.0)
			o.draw_line(Vector2(160, 16), Vector2(160, 108), Color(1, 1, 1, 0.35), 2.0)
			o.draw_line(Vector2(18, 22), Vector2(18, 92), Color(1, 1, 1, 0.22), 3.0)
			o.draw_line(Vector2(26, 22), Vector2(26, 46), Color(1, 1, 1, 0.15), 2.0)
			o.draw_rect(Rect2(6, 12, 158, 5), Color("b8913f"))
			o.draw_line(Vector2(6, 12), Vector2(164, 12), Color("f0d58f"), 1.5)
			o.draw_rect(Rect2(4, 108, 162, 10), Color("4a2c1a"))
			o.draw_rect(Rect2(4, 108, 162, 2), Color("b8913f"))
			o.draw_rect(Rect2(68, 111, 34, 5), Color("c9a55c"))


## Tamaño de referencia de cada mascota (para escalarla en previsualizaciones)
static func ref_size(kind: String) -> Vector2:
	return {"gato": Vector2(210, 105), "perro": Vector2(210, 160), "loro": Vector2(96, 96), "pez": Vector2(86, 86), "tortuga": Vector2(170, 124)}.get(kind, Vector2(100, 100))
