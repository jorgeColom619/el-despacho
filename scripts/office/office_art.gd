extends RefCounted
## Arte vectorial del despacho, generado como SVG y rasterizado en texturas (con caché).

static var _cache := {}


static func tex(name: String, scale: float = 1.0) -> Texture2D:
	var key := "%s@%s" % [name, scale]
	if _cache.has(key):
		return _cache[key]
	var svg := ""
	match name:
		"room":
			svg = room_svg()
		"desk":
			svg = desk_svg()
		"door_leaf":
			svg = door_leaf_svg()
		"lamp":
			svg = lamp_svg()
		"redphone":
			svg = redphone_svg()
		"phone":
			svg = phone_svg()
		"folder":
			svg = folder_svg()
		"mic":
			svg = mic_svg()
		"monitor":
			svg = monitor_svg()
		"globe_stand":
			svg = globe_stand_svg()
		"mug":
			svg = mug_svg()
		"seal":
			svg = seal_svg(200)
		"podium":
			svg = podium_svg()
	var img := Image.new()
	var err := img.load_svg_from_string(svg, scale)
	if err != OK:
		push_warning("SVG de %s no válido" % name)
		img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


static func _lg(id: String, x1: float, y1: float, x2: float, y2: float, stops: Array) -> String:
	var s := "<linearGradient id='%s' x1='%s' y1='%s' x2='%s' y2='%s'>" % [id, x1, y1, x2, y2]
	for st in stops:
		var op: float = st[2] if st.size() > 2 else 1.0
		s += "<stop offset='%s' stop-color='%s' stop-opacity='%s'/>" % [st[0], st[1], op]
	return s + "</linearGradient>"


static func _rg(id: String, cx: float, cy: float, r: float, stops: Array) -> String:
	var s := "<radialGradient id='%s' cx='%s' cy='%s' r='%s'>" % [id, cx, cy, r]
	for st in stops:
		var op: float = st[2] if st.size() > 2 else 1.0
		s += "<stop offset='%s' stop-color='%s' stop-opacity='%s'/>" % [st[0], st[1], op]
	return s + "</radialGradient>"


static func _r(x: float, y: float, w: float, h: float, fill: String, extra: String = "") -> String:
	return "<rect x='%s' y='%s' width='%s' height='%s' fill='%s' %s/>" % [x, y, w, h, fill, extra]


static func _panel(x: float, y: float, w: float, h: float) -> String:
	var s := _r(x, y, w, h, "url(#wpanel)")
	s += "<path d='M%s %s H%s M%s %s V%s' stroke='#8a5c3c' stroke-opacity='0.55' stroke-width='2'/>" % [x, y + 1, x + w, x + 1, y, y + h]
	s += "<path d='M%s %s H%s M%s %s V%s' stroke='#120804' stroke-opacity='0.7' stroke-width='2'/>" % [x, y + h - 1, x + w, x + w - 1, y, y + h]
	s += _r(x + 14, y + 14, w - 28, h - 28, "url(#wpanel2)", "stroke='#1a0d07' stroke-opacity='0.45' stroke-width='1.5'")
	return s


static func seal_body(cx: float, cy: float, r: float) -> String:
	var s := ""
	s += "<circle cx='%s' cy='%s' r='%s' fill='url(#sealbg)' stroke='url(#gold)' stroke-width='%s'/>" % [cx, cy, r, r * 0.09]
	s += "<circle cx='%s' cy='%s' r='%s' fill='none' stroke='#e9cf8a' stroke-width='%s' stroke-dasharray='%s %s' opacity='0.8'/>" % [cx, cy, r * 0.8, r * 0.025, r * 0.05, r * 0.05]
	var pts := ""
	for i in 16:
		var rr := r * 0.52 if i % 2 == 0 else r * 0.22
		var a := -PI / 2.0 + PI * i / 8.0
		pts += "%s,%s " % [cx + cos(a) * rr, cy + sin(a) * rr]
	s += "<polygon points='%s' fill='url(#gold)'/>" % pts
	s += "<circle cx='%s' cy='%s' r='%s' fill='#1d3557'/>" % [cx, cy, r * 0.1]
	for side in [-1, 1]:
		for i in 9:
			var a := PI * (0.62 + i * 0.075)
			var lx: float = cx + side * cos(a) * r * 1.18
			var ly := cy + sin(a) * r * 1.18 * -1.0 + r * 0.25
			var rot: float = rad_to_deg(a) * side + (90.0 if side > 0 else -90.0)
			s += "<ellipse cx='%s' cy='%s' rx='%s' ry='%s' fill='#b8913f' transform='rotate(%s %s %s)'/>" % [lx, ly, r * 0.07, r * 0.17, rot, lx, ly]
	s += "<path d='M%s %s Q%s %s %s %s L%s %s Q%s %s %s %s Z' fill='#8e2a22'/>" % [cx - r * 0.8, cy + r * 1.0, cx, cy + r * 1.25, cx + r * 0.8, cy + r * 1.0, cx + r * 0.7, cy + r * 1.18, cx, cy + r * 1.4, cx - r * 0.7, cy + r * 1.18]
	return s


