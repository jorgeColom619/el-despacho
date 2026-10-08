extends Control
## Escenario 3D detrás de un minijuego (sala de prensa, sala de negociación, hemiciclo del Congreso).
## Se pinta en su propio SubViewport a la resolución de la ventana y con la calidad gráfica del despacho;
## mientras está abierto, el despacho 3D deja de dibujarse. Las subclases montan la sala en build().

const Kit := preload("res://scripts/office3d/kit.gd")
const Tex := preload("res://scripts/office3d/tex3d.gd")
const Visitor3D := preload("res://scripts/office3d/visitor_3d.gd")
const Flags := preload("res://scripts/ui/flags.gd")
const BANNER_SHADER := preload("res://shaders/banner3d.gdshader")

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var env: Environment
var b := Kit.Batch.new()
var gfx := "media"
var advanced := false
var low := false
var hi := false
## Cámara: va suavemente hacia cam_pos mirando a cam_look (con un leve balanceo si sway > 0)
var cam_pos := Vector3(0, 1.6, 0)
var cam_look := Vector3(0, 1.6, -1)
var cam_speed := 2.5
var sway := 0.0
## Interfaz del minijuego en la pantalla 3D de la sala (si la sala tiene una)
var ui: Control
## Oscurecido arriba y abajo de la pantalla para que se lean los textos del minijuego
var shade_top := 0.55
var shade_bottom := 0.45
var _cam_look_now := Vector3.ZERO
var _t := 0.0
var _flashes: Array = []
var _flag_texs := {}
var _office_world: Node3D
var _shot_path := ""
var _shot_wait := 0
## Pantallas 3D con interfaz (screen()): {"vp", "mi", "size", "w", "h"}
var _screens: Array = []
var _drag_screen = null
var _hover_screen = null
## Clic simulado para las pruebas: [x, y, fotograma] en coordenadas de la pantalla (1920 × 1080)
var _test_click := []
var _frame := 0


## Los escenarios 3D acompañan al despacho 3D (con el despacho 2D, los fondos de siempre)
static func enabled() -> bool:
	return bool(Sfx.settings.get("view3d", true))


## Texturas que usan las salas (se preparan en segundo plano desde el menú, como las del despacho)
static func tex_specs() -> Array:
	return [["carpet", {"c0": "6e1820", "c1": "3d0b10"}],
		["wallpaper", {"c0": "e7dcc4", "c1": "dccfb2", "acc": "b89a5a"}], ["velvet", {}], ["leather", {}],
		["plaster", {}], ["brushed", {}], ["parquet", {}], ["wood", Tex.wood_params("caoba")],
		["wood", Tex.wood_params("panel")], ["wood", Tex.wood_params("ebano")], ["wood", Tex.wood_params("roble")]]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# recibe el ratón para llevarlo a las pantallas 3D con interfaz
	mouse_filter = Control.MOUSE_FILTER_PASS
	gfx = Sfx.gfx_preset()
	advanced = RenderingServer.get_current_rendering_method() in ["forward_plus", "mobile"]
	low = gfx == "baja"
	hi = gfx in ["alta", "ultra"]
	var rv := get_tree().root
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = rv.msaa_3d
	vp.screen_space_aa = rv.screen_space_aa
	vp.use_debanding = rv.use_debanding
	vp.scaling_3d_mode = rv.scaling_3d_mode
	vp.scaling_3d_scale = rv.scaling_3d_scale
	vp.positional_shadow_atlas_size = rv.positional_shadow_atlas_size
	add_child(vp)
	var view := TextureRect.new()
	view.texture = vp.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	_resize()
	rv.size_changed.connect(_resize)
	world = Node3D.new()
	vp.add_child(world)
	cam = Camera3D.new()
	cam.near = 0.05
	cam.far = 250.0
	world.add_child(cam)
	cam.make_current()
	_environment()
	build()
	_shade()
	cam.global_position = cam_pos
	_cam_look_now = cam_look
	cam.look_at(cam_look)
	_show_office(false)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stageshot="):
			_shot_path = a.substr(12)
			_shot_wait = 90
		elif a.begins_with("--stagewait="):
			_shot_wait = int(a.substr(12))
		elif a.begins_with("--stageclick="):
			_test_click = Array(a.substr(13).split_floats(","))


