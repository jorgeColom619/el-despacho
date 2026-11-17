extends "res://scripts/stages3d/stage_3d.gd"
## Sala de crisis del Palacio: un búnker con una mesa táctica en el centro (el mapa de la emergencia proyectado en
## el tablero), el Gobierno de pie alrededor (el ministro que dirige esta crisis, la Vicepresidencia, la Jefatura de
## Gabinete...), un videowall con el mismo mapa, pantallas de noticias y datos y la alerta roja latiendo. El presidente
## (la cámara) está en el lado de la mesa que da al videowall.
## La operación se juega en la mesa: las unidades son fichas apiladas en la bandeja de la derecha que se arrastran a
## las regiones del mapa; las desplegadas se pueden llevar a otra región o sacar del mapa para retirarlas, y las tres
## medidas extraordinarias son objetos del borde de la mesa (el pulsador del estado de alarma, la banderita de la
## Unión y el micrófono). La lógica de la operación es la del panel (crisis_overlay.gd): la sala solo avisa con
## on_drop_unit, on_drop_token, on_hover_px y on_special, y el panel le pasa las fichas con sync_tokens().

const MapView := preload("res://scripts/ui/map_view.gd")
const W := preload("res://scripts/data/world_data.gd")

const H := 3.8
const X0 := -6.0
const X1 := 6.0
const Z0 := -5.0
const Z1 := 5.5
const TABLE_H := 0.9
const TABLE_SIZE := Vector2(4.0, 2.7)
## Donde está el presidente (la cámara del briefing)
const HEAD := Vector3(0, 0, 2.0)
## Mapa de la mesa: centro, ancho y píxeles (el alto sale de las proporciones del mapa)
const MAP_C := Vector3(-0.4, TABLE_H + 0.006, -0.05)
const MAP_W := 2.8
const MAP_PX := Vector2(1000, 760)
## Bandeja de las unidades: columna de las pilas y filas
const TRAY_X := 1.27
const TRAY_Z := [-0.8, -0.38, 0.04, 0.46, 0.88]
## Medidas extraordinarias en el borde de la mesa, debajo del mapa
const SPECIAL_X := {"emergencia": -1.45, "ayuda": -0.45, "comparecer": 0.55}
const SPECIAL_Z := 1.13
const PILE_MAX := 6

## Datos de la crisis (los pone el panel antes de añadir la sala)
var crisis_title := ""
var crisis_icon := "alerta"
var resp_key := "interior"
## Mapa del videowall (el panel le pinta las mismas regiones que en el suyo)
var wall_map: Control
## Pantalla del tablero: el panel pone ahí su mapa y la capa con los nombres y las intensidades
var table_ui: Control
var table_map: Control
## Avisos al panel: (unidad, píxel del mapa), (ficha, píxel del mapa), (píxel bajo la ficha arrastrada o (-1, -1)), (medida)
var on_drop_unit := Callable()
var on_drop_token := Callable()
var on_hover_px := Callable()
var on_special := Callable()
## La operación está en marcha: se pueden coger fichas y pulsar las medidas
var ops_on := false
var ministers: Array = []
var _resp: Node3D
var _alarm: OmniLight3D
var _alarm_mat: StandardMaterial3D
var _news: Control
var _data: Control
var _alarm_on := true
var _m := {}
var _rng := RandomNumberGenerator.new()
var _piles: Array = []
var _pucks := {}
var _ghost: Node3D
var _drag_tid := -1
var _specials := {}
var _icon_mats := {}


func build() -> void:
	_rng.seed = 17
	_m = {
		"floor": Kit.mat(Color("15181d"), 0.55, 0.1),
		"wall": Kit.mat(Color("1c222b"), 0.85),
		"panel": Kit.mat(Color("232b36"), 0.7, 0.05),
		"ceiling": Kit.mat(Color("0f1216"), 0.9),
		"table": Kit.mat(Color("1a1f27"), 0.45, 0.2),
		"edge": Kit.emissive(Color(0.25, 0.55, 1.0), 1.6),
		"frame": Kit.emissive(Color(0.35, 0.75, 1.0), 1.2),
		"felt": Kit.mat(Color("0f161e"), 0.95),
		"chrome": Kit.chrome(),
		"black": Kit.mat(Color("0b0c0e"), 0.5, 0.2),
		"lamp": Kit.emissive(Color(0.75, 0.85, 1.0), 0.35),
		"paper": Kit.mat(Color("f2efe6"), 0.9),
		"puck": Kit.mat(Color("0d1b2a"), 0.35, 0.3),
		"rim": Kit.mat(UI.GOLD, 0.3, 0.9),
		"slot": Kit.emissive(Color(0.3, 0.6, 1.0), 0.5),
	}
	eye = HEAD + Vector3(0, 1.75, 0.35)
	shade_top = 0.15
	shade_bottom = 0.25
	_room()
	_table()
	_videowall()
	_side_screens()
	_people()
	_lights()
	b.commit(world)
	# desde el lado de la mesa del presidente, mirando al videowall por encima del Gobierno
	cam_pos = eye
	cam_look = Vector3(0, 2.15, Z0)
	fov_target = 58.0
	cam_speed = 1.4
	sway = 0.02


