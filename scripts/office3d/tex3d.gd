extends RefCounted
## Texturas del despacho 3D generadas por código, con mapa de relieve (normal map): madera, parqué,
## papel pintado de damasco, alfombra persa, cuero (liso y capitoné), mármol, yeso, terciopelo,
## latón cepillado, lomos de libros, hojas y flecos. Se guardan en user:// la primera vez y se
## preparan en segundo plano desde el menú, así el despacho carga al instante.

const VERSION := "3"
const DIR := "user://tex3d/"

static var _cache := {}
static var _task := -1


# ------------------------------------------------------------------ API

## Devuelve {"albedo": Texture2D, "normal": Texture2D o null} para una textura
static func get_set(kind: String, p: Dictionary = {}) -> Dictionary:
	var key := _key(kind, p)
	if _cache.has(key):
		return _cache[key]
	wait_prewarm()
	_ensure(kind, p)
	var out := {"albedo": _load(DIR + key + "_a.png"), "normal": null}
	if FileAccess.file_exists(DIR + key + "_n.png"):
		out["normal"] = _load(DIR + key + "_n.png")
	_cache[key] = out
	return out


## Prepara en un hilo las texturas que va a necesitar el despacho
static func prewarm(specs: Array) -> void:
	if _task != -1:
		return
	_task = WorkerThreadPool.add_task(func():
		for s in specs:
			_ensure(s[0], s[1]))


static func wait_prewarm() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## Lista de texturas de la sala con los objetos equipados en la tienda
static func default_specs(theme: Dictionary, wood: String) -> Array:
	var out := [
		["wood", wood_params(wood)], ["wood", wood_params("caoba")], ["wood", wood_params("ebano")], ["wood", wood_params("panel")],
		["wood", wood_params("marmol")], ["parquet", {}], ["leather", {}], ["tufted", {}], ["plaster", {}], ["velvet", {}],
		["brushed", {}], ["leaf", {}], ["fringe", {}],
		["wallpaper", {"c0": theme["wall"][1], "c1": theme["wall"][2], "acc": theme["damask"]}],
		["carpet", {"c0": theme["carpet"][0], "c1": theme["carpet"][1]}],
	]
	for c in SPINES:
		out.append(["spine", {"c": c}])
	return out


const SPINES := ["6b1d24", "1f3552", "2e4a2c", "8a6a3a", "1b1b1d", "5a3a22", "7a2a1e", "34405e", "4a2a3a", "a08050"]

const WOODS := {
	"caoba": ["8a4a2e", "3a1a0e", "1c0904"],
	"roble": ["c49a66", "7a5530", "4a3018"],
	"ebano": ["3e3530", "15110e", "000000"],
	"marmol": ["f2efe9", "c9c4ba", "6a6a72"],
	"panel": ["7a4a2c", "321a0c", "1a0b05"],
}


static func wood_params(name: String) -> Dictionary:
	var w: Array = WOODS.get(name, WOODS["caoba"])
	return {"l": w[0], "d": w[1], "g": w[2], "m": name == "marmol", "s": absi(name.hash()) % 97}


# ------------------------------------------------------------------ caché

static func _key(kind: String, p: Dictionary) -> String:
	return "%s_%s" % [kind, (VERSION + JSON.stringify(p, "", true)).md5_text().substr(0, 12)]


static func _load(path: String) -> Texture2D:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		img = Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _ensure(kind: String, p: Dictionary) -> void:
	var key := _key(kind, p)
	if FileAccess.file_exists(DIR + key + "_a.png"):
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	var r: Dictionary = _generate(kind, p)
	if r.has("h"):
		var hn: Image = r["h"]
		hn.bump_map_to_normal_map(float(r.get("bump", 2.0)))
		hn.save_png(DIR + key + "_n.png")
	(r["a"] as Image).save_png(DIR + key + "_a.png")


