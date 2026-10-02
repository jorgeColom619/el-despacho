extends Control
## Vista exterior a través del ventanal: cielo, ciudad, plaza y clima. Reacciona al estado del país.

const W := preload("res://scripts/data/world_data.gd")
const Flags := preload("res://scripts/ui/flags.gd")

var tod := 0.0
var tod_target := 0.0
var clouds := 0.3
var storm := 0.0
var weather := "clear"
var protest := 0.0
var protest_target := 0.0
var celebrate := false
var _sky: ColorRect
var _mat: ShaderMaterial
var _t := 0.0
var _far := []
var _mid := []
var _near := []
var _people := []
var _rain := []
var _flash := 0.0
var _fireworks := []
var _smoke := []
var _birds := []
var _next_bird := 4.0
var rng := RandomNumberGenerator.new()
var _last_tod := -1.0
var _last_storm := -1.0
var _static_dirty := true

const PLAZA_Y := 392.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.seed = 42
	_sky = ColorRect.new()
	UI.full(_sky)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/sky.gdshader")
	_sky.material = _mat
	add_child(_sky)
	var holder := Control.new()
	UI.full(holder)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.draw.connect(_draw_scene.bind(holder))
	add_child(holder)
	set_meta("static", holder)
	var dyn := Control.new()
	UI.full(dyn)
	dyn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dyn.draw.connect(_draw_dynamic.bind(dyn))
	add_child(dyn)
	set_meta("holder", dyn)
	_build_city()
	GS.month_passed.connect(_on_month)
	for i in 140:
		_rain.append(Vector2(rng.randf() * 420.0, rng.randf() * 480.0))


func _on_month() -> void:
	_static_dirty = true


func _build_city() -> void:
	var x := -10.0
	while x < 420.0:
		var w := rng.randf_range(18, 40)
		_far.append(Rect2(x, 250 - rng.randf_range(20, 90), w, 200))
		x += w - 2.0
	x = -20.0
	while x < 420.0:
		var w2 := rng.randf_range(26, 54)
		var h2 := rng.randf_range(70, 150)
		_mid.append({"r": Rect2(x, 330 - h2, w2, h2 + 80), "seed": rng.randi(), "roof": rng.randi() % 3})
		x += w2 + rng.randf_range(0, 6)
	x = -10.0
	while x < 420.0:
		var w3 := rng.randf_range(50, 90)
		var h3 := rng.randf_range(40, 80)
		_near.append({"r": Rect2(x, 380 - h3, w3, h3 + 20), "seed": rng.randi()})
		x += w3 + rng.randf_range(10, 40)


func set_people(n: int) -> void:
	while _people.size() < n:
		var depth := rng.randf()
		_people.append({"x": rng.randf_range(10, 400), "y": PLAZA_Y + 8 + depth * 60.0, "c": Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.7), rng.randf_range(0.4, 0.9)),
			"skin": Color(W.SKIN[rng.randi() % 6]), "sign": rng.randf() < 0.35, "flag": rng.randf() < 0.1, "ph": rng.randf() * TAU, "s": 0.75 + depth * 0.6})
	while _people.size() > n:
		_people.pop_back()
	_people.sort_custom(func(a, b): return a["y"] < b["y"])


func _process(delta: float) -> void:
	_t += delta
	tod = move_toward(tod, tod_target, delta * 0.25)
	protest = move_toward(protest, protest_target, delta * 0.2)
	var want_storm := 1.0 if weather == "storm" else (0.35 if weather == "rain" else (0.2 if weather == "snow" else 0.0))
	storm = move_toward(storm, want_storm, delta * 0.2)
	var want_clouds: float = {"clear": 0.2, "clouds": 0.75, "rain": 0.95, "storm": 1.0, "snow": 0.85, "fog": 0.6}.get(weather, 0.3)
	clouds = move_toward(clouds, want_clouds, delta * 0.1)
	if weather == "storm" and rng.randf() < delta * 0.25:
		_flash = 0.9
		Sfx.play("thunder", -8.0, rng.randf_range(0.8, 1.1))
	_flash = maxf(0.0, _flash - delta * 3.0)
	_mat.set_shader_parameter("tod", tod)
	_mat.set_shader_parameter("clouds", clouds)
	_mat.set_shader_parameter("storm", storm)
	_mat.set_shader_parameter("flash", _flash * 0.6)
	set_people(int(protest * 70.0) + (40 if celebrate else 0))
	if celebrate and rng.randf() < delta * 1.6:
		_fireworks.append({"p": Vector2(rng.randf_range(40, 370), rng.randf_range(40, 200)), "t": 0.0, "c": Color.from_hsv(rng.randf(), 0.7, 1.0)})
	for f in _fireworks:
		f["t"] += delta
	_fireworks = _fireworks.filter(func(f): return f["t"] < 1.6)
	if protest > 0.75 and rng.randf() < delta * 6.0:
		_smoke.append({"p": Vector2(rng.randf_range(60, 340), PLAZA_Y + rng.randf_range(10, 40)), "t": 0.0, "r": rng.randf_range(6, 12)})
	for sm in _smoke:
		sm["t"] += delta
	_smoke = _smoke.filter(func(sm): return sm["t"] < 4.0)
	_next_bird -= delta
	if _next_bird <= 0.0 and tod < 0.5 and storm < 0.3:
		_next_bird = rng.randf_range(8, 20)
		_birds.append({"x": -20.0, "y": rng.randf_range(60, 180), "v": rng.randf_range(30, 55), "n": rng.randi_range(2, 5)})
	for b in _birds:
		b["x"] += b["v"] * delta
	_birds = _birds.filter(func(b): return b["x"] < 460.0)
	(get_meta("holder") as Control).queue_redraw()
	if absf(tod - _last_tod) > 0.01 or absf(storm - _last_storm) > 0.02 or _static_dirty:
		_last_tod = tod
		_last_storm = storm
		_static_dirty = false
		(get_meta("static") as Control).queue_redraw()