static func _common_defs() -> String:
	var d := ""
	d += _lg("gold", 0, 0, 0, 1, [[0, "#f3dc9b"], [0.45, "#c9a55c"], [1, "#8a6a2c"]])
	d += _lg("goldh", 0, 0, 1, 0, [[0, "#8a6a2c"], [0.5, "#f0d58f"], [1, "#8a6a2c"]])
	d += _rg("sealbg", 0.5, 0.4, 0.7, [[0, "#2b4d7e"], [1, "#0f1f38"]])
	return d


static func seal_svg(size: int) -> String:
	return "<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d' viewBox='0 0 200 200'><defs>%s</defs>%s</svg>" % [size, size, _common_defs(), seal_body(100, 88, 62)]


static func room_svg() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var s := PackedStringArray()
	s.append("<svg xmlns='http://www.w3.org/2000/svg' width='1920' height='1080' viewBox='0 0 1920 1080'><defs>")
	s.append(_common_defs())
	s.append(_lg("wall", 0, 0, 0, 1, [[0, "#15271f"], [0.35, "#223d33"], [0.7, "#1f3830"], [1, "#172b24"]]))
	s.append(_lg("wood", 0, 0, 0, 1, [[0, "#5a3522"], [1, "#2c180e"]]))
	s.append(_lg("wpanel", 0, 0, 1, 1, [[0, "#57341f"], [1, "#351e11"]]))
	s.append(_lg("wpanel2", 0, 0, 1, 1, [[0, "#4b2c1a"], [1, "#3a2113"]]))
	s.append(_lg("cream", 0, 0, 1, 1, [[0, "#efe5cf"], [1, "#b9aa8a"]]))
	s.append(_lg("creamv", 0, 0, 0, 1, [[0, "#f1e8d4"], [1, "#c3b393"]]))
	s.append(_lg("carpet", 0, 0, 0, 1, [[0, "#4a1418"], [1, "#2a0a0d"]]))
	s.append(_lg("curtL", 0, 0, 1, 0, [[0, "#3c0c13"], [0.12, "#6d1b27"], [0.22, "#4a1019"], [0.36, "#86283a"], [0.5, "#52131d"], [0.64, "#7c2233"], [0.78, "#4c1019"], [0.9, "#6e1c29"], [1, "#360a10"]]))
	s.append(_lg("curtR", 1, 0, 0, 0, [[0, "#3c0c13"], [0.12, "#6d1b27"], [0.22, "#4a1019"], [0.36, "#86283a"], [0.5, "#52131d"], [0.64, "#7c2233"], [0.78, "#4c1019"], [0.9, "#6e1c29"], [1, "#360a10"]]))
	s.append(_lg("valance", 0, 0, 0, 1, [[0, "#5a1520"], [1, "#3a0c13"]]))
	s.append(_rg("corr", 0.5, 0.35, 0.8, [[0, "#f7dca2"], [0.5, "#b98a52"], [1, "#4a2c16"]]))
	s.append(_lg("corrfloor", 0, 0, 0, 1, [[0, "#6a1c20"], [1, "#9e2a2e"]]))
	s.append(_lg("tvg", 0, 0, 0, 1, [[0, "#26272a"], [1, "#0a0a0b"]]))
	s.append(_lg("clock", 0, 0, 1, 0, [[0, "#3a1f12"], [0.5, "#6a3c24"], [1, "#321a0e"]]))
	s.append(_lg("pole", 0, 0, 1, 0, [[0, "#7a5a22"], [0.5, "#f3dc9b"], [1, "#7a5a22"]]))
	s.append(_lg("flagfold", 0, 0, 1, 0, [[0, "#000", 0.35], [0.18, "#fff", 0.12], [0.34, "#000", 0.3], [0.52, "#fff", 0.1], [0.7, "#000", 0.32], [0.86, "#fff", 0.08], [1, "#000", 0.4]]))
	s.append(_lg("leafg", 0, 0, 1, 1, [[0, "#3f7d3a"], [1, "#1e4a22"]]))
	s.append(_lg("pot", 0, 0, 1, 0, [[0, "#3b2a1e"], [0.5, "#6b4a32"], [1, "#2e2016"]]))
	s.append(_lg("bronze", 0, 0, 1, 1, [[0, "#b08a4a"], [1, "#4a3418"]]))
	s.append("</defs>")
	# --- pared (con hueco para el cristal de la ventana)
	s.append("<path fill-rule='evenodd' d='M0 0 H1920 V720 H0 Z M96 126 H504 V596 H96 Z' fill='url(#wall)'/>")
	for x in range(0, 1920, 56):
		if x > 20 and x < 580:
			continue
		s.append(_r(x + 16, 40, 22, 392, "#ffffff", "opacity='0.022'"))
		for y in range(70, 430, 72):
			s.append("<path d='M%d %d l6 9 -6 9 -6 -9 Z' fill='#e9d9a8' opacity='0.05'/>" % [x + 27, y])
	# moldura superior
	s.append(_r(0, 0, 1920, 32, "url(#wood)"))
	s.append(_r(0, 32, 1920, 5, "url(#gold)"))
	s.append(_r(0, 37, 1920, 5, "#050807", "opacity='0.45'"))
	for x in range(0, 1920, 24):
		s.append(_r(x + 4, 6, 12, 18, "#000000", "opacity='0.18'"))
	# zócalo y paneles de madera
	for seg in [[0, 62], [538, 1920]]:
		s.append(_r(seg[0], 430, seg[1] - seg[0], 18, "url(#wood)"))
		s.append(_r(seg[0], 430, seg[1] - seg[0], 3, "url(#gold)"))
		s.append(_r(seg[0], 448, seg[1] - seg[0], 262, "#2e1a0f"))
	s.append(_r(62, 620, 476, 90, "#2e1a0f"))
	var px := 548
	while px < 1900:
		s.append(_panel(px, 462, 176, 210))
		px += 190
	s.append(_panel(10, 462, 44, 210))
	s.append(_panel(76, 632, 448, 58))
	s.append(_r(0, 688, 1920, 32, "#1d0f08"))
	s.append(_r(0, 688, 1920, 3, "#6b4128", "opacity='0.6'"))
	# alfombra
	s.append(_r(0, 720, 1920, 360, "url(#carpet)"))
	s.append(_r(0, 742, 1920, 4, "#b8913f", "opacity='0.7'"))
	s.append(_r(0, 752, 1920, 2, "#b8913f", "opacity='0.5'"))
	# --- ventana
	s.append("<path fill-rule='evenodd' d='M64 94 H536 V628 H64 Z M96 126 H504 V596 H96 Z' fill='url(#cream)'/>")
	s.append("<path fill-rule='evenodd' d='M76 106 H524 V616 H76 Z M96 126 H504 V596 H96 Z' fill='#000' opacity='0.12'/>")
	s.append(_r(96, 126, 408, 6, "#000", "opacity='0.35'"))
	s.append(_r(96, 126, 6, 470, "#000", "opacity='0.3'"))
	for mx in [228, 364]:
		s.append(_r(mx, 126, 9, 470, "url(#creamv)"))
		s.append(_r(mx + 9, 126, 3, 470, "#000", "opacity='0.25'"))
	for my in [240, 356, 472]:
		s.append(_r(96, my, 408, 8, "url(#creamv)"))
		s.append(_r(96, my + 8, 408, 3, "#000", "opacity='0.22'"))
	s.append("<polygon points='120,126 210,126 96,330 96,215' fill='#ffffff' opacity='0.05'/>")
	s.append("<polygon points='300,126 336,126 180,596 144,596' fill='#ffffff' opacity='0.035'/>")
	s.append("<polygon points='420,126 440,126 330,596 310,596' fill='#ffffff' opacity='0.03'/>")
	s.append(_r(78, 592, 444, 24, "url(#creamv)"))
	s.append(_r(84, 616, 432, 10, "#000", "opacity='0.35'"))
	# cortinas
	s.append("<path d='M0 76 L200 76 C194 200 164 330 154 410 C150 440 164 470 180 522 C200 592 210 650 216 712 L0 712 Z' fill='url(#curtL)'/>")
	s.append("<path d='M600 76 L400 76 C406 200 436 330 446 410 C450 440 436 470 420 522 C400 592 390 650 384 712 L600 712 Z' fill='url(#curtR)'/>")
	s.append("<path d='M0 76 L200 76 C194 200 164 330 154 410 C150 440 164 470 180 522 C200 592 210 650 216 712' fill='none' stroke='#1a0508' stroke-width='3' opacity='0.6'/>")
	s.append("<path d='M600 76 L400 76 C406 200 436 330 446 410 C450 440 436 470 420 522 C400 592 390 650 384 712' fill='none' stroke='#1a0508' stroke-width='3' opacity='0.6'/>")
	for side in [0, 1]:
		var cx := 158.0 if side == 0 else 442.0
		s.append("<ellipse cx='%s' cy='418' rx='34' ry='12' fill='url(#gold)'/>" % cx)
		s.append("<path d='M%s 428 q-6 30 -2 58 l8 0 q4 -28 -2 -58 Z' fill='url(#gold)'/>" % cx)
		s.append("<ellipse cx='%s' cy='490' rx='9' ry='5' fill='#8a6a2c'/>" % (cx + 2.0))
	s.append(_r(10, 64, 580, 8, "url(#goldh)"))
	s.append("<circle cx='12' cy='68' r='12' fill='url(#gold)'/><circle cx='588' cy='68' r='12' fill='url(#gold)'/>")
	var val := "M20 72 H580 V128"
	for i in 12:
		var x0 := 580.0 - i * 46.67
		val += " Q%s 150 %s 128" % [x0 - 23.3, x0 - 46.67]
	val += " Z"
	s.append("<path d='%s' fill='url(#valance)'/>" % val)
	s.append("<path d='M20 96 H580' stroke='#b8913f' stroke-width='3' opacity='0.8'/>")
	for i in 60:
		s.append(_r(22 + i * 9.4, 128 + (sin(i * 0.67) * 0.5 + 0.5) * 16, 2, 12, "#c9a55c", "opacity='0.7'"))
	# --- bandera
	s.append(_r(656, 110, 9, 600, "url(#pole)"))
	s.append("<path d='M660 70 L672 100 L660 112 L648 100 Z' fill='url(#gold)'/>")
	s.append("<circle cx='660' cy='112' r='7' fill='url(#gold)'/>")
	var cloth := [Vector2(665, 130), Vector2(742, 138), Vector2(752, 220), Vector2(736, 330), Vector2(748, 440), Vector2(730, 540), Vector2(700, 560), Vector2(676, 548), Vector2(668, 440)]
	var cloth_pts := PackedVector2Array(cloth)
	var bands := [[Color("1d3557"), -40.0, 60.0], [Color("e9c46a"), 60.0, 150.0], [Color("1d3557"), 150.0, 400.0]]
	for b in bands:
		var band := PackedVector2Array([Vector2(600, 100 + b[1]), Vector2(800, 100 + b[1] + 170.0), Vector2(800, 100 + b[2] + 170.0), Vector2(600, 100 + b[2])])
		var inter := Geometry2D.intersect_polygons(cloth_pts, band)
		for poly in inter:
			var d := "M"
			for p in poly:
				d += " %s %s" % [p.x, p.y]
			s.append("<path d='%s Z' fill='#%s'/>" % [d, b[0].to_html(false)])
	var cd := "M"
	for p in cloth:
		cd += " %s %s" % [p.x, p.y]
	s.append("<path d='%s Z' fill='url(#flagfold)'/>" % cd)
	for i in 14:
		var fx := 676.0 + i * 5.2
		s.append(_r(fx, 548 + sin(i) * 4.0, 2.5, 16, "#d4b060"))
	# --- apliques de pared
	for sx in [770, 1150]:
		s.append("<ellipse cx='%d' cy='262' rx='14' ry='24' fill='url(#gold)'/>" % sx)
		s.append("<path d='M%d 262 q14 -10 22 -34' stroke='url(#gold)' stroke-width='4' fill='none'/>" % sx)
		s.append("<path d='M%d 200 L%d 200 L%d 232 L%d 232 Z' fill='#f4ead2' opacity='0.95'/>" % [sx + 10, sx + 34, sx + 30, sx + 14])
	# --- puerta: pasillo interior
	s.append(_r(840, 178, 240, 522, "url(#corr)"))
	s.append("<polygon points='840,700 1080,700 1004,520 916,520' fill='url(#corrfloor)'/>")
	s.append("<polygon points='840,178 1080,178 1004,290 916,290' fill='#2a1a10' opacity='0.8'/>")
	s.append("<polygon points='840,178 916,290 916,520 840,700' fill='#3a2414' opacity='0.55'/>")
	s.append("<polygon points='1080,178 1004,290 1004,520 1080,700' fill='#3a2414' opacity='0.55'/>")
	s.append(_r(936, 330, 48, 110, "#fff4d6", "opacity='0.55'"))
	s.append("<ellipse cx='960' cy='300' rx='40' ry='16' fill='#fff2cc' opacity='0.6'/>")
	# marco de la puerta
	s.append("<path fill-rule='evenodd' d='M810 152 H1110 V700 H810 Z M840 178 H1080 V700 H840 Z' fill='url(#cream)'/>")
	s.append("<path d='M840 178 H1080' stroke='#000' stroke-width='5' opacity='0.35'/>")
	s.append("<path d='M822 164 H1098 V700 M822 164 V700' stroke='#a8997a' stroke-width='2' fill='none'/>")
	s.append(_r(796, 138, 328, 16, "url(#creamv)"))
	s.append(_r(796, 152, 328, 4, "#000", "opacity='0.3'"))
	s.append(seal_body(960, 82, 40))
	# --- reloj de pie
	s.append("<path d='M1196 334 L1196 232 Q1256 168 1316 232 L1316 334 Z' fill='url(#clock)'/>")
	s.append("<path d='M1190 334 H1322 V344 H1190 Z' fill='#2a160b'/>")
	s.append("<circle cx='1256' cy='262' r='44' fill='url(#gold)'/>")
	s.append("<circle cx='1256' cy='262' r='38' fill='#f1e8d4'/>")
	for i in 12:
		var a := TAU * i / 12.0
		var x1 := 1256.0 + cos(a) * 31.0
		var y1 := 262.0 + sin(a) * 31.0
		var x2 := 1256.0 + cos(a) * 36.0
		var y2 := 262.0 + sin(a) * 36.0
		s.append("<line x1='%s' y1='%s' x2='%s' y2='%s' stroke='#2a2018' stroke-width='%s'/>" % [x1, y1, x2, y2, 3 if i % 3 == 0 else 1.5])
	s.append(_r(1206, 344, 100, 262, "url(#clock)"))
	s.append(_r(1224, 362, 64, 214, "#120905"))
	s.append(_r(1220, 358, 72, 222, "none", "stroke='url(#gold)' stroke-width='4'"))
	s.append(_r(1196, 606, 120, 94, "url(#clock)"))
	s.append(_r(1190, 600, 132, 10, "#2a160b"))
	s.append(_r(1212, 624, 88, 56, "none", "stroke='#8a5a38' stroke-width='2' opacity='0.6'"))
	# --- televisor
	for i in 5:
		s.append(_r(1396 + i * 2, 158 + i * 2, 400, 252, "#000", "opacity='0.07' rx='8'"))
	s.append(_r(1390, 150, 400, 252, "url(#tvg)", "rx='6'"))
	s.append(_r(1402, 162, 376, 226, "#05070b"))
	s.append("<circle cx='1774' cy='396' r='2.5' fill='#3fbf6a'/>")
	# --- credencia con libros
	s.append(_r(1350, 462, 520, 16, "#6a3f26"))
	s.append(_r(1350, 462, 520, 3, "#9a6a46", "opacity='0.7'"))
	s.append(_r(1362, 478, 496, 212, "url(#wood)"))
	for i in 4:
		var dx := 1374 + i * 121
		s.append(_panel(dx, 492, 108, 180))
		s.append("<circle cx='%d' cy='582' r='5' fill='url(#gold)'/>" % (dx + (100 if i % 2 == 0 else 8)))
	var bx := 1374.0
	var cols := ["#6b1d24", "#1f3552", "#2e4a2c", "#8a6a3a", "#1b1b1d", "#5a3a22", "#7a2a1e", "#34405e", "#4a2a3a", "#a08050"]
	while bx < 1600.0:
		var bw := rng.randf_range(11, 22)
		var bh := rng.randf_range(56, 92)
		var col: String = cols[rng.randi() % cols.size()]
		s.append(_r(bx, 462 - bh, bw - 1.5, bh, col))
		s.append(_r(bx, 462 - bh + 8, bw - 1.5, 3, "#c9a55c", "opacity='0.75'"))
		s.append(_r(bx, 462 - 14, bw - 1.5, 2, "#c9a55c", "opacity='0.6'"))
		s.append(_r(bx, 462 - bh, 3, bh, "#fff", "opacity='0.08'"))
		bx += bw
	s.append("<path d='M1606 462 L1640 386 L1656 392 L1624 462 Z' fill='#1f3552'/>")
	s.append("<path d='M1680 462 L1680 440 Q1690 420 1700 400 Q1706 380 1720 372 Q1730 368 1734 380 Q1740 400 1728 420 Q1746 430 1742 462 Z' fill='url(#bronze)'/>")
	s.append("<ellipse cx='1712' cy='462' rx='36' ry='5' fill='#2a1a0c'/>")
	s.append(_r(1760, 392, 64, 70, "url(#gold)", "rx='2'"))
	s.append(_r(1767, 399, 50, 56, "#3a4a5a"))
	s.append("<circle cx='1792' cy='418' r='9' fill='#e0b890'/><path d='M1776 455 Q1792 426 1808 455 Z' fill='#1d2b44'/>")
	# planta
	s.append("<path d='M1846 610 L1910 610 L1900 710 L1856 710 Z' fill='url(#pot)'/>")
	s.append(_r(1840, 602, 76, 12, "#4a3424"))
	var leaves := [[1878, 600, 1830, 470, -30], [1878, 600, 1905, 440, 20], [1878, 600, 1850, 380, -10], [1878, 600, 1920, 520, 45], [1878, 600, 1800, 540, -55], [1878, 600, 1880, 420, 5], [1878, 600, 1830, 600, -80]]
	for lf in leaves:
		s.append("<path d='M%s %s Q%s %s %s %s' stroke='#2a4a22' stroke-width='3' fill='none'/>" % [lf[0], lf[1], (lf[0] + lf[2]) / 2.0 + 10, (lf[1] + lf[3]) / 2.0, lf[2], lf[3]])
		s.append("<ellipse cx='%s' cy='%s' rx='22' ry='44' fill='url(#leafg)' transform='rotate(%s %s %s)'/>" % [lf[2], lf[3], lf[4], lf[2], lf[3]])
		s.append("<path d='M%s %s L%s %s' stroke='#9ccf7a' stroke-width='1.5' opacity='0.5' transform='rotate(%s %s %s)'/>" % [lf[2], lf[3] - 40, lf[2], lf[3] + 40, lf[4], lf[2], lf[3]])
	s.append("</svg>")
	return "".join(s)


