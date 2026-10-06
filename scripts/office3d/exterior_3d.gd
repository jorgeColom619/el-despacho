extends Node3D
## Exterior del despacho 3D, visible por el ventanal: plaza con fuente, árboles y farolas, el Congreso con su
## cúpula, edificios con ventanas que se encienden de noche y la torre de televisión. Refleja el estado del país
## como lo hacía la vista 2D: manifestantes con pancartas, policía, humo, fuegos artificiales, lluvia y nieve.
## Ejes locales: −Z mira desde el ventanal hacia la plaza (y hacia el sol); el origen está bajo el ventanal.

const Kit := preload("res://scripts/office3d/kit.gd")
const Batch := Kit.Batch

## Altura de la plaza respecto al suelo del despacho (que está en la primera planta)
const GROUND_Y := -3.6
const MAX_PEOPLE := 120
const FOUNTAIN := Vector3(0, 0, -55)

var night := 0.0
var rng := RandomNumberGenerator.new()
var facade_mats: Array = []
var lamp_mat: StandardMaterial3D
var stone_mat: StandardMaterial3D
var tower_light: StandardMaterial3D
var leaf_mat: StandardMaterial3D
var people: Array = []
var crowd_body: MultiMesh
var crowd_head: MultiMesh
var crowd_board: MultiMesh
var crowd_stick: MultiMesh
var police: Node3D
var siren_red: StandardMaterial3D
var siren_blue: StandardMaterial3D
var smoke: CPUParticles3D
var rain: CPUParticles3D
var snow: CPUParticles3D
var jets: CPUParticles3D
var fireworks: Array = []
var _t := 0.0
var _fw_cd := 0.0
var _season := -1
var _shown := -1


## origin: punto del suelo del despacho bajo el ventanal; toward_sun: dirección hacia el sol
func build(origin: Vector3, toward_sun: Vector3, flag_mat: Material) -> void:
	rng.seed = 7
	position = Vector3(origin.x, GROUND_Y, origin.z)
	var hz := Vector3(toward_sun.x, 0.0, toward_sun.z).normalized()
	rotation.y = atan2(-hz.x, -hz.z)
	_materials()
	var b := Batch.new()
	_ground(b)
	_plaza(b)
	_congress(b, flag_mat)
	_city(b, toward_sun.y / Vector2(toward_sun.x, toward_sun.z).length())
	_tower(b)
	_trees(b)
	_lamps(b)
	for mi in b.commit(self):
		(mi as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_crowd()
	_police()
	_particles()


# ------------------------------------------------------------------ materiales y texturas

func _materials() -> void:
	var em := _facade_tex(Color.BLACK, true)
	for spec in [[Color("d8cbb2"), 0.0], [Color("a9a59e"), 0.37], [Color("9b5b45"), 0.61], [Color("c9bfa8"), 0.83]]:
		var m := StandardMaterial3D.new()
		m.albedo_texture = _facade_tex(spec[0], false)
		m.roughness = 0.82
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.emission_enabled = true
		m.emission_texture = em
		m.emission = Color(1.0, 0.78, 0.46)
		m.emission_energy_multiplier = 0.0
		m.uv1_offset = Vector3(spec[1], spec[1] * 0.7, 0.0)
		facade_mats.append(m)
	lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1.0, 0.92, 0.75)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.82, 0.5)
	lamp_mat.emission_energy_multiplier = 0.2
	stone_mat = StandardMaterial3D.new()
	stone_mat.albedo_color = Color("ece5d6")
	stone_mat.roughness = 0.75
	stone_mat.emission_enabled = true
	stone_mat.emission = Color(1.0, 0.85, 0.6)
	stone_mat.emission_energy_multiplier = 0.0
	tower_light = StandardMaterial3D.new()
	tower_light.albedo_color = Color(1.0, 0.2, 0.15)
	tower_light.emission_enabled = true
	tower_light.emission = Color(1.0, 0.15, 0.1)
	tower_light.emission_energy_multiplier = 0.0
	leaf_mat = StandardMaterial3D.new()
	leaf_mat.albedo_color = Color("3d6a34")
	leaf_mat.roughness = 0.95


