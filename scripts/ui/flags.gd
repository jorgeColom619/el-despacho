extends RefCounted
## Banderas de los países ficticios (dibujo vectorial inmediato).


static func star_points(c: Vector2, r_out: float, r_in: float, n: int = 5, rot: float = -PI / 2.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var r := r_out if i % 2 == 0 else r_in
		var a := rot + PI * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## Colores principales de cada estilo de bandera nacional (para la bandera colgada del despacho, la banda presidencial, etc.)
static func palette(style: String) -> Array:
	match style:
		"aurora":
			return [Color("1f4d36"), Color("f4f1e8"), Color("1f4d36")]
		"carmesi":
			return [Color("8e1b24"), Color("d4a637"), Color("8e1b24")]
		"marina":
			return [Color("1c5d8c"), Color("f4f4f4"), Color("1c5d8c")]
		"imperial":
			return [Color("141414"), Color("c9a55c"), Color("141414")]
		"nocturna":
			return [Color("0e1530"), Color("b8c0d0"), Color("0e1530")]
	return [Color("1d3557"), Color("e9c46a"), Color("1d3557")]


static func current_style() -> String:
	var pf = Engine.get_main_loop().root.get_node_or_null("Perfil") if Engine.get_main_loop() is SceneTree else null
	if pf != null:
		return pf.flag_style()
	return "clasica"


static func draw_valdoria(ci: CanvasItem, r: Rect2, style: String) -> void:
	var p := r.position
	var w := r.size.x
	var h := r.size.y
	var c := p + Vector2(w / 2.0, h / 2.0)
	match style:
		"aurora":
			ci.draw_rect(Rect2(p, Vector2(w, h)), Color("1f4d36"))
			ci.draw_rect(Rect2(p + Vector2(0, h * 0.3), Vector2(w, h * 0.4)), Color("f4f1e8"))
			for i in 16:
				var a := TAU * i / 16.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * h * 0.13, c + Vector2(cos(a), sin(a)) * h * 0.19, Color("d9a62e"), maxf(1.0, h * 0.02))
			ci.draw_circle(c, h * 0.11, Color("d9a62e"))
		"carmesi":
			ci.draw_rect(Rect2(p, Vector2(w, h)), Color("8e1b24"))
			var rect_poly := PackedVector2Array([p, p + Vector2(w, 0), p + Vector2(w, h), p + Vector2(0, h)])
			var dir := Vector2(w, -h).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			var bw := h * 0.22
			var band := PackedVector2Array([c - dir * w * 2.0 + nrm * bw / 2.0, c + dir * w * 2.0 + nrm * bw / 2.0, c + dir * w * 2.0 - nrm * bw / 2.0, c - dir * w * 2.0 - nrm * bw / 2.0])
			for poly in Geometry2D.intersect_polygons(rect_poly, band):
				ci.draw_colored_polygon(poly, Color("d4a637"))
			ci.draw_colored_polygon(star_points(p + Vector2(w * 0.2, h * 0.27), h * 0.12, h * 0.05), Color("f7f3e8"))
		"marina":
			ci.draw_rect(Rect2(p, Vector2(w, h)), Color("1c5d8c"))
			var wave := PackedVector2Array()
			var steps := 24
			for i in steps + 1:
				var x := w * i / steps
				wave.append(p + Vector2(x, h * 0.5 + sin(i * 0.8) * h * 0.06 - h * 0.09))
			for i in range(steps, -1, -1):
				var x2 := w * i / steps
				wave.append(p + Vector2(x2, h * 0.5 + sin(i * 0.8) * h * 0.06 + h * 0.09))
			ci.draw_colored_polygon(wave, Color("f4f4f4"))
			for i in 3:
				ci.draw_colored_polygon(star_points(p + Vector2(w * (0.12 + i * 0.1), h * 0.18), h * 0.06, h * 0.025), Color("f4f4f4"))
		"imperial":
			ci.draw_rect(Rect2(p, Vector2(w, h)), Color("141414"))
			ci.draw_rect(Rect2(p + Vector2(0, h * 0.08), Vector2(w, h * 0.05)), Color("c9a55c"))
			ci.draw_rect(Rect2(p + Vector2(0, h * 0.87), Vector2(w, h * 0.05)), Color("c9a55c"))
			for side in [-1.0, 1.0]:
				for i in 7:
					var a2 := PI * (0.6 + i * 0.11)
					var lp := c + Vector2(side * cos(a2) * h * 0.24, -sin(a2) * h * 0.24 + h * 0.06)
					ci.draw_circle(lp, h * 0.035, Color("c9a55c"))
			ci.draw_colored_polygon(star_points(c, h * 0.1, h * 0.045), Color("c9a55c"))
		"nocturna":
			ci.draw_rect(Rect2(p, Vector2(w, h)), Color("0e1530"))
			ci.draw_rect(Rect2(p + Vector2(h * 0.05, h * 0.05), Vector2(w - h * 0.1, h * 0.9)), Color("b8c0d0"), false, maxf(1.0, h * 0.015))
			ci.draw_colored_polygon(star_points(c, h * 0.3, h * 0.06, 4, 0.0), Color("b8c0d0"))
			ci.draw_colored_polygon(star_points(c, h * 0.18, h * 0.05, 4, PI / 4.0), Color("7d879c"))
			ci.draw_circle(c, h * 0.04, Color("0e1530"))
		_:
			ci.draw_rect(Rect2(p, Vector2(w, h)), Color("1d3557"))
			ci.draw_rect(Rect2(p + Vector2(0, h / 3.0), Vector2(w, h / 3.0)), Color("e9c46a"))
			ci.draw_colored_polygon(star_points(c, h * 0.15, h * 0.065, 8), Color("f7f3e8"))