func _room() -> void:
	b.cube(Vector3(0, -0.05, (Z0 + Z1) * 0.5), Vector3(X1 - X0, 0.1, Z1 - Z0), _m["floor"])
	b.cube(Vector3(0, H + 0.05, (Z0 + Z1) * 0.5), Vector3(X1 - X0, 0.1, Z1 - Z0), _m["ceiling"])
	b.cube(Vector3(0, H * 0.5, Z0 - 0.05), Vector3(X1 - X0, H, 0.1), _m["wall"])
	b.cube(Vector3(0, H * 0.5, Z1 + 0.05), Vector3(X1 - X0, H, 0.1), _m["wall"])
	for sx in [-1.0, 1.0]:
		b.cube(Vector3(sx * (X1 + 0.05), H * 0.5, (Z0 + Z1) * 0.5), Vector3(0.1, H, Z1 - Z0), _m["wall"])
		# paneles acústicos y una tira roja de alerta a lo largo de la pared
		for k in 7:
			var z := Z0 + 1.0 + k * 1.4
			b.cube(Vector3(sx * (X1 - 0.03), 1.9, z), Vector3(0.06, 2.4, 1.25), _m["panel"], Vector3.ZERO, 1.0, 0.02)
	_alarm_mat = Kit.emissive(Color(1.0, 0.08, 0.05), 2.5).duplicate() as StandardMaterial3D
	for sx in [-1.0, 1.0]:
		b.cube(Vector3(sx * (X1 - 0.08), 3.3, (Z0 + Z1) * 0.5), Vector3(0.04, 0.06, Z1 - Z0 - 0.4), _alarm_mat)
	b.cube(Vector3(0, 3.66, Z0 + 0.08), Vector3(X1 - X0 - 0.4, 0.06, 0.04), _alarm_mat)
	# tiras de luz del techo
	for x in [-2.4, 0.0, 2.4]:
		b.cube(Vector3(x, H - 0.03, 0.3), Vector3(0.05, 0.03, 7.5), _m["lamp"])


# ------------------------------------------------------------------ mesa táctica

static func map_h() -> float:
	return MAP_W * MAP_PX.y / MAP_PX.x


## Punto de la mesa que corresponde a un píxel del mapa del tablero (y al revés)
static func map_to_world(px: Vector2) -> Vector3:
	return MAP_C + Vector3((px.x / MAP_PX.x - 0.5) * MAP_W, 0.0, (px.y / MAP_PX.y - 0.5) * map_h())


static func world_to_map(p: Vector3) -> Vector2:
	return Vector2(((p.x - MAP_C.x) / MAP_W + 0.5) * MAP_PX.x, ((p.z - MAP_C.z) / map_h() + 0.5) * MAP_PX.y)


## Punto del tablero bajo el rayo (INF si no lo corta)
func _table_hit(from: Vector3, dir: Vector3) -> Vector3:
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := (TABLE_H - from.y) / dir.y
	if t <= 0.0:
		return Vector3.INF
	return from + dir * t


## Píxel del mapa de la mesa bajo un punto de la escena (fuera del mapa sale fuera de 0..1000 × 0..760)
func map_px_at(p: Vector2) -> Vector2:
	var ray := _ray(p)
	var hit := _table_hit(ray[0], ray[1])
	if hit == Vector3.INF:
		return Vector2(-1, -1)
	return world_to_map(hit)


