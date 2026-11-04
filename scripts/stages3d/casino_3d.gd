extends "res://scripts/stages3d/stage_3d.gd"
## El Gran Casino de Santa Aurora: un salón con moqueta, damasco rojo, columnas de mármol, techo artesonado y lámparas
## de araña. Mesas de ruleta y de blackjack, la sala privada (póker, tras los cordones), una fila de tragaperras y la
## caja. Las piezas salen de art/casino/casino.glb (tools/blender/gen_casino.py) y llevan los materiales del juego.
## El presidente (la cámara) va de un sitio a otro con go(): el vestíbulo, la caja, la ruleta, el blackjack o una
## tragaperras. Aquí solo está lo que se ve y se mueve (la rueda y la bola, las cartas, las fichas, los rodillos);
## las reglas y el dinero los lleva casino_overlay.gd.

signal picked(what: String, arg: int)

const LIB := preload("res://art/casino/casino.glb")
const D := preload("res://scripts/data/casino_data.gd")
const Art := preload("res://scripts/ui/casino_art.gd")
const Layout := preload("res://scripts/ui/roulette_layout.gd")

# ---- medidas de las piezas (tools/blender/gen_casino.py)
const TOP := 0.8
const RW_TRACK_R := 0.3705
const RW_TRACK_Y := 0.069
const RW_POCKET_R := 0.2035
const RW_POCKET_Y := 0.0255
const CHIP_H := 0.0034
const CARD := Vector2(0.063, 0.088)

# ---- el salón
const H := 5.6
const X0 := -9.5
const X1 := 9.5
const Z0 := -8.5
const Z1 := 7.0
const RT := Vector3(-3.6, 0, -0.6)
const BJ := Vector3(3.6, 0, -0.8)
const PK := Vector3(0, 0, -6.1)
const SLOTS_X := [-7.9, -7.0, -6.1, -5.2]
const SLOTS_Z := -7.85
const CAJA := Vector3(5.8, 0, -7.9)
const LOBBY_TABLE := Vector3(0.62, 0, 4.55)
## Donde espera el anfitrión en el vestíbulo
const HOST_SPOT := Vector3(1.55, 0, 3.4)

# ---- en la mesa de ruleta (coordenadas de la mesa)
const RW_AT := Vector3(-0.82, TOP - 0.003, 0.0)
## Esquina de arriba a la izquierda del paño impreso (1 px = 1 mm; x a la derecha, y hacia el jugador)
const LAYOUT_AT := Vector3(-0.36, TOP + 0.0015, -0.4)
const RT_BANK := Vector3(0.18, TOP, 0.4)
# ---- en la mesa de blackjack
const BJ_BET := Vector3(0, TOP, 0.42)
const BJ_PCARDS := Vector3(0, TOP, 0.24)
const BJ_DCARDS := Vector3(0, TOP, -0.1)
const BJ_SHOE := Vector3(0.62, TOP + 0.095, -0.2)
const BJ_DISCARD := Vector3(-0.62, TOP + 0.02, -0.24)
const BJ_BANK := Vector3(-0.42, TOP, 0.33)
const BJ_ACTIONS := Vector3(0.36, TOP, 0.3)

## Dónde se pone la cámara: [ojos, adónde mira, campo de visión, mirada libre]
var stations := {}
var station := ""

var lib: Node3D
var _mats := {}
var tables := {}
## La ruleta: la rueda (dentro de la mesa), el plato que gira, la bola y el marcador del número
var wheel: Node3D
var rotor: Node3D
var ball: Node3D
var dolly: Node3D
var layout: Control
## Tragaperras: [{"root", "reels": [3], "lever", "sign", "sign_vp", "lights": material, "rot": [3]}]
var slots: Array = []
## Personajes: "croupier", "dealer", "cashier", "host", "guard"
var people := {}
var host_look := {}
var host_name := ""
var meme := false
var _card_atlas: Texture2D
var _card_back_mat: StandardMaterial3D
var _card_mats := {}
var _chip_mats := {}
var _rotor_ang := 0.0
var _rotor_w := 0.5
var _ball_st := {}
var _lobby_picks: Array = []
var _rng := RandomNumberGenerator.new()


func build() -> void:
	_rng.seed = 41
	lib = LIB.instantiate()
	_materials()
	_room()
	_ceiling()
	_vip()
	_roulette()
	_blackjack()
	_slots()
	_cashier()
	_lobby()
	_lights()
	b.commit(world)
	_people()
	_stations()
	go("caja", true)


func _exit_tree() -> void:
	super()
	Sfx.loop_stop("ball")
	Sfx.loop_stop("reels")
	if is_instance_valid(lib):
		lib.free()


# ------------------------------------------------------------------ piezas y materiales

