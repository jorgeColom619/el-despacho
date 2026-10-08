extends RefCounted
## Construye la sala del despacho 3D: paredes con damasco, boiserie con cuarterones y molduras, techo
## artesonado, ventana con cortinas de terciopelo, puerta doble con pasillo, chimenea de mármol,
## librerías, sofá Chesterfield, sillones, escritorio, sillón giratorio, lámpara de araña con
## cristales, apliques, plantas y luces. Guarda las referencias que el despacho necesita animar.
## Ejes: X a la derecha, Y arriba; el presidente, sentado, mira hacia −Z (la puerta).

const Kit := preload("res://scripts/office3d/kit.gd")
const Tex := preload("res://scripts/office3d/tex3d.gd")
const OfficeArt := preload("res://scripts/office/office_art.gd")
const Batch := Kit.Batch

const X0 := -5.0
const X1 := 5.0
const Z0 := -5.0
const Z1 := 4.0
const H := 3.6
const WAIN := 1.05
## Ventanal de suelo casi a techo: desde el sillón se ve la plaza, la ciudad y el sol
const WINDOW := Rect2(-4.3, 0.45, 1.8, 2.55)
const DOOR := Rect2(-0.8, 0.0, 1.6, 2.6)
const DESK_TOP := 0.78
const DESK_Z := -1.0
const SEAT := Vector3(0, 0, 0.12)
const STAND := Vector3(0, 0, 1.0)
const VISITOR_SPOT := Vector3(0, 0, -2.45)
const CORRIDOR_START := Vector3(0, 0, -7.6)
## Dirección en la que viaja la luz del sol: entra por la parte alta del ventanal y, desde el sillón,
## el sol se ve por la ventana
const SUN_DIR := Vector3(0.545, -0.218, 0.809)
## Pared exterior: grosor de los muros (evita que la luz de fuera se cuele por paredes finas)
const SHELL := 0.34
## Capa de render exclusiva del muro exterior macizo: se excluye de la cámara del espejo
const SHELL_LAYER := 1 << 5

var root: Node3D
var theme: Dictionary
var b := Batch.new()
var m := {}
## Referencias para animar
var door_l: Node3D
var door_r: Node3D
var door_bodies: Array = []
## Luz del sol (o de la luna, de noche) que entra por el ventanal
var window_light: DirectionalLight3D
## Cortinas: mallas que se regeneran al abrirlas o cerrarlas (0 = recogidas, 1 = cerradas)
var curtains: Array = []
var curtain_body: StaticBody3D
var curtain_amount := 0.0
## Asientos donde puede sentarse el presidente además de su sillón: {pos, yaw, eye, stand, body, title}
var seats: Array = []
## Mapa del mundo enmarcado en la pared del fondo
var map_mesh: MeshInstance3D
var map_mat: ShaderMaterial
var chandelier_light: OmniLight3D
var sconce_lights: Array = []
var fire_light: OmniLight3D
var fire_quads: Array = []
var embers: CPUParticles3D
var dust: CPUParticles3D
var alert_light: OmniLight3D
var corridor_light: OmniLight3D
var clock_body: StaticBody3D
var clock_hour: Node3D
var clock_minute: Node3D
var clock_pendulum: Node3D
var tv_body: StaticBody3D
var tv_screen: MeshInstance3D
var chair_body: StaticBody3D
var portrait_canvas: MeshInstance3D
var flag_cloths: Array = []
var beam_mat: ShaderMaterial
var beam: MeshInstance3D
var bodies := {}
## Espejo de pared: superficie (se le asigna la textura de la cámara reflejada) y su cuerpo interactivo
var mirror_quad: MeshInstance3D
var mirror_body: StaticBody3D
## Plano del espejo en coordenadas del mundo (punto y normal hacia dentro de la sala)
var mirror_point := Vector3.ZERO
var mirror_normal := Vector3.RIGHT


func _init(parent: Node3D) -> void:
	root = parent
	theme = OfficeArt.THEMES.get(Perfil.office_theme(), OfficeArt.THEMES["clasico"])
	m["wall"] = Kit.pbr("wallpaper", {"c0": theme["wall"][1], "c1": theme["wall"][2], "acc": theme["damask"]}, 0.9, 0.78, Color.WHITE, 0.9)
	m["panel"] = Kit.panel_wood()
	m["panel_d"] = Kit.pbr("wood", Tex.wood_params("panel"), 0.6, 0.4, Color(0.62, 0.56, 0.52), 0.8)
	m["cream"] = Kit.plaster(Color("ebe2cb"))
	m["ceiling"] = Kit.plaster(Color("f1eadb"))
	m["gold"] = Kit.gold()
	m["desk"] = Kit.wood(Perfil.wood())
	m["caoba"] = Kit.wood("caoba")
	m["leather"] = Kit.pbr("leather", {}, 0.5, 0.6, Color("1d3a2f").lightened(0.18), 0.25)
	m["chair"] = Kit.tufted(Color("4a1712"), 0.22)
	m["chair_plain"] = Kit.leather(Color("4a1712"), 0.38)
	m["black"] = Kit.mat(Color("0c0c0e"), 0.35)
	m["iron"] = Kit.mat(Color("16130f"), 0.6, 0.6)
	m["marble"] = Kit.wood("marmol")
	m["curtain"] = Kit.velvet(Color(theme["curt"][2]))
	m["valance"] = Kit.velvet(Color(theme["val"][0]))
	m["sofa"] = Kit.tufted(Color("2a4434"), 0.26)
	m["sofa_plain"] = Kit.leather(Color("2a4434"), 0.36)
	m["glass"] = Kit.glass()
	m["soot"] = Kit.mat(Color("110c09"), 0.95)
	m["pot"] = Kit.mat(Color("1f3b35"), 0.12)
	m["bronze"] = Kit.mat(Color("6e5230"), 0.35, 0.8)
	m["candle"] = Kit.mat(Color("f3ecdc"), 0.5)
	m["floor"] = Kit.pbr("parquet", {}, 1.2, 0.26, Color.WHITE, 1.0, 0.0, 0.35)


func build() -> void:
	_floor_and_ceiling()
	_walls()
	_shell()
	_window()
	_door_and_corridor()
	_clock()
	_tv_and_credenza()
	_fireplace()
	_bookcase(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(X0, 0, -3.5)), 1.9, 11)
	_bookcase(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(X0, 0, 1.1)), 1.9, 23)
	_bookcase(Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(X1, 0, -3.2)), 1.9, 37)
	_back_wall()
	_seating()
	_mirror()
	_desk()
	_chair()
	_wastebasket()
	for p in [Vector3(-4.45, 0, 3.45), Vector3(4.45, 0, 3.45), Vector3(4.5, 0, -1.95)]:
		_plant(p)
	_bust(Vector3(4.6, 0, 2.3))
	_chandelier()
	_sconces()
	_light_shaft()
	_contact_shadows()
	b.commit(root)


# ------------------------------------------------------------------ suelo y techo

func _floor_and_ceiling() -> void:
	b.cube(Vector3(0, -0.05, -0.5), Vector3(10, 0.1, 9), m["floor"])
	Kit.solid(root, Vector3(0, -0.25, -2.5), Vector3(12, 0.5, 14))
	# alfombra persa con canto y flecos
	var rug := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(7.0, 5.6)
	rug.mesh = pm
	rug.material_override = Kit.pbr("carpet", {"c0": theme["carpet"][0], "c1": theme["carpet"][1]}, 1.0, 0.95, Color.WHITE, 0.9)
	rug.position = Vector3(0, 0.0165, DESK_Z)
	root.add_child(rug)
	b.cube(Vector3(0, 0.007, DESK_Z), Vector3(7.0, 0.014, 5.6), Kit.mat(Color(theme["carpet"][1]).darkened(0.35), 0.95), Vector3.ZERO, 1.0, 0.006)
	var fringe := StandardMaterial3D.new()
	fringe.albedo_texture = Tex.get_set("fringe")["albedo"]
	fringe.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	fringe.alpha_scissor_threshold = 0.5
	fringe.cull_mode = BaseMaterial3D.CULL_DISABLED
	fringe.roughness = 0.9
	fringe.uv1_scale = Vector3(36, 1, 1)
	for sx in [-1.0, 1.0]:
		var fq := MeshInstance3D.new()
		var fp := PlaneMesh.new()
		fp.size = Vector2(5.6, 0.09)
		fq.mesh = fp
		fq.material_override = fringe
		fq.position = Vector3(sx * 3.545, 0.004, DESK_Z)
		fq.rotation = Vector3(0, PI / 2.0 if sx > 0 else -PI / 2.0, 0)
		fq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(fq)
	# techo artesonado con molduras en cada casetón
	b.cube(Vector3(0, H + 0.05, -0.5), Vector3(10, 0.1, 9), m["ceiling"])
	Kit.solid(root, Vector3(0, H + 0.25, -0.5), Vector3(12, 0.5, 12))
	var xs := [-5.0, -3.75, -2.25, -0.75, 0.75, 2.25, 3.75, 5.0]
	var zs := [-5.0, -3.5, -2.0, -0.5, 1.0, 2.5, 4.0]
	for i in range(1, xs.size() - 1):
		b.cube(Vector3(xs[i], H - 0.07, -0.5), Vector3(0.16, 0.14, 9), m["ceiling"], Vector3.ZERO, 1.0, 0.02)
	for j in range(1, zs.size() - 1):
		b.cube(Vector3(0, H - 0.07, zs[j]), Vector3(10, 0.14, 0.16), m["ceiling"], Vector3.ZERO, 1.0, 0.02)
	for i in xs.size() - 1:
		for j in zs.size() - 1:
			var w: float = xs[i + 1] - xs[i] - 0.16
			var d: float = zs[j + 1] - zs[j] - 0.16
			if i == 0 or i == xs.size() - 2:
				w += 0.08
			if j == 0 or j == zs.size() - 2:
				d += 0.08
			var cx: float = (xs[i] + xs[i + 1]) * 0.5
			var cz: float = (zs[j] + zs[j + 1]) * 0.5
			b.frame(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(cx, H, cz)), w, d, Kit.FRAME_PANEL, m["ceiling"])
	# florón bajo la lámpara
	b.lathe(Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, H, DESK_Z)), [Vector2(0.46, 0.0), Vector2(0.45, 0.015), Vector2(0.4, 0.03), Vector2(0.33, 0.034), Vector2(0.27, 0.05), Vector2(0.2, 0.068), Vector2(0.14, 0.072), Vector2(0.09, 0.09), Vector2(0.0, 0.1)], m["ceiling"], 40)


# ------------------------------------------------------------------ paredes

## Rectángulos de [x0,x1]×[y0,y1] menos los huecos
static func subtract(x0: float, x1: float, y0: float, y1: float, holes: Array) -> Array:
	var xs := [x0, x1]
	for h in holes:
		var hr: Rect2 = h
		for e in [hr.position.x, hr.end.x]:
			if e > x0 and e < x1:
				xs.append(e)
	xs.sort()
	var out := []
	for i in xs.size() - 1:
		var a: float = xs[i]
		var bb: float = xs[i + 1]
		if bb - a < 0.0005:
			continue
		var ranges := [[y0, y1]]
		for h in holes:
			var hr2: Rect2 = h
			if hr2.position.x <= a + 0.0005 and hr2.end.x >= bb - 0.0005:
				var nr := []
				for r in ranges:
					var lo: float = r[0]
					var hi: float = r[1]
					if hr2.end.y <= lo or hr2.position.y >= hi:
						nr.append(r)
						continue
					if hr2.position.y > lo:
						nr.append([lo, hr2.position.y])
					if hr2.end.y < hi:
						nr.append([hr2.end.y, hi])
				ranges = nr
		for r2 in ranges:
			if r2[1] - r2[0] > 0.0005:
				out.append(Rect2(a, r2[0], bb - a, r2[1] - r2[0]))
	return out


## Tramos horizontales libres de huecos a la altura [y0, y1]
static func runs(hl: float, y0: float, y1: float, holes: Array) -> Array:
	var out := []
	for r in subtract(-hl, hl, y0, y1, holes):
		var rr: Rect2 = r
		if absf(rr.size.y - (y1 - y0)) < 0.001:
			out.append([rr.position.x, rr.end.x])
	return out