func _table() -> void:
	var w := TABLE_SIZE.x
	var d := TABLE_SIZE.y
	b.box(Transform3D(Basis(), Vector3(0, TABLE_H - 0.035, 0)), Vector3(w, 0.07, d), _m["table"], 1.0, 0.015, 2)
	# tira luminosa del canto y pie
	b.cube(Vector3(0, TABLE_H - 0.075, 0), Vector3(w + 0.02, 0.012, d + 0.02), _m["edge"])
	b.cube(Vector3(0, (TABLE_H - 0.08) * 0.5, 0), Vector3(w - 0.9, TABLE_H - 0.08, d - 0.8), _m["black"])
	# mapa: cristal negro con un marco de luz
	var mh := map_h()
	b.cube(MAP_C - Vector3(0, 0.004, 0), Vector3(MAP_W + 0.08, 0.006, mh + 0.08), _m["black"])
	for sz in [-1.0, 1.0]:
		b.cube(MAP_C + Vector3(0, -0.001, sz * (mh * 0.5 + 0.03)), Vector3(MAP_W + 0.07, 0.004, 0.008), _m["frame"])
	for sx in [-1.0, 1.0]:
		b.cube(MAP_C + Vector3(sx * (MAP_W * 0.5 + 0.03), -0.001, 0), Vector3(0.008, 0.004, mh + 0.07), _m["frame"])
	table_ui = screen(Vector2i(MAP_PX), Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), MAP_C), MAP_W, Color(0.015, 0.04, 0.07), 1.05, 1.25)
	# bandeja de las unidades, a la derecha del mapa, con un hueco iluminado para cada pila
	var tray_c := Vector3((MAP_C.x + MAP_W * 0.5 + w * 0.5) * 0.5 + 0.02, TABLE_H + 0.003, -0.02)
	b.cube(tray_c, Vector3(w * 0.5 - MAP_C.x - MAP_W * 0.5 - 0.12, 0.006, 2.25), _m["felt"])
	var tl := Kit.label(world, "UNIDADES", UI.f_sans_b, 64, Color(0.55, 0.8, 1.0), Vector3(tray_c.x, TABLE_H + 0.008, -1.08), Vector3(-PI / 2.0, 0, 0), 0.0011)
	tl.shaded = false
	for z in TRAY_Z:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.09
		ring.outer_radius = 0.097
		var mi := MeshInstance3D.new()
		mi.mesh = ring
		mi.material_override = _m["slot"]
		mi.scale = Vector3(1, 0.1, 1)
		world.add_child(mi)
		mi.position = Vector3(TRAY_X, TABLE_H + 0.004, z)
	# papeles y vasos en las esquinas
	b.box(Transform3D(Basis(Vector3.UP, 0.2), Vector3(-1.85, TABLE_H + 0.003, -1.15)), Vector3(0.21, 0.006, 0.3), _m["paper"])
	b.cyl(Vector3(1.85, TABLE_H + 0.05, 1.2), 0.04, 0.035, 0.1, Kit.mat(Color("e9e4d8"), 0.3))


## Una ficha: disco azul marino con canto dorado y el icono de la unidad encima
func _make_puck(icon_name: String) -> Node3D:
	var n := Node3D.new()
	world.add_child(n)
	var body := CylinderMesh.new()
	body.top_radius = 0.076
	body.bottom_radius = 0.08
	body.height = 0.03
	body.radial_segments = 24
	body.rings = 1
	var bm := MeshInstance3D.new()
	bm.mesh = body
	bm.material_override = _m["puck"]
	bm.position.y = 0.015
	n.add_child(bm)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.07
	rim.outer_radius = 0.082
	rim.rings = 24
	rim.ring_segments = 6
	var rm := MeshInstance3D.new()
	rm.mesh = rim
	rm.material_override = _m["rim"]
	rm.position.y = 0.03
	rm.scale = Vector3(1, 0.5, 1)
	n.add_child(rm)
	var q := QuadMesh.new()
	q.size = Vector2(0.095, 0.095)
	var im := MeshInstance3D.new()
	im.mesh = q
	im.material_override = _icon_mat(icon_name)
	im.rotation.x = -PI / 2.0
	im.position.y = 0.0305
	im.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(im)
	return n


func _icon_mat(icon_name: String) -> StandardMaterial3D:
	if not _icon_mats.has(icon_name):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = UI.icon(icon_name, 64)
		m.albedo_color = UI.GOLD_L
		_icon_mats[icon_name] = m
	return _icon_mats[icon_name]