static func desk_svg() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var s := PackedStringArray()
	s.append("<svg xmlns='http://www.w3.org/2000/svg' width='1920' height='440' viewBox='0 0 1920 440'><defs>")
	s.append(_common_defs())
	s.append(_lg("top", 0, 0, 0, 1, [[0, "#7a3d26"], [0.25, "#5e2c1b"], [1, "#351810"]]))
	s.append(_lg("leather", 0, 0, 0, 1, [[0, "#23443a"], [1, "#132820"]]))
	s.append(_lg("pad", 0, 0, 0, 1, [[0, "#1c1512"], [1, "#0e0a08"]]))
	s.append(_lg("edge", 0, 0, 0, 1, [[0, "#a86040"], [1, "#5a2c18"]]))
	s.append("</defs>")
	s.append("<polygon points='150,56 1770,56 2040,440 -120,440' fill='url(#top)'/>")
	s.append("<polygon points='150,50 1770,50 1774,58 146,58' fill='url(#edge)'/>")
	s.append("<polygon points='146,58 1774,58 1776,62 144,62' fill='#1a0a05' opacity='0.6'/>")
	for i in 34:
		var t := pow(float(i) / 34.0, 1.35)
		var y := 66.0 + t * 370.0
		var xl := lerpf(150.0, -120.0, (y - 56.0) / 384.0)
		var xr := lerpf(1770.0, 2040.0, (y - 56.0) / 384.0)
		var d := "M%s %s" % [xl, y]
		var segs := 8
		for k in segs:
			var x1 := lerpf(xl, xr, (k + 0.5) / segs)
			var x2 := lerpf(xl, xr, (k + 1.0) / segs)
			d += " Q%s %s %s %s" % [x1, y + rng.randf_range(-4, 4) * (0.5 + t), x2, y + rng.randf_range(-1.5, 1.5)]
		s.append("<path d='%s' stroke='#1c0904' stroke-width='%s' opacity='%s' fill='none'/>" % [d, 1.0 + t * 1.5, rng.randf_range(0.06, 0.16)])
	s.append("<polygon points='262,96 1658,96 1880,440 40,440' fill='url(#leather)'/>")
	s.append("<polygon points='262,96 1658,96 1880,440 40,440' fill='none' stroke='#b8913f' stroke-width='2.5' opacity='0.75'/>")
	s.append("<polygon points='276,106 1644,106 1862,440 58,440' fill='none' stroke='#b8913f' stroke-width='1' opacity='0.45'/>")
	s.append("<polygon points='700,226 1220,226 1300,440 620,440' fill='url(#pad)'/>")
	s.append("<polygon points='700,226 760,226 718,300 660,300' fill='#3a1a10'/>")
	s.append("<polygon points='1160,226 1220,226 1262,300 1202,300' fill='#3a1a10'/>")
	s.append("<polygon points='700,226 1220,226 1300,440 620,440' fill='none' stroke='#b8913f' stroke-width='1.5' opacity='0.5'/>")
	# pluma estilográfica
	s.append("<g transform='rotate(-24 930 330)'><rect x='850' y='322' width='150' height='12' rx='6' fill='#101012'/><rect x='930' y='322' width='10' height='12' fill='url(#gold)'/><path d='M1000 322 L1026 328 L1000 334 Z' fill='url(#gold)'/></g>")
	s.append("</svg>")
	return "".join(s)