func _exit_tree() -> void:
	_show_office(true)


## Lo que monta cada sala
func build() -> void:
	pass


func _shade() -> void:
	var shade := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	var ink := Color(0.01, 0.015, 0.03)
	gr.offsets = PackedFloat32Array([0.0, 0.36, 0.72, 1.0])
	gr.colors = PackedColorArray([Color(ink, shade_top), Color(ink, 0.0), Color(ink, 0.0), Color(ink, shade_bottom)])
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _resize() -> void:
	var s := get_tree().root.size
	vp.size = Vector2i(maxi(s.x, 64), maxi(s.y, 36))


## El despacho no se ve detrás del escenario: deja de dibujarse mientras tanto (y la vista principal no
## calcula su 3D: sin esto seguía pagando la iluminación global y la niebla del despacho, aunque oculto)
func _show_office(on: bool) -> void:
	get_tree().root.disable_3d = not on
	if on:
		if is_instance_valid(_office_world):
			_office_world.visible = true
		return
	var main := get_tree().root.get_node_or_null("Main")
	if main != null and main.get("office") != null and main.office.get("world") is Node3D:
		_office_world = main.office.world
		_office_world.visible = false


func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.022, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.58, 0.56)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES if advanced else Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0 if advanced else 1.08
	env.tonemap_white = 6.0
	env.glow_enabled = not low
	env.glow_intensity = 0.45
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN if advanced else Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.05
	env.ssao_enabled = advanced and not low
	env.ssao_radius = 0.9
	env.ssao_intensity = 2.0
	env.ssao_power = 1.4
	env.ssil_enabled = advanced and hi
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.7
	env.sdfgi_enabled = advanced and hi
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = false
	env.sdfgi_energy = 0.9
	env.sdfgi_min_cell_size = 0.12
	env.sdfgi_cascades = 6 if gfx == "ultra" else 4
	env.volumetric_fog_enabled = advanced and hi
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(1.0, 0.96, 0.9)
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_ambient_inject = 0.05
	env.volumetric_fog_temporal_reprojection_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)


func _process(delta: float) -> void:
	_t += delta
	var k := minf(1.0, delta * cam_speed)
	var p := cam_pos
	if sway > 0.0:
		p += Vector3(sin(_t * 0.37) * 0.6, sin(_t * 0.53 + 1.0) * 0.35, 0.0) * sway
	cam.global_position = cam.global_position.lerp(p, k)
	_cam_look_now = _cam_look_now.lerp(cam_look, k)
	if not cam.global_position.is_equal_approx(_cam_look_now):
		cam.look_at(_cam_look_now)
	_update_flashes(delta)
	_frame += 1
	if _test_click.size() >= 3 and _frame == int(_test_click[2]):
		# las coordenadas de la prueba van en píxeles de la ventana (los de la captura)
		var at := Vector2(_test_click[0], _test_click[1]) * size / Vector2(DisplayServer.window_get_size())
		var mv := InputEventMouseMotion.new()
		mv.position = at
		_mouse(mv)
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.position = at
			_mouse(ev)
	if _shot_path != "":
		_shot_wait -= 1
		if _shot_wait == 0:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()


# ------------------------------------------------------------------ pantallas con interfaz

## Pantalla 3D con interfaz: el minijuego pone sus controles en el Control que devuelve (de `size` píxeles
## virtuales) y se ve en un rectángulo de `width` metros con la transformación xf (la cara mira a +Z).
## Se usa con el ratón como cualquier interfaz.
func screen(size: Vector2i, xf: Transform3D, width: float, bg := Color(0.02, 0.03, 0.06), energy := 1.0, res := 1.25) -> Control:
	var sv := SubViewport.new()
	sv.size = Vector2i(Vector2(size) * res)
	sv.size_2d_override = size
	sv.size_2d_override_stretch = true
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var ui := Control.new()
	ui.theme = UI.theme
	ui.size = Vector2(size)
	ui.clip_contents = true
	sv.add_child(ui)
	var back := ColorRect.new()
	back.color = bg
	back.size = Vector2(size)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(back)
	var h := width * size.y / size.x
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, h)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = sv.get_texture()
	m.albedo_color = Color(energy, energy, energy)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_transform = xf
	_screens.append({"vp": sv, "mi": mi, "size": Vector2(size), "w": width, "h": h})
	return ui