func _flat_label(text: String, size: int, col: Color, pos: Vector3, px := 0.001, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label3D:
	var l := Kit.label(world, text, UI.f_sans_b, size, col, pos, Vector3(-PI / 2.0, 0, 0), px)
	l.shaded = false
	l.horizontal_alignment = align
	l.outline_size = 0
	return l


## Pilas de fichas de la bandeja: una por tipo de unidad (las de la Unión, si llegan, en la última fila libre)
func set_units(units: Array) -> void:
	for i in units.size():
		if i >= TRAY_Z.size():
			break
		if i >= _piles.size():
			_piles.append(_make_pile(i, units[i]))
		var pl: Dictionary = _piles[i]
		var u: Dictionary = units[i]
		var n := int(u["left"])
		var pucks: Array = pl["pucks"]
		for k in pucks.size():
			(pucks[k] as Node3D).visible = k < mini(n, PILE_MAX)
		(pl["count"] as Label3D).text = "×%d" % n
		(pl["count"] as Label3D).modulate = UI.GOLD_L if n > 0 else UI.DIM
		(pl["name"] as Label3D).modulate = UI.TEXT if n > 0 else UI.DIM
		var pk: Pick = pl["pick"]
		pk.enabled = ops_on and n > 0
		pk.tip = "%s · quedan %d\nPotencia %d · %s por despliegue%s\nArrástrela a una región del mapa" % [u["name"], n, int(u["power"]),
			UI.money(u["cost"]) if float(u["cost"]) > 0.0 else "sin coste",
			" · Revela amenazas" if u.get("reveal", false) else (" · Reduce víctimas" if u.get("protect", false) else "")]
		pl["n"] = n


func _make_pile(i: int, u: Dictionary) -> Dictionary:
	var z: float = TRAY_Z[i]
	var root := Node3D.new()
	world.add_child(root)
	root.position = Vector3(TRAY_X, TABLE_H + 0.006, z)
	var pucks := []
	for k in PILE_MAX:
		var p := _make_puck(u["icon"])
		p.reparent(root, false)
		p.position = Vector3(0, k * 0.031, 0)
		p.rotation.y = randf_range(-0.3, 0.3)
		pucks.append(p)
	var nm := _flat_label(String(u["name"]).to_upper(), 44, UI.TEXT, Vector3(TRAY_X + 0.12, TABLE_H + 0.008, z - 0.03), 0.0011, HORIZONTAL_ALIGNMENT_LEFT)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.width = 490.0
	nm.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	nm.offset = Vector2(245, 0)
	var cnt := _flat_label("×0", 100, UI.GOLD_L, Vector3(TRAY_X + 0.12, TABLE_H + 0.008, z + 0.06), 0.0011, HORIZONTAL_ALIGNMENT_LEFT)
	cnt.width = 300.0
	cnt.offset = Vector2(150, 0)
	cnt.font = UI.f_cond_b
	var meshes := []
	for p in pucks:
		meshes += (p as Node3D).find_children("*", "MeshInstance3D", true, false)
	var pk := add_pick(root, AABB(Vector3(-0.11, 0, -0.11), Vector3(0.22, 0.22, 0.22)), "", Callable(), meshes)
	pk.on_drag = _pile_drag.bind(i)
	return {"root": root, "pucks": pucks, "name": nm, "count": cnt, "pick": pk, "icon": u["icon"], "n": 0}


func _pile_drag(from: Vector3, dir: Vector3, phase: String, i: int) -> void:
	var hit := _table_hit(from, dir)
	match phase:
		"press":
			if is_instance_valid(_ghost):
				_ghost.queue_free()
			_ghost = _make_puck(String(_piles[i]["icon"]))
			# la ficha de arriba de la pila se va con el ratón
			var pucks: Array = _piles[i]["pucks"]
			var top := mini(int(_piles[i]["n"]), PILE_MAX) - 1
			if top >= 0:
				(pucks[top] as Node3D).visible = false
			Sfx.play("paper2", -8.0, 1.4)
		"release":
			if is_instance_valid(_ghost):
				_ghost.queue_free()
			_ghost = null
			var px := world_to_map(hit) if hit != Vector3.INF else Vector2(-1, -1)
			_hover_px(Vector2(-1, -1))
			if on_drop_unit.is_valid():
				on_drop_unit.call(i, px)
			return
	_follow(_ghost, hit)


## La ficha que se arrastra va por encima de la mesa, bajo el ratón, y el panel resalta la región de debajo
func _follow(n: Node3D, hit: Vector3) -> void:
	if not is_instance_valid(n):
		return
	n.visible = hit != Vector3.INF
	if hit == Vector3.INF:
		_hover_px(Vector2(-1, -1))
		return
	n.global_position = hit + Vector3(0, 0.05, 0)
	_hover_px(world_to_map(hit))


func _hover_px(px: Vector2) -> void:
	if on_hover_px.is_valid():
		on_hover_px.call(px)


## Fichas desplegadas: [{"id", "pos" (píxel del mapa), "icon", "lift", "tip"}] (el panel las manda en cada fotograma)
func sync_tokens(list: Array) -> void:
	var seen := {}
	for t in list:
		var id := int(t["id"])
		seen[id] = true
		if not _pucks.has(id):
			var n := _make_puck(String(t["icon"]))
			var pk := add_pick_sphere(n, 0.095, Vector3(0, 0.02, 0), "", Callable())
			pk.on_drag = _token_drag.bind(id)
			_pucks[id] = {"node": n, "pick": pk}
		var e: Dictionary = _pucks[id]
		(e["pick"] as Pick).tip = String(t["tip"])
		(e["pick"] as Pick).enabled = ops_on
		if id == _drag_tid:
			continue
		(e["node"] as Node3D).global_position = map_to_world(t["pos"]) + Vector3(0, 0.002 + float(t.get("lift", 0.0)), 0)
	for id in _pucks.keys():
		if not seen.has(id):
			var e: Dictionary = _pucks[id]
			remove_pick(e["pick"])
			(e["node"] as Node3D).queue_free()
			_pucks.erase(id)
			if _drag_tid == id:
				_drag_tid = -1


func _token_drag(from: Vector3, dir: Vector3, phase: String, id: int) -> void:
	if not _pucks.has(id):
		return
	var hit := _table_hit(from, dir)
	match phase:
		"press":
			_drag_tid = id
			Sfx.play("paper2", -8.0, 1.5)
		"release":
			_drag_tid = -1
			_hover_px(Vector2(-1, -1))
			if on_drop_token.is_valid():
				on_drop_token.call(id, world_to_map(hit) if hit != Vector3.INF else Vector2(-1, -1))
			return
	_follow(_pucks[id]["node"], hit)


## Medida extraordinaria en el borde de la mesa: el pulsador rojo, la banderita de la Unión o el micrófono
func add_special(id: String, title: String, desc: String) -> void:
	var n := Node3D.new()
	world.add_child(n)
	n.position = Vector3(SPECIAL_X.get(id, 0.0), TABLE_H, SPECIAL_Z)
	var lit := []
	match id:
		"emergencia":
			_part(n, _cyl_mesh(0.085, 0.09, 0.012), Kit.mat(Color("e0b020"), 0.5), Vector3(0, 0.006, 0))
			_part(n, _cyl_mesh(0.065, 0.07, 0.03), _m["black"], Vector3(0, 0.02, 0))
			var dome := SphereMesh.new()
			dome.radius = 0.05
			dome.height = 0.05
			dome.is_hemisphere = true
			var dm := Kit.emissive(Color(1.0, 0.1, 0.06), 1.6).duplicate() as StandardMaterial3D
			lit.append(dm)
			_part(n, dome, dm, Vector3(0, 0.035, 0))
		"ayuda":
			_part(n, _cyl_mesh(0.045, 0.05, 0.015), _m["chrome"], Vector3(0, 0.0075, 0))
			_part(n, _cyl_mesh(0.005, 0.005, 0.24), _m["chrome"], Vector3(0, 0.12, 0))
			var q := QuadMesh.new()
			q.size = Vector2(0.15, 0.09)
			var fm := StandardMaterial3D.new()
			fm.albedo_texture = _desk_flag("union")
			fm.cull_mode = BaseMaterial3D.CULL_DISABLED
			fm.emission_enabled = true
			fm.emission_texture = fm.albedo_texture
			fm.emission_energy_multiplier = 0.35
			lit.append(fm)
			var fl := _part(n, q, fm, Vector3(0.078, 0.19, 0))
			fl.rotation.y = 0.35
		"comparecer":
			_part(n, _cyl_mesh(0.055, 0.06, 0.02), _m["black"], Vector3(0, 0.01, 0))
			var neck := CylinderMesh.new()
			neck.top_radius = 0.006
			neck.bottom_radius = 0.006
			neck.height = 0.16
			var nk := _part(n, neck, _m["black"], Vector3(0, 0.09, -0.02))
			nk.rotation.x = -0.35
			var head := SphereMesh.new()
			head.radius = 0.022
			head.height = 0.07
			var hd := _part(n, head, Kit.mat(Color("15161a"), 0.9), Vector3(0, 0.17, -0.05))
			hd.rotation.x = -0.9
			var led := Kit.emissive(Color(1.0, 0.2, 0.15), 2.0).duplicate() as StandardMaterial3D
			lit.append(led)
			_part(n, _cyl_mesh(0.008, 0.008, 0.004), led, Vector3(0.03, 0.022, 0.03))
	var lbl := _flat_label(title.to_upper(), 34, UI.CREAM, Vector3(n.position.x, TABLE_H + 0.006, SPECIAL_Z + 0.135), 0.001)
	var pk := add_pick(n, AABB(Vector3(-0.1, 0, -0.1), Vector3(0.2, 0.26, 0.2)), "%s\n%s" % [title, desc], func():
		if on_special.is_valid():
			on_special.call(id))
	pk.enabled = ops_on
	_specials[id] = {"node": n, "pick": pk, "lbl": lbl, "lit": lit, "used": false}


func _cyl_mesh(rt: float, rb: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = 24
	c.rings = 1
	return c


func _part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _desk_flag(id: String) -> Texture2D:
	var sv := SubViewport.new()
	sv.size = Vector2i(200, 120)
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var c := Control.new()
	c.size = Vector2(200, 120)
	c.draw.connect(func(): Flags.draw_flag(c, id, Rect2(0, 0, 200, 120)))
	sv.add_child(c)
	return sv.get_texture()


## Medida ya usada: se apaga y ya no se puede pulsar
func special_done(id: String) -> void:
	if not _specials.has(id):
		return
	var s: Dictionary = _specials[id]
	s["used"] = true
	(s["pick"] as Pick).enabled = false
	(s["lbl"] as Label3D).modulate = Color(UI.DIM, 0.6)
	for m in s["lit"]:
		var sm := m as StandardMaterial3D
		sm.emission_energy_multiplier *= 0.15
		sm.albedo_color = sm.albedo_color.darkened(0.5)
	# el pulsador se queda hundido
	if id == "emergencia":
		var n: Node3D = s["node"]
		n.create_tween().tween_property(n, "position:y", TABLE_H - 0.012, 0.15)


## Punto de la escena (1920 × 1080) donde se ve un punto 3D (para las pruebas)
func scene_point(p: Vector3) -> Vector2:
	return cam.unproject_position(p) * size / Vector2(vp.size)


## Ratón simulado (pruebas): kind = "press", "move" o "release"
func test_mouse(p: Vector2, kind: String) -> void:
	if kind == "move":
		var mv := InputEventMouseMotion.new()
		mv.position = p
		_mouse(mv)
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = kind == "press"
	ev.position = p
	if kind == "press":
		_hover_at(p)
	_mouse(ev)


## Empieza o acaba la operación: las fichas y las medidas se pueden coger o no
func set_ops(on: bool) -> void:
	ops_on = on
	for pl in _piles:
		(pl["pick"] as Pick).enabled = on and int(pl["n"]) > 0
	for id in _specials:
		(_specials[id]["pick"] as Pick).enabled = on and not _specials[id]["used"]
	for id in _pucks:
		(_pucks[id]["pick"] as Pick).enabled = on
	if not on:
		_drag = null
		_drag_tid = -1
		if is_instance_valid(_ghost):
			_ghost.queue_free()
		_ghost = null


# ------------------------------------------------------------------ sala

## Videowall: cabecera de la emergencia y el mapa con la intensidad por regiones
func _videowall() -> void:
	var ui := screen(Vector2i(1600, 900), Transform3D(Basis(), Vector3(0, 2.0, Z0 + 0.02)), 5.4, Color(0.02, 0.04, 0.08), 1.15)
	b.box(Transform3D(Basis(), Vector3(0, 2.0, Z0 - 0.025)), Vector3(5.6, 3.2, 0.05), _m["black"])
	var head := Control.new()
	head.size = Vector2(1600, 120)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.draw.connect(func():
		head.draw_rect(Rect2(0, 0, 1600, 110), Color(0.35, 0.03, 0.03, 0.9))
		head.draw_string(UI.f_sans_b, Vector2(40, 46), "GABINETE DE CRISIS · NIVEL MÁXIMO", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.85, 0.8))
		head.draw_string(UI.f_serif_b, Vector2(40, 96), crisis_title, HORIZONTAL_ALIGNMENT_LEFT, 1300, 44, Color.WHITE)
		var on := int(_t * 2.0) % 2 == 0
		head.draw_circle(Vector2(1480, 55), 16, Color(1, 0.15, 0.1) if on else Color(0.4, 0.05, 0.05))
		head.draw_string(UI.f_sans_b, Vector2(1380, 64), "EN CURSO", HORIZONTAL_ALIGNMENT_RIGHT, 80, 22, Color.WHITE))
	ui.add_child(head)
	set_meta("wall_head", head)
	wall_map = MapView.new()
	wall_map.position = Vector2(250, 130)
	wall_map.size = Vector2(1100, 760)
	ui.add_child(wall_map)


## Pantallas laterales: el canal de noticias y la evolución de los daños
func _side_screens() -> void:
	var news_ui := screen(Vector2i(960, 540), Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(X0 + 0.04, 2.1, -1.4)), 2.4, Color(0.05, 0.05, 0.08), 1.1)
	_news = Control.new()
	_news.size = Vector2(960, 540)
	_news.mouse_filter = Control.MOUSE_FILTER_IGNORE
	news_ui.add_child(_news)
	_news.draw.connect(func():
		_news.draw_rect(Rect2(0, 0, 960, 540), Color("101a33"))
		_news.draw_rect(Rect2(0, 0, 960, 70), Color("c62828"))
		_news.draw_string(UI.f_sans_b, Vector2(24, 50), "CANAL 24 · ÚLTIMA HORA", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
		_news.draw_string(UI.f_serif_b, Vector2(24, 170), crisis_title, HORIZONTAL_ALIGNMENT_LEFT, 910, 48, Color.WHITE)
		_news.draw_string(UI.f_sans_m, Vector2(24, 240), "El Gobierno se reúne de urgencia en el Palacio", HORIZONTAL_ALIGNMENT_LEFT, 910, 28, Color(1, 1, 1, 0.8))
		_news.draw_rect(Rect2(0, 470, 960, 70), Color("0a0f1e"))
		var scroll := fmod(_t * 120.0, 1400.0)
		_news.draw_string(UI.f_sans_m, Vector2(960 - scroll, 515), "EN DIRECTO · Siga la última hora de la emergencia · Los servicios de emergencia, desbordados · ", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.9, 0.5)))
	var data_ui := screen(Vector2i(960, 540), Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(X1 - 0.04, 2.1, -1.4)), 2.4, Color(0.02, 0.04, 0.06), 1.1)
	_data = Control.new()
	_data.size = Vector2(960, 540)
	_data.mouse_filter = Control.MOUSE_FILTER_IGNORE
	data_ui.add_child(_data)
	_data.draw.connect(func():
		_data.draw_rect(Rect2(0, 0, 960, 540), Color("06121c"))
		_data.draw_string(UI.f_mono, Vector2(24, 50), "CENTRO NACIONAL DE EMERGENCIAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.4, 0.9, 1.0))
		for i in 8:
			var v := 0.35 + 0.3 * sin(_t * 0.7 + i * 1.3) + 0.2 * sin(_t * 1.9 + i)
			var col := Color(1, 0.3, 0.2) if v > 0.6 else Color(0.3, 0.8, 1.0)
			_data.draw_string(UI.f_mono, Vector2(24, 110 + i * 52), W.REGIONS[i + 1]["name"].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.85, 0.95))
			_data.draw_rect(Rect2(330, 88 + i * 52, 580 * clampf(v, 0.05, 1.0), 26), col))
	for s in [news_ui, data_ui]:
		var mi := screen_mesh(s)
		b.box(mi.global_transform * Transform3D(Basis(), Vector3(0, 0, -0.03)), Vector3(2.5, 1.45, 0.05), _m["black"])