static func door_leaf_svg() -> String:
	var s := "<svg xmlns='http://www.w3.org/2000/svg' width='120' height='522' viewBox='0 0 120 522'><defs>"
	s += _common_defs()
	s += _lg("dw", 0, 0, 1, 0, [[0, "#4a2a18"], [0.5, "#5e3721"], [1, "#3f2314"]])
	s += _lg("dp", 0, 0, 1, 1, [[0, "#654028"], [1, "#3a2012"]])
	s += "</defs>"
	s += _r(0, 0, 120, 522, "url(#dw)")
	for pnl in [[14, 22, 92, 220], [14, 272, 92, 228]]:
		s += _r(pnl[0], pnl[1], pnl[2], pnl[3], "url(#dp)", "stroke='#1a0c05' stroke-width='2'")
		s += "<path d='M%s %s H%s M%s %s V%s' stroke='#8a5c3c' stroke-width='2' opacity='0.6'/>" % [pnl[0] + 2, pnl[1] + 2, pnl[0] + pnl[2] - 2, pnl[0] + 2, pnl[1] + 2, pnl[1] + pnl[3] - 2]
		s += _r(pnl[0] + 12, pnl[1] + 12, pnl[2] - 24, pnl[3] - 24, "none", "stroke='#b8913f' stroke-width='1.5' opacity='0.55'")
	s += _r(100, 250, 8, 44, "url(#gold)", "rx='3'")
	s += "<circle cx='104' cy='272' r='9' fill='url(#gold)'/>"
	s += _r(0, 0, 3, 522, "#000", "opacity='0.35'")
	s += "</svg>"
	return s


