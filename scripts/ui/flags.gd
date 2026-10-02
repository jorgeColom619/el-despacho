extends RefCounted
## Banderas de los países ficticios (dibujo vectorial inmediato).


static func star_points(c: Vector2, r_out: float, r_in: float, n: int = 5, rot: float = -PI / 2.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var r := r_out if i % 2 == 0 else r_in
		var a := rot + PI * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func draw_flag(ci: CanvasItem, id: String, r: Rect2) -> void:
	var p := r.position
	var w := r.size.x
	var h := r.size.y
	match id:
		"valdoria":
			ci.draw_rect(Rect2(p, Vector2(w, h)), Color("1d3557"))
			ci.draw_rect(Rect2(p + Vector2(0, h / 3.0), Vector2(w, h / 3.0)), Color("e9c46a"))
			ci.draw_colored_polygon(star_points(p + Vector2(w / 2.0, h / 2.0), h * 0.15, h * 0.065, 8), Color("f7f3e8"))
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