## Transformación para una pantalla en p que mira hacia el punto eye (sin girar sobre sí misma)
static func facing(p: Vector3, eye: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(p - eye, Vector3.UP), p)


## Primera persona desde eye (mirando hacia yaw, `pitch` grados hacia abajo) con la pantalla del minijuego
## delante, inclinada hacia los ojos y `drop` grados por debajo de la horizontal: ocupa la mitad de abajo
## y deja ver a la gente por encima. Devuelve el Control donde va la interfaz.
func pov_screen(eye: Vector3, yaw: float, size: Vector2i, width: float, pitch := 14.0, drop := 23.5, dist := 0.75, res := 1.25) -> Control:
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	cam.fov = 66.0
	cam_pos = eye
	cam_look = eye + (fwd * cos(deg_to_rad(pitch)) - Vector3.UP * sin(deg_to_rad(pitch))) * 10.0
	sway = 0.0
	shade_top = 0.3
	shade_bottom = 0.0
	var c := eye + (fwd * cos(deg_to_rad(drop)) - Vector3.UP * sin(deg_to_rad(drop))) * dist
	var xf := facing(c, eye)
	var h := width * size.y / size.x
	var dark := Kit.mat(Color("101114"), 0.35, 0.3)
	b.box(xf * Transform3D(Basis(), Vector3(0, 0, -0.016)), Vector3(width + 0.036, h + 0.036, 0.024), dark, 1.0, 0.008)
	b.segment((xf * Transform3D(Basis(), Vector3(0, -h * 0.4, -0.03))).origin, (xf * Transform3D(Basis(), Vector3(0, -h * 0.5 - 0.12, -0.08))).origin, 0.018, dark, 8)
	b.commit(world)
	return screen(size, xf, width, Color(0.02, 0.03, 0.06), 1.0, res)


## Otra copia (solo de ver, sin ratón) de una pantalla creada con screen(): los marcadores del hemiciclo
func screen_copy(src: Control, xf: Transform3D, width: float, energy := 1.0) -> void:
	var sv := src.get_parent() as SubViewport
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, width * src.size.y / src.size.x)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = sv.get_texture()
	m.albedo_color = Color(energy, energy, energy)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_transform = xf


## Corte de plano: la cámara salta a cam_pos / cam_look sin recorrido
func cut() -> void:
	cam.global_position = cam_pos
	_cam_look_now = cam_look
	cam.look_at(cam_look)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse and _mouse(event):
		accept_event()


## Ratón sobre la escena: a la pantalla que esté debajo o, si no hay ninguna, a la propia escena
func _mouse(event: InputEventMouse) -> bool:
	if _forward(event):
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position * Vector2(vp.size) / size
		return _click_world(cam.project_ray_origin(p), cam.project_ray_normal(p))
	return false


## Clic en la escena (fuera de las pantallas): cada sala decide qué hacer (p. ej. elegir a un líder)
func _click_world(_from: Vector3, _dir: Vector3) -> bool:
	return false


