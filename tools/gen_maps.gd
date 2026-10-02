extends SceneTree
## Generador offline de mapas (mapa mundial y regiones de Valdoria).
## Canal R = id de país/región * 16, G = distancia a la costa, B = relieve.
## Uso: godot --headless --path . --script res://tools/gen_maps.gd

var noise := FastNoiseLite.new()
var warp := FastNoiseLite.new()
var relief := FastNoiseLite.new()


func _init() -> void:
	noise.seed = 7
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.frequency = 0.0065
	warp.seed = 99
	warp.noise_type = FastNoiseLite.TYPE_SIMPLEX
	warp.fractal_type = FastNoiseLite.FRACTAL_FBM
	warp.fractal_octaves = 3
	warp.frequency = 0.006
	relief.seed = 3
	relief.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	relief.fractal_type = FastNoiseLite.FRACTAL_FBM
	relief.fractal_octaves = 4
	relief.frequency = 0.02
	var t0 := Time.get_ticks_msec()
	gen_world()
	print("Mundo: %d ms" % (Time.get_ticks_msec() - t0))
	gen_valdoria()
	print("Valdoria: %d ms" % (Time.get_ticks_msec() - t0))
	quit()


func ell_field(x: float, y: float, e: Array) -> float:
	var dx: float = (x - e[0]) / e[2]
	var dy: float = (y - e[1]) / e[3]
	return 1.0 - sqrt(dx * dx + dy * dy)