## Fachada de 8 × 8 ventanas (24 m): color de pared y cristales; con lit = true, la máscara de ventanas
## encendidas de noche (un 38 % al azar)
func _facade_tex(wall: Color, lit: bool) -> ImageTexture:
	var key := "facade_%s_%s" % [wall.to_html(), lit]
	if Kit._tex_cache.has(key):
		return Kit._tex_cache[key]
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var r := RandomNumberGenerator.new()
	r.seed = 99
	img.fill(Color.BLACK if lit else wall)
	for cy in 8:
		for cx in 8:
			var x0 := cx * 16
			var y0 := cy * 16
			if lit:
				if r.randf() < 0.38:
					img.fill_rect(Rect2i(x0 + 4, y0 + 3, 8, 10), Color(1.0, 0.82, 0.55).lerp(Color(1.0, 0.95, 0.85), r.randf()))
				continue
			img.fill_rect(Rect2i(x0, y0 + 14, 16, 2), wall.darkened(0.12))
			img.fill_rect(Rect2i(x0 + 3, y0 + 2, 10, 12), wall.lightened(0.18))
			img.fill_rect(Rect2i(x0 + 4, y0 + 3, 8, 10), Color(0.13, 0.17, 0.23).lerp(Color(0.32, 0.4, 0.5), r.randf() * 0.5))
			img.fill_rect(Rect2i(x0 + 7, y0 + 3, 2, 10), wall.lightened(0.1))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	Kit._tex_cache[key] = t
	return t


## Losas de la plaza (4 × 4 m por repetición)
func _paving_tex() -> ImageTexture:
	if Kit._tex_cache.has("paving"):
		return Kit._tex_cache["paving"]
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	img.fill(Color("6f675d"))
	for j in 8:
		for i in 8:
			var c := Color("b7ab98").lerp(Color("a39785"), r.randf())
			img.fill_rect(Rect2i(i * 16 + 1, j * 16 + 1, 15, 15), c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	Kit._tex_cache["paving"] = t
	return t


# ------------------------------------------------------------------ escenario

func _ground(b: Batch) -> void:
	b.box(Transform3D(Basis(), Vector3(0, -0.5, -250)), Vector3(900, 1.0, 900), Kit.mat(Color("3b3c3f"), 0.92))
	# explanada de grava frente al palacio y calles
	b.box(Transform3D(Basis(), Vector3(0, 0.01, -10)), Vector3(70, 0.02, 18), Kit.mat(Color("b9ab8f"), 0.95))
	for z in [-24.0, -150.0]:
		b.box(Transform3D(Basis(), Vector3(0, 0.012, z)), Vector3(900, 0.02, 9), Kit.mat(Color("2c2d30"), 0.9))


func _plaza(b: Batch) -> void:
	var pav := StandardMaterial3D.new()
	pav.albedo_texture = _paving_tex()
	pav.roughness = 0.88
	pav.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	b.box(Transform3D(Basis(), Vector3(0, 0.03, -57)), Vector3(64, 0.06, 60), pav, 0.25)
	var curb := Kit.mat(Color("8f877a"), 0.85)
	b.box(Transform3D(Basis(), Vector3(0, 0.08, -27)), Vector3(64.6, 0.16, 0.3), curb)
	b.box(Transform3D(Basis(), Vector3(0, 0.08, -87)), Vector3(64.6, 0.16, 0.3), curb)
	b.box(Transform3D(Basis(), Vector3(-32.15, 0.08, -57)), Vector3(0.3, 0.16, 60), curb)
	b.box(Transform3D(Basis(), Vector3(32.15, 0.08, -57)), Vector3(0.3, 0.16, 60), curb)
	# fuente: pilón, taza central y agua
	var f := FOUNTAIN
	b.lathe(Transform3D(Basis(), f), [Vector2(5.2, 0.0), Vector2(5.2, 0.55), Vector2(4.9, 0.6), Vector2(4.75, 0.55), Vector2(4.75, 0.2), Vector2(0.0, 0.2)], stone_mat, 48)
	b.lathe(Transform3D(Basis(), f), [Vector2(0.7, 0.0), Vector2(0.55, 1.2), Vector2(0.45, 2.2), Vector2(1.8, 2.5), Vector2(1.9, 2.75), Vector2(1.6, 2.8), Vector2(0.35, 2.85), Vector2(0.3, 3.6), Vector2(0.5, 3.8), Vector2(0.0, 4.0)], stone_mat, 32)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.2, 0.36, 0.42)
	water.roughness = 0.25
	b.cyl(f + Vector3(0, 0.45, 0), 4.75, 4.75, 0.04, water, Vector3.ZERO, 48)
	b.cyl(f + Vector3(0, 2.66, 0), 1.6, 1.6, 0.04, water, Vector3.ZERO, 32)