static func lamp_svg() -> String:
	var s := "<svg xmlns='http://www.w3.org/2000/svg' width='200' height='240' viewBox='0 0 200 240'><defs>"
	s += _common_defs()
	s += _lg("shade", 0, 0, 0, 1, [[0, "#3aa26a"], [0.5, "#16603a"], [1, "#0b3320"]])
	s += "</defs>"
	s += "<ellipse cx='100' cy='228' rx='66' ry='10' fill='#000' opacity='0.35'/>"
	s += "<ellipse cx='100' cy='220' rx='62' ry='14' fill='url(#gold)'/>"
	s += "<ellipse cx='100' cy='214' rx='50' ry='9' fill='#f0d58f' opacity='0.5'/>"
	s += _r(94, 128, 12, 90, "url(#goldh)")
	s += "<circle cx='100' cy='176' r='8' fill='url(#gold)'/>"
	s += "<path d='M14 126 C14 76 186 76 186 126 L186 132 C186 138 14 138 14 132 Z' fill='url(#shade)'/>"
	s += "<path d='M30 104 C60 84 140 84 170 104' stroke='#ffffff' stroke-width='4' opacity='0.28' fill='none' stroke-linecap='round'/>"
	s += _r(12, 128, 176, 7, "url(#goldh)", "rx='3'")
	s += "<ellipse cx='14' cy='112' rx='6' ry='20' fill='url(#gold)'/><ellipse cx='186' cy='112' rx='6' ry='20' fill='url(#gold)'/>"
	s += "<path d='M146 135 V176' stroke='url(#gold)' stroke-width='2'/><circle cx='146' cy='180' r='4' fill='url(#gold)'/>"
	s += "</svg>"
	return s