func _materials() -> void:
	var felt_bj := StandardMaterial3D.new()
	felt_bj.albedo_texture = _paint(Vector2i(2160, 1080), func(c: Control): Art.bj_felt(c, c.size, 1000.0))
	felt_bj.roughness = 0.95
	var ring := StandardMaterial3D.new()
	ring.albedo_texture = _paint(Vector2i(2368, 96), func(c: Control): Art.number_ring(c, c.size))
	ring.roughness = 0.35
	ring.emission_enabled = true
	ring.emission_texture = ring.albedo_texture
	ring.emission_energy_multiplier = 0.15
	_mats = {
		"Wood": Kit.wood("caoba"), "WoodDark": Kit.wood("ebano"), "Gold": Kit.gold(), "Chrome": Kit.chrome(),
		"Leather": Kit.leather(Color("2a120c")), "Velvet": Kit.velvet(Color("6e1420")), "Marble": Kit.wood("marmol"),
		"Crystal": Kit.crystal(), "Bulb": Kit.emissive(Color(1.0, 0.86, 0.6), 4.0), "Ivory": Kit.mat(Color("f3eee0"), 0.25),
		"Black": Kit.mat(Color("0c0c0e"), 0.5), "Glass": Kit.glass(Color(0.8, 0.9, 1.0, 0.1)), "Sign": Kit.mat(Color("15151c"), 0.4),
		"RW_Numbers": ring, "RW_Red": Kit.mat(Color("a3161c"), 0.35), "RW_Black": Kit.mat(Color("121214"), 0.35),
		"RW_Green": Kit.mat(Color("1d7a3c"), 0.35), "RW_Cone": Kit.wood("roble"),
		"Felt": Kit.pbr("velvet", {}, 0.3, 0.97, Color("1d5638"), 0.25), "Felt_BJ": felt_bj,
		"Felt_PK": Kit.pbr("velvet", {}, 0.3, 0.97, Color("5a1420"), 0.25),
		"SL_Body": Kit.mat(Color("6a0f1c"), 0.22, 0.25), "SL_Inner": Kit.mat(Color("08080a"), 0.8), "SL_Deck": Kit.mat(Color("121216"), 0.3),
		"SL_Btn": Kit.emissive(Color("e8442a"), 1.2), "SL_Payline": Kit.emissive(Color("ff3030"), 2.5), "SL_Knob": Kit.mat(Color("c41a1a"), 0.15, 0.1),
		"SL_Lights": Kit.emissive(Color("ffd27a"), 2.0),
	}
	var belly := StandardMaterial3D.new()
	belly.albedo_texture = _paint(Vector2i(540, 600), func(c: Control): Art.slot_belly(c, c.size, meme))
	belly.emission_enabled = true
	belly.emission_texture = belly.albedo_texture
	belly.emission_energy_multiplier = 0.6
	_mats["SL_Belly"] = belly
	var crest := StandardMaterial3D.new()
	crest.albedo_texture = _paint(Vector2i(640, 180), func(c: Control): Art.slot_crest(c, c.size, meme))
	crest.emission_enabled = true
	crest.emission_texture = crest.albedo_texture
	crest.emission_energy_multiplier = 0.5
	_mats["SL_Crest"] = crest
	for r in 3:
		var rm := StandardMaterial3D.new()
		var idx := r
		rm.albedo_texture = _paint(Vector2i(256, 1536), func(c: Control): Art.reel_strip(c, idx, 256.0, 128.0, meme))
		rm.roughness = 0.5
		rm.emission_enabled = true
		rm.emission_texture = rm.albedo_texture
		rm.emission_energy_multiplier = 0.45
		_mats["SL_Reel_%d" % r] = rm
	# baraja: atlas de 13 × 4 caras y el dorso
	var faces := func(c: Control) -> void:
		for k in 52:
			Art.card_face(c, k, Rect2((k % 13) * 180 + 2, (k / 13) * 252 + 2, 176, 248))
	_card_atlas = _paint(Vector2i(13 * 180, 4 * 252), faces, true)
	var back := func(c: Control) -> void:
		Art.card_back(c, Rect2(2, 2, 176, 248))
	_card_back_mat = _card_mat(_paint(Vector2i(180, 252), back, true), Vector2.ONE, Vector2.ZERO)
	for i in D.CHIPS.size():
		var ch: Dictionary = D.CHIPS[i]
		var face := StandardMaterial3D.new()
		var col := Color(ch["col"])
		var v := int(ch["v"])
		face.albedo_texture = _paint(Vector2i(128, 128), func(c: Control): Art.chip_face(c, 128.0, v, col))
		face.roughness = 0.45
		_chip_mats[v] = {"ChipBody": Kit.mat(col, 0.45), "ChipSpot": Kit.mat(Color(ch["spot"]), 0.45), "ChipInlay": face}


## Dibuja f(control) en una textura (una sola vez)
func _paint(px: Vector2i, f: Callable, transparent := false) -> Texture2D:
	var sv := SubViewport.new()
	sv.size = px
	sv.disable_3d = true
	sv.transparent_bg = transparent
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var c := Control.new()
	c.size = Vector2(px)
	c.draw.connect(func(): f.call(c))
	sv.add_child(c)
	return sv.get_texture()


func _card_mat(tex: Texture2D, scl: Vector2, off: Vector2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_scale = Vector3(scl.x, scl.y, 1.0)
	m.uv1_offset = Vector3(off.x, off.y, 0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.roughness = 0.55
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission_energy_multiplier = 0.18
	return m


## Copia de una pieza del .glb con los materiales del juego (extra: materiales propios de esta copia)
func piece(name: String, extra := {}) -> Node3D:
	var src := lib.find_child(name, true, false) as Node3D
	if src == null:
		push_warning("casino.glb no tiene la pieza " + name)
		return Node3D.new()
	var n := src.duplicate() as Node3D
	var meshes: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	for mi in meshes:
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var sm := m3.mesh.surface_get_material(i)
			var key := sm.resource_name if sm != null else ""
			if extra.has(key):
				m3.set_surface_override_material(i, extra[key])
			elif _mats.has(key):
				m3.set_surface_override_material(i, _mats[key])
			if low:
				m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## Pieza puesta en el mundo (o dentro de parent) con la transformación xf
func place(name: String, xf: Transform3D, parent: Node3D = null, extra := {}) -> Node3D:
	var n := piece(name, extra)
	(parent if parent != null else world).add_child(n)
	if parent == null:
		n.global_transform = xf * n.transform
	else:
		n.transform = xf * n.transform
	return n


# ------------------------------------------------------------------ el salón

func _room() -> void:
	var w := X1 - X0
	var d := Z1 - Z0
	var cz := (Z0 + Z1) * 0.5
	var carpet := Kit.pbr("casino_carpet", {"c0": "5a0f18", "c1": "1f2a44", "acc": "c9a050"}, 2.6, 0.95, Color.WHITE, 0.8)
	b.cube(Vector3(0, -0.05, cz), Vector3(w, 0.1, d), carpet, Vector3.ZERO, 1.0)
	var wall := Kit.pbr("wallpaper", {"c0": "4a0f16", "c1": "3a0a10", "acc": "c9a050"}, 0.9, 0.8, Color.WHITE, 0.8)
	var panel := Kit.wood("ebano")
	var gold := Kit.gold()
	var cream := Kit.mat(Color("efe4cc"), 0.5)
	var walls := [
		[Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, Z1)), w],
		[Transform3D(Basis(), Vector3(0, 0, Z0)), w],
		[Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(X0, 0, cz)), d],
		[Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(X1, 0, cz)), d],
	]
	for wl in walls:
		var xf: Transform3D = wl[0]
		var hl: float = wl[1] * 0.5
		b.rects(xf, [Rect2(-hl, 1.2, hl * 2.0, H - 1.2)], wall, 1.0)
		b.rects(xf, [Rect2(-hl, 0.0, hl * 2.0, 1.2)], panel, 1.0)
		b.molding(xf * Transform3D(Basis(), Vector3(0, 1.165, 0)), -hl, hl, Kit.PROFILE_RAIL, gold)
		b.molding(xf, -hl, hl, Kit.PROFILE_BASE, gold)
		b.molding(xf * Transform3D(Basis(), Vector3(0, H - 0.175, 0)), -hl, hl, Kit.PROFILE_CROWN, gold)
		var px := -hl + 0.8
		while px < hl - 0.6:
			b.frame(xf * Transform3D(Basis(), Vector3(px, 0.6, 0.0)), 0.95, 0.8, Kit.FRAME_PANEL, gold)
			px += 1.25
	# pilastras de mármol en las paredes y columnas exentas entre las mesas
	for z in [-5.6, -2.0, 1.6, 5.2]:
		place("Column", Transform3D(Basis(), Vector3(X0 + 0.16, 0, z)))
		place("Column", Transform3D(Basis(), Vector3(X1 - 0.16, 0, z)))
	for x in [-6.6, 6.6]:
		for z in [-3.2, 1.0]:
			place("Column", Transform3D(Basis(), Vector3(x, 0, z)))
	# ventanales con la noche de Santa Aurora (pared izquierda) y espejos (derecha)
	var night := _night_tex()
	for z in [-3.8, -0.2, 3.4]:
		var xf := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(X0, 0, z))
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.7, 3.4)
		mi.mesh = q
		mi.material_override = Kit.screen_mat(night, 0.9)
		world.add_child(mi)
		mi.global_transform = xf * Transform3D(Basis(), Vector3(0, 2.7, 0.02))
		b.frame(xf * Transform3D(Basis(), Vector3(0, 2.7, 0.0)), 1.86, 3.56, Kit.FRAME_CASING, gold)
		b.box(xf * Transform3D(Basis(), Vector3(0, 2.7, 0.04)), Vector3(0.05, 3.4, 0.03), gold)
		for sx in [-1.0, 1.0]:
			b.box(xf * Transform3D(Basis(), Vector3(sx * 1.1, 2.4, 0.16)), Vector3(0.55, 4.4, 0.14), Kit.velvet(Color("5a0f18")), 1.0, 0.05, 2)
		b.box(xf * Transform3D(Basis(), Vector3(0, 4.62, 0.2)), Vector3(2.9, 0.4, 0.16), Kit.velvet(Color("5a0f18")), 1.0, 0.04, 2)
	# cuadros al óleo con marco dorado (pared derecha)
	for k in 3:
		var z: float = [-3.8, -0.2, 3.4][k]
		var xf2 := Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(X1, 0, z))
		var pm := MeshInstance3D.new()
		var pq := QuadMesh.new()
		pq.size = Vector2(1.5, 2.2)
		pm.mesh = pq
		pm.material_override = Kit.tex_mat(_painting_tex(k), 0.75)
		world.add_child(pm)
		pm.global_transform = xf2 * Transform3D(Basis(), Vector3(0, 2.8, 0.025))
		b.frame(xf2 * Transform3D(Basis(), Vector3(0, 2.8, 0.0)), 1.7, 2.4, Kit.FRAME_ORNATE, gold)
		for sy in [-1.0, 1.0]:
			glow((xf2 * Transform3D(Basis(), Vector3(sy * 1.05, 2.9, 0.25))).origin, 0.35, Color(1, 0.8, 0.5, 0.55))
	# puerta de entrada (detrás del vestíbulo)
	var door := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, Z1))
	b.box(door * Transform3D(Basis(), Vector3(0, 1.6, 0.03)), Vector3(2.2, 3.2, 0.06), Kit.wood("caoba"))
	b.frame(door * Transform3D(Basis(), Vector3(0, 1.6, 0.0)), 2.5, 3.4, Kit.FRAME_CASING, gold)
	# letrero dorado sobre la sala privada
	# (por debajo de la lámpara de la sala privada, para que se lean desde el vestíbulo)
	var lbl := Kit.label(world, "SALA PRIVADA", UI.f_serif_b, 96, Color("e9c46a"), Vector3(0, 2.95, Z0 + 0.05), Vector3.ZERO, 0.0028)
	lbl.shaded = false
	var lbl2 := Kit.label(world, "GRAN CASINO DE SANTA AURORA", UI.f_serif_b, 72, Color("e9c46a"), Vector3(0, 3.55, Z0 + 0.06), Vector3.ZERO, 0.0042)
	lbl2.shaded = false