## El Congreso: escalinata, cuerpo principal, pórtico de columnas con frontón, tambor y cúpula con linterna
func _congress(b: Batch, flag_mat: Material) -> void:
	var c := Vector3(16, 0, -116)
	var st := stone_mat
	b.box(Transform3D(Basis(), c + Vector3(0, 1.2, 0)), Vector3(70, 2.4, 34), st, 0.3)
	for k in 6:
		b.box(Transform3D(Basis(), c + Vector3(0, 0.2 + k * 0.4, 17.0 + (5 - k) * 0.6)), Vector3(34, 0.4, 1.2 + (5 - k) * 1.2), st)
	b.box(Transform3D(Basis(), c + Vector3(0, 9.0, 0)), Vector3(62, 13.2, 28), st, 0.2)
	b.box(Transform3D(Basis(), c + Vector3(0, 16.0, 0)), Vector3(64, 1.0, 29.5), st)
	# ventanas del cuerpo principal (huecos oscuros en dos alturas)
	var dark := Kit.mat(Color("2a2f38"), 0.3)
	for side in [-1.0, 1.0]:
		for k in 9:
			var x: float = side * (8.0 + k * 2.6)
			for y in [6.0, 11.0]:
				b.box(Transform3D(Basis(), c + Vector3(x, y, 14.02)), Vector3(1.2, 2.6, 0.08), dark)
	# pórtico
	for i in 8:
		var x2 := -14.0 + i * 4.0
		b.lathe(Transform3D(Basis(), c + Vector3(x2, 2.4, 17.6)), [Vector2(1.1, 0.0), Vector2(1.1, 0.5), Vector2(0.85, 0.7), Vector2(0.8, 11.0), Vector2(1.05, 11.4), Vector2(1.1, 12.0), Vector2(0.0, 12.0)], st, 18)
	b.box(Transform3D(Basis(), c + Vector3(0, 15.4, 17.6)), Vector3(33, 1.4, 3.6), st)
	var ped := PrismMesh.new()
	ped.size = Vector3(34, 4.2, 3.6)
	Kit.mesh(self, ped, st, c + Vector3(0, 18.2, 17.6))
	# tambor, cúpula y linterna
	b.cylinder(Transform3D(Basis(), c + Vector3(0, 19.5, 0)), 9.0, 9.4, 6.0, st, 48)
	for k in 20:
		var a := TAU * k / 20.0
		b.box(Transform3D(Basis(Vector3.UP, -a), c + Vector3(cos(a) * 9.05, 19.6, sin(a) * 9.05)), Vector3(0.12, 3.2, 1.0), dark)
	var dome := Kit.mat(Color("8e9ba3"), 0.55)
	var prof := []
	for k in 13:
		var a2 := PI * 0.5 * k / 12.0
		prof.append(Vector2(cos(a2) * 9.3, sin(a2) * 10.0))
	b.lathe(Transform3D(Basis(), c + Vector3(0, 22.5, 0)), prof, dome, 48)
	b.cylinder(Transform3D(Basis(), c + Vector3(0, 33.8, 0)), 1.5, 1.6, 3.0, st, 20)
	b.lathe(Transform3D(Basis(), c + Vector3(0, 35.3, 0)), [Vector2(1.8, 0.0), Vector2(1.4, 0.8), Vector2(0.6, 1.5), Vector2(0.0, 1.8)], dome, 20)
	b.segment(c + Vector3(0, 37.0, 0), c + Vector3(0, 44.0, 0), 0.09, Kit.mat(Color("d6c48a"), 0.3, 0.8), 8)
	if flag_mat != null:
		var flag := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(4.2, 2.8)
		q.subdivide_width = 12
		q.subdivide_depth = 8
		flag.mesh = q
		flag.material_override = flag_mat
		flag.position = c + Vector3(2.15, 42.4, 0)
		flag.rotation = Vector3(0, PI * 0.5, 0)
		flag.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(flag)