## Lleva un evento del ratón a la pantalla 3D que hay bajo el cursor. Devuelve true si cae en una
func _forward(event: InputEventMouse) -> bool:
	if _screens.is_empty() or size.x <= 0.0:
		return false
	var p := event.position * Vector2(vp.size) / size
	var from := cam.project_ray_origin(p)
	var dir := cam.project_ray_normal(p)
	var best = null
	var best_t := INF
	var best_uv := Vector2.ZERO
	for s in _screens:
		var mi: MeshInstance3D = s["mi"]
		if not mi.is_visible_in_tree():
			continue
		var xf := mi.global_transform
		var n := xf.basis.z.normalized()
		var dn := dir.dot(n)
		if absf(dn) < 0.0001:
			continue
		var t := (xf.origin - from).dot(n) / dn
		if t <= 0.0:
			continue
		var loc := xf.affine_inverse() * (from + dir * t)
		var uv := Vector2(loc.x / float(s["w"]) + 0.5, 0.5 - loc.y / float(s["h"]))
		var inside := uv.x >= 0.0 and uv.x <= 1.0 and uv.y >= 0.0 and uv.y <= 1.0
		if (inside or s == _drag_screen) and t < best_t:
			best = s
			best_t = t
			best_uv = uv.clamp(Vector2.ZERO, Vector2.ONE)
	if _drag_screen != null and best != _drag_screen:
		best = null
	# al salir de una pantalla, el ratón se va "lejos" para que se apague el resaltado de los botones
	if _hover_screen != null and best != _hover_screen:
		var away := InputEventMouseMotion.new()
		away.position = Vector2(-100, -100)
		away.global_position = away.position
		(_hover_screen["vp"] as SubViewport).push_input(away, true)
	_hover_screen = best
	if best == null:
		return false
	var ev := event.duplicate() as InputEventMouse
	ev.position = best_uv * Vector2(best["size"])
	ev.global_position = ev.position
	(best["vp"] as SubViewport).push_input(ev, true)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_screen = best if event.pressed else null
	return true


# ------------------------------------------------------------------ personas

## Personaje con el aspecto `look`, mirando hacia yaw (radianes; 0 = hacia +Z).
## mode: "sit" (silla), "table" (en la mesa) o "" (de pie)
func person(look: Dictionary, pos: Vector3, yaw: float, mode := "", shadows := true) -> Node3D:
	var v := Visitor3D.new()
	world.add_child(v)
	v.set_meta("g", look.get("g", "m"))
	v.dress(look)
	v.seat(mode)
	v.show_at(pos)
	v.rotation.y = yaw
	v.desync()
	if not shadows or low:
		for mi in v.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return v


## Rumbo (yaw) para mirar desde `from` hacia `to`
static func yaw_to(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.x, d.z)


## Aspecto al azar (traje, peinado, piel...) de un periodista, diputado o asesor
static func rand_look(rng: RandomNumberGenerator) -> Dictionary:
	var g := "m" if rng.randf() < 0.55 else "f"
	var l: Dictionary = DB.rand_look(g)
	return l


# ------------------------------------------------------------------ banderas

## Bandera dibujada en 2D (Flags.draw_flag) en vertical: la vaina va arriba y la tela cae
func flag_tex(id: String) -> Texture2D:
	if _flag_texs.has(id):
		return _flag_texs[id]
	var sv := SubViewport.new()
	sv.size = Vector2i(240, 400)
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var c := Control.new()
	c.size = Vector2(240, 400)
	c.draw.connect(func():
		c.draw_set_transform(Vector2(240, 0), PI / 2.0)
		Flags.draw_flag(c, id, Rect2(0, 0, 400, 240)))
	sv.add_child(c)
	_flag_texs[id] = sv.get_texture()
	return _flag_texs[id]


## Mástil con peana, remate dorado y la bandera colgando a un lado, con pliegues
func flag_pole(pos: Vector3, id: String, yaw := 0.0, h := 2.7) -> MeshInstance3D:
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	var gold := Kit.gold()
	b.lathe(xf, [Vector2(0.2, 0.0), Vector2(0.2, 0.03), Vector2(0.16, 0.05), Vector2(0.12, 0.06), Vector2(0.05, 0.1), Vector2(0.035, 0.16), Vector2(0.0, 0.17)], gold, 24)
	b.cylinder(xf * Transform3D(Basis(), Vector3(0, h * 0.5, 0)), 0.017, 0.019, h, Kit.wood("ebano"), 12)
	b.lathe(xf * Transform3D(Basis(), Vector3(0, h, 0)), [Vector2(0.02, 0.0), Vector2(0.03, 0.02), Vector2(0.035, 0.05), Vector2(0.015, 0.08), Vector2(0.04, 0.1), Vector2(0.0, 0.24)], gold, 14)
	var cloth := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.72, 1.55)
	qm.subdivide_width = 24
	qm.subdivide_depth = 12
	cloth.mesh = qm
	var m := ShaderMaterial.new()
	m.shader = BANNER_SHADER
	m.set_shader_parameter("tex", flag_tex(id))
	m.set_shader_parameter("phase", pos.x * 1.7 + pos.z)
	cloth.material_override = m
	world.add_child(cloth)
	cloth.global_transform = xf * Transform3D(Basis(), Vector3(0.39, h - 0.86, 0.0))
	return cloth