## Cuadros al óleo del salón: una marina al atardecer, el palacio del casino entre jardines y un bodegón
func _painting_tex(k: int) -> Texture2D:
	var draw_it := func(c: Control) -> void:
		var w := c.size.x
		var h := c.size.y
		var rng := RandomNumberGenerator.new()
		rng.seed = 300 + k
		match k:
			0:
				for y in 40:
					c.draw_rect(Rect2(0, y * h * 0.6 / 40.0, w, h * 0.6 / 40.0 + 1), Color("f0b060").lerp(Color("5a3a6a"), y / 40.0).darkened(0.1))
				c.draw_circle(Vector2(w * 0.62, h * 0.5), w * 0.12, Color("ffd890"))
				for y in 30:
					c.draw_rect(Rect2(0, h * 0.6 + y * h * 0.4 / 30.0, w, h * 0.4 / 30.0 + 1), Color("4a3a5a").lerp(Color("1a2030"), y / 30.0))
				for i in 40:
					c.draw_line(Vector2(rng.randf() * w, h * (0.62 + rng.randf() * 0.36)), Vector2(rng.randf() * w, h * (0.62 + rng.randf() * 0.36)), Color(1, 0.8, 0.5, 0.15), 2.0)
				c.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.2, h * 0.6), Vector2(w * 0.42, h * 0.6), Vector2(w * 0.38, h * 0.64), Vector2(w * 0.24, h * 0.64)]), Color("1a1418"))
				c.draw_line(Vector2(w * 0.31, h * 0.6), Vector2(w * 0.31, h * 0.4), Color("1a1418"), 3.0)
				c.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.315, h * 0.42), Vector2(w * 0.4, h * 0.56), Vector2(w * 0.315, h * 0.56)]), Color("e8d8b8"))
			1:
				for y in 40:
					c.draw_rect(Rect2(0, y * h * 0.5 / 40.0, w, h * 0.5 / 40.0 + 1), Color("16204a").lerp(Color("3a4a7a"), y / 40.0))
				for i in 30:
					c.draw_circle(Vector2(rng.randf() * w, rng.randf() * h * 0.4), 1.2, Color(1, 1, 0.9, 0.8))
				c.draw_rect(Rect2(0, h * 0.5, w, h * 0.5), Color("1a3020"))
				c.draw_rect(Rect2(w * 0.2, h * 0.32, w * 0.6, h * 0.22), Color("d8cfb8"))
				c.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.4, h * 0.32), Vector2(w * 0.5, h * 0.22), Vector2(w * 0.6, h * 0.32)]), Color("a89060"))
				for i in 7:
					c.draw_rect(Rect2(w * (0.24 + i * 0.08), h * 0.37, w * 0.04, h * 0.08), Color("ffd27a"))
				for i in 8:
					c.draw_circle(Vector2(w * (0.06 + i * 0.13), h * 0.56), w * 0.07, Color("0f2016"))
				c.draw_rect(Rect2(w * 0.44, h * 0.54, w * 0.12, h * 0.46), Color("8a7a5a"))
			_:
				c.draw_rect(Rect2(0, 0, w, h), Color("2a1c14"))
				c.draw_rect(Rect2(0, h * 0.66, w, h * 0.34), Color("5a3a22"))
				c.draw_circle(Vector2(w * 0.5, h * 0.62), w * 0.3, Color("c9a050"))
				c.draw_rect(Rect2(w * 0.2, h * 0.5, w * 0.6, h * 0.14), Color("2a1c14"))
				for p in [Vector2(0.38, 0.5), Vector2(0.52, 0.47), Vector2(0.64, 0.51), Vector2(0.46, 0.43), Vector2(0.58, 0.41)]:
					c.draw_circle(Vector2(p.x * w, p.y * h), w * 0.08, [Color("a3162a"), Color("e0a030"), Color("6a8a2a"), Color("7a2a5a"), Color("d86a20")][int(p.x * 100) % 5])
				c.draw_rect(Rect2(w * 0.72, h * 0.3, w * 0.1, h * 0.36), Color("3a5a3a"))
				c.draw_rect(Rect2(w * 0.74, h * 0.22, w * 0.06, h * 0.1), Color("3a5a3a"))
		# barniz y grietas del cuadro viejo
		for i in 120:
			c.draw_line(Vector2(rng.randf() * w, rng.randf() * h), Vector2(rng.randf() * w, rng.randf() * h), Color(0, 0, 0, 0.03), 1.0)
		c.draw_rect(Rect2(0, 0, w, h), Color(0.4, 0.3, 0.1, 0.12))
	return _paint(Vector2i(300, 440), draw_it)