static func redphone_svg() -> String:
	var s := "<svg xmlns='http://www.w3.org/2000/svg' width='200' height='150' viewBox='0 0 200 150'><defs>"
	s += _common_defs()
	s += _lg("red", 0, 0, 0, 1, [[0, "#e0453e"], [0.5, "#a61c18"], [1, "#5e0c0a"]])
	s += _lg("redh", 0, 0, 0, 1, [[0, "#ff6a5e"], [1, "#8e1612"]])
	s += "</defs>"
	s += "<ellipse cx='100' cy='138' rx='88' ry='10' fill='#000' opacity='0.4'/>"
	s += "<path d='M24 134 L46 62 Q49 52 60 52 L140 52 Q151 52 154 62 L176 134 Q176 138 170 138 L30 138 Q24 138 24 134 Z' fill='url(#red)'/>"
	s += "<path d='M50 62 Q52 56 60 56 L140 56 Q148 56 150 62 L152 70 L48 70 Z' fill='#ff8a7a' opacity='0.25'/>"
	s += "<circle cx='100' cy='100' r='18' fill='url(#gold)'/><circle cx='100' cy='100' r='13' fill='#8e1a14'/>"
	s += "<path d='M100 90 L103 97 L110 97 L104 101 L106 108 L100 104 L94 108 L96 101 L90 97 L97 97 Z' fill='url(#gold)'/>"
	s += "<path d='M16 50 C14 26 38 20 56 26 L144 26 C162 20 186 26 184 50 C184 62 170 64 162 56 L152 44 L48 44 L38 56 C30 64 16 62 16 50 Z' fill='url(#redh)'/>"
	s += "<path d='M56 30 L144 30' stroke='#ffffff' stroke-width='3' opacity='0.3' stroke-linecap='round'/>"
	s += "</svg>"
	return s