func distance_transform(land: PackedByteArray, w: int, h: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(w * h)
	var inf := 99999.0
	for y in h:
		for x in w:
			var i := y * w + x
			var v := land[i]
			var edge := false
			if x > 0 and land[i - 1] != v:
				edge = true
			elif x < w - 1 and land[i + 1] != v:
				edge = true
			elif y > 0 and land[i - w] != v:
				edge = true
			elif y < h - 1 and land[i + w] != v:
				edge = true
			d[i] = 0.0 if edge else inf
	for y in h:
		for x in w:
			var i := y * w + x
			var m := d[i]
			if x > 0:
				m = minf(m, d[i - 1] + 1.0)
			if y > 0:
				m = minf(m, d[i - w] + 1.0)
				if x > 0:
					m = minf(m, d[i - w - 1] + 1.414)
				if x < w - 1:
					m = minf(m, d[i - w + 1] + 1.414)
			d[i] = m
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var m := d[i]
			if x < w - 1:
				m = minf(m, d[i + 1] + 1.0)
			if y < h - 1:
				m = minf(m, d[i + w] + 1.0)
				if x < w - 1:
					m = minf(m, d[i + w + 1] + 1.414)
				if x > 0:
					m = minf(m, d[i + w - 1] + 1.414)
			d[i] = m
	return d


func gen_world() -> void:
	var w := 1600
	var h := 900
	# continentes: lista de elipses [cx, cy, rx, ry]
	var continents := [
		[[250, 260, 170, 150], [215, 420, 105, 120], [285, 610, 90, 150], [340, 170, 130, 80], [130, 200, 70, 60]],
		[[710, 320, 180, 140], [640, 455, 115, 75], [900, 330, 160, 170], [1150, 270, 260, 160], [1390, 420, 170, 170], [1250, 150, 260, 90], [980, 470, 90, 70]],
		[[770, 745, 220, 140], [910, 800, 170, 100], [640, 800, 120, 80]],
		[[1075, 610, 85, 65]],
		[[470, 560, 22, 16], [1520, 640, 40, 30], [1000, 870, 35, 18], [120, 760, 30, 22]],
	]
	# semillas por continente: [id, x, y, peso]
	var seeds := [
		[[7, 260, 250, 1.5], [7, 330, 180, 1.2], [7, 200, 380, 1.0], [11, 270, 610, 1.2]],
		[[1, 690, 470, 1.0], [1, 650, 495, 1.0], [2, 565, 440, 1.0], [4, 720, 300, 1.4], [4, 860, 320, 1.4], [4, 790, 215, 1.2],
			[9, 975, 470, 1.0], [5, 1100, 220, 1.5], [5, 1300, 170, 1.6], [5, 1180, 330, 1.2], [6, 1400, 430, 1.4], [6, 1330, 530, 1.0], [10, 1030, 370, 0.8]],
		[[3, 700, 660, 1.0], [12, 890, 760, 1.3], [13, 620, 800, 1.0]],
		[[8, 1075, 610, 1.0]],
		[[14, 470, 560, 1.0], [14, 1520, 640, 1.0], [14, 1000, 870, 1.0], [14, 120, 760, 1.0]],
	]
	var ids := PackedByteArray()
	ids.resize(w * h)
	var land := PackedByteArray()
	land.resize(w * h)
	var sums := {}
	for y in h:
		for x in w:
			var wx := x + warp.get_noise_2d(x, y) * 45.0
			var wy := y + warp.get_noise_2d(x + 1000.0, y + 777.0) * 45.0
			var best := -9.0
			var cont := -1
			for c in continents.size():
				for e in continents[c]:
					var f := ell_field(wx, wy, e)
					if f > best:
						best = f
						cont = c
			var n := noise.get_noise_2d(x, y)
			var val := best + n * 0.42
			var i := y * w + x
			if val > 0.0:
				land[i] = 1
				var bd := 1e9
				var bid := 14
				for s in seeds[cont]:
					var dx: float = wx - s[1]
					var dy: float = wy - s[2]
					var dd: float = sqrt(dx * dx + dy * dy) / s[3]
					if dd < bd:
						bd = dd
						bid = s[0]
				ids[i] = bid
				if not sums.has(bid):
					sums[bid] = [0.0, 0.0, 0]
				sums[bid][0] += x
				sums[bid][1] += y
				sums[bid][2] += 1
			else:
				land[i] = 0
				ids[i] = 0
	var dist := distance_transform(land, w, h)
	var data := PackedByteArray()
	data.resize(w * h * 3)
	for i in w * h:
		var x := i % w
		var y := i / w
		data[i * 3] = ids[i] * 16
		data[i * 3 + 1] = clampi(int(dist[i] * 3.0), 0, 255)
		data[i * 3 + 2] = clampi(int((relief.get_noise_2d(x, y) * 0.5 + 0.5) * 255.0), 0, 255)
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, data)
	img.save_png("res://art/maps/world_ids.png")
	var info := {}
	for k in sums.keys():
		var s: Array = sums[k]
		info[str(k)] = {"x": s[0] / s[2], "y": s[1] / s[2], "area": s[2]}
	var fa := FileAccess.open("res://art/maps/world.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify({"w": w, "h": h, "countries": info}, "  "))
	fa.close()


func gen_valdoria() -> void:
	var w := 1000
	var h := 760
	# Valdoria: gran masa central + islas. Frontera oeste con Sarvenia (id 9), norte con la Unión (id 10)
	var body := [[500, 370, 420, 300], [300, 300, 260, 220], [640, 470, 300, 220], [520, 180, 300, 150]]
	var isles := [[868, 640, 48, 30], [930, 598, 26, 18], [805, 690, 22, 15]]
	var seeds := [
		[1, 560, 335, 0.62], [2, 540, 160, 1.0], [2, 690, 180, 0.8], [3, 800, 330, 0.95], [3, 780, 450, 0.8],
		[4, 560, 560, 1.0], [4, 430, 600, 0.8], [5, 390, 410, 1.0], [6, 300, 190, 1.0], [7, 175, 380, 0.9], [7, 200, 520, 0.8], [8, 870, 630, 1.0]]
	var ids := PackedByteArray()
	ids.resize(w * h)
	var land := PackedByteArray()
	land.resize(w * h)
	var sums := {}
	var adj := {}
	for y in h:
		for x in w:
			var wx := x + warp.get_noise_2d(x * 1.6, y * 1.6) * 30.0
			var wy := y + warp.get_noise_2d(x * 1.6 + 500.0, y * 1.6 + 300.0) * 30.0
			var best := -9.0
			for e in body:
				best = maxf(best, ell_field(wx, wy, e))
			var isl := -9.0
			for e in isles:
				isl = maxf(isl, ell_field(wx, wy, e))
			var n := noise.get_noise_2d(x * 1.3, y * 1.3)
			var val := best + n * 0.3
			var ival := isl + n * 0.5
			var i := y * w + x
			# tierra extranjera: al oeste (Sarvenia) y al norte (Unión Continental)
			var border_w := 95.0 + warp.get_noise_2d(0.0, y * 2.0) * 40.0
			var border_n := 62.0 + warp.get_noise_2d(x * 2.0, 50.0) * 30.0
			var foreign := 0
			if x < border_w and (val > -0.25 or x < border_w - 10.0):
				foreign = 9
			elif y < border_n and (val > -0.25 or y < border_n - 10.0):
				foreign = 10
			if foreign != 0 and x < 30:
				foreign = 9
			if foreign != 0:
				land[i] = 1
				ids[i] = foreign
			elif val > 0.0 or ival > 0.0:
				land[i] = 1
				var bid := 8
				if ival > 0.0 and val <= 0.0:
					bid = 8
				else:
					var bd := 1e9
					for s in seeds:
						if s[0] == 8:
							continue
						var dx: float = wx - s[1]
						var dy: float = wy - s[2]
						var dd: float = sqrt(dx * dx + dy * dy) / s[3]
						if dd < bd:
							bd = dd
							bid = s[0]
				ids[i] = bid
				if not sums.has(bid):
					sums[bid] = [0.0, 0.0, 0]
				sums[bid][0] += x
				sums[bid][1] += y
				sums[bid][2] += 1
			else:
				land[i] = 0
				ids[i] = 0
	for y in range(1, h):
		for x in range(1, w):
			var i := y * w + x
			var a := ids[i]
			for j in [i - 1, i - w]:
				var b: int = ids[j]
				if a != b and a >= 1 and a <= 8 and b >= 1 and b <= 8:
					var key := "%d-%d" % [mini(a, b), maxi(a, b)]
					adj[key] = adj.get(key, 0) + 1
	var dist := distance_transform(land, w, h)
	var data := PackedByteArray()
	data.resize(w * h * 3)
	for i in w * h:
		var x := i % w
		var y := i / w
		data[i * 3] = ids[i] * 16
		data[i * 3 + 1] = clampi(int(dist[i] * 4.0), 0, 255)
		data[i * 3 + 2] = clampi(int((relief.get_noise_2d(x * 1.5, y * 1.5) * 0.5 + 0.5) * 255.0), 0, 255)
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, data)
	img.save_png("res://art/maps/valdoria_ids.png")
	var info := {}
	for k in sums.keys():
		var s: Array = sums[k]
		info[str(k)] = {"x": s[0] / s[2], "y": s[1] / s[2], "area": s[2]}
	var pairs := []
	for k in adj.keys():
		if adj[k] > 25:
			pairs.append(k)
	var fa := FileAccess.open("res://art/maps/valdoria.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify({"w": w, "h": h, "regions": info, "adjacency": pairs}, "  "))
	fa.close()