## El Gobierno, de pie alrededor de la mesa táctica: el responsable de esta crisis a la izquierda del presidente,
## la Vicepresidencia a la derecha y los demás, detrás
func _people() -> void:
	var keys := ["vice", resp_key, "jefa", "defensa", "interior", "sanidad", "economia", "exteriores"]
	var seen := []
	for k in keys:
		if not (k in seen) and GS.ministers.has(k):
			seen.append(k)
	var spots := [Vector3(-2.45, 0, 0.55), Vector3(2.45, 0, 0.55), Vector3(-2.45, 0, -0.55), Vector3(2.45, 0, -0.55), Vector3(-0.7, 0, -1.75), Vector3(0.7, 0, -1.75)]
	var order: Array = seen.slice(0, 1)
	if seen.size() > 1:
		order = [seen[1], seen[0]] + seen.slice(2, 6)
	for i in mini(order.size(), spots.size()):
		var p: Vector3 = spots[i]
		var v := person(GS.ministers[order[i]]["look"], p, yaw_to(p, Vector3(MAP_C.x * 0.5, 0, 0)), "", true, 2)
		v.rest_anim = "idle"
		v.set_meta("key", order[i])
		ministers.append(v)
		if order[i] == resp_key:
			_resp = v


func _lights() -> void:
	env.background_color = Color(0.01, 0.012, 0.018)
	env.ambient_light_color = Color(0.4, 0.5, 0.75)
	env.ambient_light_energy = 0.45
	env.volumetric_fog_density = 0.01
	spot(Vector3(0.3, H - 0.1, 0.4), Vector3(0, TABLE_H, 0.0), 2.6, 55.0, Color(0.85, 0.9, 1.0), not low, 6.0)
	spot(Vector3(0, H - 0.2, 3.6), Vector3(0, 1.2, -1.0), 1.2, 40.0, Color(0.9, 0.92, 1.0), false, 8.0)
	omni(Vector3(0, 2.0, Z0 + 1.0), 1.4, 6.0, Color(0.35, 0.55, 1.0), false)
	_alarm = omni(Vector3(0, 3.3, -1.0), 2.0, 9.0, Color(1.0, 0.1, 0.05), false)
	# luz sobre las caras del Gobierno
	for sx in [-1.0, 1.0]:
		spot(Vector3(sx * 1.2, H - 0.2, 0.0), Vector3(sx * 2.45, 1.5, 0.0), 1.6, 45.0, Color(0.9, 0.93, 1.0), false, 6.0)
	spot(Vector3(0, H - 0.2, -0.6), Vector3(0, 1.5, -1.75), 1.4, 45.0, Color(0.9, 0.93, 1.0), false, 6.0)
	for x in [-2.4, 0.0, 2.4]:
		for z in [-2.6, 0.3, 3.2]:
			glow(Vector3(x, H - 0.06, z), 0.18, Color(0.8, 0.88, 1.0, 0.3))