func _lit(seed_v: int, i: int) -> bool:
	var h := hash(seed_v * 31 + i * 7)
	return (h % 100) < 38


func _draw_scene(c: Control) -> void:
	var night := clampf((tod - 0.45) * 2.0, 0.0, 1.0)
	var haze := Color(0.55, 0.64, 0.76).lerp(Color(0.08, 0.1, 0.18), night)
	haze = haze.lerp(Color(0.35, 0.37, 0.42), storm * 0.5)
	# lejanos
	for r in _far:
		c.draw_rect(r, haze.darkened(0.08))
	# hitos: torre de TV, cúpula del Congreso, catedral
	var tcol := haze.darkened(0.2)
	c.draw_rect(Rect2(86, 120, 5, 140), tcol)
	c.draw_circle(Vector2(88.5, 150), 9, tcol)
	c.draw_line(Vector2(88.5, 80), Vector2(88.5, 120), tcol, 2)
	var mid_col := Color(0.42, 0.48, 0.58).lerp(Color(0.05, 0.06, 0.1), night).lerp(Color(0.25, 0.26, 0.3), storm * 0.4)
	for m in _mid:
		var r: Rect2 = m["r"]
		c.draw_rect(r, mid_col)
		if m["roof"] == 1:
			c.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.3, -8), Vector2(r.size.x * 0.4, 8)), mid_col)
		elif m["roof"] == 2:
			c.draw_colored_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x * 0.5, -14), r.position + Vector2(r.size.x, 0)]), mid_col)
		var idx := 0
		var wy := r.position.y + 8.0
		while wy < 360.0:
			var wx := r.position.x + 5.0
			while wx < r.end.x - 6.0:
				var lit := _lit(m["seed"], idx)
				var wc: Color
				if night > 0.1:
					wc = Color(1.0, 0.82, 0.45, 0.9 * night) if lit else Color(0.1, 0.12, 0.18, 0.5)
				else:
					wc = Color(0.75, 0.82, 0.9, 0.35) if lit else Color(0.2, 0.25, 0.32, 0.35)
				c.draw_rect(Rect2(wx, wy, 4, 5), wc)
				wx += 8.0
				idx += 1
			wy += 10.0
	# Cúpula del Congreso
	var dome := Color(0.62, 0.64, 0.66).lerp(Color(0.12, 0.13, 0.18), night)
	c.draw_rect(Rect2(232, 300, 110, 70), dome.darkened(0.1))
	for i in 7:
		c.draw_rect(Rect2(238 + i * 15, 306, 5, 60), dome.lightened(0.12))
	c.draw_rect(Rect2(252, 276, 70, 26), dome)
	var dpts := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		dpts.append(Vector2(287, 278) + Vector2(cos(a) * 36, sin(a) * 40))
	c.draw_colored_polygon(dpts, dome.lightened(0.05))
	c.draw_rect(Rect2(283, 226, 8, 14), dome)
	c.draw_line(Vector2(287, 210), Vector2(287, 226), dome, 2)
	# cercanos
	var near_col := Color(0.3, 0.3, 0.33).lerp(Color(0.04, 0.04, 0.07), night)
	for n in _near:
		var r2: Rect2 = n["r"]
		c.draw_rect(r2, near_col)
		for k in int(r2.size.x / 14.0):
			var lit2 := _lit(n["seed"], k)
			var col2 := Color(1, 0.8, 0.45, 0.85 * night) if (lit2 and night > 0.1) else Color(0.12, 0.14, 0.2, 0.6)
			c.draw_rect(Rect2(r2.position.x + 5 + k * 14, r2.position.y + 10, 7, 10), col2)
	# plaza
	var pz := Color(0.52, 0.48, 0.44).lerp(Color(0.1, 0.1, 0.13), night).lerp(Color(0.3, 0.3, 0.32), storm * 0.4)
	c.draw_rect(Rect2(0, PLAZA_Y, 420, 90), pz)
	for i in 9:
		var y := PLAZA_Y + 4.0 + pow(i / 8.0, 1.6) * 76.0
		c.draw_line(Vector2(0, y), Vector2(420, y), pz.darkened(0.12), 1)
	for i in 14:
		c.draw_line(Vector2(204 + (i - 7) * 10, PLAZA_Y), Vector2(204 + (i - 7) * 50, PLAZA_Y + 80), pz.darkened(0.1), 1)
	# fuente y farolas
	c.draw_rect(Rect2(170, PLAZA_Y + 14, 68, 10), pz.darkened(0.25))
	c.draw_rect(Rect2(198, PLAZA_Y - 26, 12, 42), pz.darkened(0.35))
	c.draw_circle(Vector2(204, PLAZA_Y - 32), 8, pz.darkened(0.4))
	for lx in [40, 368]:
		c.draw_line(Vector2(lx, PLAZA_Y + 20), Vector2(lx, PLAZA_Y - 30), Color(0.1, 0.1, 0.1), 2)
		c.draw_circle(Vector2(lx, PLAZA_Y - 32), 4, Color(1, 0.85, 0.5, 0.3 + night * 0.7))
		if night > 0.2:
			c.draw_circle(Vector2(lx, PLAZA_Y - 32), 14, Color(1, 0.8, 0.4, 0.12 * night))
	# árboles
	for tx in [20, 120, 290, 392]:
		c.draw_line(Vector2(tx, PLAZA_Y + 12), Vector2(tx, PLAZA_Y - 6), Color(0.2, 0.14, 0.1), 3)
		var leaf := Color(0.25, 0.4, 0.22).lerp(Color(0.05, 0.08, 0.06), night)
		var mo: int = UI.date_dict(GS.day)["month"] if GS.active else 5
		if mo in [10, 11]:
			leaf = Color(0.7, 0.42, 0.15).lerp(Color(0.1, 0.07, 0.04), night)
		elif mo in [12, 1, 2]:
			leaf = Color(0.35, 0.3, 0.26).lerp(Color(0.06, 0.06, 0.07), night)
		c.draw_circle(Vector2(tx, PLAZA_Y - 14), 14, leaf)
		c.draw_circle(Vector2(tx - 8, PLAZA_Y - 8), 10, leaf.darkened(0.1))