## Estrella plana de n puntas (escudos, emblemas) en el plano XY de xf, mirando a +Z
func star(xf: Transform3D, r_out: float, r_in: float, m: Material, n := 5) -> void:
	var pts := Flags.star_points(Vector2.ZERO, r_out, r_in, n)
	var st: SurfaceTool = b._tool(m)
	for i in pts.size():
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[(i + 1) % pts.size()]
		for v in [Vector3.ZERO, Vector3(p1.x, -p1.y, 0.0), Vector3(p0.x, -p0.y, 0.0)]:
			b._v(st, xf, v, Vector3.BACK, Vector2(v.x, v.y))


# ------------------------------------------------------------------ flashes de fotógrafos

## Destello de flash: una luz muy breve y un halo que se apaga en décimas de segundo
func flash(pos: Vector3, power := 1.0) -> void:
	var f: Dictionary = {}
	for e in _flashes:
		if float(e["t"]) >= 0.25:
			f = e
			break
	if f.is_empty():
		var l := OmniLight3D.new()
		l.light_color = Color(0.92, 0.95, 1.0)
		l.omni_range = 7.0
		l.omni_attenuation = 1.6
		l.shadow_enabled = false
		l.light_volumetric_fog_energy = 2.0
		world.add_child(l)
		var s := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.9)
		s.mesh = q
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		sm.albedo_texture = glow_tex()
		sm.no_depth_test = false
		s.material_override = sm
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(s)
		f = {"l": l, "s": s, "t": 1.0, "p": 1.0}
		_flashes.append(f)
	f["t"] = 0.0
	f["p"] = power
	(f["l"] as Node3D).global_position = pos
	(f["s"] as Node3D).global_position = pos
	if randf() < 0.5:
		Sfx.play("flash", -16.0, randf_range(0.9, 1.15))


func _update_flashes(delta: float) -> void:
	for f in _flashes:
		f["t"] = float(f["t"]) + delta
		var t: float = f["t"]
		var a := clampf(1.0 - t / 0.16, 0.0, 1.0)
		a *= a
		var l: OmniLight3D = f["l"]
		l.visible = a > 0.01
		l.light_energy = 9.0 * a * float(f["p"])
		var s: MeshInstance3D = f["s"]
		s.visible = a > 0.01
		(s.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, a)


static var _glow: ImageTexture


## Halo radial blanco (flashes, pilotos, bombillas vistas de lejos)
static func glow_tex() -> ImageTexture:
	if _glow != null:
		return _glow
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2((x - 31.5) / 31.5, (y - 31.5) / 31.5).length()
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, pow(a, 2.4)))
	img.generate_mipmaps()
	_glow = ImageTexture.create_from_image(img)
	return _glow


## Bombilla o piloto: halo que siempre mira a la cámara
func glow(pos: Vector3, size: float, col: Color) -> MeshInstance3D:
	var s := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	s.mesh = q
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.albedo_texture = glow_tex()
	sm.albedo_color = col
	s.material_override = sm
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(s)
	s.global_position = pos
	return s


# ------------------------------------------------------------------ luces

func spot(pos: Vector3, target: Vector3, energy: float, angle: float, col := Color(1, 0.95, 0.86), shadows := false, rng := 18.0) -> SpotLight3D:
	var l := SpotLight3D.new()
	world.add_child(l)
	l.look_at_from_position(pos, target, Vector3.UP if absf((target - pos).normalized().y) < 0.99 else Vector3.FORWARD)
	l.light_energy = energy
	l.light_color = col
	l.spot_angle = angle
	l.spot_range = rng
	l.spot_angle_attenuation = 0.8
	l.shadow_enabled = shadows and not low
	return l


func omni(pos: Vector3, energy: float, rng: float, col := Color(1, 0.88, 0.72), shadows := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	world.add_child(l)
	l.global_position = pos
	l.light_energy = energy
	l.omni_range = rng
	l.light_color = col
	l.shadow_enabled = shadows and not low
	return l