## La noche tras los ventanales: cielo azul oscuro, luces de la ciudad y la luna
func _night_tex() -> Texture2D:
	return _paint(Vector2i(256, 512), func(c: Control):
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for y in 64:
			c.draw_rect(Rect2(0, y * 8, 256, 8), Color("070b1a").lerp(Color("1a2348"), y / 64.0))
		c.draw_circle(Vector2(180, 90), 18, Color("efe6c8"))
		for i in 60:
			c.draw_circle(Vector2(rng.randf() * 256, rng.randf() * 260), rng.randf_range(0.6, 1.4), Color(1, 1, 1, rng.randf_range(0.3, 0.9)))
		var x := 0.0
		while x < 256.0:
			var bw := rng.randf_range(18, 46)
			var bh := rng.randf_range(80, 230)
			c.draw_rect(Rect2(x, 512 - bh, bw, bh), Color("0b0f1c"))
			var wy := 512 - bh + 8
			while wy < 504:
				var wx := x + 4
				while wx < x + bw - 5:
					if rng.randf() < 0.45:
						c.draw_rect(Rect2(wx, wy, 4, 5), Color(1.0, 0.82, 0.45, rng.randf_range(0.5, 1.0)))
					wx += 8
				wy += 10
			x += bw + rng.randf_range(0, 6))


func _ceiling() -> void:
	var w := X1 - X0
	var d := Z1 - Z0
	var cz := (Z0 + Z1) * 0.5
	var cream := Kit.plaster(Color("efe4cc"))
	var deep := Kit.plaster(Color("c9b48a"))
	var gold := Kit.gold()
	b.cube(Vector3(0, H + 0.35, cz), Vector3(w, 0.1, d), deep)
	# artesonado: vigas cada 2,4 m con canto dorado
	var step := 2.4
	var x := X0
	while x <= X1 + 0.01:
		b.cube(Vector3(x, H + 0.15, cz), Vector3(0.3, 0.3, d), cream)
		b.cube(Vector3(x, H - 0.005, cz), Vector3(0.32, 0.02, d), gold)
		x += step
	var z := Z0
	while z <= Z1 + 0.01:
		b.cube(Vector3(0, H + 0.15, z), Vector3(w, 0.3, 0.3), cream)
		b.cube(Vector3(0, H - 0.005, z), Vector3(w, 0.02, 0.32), gold)
		z += step
	# rosetas en el centro de los casetones
	x = X0 + step * 0.5
	while x < X1:
		z = Z0 + step * 0.5
		while z < Z1:
			b.lathe(Transform3D(Basis(Vector3.RIGHT, PI), Vector3(x, H + 0.3, z)), [Vector2(0.0, 0.0), Vector2(0.22, 0.0), Vector2(0.18, 0.04), Vector2(0.08, 0.07), Vector2(0.0, 0.08)], gold, 16)
			z += step
		x += step
	for p in [Vector3(RT.x, H, RT.z), Vector3(BJ.x, H, BJ.z), Vector3(PK.x, H, PK.z + 0.2)]:
		place("Chandelier", Transform3D(Basis(), p))
		glow(p + Vector3(0, -1.15, 0), 2.2, Color(1, 0.82, 0.55, 0.32))


func _vip() -> void:
	# tarima con moqueta roja y canto dorado, cordones de terciopelo y la mesa de póker
	var dais := Kit.pbr("carpet", {"c0": "6a1018", "c1": "2a0a10"}, 3.4, 0.95, Color.WHITE, 0.8)
	b.box(Transform3D(Basis(), Vector3(0, 0.075, PK.z - 0.2)), Vector3(7.0, 0.15, 4.4), dais)
	b.box(Transform3D(Basis(), Vector3(0, 0.15, PK.z + 2.0)), Vector3(7.04, 0.012, 0.05), Kit.gold())
	place("PK_Table", Transform3D(Basis(), PK + Vector3(0, 0.15, 0)), null, {"Felt": _mats["Felt_PK"]})
	for x in [-3.0, -1.8, 1.8, 3.0]:
		place("Stanchion", Transform3D(Basis(), Vector3(x, 0, PK.z + 2.45)))
	for x in [-2.4, 2.4]:
		place("Rope", Transform3D(Basis(), Vector3(x, 0, PK.z + 2.45)))
	for p in [Vector3(-0.7, 0.15, 0.75), Vector3(0.7, 0.15, 0.75), Vector3(-0.7, 0.15, -0.75), Vector3(0.7, 0.15, -0.75), Vector3(1.55, 0.15, 0.0)]:
		var yaw := PI if p.z > 0.0 else 0.0
		if p.x > 1.4:
			yaw = -PI / 2.0
		place("Chair", Transform3D(Basis(Vector3.UP, yaw), PK + p))
	# fichas y cartas sobre el paño de la partida privada
	for k in 4:
		var a := TAU * k / 4.0 + 0.5
		var cp := PK + Vector3(cos(a) * 0.6, 0.15 + TOP, sin(a) * 0.3)
		chip_stack(250.0 + k * 300.0, cp, world)
	for k in 5:
		var cd := card(_rng.randi() % 52, true)
		world.add_child(cd)
		cd.global_transform = Transform3D(Basis(Vector3.UP, _rng.randf_range(-0.1, 0.1)), PK + Vector3(-0.3 + k * 0.075, 0.15 + TOP + 0.001, 0.0))