## deco_holes: cuadros colgados (la moldura dorada no pasa por detrás de ellos)
func _wall(xf: Transform3D, length: float, holes: Array, deco_holes: Array = []) -> void:
	var hl := length * 0.5
	b.rects(xf, subtract(-hl, hl, WAIN, H, holes), m["wall"], 1.0)
	b.rects(xf, subtract(-hl, hl, 0.0, WAIN, holes), m["panel"], 1.0)
	for r in runs(hl, WAIN - 0.035, WAIN + 0.035, holes):
		b.molding(xf * Transform3D(Basis(), Vector3(0, WAIN - 0.035, 0)), r[0], r[1], Kit.PROFILE_RAIL, m["panel_d"], true)
	for r in runs(hl, 0.0, 0.19, holes):
		b.molding(xf, r[0], r[1], Kit.PROFILE_BASE, m["panel_d"], true)
	b.molding(xf * Transform3D(Basis(), Vector3(0, H - 0.175, 0)), -hl, hl, Kit.PROFILE_CROWN, m["cream"])
	for r in runs(hl, 2.47, 2.49, holes + deco_holes):
		b.box(xf * Transform3D(Basis(), Vector3((r[0] + r[1]) * 0.5, 2.48, 0.006)), Vector3(r[1] - r[0], 0.018, 0.012), m["gold"], 1.0, 0.004)
	# cuarterones de la boiserie
	var px := -hl + 0.6
	while px < hl - 0.4:
		var pr := Rect2(px - 0.43, 0.2, 0.86, 0.68)
		var blocked := false
		for h in holes:
			if (h as Rect2).grow(0.04).intersects(pr):
				blocked = true
		if not blocked:
			b.box(xf * Transform3D(Basis(), Vector3(px, 0.54, 0.008)), Vector3(0.76, 0.58, 0.022), m["panel"], 1.0, 0.012)
			b.frame(xf * Transform3D(Basis(), Vector3(px, 0.54, 0.0)), 0.86, 0.68, Kit.FRAME_PANEL, m["panel_d"])
		px += 1.0
	# sombreado de rincones (suelo, techo)
	Kit.corner_ao(root, xf, length, 0.32, 0.38)
	Kit.corner_ao(root, xf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0.008, 0)), length, 0.4, 0.3)


func _walls() -> void:
	_wall(Transform3D(Basis(), Vector3(0, 0, Z0)), X1 - X0, [WINDOW, DOOR])
	# mapa del mundo (pared del fondo) y retrato sobre la chimenea (pared izquierda)
	_wall(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, Z1)), X1 - X0, [], [Rect2(-1.42, 1.3, 2.84, 1.7)])
	_wall(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(X0, 0, (Z0 + Z1) / 2.0)), Z1 - Z0, [Rect2(-0.5, 0.0, 2.4, 1.15)], [Rect2(0.09, 1.66, 1.22, 1.44)])
	_wall(Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(X1, 0, (Z0 + Z1) / 2.0)), Z1 - Z0, [])
	Kit.solid(root, Vector3(-2.9, H / 2.0, Z0 - 0.2), Vector3(4.2, H, 0.4))
	Kit.solid(root, Vector3(2.9, H / 2.0, Z0 - 0.2), Vector3(4.2, H, 0.4))
	Kit.solid(root, Vector3(0, H - 0.5, Z0 - 0.2), Vector3(1.6, 1.0, 0.4))
	Kit.solid(root, Vector3(0, H / 2.0, Z1 + 0.2), Vector3(10.4, H, 0.4))
	Kit.solid(root, Vector3(X0 - 0.2, H / 2.0, -0.5), Vector3(0.4, H, 9.4))
	Kit.solid(root, Vector3(X1 + 0.2, H / 2.0, -0.5), Vector3(0.4, H, 9.4))


## Muros, tejado y forjado con grosor real por fuera de la sala (y del pasillo). Desde dentro no se ven,
## pero tapan el sol: sin ellos la luz y la iluminación global atravesaban las paredes finas.
func _shell() -> void:
	# en su propio Batch (no en el compartido "b"): así se puede poner en una capa aparte y
	# excluirla solo de la cámara del espejo, que queda fuera del edificio al reflejarse y, si no,
	# se topaba con este muro macizo en vez de ver la sala
	var sb := Batch.new()
	var sm := Kit.plaster(Color("d9cdb2"))
	var t := SHELL
	var y0 := -0.6
	var y1 := H + 0.6
	# fachada: rodea el ventanal (con holgura para no pelearse con el derrame) y la boca del pasillo
	for r in subtract(X0 - t, X1 + t, y0, y1, [WINDOW.grow(0.05), Rect2(-1.3, 0.0, 2.6, 3.0)]):
		var rr: Rect2 = r
		sb.cube(Vector3(rr.get_center().x, rr.get_center().y, Z0 - 0.01 - t * 0.5), Vector3(rr.size.x, rr.size.y, t), sm)
	sb.cube(Vector3(0, (y0 + y1) * 0.5, Z1 + 0.01 + t * 0.5), Vector3(X1 - X0 + t * 2.0, y1 - y0, t), sm)
	sb.cube(Vector3(X0 - 0.01 - t * 0.5, (y0 + y1) * 0.5, (Z0 + Z1) * 0.5), Vector3(t, y1 - y0, Z1 - Z0 + t * 2.0), sm)
	sb.cube(Vector3(X1 + 0.01 + t * 0.5, (y0 + y1) * 0.5, (Z0 + Z1) * 0.5), Vector3(t, y1 - y0, Z1 - Z0 + t * 2.0), sm)
	sb.cube(Vector3(0, H + 0.11 + t * 0.5, (Z0 + Z1) * 0.5), Vector3(X1 - X0 + t * 2.0, t, Z1 - Z0 + t * 2.0), sm)
	sb.cube(Vector3(0, -0.11 - t * 0.5, (Z0 + Z1) * 0.5), Vector3(X1 - X0 + t * 2.0, t, Z1 - Z0 + t * 2.0), sm)
	# pasillo: muros laterales, techo, suelo y fondo. Acaban 2 cm por detrás de la pared del despacho:
	# si llegaban a su mismo plano, el yeso y el papel pintado se peleaban y junto a la puerta
	# salían franjas que parpadeaban
	var cz0 := -9.0
	var front := Z0 - 0.02
	var mid := (front + cz0) * 0.5
	var clen := front - cz0 + t
	for sx in [-1.0, 1.0]:
		sb.cube(Vector3(sx * (1.31 + t * 0.5), 1.5, mid - t * 0.5), Vector3(t, 3.8, clen), sm)
	sb.cube(Vector3(0, 3.06 + t * 0.5, mid - t * 0.5), Vector3(2.62 + t * 2.0, t, clen), sm)
	sb.cube(Vector3(0, -0.05 - t * 0.5, mid - t * 0.5), Vector3(2.62 + t * 2.0, t, clen), sm)
	sb.cube(Vector3(0, 1.5, cz0 - 0.01 - t * 0.5), Vector3(2.62 + t * 2.0, 3.8, t), sm)
	for mi in sb.commit(root):
		(mi as MeshInstance3D).layers = SHELL_LAYER


# ------------------------------------------------------------------ ventana

func _window() -> void:
	var c := WINDOW.get_center()
	var x0 := WINDOW.position.x
	var x1 := WINDOW.end.x
	var y0 := WINDOW.position.y
	var y1 := WINDOW.end.y
	var ws := WINDOW.size
	# derrame
	b.cube(Vector3(x0 - 0.03, c.y, Z0 - 0.16), Vector3(0.06, ws.y + 0.12, 0.32), m["cream"])
	b.cube(Vector3(x1 + 0.03, c.y, Z0 - 0.16), Vector3(0.06, ws.y + 0.12, 0.32), m["cream"])
	b.cube(Vector3(c.x, y1 + 0.03, Z0 - 0.16), Vector3(ws.x, 0.06, 0.32), m["cream"])
	b.cube(Vector3(c.x, y0 - 0.03, Z0 - 0.16), Vector3(ws.x, 0.06, 0.32), m["cream"])
	# hojas de la ventana: bastidor, cristal y junquillos
	var glass := Kit.mesh(root, Kit.quad_mesh(ws), m["glass"], Vector3(c.x, c.y, Z0 - 0.2))
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# el cristal también para objetos lanzados y al presidente
	Kit.solid(root, Vector3(c.x, c.y, Z0 - 0.2), Vector3(ws.x, ws.y, 0.06))
	b.frame(Transform3D(Basis(), Vector3(c.x, c.y, Z0 - 0.22)), ws.x, ws.y, [Vector2(0, 0), Vector2(0, 0.04), Vector2(0.01, 0.05), Vector2(0.05, 0.05), Vector2(0.06, 0.035), Vector2(0.065, 0.0)], m["cream"])
	b.cube(Vector3(c.x, c.y, Z0 - 0.19), Vector3(0.07, ws.y - 0.1, 0.06), m["cream"], Vector3.ZERO, 1.0, 0.01)
	for i in [1, 2]:
		b.cube(Vector3(x0 + ws.x * i / 4.0 + (0.0 if i == 1 else ws.x / 4.0), c.y, Z0 - 0.19), Vector3(0.035, ws.y - 0.1, 0.04), m["cream"], Vector3.ZERO, 1.0, 0.008)
	for j in [1, 2, 3]:
		b.cube(Vector3(c.x, y0 + ws.y * j / 4.0, Z0 - 0.19), Vector3(ws.x - 0.1, 0.035, 0.04), m["cream"], Vector3.ZERO, 1.0, 0.008)
	b.cube(Vector3(c.x, c.y + 0.25, Z0 - 0.17), Vector3(0.05, 0.12, 0.02), m["gold"], Vector3.ZERO, 1.0, 0.006)
	# guarnición, alféizar y faldón
	b.frame(Transform3D(Basis(), Vector3(c.x, c.y + 0.075, Z0)), ws.x + 0.3, ws.y + 0.15, Kit.FRAME_CASING, m["cream"], [false, true, true, true])
	b.cube(Vector3(c.x, y0 - 0.025, Z0 + 0.12), Vector3(ws.x + 0.44, 0.05, 0.28), m["cream"], Vector3.ZERO, 1.0, 0.012, 2)
	b.cube(Vector3(c.x, y0 - 0.11, Z0 + 0.02), Vector3(ws.x + 0.3, 0.12, 0.04), m["cream"], Vector3.ZERO, 1.0, 0.008)
	Kit.solid(root, Vector3(c.x, y0 - 0.025, Z0 + 0.12), Vector3(ws.x + 0.44, 0.05, 0.28))
	# cortinas (recogidas o cerradas), galería con flecos y alzapaños con borla
	_curtain(x0 - 0.68, x0 + 0.12, c.x + 0.03)
	_curtain(x1 + 0.68, x1 - 0.12, c.x - 0.03)
	set_curtains(0.0)
	curtain_body = StaticBody3D.new()
	curtain_body.collision_layer = 4
	curtain_body.collision_mask = 0
	curtain_body.position = Vector3(c.x, 1.7, Z0 + 0.1)
	root.add_child(curtain_body)
	Kit.add_shape(curtain_body, Kit.shape_box(Vector3(ws.x + 1.3, 3.3, 0.12)))
	var vw := ws.x + 1.55
	b.cube(Vector3(c.x, 3.25, Z0 + 0.14), Vector3(vw, 0.42, 0.14), m["valance"], Vector3.ZERO, 1.0, 0.03, 2)
	b.molding(Transform3D(Basis(), Vector3(c.x, 3.44, Z0 + 0.21)), -vw * 0.5, vw * 0.5, [Vector2(0, 0), Vector2(0.015, 0.005), Vector2(0.02, 0.02), Vector2(0.0, 0.03)], m["gold"], true)
	for i in 46:
		var fx := c.x - vw * 0.5 + 0.03 + i * (vw - 0.06) / 45.0
		b.cyl(Vector3(fx, 3.0, Z0 + 0.212), 0.008, 0.004, 0.08, m["gold"], Vector3.ZERO, 6)
		b.sphere(Vector3(fx, 2.955, Z0 + 0.212), 0.009, m["gold"], 6, 4)
	for sx in [x0 - 0.42, x1 + 0.42]:
		Kit.mesh(root, Kit.torus_mesh(0.05, 0.075, 20), m["gold"], Vector3(sx, 1.25, Z0 + 0.17), Vector3(PI / 2.0, 0, 0))
		b.segment(Vector3(sx, 1.2, Z0 + 0.2), Vector3(sx, 1.0, Z0 + 0.21), 0.006, m["gold"])
		b.lathe(Transform3D(Basis(), Vector3(sx, 0.86, Z0 + 0.21)), [Vector2(0.035, 0.0), Vector2(0.045, 0.06), Vector2(0.03, 0.12), Vector2(0.012, 0.14), Vector2(0.0, 0.15)], m["gold"], 12)
	# el sol (de noche, la luna): luz direccional que solo entra por el ventanal
	window_light = DirectionalLight3D.new()
	root.add_child(window_light)
	window_light.look_at_from_position(Vector3.ZERO, SUN_DIR.normalized(), Vector3.UP)
	window_light.shadow_enabled = true
	window_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	window_light.directional_shadow_max_distance = 24.0
	window_light.directional_shadow_split_1 = 0.35
	window_light.light_angular_distance = 0.6
	window_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	window_light.light_color = Color(1.0, 0.95, 0.86)
	window_light.light_energy = 3.0