## Mientras dura la operación: la cámara se asoma a la mesa táctica y el Gobierno habla por teléfono y entre sí
func set_running(on: bool) -> void:
	if on:
		cam_pos = Vector3(0.0, 3.05, 2.35)
		cam_look = Vector3(-0.05, TABLE_H, 0.0)
		fov_target = 52.0
		cam_speed = 1.6
		sway = 0.0
		for v in ministers:
			if _rng.randf() < 0.5:
				v.talking = true


## Final de la crisis: aplausos si ha salido bien, caras largas si mal; si se delegó, el responsable da el parte
func result(score: float, delegated: bool) -> void:
	_alarm_on = false
	set_ops(false)
	for v in ministers:
		v.talking = false
		if score >= 0.62:
			gesture(v, "clap" if _rng.randf() < 0.7 else "cheer", randf_range(2.0, 3.5))
			v.mood = 0.6
		elif score < 0.38:
			v.mood = -0.7
			v.anger = 0.3
		else:
			v.mood = -0.1
	if delegated and is_instance_valid(_resp):
		_resp.talking = true
	# plano de la mesa y del Gobierno desde el lado del presidente
	cam_pos = Vector3(0.9, 2.3, 2.7)
	cam_look = Vector3(-0.7, 1.25, -0.6)
	fov_target = 50.0
	cam_speed = 1.0


func _process(delta: float) -> void:
	super(delta)
	var pulse := 0.5 + 0.5 * sin(_t * (6.0 if _alarm_on else 1.2))
	if _alarm != null:
		_alarm.light_energy = (0.4 + 2.2 * pulse) if _alarm_on else 0.15
	if _alarm_mat != null:
		_alarm_mat.emission_energy_multiplier = (0.6 + 2.4 * pulse) if _alarm_on else 0.3
	if has_meta("wall_head"):
		(get_meta("wall_head") as Control).queue_redraw()
	if _news != null:
		_news.queue_redraw()
	if _data != null and _frame % 3 == 0:
		_data.queue_redraw()