func _roulette() -> void:
	var t := place("RT_Table", Transform3D(Basis(), RT))
	tables["ruleta"] = t
	for x in [-0.6, 0.75, 1.3]:
		place("Chair", Transform3D(Basis(Vector3.UP, PI), RT + Vector3(x, 0, 1.0)))
	wheel = Node3D.new()
	world.add_child(wheel)
	wheel.global_position = RT + RW_AT
	wheel.add_child(piece("RW_Bowl"))
	rotor = piece("RW_Rotor")
	wheel.add_child(rotor)
	ball = piece("RW_Ball")
	wheel.add_child(ball)
	ball.position = Vector3(RW_TRACK_R, RW_TRACK_Y, 0)
	Kit.blob(world, wheel.global_position, 0.95, 0.95, 0.5)
	dolly = piece("Dolly")
	world.add_child(dolly)
	dolly.visible = false
	# el paño de las apuestas: pantalla con ratón sobre la mesa
	var xf := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), RT + LAYOUT_AT + Vector3(Layout.SIZE.x, 0, Layout.SIZE.y) * 0.0005)
	var holder := screen(Vector2i(Layout.SIZE), xf, Layout.SIZE.x * 0.001, Layout.FELT, 0.42, 1.0, true, "", true)
	layout = Layout.new()
	holder.add_child(layout)
	(holder.get_parent() as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS


## Punto de la mesa de ruleta (en el mundo) para un punto del paño en píxeles
func layout_point(px: Vector2) -> Vector3:
	return RT + LAYOUT_AT + Vector3(px.x * 0.001, 0.0, px.y * 0.001)


func _blackjack() -> void:
	var t := place("BJ_Table", Transform3D(Basis(), BJ), null, {"Felt": _mats["Felt_BJ"]})
	tables["blackjack"] = t
	for n in ["BJ_Tray", "BJ_Shoe", "BJ_Discard"]:
		place(n, Transform3D(Basis(), BJ))
	# fichas de la banca en la bandeja
	for k in 8:
		var v: int = [500, 500, 100, 100, 25, 25, 5, 5][k]
		for j in 14:
			var ch := chip(v)
			world.add_child(ch)
			ch.global_transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), BJ + Vector3(-0.21 + k * 0.06, TOP + 0.034, -0.29 - 0.05 + j * CHIP_H))


func _slots() -> void:
	for i in SLOTS_X.size():
		var root := Node3D.new()
		world.add_child(root)
		root.global_position = Vector3(SLOTS_X[i], 0, SLOTS_Z)
		var lights: StandardMaterial3D = Kit.emissive(Color("ffd27a"), 2.0).duplicate()
		var sign_mat := StandardMaterial3D.new()
		var sv := SubViewport.new()
		sv.size = Vector2i(540, 240)
		sv.disable_3d = true
		sv.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(sv)
		var sc := Control.new()
		sc.size = Vector2(540, 240)
		sv.add_child(sc)
		var st := {"title": "GRAN PREMIO", "line": "APUESTA 25 M€", "lit": 0.0}
		sc.draw.connect(func(): Art.slot_sign(sc, sc.size, st["title"], st["line"], st["lit"]))
		sign_mat.albedo_texture = sv.get_texture()
		sign_mat.emission_enabled = true
		sign_mat.emission_texture = sv.get_texture()
		sign_mat.emission_energy_multiplier = 1.1
		root.add_child(piece("SL_Cabinet", {"SL_Lights": lights, "SL_Sign": sign_mat}))
		var reels := []
		for r in 3:
			var rn := piece("SL_Reel_%d" % r, {"SL_Reel": _mats["SL_Reel_%d" % r]})
			root.add_child(rn)
			reels.append(rn)
		var lever := piece("SL_Lever")
		root.add_child(lever)
		Kit.blob(world, root.global_position, 0.9, 0.8, 0.5)
		glow(root.global_position + Vector3(0, 1.62, 0.3), 1.2, Color(1, 0.7, 0.3, 0.25))
		var s := {"root": root, "reels": reels, "lever": lever, "lights": lights, "sign_vp": sv, "sign": sc, "sign_st": st, "rot": [0.0, 0.0, 0.0], "spin": []}
		slots.append(s)
		for r in 3:
			set_reel(i, r, _rng.randi() % 12)
		place("Stool", Transform3D(Basis(Vector3.UP, PI), root.global_position + Vector3(0, 0, 0.75)))


func _cashier() -> void:
	tables["caja"] = place("Cashier", Transform3D(Basis(), CAJA))
	var lbl := Kit.label(world, "CAJA", UI.f_serif_b, 90, Color("e9c46a"), CAJA + Vector3(0, 2.42, 0.29), Vector3.ZERO, 0.0026)
	lbl.shaded = false
	# pilas de fichas tras la reja
	for k in 6:
		chip_stack([500.0, 1500.0, 900.0, 300.0, 2500.0, 700.0][k], CAJA + Vector3(-0.5 + k * 0.2, 1.14, -0.05), world)
	glow(CAJA + Vector3(0, 2.1, 0.2), 1.3, Color(1, 0.8, 0.5, 0.4))


func _lobby() -> void:
	# velador alto del vestíbulo, donde el anfitrión ofrece sus cosas
	var c := LOBBY_TABLE
	b.lathe(Transform3D(Basis(), c), [Vector2(0.0, 0.0), Vector2(0.26, 0.0), Vector2(0.26, 0.03), Vector2(0.11, 0.08), Vector2(0.045, 0.14), Vector2(0.035, 1.0), Vector2(0.07, 1.02), Vector2(0.0, 1.03)], Kit.gold(), 24)
	b.cylinder(Transform3D(Basis(), c + Vector3(0, 1.05, 0)), 0.36, 0.36, 0.04, Kit.wood("marmol"), 40)
	b.cylinder(Transform3D(Basis(), c + Vector3(0, 1.03, 0)), 0.365, 0.365, 0.012, Kit.gold(), 40)
	Kit.blob(world, c, 0.7, 0.7, 0.5)