## Cortina de terciopelo con pliegues. Recogida (0) se ciñe al alzapaños hacia el lado exterior;
## cerrada (1) cae recta hasta el centro del ventanal.
func _curtain(outer: float, inner_open: float, inner_closed: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = ArrayMesh.new()
	mi.material_override = m["curtain"]
	root.add_child(mi)
	curtains.append({"mi": mi, "outer": outer, "open": inner_open, "closed": inner_closed})


## Abre o cierra las cortinas (0 = recogidas, 1 = cerradas) regenerando sus mallas
func set_curtains(amount: float) -> void:
	curtain_amount = clampf(amount, 0.0, 1.0)
	var k := curtain_amount * curtain_amount * (3.0 - 2.0 * curtain_amount)
	for cd in curtains:
		var inner: float = lerpf(cd["open"], cd["closed"], k)
		_curtain_arrays(cd["mi"], cd["outer"], inner, k)


func _curtain_arrays(mi: MeshInstance3D, outer: float, inner: float, closed: float) -> void:
	var cols := 36
	var rows := 24
	var top := 3.36
	var bot := 0.02
	var grid := []
	for j in rows + 1:
		var row := []
		var y := lerpf(top, bot, float(j) / rows)
		var gather := 1.0 - 0.52 * exp(-pow((y - 1.25) / 0.42, 2.0)) * (1.0 - closed)
		var flare := 1.0 + 0.12 * clampf((0.9 - y) / 0.9, 0.0, 1.0) * (1.0 - closed)
		var folds := lerpf(1.3 - gather * 0.6, 0.85, closed)
		for i in cols + 1:
			var u := float(i) / cols
			var x := outer + (inner - outer) * u * gather * flare
			var depth := (sin(u * PI * 11.0) * 0.042 + sin(u * PI * 4.0 + 0.7) * 0.015) * folds
			row.append([Vector3(x, y, Z0 + 0.1 + depth), Vector2(u * 1.6, (top - y))])
		grid.append(row)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	for j in rows:
		for i in cols:
			var q := [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]]
			for tri in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
				var p0: Vector3 = tri[0][0]
				var n := ((tri[1][0] as Vector3) - p0).cross((tri[2][0] as Vector3) - p0).normalized()
				var order := [0, 1, 2]
				if n.z < 0.0:
					# la cara delantera tiene que mirar a la sala: si no, se ve la trasera y la luz la
					# trata como si mirase a la pared (la cortina izquierda salía rosa pálido)
					n = -n
					order = [0, 2, 1]
				# tangente: hacia donde crece u (a lo ancho, a la derecha o a la izquierda según la cortina);
				# la v crece hacia abajo
				var du: Vector3 = (grid[0][cols][0] as Vector3) - (grid[0][0][0] as Vector3)
				var tg := (Vector3(signf(du.x), 0, 0) - n * n.x * signf(du.x)).normalized()
				var w := -1.0 if du.x > 0.0 else 1.0
				for k in order:
					var v: Array = tri[k]
					verts.append(v[0])
					norms.append(n)
					uvs.append(v[1])
					tans.append_array([tg.x, tg.y, tg.z, w])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TANGENT] = tans
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var am := mi.mesh as ArrayMesh
	am.clear_surfaces()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


# ------------------------------------------------------------------ puerta y pasillo

func _door_and_corridor() -> void:
	var zf := Z0
	b.frame(Transform3D(Basis(), Vector3(0, 1.39, zf)), 1.96, 2.78, Kit.FRAME_CASING, m["cream"], [false, true, true, true])
	# bloques del zócalo: un poco más adelantados que el marco (a la misma altura, competían con
	# el relieve de la moldura justo ahí)
	for sx in [-0.9, 0.9]:
		b.cube(Vector3(sx, 0.12, zf + 0.055), Vector3(0.2, 0.24, 0.05), m["cream"], Vector3.ZERO, 1.0, 0.008)
	b.cube(Vector3(0, 2.96, zf + 0.03), Vector3(2.2, 0.3, 0.06), m["cream"], Vector3.ZERO, 1.0, 0.01)
	b.molding(Transform3D(Basis(), Vector3(0, 3.1, zf + 0.03)), -1.15, 1.15, Kit.PROFILE_CROWN, m["cream"], true)
	b.molding(Transform3D(Basis(), Vector3(0, 2.79, zf + 0.06)), -1.1, 1.1, Kit.PROFILE_RAIL, m["cream"], true)
	# umbral de mármol: antes era un listón casi de papel (2 cm) que, mirado hacia abajo en ángulo,
	# se "estiraba" por la perspectiva hasta parecer una muesca oscura en el marco de la puerta;
	# con margen extra de grosor para que no vuelva a pasar en ningún ángulo
	b.cube(Vector3(0, 0.03, Z0 - 0.05), Vector3(1.6, 0.06, 0.12), m["marble"])
	var seal := Sprite3D.new()
	seal.texture = OfficeArt.tex("seal", 1.5)
	seal.pixel_size = 0.0013
	seal.position = Vector3(0, 2.97, zf + 0.065)
	seal.shaded = true
	seal.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	root.add_child(seal)
	door_l = _leaf(Vector3(-0.8, 0, Z0 - 0.02), 1.0)
	door_r = _leaf(Vector3(0.8, 0, Z0 - 0.02), -1.0)
	Kit.solid(root, Vector3(0, 1.3, -6.1), Vector3(2.6, 2.6, 0.2))
	# pasillo
	var cw := 1.3
	var cz0 := -9.0
	var mid := (Z0 + cz0) / 2.0
	var corr := Kit.plaster(Color("dccba6"))
	for side in [[Basis(Vector3.UP, PI / 2.0), -cw], [Basis(Vector3.UP, -PI / 2.0), cw]]:
		var xf := Transform3D(side[0], Vector3(side[1], 0, mid))
		b.rects(xf, [Rect2(-2.0, 1.0, 4.0, 2.0)], corr)
		b.rects(xf, [Rect2(-2.0, 0.0, 4.0, 1.0)], m["panel"])
		b.molding(xf * Transform3D(Basis(), Vector3(0, 0.965, 0)), -2.0, 2.0, Kit.PROFILE_RAIL, m["panel_d"])
		b.molding(xf * Transform3D(Basis(), Vector3(0, 2.825, 0)), -2.0, 2.0, Kit.PROFILE_CROWN, m["cream"])
		Kit.corner_ao(root, xf, 4.0, 0.3, 0.4)
	b.rects(Transform3D(Basis(), Vector3(0, 0, cz0)), [Rect2(-cw, 0, cw * 2.0, 3.0)], corr)
	b.cube(Vector3(0, 3.0, mid), Vector3(cw * 2.0, 0.05, 4.0), m["ceiling"])
	b.cube(Vector3(0, -0.02, mid), Vector3(cw * 2.0, 0.04, 4.0), m["floor"])
	b.cube(Vector3(0, 0.006, mid), Vector3(1.3, 0.012, 4.0), Kit.mat(Color("8e2228"), 0.95), Vector3.ZERO, 1.0, 0.004)
	for sx in [-0.62, 0.62]:
		b.cube(Vector3(sx, 0.0125, mid), Vector3(0.04, 0.002, 4.0), m["gold"])
	b.frame(Transform3D(Basis(), Vector3(0, 1.9, cz0)), 1.0, 0.7, Kit.FRAME_ORNATE, m["gold"])
	Kit.mesh(root, Kit.quad_mesh(Vector2(0.84, 0.54)), Kit.tex_mat(_landscape_tex(), 0.9), Vector3(0, 1.9, cz0 + 0.02))
	corridor_light = OmniLight3D.new()
	corridor_light.position = Vector3(0, 2.6, -7.4)
	corridor_light.omni_range = 3.4
	corridor_light.light_energy = 1.6
	corridor_light.light_color = Color(1.0, 0.82, 0.58)
	root.add_child(corridor_light)