func _draw_dynamic(c: Control) -> void:
	var night := clampf((tod - 0.45) * 2.0, 0.0, 1.0)
	if night > 0.3 and int(_t * 1.5) % 2 == 0:
		c.draw_circle(Vector2(88.5, 80), 2.5, Color(1, 0.2, 0.15))
	var fcol: Array = Flags.palette(Flags.current_style())
	for i in 3:
		var wave := sin(_t * 3.0 + i) * 1.5
		c.draw_rect(Rect2(288, 210 + i * 3 + wave * 0.2, 14 + wave, 3), fcol[i])
	# policía
	if protest > 0.55:
		var blink := int(_t * 6.0) % 2 == 0
		for vx in [30, 330]:
			c.draw_rect(Rect2(vx, PLAZA_Y + 8, 46, 20), Color(0.9, 0.9, 0.92).lerp(Color(0.3, 0.3, 0.35), night))
			c.draw_rect(Rect2(vx, PLAZA_Y + 18, 46, 4), Color(0.15, 0.3, 0.7))
			c.draw_rect(Rect2(vx + 16, PLAZA_Y + 4, 14, 4), Color(0.2, 0.4, 1.0) if blink else Color(1, 0.2, 0.2))
			c.draw_circle(Vector2(vx + 23, PLAZA_Y + 6), 16, Color(0.2, 0.4, 1.0, 0.18) if blink else Color(1, 0.2, 0.2, 0.18))
		for i in 12:
			var px := 110.0 + i * 16.0
			c.draw_rect(Rect2(px, PLAZA_Y + 2, 6, 12), Color(0.08, 0.1, 0.2))
			c.draw_circle(Vector2(px + 3, PLAZA_Y), 3, Color(0.08, 0.08, 0.1))
			c.draw_rect(Rect2(px - 2, PLAZA_Y + 3, 3, 10), Color(0.6, 0.7, 0.8, 0.8))
	# multitud
	for p in _people:
		var s: float = p["s"]
		var bob := absf(sin(_t * (4.0 if protest > 0.3 else 2.5) + p["ph"])) * 2.5 * s
		var base := Vector2(p["x"], p["y"] - bob)
		var body: Color = p["c"]
		if night > 0.2:
			body = body.darkened(0.6 * night)
		c.draw_rect(Rect2(base + Vector2(-3, -10) * s, Vector2(6, 11) * s), body)
		c.draw_circle(base + Vector2(0, -13) * s, 3.0 * s, (p["skin"] as Color).darkened(0.5 * night))
		if p["sign"]:
			c.draw_line(base + Vector2(3, -8) * s, base + Vector2(4, -26) * s, Color(0.35, 0.25, 0.15), 1.2)
			c.draw_rect(Rect2(base + Vector2(-4, -34) * s, Vector2(16, 9) * s), Color(0.95, 0.93, 0.88).darkened(0.5 * night))
			c.draw_line(base + Vector2(-2, -30) * s, base + Vector2(9, -30) * s, Color(0.7, 0.1, 0.1), 1.0)
		elif p["flag"]:
			c.draw_line(base + Vector2(3, -8) * s, base + Vector2(4, -30) * s, Color(0.3, 0.3, 0.3), 1.2)
			c.draw_rect(Rect2(base + Vector2(4, -30) * s, Vector2(12, 3) * s), Color("1d3557"))
			c.draw_rect(Rect2(base + Vector2(4, -27) * s, Vector2(12, 3) * s), Color("e9c46a"))
			c.draw_rect(Rect2(base + Vector2(4, -24) * s, Vector2(12, 3) * s), Color("1d3557"))
		elif protest > 0.3 and fmod(_t + p["ph"], 2.0) < 1.0:
			c.draw_line(base + Vector2(3, -9) * s, base + Vector2(6, -18) * s, body, 2.0 * s)
	# humo
	for sm in _smoke:
		var tt: float = sm["t"]
		var pos: Vector2 = sm["p"] + Vector2(sin(tt * 2.0) * 6.0, -tt * 30.0)
		c.draw_circle(pos, sm["r"] + tt * 6.0, Color(0.25, 0.24, 0.24, 0.45 * (1.0 - tt / 4.0)))
		if tt < 0.6:
			c.draw_circle(sm["p"], 5, Color(1.0, 0.5, 0.1, 0.7))
	# fuegos artificiales
	for f in _fireworks:
		var ft: float = f["t"]
		var col: Color = f["c"]
		col.a = 1.0 - ft / 1.6
		for i in 14:
			var a := TAU * i / 14.0
			var pp: Vector2 = f["p"] + Vector2(cos(a), sin(a)) * ft * 48.0 + Vector2(0, ft * ft * 10.0)
			c.draw_circle(pp, 2.2, col)
	# pájaros
	for b in _birds:
		for k in int(b["n"]):
			var bp := Vector2(b["x"] - k * 12.0, b["y"] + absf(k - 1) * 6.0)
			var fl := sin(_t * 10.0 + k) * 3.0
			c.draw_polyline(PackedVector2Array([bp + Vector2(-5, -fl), bp, bp + Vector2(5, -fl)]), Color(0.1, 0.1, 0.12, 0.8), 1.3)
	# clima
	if weather in ["rain", "storm"]:
		var rc := Color(0.75, 0.8, 0.9, 0.35 if weather == "rain" else 0.5)
		for i in _rain.size():
			var rp: Vector2 = _rain[i]
			var y2 := fmod(rp.y + _t * 520.0, 480.0)
			var x2 := fmod(rp.x + _t * 90.0, 420.0)
			c.draw_line(Vector2(x2, y2), Vector2(x2 - 3, y2 + 12), rc, 1.0)
	elif weather == "snow":
		for i in _rain.size():
			var rp2: Vector2 = _rain[i]
			var y3 := fmod(rp2.y + _t * 40.0, 480.0)
			var x3 := fmod(rp2.x + sin(_t + i) * 10.0, 420.0)
			c.draw_circle(Vector2(x3, y3), 1.6, Color(1, 1, 1, 0.85))
	elif weather == "fog":
		for i in 6:
			c.draw_rect(Rect2(0, 200 + i * 50, 420, 60), Color(0.85, 0.87, 0.9, 0.12))
	# resplandor nocturno de la ciudad
	if night > 0.3:
		c.draw_rect(Rect2(0, 300, 420, 100), Color(1.0, 0.6, 0.3, 0.05 * night))