func _lights() -> void:
	env.ambient_light_color = Color(0.9, 0.7, 0.55)
	env.ambient_light_energy = 0.36
	env.background_color = Color(0.03, 0.02, 0.02)
	for p in [Vector3(RT.x, H - 1.9, RT.z), Vector3(BJ.x, H - 1.9, BJ.z), Vector3(PK.x, H - 1.9, PK.z)]:
		omni(p, 2.4, 9.5, Color(1.0, 0.82, 0.6), false)
	spot(Vector3(RT.x + 0.2, H - 0.4, RT.z + 1.2), RT + Vector3(0.1, TOP, 0), 3.2, 34.0, Color(1.0, 0.9, 0.75), hi, 9.0)
	spot(Vector3(BJ.x, H - 0.4, BJ.z + 1.2), BJ + Vector3(0, TOP, 0), 3.0, 32.0, Color(1.0, 0.9, 0.75), hi, 9.0)
	spot(Vector3(PK.x, H - 0.4, PK.z + 1.4), PK + Vector3(0, TOP, 0), 2.4, 36.0, Color(1.0, 0.86, 0.7), false, 9.0)
	spot(Vector3(-6.5, H - 0.4, SLOTS_Z + 3.0), Vector3(-6.5, 1.2, SLOTS_Z), 2.0, 40.0, Color(1.0, 0.82, 0.62), false, 9.0)
	spot(Vector3(CAJA.x, H - 0.4, CAJA.z + 2.4), CAJA + Vector3(0, 1.2, 0), 1.8, 34.0, Color(1.0, 0.86, 0.68), false, 8.0)


# ------------------------------------------------------------------ gente

func _people() -> void:
	var croupier := {"g": "m", "skin": 1, "hair": "slick", "hc": 1, "glasses": 0, "suit": "121214", "shirt": "f4f4f4", "tie": "121214", "age": 1, "beard": "none", "eyes": "3b2a20"}
	var dealer := {"g": "f", "skin": 2, "hair": "bun", "hc": 0, "glasses": 0, "suit": "121214", "shirt": "f4f4f4", "tie": "", "age": 0, "eyes": "3b2a20"}
	var cashier := {"g": "f", "skin": 0, "hair": "bob", "hc": 4, "glasses": 1, "suit": "2a2a30", "shirt": "f4f4f4", "tie": "", "age": 1, "eyes": "4d6a80"}
	var guard := {"g": "m", "skin": 4, "hair": "buzz", "hc": 0, "glasses": 0, "suit": "0e0e10", "shirt": "e8e8e8", "tie": "0e0e10", "age": 1, "beard": "none", "eyes": "2a1c14"}
	people["croupier"] = person(croupier, RT + Vector3(-1.02, 0, -0.9), 0.25)
	people["dealer"] = person(dealer, BJ + Vector3(0, 0, -0.78), 0.0)
	people["cashier"] = person(cashier, CAJA + Vector3(0, 0, -0.55), 0.0, "", true, 2)
	people["guard"] = person(guard, Vector3(0.0, 0.15, PK.z + 2.75), 0.0, "", false, 3)
	people["host"] = person(host_look if not host_look.is_empty() else D.HOSTS["magnate"]["look"], HOST_SPOT, yaw_to(HOST_SPOT, Vector3(0, 0, 5.7)))
	# jugadores de la sala privada y mirones de la ruleta y del blackjack
	for p in [Vector3(-0.7, 0.15, 0.75), Vector3(0.7, 0.15, -0.75), Vector3(1.55, 0.15, 0.0)]:
		var yaw := PI if p.z > 0.0 else 0.0
		if p.x > 1.4:
			yaw = -PI / 2.0
		person(rand_look(_rng), PK + p + Vector3(0, 0, 0), yaw, "table", false, 3)
	# una pareja mira la ruleta desde lejos (no delante de la mesa: desde la silla del presidente les cortaba la cabeza)
	person(rand_look(_rng), RT + Vector3(1.9, 0, -1.6), -0.6, "", false, 2)
	person(rand_look(_rng), RT + Vector3(2.35, 0, -1.25), -0.9, "", false, 2)
	# y otra pareja junto al blackjack, de pie a un lado
	person(rand_look(_rng), BJ + Vector3(1.75, 0, -1.2), -0.9, "", false, 2)
	person(rand_look(_rng), BJ + Vector3(-1.9, 0, -1.4), 0.7, "", false, 2)


## El anfitrión: su aspecto (antes de montar la sala) y su nombre
func set_host(look: Dictionary, nm: String) -> void:
	host_look = look
	host_name = nm


## El anfitrión se acerca al presidente, esté donde esté
func host_to(where: String) -> void:
	var h: Node3D = people.get("host")
	if not is_instance_valid(h):
		return
	var dest := HOST_SPOT
	match where:
		"ruleta":
			dest = RT + Vector3(1.55, 0, 0.75)
		"blackjack":
			dest = BJ + Vector3(-1.2, 0, 0.9)
		"caja":
			dest = CAJA + Vector3(-1.2, 0, 1.3)
		"slot":
			dest = Vector3(SLOTS_X[0] + 1.6, 0, SLOTS_Z + 1.4)
	if h.global_position.distance_to(dest) < 0.1:
		return
	h.walk_to(dest, clampf(h.global_position.distance_to(dest) / 1.3, 0.6, 5.0))


# ------------------------------------------------------------------ cámara

func _stations() -> void:
	stations = {
		"vestibulo": [Vector3(0, 1.72, 5.7), Vector3(0, 1.15, -2.0), 64.0, Vector2(18.0, 7.0)],
		"caja": [CAJA + Vector3(0, 1.62, 0.98), CAJA + Vector3(0, 1.2, 0.1), 54.0, Vector2(5.0, 3.0)],
		"ruleta": [RT + Vector3(0.22, 1.66, 0.98), RT + Vector3(0.26, 0.66, -0.14), 60.0, Vector2(6.0, 3.0)],
		"rueda": [RT + Vector3(-0.42, 1.24, 0.62), RT + RW_AT + Vector3(0, 0.02, 0), 48.0, Vector2(2.0, 1.5)],
		"blackjack": [BJ + Vector3(0, 1.56, 1.04), BJ + Vector3(0, 1.1, 0.12), 63.0, Vector2(6.0, 3.0)],
	}
	for i in SLOTS_X.size():
		var p := Vector3(SLOTS_X[i], 0, SLOTS_Z)
		stations["slot%d" % i] = [p + Vector3(0, 1.6, 1.08), p + Vector3(0, 1.3, 0.0), 56.0, Vector2(4.0, 3.0)]


## Lleva la cámara a un sitio (de golpe con now)
func go(where: String, now := false) -> void:
	if not stations.has(where):
		return
	station = where
	var s: Array = stations[where]
	cam_pos = s[0]
	cam_look = s[1]
	fov_target = float(s[2])
	look_range = s[3]
	eye = cam_pos
	cam_speed = 2.2
	if now:
		cut()
	_set_lobby_picks(where == "vestibulo")


