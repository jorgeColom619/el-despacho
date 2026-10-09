extends Control
## Escenario 3D de un minijuego (sala de prensa, plató, salón de negociaciones, hemiciclo del Congreso). Se pinta en
## su propio SubViewport a la resolución de la ventana y con la calidad gráfica del despacho; mientras está abierto, el
## despacho 3D deja de dibujarse. Las subclases montan la sala en build().
## No hay ventanas ni monitores con las opciones: se eligen cosas de la propia escena con el ratón (tarjetas sobre el
## atril o la mesa, periodistas que alzan la mano, objetos de la mesa de negociación) y la interfaz se queda en
## subtítulos, una cita arriba, una pista junto al ratón, golpes de efecto (¡ZASCA!) y un rótulo final pequeño.

const Kit := preload("res://scripts/office3d/kit.gd")
const Tex := preload("res://scripts/office3d/tex3d.gd")
const Visitor3D := preload("res://scripts/office3d/visitor_3d.gd")
const Flags := preload("res://scripts/ui/flags.gd")
const Typewriter := preload("res://scripts/ui/typewriter.gd")
const Card3D := preload("res://scripts/stages3d/card_3d.gd")
const BANNER_SHADER := preload("res://shaders/banner3d.gdshader")
const GLOW_SHADER := preload("res://shaders/glow3d.gdshader")

## Se han dicho todas las frases de la cola de subtítulos
signal lines_done

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
## Campo de visión al que va la cámara poco a poco (0: no se toca; los planos que lo cambian de golpe usan cam.fov)
var fov_target := 0.0
## Mirada libre (grados en horizontal y vertical): la cámara se gira un poco hacia donde está el ratón
var look_range := Vector2.ZERO
## Ojos del presidente (las tarjetas se orientan hacia aquí)
var eye := Vector3(0, 1.6, 0)
## Oscurecido arriba y abajo de la pantalla para que se lean los subtítulos
var shade_top := 0.4
var shade_bottom := 0.55
## Subtítulos arriba en vez de abajo (en la mesa de negociación, abajo está el tratado)
var sub_top := false
## Capa 2D por encima de la escena (subtítulos, cita, pista, avisos, golpes de efecto, rótulo final)
var hud: Control
## Cuenta atrás del minijuego (un TimerBar oculto): la luz del atril la sigue
var timer_src: Control
## Tarjetas repartidas ahora (card_3d.gd)
var cards: Array = []
var _cam_look_now := Vector3.ZERO
var _t := 0.0
var _look := Vector2.ZERO
var _shake := 0.0
var _flashes: Array = []
var _flag_texs := {}
var _office_world: Node3D
var _shot_path := ""
var _shot_wait := 0
var _shot_frames: Array = []
var _sheet: Array = []
## Pantallas 3D con interfaz (screen()): {"vp", "mi", "size", "w", "h", "input", "tip"}
var _screens: Array = []
var _drag_screen = null
var _hover_screen = null
## Objetos que se señalan y se pulsan (add_pick)
var _picks: Array = []
var _hover: Pick = null
var _drag: Pick = null
var _sub: VBoxContainer
var _sub_who: Label
var _sub_line: RichTextLabel
var _cap: VBoxContainer
var _cap_who: Label
var _cap_line: Label
var _notice: Label
var _title: VBoxContainer
var _tip: PanelContainer
var _tip_lbl: Label
var _lines: Array = []
var _line := {}
var _line_left := -1.0
var _sub_tw: Tween
var _cap_tw: Tween
var _title_tw: Tween
var _strip: MeshInstance3D
var _strip_mat: StandardMaterial3D
var _strip_lbl: Label3D
var _strip_xf := Transform3D()
var _strip_w := 0.5
## Pruebas: clics simulados [x, y, fotograma] (en píxeles de la ventana), teclas [número, fotograma] y un ratón fijo
var _test_clicks: Array = []
var _test_keys: Array = []
var _test_mouse := Vector2(-1, -1)
var _frame := 0


## Objeto de la escena que se puede señalar y pulsar con el ratón
class Pick:
	extends RefCounted
	var node: Node3D
	## Caja en el espacio local de node; si r > 0, esfera de radio r en node.global_transform * off
	var box := AABB()
	var r := 0.0
	var off := Vector3.ZERO
	## Prueba propia (from, dir) -> distancia o INF (las tarjetas cuentan su sitio y donde están ahora)
	var hit_fn := Callable()
	## Lo que hace, junto al ratón
	var tip := ""
	var on_click := Callable()
	## Arrastre: se llama con (from, dir, "press" / "move" / "release")
	var on_drag := Callable()
	## Al señalarla (true) o dejar de hacerlo (false)
	var on_hover := Callable()
	var enabled := true
	## Tecla numérica (1-9) que la pulsa
	var key := 0
	var meshes: Array = []
	var glow: ShaderMaterial


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
	# recibe el ratón para llevarlo a los objetos de la escena
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
	resized.connect(_resize)
	world = Node3D.new()
	vp.add_child(world)
	cam = Camera3D.new()
	cam.near = 0.03
	cam.far = 250.0
	world.add_child(cam)
	cam.make_current()
	_environment()
	# la interfaz ya existe mientras se monta la sala (y luego se pone por encima del oscurecido)
	_build_hud()
	build()
	_shade()
	move_child(hud, get_child_count() - 1)
	cam.global_position = cam_pos
	if fov_target > 0.0:
		cam.fov = fov_target
	_cam_look_now = cam_look
	cam.look_at(cam_look)
	_show_office(false)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stageshot="):
			_shot_path = a.substr(12)
			_shot_wait = 90
		elif a.begins_with("--stagewait="):
			_shot_wait = int(a.substr(12))
		elif a.begins_with("--stageframes="):
			# varias capturas en una sola partida, juntas en una hoja (a la mitad de tamaño, en dos columnas)
			for f in a.substr(14).split(","):
				_shot_frames.append(int(f))
		elif a.begins_with("--stageclick="):
			# se puede repetir: --stageclick=x,y,fotograma
			_test_clicks.append(Array(a.substr(13).split_floats(",")))
		elif a.begins_with("--stagekey="):
			_test_keys.append(Array(a.substr(11).split_floats(",")))
		elif a.begins_with("--stagemouse="):
			var m := a.substr(13).split_floats(",")
			_test_mouse = Vector2(m[0], m[1])