## Manzanas de edificios a los lados de la plaza y skyline al fondo. sun_slope: pendiente del rayo de sol,
## para que ningún edificio tape el sol que se ve desde el despacho
func _city(b: Batch, sun_slope: float) -> void:
	var roof := Kit.mat(Color("3d3f44"), 0.9)
	# lados de la plaza
	for side in [-1.0, 1.0]:
		var z := -14.0
		while z > -150.0:
			var d := rng.randf_range(14.0, 22.0)
			var w := rng.randf_range(14.0, 22.0)
			var h := rng.randf_range(14.0, 30.0)
			var x: float = side * (44.0 + w * 0.5 + rng.randf_range(0.0, 6.0))
			_building(b, Vector3(x, 0, z - d * 0.5), Vector3(w, h, d), roof)
			z -= d + rng.randf_range(3.0, 7.0)
	# skyline del fondo
	var zr := -175.0
	while zr > -360.0:
		var xr := -260.0
		while xr < 260.0:
			var w2 := rng.randf_range(16.0, 30.0)
			var d2 := rng.randf_range(16.0, 28.0)
			var h2 := rng.randf_range(18.0, 52.0)
			if rng.randf() < 0.12:
				h2 = rng.randf_range(60.0, 105.0)
			# delante del sol, más bajos (el rayo hasta el ojo sube sun_slope por metro desde unos 6 m de altura)
			if absf(xr) < 30.0:
				h2 = minf(h2, sun_slope * absf(zr))
			if xr > -6.0 and xr < 40.0 and zr > -200.0:
				h2 = minf(h2, 26.0)
			_building(b, Vector3(xr + w2 * 0.5, 0, zr - d2 * 0.5), Vector3(w2, h2, d2), roof)
			xr += w2 + rng.randf_range(4.0, 12.0)
		zr -= rng.randf_range(34.0, 52.0)


func _building(b: Batch, base: Vector3, size: Vector3, roof: Material) -> void:
	var m: Material = facade_mats[rng.randi() % facade_mats.size()]
	b.box(Transform3D(Basis(), base + Vector3(0, size.y * 0.5, 0)), size, m, 1.0 / 24.0)
	b.box(Transform3D(Basis(), base + Vector3(0, size.y + 0.25, 0)), Vector3(size.x + 0.6, 0.5, size.z + 0.6), roof)
	if rng.randf() < 0.4:
		b.box(Transform3D(Basis(), base + Vector3(rng.randf_range(-2, 2), size.y + 1.6, rng.randf_range(-2, 2))), Vector3(4.0, 2.4, 4.0), roof)