func _set_lobby_picks(on: bool) -> void:
	for pk in _lobby_picks:
		remove_pick(pk)
	_lobby_picks.clear()
	if not on:
		return
	var rt: Node3D = tables["ruleta"]
	_lobby_picks.append(add_pick(rt, AABB(Vector3(-1.45, 0, -0.7), Vector3(2.9, 1.0, 1.4)), "Ruleta\nPleno a 35 a 1. La banca siempre gana... casi siempre.", func(): picked.emit("ruleta", 0)))
	var bj: Node3D = tables["blackjack"]
	_lobby_picks.append(add_pick(bj, AABB(Vector3(-1.15, 0, -0.45), Vector3(2.3, 1.0, 1.2)), "Blackjack\nGánele a la banca sin pasarse de 21.", func(): picked.emit("blackjack", 0)))
	for i in slots.size():
		var idx := i
		var root: Node3D = slots[i]["root"]
		_lobby_picks.append(add_pick(root, AABB(Vector3(-0.34, 0, -0.3), Vector3(0.68, 2.0, 0.6)), "Tragaperras\nTres sellos presidenciales: 300 veces la apuesta.", func(): picked.emit("slot", idx), root.find_children("*", "MeshInstance3D", true, false).slice(0, 1)))
	_lobby_picks.append(add_pick(tables["caja"], AABB(Vector3(-0.85, 0, -0.4), Vector3(1.7, 2.5, 0.8)), "Caja\nCambiar las fichas y dar por terminada la noche.", func(): picked.emit("caja", 0)))


# ------------------------------------------------------------------ fichas

## Una ficha suelta del valor v (de pie: la cara mira a +Y)
func chip(v: int) -> MeshInstance3D:
	var key := v if _chip_mats.has(v) else 5
	return piece("Chip", _chip_mats[key]) as MeshInstance3D


## Descompone una cantidad en fichas (de mayor a menor)
static func chips_for(amount: float, max_n := 24) -> Array:
	var out := []
	var left := int(round(amount))
	for v in [500, 100, 25, 5]:
		while left >= v and out.size() < max_n:
			out.append(v)
			left -= v
	return out


## Montón de fichas por la cantidad amount en pos (pilas de cada valor, una junto a otra)
func chip_stack(amount: float, pos: Vector3, parent: Node3D) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.global_position = pos
	var list := chips_for(amount)
	var piles := {}
	for v in list:
		piles[v] = int(piles.get(v, 0)) + 1
	var k := 0
	for v in [500, 100, 25, 5]:
		if not piles.has(v):
			continue
		var off := Vector3((k % 2) * 0.043 - 0.02, 0, (k / 2) * 0.043 - 0.02) if piles.size() > 1 else Vector3.ZERO
		for j in int(piles[v]):
			var c := chip(v)
			n.add_child(c)
			c.position = off + Vector3(randf_range(-0.0012, 0.0012), j * CHIP_H, randf_range(-0.0012, 0.0012))
			c.rotation.y = randf() * TAU
		k += 1
	return n


## Mueve un montón de fichas hasta to y lo quita (fichas perdidas que recoge el crupier) o lo deja allí
func slide(n: Node3D, to: Vector3, dur := 0.5, remove := true) -> void:
	if not is_instance_valid(n):
		return
	var t := n.create_tween()
	t.tween_property(n, "global_position", to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if remove:
		t.tween_callback(n.queue_free)


# ------------------------------------------------------------------ cartas

## Carta 3D (tumbada, la cara arriba si face_up). c: 0..51
func card(c: int, face_up: bool) -> Node3D:
	var n := Node3D.new()
	var key := c
	if not _card_mats.has(key):
		_card_mats[key] = _card_mat(_card_atlas, Vector2(1.0 / 13.0, 0.25), Vector2((c % 13) / 13.0, (c / 13) * 0.25))
	var f := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = CARD
	f.mesh = q
	f.material_override = _card_mats[key]
	f.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, 0.0004, 0))
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(f)
	var bk := MeshInstance3D.new()
	bk.mesh = q
	bk.material_override = _card_back_mat
	bk.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, -0.0004, 0))
	bk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(bk)
	n.set_meta("up", face_up)
	if not face_up:
		n.rotate_object_local(Vector3.BACK, PI)
	return n


## Reparte una carta desde el sabot hasta to (posición en el mundo, girada yaw); se da la vuelta por el camino si va
## boca arriba. Llama a done al llegar
func deal_card(c: int, to: Vector3, face_up: bool, delay := 0.0, yaw := 0.0, done := Callable()) -> Node3D:
	var n := card(c, false)
	world.add_child(n)
	var from := Transform3D(Basis(Vector3.BACK, PI) * Basis(Vector3.RIGHT, 0.5), BJ + BJ_SHOE)
	n.global_transform = from
	n.visible = delay <= 0.0
	var end := Transform3D(Basis(Vector3.UP, yaw + randf_range(-0.05, 0.05)), to)
	if not face_up:
		end = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, PI), to + Vector3(0, 0.0008, 0))
	var t := n.create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
		t.tween_callback(func(): n.visible = true)
	t.tween_callback(func(): Sfx.play("card", -6.0, 1.0, 0.1))
	var fly := func(k: float) -> void:
		var xf := from.interpolate_with(end, k)
		xf.origin.y += sin(k * PI) * 0.06
		n.global_transform = xf
	t.tween_method(fly, 0.0, 1.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	n.set_meta("up", face_up)
	if done.is_valid():
		t.tween_callback(done)
	return n


## Da la vuelta a una carta (la carta tapada de la banca)
func flip(n: Node3D, c: int) -> void:
	if not is_instance_valid(n):
		return
	var start := n.global_transform
	var yaw := start.basis.get_euler().y
	var turn := func(k: float) -> void:
		n.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, PI * (1.0 - k)), start.origin + Vector3(0, sin(k * PI) * 0.05 - 0.0008 * k, 0))
	var t := n.create_tween()
	t.tween_method(turn, 0.0, 1.0, 0.3)
	n.set_meta("up", true)
	Sfx.play("card", -8.0, 1.2)


## Recoge cartas y fichas de la mesa: se deslizan hacia el descarte y desaparecen
func sweep(nodes: Array, to: Vector3) -> void:
	for n in nodes:
		if is_instance_valid(n):
			slide(n, to, 0.45, true)


# ------------------------------------------------------------------ ruleta

## Ángulo (en el plato) del centro de la casilla i de la rueda (en el orden de D.WHEEL)
static func pocket_angle(i: int) -> float:
	return PI / 2.0 - i * TAU / 37.0


## Lanza la bola: cae en el número n y entonces llama a done
func spin_wheel(n: int, done: Callable) -> void:
	_rotor_w = 1.9
	var a0 := randf() * TAU
	_ball_st = {"t": 0.0, "T": 7.6, "drop": 4.8, "a": a0, "w0": -10.5, "w1": -3.2, "pocket": D.WHEEL.find(n), "done": done, "stage": "pista"}
	ball.visible = true
	dolly.visible = false
	Sfx.loop_start("ball", "ball_roll", -4.0)