func _leaf(hinge: Vector3, dir: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = hinge
	root.add_child(pivot)
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	pivot.add_child(body)
	var lb := Batch.new()
	var cx := 0.4 * dir
	# madera satinada, sin laca: la laca reflejaba la lámpara de araña como un sol sobre la puerta
	var door_wood := Kit.pbr("wood", Tex.wood_params("caoba"), 0.6, 0.5, Color.WHITE, 0.8)
	lb.cube(Vector3(cx, 1.3, 0), Vector3(0.79, 2.6, 0.05), door_wood, Vector3.ZERO, 1.0, 0.006)
	for pnl in [[1.92, 1.0], [0.66, 0.8]]:
		for face in [1.0, -1.0]:
			var fz: float = 0.025 * face
			var xf := Transform3D(Basis(Vector3.UP, 0.0 if face > 0 else PI), Vector3(cx, pnl[0], fz))
			lb.frame(xf, 0.6, pnl[1], Kit.FRAME_PANEL, m["panel_d"])
			lb.box(xf * Transform3D(Basis(), Vector3(0, 0, 0.006)), Vector3(0.5, pnl[1] - 0.1, 0.014), door_wood, 1.0, 0.012, 2)
	for face2 in [1.0, -1.0]:
		var hz: float = 0.03 * face2
		lb.cube(Vector3(0.72 * dir, 1.05, hz), Vector3(0.05, 0.22, 0.01), m["gold"], Vector3.ZERO, 1.0, 0.004)
		lb.cyl(Vector3(0.72 * dir, 1.08, hz + 0.02 * face2), 0.018, 0.022, 0.035, m["gold"], Vector3(PI / 2.0, 0, 0), 16)
		lb.segment(Vector3(0.72 * dir, 1.08, hz + 0.04 * face2), Vector3(0.6 * dir, 1.08, hz + 0.045 * face2), 0.009, m["gold"], 10)
		lb.sphere(Vector3(0.6 * dir, 1.08, hz + 0.045 * face2), 0.012, m["gold"], 8, 5)
		lb.cyl(Vector3(0.72 * dir, 0.98, hz + 0.006 * face2), 0.008, 0.008, 0.01, m["black"], Vector3(PI / 2.0, 0, 0), 8)
	lb.commit(body)
	Kit.add_shape(body, Kit.shape_box(Vector3(0.8, 2.6, 0.05)), Vector3(cx, 1.3, 0))
	door_bodies.append(body)
	return pivot


# ------------------------------------------------------------------ reloj de pie

func _clock() -> void:
	var cx := 2.2
	var cz := Z0 + 0.2
	var cw: Material = m["caoba"]
	b.cube(Vector3(cx, 0.26, cz), Vector3(0.62, 0.48, 0.38), cw, Vector3.ZERO, 1.0, 0.01, 2)
	b.cube(Vector3(cx, 0.03, cz), Vector3(0.68, 0.06, 0.42), m["panel_d"], Vector3.ZERO, 1.0, 0.01)
	b.frame(Transform3D(Basis(), Vector3(cx, 0.27, cz + 0.19)), 0.46, 0.34, Kit.FRAME_PANEL, m["panel_d"])
	b.cube(Vector3(cx, 0.52, cz), Vector3(0.6, 0.04, 0.36), m["panel_d"], Vector3.ZERO, 1.0, 0.012)
	b.cube(Vector3(cx, 1.15, cz), Vector3(0.46, 1.24, 0.3), cw, Vector3.ZERO, 1.0, 0.01, 2)
	b.cube(Vector3(cx, 1.78, cz), Vector3(0.6, 0.04, 0.36), m["panel_d"], Vector3.ZERO, 1.0, 0.012)
	b.cube(Vector3(cx, 2.08, cz), Vector3(0.6, 0.58, 0.36), cw, Vector3.ZERO, 1.0, 0.012, 2)
	b.cube(Vector3(cx, 2.4, cz), Vector3(0.68, 0.05, 0.42), m["panel_d"], Vector3.ZERO, 1.0, 0.015)
	b.cyl(Vector3(cx, 2.44, cz), 0.3, 0.3, 0.36, cw, Vector3(PI / 2.0, 0, 0), 32)
	for sx in [-0.27, 0.27]:
		b.lathe(Transform3D(Basis(), Vector3(cx + sx, 1.8, cz + 0.17)), [Vector2(0.03, 0.0), Vector2(0.025, 0.03), Vector2(0.018, 0.05), Vector2(0.018, 0.52), Vector2(0.026, 0.55), Vector2(0.026, 0.58)], m["gold"], 12)
	for fx in [-0.3, 0.0, 0.3]:
		var fy := 2.75 if fx == 0.0 else 2.45
		b.lathe(Transform3D(Basis(), Vector3(cx + fx, fy, cz)), [Vector2(0.03, 0.0), Vector2(0.02, 0.02), Vector2(0.035, 0.05), Vector2(0.03, 0.08), Vector2(0.012, 0.1), Vector2(0.0, 0.13)], m["gold"], 14)
	# ventana del péndulo
	b.cube(Vector3(cx, 1.12, cz + 0.151), Vector3(0.3, 0.95, 0.004), m["soot"])
	var g := Kit.mesh(root, Kit.quad_mesh(Vector2(0.3, 0.95)), m["glass"], Vector3(cx, 1.12, cz + 0.165))
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.frame(Transform3D(Basis(), Vector3(cx, 1.12, cz + 0.15)), 0.36, 1.01, Kit.FRAME_PANEL, m["gold"])
	for wx in [-0.07, 0.07]:
		b.segment(Vector3(cx + wx, 1.55, cz + 0.08), Vector3(cx + wx, 1.05 + absf(wx) * 2.0, cz + 0.08), 0.002, m["gold"], 6)
		b.cyl(Vector3(cx + wx, 0.98 + absf(wx) * 2.0, cz + 0.08), 0.022, 0.022, 0.14, m["gold"], Vector3.ZERO, 14)
	# esfera
	var fz := cz + 0.18
	b.cube(Vector3(cx, 2.08, fz + 0.002), Vector3(0.48, 0.48, 0.006), m["gold"], Vector3.ZERO, 1.0, 0.003)
	b.cyl(Vector3(cx, 2.08, fz + 0.012), 0.2, 0.2, 0.012, Kit.mat(Color("f1e8d4"), 0.4), Vector3(PI / 2.0, 0, 0), 40)
	Kit.mesh(root, Kit.torus_mesh(0.195, 0.222, 48), m["gold"], Vector3(cx, 2.08, fz + 0.018), Vector3(PI / 2.0, 0, 0))
	for i in 12:
		var a := TAU * i / 12.0
		var p := Vector3(cx + sin(a) * 0.165, 2.08 + cos(a) * 0.165, fz + 0.019)
		b.box(Transform3D(Basis(Vector3.BACK, -a), p), Vector3(0.012 if i % 3 == 0 else 0.006, 0.035, 0.003), m["black"])
	for i2 in 60:
		if i2 % 5 != 0:
			var a2 := TAU * i2 / 60.0
			b.box(Transform3D(Basis(Vector3.BACK, -a2), Vector3(cx + sin(a2) * 0.178, 2.08 + cos(a2) * 0.178, fz + 0.019)), Vector3(0.003, 0.01, 0.002), m["black"])
	clock_hour = _hand(Vector3(cx, 2.08, fz + 0.022), 0.11, 0.014)
	clock_minute = _hand(Vector3(cx, 2.08, fz + 0.026), 0.16, 0.009)
	b.cyl(Vector3(cx, 2.08, fz + 0.03), 0.012, 0.012, 0.01, m["gold"], Vector3(PI / 2.0, 0, 0))
	clock_pendulum = Node3D.new()
	clock_pendulum.position = Vector3(cx, 1.58, cz + 0.12)
	root.add_child(clock_pendulum)
	var pb := Batch.new()
	pb.cube(Vector3(0, -0.36, 0), Vector3(0.012, 0.72, 0.006), m["gold"])
	pb.cyl(Vector3(0, -0.74, 0), 0.075, 0.075, 0.014, m["gold"], Vector3(PI / 2.0, 0, 0), 32)
	pb.cyl(Vector3(0, -0.74, 0.008), 0.05, 0.05, 0.004, Kit.mat(Color("e9cf8a"), 0.15, 0.95), Vector3(PI / 2.0, 0, 0), 24)
	pb.commit(clock_pendulum)
	clock_body = Kit.solid(root, Vector3(cx, 1.25, cz), Vector3(0.66, 2.5, 0.4))


func _hand(pos: Vector3, length: float, width: float) -> Node3D:
	var pv := Node3D.new()
	pv.position = pos
	root.add_child(pv)
	var hb := Batch.new()
	hb.box(Transform3D(Basis(), Vector3(0, length * 0.4, 0)), Vector3(width, length, 0.003), m["black"])
	hb.box(Transform3D(Basis(Vector3.BACK, PI / 4.0), Vector3(0, length * 0.72, 0)), Vector3(width * 1.6, width * 1.6, 0.003), m["black"])
	hb.commit(pv, false)
	return pv


# ------------------------------------------------------------------ televisor y aparador

func _tv_and_credenza() -> void:
	var cx := 3.75
	var cz := Z0 + 0.24
	var cw: Material = m["caoba"]
	b.cube(Vector3(cx, 0.44, cz), Vector3(1.8, 0.74, 0.48), cw, Vector3.ZERO, 1.0, 0.01, 2)
	b.cube(Vector3(cx, 0.835, cz + 0.01), Vector3(1.9, 0.045, 0.53), m["marble"], Vector3.ZERO, 1.0, 0.012, 2)
	b.cube(Vector3(cx, 0.05, cz), Vector3(1.86, 0.1, 0.5), m["panel_d"], Vector3.ZERO, 1.0, 0.012)
	for i in 3:
		var px := cx - 0.6 + i * 0.6
		var xf := Transform3D(Basis(), Vector3(px, 0.44, cz + 0.24))
		b.frame(xf, 0.54, 0.6, Kit.FRAME_PANEL, m["panel_d"])
		b.box(xf * Transform3D(Basis(), Vector3(0, 0, 0.006)), Vector3(0.44, 0.5, 0.014), cw, 1.0, 0.01, 2)
		var hx := px + (0.2 if i != 1 else 0.0)
		b.cube(Vector3(hx, 0.56, cz + 0.255), Vector3(0.02, 0.07, 0.006), m["gold"], Vector3.ZERO, 1.0, 0.003)
		b.sphere(Vector3(hx, 0.53, cz + 0.27), 0.014, m["gold"], 10, 6)
	Kit.solid(root, Vector3(cx, 0.43, cz), Vector3(1.9, 0.86, 0.53))
	tv_body = StaticBody3D.new()
	tv_body.position = Vector3(cx, 2.05, Z0 + 0.045)
	root.add_child(tv_body)
	var tb := Batch.new()
	tb.cube(Vector3.ZERO, Vector3(1.52, 0.9, 0.05), Kit.mat(Color("141518"), 0.25, 0.3), Vector3.ZERO, 1.0, 0.008, 2)
	tb.cube(Vector3(0, -0.43, 0.026), Vector3(1.44, 0.016, 0.004), Kit.mat(Color("2a2c31"), 0.2, 0.5))
	tb.commit(tv_body)
	tv_screen = Kit.mesh(tv_body, Kit.quad_mesh(Vector2(1.44, 0.82)), null, Vector3(0, 0.01, 0.0262))
	tv_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.add_shape(tv_body, Kit.shape_box(Vector3(1.52, 0.9, 0.06)))


# ------------------------------------------------------------------ chimenea y retrato

func _fireplace() -> void:
	var cz := -1.2
	var x := X0
	var fxf := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(x, 0, cz))
	var mb: Material = m["marble"]
	for s in [-1.0, 1.0]:
		var pz: float = cz + 0.8 * s
		b.cube(Vector3(x + 0.19, 0.6, pz), Vector3(0.38, 1.0, 0.34), mb, Vector3.ZERO, 1.0, 0.01, 2)
		b.cube(Vector3(x + 0.21, 0.06, pz), Vector3(0.42, 0.12, 0.4), mb, Vector3.ZERO, 1.0, 0.01, 2)
		b.cube(Vector3(x + 0.21, 1.03, pz), Vector3(0.42, 0.1, 0.4), mb, Vector3.ZERO, 1.0, 0.01, 2)
		b.frame(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(x + 0.38, 0.6, pz)), 0.24, 0.8, Kit.FRAME_PANEL, mb)
	b.cube(Vector3(x + 0.18, 0.98, cz), Vector3(0.36, 0.3, 1.26), mb, Vector3.ZERO, 1.0, 0.01, 2)
	b.frame(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(x + 0.36, 0.98, cz)), 1.1, 0.22, Kit.FRAME_PANEL, mb)
	b.molding(fxf * Transform3D(Basis(), Vector3(0, 1.065, 0.36)), -1.1, 1.1, Kit.PROFILE_RAIL, mb, true)
	b.cube(Vector3(x + 0.26, 1.17, cz), Vector3(0.52, 0.07, 2.3), mb, Vector3.ZERO, 1.0, 0.015, 2)
	b.cube(Vector3(x + 0.4, 0.02, cz), Vector3(0.8, 0.04, 2.36), mb, Vector3.ZERO, 1.0, 0.01, 2)
	# hogar de hierro
	b.cube(Vector3(x + 0.03, 0.43, cz), Vector3(0.06, 0.86, 1.26), m["iron"])
	for s2 in [-1.0, 1.0]:
		b.cube(Vector3(x + 0.18, 0.43, cz + 0.62 * s2), Vector3(0.3, 0.86, 0.02), m["iron"], Vector3(0, 0.25 * s2, 0))
	b.cube(Vector3(x + 0.18, 0.84, cz), Vector3(0.36, 0.02, 1.26), m["soot"])
	b.cube(Vector3(x + 0.2, 0.045, cz), Vector3(0.36, 0.01, 1.2), m["soot"])
	# morillos, troncos y brasas
	for dz in [-0.28, 0.28]:
		b.cube(Vector3(x + 0.22, 0.08, cz + dz), Vector3(0.3, 0.025, 0.025), m["iron"])
		b.lathe(Transform3D(Basis(), Vector3(x + 0.37, 0.05, cz + dz)), [Vector2(0.025, 0.0), Vector2(0.02, 0.05), Vector2(0.03, 0.09), Vector2(0.02, 0.12), Vector2(0.0, 0.14)], m["gold"], 12)
	var bark := Kit.pbr("wood", Tex.wood_params("ebano"), 0.3, 0.9, Color(0.75, 0.6, 0.5), 1.5)
	b.cyl(Vector3(x + 0.18, 0.13, cz), 0.055, 0.055, 0.62, bark, Vector3(PI / 2.0, 0, 0), 12)
	b.cyl(Vector3(x + 0.27, 0.13, cz - 0.05), 0.05, 0.05, 0.6, bark, Vector3(PI / 2.0, 0.2, 0), 12)
	b.cyl(Vector3(x + 0.22, 0.22, cz + 0.02), 0.045, 0.045, 0.55, bark, Vector3(PI / 2.0, -0.3, 0), 12)
	b.cube(Vector3(x + 0.2, 0.09, cz), Vector3(0.26, 0.02, 0.62), Kit.emissive(Color(1.0, 0.32, 0.06), 2.2), Vector3.ZERO, 1.0, 0.01)
	var fire_sh: Shader = load("res://shaders/fire3d.gdshader")
	for i in 4:
		var fm := ShaderMaterial.new()
		fm.shader = fire_sh
		fm.set_shader_parameter("seed", i * 3.7)
		var q := Kit.mesh(root, Kit.quad_mesh(Vector2(0.34 - i * 0.03, 0.48 - i * 0.05)), fm, Vector3(x + 0.22, 0.36 - i * 0.02, cz + (i - 1.5) * 0.13))
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fire_quads.append(fm)
	embers = CPUParticles3D.new()
	embers.position = Vector3(x + 0.22, 0.2, cz)
	embers.amount = 24
	embers.lifetime = 1.6
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(0.1, 0.05, 0.25)
	embers.direction = Vector3.UP
	embers.spread = 20.0
	embers.initial_velocity_min = 0.25
	embers.initial_velocity_max = 0.6
	embers.gravity = Vector3(0, 0.15, 0)
	embers.scale_amount_min = 0.4
	embers.scale_amount_max = 1.0
	var eq := QuadMesh.new()
	eq.size = Vector2(0.012, 0.012)
	var emat := StandardMaterial3D.new()
	emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	emat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	emat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	emat.albedo_texture = Kit.disc_tex()
	emat.albedo_color = Color(1.0, 0.55, 0.15)
	emat.vertex_color_use_as_albedo = true
	eq.material = emat
	embers.mesh = eq
	var eg := Gradient.new()
	eg.set_color(0, Color(1, 0.8, 0.4, 1))
	eg.set_color(1, Color(1, 0.3, 0.05, 0))
	embers.color_ramp = eg
	root.add_child(embers)
	fire_light = OmniLight3D.new()
	fire_light.position = Vector3(x + 0.6, 0.45, cz)
	fire_light.omni_range = 4.6
	fire_light.light_energy = 1.3
	fire_light.light_color = Color(1.0, 0.55, 0.22)
	fire_light.light_size = 0.06
	root.add_child(fire_light)
	# guardafuegos de latón y atizadores
	b.segment(Vector3(x + 0.72, 0.13, cz - 0.82), Vector3(x + 0.72, 0.13, cz + 0.82), 0.012, m["gold"], 12)
	b.segment(Vector3(x + 0.72, 0.05, cz - 0.82), Vector3(x + 0.72, 0.05, cz + 0.82), 0.008, m["gold"], 10)
	for s3 in [-1.0, 1.0]:
		b.segment(Vector3(x + 0.72, 0.13, cz + 0.82 * s3), Vector3(x + 0.42, 0.13, cz + 0.9 * s3), 0.012, m["gold"], 12)
		b.sphere(Vector3(x + 0.72, 0.15, cz + 0.82 * s3), 0.025, m["gold"], 10, 6)
	for k in 9:
		var zz := cz - 0.8 + k * 0.2
		b.segment(Vector3(x + 0.72, 0.05, zz), Vector3(x + 0.72, 0.13, zz), 0.004, m["gold"], 6)
	var tx := Vector3(x + 0.55, 0, cz + 1.42)
	b.lathe(Transform3D(Basis(), tx), [Vector2(0.11, 0.0), Vector2(0.1, 0.02), Vector2(0.03, 0.04), Vector2(0.012, 0.06), Vector2(0.012, 0.7), Vector2(0.03, 0.72), Vector2(0.0, 0.78)], m["gold"], 16)
	for t in 3:
		var a := TAU * t / 3.0
		var top := tx + Vector3(cos(a) * 0.05, 0.66, sin(a) * 0.05)
		var bot := tx + Vector3(cos(a) * 0.07, 0.08, sin(a) * 0.07)
		b.segment(bot, top, 0.006, m["iron"], 6)
		b.sphere(top + Vector3(0, 0.03, 0), 0.016, m["gold"], 8, 5)
	Kit.solid(root, Vector3(x + 0.19, 0.6, cz), Vector3(0.38, 1.2, 2.0))
	Kit.solid(root, Vector3(x + 0.26, 1.17, cz), Vector3(0.52, 0.07, 2.3))
	Kit.solid(root, Vector3(x + 0.72, 0.08, cz), Vector3(0.05, 0.16, 1.7))
	# retrato presidencial sobre la chimenea, con marco dorado y luz de cuadro
	b.frame(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(x, 2.38, cz)), 1.18, 1.4, Kit.FRAME_ORNATE, m["gold"])
	portrait_canvas = Kit.mesh(root, Kit.quad_mesh(Vector2(1.01, 1.23)), null, Vector3(x + 0.012, 2.38, cz), Vector3(0, PI / 2.0, 0))
	b.cube(Vector3(x + 0.1, 3.14, cz), Vector3(0.05, 0.04, 0.44), m["gold"], Vector3.ZERO, 1.0, 0.012)
	b.cube(Vector3(x + 0.1, 3.118, cz), Vector3(0.04, 0.004, 0.4), Kit.emissive(Color(1.0, 0.9, 0.7), 2.5))
	b.segment(Vector3(x + 0.0, 3.2, cz), Vector3(x + 0.1, 3.15, cz), 0.008, m["gold"], 8)