static func phone_svg() -> String:
	var s := "<svg xmlns='http://www.w3.org/2000/svg' width='230' height='160' viewBox='0 0 230 160'><defs>"
	s += _lg("ph", 0, 0, 0, 1, [[0, "#3a3c42"], [1, "#101114"]])
	s += _lg("hs", 0, 0, 1, 0, [[0, "#26272b"], [0.5, "#3c3e44"], [1, "#1a1b1e"]])
	s += "</defs>"
	s += "<ellipse cx='118' cy='150' rx='108' ry='9' fill='#000' opacity='0.4'/>"
	s += "<path d='M16 146 L38 40 Q41 30 52 30 L198 30 Q209 30 212 40 L224 146 Q224 150 218 150 L22 150 Q16 150 16 146 Z' fill='url(#ph)'/>"
	s += _r(24, 34, 48, 114, "url(#hs)", "rx='20'")
	s += "<ellipse cx='48' cy='50' rx='18' ry='10' fill='#0c0c0e'/><ellipse cx='48' cy='132' rx='18' ry='10' fill='#0c0c0e'/>"
	s += _r(90, 42, 110, 28, "#2b3a30", "rx='3'")
	for r in 4:
		for c in 3:
			s += _r(100 + c * 32, 82 + r * 16, 26, 11, "#4a4c54", "rx='3'")
	s += "<path d='M40 148 q-6 6 0 12 q6 6 0 12' stroke='#1a1a1c' stroke-width='3' fill='none'/>"
	s += "</svg>"
	return s


static func folder_svg() -> String:
	var s := "<svg xmlns='http://www.w3.org/2000/svg' width='220' height='130' viewBox='0 0 220 130'><defs>"
	s += _common_defs()
	s += _lg("lth", 0, 0, 1, 1, [[0, "#5a2418"], [1, "#2a0e08"]])
	s += "</defs>"
	s += "<ellipse cx='112' cy='122' rx='104' ry='8' fill='#000' opacity='0.4'/>"
	s += "<path d='M22 18 L200 18 L212 116 L8 116 Z' fill='url(#lth)'/>"
	s += "<path d='M30 26 L192 26 L202 108 L18 108 Z' fill='none' stroke='#c9a55c' stroke-width='1.5' opacity='0.8'/>"
	s += "<path d='M22 18 L44 18 L22 40 Z M200 18 L178 18 L200 40 Z' fill='url(#gold)'/>"
	s += _r(150, 112, 8, 16, "#8e2a22")
	s += "</svg>"
	return s