static func _generate(kind: String, p: Dictionary) -> Dictionary:
	match kind:
		"wood":
			return _wood(p)
		"parquet":
			return _parquet()
		"wallpaper":
			return _wallpaper(Color(p["c0"]), Color(p["c1"]), Color(p["acc"]))
		"carpet":
			return _carpet(Color(p["c0"]), Color(p["c1"]))
		"leather":
			return _leather()
		"tufted":
			return _tufted()
		"plaster":
			return _plain_noise(0.09, 0.96, 0.04, 1.5)
		"velvet":
			return _velvet()
		"brushed":
			return _brushed()
		"spine":
			return _spine(Color(p["c"]))
		"leaf":
			return _leaf()
		"fringe":
			return _fringe()
	return {"a": Image.create(4, 4, false, Image.FORMAT_RGB8)}


# ------------------------------------------------------------------ utilidades

static func _noise(seed_v: int, freq: float, w: int, h: int, octaves := 3, type := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> PackedByteArray:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	n.noise_type = type
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = octaves
	var img := n.get_seamless_image(w, h)
	img.convert(Image.FORMAT_L8)
	return img.get_data()


static func _img(w: int, h: int, data: PackedByteArray, fmt := Image.FORMAT_RGB8) -> Image:
	return Image.create_from_data(w, h, false, fmt, data)


static func _put(data: PackedByteArray, i: int, c: Color) -> void:
	data[i] = clampi(int(c.r * 255.0), 0, 255)
	data[i + 1] = clampi(int(c.g * 255.0), 0, 255)
	data[i + 2] = clampi(int(c.b * 255.0), 0, 255)


static func _hput(data: PackedByteArray, i: int, v: float) -> void:
	var b := clampi(int(v * 255.0), 0, 255)
	data[i] = b
	data[i + 1] = b
	data[i + 2] = b


# ------------------------------------------------------------------ generadores

## Madera con anillos, fibras y poros (o mármol con vetas). Las vetas corren a lo largo de X.
static func _wood(p: Dictionary) -> Dictionary:
	var W := 512
	var light := Color(p["l"])
	var dark := Color(p["d"])
	var grain := Color(p["g"])
	var sd := int(p["s"])
	var warp := _noise(sd, 0.018, 128, 512, 3)
	var fib := _noise(sd + 1, 0.09, 64, 512, 2)
	var pores := _noise(sd + 2, 0.45, 512, 512, 1)
	var big := _noise(sd + 3, 0.008, 512, 512, 2)
	var a := PackedByteArray()
	a.resize(W * W * 3)
	var h := PackedByteArray()
	h.resize(W * W * 3)
	var marble: bool = p["m"]
	for y in W:
		for x in W:
			var i := y * W + x
			var wv := warp[y * 128 + (x >> 2)] / 255.0
			var fv := fib[y * 64 + (x >> 3)] / 255.0
			var pv := pores[i] / 255.0
			var bv := big[i] / 255.0
			var c: Color
			var hv: float
			if marble:
				var s1 := absf(sin((x / 512.0) * TAU * 2.0 + (y / 512.0) * TAU * 3.0 + bv * 9.0))
				var s2 := absf(sin((x / 512.0) * TAU * 5.0 - (y / 512.0) * TAU * 2.0 + wv * 6.0))
				var vein := pow(1.0 - s1, 14.0) + pow(1.0 - s2, 30.0) * 0.6
				c = light.lerp(dark, bv * 0.35 + fv * 0.08).lerp(grain, clampf(vein, 0.0, 1.0) * 0.7)
				hv = 0.6 - vein * 0.15
			else:
				var ring := sin((y / 512.0) * TAU * 9.0 + wv * 8.0 + bv * 3.0) * 0.5 + 0.5
				var r3 := ring * ring * ring
				var t := clampf(0.22 + ring * 0.38 + (fv - 0.5) * 0.55 + (bv - 0.5) * 0.25, 0.0, 1.0)
				c = light.lerp(dark, t).lerp(grain, r3 * 0.3)
				var pore := maxf(0.0, pv - 0.72) * 2.2
				c = c.darkened(pore * 0.35)
				hv = 0.55 + (1.0 - r3) * 0.18 + (fv - 0.5) * 0.18 - pore * 0.35
			_put(a, i * 3, c)
			_hput(h, i * 3, hv)
	return {"a": _img(W, W, a), "h": _img(W, W, h), "bump": 1.6 if not marble else 0.6}


## Parqué de cestería (bloques de tres tablas alternando dirección); la imagen cubre 1,2 m
static func _parquet() -> Dictionary:
	var W := 512
	var B := 128
	var warp := _noise(41, 0.02, 512, 512, 3)
	var fib := _noise(42, 0.12, 512, 512, 2)
	var light := Color("7a4a2c")
	var dark := Color("3a1f10")
	var a := PackedByteArray()
	a.resize(W * W * 3)
	var h := PackedByteArray()
	h.resize(W * W * 3)
	var pw := B / 3.0
	for y in W:
		for x in W:
			var i := y * W + x
			var bx := x / B
			var by := y / B
			var horiz := (bx + by) % 2 == 0
			var lx := x % B
			var ly := y % B
			var across := ly if horiz else lx
			var along := x if horiz else y
			var idx := int(across / pw)
			var seed_v := absi(hash(Vector3i(bx, by, idx))) % 1000
			var tone := (seed_v % 100) / 100.0
			var acr := across - idx * pw
			var wv := warp[((int(acr * 3.0) + seed_v) % 512) * 512 + along % 512] / 255.0
			var fv := fib[(along % 512) * 512 + (int(acr * 4.0) + seed_v * 3) % 512] / 255.0
			var ring := sin(acr * 0.42 + wv * 9.0 + seed_v) * 0.5 + 0.5
			var c := light.lerp(dark, clampf(0.15 + tone * 0.4 + ring * 0.3 + (fv - 0.5) * 0.4, 0.0, 1.0))
			var seam := acr < 1.2 or (lx < 1 or ly < 1)
			var hv := 0.7 + ring * 0.08 + (fv - 0.5) * 0.1
			if seam:
				c = c.darkened(0.6)
				hv = 0.1
			_put(a, i * 3, c)
			_hput(h, i * 3, hv)
	return {"a": _img(W, W, a), "h": _img(W, W, h), "bump": 3.0}


## Papel pintado de damasco (tono sobre tono, aterciopelado y en relieve); la imagen cubre 0,9 m
static func _wallpaper(c0: Color, c1: Color, acc: Color) -> Dictionary:
	var W := 512
	var fine := _noise(51, 0.3, 512, 512, 1)
	var a := PackedByteArray()
	a.resize(W * W * 3)
	var h := PackedByteArray()
	h.resize(W * W * 3)
	for y in W:
		for x in W:
			var i := y * W + x
			var base := c0 if (x / 32) % 2 == 0 else c0.lerp(c1, 0.55)
			var m := 0.0
			for ctr in [Vector2(128, 128), Vector2(384, 384)]:
				var dx := wrapf(x - ctr.x, -256.0, 256.0)
				var dy := wrapf(y - ctr.y, -256.0, 256.0)
				var r := sqrt(dx * dx + dy * dy * 0.62)
				var th := atan2(dy, dx)
				var lobe := 96.0 * pow(0.45 + 0.55 * absf(cos(2.0 * th)), 0.8)
				if r < lobe:
					m = maxf(m, 0.42)
				if absf(r - lobe) < 3.2:
					m = maxf(m, 0.95)
				var inner := 36.0 * (0.6 + 0.4 * absf(cos(4.0 * th)))
				if r < inner:
					m = maxf(m, 0.8 if r > inner - 4.0 else 0.25)
				if absf(r - 64.0) < 2.4 and absf(sin(4.0 * th)) > 0.55:
					m = maxf(m, 0.9)
				if absf(dx) < 2.2 and absf(dy) > lobe * 0.8 and absf(dy) < 150.0:
					m = maxf(m, 0.7)
			for ctr2 in [Vector2(384, 128), Vector2(128, 384)]:
				var ex := wrapf(x - ctr2.x, -256.0, 256.0)
				var ey := wrapf(y - ctr2.y, -256.0, 256.0)
				var r2 := sqrt(ex * ex + ey * ey)
				var th2 := atan2(ey, ex)
				if r2 < 26.0 * (0.45 + 0.55 * absf(cos(2.0 * th2))):
					m = maxf(m, 0.6)
			var fv := fine[i] / 255.0
			var c := base.lerp(acc, m * 0.17).darkened((fv - 0.5) * 0.05)
			_put(a, i * 3, c)
			_hput(h, i * 3, 0.45 + m * 0.4 + fv * 0.05)
	return {"a": _img(W, W, a), "h": _img(W, W, h), "bump": 2.0}


## Alfombra persa: cenefas con rosetas, campo con celosía floral, medallón central y esquinas
static func _carpet(c0: Color, c1: Color) -> Dictionary:
	var W := 800
	var H := 640
	var pile := _noise(61, 0.35, 800, 640, 1)
	var abrash := _noise(62, 0.01, 800, 640, 2)
	var gold := Color("c9a050")
	var ivory := Color("e6d6b4")
	var navy := Color("1f2a44")
	var a := PackedByteArray()
	a.resize(W * H * 3)
	var h := PackedByteArray()
	h.resize(W * H * 3)
	var cx := W / 2.0
	var cy := H / 2.0
	for y in H:
		for x in W:
			var i := y * W + x
			var ex := mini(x, W - 1 - x)
			var ey := mini(y, H - 1 - y)
			var e := mini(ex, ey)
			var c: Color
			var edge := 0.0
			if e < 9:
				c = c1.darkened(0.2)
				if (x + y) % 12 < 2 and e > 2 and e < 7:
					c = ivory
			elif e < 12:
				c = gold
				edge = 1.0
			elif e < 66:
				c = navy
				var s := float(y if ex < ey else x)
				var lu := fposmod(s, 56.0) - 28.0
				var lv := float(e) - 39.0
				var rr := sqrt(lu * lu + lv * lv)
				var tt := atan2(lv, lu)
				if rr < 17.0 * (0.62 + 0.38 * cos(6.0 * tt)):
					c = gold if rr > 7.0 else c0
					edge = 0.5
				elif absf(lv) < 2.0 or (absf(absf(lu) - 28.0) < 2.0 and absf(lv) < 18.0):
					c = c0.darkened(0.15)
				elif absf(lu) + absf(lv) < 6.0:
					c = ivory
			elif e < 69:
				c = gold
				edge = 1.0
			elif e < 82:
				c = c1
				if (x * 7 + y * 3) % 17 == 0:
					c = ivory
			elif e < 85:
				c = gold
				edge = 1.0
			else:
				c = c0.lerp(c0.darkened(0.25), abrash[i] / 255.0 * 0.6)
				var lx := fposmod(float(x - cx), 64.0) - 32.0
				var ly := fposmod(float(y - cy), 64.0) - 32.0
				var ld := absf(lx) + absf(ly)
				if ld < 9.0:
					c = ivory if ld < 4.0 else navy
				elif absf(ld - 30.0) < 1.4:
					c = c.darkened(0.25)
				var dx := (x - cx) / 1.15
				var dy := float(y - cy)
				var d := sqrt(dx * dx + dy * dy)
				var th := atan2(dy, dx)
				var rs := 170.0 * (0.84 + 0.16 * cos(16.0 * th))
				if d < rs:
					c = navy
					if d < 118.0:
						c = ivory if d > 70.0 else c0
						var st := 60.0 * (0.7 + 0.3 * cos(8.0 * th))
						if d < st and d > 22.0:
							c = c1
						if d < 22.0:
							c = gold
					if absf(d - rs) < 3.5 or absf(d - 118.0) < 2.5 or absf(d - 70.0) < 2.0:
						c = gold
						edge = 1.0
				for k in 4:
					var qx := 85.0 if k % 2 == 0 else W - 86.0
					var qy := 85.0 if k < 2 else H - 86.0
					var qd := Vector2((x - qx) / 1.15, y - qy).length()
					var qt := atan2(y - qy, x - qx)
					var qr := 150.0 * (0.82 + 0.18 * cos(8.0 * qt))
					if qd < qr:
						c = navy if qd > 60.0 else c1
						if absf(qd - qr) < 3.0 or absf(qd - 60.0) < 2.0:
							c = gold
							edge = 1.0
			var pv := pile[i] / 255.0
			c = c.darkened((pv - 0.5) * 0.12)
			_put(a, i * 3, c)
			_hput(h, i * 3, 0.5 + (pv - 0.5) * 0.5 - edge * 0.08)
	return {"a": _img(W, H, a), "h": _img(W, H, h), "bump": 2.5}


## Cuero con grano (gris claro: se tiñe con el color del material)
static func _leather() -> Dictionary:
	var W := 256
	var cell := _noise(71, 0.09, 256, 256, 1, FastNoiseLite.TYPE_CELLULAR)
	var soft := _noise(72, 0.03, 256, 256, 2)
	var a := PackedByteArray()
	a.resize(W * W * 3)
	var h := PackedByteArray()
	h.resize(W * W * 3)
	for i in W * W:
		var cv := cell[i] / 255.0
		var sv := soft[i] / 255.0
		var g := 0.8 + cv * 0.12 - (sv - 0.5) * 0.12
		_put(a, i * 3, Color(g, g, g))
		_hput(h, i * 3, 0.4 + cv * 0.5)
	return {"a": _img(W, W, a), "h": _img(W, W, h), "bump": 3.0}


## Cuero capitoné: almohadillas en rombo, pliegues y botones (una imagen = 2 rombos)
static func _tufted() -> Dictionary:
	var W := 256
	var cell := _noise(73, 0.18, 256, 256, 1, FastNoiseLite.TYPE_CELLULAR)
	var a := PackedByteArray()
	a.resize(W * W * 3)
	var h := PackedByteArray()
	h.resize(W * W * 3)
	for y in W:
		for x in W:
			var i := y * W + x
			var m1 := posmod(x - y, 256)
			var m2 := posmod(x + y, 256)
			var d1 := mini(m1, 256 - m1)
			var d2 := mini(m2, 256 - m2)
			var dc := minf(d1, d2) * 0.7071
			var puff := sqrt(clampf(dc / 40.0, 0.0, 1.0))
			var db := minf(Vector2(wrapf(x, -128.0, 128.0), wrapf(y, -128.0, 128.0)).length(), Vector2(x - 128.0, y - 128.0).length())
			var hv := 0.15 + puff * 0.75
			var g := 0.5 + puff * 0.38 + (cell[i] / 255.0) * 0.06
			if db < 9.0:
				hv = 0.55 + (9.0 - db) / 9.0 * 0.3
				g = 0.42 + (9.0 - db) / 9.0 * 0.2
			elif db < 14.0:
				hv = 0.05
				g = 0.3
			_put(a, i * 3, Color(g, g, g))
			_hput(h, i * 3, hv)
	return {"a": _img(W, W, a), "h": _img(W, W, h), "bump": 6.0}


static func _plain_noise(freq: float, base: float, amp: float, bump: float) -> Dictionary:
	var W := 256
	var n := _noise(81, freq, 256, 256, 3)
	var a := PackedByteArray()
	a.resize(W * W * 3)
	var h := PackedByteArray()
	h.resize(W * W * 3)
	for i in W * W:
		var v := n[i] / 255.0
		var g := base - (v - 0.5) * amp
		_put(a, i * 3, Color(g, g, g))
		_hput(h, i * 3, v)
	return {"a": _img(W, W, a), "h": _img(W, W, h), "bump": bump}


static func _velvet() -> Dictionary:
	var W := 256
	var n := _noise(91, 0.06, 32, 256, 2)
	var f := _noise(92, 0.5, 256, 256, 1)
	var a := PackedByteArray()
	a.resize(W * W * 3)
	var h := PackedByteArray()
	h.resize(W * W * 3)
	for y in W:
		for x in W:
			var i := y * W + x
			var v := n[(x >> 3) + y * 32] / 255.0
			var g := 0.86 + (v - 0.5) * 0.18 + (f[i] / 255.0 - 0.5) * 0.06
			_put(a, i * 3, Color(g, g, g))
			_hput(h, i * 3, v * 0.8 + f[i] / 255.0 * 0.2)
	return {"a": _img(W, W, a), "h": _img(W, W, h), "bump": 1.5}


static func _brushed() -> Dictionary:
	var W := 256
	var n := _noise(95, 0.25, 256, 16, 1)
	var a := PackedByteArray()
	a.resize(W * W * 3)
	var h := PackedByteArray()
	h.resize(W * W * 3)
	for y in W:
		for x in W:
			var i := y * W + x
			var v := n[(y >> 4) * 256 + x] / 255.0
			var g := 0.9 + (v - 0.5) * 0.12
			_put(a, i * 3, Color(g, g, g))
			_hput(h, i * 3, v)
	return {"a": _img(W, W, a), "h": _img(W, W, h), "bump": 0.8}


## Lomo de libro encuadernado: nervios dorados, tejuelo y título
static func _spine(col: Color) -> Dictionary:
	var W := 64
	var H := 256
	var n := _noise(int(col.r * 1000), 0.2, 64, 256, 1)
	var a := PackedByteArray()
	a.resize(W * H * 3)
	var h := PackedByteArray()
	h.resize(W * H * 3)
	var gold := Color("d8b46a")
	var label := col.darkened(0.45)
	for y in H:
		for x in W:
			var i := y * W + x
			var u := (x + 0.5) / W
			var round_shade := 0.72 + 0.28 * sin(u * PI)
			var c := col * round_shade
			var hv := 0.5 + sin(u * PI) * 0.2
			for band in [18, 44, 196, 226]:
				if absi(y - band) <= 3:
					c = gold * (0.75 + 0.25 * sin(u * PI))
					hv = 0.95
			if y >= 64 and y <= 124 and x > 7 and x < W - 8:
				c = label * round_shade
				if y == 66 or y == 122 or x == 9 or x == W - 10:
					c = gold
				elif (y >= 82 and y <= 86 or y >= 98 and y <= 101) and x > 14 and x < W - 15 and (x / 3) % 3 != 0:
					c = gold
			c = c.darkened((n[i] / 255.0 - 0.5) * 0.15)
			_put(a, i * 3, c)
			_hput(h, i * 3, hv)
	return {"a": _img(W, H, a), "h": _img(W, H, h), "bump": 3.0}


## Hoja con nervios (RGBA, con transparencia fuera de la silueta)
static func _leaf() -> Dictionary:
	var W := 128
	var H := 256
	var a := PackedByteArray()
	a.resize(W * H * 4)
	var base := Color("2f6b2e")
	var tip := Color("4f8f3a")
	for y in H:
		for x in W:
			var i := (y * W + x) * 4
			var t := 1.0 - float(y) / (H - 1)
			var hw := 58.0 * pow(sin(PI * clampf(t * 1.02, 0.0, 1.0)), 0.75)
			var dx := absf(x - W / 2.0)
			var inside := dx < hw
			var c := base.lerp(tip, t)
			if dx < 1.8:
				c = c.lightened(0.35)
			elif inside:
				var vein := fposmod(y + dx * 0.9, 22.0)
				if vein < 1.5:
					c = c.lightened(0.15)
				if dx > hw - 3.0:
					c = c.darkened(0.25)
			data_put_rgba(a, i, c, 1.0 if inside else 0.0)
	return {"a": _img(W, H, a, Image.FORMAT_RGBA8)}


static func data_put_rgba(a: PackedByteArray, i: int, c: Color, alpha: float) -> void:
	_put(a, i, c)
	a[i + 3] = int(alpha * 255.0)


## Flecos (RGBA): hilos verticales
static func _fringe() -> Dictionary:
	var W := 128
	var H := 32
	var a := PackedByteArray()
	a.resize(W * H * 4)
	for y in H:
		for x in W:
			var i := (y * W + x) * 4
			var strand := x % 4 < 2
			var slen := 26 + (absi(hash(x / 4)) % 6)
			var on := strand and y < slen
			data_put_rgba(a, i, Color(0.93, 0.88, 0.76).darkened(float(y) / H * 0.25), 1.0 if on else 0.0)
	return {"a": _img(W, H, a, Image.FORMAT_RGBA8)}