# ------------------------------------------------------------------ librerías

func _bookcase(xf: Transform3D, width: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var w := width
	var d := 0.4
	var hgt := 2.62
	var wood: Material = m["caoba"]
	b.box(xf * Transform3D(Basis(), Vector3(0, hgt / 2.0, 0.01)), Vector3(w, hgt, 0.02), m["panel_d"])
	for sx in [-w / 2.0 + 0.025, w / 2.0 - 0.025]:
		b.box(xf * Transform3D(Basis(), Vector3(sx, hgt / 2.0, d / 2.0)), Vector3(0.05, hgt, d), wood, 1.0, 0.008, 2)
		b.box(xf * Transform3D(Basis(), Vector3(sx, hgt / 2.0, d + 0.006)), Vector3(0.07, hgt - 0.2, 0.012), wood, 1.0, 0.004)
	b.box(xf * Transform3D(Basis(), Vector3(0, hgt + 0.03, d / 2.0)), Vector3(w + 0.04, 0.06, d), wood, 1.0, 0.01)
	b.molding(xf * Transform3D(Basis(), Vector3(0, hgt + 0.02, d)), -w / 2.0 - 0.02, w / 2.0 + 0.02, Kit.PROFILE_CROWN, m["panel_d"], true)
	var shelves := [0.12, 0.64, 1.16, 1.68, 2.2]
	for sy in shelves:
		b.box(xf * Transform3D(Basis(), Vector3(0, sy, d / 2.0)), Vector3(w - 0.06, 0.03, d - 0.02), wood, 1.0, 0.006)
		b.box(xf * Transform3D(Basis(), Vector3(0, sy - 0.005, d - 0.012)), Vector3(w - 0.06, 0.04, 0.02), wood, 1.0, 0.006)
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.05, d / 2.0)), Vector3(w, 0.1, d), m["panel_d"], 1.0, 0.008)
	var spine_mats := []
	for c in Tex.SPINES:
		var sm := Kit.pbr("spine", {"c": c}, 1.0, 0.55, Color.WHITE, 0.7)
		spine_mats.append(sm)
	var gold: Material = m["gold"]
	for si in range(1, shelves.size()):
		var base_y: float = shelves[si - 1] + 0.016
		var top_y: float = shelves[si] - 0.02
		var x := -w / 2.0 + 0.07
		var deco_at := rng.randf_range(-0.4, 0.5)
		var deco_kind := rng.randi() % 4
		while x < w / 2.0 - 0.09:
			if absf(x - deco_at) < 0.13:
				_shelf_deco(xf, Vector3(x + 0.11, base_y, d / 2.0 + 0.02), deco_kind, top_y - base_y, rng)
				x += 0.26
				continue
			if rng.randf() < 0.06 and x < w / 2.0 - 0.35:
				# pila de libros tumbados
				var sy2 := base_y
				for k in rng.randi_range(2, 4):
					var bh2 := rng.randf_range(0.03, 0.05)
					var bl2 := rng.randf_range(0.2, 0.26)
					b.box(xf * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.08, 0.08)), Vector3(x + 0.14, sy2 + bh2 / 2.0, d / 2.0 + 0.03)), Vector3(bl2, bh2, 0.2), spine_mats[rng.randi() % spine_mats.size()], 1.0, 0.0, 1, true)
					sy2 += bh2
				x += 0.3
				continue
			var bw := rng.randf_range(0.026, 0.056)
			var bh := minf(rng.randf_range(0.22, 0.42), top_y - base_y)
			var bm: Material = spine_mats[rng.randi() % spine_mats.size()]
			var lean := 0.0
			if rng.randf() < 0.04:
				lean = 0.16
			b.box(xf * Transform3D(Basis(Vector3.BACK, -lean), Vector3(x + bw / 2.0, base_y + bh / 2.0, d / 2.0 + 0.03)), Vector3(bw - 0.003, bh, 0.23), bm, 1.0, 0.0, 1, true)
			x += bw + (0.25 * bh if lean > 0.0 else 0.0)
	Kit.solid(root, xf * Vector3(0, hgt / 2.0, d / 2.0), Vector3(w, hgt, d), Vector3(0, xf.basis.get_euler().y, 0))
	Kit.blob(root, xf * Vector3(0, 0, d / 2.0 + 0.05), w + 0.25, 0.75, 0.45, xf.basis.get_euler().y)


## Adornos en los estantes: jarrón, globo pequeño, portarretratos o caja
func _shelf_deco(xf: Transform3D, p: Vector3, kind: int, max_h: float, rng: RandomNumberGenerator) -> void:
	match kind:
		0:
			var h := minf(0.3, max_h - 0.02)
			b.lathe(xf * Transform3D(Basis(), p), [Vector2(0.04, 0.0), Vector2(0.07, h * 0.25), Vector2(0.075, h * 0.45), Vector2(0.04, h * 0.8), Vector2(0.035, h * 0.92), Vector2(0.045, h), Vector2(0.0, h)], Kit.mat(Color("1f3552").lerp(Color("e8e2d4"), rng.randf() * 0.3), 0.08), 18)
		1:
			b.lathe(xf * Transform3D(Basis(), p), [Vector2(0.05, 0.0), Vector2(0.04, 0.02), Vector2(0.01, 0.04), Vector2(0.008, 0.08), Vector2(0.0, 0.09)], m["gold"], 12)
			b.sphere(xf * (p + Vector3(0, 0.15, 0)), 0.075, Kit.mat(Color("c9b07a"), 0.3), 16, 10)
		2:
			b.box(xf * Transform3D(Basis(Vector3.RIGHT, -0.15), p + Vector3(0, 0.11, -0.02)), Vector3(0.16, 0.21, 0.015), m["gold"], 1.0, 0.004)
			b.box(xf * Transform3D(Basis(Vector3.RIGHT, -0.15), p + Vector3(0, 0.11, -0.011)), Vector3(0.12, 0.16, 0.004), Kit.mat(Color("5a6a7a"), 0.4))
		_:
			b.box(xf * Transform3D(Basis(), p + Vector3(0, 0.05, 0)), Vector3(0.18, 0.1, 0.13), m["caoba"], 1.0, 0.008, 2)
			b.box(xf * Transform3D(Basis(), p + Vector3(0, 0.1, 0)), Vector3(0.16, 0.006, 0.11), m["gold"], 1.0, 0.002)


# ------------------------------------------------------------------ pared del fondo: mapa, consola y banderas