func _update_wheel(delta: float) -> void:
	_rotor_w = move_toward(_rotor_w, 0.45, delta * 0.1)
	_rotor_ang += _rotor_w * delta
	rotor.rotation.y = _rotor_ang
	if _ball_st.is_empty():
		return
	var st := _ball_st
	var t: float = st["t"] + delta
	st["t"] = t
	var drop: float = st["drop"]
	var tt: float = st["T"]
	if st["stage"] == "pista":
		var w: float = lerpf(float(st["w0"]), float(st["w1"]), smoothstep(0.0, drop, t))
		st["a"] = float(st["a"]) + w * delta
		_ball_at(float(st["a"]), RW_TRACK_R, RW_TRACK_Y)
		if t >= drop:
			st["stage"] = "cae"
			# ángulo de la bola respecto al plato y cuánto le falta (siguiendo en su sentido) hasta su casilla
			var rel0 := float(st["a"]) - _rotor_ang
			var target := pocket_angle(int(st["pocket"]))
			var rel_w := float(st["w1"]) - _rotor_w
			var span := tt - drop
			var d1 := fposmod(target - rel0, TAU) - TAU
			var best := d1
			for k in 3:
				var dk := d1 - TAU * k
				if absf(2.0 * dk / span - rel_w) < absf(2.0 * best / span - rel_w):
					best = dk
			st["rel0"] = rel0
			st["drel"] = best
			Sfx.loop_volume("ball", -8.0)
	elif st["stage"] == "cae":
		var s := clampf((t - drop) / (tt - drop), 0.0, 1.0)
		var e := 1.0 - (1.0 - s) * (1.0 - s)
		var rel := float(st["rel0"]) + float(st["drel"]) * e
		var r := lerpf(RW_TRACK_R, RW_POCKET_R, smoothstep(0.0, 0.55, s))
		var y := lerpf(RW_TRACK_Y, RW_POCKET_Y, smoothstep(0.0, 0.5, s))
		# rebotes en los separadores de las casillas
		if s > 0.35:
			var bk := (s - 0.35) / 0.65
			y += absf(sin(bk * PI * 5.0)) * (1.0 - bk) * 0.016
			if int(bk * 5.0) != int(st.get("bounce", -1)):
				st["bounce"] = int(bk * 5.0)
				Sfx.play("ball_drop", -10.0 - bk * 8.0, randf_range(0.9, 1.15))
		_ball_at(_rotor_ang + rel, r, y)
		if s >= 1.0:
			st["stage"] = "casilla"
			Sfx.loop_stop("ball", 0.2)
			var cb: Callable = st["done"]
			if cb.is_valid():
				cb.call_deferred()
	else:
		_ball_at(_rotor_ang + pocket_angle(int(st["pocket"])), RW_POCKET_R, RW_POCKET_Y)


func _ball_at(a: float, r: float, y: float) -> void:
	ball.position = Vector3(r * cos(a), y, -r * sin(a))


## Pone el marcador encima del número ganador del paño
func put_dolly(n: int) -> void:
	dolly.visible = true
	var p := layout_point(Layout.cell_center(n))
	dolly.global_position = p + Vector3(0, 0.25, 0)
	var t := dolly.create_tween()
	t.tween_property(dolly, "global_position", p, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ tragaperras

## Pone el rodillo r de la máquina m con el símbolo idx en la línea
func set_reel(m: int, r: int, idx: int) -> void:
	var a := _reel_angle(idx)
	slots[m]["rot"][r] = a
	(slots[m]["reels"][r] as Node3D).rotation.x = a


## Giro del rodillo que deja el símbolo idx (de 12) delante, en la línea de premio
static func _reel_angle(idx: int) -> float:
	return fposmod(1.5 * PI - TAU * (idx + 0.5) / 12.0, TAU)


## Gira los rodillos de la máquina m hasta stops; on_stop(r) al pararse cada uno y done al final
func spin_slot(m: int, stops: Array, on_stop: Callable, done: Callable) -> void:
	var s: Dictionary = slots[m]
	Sfx.loop_start("reels", "reels", -8.0)
	var lever: Node3D = s["lever"]
	var lt := lever.create_tween()
	lt.tween_property(lever, "rotation:x", 0.9, 0.18).set_trans(Tween.TRANS_SINE)
	lt.tween_property(lever, "rotation:x", 0.0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Sfx.play("lever", -2.0)
	var left := [3]
	for r in 3:
		var reel: Node3D = s["reels"][r]
		var from: float = s["rot"][r]
		var target := _reel_angle(int(stops[r]))
		# varias vueltas enteras (más en cada rodillo) y siempre hacia delante
		var to := from + fposmod(target - from, TAU) + TAU * (3 + r)
		var dur := 1.2 + r * 0.55
		var idx := r
		var t := reel.create_tween()
		t.tween_method(func(v: float): reel.rotation.x = v, from, to + 0.08, dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		t.tween_method(func(v: float): reel.rotation.x = v, to + 0.08, to, 0.12)
		t.tween_callback(func():
			s["rot"][idx] = fposmod(to, TAU)
			Sfx.play("reel_stop", -4.0, 1.0 + idx * 0.05)
			if on_stop.is_valid():
				on_stop.call(idx)
			left[0] -= 1
			if left[0] == 0:
				Sfx.loop_stop("reels", 0.15)
				if done.is_valid():
					done.call())


## Letrero de la máquina m
func slot_sign(m: int, title: String, line: String) -> void:
	var s: Dictionary = slots[m]
	s["sign_st"]["title"] = title
	s["sign_st"]["line"] = line
	_redraw_sign(s)


func _redraw_sign(s: Dictionary) -> void:
	(s["sign"] as Control).queue_redraw()
	(s["sign_vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE


## Luces de premio: parpadean durante dur segundos
func slot_win(m: int, dur: float) -> void:
	var s: Dictionary = slots[m]
	s["blink"] = dur


func _update_slots(delta: float) -> void:
	for s in slots:
		var lm: StandardMaterial3D = s["lights"]
		var bl := float(s.get("blink", 0.0))
		if bl > 0.0:
			s["blink"] = bl - delta
			var on := int(_t * 8.0) % 2 == 0
			lm.emission_energy_multiplier = 6.0 if on else 0.8
			s["sign_st"]["lit"] = 1.0 if on else 0.0
			_redraw_sign(s)
		else:
			lm.emission_energy_multiplier = 1.6 + 0.5 * sin(_t * 2.0 + float(s["root"].global_position.x))
			var lit := 0.5 + 0.5 * sin(_t * 3.0)
			if absf(float(s["sign_st"]["lit"]) - lit) > 0.2:
				s["sign_st"]["lit"] = lit
				_redraw_sign(s)


func _process(delta: float) -> void:
	super(delta)
	if is_instance_valid(rotor):
		_update_wheel(delta)
	_update_slots(delta)