static func draw_flag(ci: CanvasItem, id: String, r: Rect2) -> void:
	var p := r.position
	var w := r.size.x
	var h := r.size.y
	match id:
		"valdoria":
			draw_valdoria(ci, r, current_style())
		"norland":
			# azul marino con banda diagonal blanca ribeteada en rojo y estrella
			ci.draw_rect(Rect2(p, Vector2(w, h)), Color("15285a"))
			var rect_poly := PackedVector2Array([p, p + Vector2(w, 0), p + Vector2(w, h), p + Vector2(0, h)])
			var dir := Vector2(w, -h).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			var cc := p + Vector2(w / 2.0, h / 2.0)
			for spec in [[h * 0.42, Color("c1272d")], [h * 0.28, Color("f4f4f4")]]:
				var bw: float = spec[0]
				var band := PackedVector2Array([cc - dir * w * 2.0 + nrm * bw / 2.0, cc + dir * w * 2.0 + nrm * bw / 2.0, cc + dir * w * 2.0 - nrm * bw / 2.0, cc - dir * w * 2.0 - nrm * bw / 2.0])
				for poly in Geometry2D.intersect_polygons(rect_poly, band):
					ci.draw_colored_polygon(poly, spec[1])
			ci.draw_colored_polygon(star_points(p + Vector2(w * 0.18, h * 0.26), h * 0.12, h * 0.05), Color("f4f4f4"))
		"union":
			# azul con arco de nueve estrellas doradas y estrella polar central
			ci.draw_rect(Rect2(p, Vector2(w, h)), Color("24407e"))
			for i in 9:
				var a := PI * 0.1 + PI * 0.8 * i / 8.0
				var c := p + Vector2(w / 2.0, h * 0.62) + Vector2(-cos(a), -sin(a)) * h * 0.34
				ci.draw_colored_polygon(star_points(c, h * 0.045, h * 0.02), Color("f2c94c"))
			ci.draw_colored_polygon(star_points(p + Vector2(w / 2.0, h * 0.6), h * 0.11, h * 0.035, 4, 0.0), Color("f2c94c"))
		"kharovia":
			ci.draw_rect(Rect2(p, Vector2(w, h)), Color("8e1b1b"))
			ci.draw_rect(Rect2(p, Vector2(w * 0.28, h)), Color("141414"))
			ci.draw_colored_polygon(star_points(p + Vector2(w * 0.14, h / 2.0), h * 0.16, h * 0.07), Color("e0b54a"))
			ci.draw_rect(Rect2(p + Vector2(w * 0.28, h * 0.46), Vector2(w * 0.72, h * 0.08)), Color("141414"))
		"tsaing":
			ci.draw_rect(Rect2(p, Vector2(w, h)), Color("c8102e"))
			ci.draw_circle(p + Vector2(w * 0.35, h * 0.5), h * 0.28, Color("f5c518"))
			ci.draw_circle(p + Vector2(w * 0.35, h * 0.5), h * 0.2, Color("c8102e"))
			ci.draw_circle(p + Vector2(w * 0.35, h * 0.5), h * 0.12, Color("f5c518"))
		"sarvenia":
			ci.draw_rect(Rect2(p, Vector2(w, h / 2.0)), Color("2f6b2f"))
			ci.draw_rect(Rect2(p + Vector2(0, h / 2.0), Vector2(w, h / 2.0)), Color("e0c341"))
			ci.draw_colored_polygon(PackedVector2Array([p, p + Vector2(w * 0.36, h / 2.0), p + Vector2(0, h)]), Color("b3261e"))
		"qadar":
			# granate arriba, arena abajo, separados por una línea blanca en zigzag, sol blanco
			ci.draw_rect(Rect2(p, Vector2(w, h)), Color("d9b36a"))
			var pts := PackedVector2Array([p, p + Vector2(w, 0)])
			var n := 10
			for i in range(n, -1, -1):
				var x := w * i / n
				pts.append(p + Vector2(x, h * (0.6 if i % 2 == 0 else 0.68)))
			ci.draw_colored_polygon(pts, Color("7a1f35"))
			ci.draw_polyline(pts.slice(2), Color("f4f4f4"), maxf(2.0, h * 0.025))
			ci.draw_circle(p + Vector2(w * 0.25, h * 0.3), h * 0.1, Color("f4f4f4"))
		"aldora":
			# tricolor vertical verde, oro y celeste con estrella negra
			ci.draw_rect(Rect2(p, Vector2(w / 3.0 + 1, h)), Color("2e7d4f"))
			ci.draw_rect(Rect2(p + Vector2(w / 3.0, 0), Vector2(w / 3.0 + 1, h)), Color("f2b632"))
			ci.draw_rect(Rect2(p + Vector2(w * 2.0 / 3.0, 0), Vector2(w / 3.0, h)), Color("4fa3d9"))
			ci.draw_colored_polygon(star_points(p + Vector2(w / 2.0, h / 2.0), h * 0.16, h * 0.065), Color("141414"))
		_:
			ci.draw_rect(Rect2(p, Vector2(w, h)), Color("777777"))