func _back_wall() -> void:
	var z := Z1
	var bxf := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 2.15, z))
	b.frame(bxf, 2.8, 1.68, Kit.FRAME_ORNATE, m["gold"])
	map_mesh = Kit.mesh(root, Kit.quad_mesh(Vector2(2.64, 1.52)), null, Vector3(0, 2.15, z - 0.012), Vector3(0, PI, 0))
	map_mat = ShaderMaterial.new()
	map_mat.shader = load("res://shaders/globe3d.gdshader")
	map_mat.set_shader_parameter("map_tex", load("res://art/maps/world_ids.png"))
	map_mat.set_shader_parameter("flat_map", true)
	map_mesh.material_override = map_mat
	# lámpara de cuadro sobre el mapa
	b.cube(Vector3(0, 3.1, z - 0.1), Vector3(0.9, 0.04, 0.05), m["gold"], Vector3.ZERO, 1.0, 0.012)
	b.cube(Vector3(0, 3.078, z - 0.1), Vector3(0.86, 0.004, 0.04), Kit.emissive(Color(1.0, 0.9, 0.7), 2.5))
	b.segment(Vector3(0, 3.2, z), Vector3(0, 3.12, z - 0.1), 0.008, m["gold"], 8)
	var ml := SpotLight3D.new()
	root.add_child(ml)
	ml.look_at_from_position(Vector3(0, 3.06, z - 0.5), Vector3(0, 1.9, z), Vector3.UP)
	ml.spot_angle = 48.0
	ml.spot_range = 3.2
	ml.light_energy = 1.4
	ml.light_color = Color(1.0, 0.86, 0.62)
	ml.light_volumetric_fog_energy = 0.0
	# consola con patas torneadas
	var cw: Material = m["caoba"]
	b.cube(Vector3(0, 0.825, z - 0.26), Vector3(2.3, 0.045, 0.48), m["marble"], Vector3.ZERO, 1.0, 0.012, 2)
	b.cube(Vector3(0, 0.72, z - 0.26), Vector3(2.16, 0.16, 0.4), cw, Vector3.ZERO, 1.0, 0.01, 2)
	for px in [-0.6, 0.0, 0.6]:
		b.frame(Transform3D(Basis(Vector3.UP, PI), Vector3(px, 0.72, z - 0.462)), 0.5, 0.12, Kit.FRAME_PANEL, m["panel_d"])
	for sx in [-1.0, 1.0]:
		for sz in [-0.1, -0.42]:
			b.lathe(Transform3D(Basis(), Vector3(sx, 0.0, z + sz)), [Vector2(0.03, 0.0), Vector2(0.025, 0.05), Vector2(0.04, 0.09), Vector2(0.02, 0.2), Vector2(0.025, 0.45), Vector2(0.04, 0.55), Vector2(0.03, 0.6), Vector2(0.035, 0.64), Vector2(0.0, 0.64)], cw, 16)
	b.cube(Vector3(0, 0.12, z - 0.26), Vector3(2.0, 0.025, 0.3), cw, Vector3.ZERO, 1.0, 0.008)
	Kit.solid(root, Vector3(0, 0.6, z - 0.26), Vector3(2.3, 0.5, 0.46))
	Kit.solid(root, Vector3(0, 0.825, z - 0.26), Vector3(2.3, 0.05, 0.48))
	Kit.blob(root, Vector3(0, 0, z - 0.3), 2.6, 0.8, 0.5)
	# banderas a ambos lados
	for sx in [-1.95, 1.95]:
		var pz := z - 0.45
		b.lathe(Transform3D(Basis(), Vector3(sx, 0, pz)), [Vector2(0.2, 0.0), Vector2(0.2, 0.03), Vector2(0.16, 0.05), Vector2(0.12, 0.06), Vector2(0.05, 0.1), Vector2(0.035, 0.16), Vector2(0.0, 0.17)], m["gold"], 24)
		b.cyl(Vector3(sx, 1.42, pz), 0.017, 0.019, 2.56, m["panel_d"], Vector3.ZERO, 12)
		b.lathe(Transform3D(Basis(), Vector3(sx, 2.7, pz)), [Vector2(0.02, 0.0), Vector2(0.03, 0.02), Vector2(0.035, 0.05), Vector2(0.015, 0.08), Vector2(0.04, 0.1), Vector2(0.0, 0.24)], m["gold"], 14)
		var cloth := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.62, 1.4)
		qm.subdivide_width = 20
		qm.subdivide_depth = 24
		cloth.mesh = qm
		cloth.position = Vector3(sx + (0.33 if sx < 0 else -0.33), 1.98, pz - 0.02)
		cloth.rotation = Vector3(0, PI, 0)
		# el lado de la driza (donde no ondea) va pegado al mástil: en la de la izquierda se invierte la tela
		cloth.set_meta("flip_u", sx < 0.0)
		root.add_child(cloth)
		flag_cloths.append(cloth)
		b.segment(Vector3(sx, 2.66, pz - 0.02), Vector3(sx + (0.1 if sx < 0 else -0.1), 2.3, pz - 0.05), 0.004, m["gold"], 6)
		b.lathe(Transform3D(Basis(), Vector3(sx + (0.1 if sx < 0 else -0.1), 2.18, pz - 0.05)), [Vector2(0.02, 0.0), Vector2(0.03, 0.06), Vector2(0.015, 0.1), Vector2(0.0, 0.12)], m["gold"], 10)
		Kit.solid(root, Vector3(sx, 1.35, pz), Vector3(0.08, 2.7, 0.08))
		Kit.blob(root, Vector3(sx, 0, pz), 0.55, 0.55, 0.5)


# ------------------------------------------------------------------ sofá Chesterfield, sillones y mesa baja

func _seating() -> void:
	var sx := X1 - 0.44
	var cz := -0.6
	var tf: Material = m["sofa"]
	var pl: Material = m["sofa_plain"]
	b.cube(Vector3(sx, 0.2, cz), Vector3(0.86, 0.22, 2.12), pl, Vector3.ZERO, 1.0, 0.03, 2)
	b.cube(Vector3(sx + 0.33, 0.66, cz), Vector3(0.22, 0.6, 2.06), tf, Vector3.ZERO, 1.0, 0.06, 2)
	b.cyl(Vector3(sx + 0.33, 0.96, cz), 0.11, 0.11, 2.06, pl, Vector3(PI / 2.0, 0, 0), 20)
	for dz in [-1.13, 1.13]:
		b.cube(Vector3(sx, 0.43, cz + dz), Vector3(0.86, 0.46, 0.2), tf, Vector3.ZERO, 1.0, 0.05, 2)
		b.cyl(Vector3(sx, 0.68, cz + dz), 0.125, 0.125, 0.86, pl, Vector3(0, 0, PI / 2.0), 20)
		for k in 14:
			b.sphere(Vector3(sx - 0.43, 0.24 + k * 0.03, cz + dz + (-0.09 if dz < 0 else 0.09)), 0.006, m["gold"], 5, 3)
	for i in 3:
		b.cube(Vector3(sx - 0.05, 0.37, cz - 0.68 + i * 0.68), Vector3(0.74, 0.14, 0.66), pl, Vector3.ZERO, 1.0, 0.05, 3)
	for k2 in 68:
		b.sphere(Vector3(sx - 0.432, 0.15, cz - 1.02 + k2 * 0.0303), 0.006, m["gold"], 5, 3)
	for dz2 in [-1.0, 1.0]:
		for dx in [-0.36, 0.36]:
			b.lathe(Transform3D(Basis(), Vector3(sx + dx, 0.0, cz + dz2)), [Vector2(0.03, 0.0), Vector2(0.045, 0.04), Vector2(0.04, 0.07), Vector2(0.03, 0.09), Vector2(0.0, 0.09)], m["caoba"], 14)
	# el asiento a la altura de los cojines (0,44 m; antes la colisión llegaba a 0,54 y lo que se dejaba encima flotaba)
	var sofa := Kit.solid(root, Vector3(sx, 0.22, cz), Vector3(0.86, 0.44, 2.1))
	Kit.add_shape(sofa, Kit.shape_box(Vector3(0.2, 0.62, 2.1)), Vector3(0.33, 0.46, 0))
	for dz3 in [-1.13, 1.13]:
		Kit.add_shape(sofa, Kit.shape_box(Vector3(0.86, 0.6, 0.2)), Vector3(0, 0.18, dz3))
	Kit.blob(root, Vector3(sx, 0, cz), 1.1, 2.5, 0.6)
	# el sofá: se sienta en el cojín central mirando a la sala; al levantarse sale junto a la mesa baja
	seats.append({"pos": Vector3(sx - 0.02, 0, cz), "yaw": PI / 2.0, "eye": 1.06, "stand": Vector3(2.75, 0, cz), "body": sofa,
		"title": "Sofá Chesterfield · clic para sentarse", "key": "sofa"})
	# cuadro sobre el sofá
	b.frame(Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(X1, 1.85, cz)), 1.66, 1.1, Kit.FRAME_ORNATE, m["gold"])
	Kit.mesh(root, Kit.quad_mesh(Vector2(1.49, 0.93)), Kit.tex_mat(_landscape_tex(), 0.85), Vector3(X1 - 0.012, 1.85, cz), Vector3(0, -PI / 2.0, 0))
	b.cube(Vector3(X1 - 0.1, 2.48, cz), Vector3(0.05, 0.04, 0.5), m["gold"], Vector3.ZERO, 1.0, 0.012)
	b.cube(Vector3(X1 - 0.1, 2.458, cz), Vector3(0.04, 0.004, 0.46), Kit.emissive(Color(1.0, 0.9, 0.7), 2.5))
	# mesa baja con patas torneadas
	var tx := 3.5
	b.cube(Vector3(tx, 0.445, cz), Vector3(0.72, 0.035, 1.22), m["desk"], Vector3.ZERO, 1.0, 0.012, 2)
	b.cube(Vector3(tx, 0.41, cz), Vector3(0.66, 0.06, 1.14), m["panel_d"], Vector3.ZERO, 1.0, 0.01)
	for dx2 in [-0.28, 0.28]:
		for dz4 in [-0.5, 0.5]:
			b.lathe(Transform3D(Basis(), Vector3(tx + dx2, 0, cz + dz4)), [Vector2(0.018, 0.0), Vector2(0.025, 0.03), Vector2(0.018, 0.06), Vector2(0.022, 0.22), Vector2(0.032, 0.3), Vector2(0.024, 0.36), Vector2(0.03, 0.38), Vector2(0.0, 0.38)], m["caoba"], 14)
	Kit.solid(root, Vector3(tx, 0.42, cz), Vector3(0.72, 0.08, 1.22))
	Kit.blob(root, Vector3(tx, 0, cz), 0.95, 1.5, 0.45)
	_armchair(Vector3(tx, 0, cz - 1.45), 0.0)
	_armchair(Vector3(tx, 0, cz + 1.45), PI)


## Espejo de pared, en el hueco libre de la pared izquierda entre la librería y el rincón:
## marco dorado y una pequeña repisa de mármol. La superficie la pinta office_3d.gd con la
## cámara que refleja la vista del jugador respecto al plano del cristal.
func _mirror() -> void:
	var x := X0
	var cz := 2.6
	var cy := 1.55
	var fw := 0.84
	var fh := 1.5
	b.frame(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(x, cy, cz)), fw, fh, Kit.FRAME_ORNATE, m["gold"])
	b.cube(Vector3(x + 0.05, cy - fh / 2.0 - 0.025, cz), Vector3(0.16, 0.05, fw + 0.14), m["marble"], Vector3.ZERO, 1.0, 0.012, 2)
	mirror_body = StaticBody3D.new()
	mirror_body.position = Vector3(x + 0.05, cy, cz)
	root.add_child(mirror_body)
	Kit.add_shape(mirror_body, Kit.shape_box(Vector3(0.1, fh, fw)))
	# el cristal cuelga del mismo cuerpo que la insignia/resalte usa para la mira (antes era un
	# hijo suelto de root y el espejo nunca se resaltaba al mirarlo)
	mirror_quad = Kit.mesh(mirror_body, Kit.quad_mesh(Vector2(fw - 0.1, fh - 0.1)), m["glass"], Vector3(-0.038, 0, 0), Vector3(0, PI / 2.0, 0))
	mirror_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mirror_point = Vector3(x + 0.012, cy, cz)
	mirror_normal = Vector3.RIGHT


## Paisaje al óleo para los cuadros
static func _landscape_tex() -> Texture2D:
	if Kit._tex_cache.has("landscape"):
		return Kit._tex_cache["landscape"]
	var W := 480
	var Hh := 300
	var img := Image.create(W, Hh, false, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new()
	n.seed = 23
	n.frequency = 0.008
	var n2 := FastNoiseLite.new()
	n2.seed = 29
	n2.frequency = 0.06
	var sky_t := Color("e7c58f")
	var sky_b := Color("9cb7c0")
	for y in Hh:
		for x in W:
			var v := float(y) / Hh
			var c := sky_b.lerp(sky_t, clampf(1.0 - v * 1.6, 0.0, 1.0))
			var sun := Vector2(x - 345, y - 92).length()
			if sun < 22.0:
				c = Color("fff1c8")
			elif sun < 60.0:
				c = c.lerp(Color("ffe8b0"), (60.0 - sun) / 90.0)
			var cl := n.get_noise_2d(x * 2.0, y * 6.0)
			if v < 0.4 and cl > 0.25:
				c = c.lerp(Color("f6ead2"), (cl - 0.25) * 1.2)
			var h1 := 165.0 + n.get_noise_1d(x * 0.8) * 45.0
			var h2 := 200.0 + n.get_noise_1d(x * 1.6 + 300.0) * 32.0
			var h3 := 248.0 + n.get_noise_1d(x * 2.4 + 700.0) * 15.0
			if y > h1:
				c = Color("6d7f86").lerp(Color("4f6264"), (y - h1) / 90.0)
			if y > h2:
				c = Color("5f7445").lerp(Color("3d4f2c"), (y - h2) / 75.0)
			if y > h3:
				c = Color("4a5a2e").lerp(Color("2e3a1c"), (y - h3) / 52.0)
			c = c.lerp(c.darkened(0.3), clampf(n2.get_noise_2d(x, y) * 0.5, 0.0, 0.4))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	Kit._tex_cache["landscape"] = t
	return t


func _armchair(pos: Vector3, yaw: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	var tf: Material = m["chair"]
	var pl: Material = m["chair_plain"]
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(0.74, 0.3, 0.72), pl, 1.0, 0.03, 2)
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.45, 0.04)), Vector3(0.56, 0.12, 0.62), pl, 1.0, 0.05, 3)
	b.box(xf * Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 0.8, -0.3)), Vector3(0.74, 0.74, 0.16), tf, 1.0, 0.05, 2)
	for sx in [-0.32, 0.32]:
		b.box(xf * Transform3D(Basis(), Vector3(sx, 0.47, 0.0)), Vector3(0.12, 0.32, 0.7), pl, 1.0, 0.04, 2)
		b.cylinder(xf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(sx, 0.64, 0.02)), 0.075, 0.075, 0.7, pl, 18)
		b.box(xf * Transform3D(Basis(Vector3.UP, -0.25 * signf(sx)), Vector3(sx * 1.05, 0.88, -0.22)), Vector3(0.1, 0.5, 0.22), tf, 1.0, 0.04, 2)
	for c in [Vector3(-0.3, 0.0, -0.28), Vector3(0.3, 0.0, -0.28), Vector3(-0.3, 0.0, 0.28), Vector3(0.3, 0.0, 0.28)]:
		b.lathe(xf * Transform3D(Basis(), c), [Vector2(0.022, 0.0), Vector2(0.03, 0.03), Vector2(0.02, 0.07), Vector2(0.026, 0.1), Vector2(0.0, 0.1)], m["caoba"], 12)
	var body := StaticBody3D.new()
	body.transform = xf
	# asiento a la altura del cojín (0,51 m) y brazos aparte (antes una caja de 0,6 m: lo dejado encima flotaba)
	Kit.add_shape(body, Kit.shape_box(Vector3(0.74, 0.51, 0.72)), Vector3(0, 0.255, 0))
	for sx2 in [-0.32, 0.32]:
		Kit.add_shape(body, Kit.shape_box(Vector3(0.12, 0.7, 0.7)), Vector3(sx2, 0.35, 0.0))
	Kit.add_shape(body, Kit.shape_box(Vector3(0.74, 0.74, 0.16)), Vector3(0, 0.8, -0.3))
	root.add_child(body)
	Kit.blob(root, pos, 0.95, 0.95, 0.55, yaw)
	# se puede sentar en él (mirando hacia delante del sillón); al levantarse sale hacia el centro de la sala
	seats.append({"pos": xf * Vector3(0, 0, 0.06), "yaw": wrapf(yaw + PI, -PI, PI), "eye": 1.12, "stand": pos + Vector3(-0.75, 0, 0), "body": body,
		"title": "Sillón · clic para sentarse", "key": "armchair_%d" % seats.size()})