## Torre de televisión con su luz roja de balizamiento
func _tower(b: Batch) -> void:
	var p := Vector3(-34, 0, -250)
	var conc := Kit.mat(Color("c9c6bf"), 0.7)
	b.cylinder(Transform3D(Basis(), p + Vector3(0, 45, 0)), 1.6, 3.2, 90.0, conc, 20)
	b.sphere(p + Vector3(0, 92, 0), 6.5, conc, 20, 12, Vector3(1.0, 0.75, 1.0))
	b.cylinder(Transform3D(Basis(), p + Vector3(0, 97, 0)), 1.0, 1.2, 4.0, conc, 12)
	b.segment(p + Vector3(0, 99, 0), p + Vector3(0, 124, 0), 0.35, Kit.mat(Color("8a8f96"), 0.4, 0.7), 8)
	b.sphere(p + Vector3(0, 124.6, 0), 0.9, tower_light, 10, 6)


func _trees(b: Batch) -> void:
	var bark := Kit.mat(Color("4a3424"), 0.95)
	var spots := []
	for side in [-1.0, 1.0]:
		var z := -30.0
		while z > -88.0:
			spots.append(Vector3(side * 29.0, 0, z))
			z -= 11.5
	for x in [-18.0, -7.0, 7.0, 18.0]:
		spots.append(Vector3(x, 0, -30.0))
	for p in spots:
		var pp: Vector3 = p
		var hgt := rng.randf_range(5.5, 7.5)
		b.segment(pp, pp + Vector3(0, hgt * 0.55, 0), 0.25, bark, 8)
		for k in 3:
			var off := Vector3(rng.randf_range(-1.0, 1.0), hgt * 0.62 + k * 0.9, rng.randf_range(-1.0, 1.0))
			b.sphere(pp + off, rng.randf_range(1.8, 2.6), leaf_mat, 12, 8, Vector3(1.0, 0.85, 1.0))


func _lamps(b: Batch) -> void:
	var iron := Kit.mat(Color("1d1e21"), 0.5, 0.6)
	for side in [-1.0, 1.0]:
		for z in [-30.0, -48.0, -66.0, -84.0]:
			var p := Vector3(side * 25.0, 0, z)
			b.cylinder(Transform3D(Basis(), p + Vector3(0, 2.2, 0)), 0.09, 0.14, 4.4, iron, 8)
			b.box(Transform3D(Basis(), p + Vector3(0, 4.7, 0)), Vector3(0.5, 0.6, 0.5), lamp_mat)
			b.box(Transform3D(Basis(), p + Vector3(0, 5.05, 0)), Vector3(0.62, 0.1, 0.62), iron)


# ------------------------------------------------------------------ multitud y policía

func _mm(mesh: Mesh, count: int, colors: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mi)
	return mm


func _vcolor_mat(rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	return m


func _crowd() -> void:
	var cap := CapsuleMesh.new()
	cap.radius = 0.24
	cap.height = 1.3
	cap.radial_segments = 8
	cap.rings = 2
	cap.material = _vcolor_mat()
	crowd_body = _mm(cap, MAX_PEOPLE, true)
	var head := SphereMesh.new()
	head.radius = 0.14
	head.height = 0.28
	head.radial_segments = 8
	head.rings = 4
	head.material = _vcolor_mat(0.6)
	crowd_head = _mm(head, MAX_PEOPLE, true)
	var board := BoxMesh.new()
	board.size = Vector3(0.8, 0.5, 0.04)
	board.material = _vcolor_mat(0.7)
	crowd_board = _mm(board, MAX_PEOPLE, true)
	var stick := CylinderMesh.new()
	stick.top_radius = 0.025
	stick.bottom_radius = 0.025
	stick.height = 1.3
	stick.radial_segments = 5
	stick.rings = 1
	stick.material = Kit.mat(Color("5a3f28"), 0.9)
	crowd_stick = _mm(stick, MAX_PEOPLE, false)
	const SKIN := ["f1c8a5", "e0ac85", "c68a62", "a8694a", "7d4a32", "f5d6bd"]
	var placed := 0
	while placed < MAX_PEOPLE:
		var p := Vector3(rng.randf_range(-24.0, 24.0), 0, rng.randf_range(-33.0, -82.0))
		if Vector2(p.x - FOUNTAIN.x, p.z - FOUNTAIN.z).length() < 6.2:
			continue
		var kind := 0
		var roll := rng.randf()
		if roll < 0.33:
			kind = 1
		elif roll < 0.43:
			kind = 2
		people.append({"p": p, "c": Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.7), rng.randf_range(0.35, 0.85)),
			"skin": Color(SKIN[rng.randi() % SKIN.size()]), "kind": kind, "ph": rng.randf() * TAU, "yaw": rng.randf_range(-0.5, 0.5)})
		placed += 1
	# los más cercanos al palacio primero: así, con poca gente, se ve desde el despacho
	people.sort_custom(func(a, b2): return a["p"].z > b2["p"].z)
	for i in people.size():
		var pe: Dictionary = people[i]
		crowd_body.set_instance_color(i, pe["c"])
		crowd_head.set_instance_color(i, pe["skin"])
		var bc := Color(0.95, 0.93, 0.88)
		if pe["kind"] == 2:
			bc = Color("1d3557") if i % 2 == 0 else Color("e9c46a")
		crowd_board.set_instance_color(i, bc)