static func mic_svg() -> String:
	var s := "<svg xmlns='http://www.w3.org/2000/svg' width='120' height='200' viewBox='0 0 120 200'><defs>"
	s += _common_defs()
	s += _lg("chrome", 0, 0, 1, 0, [[0, "#6a6a6e"], [0.3, "#f2f2f2"], [0.55, "#9a9aa0"], [1, "#4a4a4e"]])
	s += "</defs>"
	s += "<ellipse cx='60' cy='190' rx='46' ry='8' fill='#000' opacity='0.4'/>"
	s += "<ellipse cx='60' cy='184' rx='42' ry='10' fill='url(#chrome)'/>"
	s += _r(56, 112, 8, 72, "url(#chrome)")
	s += "<path d='M36 112 Q60 128 84 112' stroke='url(#chrome)' stroke-width='5' fill='none'/>"
	s += _r(30, 14, 60, 100, "url(#chrome)", "rx='30'")
	for i in 11:
		s += "<path d='M34 %d H86' stroke='#3a3a3e' stroke-width='2' opacity='0.55'/>" % (26 + i * 8)
	s += _r(28, 60, 64, 10, "url(#goldh)")
	s += "</svg>"
	return s


static func monitor_svg() -> String:
	var s := "<svg xmlns='http://www.w3.org/2000/svg' width='340' height='320' viewBox='0 0 340 320'><defs>"
	s += _lg("alu", 0, 0, 1, 0, [[0, "#6a6c72"], [0.5, "#c8cad0"], [1, "#5a5c62"]])
	s += "</defs>"
	s += "<ellipse cx='170' cy='306' rx='96' ry='12' fill='#000' opacity='0.4'/>"
	s += "<ellipse cx='170' cy='298' rx='84' ry='13' fill='url(#alu)'/>"
	s += _r(150, 224, 40, 76, "url(#alu)")
	s += _r(8, 8, 324, 222, "#0e0f11", "rx='10'")
	s += _r(20, 20, 300, 192, "#05070b")
	s += _r(8, 8, 324, 4, "#fff", "opacity='0.08' rx='2'")
	s += "</svg>"
	return s


static func globe_stand_svg() -> String:
	var s := "<svg xmlns='http://www.w3.org/2000/svg' width='240' height='300' viewBox='0 0 240 300'><defs>"
	s += _common_defs()
	s += _lg("gw", 0, 0, 1, 0, [[0, "#3a1f12"], [0.5, "#7a4a2c"], [1, "#2e180c"]])
	s += "</defs>"
	s += "<ellipse cx='120' cy='288' rx='80' ry='10' fill='#000' opacity='0.4'/>"
	s += "<path d='M60 284 Q120 262 180 284 L170 290 Q120 276 70 290 Z' fill='url(#gw)'/>"
	s += "<path d='M104 280 L108 236 L132 236 L136 280 Z' fill='url(#gw)'/>"
	s += "<path d='M110 236 Q120 228 130 236 L126 222 L114 222 Z' fill='url(#gold)'/>"
	s += "<path d='M120 18 A104 104 0 1 1 119 18' fill='none' stroke='url(#gold)' stroke-width='7' transform='rotate(18 120 122)'/>"
	s += "<circle cx='120' cy='18' r='6' fill='url(#gold)'/>"
	s += "</svg>"
	return s


static func mug_svg() -> String:
	var s := "<svg xmlns='http://www.w3.org/2000/svg' width='100' height='110' viewBox='0 0 100 110'><defs>"
	s += _common_defs()
	s += _lg("cer", 0, 0, 1, 0, [[0, "#c9c4bb"], [0.4, "#fbf8f2"], [1, "#a8a298"]])
	s += "</defs>"
	s += "<ellipse cx='46' cy='102' rx='40' ry='7' fill='#000' opacity='0.4'/>"
	s += "<path d='M70 40 q24 0 24 22 q0 22 -26 22' stroke='url(#cer)' stroke-width='9' fill='none'/>"
	s += "<path d='M12 24 L80 24 L76 94 Q46 104 16 94 Z' fill='url(#cer)'/>"
	s += "<ellipse cx='46' cy='24' rx='34' ry='9' fill='#e9e4da'/>"
	s += "<ellipse cx='46' cy='26' rx='29' ry='6.5' fill='#3a1f10'/>"
	s += "<circle cx='44' cy='62' r='11' fill='url(#gold)'/><circle cx='44' cy='62' r='7' fill='#1d3557'/>"
	s += "</svg>"
	return s


static func podium_svg() -> String:
	var s := "<svg xmlns='http://www.w3.org/2000/svg' width='700' height='420' viewBox='0 0 700 420'><defs>"
	s += _common_defs()
	s += _lg("pw", 0, 0, 1, 0, [[0, "#3a1f12"], [0.5, "#6e4128"], [1, "#2e180c"]])
	s += _lg("pt", 0, 0, 0, 1, [[0, "#8a5234"], [1, "#4a2616"]])
	s += "</defs>"
	s += "<polygon points='60,90 640,90 600,420 100,420' fill='url(#pw)'/>"
	s += "<polygon points='40,40 660,40 640,96 60,96' fill='url(#pt)'/>"
	s += _r(40, 36, 620, 8, "url(#goldh)")
	s += "<polygon points='60,96 640,96 638,106 62,106' fill='#000' opacity='0.4'/>"
	s += seal_body(350, 230, 70)
	s += "<path d='M300 40 L310 0 L316 0 L318 40 Z' fill='#222'/><path d='M382 40 L390 0 L396 0 L400 40 Z' fill='#222'/>"
	s += "</svg>"
	return s