# ------------------------------------------------------------------ escritorio y sillón

func _desk() -> void:
	var z := DESK_Z
	var wood: Material = m["desk"]
	var gold: Material = m["gold"]
	b.cube(Vector3(0, DESK_TOP - 0.022, z), Vector3(2.6, 0.044, 1.2), wood, Vector3.ZERO, 1.0, 0.014, 2)
	b.cube(Vector3(0, DESK_TOP - 0.058, z), Vector3(2.54, 0.035, 1.14), m["panel_d"], Vector3.ZERO, 1.0, 0.01, 2)
	b.cube(Vector3(0, DESK_TOP + 0.0015, z), Vector3(2.1, 0.003, 0.84), m["leather"])
	for inset in [0.0, 0.025]:
		var w: float = 2.08 - inset * 2.0
		var d: float = 0.82 - inset * 2.0
		for e in [[Vector3(0, DESK_TOP + 0.0035, z - d / 2.0), Vector3(w, 0.001, 0.005)], [Vector3(0, DESK_TOP + 0.0035, z + d / 2.0), Vector3(w, 0.001, 0.005)],
				[Vector3(-w / 2.0, DESK_TOP + 0.0035, z), Vector3(0.005, 0.001, d)], [Vector3(w / 2.0, DESK_TOP + 0.0035, z), Vector3(0.005, 0.001, d)]]:
			b.cube(e[0], e[1], gold)
	for sx in [-0.95, 0.95]:
		b.cube(Vector3(sx, 0.38, z), Vector3(0.62, 0.66, 1.1), wood, Vector3.ZERO, 1.0, 0.012, 2)
		b.cube(Vector3(sx, 0.045, z), Vector3(0.67, 0.09, 1.15), m["panel_d"], Vector3.ZERO, 1.0, 0.012, 2)
		b.cube(Vector3(sx, 0.69, z), Vector3(0.64, 0.025, 1.12), m["panel_d"], Vector3.ZERO, 1.0, 0.008)
		for i in 3:
			var dy := 0.58 - i * 0.205
			var dxf := Transform3D(Basis(), Vector3(sx, dy, z + 0.55))
			b.frame(dxf, 0.54, 0.19, Kit.FRAME_PANEL, m["panel_d"])
			b.box(dxf * Transform3D(Basis(), Vector3(0, 0, 0.006)), Vector3(0.46, 0.13, 0.014), wood, 1.0, 0.01, 2)
			b.box(dxf * Transform3D(Basis(), Vector3(0, 0, 0.016)), Vector3(0.13, 0.03, 0.005), gold, 1.0, 0.003)
			for px in [-0.045, 0.045]:
				b.sphere(dxf * Vector3(px, 0.0, 0.026), 0.007, gold, 8, 5)
			b.segment(dxf * Vector3(-0.045, -0.002, 0.026), dxf * Vector3(-0.03, -0.03, 0.032), 0.003, gold, 6)
			b.segment(dxf * Vector3(-0.03, -0.03, 0.032), dxf * Vector3(0.03, -0.03, 0.032), 0.003, gold, 6)
			b.segment(dxf * Vector3(0.03, -0.03, 0.032), dxf * Vector3(0.045, -0.002, 0.026), 0.003, gold, 6)
		var vxf := Transform3D(Basis(Vector3.UP, PI), Vector3(sx, 0.38, z - 0.551))
		b.frame(vxf, 0.5, 0.52, Kit.FRAME_PANEL, m["panel_d"])
		b.box(vxf * Transform3D(Basis(), Vector3(0, 0, 0.006)), Vector3(0.42, 0.44, 0.014), wood, 1.0, 0.012, 2)
	b.cube(Vector3(0, 0.43, z - 0.53), Vector3(1.3, 0.6, 0.04), wood, Vector3.ZERO, 1.0, 0.008)
	var mxf := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.43, z - 0.551))
	b.frame(mxf, 1.14, 0.48, Kit.FRAME_PANEL, m["panel_d"])
	var seal := Sprite3D.new()
	seal.texture = OfficeArt.tex("seal", 1.2)
	seal.pixel_size = 0.0016
	seal.position = Vector3(0, 0.45, z - 0.565)
	seal.rotation = Vector3(0, PI, 0)
	seal.shaded = true
	seal.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	root.add_child(seal)
	var body := StaticBody3D.new()
	root.add_child(body)
	Kit.add_shape(body, Kit.shape_box(Vector3(2.6, 0.05, 1.2)), Vector3(0, DESK_TOP - 0.025, z))
	for sx2 in [-0.95, 0.95]:
		Kit.add_shape(body, Kit.shape_box(Vector3(0.62, 0.72, 1.1)), Vector3(sx2, 0.36, z))
	Kit.add_shape(body, Kit.shape_box(Vector3(1.3, 0.6, 0.04)), Vector3(0, 0.43, z - 0.53))
	bodies["desk"] = body
	Kit.blob(root, Vector3(0, 0, z), 3.1, 1.7, 0.6)


## Sillón presidencial giratorio de cuero capitoné (el cuerpo entero gira con el presidente)
func _chair() -> void:
	chair_body = StaticBody3D.new()
	chair_body.position = SEAT
	root.add_child(chair_body)
	var cb := Batch.new()
	var tf: Material = m["chair"]
	var pl: Material = m["chair_plain"]
	cb.cube(Vector3(0, 0.5, 0.02), Vector3(0.6, 0.13, 0.56), pl, Vector3.ZERO, 1.0, 0.05, 3)
	cb.cube(Vector3(0, 1.08, 0.36), Vector3(0.62, 0.95, 0.14), tf, Vector3(0.1, 0, 0), 1.0, 0.05, 2)
	cb.cylinder(Transform3D(Basis(Vector3.BACK, PI / 2.0) * Basis(), Vector3(0, 1.57, 0.41)), 0.075, 0.075, 0.64, pl, 20)
	for sx in [-0.35, 0.35]:
		cb.cube(Vector3(sx, 0.72, 0.06), Vector3(0.09, 0.07, 0.5), pl, Vector3.ZERO, 1.0, 0.03, 2)
		cb.segment(Vector3(sx, 0.56, 0.18), Vector3(sx, 0.69, 0.16), 0.014, m["gold"], 10)
		cb.segment(Vector3(sx, 0.56, -0.08), Vector3(sx, 0.69, -0.1), 0.014, m["gold"], 10)
		for k in 16:
			cb.sphere(Vector3(sx * 0.885, 0.66 + k * 0.058, 0.44 + k * 0.0058), 0.005, m["gold"], 5, 3)
	cb.lathe(Transform3D(Basis(), Vector3(0, 0.08, 0.02)), [Vector2(0.06, 0.0), Vector2(0.045, 0.03), Vector2(0.03, 0.05), Vector2(0.03, 0.3), Vector2(0.05, 0.33), Vector2(0.12, 0.36), Vector2(0.0, 0.37)], Kit.chrome(), 20)
	for i in 5:
		var a := TAU * i / 5.0
		var tip := Vector3(cos(a) * 0.33, 0.07, 0.02 + sin(a) * 0.33)
		cb.segment(Vector3(0, 0.1, 0.02), tip, 0.022, Kit.chrome(), 10, true, 0.016)
		cb.sphere(tip + Vector3(0, -0.035, 0), 0.03, m["black"], 10, 6)
	cb.commit(chair_body)
	Kit.add_shape(chair_body, Kit.shape_box(Vector3(0.72, 0.62, 0.62)), Vector3(0, 0.31 + 0.12, 0.02))
	Kit.add_shape(chair_body, Kit.shape_box(Vector3(0.64, 1.1, 0.16)), Vector3(0, 1.1, 0.38))
	Kit.blob(chair_body, Vector3.ZERO, 0.9, 0.9, 0.5)


## Papelera de latón con colisión hueca: se puede encestar papel
func _wastebasket() -> void:
	var pos := Vector3(0.78, 0, 0.05)
	var wm := Kit.leather(Color("3a2416"))
	wm = wm.duplicate()
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wb := Batch.new()
	wb.cylinder(Transform3D(Basis(), Vector3(0, 0.17, 0)), 0.17, 0.13, 0.34, wm, 24, false)
	wb.cyl(Vector3(0, 0.005, 0), 0.13, 0.13, 0.01, wm, Vector3.ZERO, 24)
	var body := StaticBody3D.new()
	body.position = pos
	root.add_child(body)
	wb.commit(body)
	Kit.mesh(body, Kit.torus_mesh(0.162, 0.18, 32), m["gold"], Vector3(0, 0.34, 0))
	Kit.mesh(body, Kit.torus_mesh(0.123, 0.137, 32), m["gold"], Vector3(0, 0.01, 0))
	Kit.add_shape(body, Kit.shape_box(Vector3(0.3, 0.02, 0.3)), Vector3(0, 0.01, 0))
	for i in 8:
		var a := TAU * i / 8.0
		Kit.add_shape(body, Kit.shape_box(Vector3(0.13, 0.34, 0.02)), Vector3(cos(a) * 0.15, 0.17, sin(a) * 0.15), Vector3(0, -a + PI / 2.0, 0))
	Kit.blob(root, pos, 0.45, 0.45, 0.5)


## Planta en maceta vidriada con hojas texturizadas
func _plant(pos: Vector3) -> void:
	b.lathe(Transform3D(Basis(), pos), [Vector2(0.15, 0.0), Vector2(0.17, 0.03), Vector2(0.2, 0.15), Vector2(0.23, 0.36), Vector2(0.24, 0.42), Vector2(0.25, 0.45), Vector2(0.22, 0.46), Vector2(0.0, 0.46)], m["pot"], 28)
	b.cyl(pos + Vector3(0, 0.39, 0), 0.236, 0.236, 0.03, m["gold"], Vector3.ZERO, 28)
	b.cyl(pos + Vector3(0, 0.455, 0), 0.215, 0.215, 0.01, Kit.mat(Color("2a1a10"), 1.0), Vector3.ZERO, 20)
	var leaf_m := StandardMaterial3D.new()
	leaf_m.albedo_texture = Tex.get_set("leaf")["albedo"]
	leaf_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	leaf_m.alpha_scissor_threshold = 0.5
	leaf_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaf_m.albedo_color = Color(0.68, 0.76, 0.66)
	leaf_m.roughness = 0.6
	leaf_m.rim_enabled = true
	leaf_m.rim = 0.12
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 100 + pos.z * 7)
	var lm := _leaf_mesh()
	for i in 22:
		var a := TAU * i / 22.0 + rng.randf() * 0.3
		var tilt := rng.randf_range(0.15, 1.0)
		var ln := rng.randf_range(0.45, 0.85)
		var mi := MeshInstance3D.new()
		mi.mesh = lm
		mi.material_override = leaf_m
		mi.basis = Basis(Vector3.UP, -a) * Basis(Vector3.BACK, tilt) * Basis.from_scale(Vector3(ln * 0.55, ln, ln))
		mi.position = pos + Vector3(0, 0.45, 0)
		root.add_child(mi)
	Kit.solid(root, pos + Vector3(0, 0.5, 0), Vector3(0.44, 1.0, 0.44))
	Kit.blob(root, pos, 0.7, 0.7, 0.55)


