extends Control
## El despacho presidencial en 3D: centro del juego en primera persona, con objetos físicos.
## Mantiene la interfaz del despacho 2D (request, objs, hud, visitor, window_view, light,
## enter_visitor/exit_visitor, _refresh) para que pantallas y minijuegos no noten el cambio.

signal request(kind: String, data: Dictionary)

const Kit := preload("res://scripts/office3d/kit.gd")
const Tex := preload("res://scripts/office3d/tex3d.gd")
const Room := preload("res://scripts/office3d/room_3d.gd")
const Interactable := preload("res://scripts/office3d/interactable.gd")
const Player := preload("res://scripts/office3d/player.gd")
const Visitor3D := preload("res://scripts/office3d/visitor_3d.gd")
const PaperView := preload("res://scripts/office3d/paper_views.gd")
const Exterior := preload("res://scripts/office3d/exterior_3d.gd")
const Aquarium := preload("res://scripts/office3d/aquarium_3d.gd")
const Parrot3D := preload("res://scripts/office3d/parrot_3d.gd")
const Cat3D := preload("res://scripts/office3d/cat_3d.gd")
const Dog3D := preload("res://scripts/office3d/dog_3d.gd")
const Fishbowl3D := preload("res://scripts/office3d/fishbowl_3d.gd")
const WindowView := preload("res://scripts/office/window_view.gd")
const TvView := preload("res://scripts/office/tv_view.gd")
const MonitorView := preload("res://scripts/office/monitor_view.gd")
const Hud := preload("res://scripts/office/hud.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const OfficeArt := preload("res://scripts/office/office_art.gd")
const PetArt := preload("res://scripts/office/pet_art.gd")
const W := preload("res://scripts/data/world_data.gd")
const PhoneLock := preload("res://scripts/ui/phone_lock.gd")
const Redes := preload("res://scripts/systems/redes.gd")
const Batch := Kit.Batch

const INTERACT_RANGE := 12.0
## Capa de render exclusiva del doble del jugador en el espejo: invisible para su propia cámara
## en primera persona, visible para la cámara que pinta el reflejo
const AVATAR_LAYER := 1 << 4
const PARROT := ["¡Dimisión! ¡Dimisión!", "¡Viva Valdoria!", "¡Más presupuesto!", "¡Recortes no!", "¡Orden! ¡Orden!", "¡Elecciones ya!", "Rrrr... ¡Corrupción!", "¡Presidente guapo!"]
const PARROT_MEME := ["¡Un vaso es un vaso!", "¡Sé fuerte!", "¡Con cebolla!", "¡Sin cebolla!", "¡Me gusta la fruta!", "¡Plasma! ¡Plasma!", "¡Bueno... eso!", "¡Es muy difícil todo esto!"]
const HELP := "Ratón: mirar   ·   Clic: usar   ·   Clic derecho: coger / soltar (clic para lanzar)   ·   WASD: levantarse y andar (Mayús: correr)\nF: sentarse (sillón, sillones o sofá) / levantarse   ·   R: ordenar la mesa   ·   Tab: liberar el cursor   ·   Espacio: pausa   ·   1-3: velocidad   ·   H: mostrar u ocultar esta ayuda"

## El controlador principal lo consulta para ocultar su fondo 2D
var is_3d := true
var main: Node
var world: Node3D
var room
var player
var visitor3d
## Retrato animado del visitante (lo controla el panel del asesor)
## Cara del visitante (talking / mood / anger), como el retrato del despacho 2D
var visitor
var window_view: Control
var tv: Control
var monitor: Control
var hud: Control
var light: ColorRect
var light_mat: ShaderMaterial
var objs := {}
var tip: PanelContainer
var tip_lbl: Label
var crosshair: Control
var hint: PanelContainer
var env: Environment
var globe_mat: ShaderMaterial
var globe_spin: Node3D
var cursor_mode := false
var pet_kind := ""
var _t := 0.0
var _knock_t := 0.0
var _coffee_cd := 0.0
var _door_open := 0.0
var _last_alert := false
var _pet_cd := 0.0
var _pet_happy := 0.0
var _parrot_line := ""
var _parrot_t := 12.0
var _hover: Node
var _hover_grab: RigidBody3D
var _props := []
var _news_vp: SubViewport
var _news_view: Control
var _cal_vp: SubViewport
var _cal_view: Control
var _diary_vp: SubViewport
var _diary_view: Control
var _diary_seed := 0
## Espejo: cámara que renderiza el reflejo y doble del jugador que aparece en él
var mirror_cam: Camera3D
var mirror_vp: SubViewport
var mirror_avatar
var _tray_sheets := []
var _tray_mark: MeshInstance3D
var _phone_lcd: Label3D
var _mic_led: MeshInstance3D
var _led_on: Material
var _led_off: Material
var _steam: CPUParticles3D
var _mug: RigidBody3D
## El móvil del presidente: pantalla de bloqueo pintada en una textura
var _phone_lock: Control
var _phone_vp: SubViewport
var _lamp_light: SpotLight3D
var _lamp_shade: StandardMaterial3D
var _lamp_on := true
var _globe_boost := 0.0
var _pet_view: Control
var _parrot_lbl: Label3D
var _ui_was_open := false
var _hint_t := 0.0
## Calidad gráfica: "baja", "media", "alta" o "ultra" (ver apply_quality)
var gfx := "media"
## true con el motor avanzado (Forward+): iluminación global, oclusión ambiental, reflejos y niebla volumétrica
var advanced := false
## En calidad baja, las pantallas (ventana, televisor, ordenador) se refrescan menos
var low_quality := false
## Resolución de las pantallas y lienzos 2D proyectados en 3D (1 = la del juego 2D)
var screen_scale := 1.0
var _live_vps := []
var _frame := 0
## Depuración: --pngshot=<ruta> guarda una captura a los pocos fotogramas y cierra el juego
var _pngshot_path := ""
var _pngshot_wait := -1
var _probe: ReflectionProbe
## Ciudad, plaza y clima que se ven por el ventanal
var exterior
var sky_mat: ShaderMaterial
var _flag_mat: Material
var _cloud_shift := 0.0
var _cloud_t := 0.0
## Pecera 3D (si la mascota es la tortuga)
var aquarium
var parrot3d
var cat3d
var dog3d
var fishbowl3d
## Cortinas: objetivo (0 abiertas, 1 cerradas) y posición actual
var _curtain_target := 0.0
var _sky_state := Vector4(-1, -1, -1, -1)
## Asiento que ocupa el presidente ({} de pie). El sillón presidencial es "chair"
var seat_now := {}
var pres_seat := {"pos": Room.SEAT, "yaw": 0.0, "eye": Player.EYE_SIT, "stand": Room.STAND, "key": "chair"}


func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	advanced = RenderingServer.get_current_rendering_method() in ["forward_plus", "mobile"]
	gfx = Sfx.gfx_preset()
	screen_scale = {"baja": 1.0, "media": 1.5, "alta": 2.0, "ultra": 2.0}.get(gfx, 1.5)
	Tex.wait_prewarm()
	world = Node3D.new()
	add_child(world)
	_environment()
	room = Room.new(world)
	room.build()
	_screens()
	_mirror_screen()
	exterior = Exterior.new()
	world.add_child(exterior)
	exterior.build(Vector3(Room.WINDOW.get_center().x, 0.0, Room.Z0), -Room.SUN_DIR.normalized(), _flag_mat)
	_desk_objects()
	_globe()
	_world_map()
	_room_objects()
	_decor_props()
	_pet()
	# jugador y visitante
	player = Player.new()
	player.seat_pos = Room.SEAT
	player.stand_pos = Room.STAND
	player.seat_yaw = 0.0
	player.sens = float(Sfx.settings.get("mouse_sens", 1.0))
	world.add_child(player)
	player.global_position = Room.SEAT
	seat_now = pres_seat
	visitor3d = Visitor3D.new()
	world.add_child(visitor3d)
	visitor3d.cam = player.cam
	visitor = visitor3d
	# doble del jugador que se ve en el espejo: invisible para su propia cámara (capa exclusiva),
	# visible para la cámara del reflejo
	mirror_avatar = Visitor3D.new()
	player.add_child(mirror_avatar)
	mirror_avatar.dress(Perfil.apply_outfit(GS.pres.get("look", {})))
	mirror_avatar.visible = not player.seated
	_set_layer(mirror_avatar, AVATAR_LAYER)
	player.cam.cull_mask &= ~AVATAR_LAYER
	# capa 2D
	light = ColorRect.new()
	UI.full(light)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light_mat = ShaderMaterial.new()
	light_mat.shader = load("res://shaders/vignette.gdshader")
	light.material = light_mat
	add_child(light)
	crosshair = Control.new()
	UI.full(crosshair)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(_draw_crosshair)
	add_child(crosshair)
	hint = PanelContainer.new()
	hint.add_theme_stylebox_override("panel", UI.sb(Color(0.03, 0.05, 0.09, 0.82), 8, Color(UI.GOLD, 0.45), 1, 6, 12))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hl := UI.lbl(HELP, UI.f_sans_m, 15, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	hint.add_child(hl)
	add_child(hint)
	_hint_t = 16.0
	hud = Hud.new()
	add_child(hud)
	hud.menu_pressed.connect(func(): request.emit("pause", {}))
	tip = PanelContainer.new()
	tip.add_theme_stylebox_override("panel", UI.sb(Color(0.03, 0.05, 0.09, 0.9), 6, Color(UI.GOLD, 0.6), 1, 4, 6))
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_lbl = UI.lbl("", UI.f_sans_m, 13, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	tip.add_child(tip_lbl)
	tip.visible = false
	add_child(tip)
	GS.headline.connect(_on_headline_news)
	GS.day_passed.connect(_on_day_redraw)
	GS.queue_changed.connect(_refresh)
	GS.weather_changed.connect(_on_weather)
	window_view.weather = GS.weather
	_refresh()
	apply_quality()
	# depuración (capturas): --cam=x,y,z,giro,inclinación coloca al presidente de pie en ese punto
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cam="):
			var v := a.substr(6).split_floats(",")
			if v.size() >= 5:
				player.seated = false
				player.collision_mask = 1 | 2
				player.global_position = Vector3(v[0], v[1], v[2])
				player.yaw = deg_to_rad(v[3])
				player.pitch = deg_to_rad(v[4])
				player._eye = player.EYE_STAND
			_hint_t = 0.0
		elif a.begins_with("--pngshot="):
			_pngshot_path = a.substr(10)
			_pngshot_wait = 60


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	get_viewport().scaling_3d_scale = 1.0


## Aplica la calidad gráfica elegida en Opciones (se puede cambiar en plena partida)
func apply_quality() -> void:
	gfx = Sfx.gfx_preset()
	low_quality = gfx == "baja"
	var hi := gfx in ["alta", "ultra"]
	var ultra := gfx == "ultra"
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 0.75 if low_quality else 1.0
	vp.msaa_3d = Viewport.MSAA_DISABLED if low_quality else (Viewport.MSAA_2X if gfx == "media" else Viewport.MSAA_4X)
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if low_quality or (advanced and hi) else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_debanding = hi
	vp.positional_shadow_atlas_size = 8192 if ultra else 4096
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH if hi else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH if hi else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	# entorno
	env.glow_enabled = not low_quality
	env.ssao_enabled = advanced and gfx != "baja"
	env.ssil_enabled = advanced and hi
	env.ssr_enabled = advanced and hi
	env.sdfgi_enabled = advanced and hi
	env.volumetric_fog_enabled = advanced and hi
	env.sdfgi_cascades = 6 if ultra else 4
	env.ssr_max_steps = 96 if ultra else 56
	# depuración: --nofx=sdfgi,fog,ssr,ssil,ssao,probe desactiva efectos concretos
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--nofx="):
			var off := a.substr(7).split(",")
			env.sdfgi_enabled = env.sdfgi_enabled and not "sdfgi" in off
			env.volumetric_fog_enabled = env.volumetric_fog_enabled and not "fog" in off
			env.ssr_enabled = env.ssr_enabled and not "ssr" in off
			env.ssil_enabled = env.ssil_enabled and not "ssil" in off
			env.ssao_enabled = env.ssao_enabled and not "ssao" in off
			if "probe" in off and _probe != null:
				_probe.queue_free()
				_probe = null
	# luces y sombras
	room.window_light.shadow_enabled = not low_quality
	_lamp_light.shadow_enabled = not low_quality
	room.chandelier_light.shadow_enabled = advanced and hi
	room.fire_light.shadow_enabled = advanced and hi
	room.window_light.light_volumetric_fog_energy = 1.0
	room.chandelier_light.light_volumetric_fog_energy = 0.3
	room.fire_light.light_volumetric_fog_energy = 0.6
	room.corridor_light.light_volumetric_fog_energy = 0.0
	for l in room.sconce_lights:
		(l as Light3D).visible = not low_quality
		(l as Light3D).shadow_enabled = advanced and ultra
	room.corridor_light.visible = not low_quality
	_steam.visible = not low_quality
	room.dust.visible = not low_quality
	room.embers.visible = not low_quality
	# el haz falso solo hace falta sin niebla volumétrica
	room.beam.visible = not (advanced and hi)
	light.visible = not low_quality
	# sombras de contacto: más suaves si ya hay oclusión ambiental real
	for mt in Kit.shadow_mats:
		var bs: float = mt.get_meta("base_strength", 0.5)
		(mt as StandardMaterial3D).albedo_color.a = bs * (0.55 if env.ssao_enabled else 1.0)
	if _probe != null:
		_probe.visible = advanced and gfx != "baja"
	for v in _live_vps:
		(v as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE if low_quality else SubViewport.UPDATE_ALWAYS


# ------------------------------------------------------------------ montaje

func _environment() -> void:
	env = Environment.new()
	# el cielo de verdad (sol, nubes, estrellas) solo se ve por el ventanal; para los reflejos del interior
	# el shader devuelve los tonos cálidos del despacho
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky3d.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_REALTIME if advanced else Sky.PROCESS_MODE_AUTOMATIC
	env.sky = sky
	# bruma lejana: da profundidad a la ciudad; dentro de la sala apenas se nota
	env.fog_enabled = true
	env.fog_density = 0.002
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	env.fog_light_color = Color(0.66, 0.75, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.52, 0.42)
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES if advanced else Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0 if advanced else 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.02
	# solo brilla lo muy luminoso (sol, llamas, pantallas); los reflejos ya no se convierten en bolas blancas
	env.glow_hdr_threshold = 1.45
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT if not advanced else Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.06
	# efectos del motor avanzado (se activan según la calidad en apply_quality)
	env.ssao_radius = 0.9
	env.ssao_intensity = 2.2
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.25
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = false
	env.sdfgi_energy = 1.1
	env.sdfgi_min_cell_size = 0.08
	env.sdfgi_bounce_feedback = 0.6
	env.volumetric_fog_density = 0.018
	env.volumetric_fog_albedo = Color(1.0, 0.95, 0.88)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 14.0
	env.volumetric_fog_ambient_inject = 0.08
	env.volumetric_fog_temporal_reprojection_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	# sin niebla volumétrica fuera del edificio ni en el pasillo: iluminada por el sol se colaba por el
	# ventanal y velaba la ciudad (solo en el motor avanzado: el compatible no tiene niebla volumétrica)
	if advanced:
		var no_fog := FogVolume.new()
		no_fog.size = Vector3(90.0, 50.0, 46.0)
		no_fog.position = Vector3(0.0, 10.0, Room.Z0 - 0.4 - 23.0)
		var fmt := FogMaterial.new()
		fmt.density = -1.0
		no_fog.material = fmt
		world.add_child(no_fog)
	if advanced:
		# sonda de reflejos de la sala: metales, madera barnizada y suelo reflejan el despacho
		_probe = ReflectionProbe.new()
		_probe.size = Vector3(10.0, 3.6, 9.0)
		_probe.position = Vector3(0, 1.8, -0.5)
		_probe.origin_offset = Vector3(0, -0.4, 0)
		_probe.box_projection = true
		_probe.interior = true
		_probe.enable_shadows = true
		_probe.update_mode = ReflectionProbe.UPDATE_ONCE
		_probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		world.add_child(_probe)


func _viewport(sz: Vector2i, content: Control, transparent := false, mode := SubViewport.UPDATE_ALWAYS) -> SubViewport:
	var vp := SubViewport.new()
	# se pinta a mayor resolución (con el 2D escalado) para que textos y pantallas se vean nítidos
	vp.size = Vector2i(Vector2(sz) * screen_scale)
	vp.size_2d_override = sz
	vp.size_2d_override_stretch = true
	vp.transparent_bg = transparent
	vp.render_target_update_mode = mode
	vp.disable_3d = true
	add_child(vp)
	content.position = Vector2.ZERO
	content.size = Vector2(sz)
	vp.add_child(content)
	return vp


func _paper(kind: String, sz: Vector2i, transparent := false, mode := SubViewport.UPDATE_ONCE) -> Array:
	var pv := PaperView.new()
	pv.kind = kind
	var vp := _viewport(sz, pv, transparent, mode)
	return [vp, pv]


## Vistas 2D del juego proyectadas en pantallas y lienzos 3D
func _screens() -> void:
	# la vista 2D de la ventana ya no se pinta (la ventana es 3D), pero sigue llevando el estado de fuera:
	# hora del día, nubes, tormenta y relámpagos (con su trueno), manifestaciones y celebraciones
	window_view = WindowView.new()
	_viewport(Vector2i(408, 470), window_view, false, SubViewport.UPDATE_DISABLED)
	tv = TvView.new()
	var tvp := _viewport(Vector2i(376, 226), tv)
	_live_vps.append(tvp)
	var tvm := Kit.screen_mat(tvp.get_texture(), 1.2)
	room.tv_screen.material_override = tvm
	# retrato oficial del presidente sobre la chimenea
	var holder := Control.new()
	var bg := PaperView.new()
	bg.kind = "portrait_bg"
	bg.size = Vector2(400, 492)
	holder.add_child(bg)
	var pr := Portrait.new()
	pr.position = Vector2(0, 12)
	pr.size = Vector2(400, 480)
	pr.track_mouse = false
	pr.breathe = false
	holder.add_child(pr)
	pr.setup(Perfil.apply_outfit(GS.pres.get("look", {})), true)
	var pvp := _viewport(Vector2i(400, 492), holder, false, SubViewport.UPDATE_ONCE)
	var pm := Kit.tex_mat(pvp.get_texture(), 0.55)
	room.portrait_canvas.material_override = pm
	# banderas
	var fl: Array = _paper("flag", Vector2i(300, 200))
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/flag3d.gdshader")
	fm.set_shader_parameter("flag_tex", (fl[0] as SubViewport).get_texture())
	var fm_flip := fm.duplicate() as ShaderMaterial
	fm_flip.set_shader_parameter("flip_u", true)
	for c in room.flag_cloths:
		(c as MeshInstance3D).material_override = fm_flip if c.get_meta("flip_u", false) else fm
	_flag_mat = fm


## Espejo de pared: una cámara 3D aparte (comparte el mundo de la sala, no duplica nada) que cada
## fotograma se coloca en el reflejo de la cámara del jugador respecto al cristal; su imagen se
## pinta en la superficie del espejo. Ver _update_mirror().
func _mirror_screen() -> void:
	mirror_vp = SubViewport.new()
	var msz := Vector2i(int(420 * screen_scale), int(750 * screen_scale))
	mirror_vp.size = msz
	mirror_vp.disable_3d = false
	mirror_vp.world_3d = get_viewport().world_3d
	mirror_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(mirror_vp)
	mirror_cam = Camera3D.new()
	mirror_cam.fov = 60.0
	mirror_cam.near = 0.05
	mirror_cam.far = 25.0
	mirror_cam.current = true
	# la cámara reflejada queda detrás del cristal, fuera del edificio: sin excluir el muro
	# exterior macizo (nunca pensado para verse) se vería ese muro en vez del reflejo de la sala
	mirror_cam.cull_mask &= ~Room.SHELL_LAYER
	mirror_vp.add_child(mirror_cam)
	_live_vps.append(mirror_vp)
	var mat := Kit.screen_mat(mirror_vp.get_texture(), 1.05)
	# la cámara del reflejo se reconstruye con un giro "derecho" (looking_at), así que la imagen
	# sale sin la inversión de un espejo real: se corrige volteando la U al pintarla
	mat.uv1_scale.x = -1.0
	mat.uv1_offset.x = 1.0
	room.mirror_quad.material_override = mat
	var mo = _obj("mirror", room.mirror_body, "Espejo", null, 1.05)
	mo.glow_color = Color(0.85, 0.92, 1.0)
	mo.status = "Se refleja el despacho"


func _obj(key: String, body: CollisionObject3D, title: String, shake: Node3D = null, badge_h := 0.25) -> Node:
	var o = Interactable.new()
	o.key = key
	o.title = title
	o.badge_height = badge_h
	body.add_child(o)
	o.setup(body, shake)
	objs[key] = o
	return o


## Registra un objeto físico para poder ordenarlo (tecla R) o recuperarlo si sale de la sala
func _prop(b: RigidBody3D) -> RigidBody3D:
	_props.append({"b": b, "xf": b.global_transform})
	return b


func _static(pos: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var s := StaticBody3D.new()
	s.position = pos
	s.rotation = rot
	world.add_child(s)
	return s


func _desk_objects() -> void:
	var top: float = Room.DESK_TOP
	var dz: float = Room.DESK_Z
	var gold := Kit.gold()
	var black := Kit.mat(Color("121316"), 0.42)
	# --- lámpara de banquero (fija)
	var lamp_col: Array = OfficeArt.LAMPS.get(Perfil.equipped_data("lampara").get("lamp", "verde"), OfficeArt.LAMPS["verde"])
	var lamp := _static(Vector3(-1.12, top, dz - 0.4))
	var lb := Batch.new()
	lb.lathe(Transform3D(), [Vector2(0.095, 0.0), Vector2(0.095, 0.008), Vector2(0.085, 0.014), Vector2(0.06, 0.022), Vector2(0.03, 0.03), Vector2(0.016, 0.04), Vector2(0.0, 0.04)], gold, 32)
	lb.lathe(Transform3D(), [Vector2(0.012, 0.04), Vector2(0.018, 0.06), Vector2(0.011, 0.08), Vector2(0.011, 0.25), Vector2(0.016, 0.27), Vector2(0.0, 0.28)], gold, 16)
	lb.segment(Vector3(0, 0.27, 0), Vector3(0, 0.3, 0.02), 0.01, gold)
	for sx in [-0.155, 0.155]:
		lb.lathe(Transform3D(Basis(Vector3.BACK, PI / 2.0 * signf(sx)), Vector3(sx, 0.32, 0.02)), [Vector2(0.078, 0.0), Vector2(0.08, 0.004), Vector2(0.04, 0.01), Vector2(0.0, 0.014)], gold, 24)
	lb.segment(Vector3(0.11, 0.3, 0.07), Vector3(0.11, 0.18, 0.075), 0.0015, gold, 6)
	lb.sphere(Vector3(0.11, 0.175, 0.075), 0.008, gold, 8, 5)
	lb.commit(lamp)
	_lamp_shade = StandardMaterial3D.new()
	_lamp_shade.albedo_color = Color(lamp_col[1])
	_lamp_shade.roughness = 0.06
	_lamp_shade.metallic_specular = 0.9
	_lamp_shade.emission_enabled = true
	_lamp_shade.emission = Color(lamp_col[0])
	_lamp_shade.emission_energy_multiplier = 0.4
	_lamp_shade.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shade := Kit.mesh(lamp, CylinderMesh.new(), _lamp_shade, Vector3(0, 0.32, 0.02), Vector3(0, 0, PI / 2.0), Vector3(1, 1, 0.72))
	var cm := shade.mesh as CylinderMesh
	cm.top_radius = 0.077
	cm.bottom_radius = 0.077
	cm.height = 0.3
	cm.radial_segments = 40
	Kit.add_shape(lamp, Kit.shape_cyl(0.1, 0.42), Vector3(0, 0.21, 0))
	_lamp_light = SpotLight3D.new()
	lamp.add_child(_lamp_light)
	_lamp_light.position = Vector3(0, 0.27, 0.05)
	_lamp_light.look_at_from_position(lamp.global_position + Vector3(0, 0.27, 0.05), Vector3(-0.45, top, dz + 0.25))
	_lamp_light.spot_angle = 62.0
	_lamp_light.spot_range = 2.4
	_lamp_light.light_energy = 1.25
	_lamp_light.light_color = Color(1.0, 0.84, 0.6)
	_lamp_light.light_size = 0.08
	_lamp_light.shadow_enabled = true
	_obj("lamp", lamp, "Lámpara · clic para encender o apagar", null, 0.5)
	# --- teléfono rojo (físico): cuerpo redondeado, dial de oro y cable rizado
	var gold_style: bool = Perfil.equipped_data("telefono").get("phone", "rojo") == "oro"
	var red := Kit.mat(Color("c9a050") if gold_style else Color("a3170f"), 0.18, 0.85 if gold_style else 0.0)
	var rp := _prop(Kit.rigid(world, Vector3(-1.0, top + 0.04, dz + 0.22), Kit.shape_box(Vector3(0.2, 0.08, 0.16)), 0.9, Vector3(0, 0.25, 0)))
	var rb := Batch.new()
	rb.cube(Vector3(0, -0.015, 0), Vector3(0.2, 0.05, 0.16), red, Vector3.ZERO, 1.0, 0.014, 2)
	rb.cube(Vector3(0, 0.016, -0.012), Vector3(0.16, 0.035, 0.12), red, Vector3(-0.22, 0, 0), 1.0, 0.014, 2)
	rb.lathe(Transform3D(Basis(Vector3.RIGHT, 1.35), Vector3(0, 0.022, 0.05)), [Vector2(0.036, 0.0), Vector2(0.037, 0.003), Vector2(0.032, 0.006), Vector2(0.012, 0.006), Vector2(0.0, 0.008)], gold, 32)
	for k in 10:
		var a := TAU * k / 12.0 + 0.6
		var hp := Basis(Vector3.RIGHT, 1.35) * Vector3(cos(a) * 0.024, 0.0068, sin(a) * 0.024)
		rb.sphere(Vector3(0, 0.022, 0.05) + hp, 0.004, Kit.mat(Color("3a0806"), 0.5), 8, 4, Vector3(1, 0.35, 1))
	_handset(rb, Vector3(0, 0.052, -0.012), 0.22, red)
	_coil(rb, Vector3(0.11, 0.05, -0.012), Vector3(0.1, -0.02, 0.07), red)
	rb.commit(rp)
	var rpo = _obj("redphone", rp, "Teléfono rojo · Gabinete de crisis")
	rpo.glow_color = Color(1.0, 0.3, 0.25)
	# --- teléfono de mesa (físico)
	var ph := _prop(Kit.rigid(world, Vector3(-0.58, top + 0.035, dz + 0.37), Kit.shape_box(Vector3(0.22, 0.07, 0.18)), 0.8, Vector3(0, 0.15, 0)))
	var pb := Batch.new()
	pb.cube(Vector3(0, -0.012, 0), Vector3(0.22, 0.045, 0.18), black, Vector3.ZERO, 1.0, 0.012, 2)
	pb.cube(Vector3(0.03, 0.016, 0.0), Vector3(0.15, 0.025, 0.16), black, Vector3(-0.15, 0, 0), 1.0, 0.01, 2)
	var key_m := Kit.mat(Color("3e4048"), 0.35)
	var kb := Basis(Vector3.RIGHT, -0.15)
	for r in 4:
		for c in 3:
			pb.box(Transform3D(kb, Vector3(0.0 + c * 0.03, 0.031, 0.04 - r * 0.022)), Vector3(0.022, 0.006, 0.015), key_m, 1.0, 0.0025)
	pb.box(Transform3D(kb, Vector3(0.03, 0.031, -0.055)), Vector3(0.115, 0.004, 0.032), Kit.mat(Color("16261d"), 0.1), 1.0, 0.002)
	_handset(pb, Vector3(-0.075, 0.034, 0), 0.2, black, true)
	_coil(pb, Vector3(-0.075, 0.03, 0.1), Vector3(-0.11, -0.025, 0.05), black)
	pb.commit(ph)
	_phone_lcd = Kit.label(ph, "LÍNEA LIBRE", UI.f_mono, 22, Color(0.5, 0.9, 0.55), Vector3(0.03, 0.0345, -0.0545), Vector3(-PI / 2.0 + 0.15, 0, 0), 0.0005)
	_phone_lcd.shaded = false
	_obj("phone", ph, "Teléfono")
	# --- bandeja de documentos (fija)
	var tray := _static(Vector3(-0.45, top, dz - 0.28))
	var tw := Kit.wood("caoba")
	var tb := Batch.new()
	tb.cube(Vector3(0, 0.006, 0), Vector3(0.36, 0.012, 0.28), tw, Vector3.ZERO, 1.0, 0.004)
	tb.cube(Vector3(0, 0.03, 0.134), Vector3(0.36, 0.05, 0.014), tw, Vector3.ZERO, 1.0, 0.005)
	tb.cube(Vector3(0, 0.03, -0.134), Vector3(0.36, 0.05, 0.014), tw, Vector3.ZERO, 1.0, 0.005)
	tb.cube(Vector3(0.173, 0.03, 0), Vector3(0.014, 0.05, 0.28), tw, Vector3.ZERO, 1.0, 0.005)
	tb.cube(Vector3(-0.173, 0.03, 0), Vector3(0.014, 0.05, 0.28), tw, Vector3.ZERO, 1.0, 0.005)
	for cx in [-0.173, 0.173]:
		for cz in [-0.134, 0.134]:
			tb.cube(Vector3(cx, 0.03, cz), Vector3(0.02, 0.054, 0.02), gold, Vector3.ZERO, 1.0, 0.004)
	tb.commit(tray)
	var paper_m := Kit.plaster(Color(0.97, 0.95, 0.9))
	var sheet := BoxMesh.new()
	sheet.size = Vector3(0.21, 0.004, 0.27)
	for i in 8:
		var s := Kit.mesh(tray, sheet, paper_m, Vector3(sin(i * 1.7) * 0.012, 0.016 + i * 0.0045, cos(i * 2.3) * 0.006), Vector3(0, sin(i * 1.3) * 0.06, 0))
		_tray_sheets.append(s)
	_tray_mark = Kit.mesh(tray, sheet, Kit.mat(Color(0.75, 0.1, 0.1), 0.6), Vector3.ZERO, Vector3.ZERO, Vector3(0.4, 1.0, 0.08))
	Kit.label(tray, "ENTRADA", UI.f_sans_b, 30, Color(0.85, 0.7, 0.4), Vector3(0, 0.03, 0.1415), Vector3.ZERO, 0.0006)
	Kit.add_shape(tray, Kit.shape_box(Vector3(0.36, 0.06, 0.28)), Vector3(0, 0.03, 0))
	_obj("tray", tray, "Bandeja de documentos", null, 0.2)
	# --- periódico (físico)
	var news := _prop(Kit.rigid(world, Vector3(-0.02, top + 0.007, dz + 0.34), Kit.shape_box(Vector3(0.3, 0.012, 0.4)), 0.3, Vector3(0, 0.12, 0)))
	var nb := Batch.new()
	nb.cube(Vector3.ZERO, Vector3(0.3, 0.012, 0.4), Kit.plaster(Color(0.88, 0.85, 0.78)), Vector3.ZERO, 1.0, 0.004)
	nb.commit(news)
	var np: Array = _paper("newspaper", Vector2i(300, 400))
	_news_vp = np[0]
	_news_view = np[1]
	var nq := Kit.mesh(news, Kit.quad_mesh(Vector2(0.29, 0.39)), Kit.tex_mat(_news_vp.get_texture(), 0.9), Vector3(0, 0.0062, 0), Vector3(-PI / 2.0, 0, 0))
	nq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var no = _obj("newspaper", news, "Periódico del día", null, 0.15)
	no.redraw = func():
		_news_view.queue_redraw()
		_news_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	# --- carpeta de presupuestos de cuero repujado (física)
	var fold := _prop(Kit.rigid(world, Vector3(0.36, top + 0.013, dz + 0.28), Kit.shape_box(Vector3(0.33, 0.026, 0.25)), 0.6, Vector3(0, -0.08, 0)))
	var fb := Batch.new()
	fb.cube(Vector3.ZERO, Vector3(0.33, 0.026, 0.25), Kit.leather(Color("4a1a12")), Vector3.ZERO, 1.0, 0.008, 2)
	for cx in [-0.15, 0.15]:
		for cz in [-0.11, 0.11]:
			fb.cube(Vector3(cx, 0.0132, cz), Vector3(0.04, 0.002, 0.04), gold, Vector3(0, PI / 4.0, 0))
	for inset in [0.018, 0.026]:
		fb.cube(Vector3(0, 0.0131, -0.125 + inset), Vector3(0.33 - inset * 2.0, 0.0005, 0.002), gold)
		fb.cube(Vector3(0, 0.0131, 0.125 - inset), Vector3(0.33 - inset * 2.0, 0.0005, 0.002), gold)
		fb.cube(Vector3(-0.165 + inset, 0.0131, 0), Vector3(0.002, 0.0005, 0.25 - inset * 2.0), gold)
		fb.cube(Vector3(0.165 - inset, 0.0131, 0), Vector3(0.002, 0.0005, 0.25 - inset * 2.0), gold)
	fb.cube(Vector3(0.09, 0.0, 0.127), Vector3(0.018, 0.02, 0.006), Kit.mat(Color("8e2a22"), 0.6))
	fb.commit(fold)
	Kit.label(fold, "PRESUPUESTOS", UI.f_serif_b, 40, Color(0.92, 0.77, 0.43), Vector3(0, 0.0138, -0.012), Vector3(-PI / 2.0, 0, 0), 0.0006)
	Kit.label(fold, "GENERALES DEL ESTADO", UI.f_sans_b, 18, Color(0.92, 0.77, 0.43, 0.85), Vector3(0, 0.0138, 0.025), Vector3(-PI / 2.0, 0, 0), 0.0006)
	_obj("folder", fold, "Presupuestos Generales", null, 0.15)
	# --- micrófono de flexo (fijo)
	var mic := _static(Vector3(0.42, top, dz - 0.3))
	var mb := Batch.new()
	var chrome := Kit.chrome()
	mb.lathe(Transform3D(), [Vector2(0.068, 0.0), Vector2(0.068, 0.006), Vector2(0.06, 0.016), Vector2(0.02, 0.022), Vector2(0.012, 0.03), Vector2(0.0, 0.03)], chrome, 32)
	var prev := Vector3(0, 0.025, 0)
	var last_dir := Vector3.UP
	var neck := Kit.mat(Color("1b1b1d"), 0.4)
	for i in range(1, 17):
		var t := float(i) / 16.0
		var p := Vector3(0, 0.025 + 0.27 * sin(t * PI / 2.0), 0.17 * (1.0 - cos(t * PI / 2.0)))
		last_dir = (p - prev).normalized()
		mb.segment(prev, p, 0.0075, neck, 10, false)
		if i % 2 == 0:
			mb.lathe(Transform3D(_basis_y(last_dir), p), [Vector2(0.0085, -0.003), Vector2(0.0085, 0.003)], neck, 10)
		prev = p
	var head_c := prev + last_dir * 0.05
	mb.lathe(Transform3D(_basis_y(last_dir), head_c - last_dir * 0.05), [Vector2(0.0, 0.0), Vector2(0.014, 0.005), Vector2(0.02, 0.02), Vector2(0.023, 0.06), Vector2(0.021, 0.09), Vector2(0.012, 0.1), Vector2(0.0, 0.102)], Kit.mat(Color("2a2b30"), 0.55, 0.4), 24)
	mb.lathe(Transform3D(_basis_y(last_dir), head_c - last_dir * 0.03), [Vector2(0.0235, -0.006), Vector2(0.0245, 0.0), Vector2(0.0235, 0.006)], gold, 24)
	mb.commit(mic)
	_led_on = Kit.emissive(Color(1.0, 0.15, 0.1), 3.0)
	_led_off = Kit.mat(Color(0.25, 0.06, 0.05), 0.4)
	_mic_led = Kit.mesh(mic, Kit.sphere_mesh(0.006, 10), _led_on, Vector3(0, 0.019, 0.058))
	Kit.add_shape(mic, Kit.shape_cyl(0.07, 0.34), Vector3(0, 0.17, 0.06))
	_obj("mic", mic, "Micrófono · Dirigirse a la nación", null, 0.42)
	# --- ordenador (fijo)
	var mon := _static(Vector3(1.02, top, dz - 0.3), Vector3(0, atan2(-1.02, 1.4), 0))
	var monb := Batch.new()
	var alu := Kit.mat(Color("8f9298"), 0.25, 0.8)
	monb.cube(Vector3(0, 0.006, 0.02), Vector3(0.24, 0.012, 0.17), alu, Vector3.ZERO, 1.0, 0.005, 2)
	monb.cube(Vector3(0, 0.1, -0.01), Vector3(0.045, 0.19, 0.025), alu, Vector3.ZERO, 1.0, 0.008, 2)
	monb.cube(Vector3(0, 0.36, 0.0), Vector3(0.52, 0.34, 0.028), Kit.mat(Color("111215"), 0.2, 0.3), Vector3.ZERO, 1.0, 0.008, 2)
	monb.cube(Vector3(0, 0.205, 0.012), Vector3(0.05, 0.006, 0.004), Kit.emissive(Color(0.4, 0.8, 1.0), 1.5))
	monb.commit(mon)
	monitor = MonitorView.new()
	var mvp := _viewport(Vector2i(300, 192), monitor)
	_live_vps.append(mvp)
	var ms := Kit.mesh(mon, Kit.quad_mesh(Vector2(0.49, 0.3136)), Kit.screen_mat(mvp.get_texture(), 1.1), Vector3(0, 0.365, 0.0145))
	ms.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.add_shape(mon, Kit.shape_box(Vector3(0.52, 0.54, 0.17)), Vector3(0, 0.27, 0))
	var mo = _obj("monitor", mon, "Ordenador · SIGEP", null, 0.6)
	mo.glow_color = Color(0.5, 0.75, 1.0)
	# --- calendario de mesa (físico)
	var cal := _prop(Kit.rigid(world, Vector3(1.05, top + 0.055, dz + 0.32), Kit.shape_box(Vector3(0.14, 0.11, 0.07)), 0.15, Vector3(0, atan2(-1.05, 0.98), 0)))
	var calb := Batch.new()
	var cal_wood := Kit.wood("caoba")
	calb.cube(Vector3(0, 0, 0.012), Vector3(0.14, 0.12, 0.006), cal_wood, Vector3(-0.32, 0, 0), 1.0, 0.002)
	calb.cube(Vector3(0, 0, -0.022), Vector3(0.13, 0.11, 0.005), cal_wood, Vector3(0.38, 0, 0), 1.0, 0.002)
	calb.cube(Vector3(0, -0.052, 0), Vector3(0.15, 0.008, 0.075), cal_wood, Vector3.ZERO, 1.0, 0.003)
	for rx in [-0.035, 0.035]:
		calb.lathe(Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(rx, 0.058, -0.002)), [Vector2(0.006, -0.004), Vector2(0.007, 0.0), Vector2(0.006, 0.004)], gold, 12)
	calb.commit(cal)
	var cp: Array = _paper("calendar", Vector2i(128, 120))
	_cal_vp = cp[0]
	_cal_view = cp[1]
	Kit.mesh(cal, Kit.quad_mesh(Vector2(0.122, 0.104)), Kit.tex_mat(_cal_vp.get_texture(), 0.8), Vector3(0, 0.002, 0.0165), Vector3(-0.32, 0, 0))
	var co = _obj("calendar", cal, "Agenda", null, 0.15)
	co.redraw = func():
		_cal_view.queue_redraw()
		_cal_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	# --- taza de porcelana con el sello (física)
	_mug = _prop(Kit.rigid(world, Vector3(0.72, top + 0.05, dz + 0.45), Kit.shape_cyl(0.042, 0.1), 0.35))
	var cer := Kit.mat(Color("f6f3ec"), 0.12)
	var ub := Batch.new()
	ub.lathe(Transform3D(Basis(), Vector3(0, -0.05, 0)), [Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.034, 0.003), Vector2(0.036, 0.008), Vector2(0.041, 0.05), Vector2(0.043, 0.095), Vector2(0.0435, 0.099), Vector2(0.041, 0.1), Vector2(0.038, 0.095), Vector2(0.036, 0.06), Vector2(0.032, 0.012), Vector2(0.0, 0.01)], cer, 32)
	ub.cyl(Vector3(0, 0.032, 0), 0.0375, 0.0375, 0.002, Kit.mat(Color("2a1408"), 0.05), Vector3.ZERO, 28)
	ub.lathe(Transform3D(Basis(), Vector3(0, 0.038, 0)), [Vector2(0.0435, 0.0), Vector2(0.0438, 0.003), Vector2(0.0435, 0.006)], gold, 32)
	ub.cyl(Vector3(0, 0.0, 0.0415), 0.013, 0.013, 0.003, gold, Vector3(PI / 2.0, 0, 0), 20)
	ub.commit(_mug)
	Kit.mesh(_mug, Kit.torus_mesh(0.017, 0.026, 24), cer, Vector3(0.048, 0.0, 0), Vector3(PI / 2.0, 0, 0))
	_steam = CPUParticles3D.new()
	_steam.amount = 10
	_steam.lifetime = 2.2
	_steam.position = Vector3(0, 0.05, 0)
	_steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_steam.emission_sphere_radius = 0.018
	_steam.direction = Vector3.UP
	_steam.spread = 12.0
	_steam.initial_velocity_min = 0.04
	_steam.initial_velocity_max = 0.08
	_steam.gravity = Vector3(0, 0.02, 0)
	_steam.scale_amount_min = 0.6
	_steam.scale_amount_max = 1.4
	_steam.local_coords = false
	var sq := QuadMesh.new()
	sq.size = Vector2(0.035, 0.035)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.vertex_color_use_as_albedo = true
	smat.albedo_texture = Kit.disc_tex()
	sq.material = smat
	_steam.mesh = sq
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	grad.add_point(0.25, Color(1, 1, 1, 0.07))
	_steam.color_ramp = grad
	_mug.add_child(_steam)
	_obj("mug", _mug, "Café", null, 0.15)
	# --- el móvil del presidente (físico): se puede coger y lanzar como todo lo demás
	var mv := _prop(Kit.rigid(world, Vector3(0.79, top + 0.0055, dz + 0.15), Kit.shape_box(Vector3(0.078, 0.011, 0.158)), 0.17, Vector3(0, 0.42, 0)))
	var mvb := Batch.new()
	mvb.cube(Vector3.ZERO, Vector3(0.078, 0.009, 0.158), Kit.mat(Color("15161a"), 0.25, 0.3), Vector3.ZERO, 1.0, 0.006, 2)
	mvb.cube(Vector3(0.0, -0.001, -0.06), Vector3(0.022, 0.0095, 0.022), Kit.mat(Color("2a2c33"), 0.1, 0.6), Vector3.ZERO, 1.0, 0.004, 2)
	mvb.commit(mv)
	_phone_lock = PhoneLock.new()
	_phone_vp = _viewport(Vector2i(120, 250), _phone_lock, false, SubViewport.UPDATE_ONCE)
	var mscr := Kit.mesh(mv, Kit.quad_mesh(Vector2(0.07, 0.148)), Kit.screen_mat(_phone_vp.get_texture(), 1.1), Vector3(0, 0.0047, 0), Vector3(-PI / 2.0, 0, 0))
	mscr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mvo = _obj("movil", mv, "Móvil · Pío y mensajes", null, 0.12)
	mvo.glow_color = Color(0.45, 0.72, 1.0)
	mvo.redraw = func():
		_phone_lock.queue_redraw()
		_phone_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	# --- placa con el nombre, hacia los visitantes (física)
	var plate := _prop(Kit.rigid(world, Vector3(0.0, top + 0.03, dz - 0.5), Kit.shape_box(Vector3(0.38, 0.06, 0.06)), 0.7, Vector3(0, PI, 0)))
	var plb := Batch.new()
	plb.cube(Vector3(0, -0.017, 0), Vector3(0.38, 0.026, 0.06), Kit.wood("ebano"), Vector3.ZERO, 1.0, 0.006, 2)
	plb.cube(Vector3(0, 0.012, 0), Vector3(0.36, 0.05, 0.006), gold, Vector3(-0.2, 0, 0), 1.0, 0.0025)
	plb.commit(plate)
	Kit.label(plate, "PRESIDENCIA DE LA REPÚBLICA", UI.f_serif_b, 22, Color("2a1d0e"), Vector3(0, 0.017, 0.0045), Vector3(-0.2, 0, 0), 0.0006)
	Kit.label(plate, GS.pres.get("name", ""), UI.f_serif_b, 30, Color("2a1d0e"), Vector3(0, 0.004, 0.0062), Vector3(-0.2, 0, 0), 0.0006)
	Kit.label(plate, "Presidencia", UI.f_serif, 20, Color("2a1d0e"), Vector3(0, 0.012, -0.0045), Vector3(0.2, PI, 0), 0.0006)
	# --- escribanía de latón con dos tinteros (fija)
	var ink := _static(Vector3(-0.17, top, dz - 0.05))
	var ib := Batch.new()
	ib.cube(Vector3(0, 0.006, 0), Vector3(0.24, 0.012, 0.13), gold, Vector3.ZERO, 1.0, 0.004, 2)
	for ix in [-0.06, 0.06]:
		ib.lathe(Transform3D(Basis(), Vector3(ix, 0.012, 0.01)), [Vector2(0.026, 0.0), Vector2(0.03, 0.01), Vector2(0.03, 0.04), Vector2(0.022, 0.05), Vector2(0.012, 0.055), Vector2(0.0, 0.055)], Kit.glass(Color(0.6, 0.7, 0.75, 0.35)), 20)
		ib.cyl(Vector3(ix, 0.03, 0.01), 0.022, 0.024, 0.032, Kit.mat(Color("101826"), 0.05), Vector3.ZERO, 16)
		ib.lathe(Transform3D(Basis(), Vector3(ix, 0.066, 0.01)), [Vector2(0.016, 0.0), Vector2(0.016, 0.008), Vector2(0.008, 0.014), Vector2(0.006, 0.02), Vector2(0.0, 0.024)], gold, 16)
	ib.segment(Vector3(-0.09, 0.016, -0.045), Vector3(0.09, 0.016, -0.045), 0.006, gold)
	ib.commit(ink)
	Kit.add_shape(ink, Kit.shape_box(Vector3(0.24, 0.08, 0.13)), Vector3(0, 0.04, 0))
	# --- juguetes físicos: plumas estilográficas, sello, pisapapeles, portarretratos y bolas de papel
	for i in 2:
		# forma de caja: un cilindro tumbado rodaba solo por la mesa
		var pen := _prop(Kit.rigid(world, Vector3(-0.22 + i * 0.05, top + 0.0072, dz + 0.5 + i * 0.03), Kit.shape_box(Vector3(0.013, 0.14, 0.013)), 0.03, Vector3(0, 0.3 + i * 0.25, PI / 2.0)))
		var penb := Batch.new()
		var body_m := Kit.mat(Color("0e0e10") if i == 0 else Color("1d3557"), 0.08)
		penb.lathe(Transform3D(Basis(), Vector3(0, -0.07, 0)), [Vector2(0.0, 0.0), Vector2(0.003, 0.004), Vector2(0.006, 0.014), Vector2(0.0068, 0.03), Vector2(0.007, 0.08), Vector2(0.0072, 0.12), Vector2(0.006, 0.137), Vector2(0.0, 0.14)], body_m, 14)
		penb.lathe(Transform3D(Basis(), Vector3(0, 0.03, 0)), [Vector2(0.0074, 0.0), Vector2(0.0076, 0.005), Vector2(0.0074, 0.01)], gold, 14)
		penb.cube(Vector3(0.0078, 0.05, 0), Vector3(0.0015, 0.04, 0.003), gold)
		penb.lathe(Transform3D(Basis(), Vector3(0, -0.08, 0)), [Vector2(0.0, 0.0), Vector2(0.0035, 0.01), Vector2(0.0, 0.0105)], gold, 8)
		penb.commit(pen)
	var stamp := _prop(Kit.rigid(world, Vector3(0.17, top + 0.05, dz + 0.52), Kit.shape_box(Vector3(0.07, 0.1, 0.05)), 0.15))
	var stb := Batch.new()
	stb.cube(Vector3(0, -0.042, 0), Vector3(0.07, 0.016, 0.05), Kit.mat(Color("6a2016"), 0.7), Vector3.ZERO, 1.0, 0.002)
	stb.cube(Vector3(0, -0.028, 0), Vector3(0.068, 0.012, 0.048), Kit.wood("caoba"), Vector3.ZERO, 1.0, 0.003)
	stb.lathe(Transform3D(Basis(), Vector3(0, -0.022, 0)), [Vector2(0.016, 0.0), Vector2(0.012, 0.01), Vector2(0.01, 0.03), Vector2(0.014, 0.04), Vector2(0.022, 0.052), Vector2(0.02, 0.064), Vector2(0.01, 0.07), Vector2(0.0, 0.071)], Kit.wood("ebano"), 18)
	stb.lathe(Transform3D(Basis(), Vector3(0, -0.01, 0)), [Vector2(0.0125, 0.0), Vector2(0.013, 0.003), Vector2(0.0125, 0.006)], gold, 18)
	stb.commit(stamp)
	var pw := _prop(Kit.rigid(world, Vector3(-0.78, top + 0.036, dz - 0.02), _sphere_shape(0.035), 0.4))
	Kit.mesh(pw, Kit.sphere_mesh(0.035, 28), Kit.glass(Color(0.75, 0.88, 1.0, 0.3)))
	Kit.mesh(pw, Kit.sphere_mesh(0.016, 12), Kit.emissive(Color(1.0, 0.7, 0.25), 0.3))
	# apenas inclinado: con más inclinación se volcaba al empezar
	var photo := _prop(Kit.rigid(world, Vector3(0.68, top + 0.0917, dz - 0.42), Kit.shape_box(Vector3(0.14, 0.18, 0.03)), 0.3, Vector3(-0.05, -0.35, 0)))
	var phb := Batch.new()
	phb.frame(Transform3D(Basis(), Vector3(0, 0, -0.006)), 0.14, 0.18, [Vector2(0, 0), Vector2(0.002, 0.008), Vector2(0.01, 0.012), Vector2(0.016, 0.008), Vector2(0.02, 0.0)], gold)
	phb.cube(Vector3(0, 0, -0.008), Vector3(0.14, 0.18, 0.004), Kit.wood("ebano"), Vector3.ZERO, 1.0, 0.0015)
	phb.commit(photo)
	Kit.mesh(photo, Kit.quad_mesh(Vector2(0.1, 0.14)), Kit.tex_mat(Room._landscape_tex(), 0.3), Vector3(0, 0, -0.0055))
	var crumple := Kit.sphere_mesh(0.032, 7)
	for i in 3:
		var ball := _prop(Kit.rigid(world, Vector3(0.22 + i * 0.07, top + 0.033, dz - 0.45 + (i % 2) * 0.04), _sphere_shape(0.032), 0.012))
		Kit.mesh(ball, crumple, Kit.plaster(Color(0.95, 0.94, 0.9)), Vector3.ZERO, Vector3(i, i * 2.0, 0), Vector3(1.0, 0.85, 0.95))


## Auricular de teléfono: mango con dos cazoletas
func _handset(bt, c: Vector3, length: float, m: Material, along_z := false) -> void:
	var ax := Vector3(0, 0, 1) if along_z else Vector3(1, 0, 0)
	var a := c - ax * length * 0.5
	var b2 := c + ax * length * 0.5
	bt.segment(a + ax * 0.03, b2 - ax * 0.03, 0.014, m, 14)
	for e in [a, b2]:
		bt.lathe(Transform3D(Basis(Vector3.RIGHT, PI), (e as Vector3) + Vector3(0, 0.012, 0)), [Vector2(0.0, 0.0), Vector2(0.028, 0.004), Vector2(0.032, 0.014), Vector2(0.028, 0.026), Vector2(0.0, 0.03)], m, 18)


## Cable rizado entre dos puntos (hélice)
func _coil(bt, from: Vector3, to: Vector3, m: Material) -> void:
	var d := to - from
	var bas := _basis_y(d.normalized())
	var turns := 14
	var steps := turns * 8
	var prev := from
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var a := t * TAU * turns
		var p := from + d * t + bas * Vector3(cos(a) * 0.006, 0, sin(a) * 0.006) + Vector3(0, -sin(t * PI) * 0.015, 0)
		bt.segment(prev, p, 0.0018, m, 5, false)
		prev = p


func _globe() -> void:
	var g := _static(Vector3(1.85, 0, -0.95))
	var gb := Batch.new()
	var wood := Kit.wood("caoba")
	var gold := Kit.gold()
	for i in 3:
		var a := TAU * i / 3.0
		var foot := Vector3(cos(a) * 0.26, 0.0, sin(a) * 0.26)
		var collar := Vector3(cos(a) * 0.05, 0.6, sin(a) * 0.05)
		var d := collar - foot
		gb.cylinder(Transform3D(_basis_y(d.normalized()), (foot + collar) * 0.5), 0.016, 0.022, d.length(), wood, 10)
	gb.cyl(Vector3(0, 0.62, 0), 0.06, 0.07, 0.05, wood, Vector3.ZERO, 20)
	gb.cyl(Vector3(0, 0.66, 0), 0.03, 0.05, 0.04, gold, Vector3.ZERO, 20)
	gb.commit(g)
	Kit.mesh(g, Kit.torus_mesh(0.24, 0.27, 40), wood, Vector3(0, 0.25, 0))
	var tilt := Node3D.new()
	tilt.position = Vector3(0, 0.98, 0)
	tilt.rotation = Vector3(0, 0, deg_to_rad(23.0))
	g.add_child(tilt)
	Kit.mesh(tilt, Kit.torus_mesh(0.3, 0.318, 56), gold, Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
	Kit.mesh(tilt, Kit.sphere_mesh(0.015, 8), gold, Vector3(0, 0.31, 0))
	globe_spin = Node3D.new()
	tilt.add_child(globe_spin)
	globe_mat = ShaderMaterial.new()
	globe_mat.shader = load("res://shaders/globe3d.gdshader")
	globe_mat.set_shader_parameter("map_tex", load("res://art/maps/world_ids.png"))
	globe_mat.set_shader_parameter("style", 1 if Perfil.equipped_data("globo").get("globe", "") == "nocturno" else 0)
	Kit.mesh(globe_spin, Kit.sphere_mesh(0.28, 48), globe_mat)
	Kit.add_shape(g, Kit.shape_cyl(0.32, 1.3), Vector3(0, 0.65, 0))
	_obj("globe", g, "Globo terráqueo · Diplomacia", null, 1.35)


## Colores de los países (índice = id del mapa): cada uno con su color, suavizado hacia el pergamino;
## Valdoria en dorado y las tierras sin nombre en tonos de pergamino
static func _world_palette() -> ImageTexture:
	var img := Image.create(16, 1, false, Image.FORMAT_RGBA8)
	var parch := Color(0.86, 0.78, 0.6)
	for i in 16:
		img.set_pixel(i, 0, parch.darkened(0.05 * (i % 4)))
	for c in W.COUNTRIES.keys():
		img.set_pixel(int(W.COUNTRIES[c]["map"]), 0, Color(W.COUNTRIES[c]["color"]).lerp(parch, 0.3))
	img.set_pixel(1, 0, Color(0.97, 0.74, 0.27))
	return ImageTexture.create_from_image(img)


## Mapa del mundo de la pared del fondo y globo: países coloreados y, en el mapa, sus nombres
func _world_map() -> void:
	var pal := _world_palette()
	for mt in [room.map_mat, globe_mat]:
		(mt as ShaderMaterial).set_shader_parameter("pal", pal)
		(mt as ShaderMaterial).set_shader_parameter("tex_size", Vector2(1600, 900))
	var names := {1: "VALDORIA"}
	for c in W.COUNTRIES.keys():
		names[int(W.COUNTRIES[c]["map"])] = String(W.COUNTRIES[c]["name"]).to_upper()
	var info: Dictionary = DB.world_map_info.get("countries", {})
	# ajustes para que Valdoria y Sarvenia, vecinas, no se pisen (en píxeles del mapa de 1600 × 900)
	var nudge := {1: Vector2(14, 30), 2: Vector2(-40, -18)}
	for k in info.keys():
		var id := int(k)
		if not names.has(id):
			continue
		var at: Vector2 = Vector2(float(info[k]["x"]), float(info[k]["y"])) + nudge.get(id, Vector2.ZERO)
		var u := at.x / 1600.0
		var v := at.y / 900.0
		var l := Kit.label(room.map_mesh, names[id], UI.f_serif_b, 44, Color(1.0, 0.95, 0.82) if id != 1 else Color(1.0, 0.86, 0.45), Vector3((u - 0.5) * 2.64, (0.5 - v) * 1.52, 0.003), Vector3.ZERO, 0.0012)
		l.outline_size = 14
		l.outline_modulate = Color(0.08, 0.05, 0.03, 0.9)


## Objetos de la habitación que ya construyó Room: puerta, televisor, reloj y sillón
func _room_objects() -> void:
	var door_hot := StaticBody3D.new()
	door_hot.collision_layer = 4
	door_hot.collision_mask = 0
	door_hot.position = Vector3(0, 1.3, Room.Z0 + 0.06)
	world.add_child(door_hot)
	Kit.add_shape(door_hot, Kit.shape_box(Vector3(1.6, 2.6, 0.04)))
	var door = _obj("door", door_hot, "Puerta del despacho", null, 0.95)
	door.glow_color = Color(1.0, 0.9, 0.6)
	for lb in room.door_bodies:
		door.collect(lb)
	var tvo = _obj("tv", room.tv_body, "Televisión · Canal 24 Noticias", null, 0.6)
	tvo.glow_color = Color(0.6, 0.8, 1.0)
	var clock = _obj("clock", room.clock_body, "Reloj · clic para pausar o reanudar", null, 1.4)
	clock.glow_color = Color(1.0, 0.85, 0.5)
	clock.collect(room.clock_pendulum)
	clock.collect(room.clock_hour)
	clock.collect(room.clock_minute)
	var chair = _obj("chair", room.chair_body, "Sillón presidencial · clic para sentarse", null, 1.8)
	chair.glow_color = Color(1.0, 0.9, 0.7)
	# cortinas del ventanal: se abren y se cierran
	var cur = _obj("curtains", room.curtain_body, "Cortinas", null, 3.5)
	cur.glow_color = Color(1.0, 0.8, 0.7)
	for cd in room.curtains:
		cur.collect(cd["mi"])
	# sofá y sillones de la zona de estar: se puede sentar en ellos
	for s in room.seats:
		var so = _obj(s["key"], s["body"], s["title"], null, 1.2)
		so.glow_color = Color(1.0, 0.9, 0.7)


## Objetos físicos repartidos por la sala (para jugar con ellos)
func _decor_props() -> void:
	var gold := Kit.gold()
	# revistas, licorera y vasos en la mesa baja
	var cols := [Color("8e2a22"), Color("1f3552"), Color("e9dcc0")]
	for i in 3:
		# apiladas justo una encima de otra (antes aparecían flotando y caían)
		var mg := _prop(Kit.rigid(world, Vector3(3.45 + i * 0.05, 0.4642 + i * 0.0082, -0.95 + i * 0.12), Kit.shape_box(Vector3(0.22, 0.008, 0.3)), 0.25, Vector3(0, i * 0.4 - 0.3, 0)))
		Kit.mesh(mg, _box(Vector3(0.22, 0.008, 0.3)), Kit.mat(cols[i], 0.6))
	var dec := _prop(Kit.rigid(world, Vector3(3.55, 0.561, -0.25), Kit.shape_cyl(0.055, 0.2), 0.9))
	var db := Batch.new()
	var crystal := Kit.mat(Color(0.75, 0.82, 0.86), 0.05, 0.4)
	db.cyl(Vector3(0, -0.03, 0), 0.055, 0.055, 0.14, crystal, Vector3.ZERO, 8)
	db.cyl(Vector3(0, -0.03, 0), 0.05, 0.05, 0.1, Kit.mat(Color("7a3a10"), 0.1), Vector3.ZERO, 8)
	db.cyl(Vector3(0, 0.06, 0), 0.018, 0.04, 0.05, crystal, Vector3.ZERO, 8)
	db.commit(dec)
	Kit.mesh(dec, Kit.sphere_mesh(0.025, 8), crystal, Vector3(0, 0.1, 0))
	for i in 2:
		var gl := _prop(Kit.rigid(world, Vector3(3.35 + i * 0.12, 0.505, -0.2), Kit.shape_cyl(0.032, 0.075), 0.2))
		var glb := Batch.new()
		glb.cyl(Vector3.ZERO, 0.032, 0.03, 0.075, crystal, Vector3.ZERO, 8)
		glb.commit(gl)
	# diarios de opinión: una pila interactiva, al otro lado de la mesa baja
	var dcols := [Color("7a2f36"), Color("2d4a3a"), Color("8e742a")]
	var diary_top: RigidBody3D
	for i in 3:
		diary_top = _prop(Kit.rigid(world, Vector3(3.72, 0.4642 + i * 0.0082, -0.15 + i * 0.03), Kit.shape_box(Vector3(0.22, 0.008, 0.28)), 0.25, Vector3(0, i * 0.3 - 0.25, 0)))
		Kit.mesh(diary_top, _box(Vector3(0.22, 0.008, 0.28)), Kit.mat(dcols[i], 0.65))
	var dv: Array = _paper("diary", Vector2i(260, 340))
	_diary_vp = dv[0]
	_diary_view = dv[1]
	var dq := Kit.mesh(diary_top, Kit.quad_mesh(Vector2(0.21, 0.27)), Kit.tex_mat(_diary_vp.get_texture(), 0.9), Vector3(0, 0.0062, 0), Vector3(-PI / 2.0, 0, 0))
	dq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dobj = _obj("diary", diary_top, "Diarios de opinión", null, 0.14)
	dobj.glow_color = Color(0.9, 0.8, 0.6)
	dobj.status = "Clic para leer"
	dobj.redraw = func():
		_diary_view.diary_seed = _diary_seed
		_diary_view.queue_redraw()
		_diary_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	dobj.queue_redraw()
	# cojines en el sofá
	var vel := Kit.velvet(Color(OfficeArt.THEMES.get(Perfil.office_theme(), OfficeArt.THEMES["clasico"])["curt"][2]))
	for dz in [-1.25, 0.05]:
		# apoyados en el asiento y recostados en el respaldo (inclinados lo justo para no caerse hacia delante)
		var cu := _prop(Kit.rigid(world, Vector3(4.661, 0.639, dz), Kit.shape_box(Vector3(0.12, 0.38, 0.38)), 0.4, Vector3(0, 0, -0.4)))
		Kit.mesh(cu, _box(Vector3(0.12, 0.38, 0.38)), vel)
		var cb := Batch.new()
		cb.cube(Vector3(0, 0, 0), Vector3(0.125, 0.39, 0.02), gold)
		cb.commit(cu)
	# libros, sujetalibros y estatuilla en el aparador
	var bcols := ["6b1d24", "1f3552", "2e4a2c", "8a6a3a", "34405e"]
	var bx := 3.0
	for i in 5:
		var bw := 0.045 + (i % 3) * 0.01
		var bh := 0.26 + (i % 2) * 0.04
		var book := _prop(Kit.rigid(world, Vector3(bx + bw * 0.5, 0.865 + bh * 0.5, -4.76), Kit.shape_box(Vector3(bw, bh, 0.2)), 0.5))
		Kit.mesh(book, _box(Vector3(bw, bh, 0.2)), Kit.mat(Color(bcols[i]), 0.7))
		Kit.mesh(book, _box(Vector3(bw + 0.001, 0.012, 0.18)), gold, Vector3(0, bh * 0.3, 0.012))
		bx += bw + 0.004
	for ex in [2.97, bx + 0.012]:
		var be := _prop(Kit.rigid(world, Vector3(ex, 0.94, -4.76), Kit.shape_box(Vector3(0.02, 0.15, 0.12)), 1.2))
		Kit.mesh(be, _box(Vector3(0.02, 0.15, 0.12)), gold)
	var statue := _prop(Kit.rigid(world, Vector3(4.35, 1.0, -4.76), Kit.shape_cyl(0.06, 0.27), 1.6))
	var sb := Batch.new()
	var bronze := Kit.mat(Color("6e5230"), 0.4, 0.75)
	sb.cyl(Vector3(0, -0.12, 0), 0.06, 0.07, 0.03, Kit.wood("ebano"), Vector3.ZERO, 16)
	sb.cyl(Vector3(0, -0.02, 0), 0.03, 0.045, 0.17, bronze, Vector3.ZERO, 12)
	sb.commit(statue)
	Kit.mesh(statue, Kit.sphere_mesh(0.035, 12), bronze, Vector3(0, 0.1, 0))
	# portarretratos en la consola del fondo
	for fx in [-0.75, 0.75]:
		# sobre el mármol (antes aparecían hundidos en él y saltaban)
		var fr := _prop(Kit.rigid(world, Vector3(fx, 0.978, 3.72), Kit.shape_box(Vector3(0.2, 0.25, 0.03)), 0.3, Vector3(-0.06, PI + (0.25 if fx < 0 else -0.25), 0)))
		Kit.mesh(fr, _box(Vector3(0.2, 0.25, 0.02)), gold)
		Kit.mesh(fr, Kit.quad_mesh(Vector2(0.16, 0.21)), Kit.tex_mat(Room._landscape_tex(), 0.4), Vector3(0, 0, 0.0105))
	# candelabros sobre la chimenea
	for cz in [-1.95, -0.45]:
		var cs := _prop(Kit.rigid(world, Vector3(Room.X0 + 0.3, 1.367, cz), Kit.shape_cyl(0.035, 0.32), 0.8))
		var csb := Batch.new()
		csb.cyl(Vector3(0, -0.14, 0), 0.045, 0.05, 0.03, gold, Vector3.ZERO, 16)
		csb.cyl(Vector3(0, -0.01, 0), 0.012, 0.018, 0.24, gold, Vector3.ZERO, 12)
		csb.cyl(Vector3(0, 0.13, 0), 0.012, 0.012, 0.06, Kit.mat(Color("f3ecdc"), 0.6), Vector3.ZERO, 10)
		csb.commit(cs)


func _pet() -> void:
	pet_kind = Perfil.equipped_data("mascota").get("pet", "")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pet="):
			pet_kind = a.substr(6)
	if pet_kind == "":
		return
	if pet_kind == "tortuga":
		# pecera 3D en la esquina trasera izquierda de la mesa, entre la lámpara y la bandeja
		aquarium = Aquarium.new()
		world.add_child(aquarium)
		aquarium.position = Vector3(-0.82, Room.DESK_TOP, Room.DESK_Z - 0.36)
		aquarium.build()
		var ao = _obj("pet", aquarium.body, "Trámite, la tortuga", null, 0.36)
		ao.glow_color = Color(0.7, 0.95, 1.0)
		ao.status = "Clic para mimarla (baja el estrés)"
		return
	if pet_kind == "loro":
		# posado en lo alto de la cúpula del reloj de pie (cx=2.2, cz=Z0+0.2 en _clock(); la cúpula
		# culmina sobre y=2.44 a radio 0.3)
		parrot3d = Parrot3D.new()
		world.add_child(parrot3d)
		parrot3d.position = Vector3(2.2, 2.74, Room.Z0 + 0.2)
		parrot3d.build()
		var po2 = _obj("pet", parrot3d.body, "Senador, el loro", null, 0.3)
		po2.glow_color = Color(1.0, 0.9, 0.7)
		po2.status = "Clic para mimarla (baja el estrés)"
		_parrot_lbl = Label3D.new()
		_parrot_lbl.font = UI.f_sans_b
		_parrot_lbl.font_size = 34
		_parrot_lbl.outline_size = 14
		_parrot_lbl.outline_modulate = Color(0.98, 0.97, 0.92)
		_parrot_lbl.modulate = Color("1a1a1a")
		_parrot_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_parrot_lbl.pixel_size = 0.0022
		_parrot_lbl.position = Vector3(0, 0.22, 0.06)
		parrot3d.body.add_child(_parrot_lbl)
		return
	if pet_kind == "gato":
		cat3d = Cat3D.new()
		world.add_child(cat3d)
		cat3d.position = Vector3(0.05, Room.DESK_TOP, Room.DESK_Z - 0.3)
		cat3d.build()
		var co = _obj("pet", cat3d.body, "Decreto, el gato", null, 0.3)
		co.glow_color = Color(1.0, 0.9, 0.7)
		co.status = "Clic para mimarla (baja el estrés)"
		return
	if pet_kind == "perro":
		dog3d = Dog3D.new()
		world.add_child(dog3d)
		dog3d.position = Vector3(1.45, 0.0, 0.35)
		dog3d.build()
		var dob = _obj("pet", dog3d.body, "Tribuno, el perro", null, 0.46)
		dob.glow_color = Color(1.0, 0.9, 0.7)
		dob.status = "Clic para mimarla (baja el estrés)"
		return
	if pet_kind == "pez":
		fishbowl3d = Fishbowl3D.new()
		world.add_child(fishbowl3d)
		fishbowl3d.position = Vector3(0.05, Room.DESK_TOP, Room.DESK_Z - 0.3)
		fishbowl3d.build()
		var fo = _obj("pet", fishbowl3d.body, "El pez dorado", null, 0.3)
		fo.glow_color = Color(0.7, 0.95, 1.0)
		fo.status = "Clic para mimarla (baja el estrés)"


func _box(s: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = s
	return bm


func _sphere_shape(r: float) -> SphereShape3D:
	var s := SphereShape3D.new()
	s.radius = r
	return s


## Pone `n` y todo su árbol de mallas/sprites en una única capa de render (ver AVATAR_LAYER)
func _set_layer(n: Node, layer: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = layer
	for c in n.get_children():
		_set_layer(c, layer)


## Base cuyo eje Y apunta en la dirección d
func _basis_y(d: Vector3) -> Basis:
	var y := d.normalized()
	var x := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := x.cross(y).normalized()
	x = y.cross(z).normalized()
	return Basis(x, y, z)


# ------------------------------------------------------------------ señales del juego

func _on_headline_news(_t2: String) -> void:
	objs["newspaper"].queue_redraw()


func _on_day_redraw() -> void:
	objs["calendar"].queue_redraw()
	if not GS.unlocks.is_empty() and GS.day <= 120:
		_refresh()


func _on_weather() -> void:
	window_view.weather = GS.weather


func _refresh() -> void:
	if objs.is_empty():
		return
	var tray = objs["tray"]
	tray.badge = str(GS.inbox.size()) if GS.inbox.size() > 0 else ""
	tray.status = "%d documentos pendientes" % GS.inbox.size() if GS.inbox.size() > 0 else "Sin documentos pendientes"
	tray.pulse = GS.inbox.size() > 0
	var n := mini(GS.inbox.size(), 8)
	for i in _tray_sheets.size():
		(_tray_sheets[i] as Node3D).visible = i < n
	_tray_mark.visible = false
	if n > 0:
		var ev: Dictionary = GS.inbox[GS.inbox.size() - 1]["ev"]
		_tray_mark.visible = ev.get("kind", "") in ["informe"]
		_tray_mark.position = (_tray_sheets[n - 1] as Node3D).position + Vector3(0, 0.003, -0.08)
	var ph = objs["phone"]
	ph.ringing = GS.calls.size() > 0
	if GS.calls.size() > 0:
		var who: String = GS.calls[0]["ev"].get("who", "")
		ph.status = "Llamada entrante: %s" % DB.character(who).get("name", "")
		Sfx.loop_start("ring", "ring", -6.0)
	else:
		ph.status = "Llamar a un líder o interlocutor"
		Sfx.loop_stop("ring")
	var rp = objs["redphone"]
	rp.ringing = GS.alerts.size() > 0
	if GS.alerts.size() > 0:
		rp.status = "¡CRISIS! %s" % GS.fmt(GS.alerts[0]["ev"]["title"])
		rp.badge = "!"
		if not _last_alert:
			Sfx.loop_start("red", "ring_red", -8.0)
		_last_alert = true
	else:
		rp.status = "Línea directa del Gabinete de Crisis"
		rp.badge = ""
		Sfx.loop_stop("red")
		_last_alert = false
	tv.alert = GS.alerts.size() > 0
	var door = objs["door"]
	door.pulse = GS.visitors.size() > 0
	door.badge = str(GS.visitors.size()) if GS.visitors.size() > 0 else ""
	door.badge_color = UI.AMBER
	if GS.visitors.size() > 0:
		var ch := DB.character(GS.visitors[0]["ev"].get("who", "jefa"))
		door.status = "%s espera: %s" % [ch.get("name", ""), GS.fmt(GS.visitors[0]["ev"]["title"])]
	else:
		door.status = "No hay nadie esperando · Consejo de Ministros"
	var fold = objs["folder"]
	fold.pulse = GS.flags.has("presupuesto_pendiente")
	fold.badge = "!" if GS.flags.has("presupuesto_pendiente") else ""
	fold.badge_color = UI.GOLD_D
	var mic = objs["mic"]
	var cd := GS.speech_until - GS.day
	mic.status = "Disponible" if cd <= 0 else "Disponible en %d días" % cd
	if GS.campaign:
		mic.status = "Mitin de campaña · " + mic.status
	var mv = objs["movil"]
	var unread := Redes.unread()
	mv.badge = str(unread) if unread > 0 else ""
	mv.badge_color = Color(0.11, 0.6, 0.94)
	mv.pulse = unread > 0
	mv.status = ("%d mensaje%s sin leer" % [unread, "" if unread == 1 else "s"]) if unread > 0 else "Lo que dice la calle en Pío"
	objs["newspaper"].status = "Última edición"
	objs["monitor"].status = "Datos, leyes, Congreso y gabinete"
	objs["globe"].status = "Relaciones internacionales y acuerdos"
	objs["calendar"].status = "Próximos acontecimientos"
	objs["folder"].status = "Gasto por partidas e impuestos"
	objs["mug"].status = "Un café para el estrés"
	objs["tv"].status = "Noticias y encuestas"
	objs["clock"].status = "Tiempo en marcha" if GS.speed > 0 else "Tiempo detenido"
	objs["curtains"].status = "Clic para abrirlas" if _curtain_target > 0.5 else "Clic para cerrarlas"
	for k in ["globe", "folder", "mic", "phone"]:
		var lk := _lock_key(k)
		var locked := lk != "" and not GS.is_unlocked(lk)
		objs[k].modulate = Color(0.62, 0.62, 0.66) if locked else Color.WHITE
		if locked:
			objs[k].status = "Disponible en %d días" % GS.days_to_unlock(lk)
	for o in objs.values():
		o.queue_redraw()


## Objetos que se presentan poco a poco (fácil y normal) y el sistema del que dependen
const LOCKS := {"globe": "diplomacia", "folder": "presupuestos", "mic": "discurso"}


func _lock_key(key: String) -> String:
	if key == "phone" and GS.calls.is_empty():
		return "diplomacia"
	if key == "mic" and GS.campaign:
		return ""
	return LOCKS.get(key, "")


## Si el objeto aún no está disponible, avisa y devuelve true
func _blocked(key: String) -> bool:
	var lk := _lock_key(key)
	if lk == "" or GS.is_unlocked(lk):
		return false
	var n := GS.days_to_unlock(lk)
	GS.toast.emit("%s: su gabinete se lo presentará en %d día%s. De momento, céntrese en documentos, visitas y llamadas." % [GS.UNLOCK_INFO[lk]["name"], n, "" if n == 1 else "s"], "info", "candado")
	Sfx.play("click", -6.0, 0.7)
	return true


func _on_object(key: String) -> void:
	tip.visible = false
	if _blocked(key):
		return
	Sfx.play("click", -4.0)
	match key:
		"tray":
			if GS.inbox.is_empty():
				GS.toast.emit("La bandeja está vacía. ¡Buen trabajo!", "info", "documento")
			else:
				request.emit("doc", {})
		"phone":
			if GS.calls.size() > 0:
				Sfx.loop_stop("ring")
				request.emit("call", {"item": GS.calls[0]})
			else:
				request.emit("phonebook", {})
		"redphone":
			if GS.alerts.size() > 0:
				Sfx.loop_stop("red")
				request.emit("crisis", {"item": GS.alerts[0]})
			else:
				GS.toast.emit("El Gabinete de Crisis informa: sin incidencias graves.", "good", "seguridad")
		"door":
			if GS.visitors.size() > 0:
				request.emit("advisor", {"item": GS.visitors[0]})
			else:
				request.emit("cabinet", {})
		"tv":
			request.emit("tv", {})
		"monitor":
			request.emit("dashboard", {})
		"calendar":
			request.emit("dashboard", {"tab": "agenda"})
		"globe":
			_globe_boost = 3.0
			request.emit("world", {})
		"newspaper":
			request.emit("newspaper", {"latest": true})
		"movil":
			request.emit("movil", {})
		"folder":
			request.emit("budget", {})
		"mic":
			if GS.campaign:
				request.emit("campaign", {})
			elif GS.day < GS.speech_until:
				GS.toast.emit("Demasiado pronto para otro discurso (%d días)." % (GS.speech_until - GS.day), "warn", "microfono")
			else:
				request.emit("speech", {"occasion": "campana" if GS.campaign else "nacion"})
		"mug":
			if _mug.global_transform.basis.y.dot(Vector3.UP) < 0.6:
				GS.toast.emit("La taza está volcada. Póngala derecha para tomar café.", "warn", "cafe")
			elif _coffee_cd <= 0.0:
				_coffee_cd = 25.0
				GS.stress = maxf(0.0, GS.stress - 4.0)
				Sfx.play("paper2", -10.0, 0.6)
				GS.toast.emit("Un café solo. Estrés −4.", "info", "cafe")
			else:
				GS.toast.emit("Ya ha tomado demasiado café.", "warn", "cafe")
		"clock":
			GS.set_speed(1 if GS.speed == 0 else 0)
			_refresh()
		"lamp":
			_lamp_on = not _lamp_on
			Sfx.play("click", -2.0, 0.7)
		"chair":
			_sit_on(pres_seat)
		"curtains":
			_curtain_target = 0.0 if _curtain_target > 0.5 else 1.0
			Sfx.play("whoosh", -12.0, 0.55)
			_refresh()
		"diary":
			request.emit("diary", {"seed": _diary_seed})
		"mirror":
			pass
		"pet":
			_pet_happy = 2.5
			if _pet_view != null:
				_pet_view.pet_happy = true
			if _pet_cd <= 0.0:
				_pet_cd = 20.0
				GS.stress = maxf(0.0, GS.stress - 3.0)
				GS.toast.emit({"gato": "Decreto ronronea. Estrés −3.", "perro": "Tribuno mueve la cola. Estrés −3.", "loro": "Senador: «¡Presidente guapo!». Estrés −3.", "pez": "El pez da una vuelta. Estrés −3.", "tortuga": "Trámite echa burbujas de alegría. Estrés −3."}.get(pet_kind, ""), "good", "bienestar")
			if pet_kind == "loro":
				_parrot_line = (PARROT_MEME if GS.mode == "meme" and randf() < 0.7 else PARROT).pick_random()
				_parrot_t = 4.0
			Sfx.play("notify", -10.0, 1.6 if pet_kind != "perro" else 0.7)
		_:
			for s in room.seats:
				if s["key"] == key:
					_sit_on(s)


## Se sienta en un asiento (sillón presidencial, sillones o sofá)
func _sit_on(s: Dictionary) -> void:
	if player.seated and seat_now.get("key", "") == s["key"]:
		return
	seat_now = s
	player.stand_pos = s["stand"]
	player.sit_at(s["pos"], s["yaw"], s["eye"])


## Asiento más cercano al presidente (a menos de `max_d` metros) o {}
func _nearest_seat(max_d: float) -> Dictionary:
	var best := {}
	var bd := max_d
	for s in [pres_seat] + room.seats:
		var d: float = player.global_position.distance_to(s["pos"])
		if d < bd:
			bd = d
			best = s
	return best


# ------------------------------------------------------------------ visitas

func enter_visitor(look: Dictionary) -> void:
	visitor3d.dress(look)
	visitor3d.show_at(Room.CORRIDOR_START)
	Sfx.play("door", -2.0)
	var t := create_tween()
	t.tween_property(self, "_door_open", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): visitor3d.walk_to(Room.VISITOR_SPOT, 1.7))
	t.tween_interval(1.5)
	t.tween_property(self, "_door_open", 0.0, 0.6)
	player.drop()
	player.focus_on(Room.VISITOR_SPOT + Vector3(0, Visitor3D.FACE_H, 0), -0.2)


func exit_visitor() -> void:
	if not visitor3d.visible:
		return
	Sfx.play("door", -4.0, 0.9)
	var t := create_tween()
	t.tween_property(self, "_door_open", 1.0, 0.45)
	t.parallel().tween_callback(func(): visitor3d.walk_to(Room.CORRIDOR_START, 1.6))
	t.tween_interval(1.6)
	t.tween_callback(func(): visitor3d.hide_away())
	t.tween_property(self, "_door_open", 0.0, 0.5)


## Pasa a otra opinión del diario (la llama la pantalla de lectura en 2D) y actualiza la mesa baja
func next_diary_opinion() -> int:
	_diary_seed += 1
	Sfx.play("paper", -10.0, 1.0)
	if objs.has("diary"):
		objs["diary"].queue_redraw()
	return _diary_seed


# ------------------------------------------------------------------ entrada

func _ui_open() -> bool:
	if main != null and main.get("current_overlay") != null:
		return true
	return GS.holds > 0


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not GS.active or _ui_open():
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			player.look(event.relative)
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if player.held != null:
					player.throw_held()
				elif _hover != null and _hover.enabled:
					_on_object(_hover.key)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT:
				if player.held != null:
					player.drop()
				elif _hover_grab != null:
					player.grab(_hover_grab)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				if player.held != null:
					player.scroll_hold(0.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if player.held != null:
					player.scroll_hold(-0.1)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB:
				cursor_mode = not cursor_mode
				get_viewport().set_input_as_handled()
			KEY_F:
				if player.seated:
					_stand()
				else:
					var s := _nearest_seat(2.4)
					if s.is_empty():
						GS.toast.emit("Acérquese a un sillón o al sofá para sentarse.", "info", "info")
					else:
						_sit_on(s)
				get_viewport().set_input_as_handled()
			KEY_R:
				_tidy()
				get_viewport().set_input_as_handled()
			KEY_H:
				_hint_t = 0.0 if _hint_t > 0.0 else 9999.0
				get_viewport().set_input_as_handled()
			KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
				if player.seated:
					_stand()


## Se levanta del sillón giratorio hacia donde mira; si delante está la mesa, sale por detrás.
## De los sillones y el sofá sale a un sitio despejado junto a ellos.
func _stand() -> void:
	if seat_now.get("key", "chair") != "chair":
		player.stand_pos = seat_now["stand"]
		seat_now = {}
		player.stand()
		return
	seat_now = {}
	var fwd := Vector3(-sin(player.yaw), 0, -cos(player.yaw))
	var p: Vector3 = Room.SEAT + fwd * 0.8
	if _blocked_spot(p):
		p = Room.SEAT - fwd * 0.88
		if _blocked_spot(p):
			p = Room.STAND
	player.stand_pos = p
	player.stand()


func _blocked_spot(p: Vector3) -> bool:
	return absf(p.x) < 1.6 and p.z < -0.15 and p.z > -1.85


## Devuelve a su sitio todos los objetos físicos
func _tidy() -> void:
	player.drop()
	for p in _props:
		var b: RigidBody3D = p["b"]
		if is_instance_valid(b):
			b.global_transform = p["xf"]
			b.linear_velocity = Vector3.ZERO
			b.angular_velocity = Vector3.ZERO
	Sfx.play("whoosh", -12.0, 1.2)
	GS.toast.emit("Su secretaría ha ordenado el despacho.", "info", "documento")


# ------------------------------------------------------------------ bucle

func _physics_process(_delta: float) -> void:
	if player == null:
		return
	# objetos que se han salido de la sala vuelven a su sitio
	for p in _props:
		var b: RigidBody3D = p["b"]
		if not is_instance_valid(b):
			continue
		var gp := b.global_position
		if gp.y < -1.0 or gp.y > 5.0 or absf(gp.x) > 6.0 or gp.z > 5.0 or gp.z < -9.5:
			b.global_transform = p["xf"]
			b.linear_velocity = Vector3.ZERO
			b.angular_velocity = Vector3.ZERO
	_update_hover()


func _update_hover() -> void:
	var new_hover: Node = null
	var new_grab: RigidBody3D = null
	if GS.active and not _ui_open():
		var cam: Camera3D = player.cam
		var sp: Vector2
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			sp = get_viewport().get_visible_rect().size * 0.5
		else:
			sp = get_viewport().get_mouse_position()
		var from := cam.project_ray_origin(sp)
		var dir := cam.project_ray_normal(sp)
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * INTERACT_RANGE, 1 | 2 | 4)
		var ex: Array[RID] = [player.get_rid()]
		if player.held != null and is_instance_valid(player.held):
			ex.append(player.held.get_rid())
		q.exclude = ex
		var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			var col: Object = hit["collider"]
			if col != null and col.has_meta("obj"):
				var o = col.get_meta("obj")
				if is_instance_valid(o) and not (player.seated and o.key == seat_now.get("key", "")):
					new_hover = o
			if col is RigidBody3D and player.can_grab(col):
				new_grab = col
	if new_hover != _hover:
		if _hover != null and is_instance_valid(_hover):
			_hover.hover = false
		_hover = new_hover
		if _hover != null:
			_hover.hover = true
			Sfx.play("hover", -14.0)
	_hover_grab = new_grab


func _process(delta: float) -> void:
	_t += delta
	if _pngshot_wait > 0:
		_pngshot_wait -= 1
		if _pngshot_wait == 0:
			get_viewport().get_texture().get_image().save_png(_pngshot_path)
			get_tree().quit()
			return
	# en calidad reducida, las pantallas (ventana, televisor, ordenador) se repintan una vez de cada cuatro
	_frame += 1
	if low_quality and _frame % 4 == 0:
		var v: SubViewport = _live_vps[(_frame / 4) % _live_vps.size()]
		v.render_target_update_mode = SubViewport.UPDATE_ONCE
	_coffee_cd = maxf(0.0, _coffee_cd - delta)
	_pet_cd = maxf(0.0, _pet_cd - delta)
	_pet_happy = maxf(0.0, _pet_happy - delta)
	if _pet_view != null:
		_pet_view.pet_happy = _pet_happy > 0.0
	_globe_boost = maxf(0.0, _globe_boost - delta)
	# ratón: capturado para mirar salvo con pantallas abiertas o cursor libre
	var ui := _ui_open()
	if ui and not _ui_was_open:
		player.drop()
	_ui_was_open = ui
	var want := Input.MOUSE_MODE_VISIBLE
	if GS.active and not ui and not cursor_mode and get_window().has_focus():
		want = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != want and DisplayServer.get_name() != "headless":
		Input.mouse_mode = want
	player.input_enabled = not ui
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if (cursor_mode and _hover != null and not ui) else Input.CURSOR_ARROW)
	_update_tip()
	crosshair.visible = not ui and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	crosshair.queue_redraw()
	_hint_t -= delta
	hint.visible = _hint_t > 0.0 and not ui
	if hint.visible:
		hint.reset_size()
		hint.position = Vector2((1920.0 - hint.size.x) * 0.5, 1080.0 - hint.size.y - 22.0)
		hint.modulate.a = clampf(_hint_t, 0.0, 1.0)
	# loro
	if pet_kind == "loro":
		_parrot_t -= delta
		if _parrot_t <= 0.0:
			if _parrot_line == "":
				_parrot_line = (PARROT_MEME if GS.mode == "meme" and randf() < 0.7 else PARROT).pick_random()
				_parrot_t = 3.5
			else:
				_parrot_line = ""
				_parrot_t = randf_range(18.0, 35.0)
		if _parrot_lbl != null:
			_parrot_lbl.text = _parrot_line
	# el sillón gira con el presidente sentado en él
	if player.seated and seat_now.get("key", "") == "chair":
		room.chair_body.rotation.y = lerp_angle(room.chair_body.rotation.y, player.yaw, minf(1.0, delta * 10.0))
	# cortinas
	if not is_equal_approx(room.curtain_amount, _curtain_target):
		room.set_curtains(move_toward(room.curtain_amount, _curtain_target, delta / 1.3))
	# pecera
	if aquarium != null:
		aquarium.happy = _pet_happy > 0.0
		aquarium.update(delta)
	if parrot3d != null:
		parrot3d.happy = _pet_happy > 0.0
		parrot3d.update(delta)
	if cat3d != null:
		cat3d.happy = _pet_happy > 0.0
		cat3d.update(delta)
	if dog3d != null:
		dog3d.happy = _pet_happy > 0.0
		dog3d.update(delta)
	if fishbowl3d != null:
		fishbowl3d.happy = _pet_happy > 0.0
		fishbowl3d.update(delta)
	# puerta
	room.door_l.rotation.y = _door_open * deg_to_rad(100.0)
	room.door_r.rotation.y = -_door_open * deg_to_rad(100.0)
	# llamadas a la puerta periódicas
	if GS.visitors.size() > 0 and GS.holds == 0 and GS.speed > 0:
		_knock_t += delta
		if _knock_t > 11.0:
			_knock_t = 0.0
			Sfx.play("knock", -8.0)
	else:
		_knock_t = 0.0
	# ambiente (igual que en el despacho 2D)
	var alert := GS.alerts.size() > 0
	var tod := 0.06
	if alert:
		tod = 0.62
	if GS.campaign and GS.term_days - GS.day < 20:
		tod = 0.78
	var celebrate := GS.flags.has("fiesta") and GS.day - int(GS.flags["fiesta"]) < 6
	if celebrate:
		tod = maxf(tod, 0.7)
	window_view.tod_target = tod
	window_view.celebrate = celebrate
	var protest := clampf((48.0 - GS.approval) / 26.0, 0.0, 1.0)
	for a in GS.alerts:
		if a["ev"].get("crisis", "") in ["disturbios", "huelga_general", "huelga_sanitaria"]:
			protest = maxf(protest, 0.85)
	window_view.protest_target = protest
	_lighting(alert)
	var month: int = UI.date_dict(GS.day)["month"] if GS.active else 5
	exterior.update(delta, window_view.protest, celebrate, window_view.weather, clampf((window_view.tod - 0.45) * 2.0, 0.0, 1.0), month)
	# nubes: avanzan despacio (en el motor compatible, a saltos cada pocos segundos para no recalcular el cielo)
	_cloud_t += delta * 0.006
	if advanced or absf(_cloud_t - _cloud_shift) > 0.02:
		_cloud_shift = _cloud_t
		sky_mat.set_shader_parameter("cloud_shift", _cloud_shift)
	# reloj real, péndulo y globo
	var now := Time.get_time_dict_from_system()
	var hr := (float(now["hour"] % 12) + float(now["minute"]) / 60.0) / 12.0 * TAU
	var mn := (float(now["minute"]) + float(now["second"]) / 60.0) / 60.0 * TAU
	room.clock_hour.rotation.z = -hr
	room.clock_minute.rotation.z = -mn
	room.clock_pendulum.rotation.z = sin(_t * PI) * 0.16
	globe_spin.rotate_y(delta * (0.12 + _globe_boost * 0.8))
	globe_mat.set_shader_parameter("highlight", objs["globe"]._hv)
	# micro, teléfono y vapor del café
	var ready := GS.day >= GS.speech_until
	_mic_led.material_override = _led_on if (ready and (int(_t * 2.0) % 2 == 0 or not GS.active)) else _led_off
	if GS.calls.size() > 0:
		_phone_lcd.text = "ENTRANTE"
		_phone_lcd.modulate = Color(0.55, 1.0, 0.6) if int(_t * 3.0) % 2 == 0 else Color(0.2, 0.45, 0.25)
	else:
		_phone_lcd.text = "LÍNEA LIBRE"
		_phone_lcd.modulate = Color(0.5, 0.85, 0.55, 0.8)
	_steam.emitting = _mug.global_transform.basis.y.dot(Vector3.UP) > 0.8 and _coffee_cd < 20.0
	_update_mirror()


## Coloca la cámara del espejo en el reflejo de la cámara del jugador respecto al plano del
## cristal (punto + normal de room.mirror_point/mirror_normal), y sincroniza el andar del doble
func _update_mirror() -> void:
	if mirror_cam == null:
		return
	var p0: Vector3 = room.mirror_point
	var n: Vector3 = room.mirror_normal
	var cam: Camera3D = player.cam
	var eye := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var up := cam.global_transform.basis.y
	var r_eye := eye - 2.0 * (eye - p0).dot(n) * n
	var r_fwd := fwd - 2.0 * fwd.dot(n) * n
	var r_up := up - 2.0 * up.dot(n) * n
	var fwd_n := r_fwd.normalized()
	# mirando casi derecho hacia arriba o abajo, "arriba" y la dirección de vista casi se alinean
	# y looking_at() no sabe construir una base con eso: a falta de eso, se usa un "arriba" de recambio
	# en vez de dejar la cámara congelada o con una orientación cualquiera durante ese fotograma
	if absf(fwd_n.dot(r_up.normalized())) > 0.999:
		r_up = Vector3.FORWARD if absf(fwd_n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	mirror_cam.global_transform = Transform3D(Basis.looking_at(r_fwd, r_up), r_eye)
	mirror_cam.fov = cam.fov
	if mirror_avatar != null:
		# se recalcula cada fotograma (no solo al sentarse/levantarse) para que nunca se quede
		# "colgado" visible u oculto si algo cambia el estado del jugador sin pasar por sit()/stand()
		var should_show: bool = not player.seated
		if mirror_avatar.visible != should_show:
			mirror_avatar.visible = should_show
		mirror_avatar.walking = should_show and Vector2(player.velocity.x, player.velocity.z).length() > 0.3


func _lighting(alert: bool) -> void:
	var wt: float = window_view.tod
	var night := clampf((wt - 0.3) * 1.4, 0.0, 1.0)
	var storm: float = window_view.storm
	var flash: float = window_view.get("_flash") if window_view.get("_flash") != null else 0.0
	var day := clampf(1.0 - wt * 1.6, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(wt - 0.5) * 3.0, 0.0, 1.0)
	# con las cortinas cerradas apenas entra luz
	var open: float = 1.0 - room.curtain_amount * 0.92
	# sol de día, sol bajo y anaranjado al atardecer, luna de noche (la misma luz direccional)
	var sun_e := (1.7 * day + 1.0 * dusk) * (1.0 - storm * 0.75)
	room.window_light.light_energy = (maxf(sun_e, 0.3 * night) + flash * 6.0) * open
	room.window_light.light_color = Color(1.0, 0.95, 0.86).lerp(Color(1.0, 0.6, 0.36), clampf((wt - 0.2) * 2.5, 0.0, 1.0)).lerp(Color(0.62, 0.7, 0.96), night)
	# cielo y bruma lejana (solo cuando cambian: así el cielo no se recalcula en cada fotograma)
	var sky_state := Vector4(wt, window_view.clouds, storm, flash)
	if not sky_state.is_equal_approx(_sky_state):
		_sky_state = sky_state
		sky_mat.set_shader_parameter("tod", wt)
		sky_mat.set_shader_parameter("clouds", window_view.clouds)
		sky_mat.set_shader_parameter("storm", storm)
		sky_mat.set_shader_parameter("flash", flash * 0.6)
		var hz := Color(0.66, 0.75, 0.86).lerp(Color(0.95, 0.6, 0.42), dusk).lerp(Color(0.05, 0.07, 0.12), night)
		env.fog_light_color = hz.lerp(Color(0.4, 0.42, 0.46) * (1.0 - night * 0.8), storm)
		env.fog_density = {"clear": 0.0018, "clouds": 0.0025, "rain": 0.005, "storm": 0.007, "snow": 0.006, "fog": 0.02}.get(window_view.weather, 0.002)
	room.chandelier_light.light_energy = 1.3 + night * 0.9
	for l in room.sconce_lights:
		(l as OmniLight3D).light_energy = 0.5 + night * 0.6
	# con iluminación global (SDFGI) casi toda la luz ambiente sale de los rebotes reales
	var amb := 0.3 if env.sdfgi_enabled else 1.0
	env.ambient_light_energy = lerpf(0.62, 0.36, night) * amb
	env.ambient_light_color = Color(0.62, 0.52, 0.42).lerp(Color(0.4, 0.42, 0.55), night * 0.6)
	room.beam_mat.set_shader_parameter("strength", day * (1.0 - storm * 0.7) * open)
	room.dust.emitting = day > 0.3 and open > 0.5
	room.dust.visible = day > 0.05 and not low_quality and open > 0.3
	env.volumetric_fog_density = 0.018 * (0.4 + 0.6 * day)
	room.alert_light.light_energy = maxf(0.0, sin(_t * 3.2)) * 1.4 if alert else 0.0
	room.fire_light.light_energy = 1.25 + sin(_t * 13.0) * 0.12 + sin(_t * 7.3) * 0.1 + randf() * 0.08
	_lamp_light.visible = _lamp_on
	_lamp_shade.emission_energy_multiplier = 0.45 if _lamp_on else 0.0
	light_mat.set_shader_parameter("night", night)
	light_mat.set_shader_parameter("alert", 1.0 if alert else 0.0)


func _update_tip() -> void:
	if _hover == null or not is_instance_valid(_hover) or _ui_open():
		tip.visible = false
		return
	var txt: String = _hover.title
	if _hover.status != "":
		txt += "\n" + _hover.status
	if _hover_grab != null and player.held == null:
		txt += "\n[clic derecho: coger]"
	tip_lbl.text = txt
	tip.visible = true
	tip.reset_size()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		tip.position = Vector2(960.0 - tip.size.x * 0.5, 600.0)
	else:
		var mp := get_viewport().get_mouse_position()
		tip.position = mp + Vector2(22, 18)
		if tip.position.x + tip.size.x > 1900:
			tip.position.x = mp.x - tip.size.x - 12


func _draw_crosshair() -> void:
	var c := Vector2(960, 540)
	var active := _hover != null or _hover_grab != null or (player != null and player.held != null)
	if active:
		crosshair.draw_arc(c, 11.0, 0, TAU, 32, Color(UI.GOLD_L, 0.9), 2.0, true)
		crosshair.draw_circle(c, 2.5, Color(UI.GOLD_L, 0.95))
	else:
		crosshair.draw_circle(c, 3.0, Color(0, 0, 0, 0.35))
		crosshair.draw_circle(c, 2.0, Color(1, 1, 1, 0.75))


## Posición en pantalla de un objeto (para los números flotantes); `fallback` si no se ve
func screen_anchor(key: String, fallback: Vector2) -> Vector2:
	if not objs.has(key) or player == null:
		return fallback
	var o = objs[key]
	var p: Vector3 = o.body.global_position + Vector3(0, o.badge_height, 0)
	var cam: Camera3D = player.cam
	if cam.is_position_behind(p):
		return fallback
	var sp := cam.unproject_position(p)
	if sp.x < 40 or sp.x > 1880 or sp.y < 120 or sp.y > 1040:
		return fallback
	return sp