func _police() -> void:
	police = Node3D.new()
	police.visible = false
	add_child(police)
	siren_red = StandardMaterial3D.new()
	siren_red.albedo_color = Color(1.0, 0.15, 0.1)
	siren_red.emission_enabled = true
	siren_red.emission = Color(1.0, 0.1, 0.05)
	siren_blue = StandardMaterial3D.new()
	siren_blue.albedo_color = Color(0.15, 0.35, 1.0)
	siren_blue.emission_enabled = true
	siren_blue.emission = Color(0.1, 0.3, 1.0)
	var b := Batch.new()
	var white := Kit.mat(Color("e9ecef"), 0.4)
	var stripe := Kit.mat(Color("1f4fa8"), 0.5)
	var tyre := Kit.mat(Color("141414"), 0.9)
	var glass := Kit.mat(Color("1b2633"), 0.1)
	for side in [-1.0, 1.0]:
		var p := Vector3(side * 14.0, 0, -31.0)
		var bas := Basis(Vector3.UP, PI * 0.5)
		b.box(Transform3D(bas, p + Vector3(0, 1.45, 0)), Vector3(5.2, 2.1, 2.2), white, 1.0, 0.12, 2)
		b.box(Transform3D(bas, p + Vector3(0, 1.2, 0)), Vector3(5.24, 0.35, 2.24), stripe)
		b.box(Transform3D(bas, p + Vector3(2.0, 1.95, 0)), Vector3(1.0, 0.7, 2.24), glass)
		b.box(Transform3D(bas, p + Vector3(-0.6, 2.58, 0)), Vector3(0.35, 0.18, 0.8), siren_red if side < 0 else siren_blue)
		b.box(Transform3D(bas, p + Vector3(0.6, 2.58, 0)), Vector3(0.35, 0.18, 0.8), siren_blue if side < 0 else siren_red)
		for wx in [-1.7, 1.7]:
			for wz in [-1.05, 1.05]:
				b.cylinder(Transform3D(bas * Basis(Vector3.RIGHT, PI * 0.5), p + bas * Vector3(wx, 0.42, wz)), 0.42, 0.42, 0.3, tyre, 12)
	# línea de antidisturbios con escudos
	var dark := Kit.mat(Color("15192a"), 0.6)
	var shield := Kit.mat(Color(0.75, 0.82, 0.9), 0.15)
	for i in 14:
		var px := -11.0 + i * 1.7
		b.cylinder(Transform3D(Basis(), Vector3(px, 0.85, -30.0)), 0.25, 0.27, 1.6, dark, 8)
		b.sphere(Vector3(px, 1.82, -30.0), 0.17, dark, 8, 5)
		b.box(Transform3D(Basis(), Vector3(px, 1.05, -30.4)), Vector3(0.62, 1.1, 0.05), shield)
	for mi in b.commit(police):
		(mi as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED


# ------------------------------------------------------------------ partículas

func _particle_mat(col: Color, additive: bool, billboard := BaseMaterial3D.BILLBOARD_PARTICLES) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = billboard
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	m.albedo_texture = Kit.disc_tex()
	return m


func _quad(size: Vector2, m: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	q.material = m
	return q


func _particles() -> void:
	# chorros de la fuente
	jets = CPUParticles3D.new()
	jets.position = FOUNTAIN + Vector3(0, 3.9, 0)
	jets.amount = 140
	jets.lifetime = 1.3
	jets.direction = Vector3.UP
	jets.spread = 14.0
	jets.initial_velocity_min = 4.2
	jets.initial_velocity_max = 5.0
	jets.scale_amount_min = 0.6
	jets.scale_amount_max = 1.2
	jets.mesh = _quad(Vector2(0.18, 0.18), _particle_mat(Color(0.85, 0.92, 1.0, 0.55), false))
	add_child(jets)
	# humo de las protestas
	smoke = CPUParticles3D.new()
	smoke.position = Vector3(0, 0.6, -50)
	smoke.emitting = false
	smoke.amount = 40
	smoke.lifetime = 7.0
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	smoke.emission_box_extents = Vector3(14.0, 0.2, 10.0)
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 1.6
	smoke.gravity = Vector3(0.3, 0.12, 0.0)
	smoke.scale_amount_min = 3.0
	smoke.scale_amount_max = 5.5
	var sg := Gradient.new()
	sg.set_color(0, Color(1.0, 0.55, 0.2, 0.0))
	sg.set_color(1, Color(0.35, 0.34, 0.34, 0.0))
	sg.add_point(0.12, Color(0.5, 0.42, 0.36, 0.55))
	sg.add_point(0.6, Color(0.36, 0.35, 0.35, 0.4))
	smoke.color_ramp = sg
	smoke.mesh = _quad(Vector2(1.0, 1.0), _particle_mat(Color.WHITE, false))
	add_child(smoke)
	# lluvia y nieve (entre el palacio y la plaza)
	rain = CPUParticles3D.new()
	rain.position = Vector3(0, 9.0, -18.0)
	rain.emitting = false
	rain.amount = 1100
	rain.lifetime = 1.0
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(16.0, 0.5, 12.0)
	rain.direction = Vector3(0.08, -1.0, 0.0)
	rain.spread = 2.0
	rain.initial_velocity_min = 15.0
	rain.initial_velocity_max = 17.0
	rain.mesh = _quad(Vector2(0.02, 0.55), _particle_mat(Color(0.78, 0.84, 0.92, 0.38), false, BaseMaterial3D.BILLBOARD_FIXED_Y))
	add_child(rain)
	snow = CPUParticles3D.new()
	snow.position = Vector3(0, 9.0, -18.0)
	snow.emitting = false
	snow.amount = 700
	snow.lifetime = 8.0
	snow.preprocess = 8.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(16.0, 0.5, 12.0)
	snow.direction = Vector3(0.1, -1.0, 0.0)
	snow.spread = 25.0
	snow.initial_velocity_min = 0.9
	snow.initial_velocity_max = 1.4
	snow.gravity = Vector3(0, -0.6, 0)
	snow.mesh = _quad(Vector2(0.07, 0.07), _particle_mat(Color(1, 1, 1, 0.9), false))
	add_child(snow)
	# fuegos artificiales: varias palmeras que se reutilizan
	var fg := Gradient.new()
	fg.set_color(0, Color(1, 1, 1, 1))
	fg.set_color(1, Color(1, 1, 1, 0))
	fg.add_point(0.7, Color(1, 1, 1, 0.8))
	for i in 6:
		var fw := CPUParticles3D.new()
		fw.emitting = false
		fw.one_shot = true
		fw.amount = 90
		fw.lifetime = 1.9
		fw.explosiveness = 1.0
		fw.direction = Vector3.UP
		fw.spread = 180.0
		fw.initial_velocity_min = 11.0
		fw.initial_velocity_max = 14.0
		fw.damping_min = 3.0
		fw.damping_max = 4.0
		fw.gravity = Vector3(0, -3.0, 0)
		fw.color_ramp = fg
		fw.mesh = _quad(Vector2(0.7, 0.7), _particle_mat(Color(1, 1, 1, 1), true))
		add_child(fw)
		fireworks.append(fw)


# ------------------------------------------------------------------ animación

## Estado del país (desde la vista de la ventana): protesta 0-1, celebración, clima, noche y mes
func update(delta: float, protest: float, celebrate: bool, weather: String, night_v: float, month: int) -> void:
	_t += delta
	night = night_v
	var lit := clampf((night - 0.15) * 1.6, 0.0, 1.0)
	for m in facade_mats:
		(m as StandardMaterial3D).emission_energy_multiplier = lit * 1.6
	lamp_mat.emission_energy_multiplier = 0.2 + lit * 3.5
	stone_mat.emission_energy_multiplier = lit * 0.22
	tower_light.emission_energy_multiplier = (4.0 if int(_t * 1.2) % 2 == 0 else 0.0) * lit
	# estación (los árboles cambian con el mes)
	var season := 0 if month in [3, 4, 5, 6, 7, 8, 9] else (1 if month in [10, 11] else 2)
	if season != _season:
		_season = season
		leaf_mat.albedo_color = [Color("3d6a34"), Color("b0662a"), Color("6c6458")][season]
	# multitud
	var n := clampi(int(protest * 70.0) + (40 if celebrate else 0), 0, MAX_PEOPLE)
	if n != _shown:
		_shown = n
		for mm in [crowd_body, crowd_head, crowd_board, crowd_stick]:
			(mm as MultiMesh).visible_instance_count = n
	if n > 0:
		var spd := 4.0 if protest > 0.3 else 2.5
		var amp := 0.12 if (protest > 0.3 or celebrate) else 0.05
		var hide := Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3.ZERO)
		for i in n:
			var pe: Dictionary = people[i]
			var bob := absf(sin(_t * spd + pe["ph"])) * amp
			var base := Transform3D(Basis(Vector3.UP, pe["yaw"]), pe["p"] + Vector3(0, bob, 0))
			crowd_body.set_instance_transform(i, base * Transform3D(Basis(), Vector3(0, 0.89, 0)))
			crowd_head.set_instance_transform(i, base * Transform3D(Basis(), Vector3(0, 1.72, 0)))
			if pe["kind"] > 0:
				var sway := sin(_t * 1.7 + pe["ph"]) * 0.12
				var hold := base * Transform3D(Basis(Vector3.BACK, sway), Vector3(0.28, 1.0, 0.05))
				crowd_stick.set_instance_transform(i, hold * Transform3D(Basis(), Vector3(0, 0.65, 0)))
				crowd_board.set_instance_transform(i, hold * Transform3D(Basis(), Vector3(0, 1.45, 0)))
			else:
				crowd_stick.set_instance_transform(i, hide)
				crowd_board.set_instance_transform(i, hide)
	# policía con las luces encendidas
	police.visible = protest > 0.55
	if police.visible:
		var on := int(_t * 6.0) % 2 == 0
		siren_red.emission_energy_multiplier = 6.0 if on else 0.4
		siren_blue.emission_energy_multiplier = 0.4 if on else 6.0
	smoke.emitting = protest > 0.75
	# fuegos artificiales
	if celebrate:
		_fw_cd -= delta
		if _fw_cd <= 0.0:
			_fw_cd = rng.randf_range(0.35, 0.9)
			for fw in fireworks:
				var f := fw as CPUParticles3D
				if not f.emitting:
					f.position = Vector3(rng.randf_range(-45.0, 45.0), rng.randf_range(38.0, 70.0), rng.randf_range(-70.0, -140.0))
					f.color = Color.from_hsv(rng.randf(), 0.85, 1.0) * 1.5
					f.restart()
					break
	# clima
	rain.emitting = weather in ["rain", "storm"]
	snow.emitting = weather == "snow"
	jets.emitting = weather != "snow"