## Hoja curvada (sale del origen hacia +Y y se arquea hacia +X)
static func _leaf_mesh() -> ArrayMesh:
	if Kit._tex_cache.has("leaf_mesh"):
		return Kit._tex_cache["leaf_mesh"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 8
	var spine := []
	for j in segs + 1:
		var t := float(j) / segs
		spine.append(Vector3(t * t * 0.55, t * (1.0 - t * 0.25), 0))
	# dos mitades (izquierda y derecha) plegadas en V a lo largo del nervio central
	for half in [-1.0, 1.0]:
		for j in segs:
			var p0: Vector3 = spine[j]
			var p1: Vector3 = spine[j + 1]
			var t0 := float(j) / segs
			var t1 := float(j + 1) / segs
			var dir := (p1 - p0).normalized()
			var n := dir.cross(Vector3.BACK).normalized()
			var e0 := p0 + Vector3(0, 0, 0.5 * half) - n * 0.07
			var e1 := p1 + Vector3(0, 0, 0.5 * half) - n * 0.07
			var u_edge: float = 0.5 + 0.5 * half
			for v in [[p1, Vector2(0.5, 1.0 - t1)], [e1, Vector2(u_edge, 1.0 - t1)], [e0, Vector2(u_edge, 1.0 - t0)], [p1, Vector2(0.5, 1.0 - t1)], [e0, Vector2(u_edge, 1.0 - t0)], [p0, Vector2(0.5, 1.0 - t0)]]:
				st.set_normal(n)
				st.set_uv(v[1])
				st.add_vertex(v[0])
	var mesh := st.commit()
	Kit._tex_cache["leaf_mesh"] = mesh
	return mesh


func _bust(pos: Vector3) -> void:
	b.lathe(Transform3D(Basis(), pos), [Vector2(0.25, 0.0), Vector2(0.25, 0.06), Vector2(0.2, 0.09), Vector2(0.16, 0.14), Vector2(0.15, 0.95), Vector2(0.19, 1.0), Vector2(0.24, 1.06), Vector2(0.24, 1.12), Vector2(0.0, 1.12)], m["marble"], 32)
	b.cube(pos + Vector3(0, 1.26, 0), Vector3(0.36, 0.2, 0.2), m["bronze"], Vector3.ZERO, 1.0, 0.06, 3)
	b.cyl(pos + Vector3(0, 1.39, 0), 0.05, 0.06, 0.1, m["bronze"], Vector3.ZERO, 16)
	b.sphere(pos + Vector3(0, 1.5, 0), 0.1, m["bronze"], 24, 16, Vector3(0.9, 1.1, 1.0))
	Kit.solid(root, pos + Vector3(0, 0.75, 0), Vector3(0.44, 1.5, 0.44))
	Kit.blob(root, pos, 0.75, 0.75, 0.55)


# ------------------------------------------------------------------ luces

## Lámpara de araña de latón con brazos en S, velas, cristales tallados y guirnaldas de cuentas
func _chandelier() -> void:
	var c := Vector3(0, H, DESK_Z)
	var gold: Material = m["gold"]
	var cry := Kit.crystal()
	var cb := Batch.new()
	cb.lathe(Transform3D(Basis(Vector3.RIGHT, PI), c + Vector3(0, -0.12, 0)), [Vector2(0.1, 0.0), Vector2(0.12, 0.01), Vector2(0.06, 0.05), Vector2(0.0, 0.06)], gold, 20)
	for k in 10:
		cb.sphere(c + Vector3(0, -0.2 - k * 0.04, 0), 0.012, gold, 8, 5)
	cb.lathe(Transform3D(Basis(), c + Vector3(0, -0.95, 0)), [Vector2(0.0, 0.0), Vector2(0.03, 0.02), Vector2(0.07, 0.06), Vector2(0.1, 0.12), Vector2(0.09, 0.16), Vector2(0.04, 0.2), Vector2(0.05, 0.24), Vector2(0.035, 0.3), Vector2(0.02, 0.38), Vector2(0.03, 0.42), Vector2(0.0, 0.43)], gold, 24)
	var tips := []
	for i in 8:
		var a := TAU * i / 8.0
		var dirv := Vector3(cos(a), 0, sin(a))
		var prev := c + Vector3(0, -0.84, 0) + dirv * 0.08
		for s in range(1, 9):
			var t := float(s) / 8.0
			var r := 0.08 + 0.42 * t
			var y := -0.84 - 0.1 * sin(t * PI) + 0.05 * sin(t * TAU)
			var p := c + Vector3(0, y, 0) + dirv * r
			cb.segment(prev, p, 0.011, gold, 8)
			prev = p
		tips.append(prev)
		cb.lathe(Transform3D(Basis(), prev), [Vector2(0.02, 0.0), Vector2(0.05, 0.015), Vector2(0.06, 0.02), Vector2(0.03, 0.03), Vector2(0.0, 0.03)], gold, 16)
		cb.cyl(prev + Vector3(0, 0.08, 0), 0.016, 0.016, 0.1, m["candle"], Vector3.ZERO, 12)
		for dpos in [-1.0, 0.0, 1.0]:
			var side: Vector3 = dirv.cross(Vector3.UP) * dpos * 0.035
			cb.sphere(prev + side + Vector3(0, -0.06, 0) + dirv * 0.04, 0.012, cry, 4, 2, Vector3(1, 2.4, 1))
	for i2 in 8:
		var a0: Vector3 = tips[i2]
		var a1: Vector3 = tips[(i2 + 1) % 8]
		for k2 in range(1, 10):
			var t2 := float(k2) / 10.0
			var p2 := a0.lerp(a1, t2) + Vector3(0, -0.13 * sin(t2 * PI), 0)
			cb.sphere(p2, 0.008, cry, 6, 3)
	for k3 in 16:
		var a3 := TAU * k3 / 16.0
		cb.sphere(c + Vector3(cos(a3) * 0.13, -0.98, sin(a3) * 0.13), 0.012, cry, 4, 2, Vector3(1, 2.6, 1))
	cb.sphere(c + Vector3(0, -1.03, 0), 0.03, cry, 10, 6)
	cb.commit(root, false)
	var flame := Kit.emissive(Color(1.0, 0.82, 0.5), 5.0)
	for tip in tips:
		Kit.mesh(root, Kit.sphere_mesh(0.016, 8), flame, (tip as Vector3) + Vector3(0, 0.15, 0), Vector3.ZERO, Vector3(1, 1.8, 1)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chandelier_light = OmniLight3D.new()
	chandelier_light.position = c + Vector3(0, -0.72, 0)
	chandelier_light.omni_range = 11.0
	chandelier_light.omni_attenuation = 0.8
	chandelier_light.light_energy = 1.5
	chandelier_light.light_color = Color(1.0, 0.86, 0.66)
	# fuente pequeña (las velas): con 0,5 m su reflejo en la puerta era un gran disco blanco
	chandelier_light.light_size = 0.08
	root.add_child(chandelier_light)
	alert_light = OmniLight3D.new()
	alert_light.position = c + Vector3(0, -0.4, 0.5)
	alert_light.omni_range = 12.0
	alert_light.light_energy = 0.0
	alert_light.light_color = Color(1.0, 0.12, 0.08)
	root.add_child(alert_light)


## Apliques de pared de dos brazos con pantallas
func _sconces() -> void:
	var shade := Kit.emissive(Color(1.0, 0.9, 0.72), 1.8)
	var gold: Material = m["gold"]
	for sx in [-1.45, 1.45]:
		var p := Vector3(sx, 2.2, Z0)
		b.lathe(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), p), [Vector2(0.06, 0.0), Vector2(0.065, 0.01), Vector2(0.04, 0.025), Vector2(0.0, 0.03)], gold, 20)
		for s in [-1.0, 1.0]:
			var prev := p + Vector3(0, -0.04, 0.03)
			for k in range(1, 7):
				var t := float(k) / 6.0
				var q := p + Vector3(s * 0.16 * t, -0.04 + 0.12 * t * t - 0.05 * sin(t * PI), 0.03 + 0.1 * t)
				b.segment(prev, q, 0.008, gold, 8)
				prev = q
			b.lathe(Transform3D(Basis(), prev), [Vector2(0.015, 0.0), Vector2(0.035, 0.012), Vector2(0.0, 0.016)], gold, 12)
			b.cyl(prev + Vector3(0, 0.05, 0), 0.012, 0.012, 0.07, m["candle"], Vector3.ZERO, 10)
			b.cyl(prev + Vector3(0, 0.1, 0), 0.045, 0.07, 0.1, shade, Vector3.ZERO, 18)
		var l := OmniLight3D.new()
		l.position = p + Vector3(0, 0.12, 0.3)
		l.omni_range = 3.2
		l.light_energy = 0.6
		l.light_color = Color(1.0, 0.82, 0.58)
		root.add_child(l)
		sconce_lights.append(l)


## Haz de luz falso desde la ventana hasta la mancha de sol del suelo, con motas de polvo
func _light_shaft() -> void:
	var corners := [Vector3(WINDOW.position.x, WINDOW.position.y, Z0), Vector3(WINDOW.end.x, WINDOW.position.y, Z0), Vector3(WINDOW.end.x, WINDOW.end.y, Z0), Vector3(WINDOW.position.x, WINDOW.end.y, Z0)]
	var floor_pts := []
	var sd := SUN_DIR.normalized()
	for c in corners:
		# hasta el suelo o, si el rayo es muy rasante, hasta 7 m dentro de la sala
		var cc: Vector3 = c
		var t := minf(-cc.y / sd.y, 7.0) if sd.y < -0.001 else 7.0
		var p: Vector3 = cc + sd * t
		p.y = maxf(p.y, 0.02)
		floor_pts.append(p)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a0: Vector3 = corners[i]
		var a1: Vector3 = corners[(i + 1) % 4]
		var f0: Vector3 = floor_pts[i]
		var f1: Vector3 = floor_pts[(i + 1) % 4]
		var n := (a1 - a0).cross(f0 - a0).normalized()
		for v in [[a0, Vector2(0, 0)], [a1, Vector2(1, 0)], [f1, Vector2(1, 1)], [a0, Vector2(0, 0)], [f1, Vector2(1, 1)], [f0, Vector2(0, 1)]]:
			st.set_normal(n)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	beam = MeshInstance3D.new()
	beam.mesh = st.commit()
	beam_mat = ShaderMaterial.new()
	beam_mat.shader = load("res://shaders/beam3d.gdshader")
	beam.material_override = beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	var ctr := Vector3.ZERO
	for p2 in floor_pts:
		ctr += p2
	ctr /= 4.0
	var mid := (Vector3(WINDOW.get_center().x, WINDOW.get_center().y, Z0) + ctr) * 0.5
	dust = CPUParticles3D.new()
	dust.position = mid
	dust.amount = 70
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(0.9, 0.9, 1.6)
	dust.direction = Vector3(0.2, 0.3, 0.1)
	dust.spread = 180.0
	dust.initial_velocity_min = 0.01
	dust.initial_velocity_max = 0.04
	dust.gravity = Vector3(0, -0.003, 0)
	var dq := QuadMesh.new()
	dq.size = Vector2(0.006, 0.006)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.albedo_texture = Kit.disc_tex()
	dm.albedo_color = Color(1.0, 0.92, 0.75, 0.55)
	dq.material = dm
	dust.mesh = dq
	root.add_child(dust)


## Sombras de contacto de lo que no se ha sombreado al construirlo
func _contact_shadows() -> void:
	Kit.blob(root, Vector3(2.2, 0, Z0 + 0.25), 0.9, 0.6, 0.55)
	Kit.blob(root, Vector3(3.75, 0, Z0 + 0.3), 2.2, 0.75, 0.55)
	Kit.blob(root, Vector3(X0 + 0.45, 0, -1.2), 1.0, 2.7, 0.45)
	Kit.blob(root, Vector3(1.85, 0, -0.95), 0.8, 0.8, 0.55)