func _exit_tree() -> void:
	_show_office(true)
	if is_instance_valid(_hover) and _hover.on_hover.is_valid():
		_hover.on_hover.call(false)


## Lo que monta cada sala
func build() -> void:
	pass


func _shade() -> void:
	var shade := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	var ink := Color(0.01, 0.015, 0.03)
	gr.offsets = PackedFloat32Array([0.0, 0.26, 0.74, 1.0])
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


## La escena se pinta a los píxeles que ocupa de verdad en la pantalla (sin contar las franjas negras de una
## pantalla que no sea 16:9: si no, se veía estirada)
func _resize() -> void:
	var s := Vector2(get_tree().root.size)
	var shown := size * get_viewport().get_final_transform().get_scale()
	if shown.x >= 64.0 and shown.y >= 36.0:
		s = shown
	vp.size = Vector2i(maxi(int(s.x), 64), maxi(int(s.y), 36))


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
	_frame += 1
	var k := minf(1.0, delta * cam_speed)
	var p := cam_pos
	if sway > 0.0:
		p += Vector3(sin(_t * 0.37) * 0.6, sin(_t * 0.53 + 1.0) * 0.35, 0.0) * sway
	cam.global_position = cam.global_position.lerp(p, k)
	_cam_look_now = _cam_look_now.lerp(cam_look, k)
	if fov_target > 0.0:
		cam.fov = lerpf(cam.fov, fov_target, k)
	if not cam.global_position.is_equal_approx(_cam_look_now):
		cam.look_at(_cam_look_now)
	# mirada libre hacia el ratón y temblor de los golpes de efecto
	var want := Vector2.ZERO
	var mp := _mouse_pos()
	if look_range != Vector2.ZERO and mp.x >= 0.0 and _drag == null and _drag_screen == null:
		var m := ((mp / size) - Vector2(0.5, 0.5)) * 2.0
		m = m.clamp(-Vector2.ONE, Vector2.ONE)
		want = Vector2(-m.x * look_range.x, -m.y * look_range.y)
	_look = _look.lerp(want, minf(1.0, delta * 2.2))
	if _look.length_squared() > 0.0001:
		cam.rotate_object_local(Vector3.UP, deg_to_rad(_look.x))
		cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(_look.y))
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, delta * 1.8)
		cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(randf_range(-1.0, 1.0) * _shake * 1.6))
		cam.rotate_object_local(Vector3.UP, deg_to_rad(randf_range(-1.0, 1.0) * _shake * 1.6))
	_update_flashes(delta)
	# lo que hay bajo el ratón (también si se mueve la cámara o la tarjeta sin mover el ratón)
	if mp.x >= 0.0 and _drag == null:
		_hover_at(mp)
	elif mp.x < 0.0:
		_set_hover(null)
	_update_strip()
	_update_lines(delta)
	if _tip.visible and mp.x >= 0.0:
		_tip.reset_size()
		_tip.position = (mp + Vector2(26, -_tip.size.y - 18)).clamp(Vector2(10, 10), Vector2(1910, 1070) - _tip.size)
	_test_input()
	if _shot_path != "":
		if _frame in _shot_frames:
			var img := get_viewport().get_texture().get_image()
			# todas a la mitad de tamaño, en una hoja de dos columnas
			img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
			_sheet.append(img)
			print("captura %d · %.2f s" % [_frame, _t])
			if _frame >= _shot_frames.max():
				var w := img.get_width()
				var h := img.get_height()
				var rows := int(ceil(_sheet.size() / 2.0))
				var out := Image.create(w * mini(2, _sheet.size()), h * rows, false, img.get_format())
				for i in _sheet.size():
					out.blit_rect(_sheet[i], Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
				out.save_png(_shot_path)
				get_tree().quit()
			return
		_shot_wait -= 1
		if _shot_wait == 0 and _shot_frames.is_empty():
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()


## Ratón sobre la escena, en coordenadas del escenario (1920 × 1080); (-1, -1) si está fuera o encima de un botón
func _mouse_pos() -> Vector2:
	if _test_mouse.x >= 0.0:
		return _test_mouse * size / Vector2(DisplayServer.window_get_size())
	if _shot_path != "" or DisplayServer.get_name() == "headless" or not get_window().has_focus():
		return Vector2(-1, -1)
	var vpt := get_viewport()
	if vpt.has_method("gui_get_hovered_control") and vpt.gui_get_hovered_control() != self:
		return Vector2(-1, -1)
	var mp := get_local_mouse_position()
	if mp.x < 0.0 or mp.y < 0.0 or mp.x > size.x or mp.y > size.y:
		return Vector2(-1, -1)
	return mp


func _test_input() -> void:
	for c in _test_clicks:
		if c.size() >= 3 and _frame == int(c[2]):
			# las coordenadas de la prueba van en píxeles de la ventana (los de la captura)
			var at := Vector2(c[0], c[1]) * size / Vector2(DisplayServer.window_get_size())
			var mv := InputEventMouseMotion.new()
			mv.position = at
			_hover_at(at)
			_mouse(mv)
			for pressed in [true, false]:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = pressed
				ev.position = at
				_mouse(ev)
	for kk in _test_keys:
		if kk.size() >= 2 and _frame == int(kk[1]):
			_press_key(int(kk[0]))


# ------------------------------------------------------------------ interfaz mínima

func _outline(c: Control, px := 10) -> void:
	c.add_theme_constant_override("outline_size", px)
	c.add_theme_color_override("font_outline_color", Color(0.01, 0.012, 0.02, 0.85))


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = UI.theme
	add_child(hud)
	# subtítulos: abajo, crecen hacia arriba
	_sub = UI.vbox(2)
	_sub.anchor_left = 0.5
	_sub.anchor_right = 0.5
	_sub.anchor_top = 0.0 if sub_top else 1.0
	_sub.anchor_bottom = 0.0 if sub_top else 1.0
	_sub.offset_left = -760.0
	_sub.offset_right = 760.0
	_sub.offset_top = 36.0 if sub_top else -74.0
	_sub.offset_bottom = 36.0 if sub_top else -74.0
	_sub.grow_vertical = Control.GROW_DIRECTION_END if sub_top else Control.GROW_DIRECTION_BEGIN
	_sub.modulate.a = 0.0
	hud.add_child(_sub)
	_sub_who = UI.lbl("", UI.f_sans_b, 21, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_outline(_sub_who, 8)
	_sub.add_child(_sub_who)
	_sub_line = Typewriter.new()
	_sub_line.custom_minimum_size = Vector2(1520, 0)
	_sub_line.add_theme_font_override("normal_font", UI.f_serif)
	_sub_line.add_theme_font_size_override("normal_font_size", 36)
	_sub_line.add_theme_color_override("default_color", UI.CREAM)
	_outline(_sub_line, 12)
	_sub_line.typed.connect(_on_typed)
	_sub.add_child(_sub_line)
	_sub_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# cita de arriba: la pregunta a la que se está respondiendo
	_cap = UI.vbox(2)
	_cap.position = Vector2(180, 40)
	_cap.size = Vector2(1560, 0)
	_cap.modulate.a = 0.0
	hud.add_child(_cap)
	_cap_who = UI.lbl("", UI.f_sans_b, 19, UI.RED, HORIZONTAL_ALIGNMENT_CENTER)
	_outline(_cap_who, 8)
	_cap.add_child(_cap_who)
	_cap_line = UI.lbl("", UI.f_serif, 31, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_cap_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cap_line.custom_minimum_size = Vector2(1560, 0)
	_outline(_cap_line, 11)
	_cap.add_child(_cap_line)
	# aviso de una línea, abajo del todo (qué hay que hacer ahora)
	_notice = UI.lbl("", UI.f_sans_m, 21, UI.GOLD_L, HORIZONTAL_ALIGNMENT_CENTER)
	_notice.position = Vector2(0, 1080 - 46)
	_notice.size = Vector2(1920, 32)
	_outline(_notice, 8)
	hud.add_child(_notice)
	# rótulo de la escena (arriba, se va solo)
	_title = UI.vbox(0)
	_title.position = Vector2(0, 92)
	_title.size = Vector2(1920, 0)
	_title.modulate.a = 0.0
	hud.add_child(_title)
	# pista junto al ratón
	_tip = PanelContainer.new()
	_tip.add_theme_stylebox_override("panel", UI.sb(Color(0.03, 0.045, 0.08, 0.92), 8, Color(UI.GOLD, 0.6), 1, 8, 12))
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	hud.add_child(_tip)
	_tip_lbl = UI.lbl("", UI.f_sans_m, 19, UI.TEXT)
	_tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_lbl.custom_minimum_size = Vector2(430, 0)
	_tip.add_child(_tip_lbl)


## Frase de un personaje en subtítulos (se ponen en cola). speaker: el personaje 3D que mueve la boca mientras tanto
## quick: la frase va a quedarse escrita en otro sitio (la pregunta, arriba): no hace falta esperar a que se lea
func say(who: String, text: String, col := UI.GOLD, speaker: Node3D = null, hold := 1.0, quick := false) -> void:
	_lines.append({"who": who, "text": text, "col": col, "speaker": speaker, "hold": hold, "quick": quick})
	if _line.is_empty():
		_next_line()


## ¿Hay alguien hablando (o frases esperando)?
func speaking() -> bool:
	return not _line.is_empty() or not _lines.is_empty()


## Llama a f cuando se hayan dicho todas las frases (o enseguida, si no habla nadie)
func after_lines(f: Callable) -> void:
	if not speaking():
		f.call_deferred()
	elif not lines_done.is_connected(f):
		lines_done.connect(f, CONNECT_ONE_SHOT)


## Clic durante una frase: la completa; si ya estaba completa, pasa a la siguiente
func skip_line() -> void:
	if _line.is_empty():
		return
	if _sub_line.is_running():
		_sub_line.skip()
	else:
		_line_left = 0.0


func clear_lines() -> void:
	_lines.clear()
	_end_line()
	_line = {}
	if _sub_tw != null:
		_sub_tw.kill()
	_sub.modulate.a = 0.0


func _next_line() -> void:
	_end_line()
	if _sub_tw != null:
		_sub_tw.kill()
	if _lines.is_empty():
		_line = {}
		_sub_tw = UI.fade(_sub, 0.0, 0.25)
		lines_done.emit()
		return
	_line = _lines.pop_front()
	_sub_who.text = String(_line["who"]).to_upper()
	_sub_who.add_theme_color_override("font_color", _line["col"])
	_sub_who.visible = _sub_who.text != ""
	# sin nombre es el narrador: va sin comillas
	_sub_line.play("[center]%s[/center]" % (("«%s»" % _line["text"]) if _sub_who.text != "" else String(_line["text"])), 46.0)
	_line_left = -1.0
	_sub.modulate.a = 1.0
	var sp = _line.get("speaker")
	if is_instance_valid(sp):
		sp.talking = true


func _on_typed() -> void:
	if _line.is_empty():
		return
	var sp = _line.get("speaker")
	if is_instance_valid(sp):
		sp.talking = false
	_line_left = float(_line["hold"]) + (0.0 if _line.get("quick", false) else String(_line["text"]).length() * 0.016)


func _end_line() -> void:
	if _line.is_empty():
		return
	var sp = _line.get("speaker")
	if is_instance_valid(sp):
		sp.talking = false


func _update_lines(delta: float) -> void:
	if _line.is_empty() or _line_left < 0.0:
		return
	_line_left -= delta
	if _line_left <= 0.0:
		_next_line()


## Cita fija arriba (la pregunta que hay que contestar); "" la quita
func caption(who: String, text: String, col := UI.RED) -> void:
	if _cap_tw != null:
		_cap_tw.kill()
	if text == "":
		_cap_tw = UI.fade(_cap, 0.0, 0.25)
		return
	_cap_who.text = who.to_upper()
	_cap_who.add_theme_color_override("font_color", col)
	_cap_who.visible = who != ""
	_cap_line.text = "«%s»" % text
	_cap.modulate.a = 0.0
	_cap_tw = UI.fade(_cap, 1.0, 0.25)


## Aviso de una línea abajo del todo ("Elija una tarjeta · 1 2 3"); "" lo quita
func notice(text: String) -> void:
	_notice.text = text


## Rótulo de la escena arriba: antetítulo, título y una línea; se va solo al cabo de dur segundos (0 = se queda)
func title_card(kicker: String, title: String, sub := "", dur := 4.5) -> void:
	for c in _title.get_children():
		c.queue_free()
	var k := UI.lbl(kicker.to_upper(), UI.f_sans_b, 20, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_outline(k, 8)
	_title.add_child(k)
	var t := UI.lbl(title, UI.f_serif_b, 64, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_outline(t, 14)
	_title.add_child(t)
	if sub != "":
		var s := UI.lbl(sub, UI.f_sans_m, 22, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.custom_minimum_size = Vector2(1200, 0)
		_outline(s, 8)
		var row := CenterContainer.new()
		row.custom_minimum_size = Vector2(1920, 0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(s)
		_title.add_child(row)
	_title.modulate.a = 0.0
	if _title_tw != null:
		_title_tw.kill()
	var tw := _title.create_tween()
	_title_tw = tw
	tw.tween_property(_title, "modulate:a", 1.0, 0.5)
	if dur > 0.0:
		tw.tween_interval(dur)
		tw.tween_property(_title, "modulate:a", 0.0, 0.6)


func hide_title() -> void:
	if _title_tw != null:
		_title_tw.kill()
	_title_tw = UI.fade(_title, 0.0, 0.3)


## Golpe de efecto en grande (¡ZASCA!, COMBO x3, ¡ABUCHEOS!): aparece de golpe, se queda un momento y se va
func big_text(text: String, col: Color, font_size := 130, at := Vector2(960, 380), dur := 1.1) -> void:
	var l := UI.lbl(text, UI.f_cond_b, font_size, col, HORIZONTAL_ALIGNMENT_CENTER)
	_outline(l, int(font_size * 0.17))
	hud.add_child(l)
	l.size = Vector2(1600, font_size * 1.5)
	l.position = at - l.size * 0.5
	l.pivot_offset = l.size * 0.5
	l.rotation = deg_to_rad(randf_range(-5.0, 5.0))
	l.scale = Vector2(0.3, 0.3)
	l.modulate.a = 0.0
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "modulate:a", 1.0, 0.1)
	t.tween_property(l, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(l, "scale", Vector2.ONE, 0.12)
	t.chain().tween_interval(dur)
	t.chain().tween_property(l, "modulate:a", 0.0, 0.35)
	t.parallel().tween_property(l, "position:y", l.position.y - 40.0, 0.35)
	t.chain().tween_callback(l.queue_free)


## Rótulo final abajo, en el centro y sin tapar la escena: título, una línea, los efectos y un botón
func end_card(title: String, col: Color, line: String, chips: Control, button: String, on_press: Callable) -> PanelContainer:
	var p := UI.panel(Color(0.03, 0.045, 0.08, 0.9), 12, Color(UI.GOLD, 0.55), 22)
	p.custom_minimum_size = Vector2(1040, 0)
	var v := UI.vbox(10)
	p.add_child(v)
	var h := UI.hbox(20)
	var tl := UI.lbl(title, UI.f_cond_b, 44, col)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tl)
	var bt := UI.btn(button, "gold", 20)
	bt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bt.pressed.connect(on_press)
	h.add_child(bt)
	v.add_child(h)
	if line != "":
		v.add_child(UI.lbl(line, UI.f_sans_m, 19, UI.TEXT))
	if chips != null:
		chips.custom_minimum_size = Vector2(990, 0)
		v.add_child(chips)
	hud.add_child(p)
	# abajo y centrado (también cuando los efectos ocupan más de una línea y el rótulo crece)
	var place := func():
		p.position = Vector2((1920.0 - p.size.x) * 0.5, 1080.0 - p.size.y - 34.0)
		p.pivot_offset = p.size * 0.5
	p.resized.connect(place)
	p.reset_size()
	place.call()
	UI.pop_in(p)
	notice("")
	return p


## Temblor de cámara (golpes de efecto); a = 0..1
func shake(a: float) -> void:
	_shake = maxf(_shake, a)


# ------------------------------------------------------------------ objetos que se pulsan

## Objeto que se señala con el ratón: caja `box` en el espacio local de `node`. meshes: lo que brilla al señalarlo
func add_pick(node: Node3D, box: AABB, tip: String, on_click: Callable, meshes: Array = []) -> Pick:
	var pk := Pick.new()
	pk.node = node
	pk.box = box
	pk.tip = tip
	pk.on_click = on_click
	pk.meshes = meshes if not meshes.is_empty() else node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D and pk.meshes.is_empty():
		pk.meshes = [node]
	_picks.append(pk)
	return pk


## Igual, pero una esfera de radio r alrededor de node (personas: off es el pecho o la cabeza)
func add_pick_sphere(node: Node3D, r: float, off: Vector3, tip: String, on_click: Callable) -> Pick:
	var pk := add_pick(node, AABB(), tip, on_click)
	pk.r = r
	pk.off = off
	return pk


func remove_pick(pk: Pick) -> void:
	if pk == null:
		return
	if pk == _hover:
		_set_hover(null)
	_set_glow(pk, false)
	_picks.erase(pk)


func clear_picks() -> void:
	for pk in _picks.duplicate():
		remove_pick(pk)


func _ray(p: Vector2) -> Array:
	var vpp := p * Vector2(vp.size) / size
	return [cam.project_ray_origin(vpp), cam.project_ray_normal(vpp)]


func _hit(pk: Pick, from: Vector3, dir: Vector3) -> float:
	if not pk.enabled or not is_instance_valid(pk.node) or not pk.node.is_visible_in_tree():
		return INF
	if pk.hit_fn.is_valid():
		return float(pk.hit_fn.call(from, dir))
	if pk.r > 0.0:
		var c := pk.node.global_transform * pk.off
		var t := (c - from).dot(dir)
		if t <= 0.0 or (from + dir * t).distance_to(c) > pk.r:
			return INF
		return t
	return Card3D._hit_box(pk.node.global_transform, pk.box, from, dir)


func _pick_hit(from: Vector3, dir: Vector3) -> Array:
	var best: Pick = null
	var best_t := INF
	for pk in _picks:
		var t := _hit(pk, from, dir)
		if t < best_t:
			best_t = t
			best = pk
	return [best, best_t]


func _hover_at(p: Vector2) -> void:
	var ray := _ray(p)
	var ph := _pick_hit(ray[0], ray[1])
	var sh := _screen_hit(ray[0], ray[1])
	if not sh.is_empty() and float(sh["t"]) < float(ph[1]):
		_set_hover(null)
		_tip_text(String(sh["s"].get("tip", "")))
		return
	_set_hover(ph[0])
	if ph[0] == null:
		# (también quita la pista de una pantalla de la que se acaba de salir)
		_tip_text("")


func _set_hover(pk: Pick) -> void:
	if pk == _hover:
		return
	if _hover != null:
		_set_glow(_hover, false)
		if _hover.on_hover.is_valid():
			_hover.on_hover.call(false)
	_hover = pk
	if pk != null:
		_set_glow(pk, true)
		if pk.on_hover.is_valid():
			pk.on_hover.call(true)
		Sfx.play("hover", -12.0)
	_tip_text(pk.tip if pk != null else "")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if pk != null else Control.CURSOR_ARROW


func _tip_text(t: String) -> void:
	_tip_lbl.text = t
	_tip.visible = t != ""


func _set_glow(pk: Pick, on: bool) -> void:
	if pk.glow == null:
		pk.glow = ShaderMaterial.new()
		pk.glow.shader = GLOW_SHADER
		pk.glow.set_shader_parameter("glow_color", Color(1.0, 0.86, 0.52))
		pk.glow.set_shader_parameter("amount", 0.7)
	for m in pk.meshes:
		if is_instance_valid(m):
			(m as GeometryInstance3D).material_overlay = pk.glow if on else null


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var n: int = event.keycode - KEY_0
	if n < 1 or n > 9:
		n = event.keycode - KEY_KP_0
	if n >= 1 and n <= 9 and _press_key(n):
		get_viewport().set_input_as_handled()


func _press_key(n: int) -> bool:
	for pk in _picks:
		if pk.key == n and pk.enabled and pk.on_click.is_valid():
			Sfx.play("click", -3.0)
			pk.on_click.call()
			return true
	return false


# ------------------------------------------------------------------ tarjetas

## Reparte tarjetas (specs: ver card_3d.gd) en fila sobre una superficie de centro `center` y normal `normal`, de cara a
## los ojos del presidente. on_pick(i) se llama al elegir una (clic o teclas 1, 2, 3...)
func deal_cards(specs: Array, center: Vector3, normal: Vector3, gap: float, on_pick: Callable, card_size := Vector2(0.2, 0.13), delay := 0.0) -> void:
	clear_cards()
	var n := normal.normalized()
	var far := (center - eye) - n * (center - eye).dot(n)
	far = far.normalized()
	var right := far.cross(n)
	var base := Basis(right, n, -far)
	for i in specs.size():
		var spec: Dictionary = specs[i].duplicate()
		# teclas 1, 2, 3... salvo que la tarjeta diga "key": 0
		spec["key"] = 0 if int(spec.get("key", -1)) == 0 else i + 1
		var mid := (specs.size() - 1) * 0.5
		var pos := center + right * (i - mid) * gap - far * absf(i - mid) * 0.012 + n * (0.003 + 0.001 * i)
		var rest := Transform3D(base.rotated(n, deg_to_rad(randf_range(-3.0, 3.0) - (i - mid) * 2.0)), pos)
		var from := Transform3D(base.rotated(n, deg_to_rad(randf_range(-25.0, 25.0))), center - far * 0.3 - n * 0.06 + right * (i - mid) * 0.05)
		var c := Card3D.new()
		world.add_child(c)
		c.setup(spec, rest, eye, from, delay + 0.09 * i, card_size)
		cards.append(c)
		var idx := i
		var pk := add_pick(c, AABB(), "", func(): _pick_card(idx, on_pick))
		pk.hit_fn = c.hit
		pk.on_hover = c.set_hover
		pk.key = int(spec["key"])
		pk.meshes = []
		c.set_meta("pick", pk)


func _pick_card(i: int, on_pick: Callable) -> void:
	if i < 0 or i >= cards.size() or not is_instance_valid(cards[i]) or not (cards[i].state in ["deal", "rest"]):
		return
	Sfx.play("paper2", -6.0)
	for j in cards.size():
		var c = cards[j]
		if not is_instance_valid(c):
			continue
		remove_pick(c.get_meta("pick"))
		if j == i:
			c.pick()
		else:
			c.discard(0.05 * absf(j - i))
	cards.clear()
	on_pick.call(i)


## Tarjeta suelta que no se elige (la chuleta del gabinete): reposa en pos y se levanta hacia los ojos al señalarla
func note_card(spec: Dictionary, pos: Vector3, normal: Vector3, card_size: Vector2, angle_deg := 0.0) -> Node3D:
	var n := normal.normalized()
	var far := ((pos - eye) - n * (pos - eye).dot(n)).normalized()
	var base := Basis(far.cross(n), n, -far).rotated(n, deg_to_rad(angle_deg))
	var sp := spec.duplicate()
	sp["key"] = 0
	var xf := Transform3D(base, pos + n * 0.004)
	var c := Card3D.new()
	world.add_child(c)
	c.setup(sp, xf, eye, xf, 0.0, card_size)
	var pk := add_pick(c, AABB(), "", Callable())
	pk.hit_fn = c.hit
	pk.on_hover = c.set_hover
	pk.meshes = []
	return c


## Quita las tarjetas que haya (se retiran deslizándose)
func clear_cards(animate := true) -> void:
	for c in cards:
		if is_instance_valid(c):
			remove_pick(c.get_meta("pick"))
			if animate:
				c.discard()
			else:
				c.queue_free()
	cards.clear()


## Se acabó el tiempo: las tarjetas se apagan y ya no se pueden elegir
func dim_cards() -> void:
	for c in cards:
		if is_instance_valid(c):
			var pk: Pick = c.get_meta("pick")
			if pk != null:
				pk.enabled = false
			c.dim()


# ------------------------------------------------------------------ tiempo de palabra

## Luz del tiempo en el borde del atril o de la mesa (xf: centro, mirando a los ojos con +Z): una tira que se acorta,
## dorada, ámbar y roja, con los segundos al lado
func time_strip(xf: Transform3D, width: float) -> void:
	_strip_xf = xf
	_strip_w = width
	# lote propio: no se mezcla con la geometría de la sala que aún no se haya montado
	var bb := Kit.Batch.new()
	bb.box(xf * Transform3D(Basis(), Vector3(0, 0, -0.006)), Vector3(width + 0.03, 0.03, 0.012), Kit.mat(Color("0c0d10"), 0.4, 0.2), 1.0, 0.004)
	bb.commit(world, false)
	_strip = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, 0.012)
	_strip.mesh = q
	_strip_mat = StandardMaterial3D.new()
	_strip_mat.albedo_color = Color.BLACK
	# luz propia fuerte: con el resplandor de la sala parece una tira de LED encendida
	_strip_mat.emission_enabled = true
	_strip_mat.emission = UI.GOLD_L
	_strip_mat.emission_energy_multiplier = 2.6
	_strip.material_override = _strip_mat
	_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(_strip)
	_strip.global_transform = xf
	_strip_lbl = Label3D.new()
	_strip_lbl.font = UI.f_cond_b
	_strip_lbl.font_size = 64
	_strip_lbl.pixel_size = 0.0004
	_strip_lbl.outline_size = 0
	_strip_lbl.shaded = false
	_strip_lbl.double_sided = false
	_strip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	world.add_child(_strip_lbl)
	_strip_lbl.global_transform = xf * Transform3D(Basis(), Vector3(width * 0.5 + 0.03, 0.0, 0.002))
	_strip.visible = false
	_strip_lbl.visible = false


func _update_strip() -> void:
	if _strip == null:
		return
	var on: bool = is_instance_valid(timer_src) and timer_src.running
	_strip.visible = on
	_strip_lbl.visible = on
	if not on:
		return
	var f := clampf(float(timer_src.left) / maxf(0.01, float(timer_src.total)), 0.0, 1.0)
	var col := UI.GOLD_L
	if f < 0.25:
		col = UI.RED if int(Time.get_ticks_msec() / 150) % 2 == 0 else UI.RED.lightened(0.35)
	elif f < 0.5:
		col = UI.AMBER
	_strip_mat.emission = col
	_strip.global_transform =_strip_xf * Transform3D(Basis.from_scale(Vector3(maxf(f, 0.002), 1, 1)), Vector3(-_strip_w * 0.5 * (1.0 - f), 0, 0.001))
	_strip_lbl.text = "%d" % int(ceil(float(timer_src.left)))
	_strip_lbl.modulate = col


# ------------------------------------------------------------------ pantallas con interfaz

## Pantalla 3D con interfaz: el minijuego pone sus controles en el Control que devuelve (de `size` píxeles virtuales) y
## se ve en un rectángulo de `width` metros con la transformación xf (la cara mira a +Z). Con input, se usa con el
## ratón como cualquier interfaz (el papel del tratado); sin él solo se mira (marcadores, televisores). tip: la pista
## que sale junto al ratón al pasar por encima
func screen(size: Vector2i, xf: Transform3D, width: float, bg := Color(0.02, 0.03, 0.06), energy := 1.0, res := 1.25, input := false, tip := "", shaded := false) -> Control:
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
	if shaded:
		# papel: le da la luz de la sala, con un poco de luz propia para que se lea
		m.roughness = 0.9
		m.emission_enabled = true
		m.emission_texture = sv.get_texture()
		m.emission_energy_multiplier = energy
	else:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(energy, energy, energy)
	m.albedo_texture = sv.get_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_transform = xf
	_screens.append({"vp": sv, "mi": mi, "size": Vector2(size), "w": width, "h": h, "input": input, "tip": tip})
	return ui


## La malla de una pantalla creada con screen() (para moverla)
func screen_mesh(ui: Control) -> MeshInstance3D:
	for s in _screens:
		if (s["vp"] as SubViewport) == ui.get_parent():
			return s["mi"]
	return null


## Transformación para una pantalla en p que mira hacia el punto eye (sin girar sobre sí misma)
static func facing(p: Vector3, eye_pos: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(p - eye_pos, Vector3.UP), p)


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
	if fov_target > 0.0:
		cam.fov = fov_target


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse and _mouse(event):
		accept_event()


## Ratón sobre la escena: a la pantalla con interfaz o al objeto que estén debajo (el más cercano); si no hay ninguno,
## un clic completa la frase que se está diciendo o va a la propia escena
func _mouse(event: InputEventMouse) -> bool:
	if size.x <= 0.0:
		return false
	var ray := _ray(event.position)
	var from: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	if _drag != null:
		if event is InputEventMouseMotion:
			_drag.on_drag.call(from, dir, "move")
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_drag.on_drag.call(from, dir, "release")
			_drag = null
		return true
	var ph := _pick_hit(from, dir)
	var sh := _screen_hit(from, dir)
	if _drag_screen != null or (not sh.is_empty() and float(sh["t"]) < float(ph[1])):
		_set_hover(null)
		return _forward(event, sh)
	_leave_screen()
	if event is InputEventMouseMotion:
		_set_hover(ph[0])
		return _hover != null
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_hover(ph[0])
		if _hover != null:
			if _hover.on_drag.is_valid():
				_drag = _hover
				_drag.on_drag.call(from, dir, "press")
			elif _hover.on_click.is_valid():
				Sfx.play("click", -3.0)
				_hover.on_click.call()
			return true
		if speaking():
			skip_line()
			return true
		return _click_world(from, dir)
	return false


## Clic en la escena fuera de los objetos: cada sala decide qué hacer
func _click_world(_from: Vector3, _dir: Vector3) -> bool:
	return false


## Pantalla con interfaz que hay bajo el rayo: {"s", "t", "uv"} o {} si no hay ninguna
func _screen_hit(from: Vector3, dir: Vector3) -> Dictionary:
	var best := {}
	var best_t := INF
	for s in _screens:
		if not s["input"]:
			continue
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
			best = {"s": s, "t": t, "uv": uv.clamp(Vector2.ZERO, Vector2.ONE)}
			best_t = t
	return best


## Lleva un evento del ratón a la pantalla 3D que hay bajo el cursor. Devuelve true si cae en una
func _forward(event: InputEventMouse, sh: Dictionary) -> bool:
	var best = sh.get("s") if not sh.is_empty() else null
	if _drag_screen != null and best != _drag_screen:
		best = null
	if best != _hover_screen:
		_leave_screen()
	_hover_screen = best
	if best == null:
		if _drag_screen != null and event is InputEventMouseButton and not event.pressed:
			_drag_screen = null
		return false
	_tip_text(String(best.get("tip", "")))
	var ev := event.duplicate() as InputEventMouse
	ev.position = (sh["uv"] as Vector2) * Vector2(best["size"])
	ev.global_position = ev.position
	(best["vp"] as SubViewport).push_input(ev, true)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_screen = best if event.pressed else null
	return true


## Al salir de una pantalla, el ratón se va "lejos" para que se apague el resaltado de sus controles
func _leave_screen() -> void:
	if _hover_screen == null:
		return
	var away := InputEventMouseMotion.new()
	away.position = Vector2(-100, -100)
	away.global_position = away.position
	(_hover_screen["vp"] as SubViewport).push_input(away, true)
	_hover_screen = null
	if _hover == null:
		_tip_text("")


# ------------------------------------------------------------------ personas

## Personaje con el aspecto `look`, mirando hacia yaw (radianes; 0 = hacia +Z).
## mode: "sit" (silla), "table" (en la mesa) o "" (de pie). every: en reposo, la animación avanza cada `every` fotogramas
## (los del fondo de la sala; ver visitor_3d.gd)
func person(look: Dictionary, pos: Vector3, yaw: float, mode := "", shadows := true, every := 1) -> Node3D:
	var v := Visitor3D.new()
	world.add_child(v)
	v.set_meta("g", look.get("g", "m"))
	v.dress(look)
	v.seat(mode)
	v.show_at(pos)
	v.rotation.y = yaw
	v.desync()
	v.anim_every = every
	if not shadows or low:
		for mi in v.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return v


## Gesto de un personaje (point, laugh, sit_cheer, sit_table_nod...) durante dur segundos (0 = hasta que se quite);
## al acabar vuelve a su postura, salvo que mientras tanto le hayan puesto otro
func gesture(v: Node3D, g: String, dur := 0.0) -> void:
	if not is_instance_valid(v):
		return
	v.gesture = g
	if dur > 0.0:
		# la espera va con el propio personaje: si se cierra la sala antes, desaparece con él
		var t := v.create_tween()
		t.tween_interval(dur)
		t.tween_callback(func():
			if v.gesture == g:
				v.gesture = "")


## Acreditación flotante (siempre de cara a la cámara): una placa del color `col` con un título y una línea debajo
func tag3d(title: String, sub: String, col: Color, pos: Vector3, width := 0.62) -> Sprite3D:
	var px := Vector2i(560, 150 if sub != "" else 96)
	var sv := SubViewport.new()
	sv.size = px
	sv.transparent_bg = true
	sv.disable_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sv)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sb(Color(col.darkened(0.35), 0.92), 18, col.lightened(0.25), 4, 0, 14))
	p.size = Vector2(px)
	sv.add_child(p)
	var v := UI.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	v.add_child(UI.lbl(title, UI.f_sans_b, 40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	if sub != "":
		v.add_child(UI.lbl(sub, UI.f_sans_m, 28, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
	var s := Sprite3D.new()
	s.texture = sv.get_texture()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.pixel_size = width / float(px.x)
	s.shaded = false
	s.no_depth_test = true
	s.render_priority = 10
	world.add_child(s)
	s.global_position = pos
	s.set_meta("vp", sv)
	return s


## Quita una acreditación de tag3d() (con su SubViewport)
func untag(s: Node3D) -> void:
	if not is_instance_valid(s):
		return
	var sv = s.get_meta("vp", null)
	if is_instance_valid(sv):
		sv.queue_free()
	s.queue_free()


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
