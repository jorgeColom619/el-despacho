extends Node
## Gestor de audio: efectos con pool de reproductores, bucles y música con fundido cruzado.

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_idx := 0
var _loops := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_on_a := true
var current_music := ""
var settings := {"master": 0.85, "music": 0.55, "sfx": 0.9, "fullscreen": false, "grain": true, "text_speed": 1.0, "view3d": true, "stage3d": true, "mouse_sens": 1.0, "gfx": "auto", "engine": "auto", "aviso_motor": false}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus("Music")
	_bus("SFX")
	_bus("Amb")
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	add_child(_music_b)
	load_settings()
	_check_renderer()


func _bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")


func stream(sname: String) -> AudioStream:
	if not _streams.has(sname):
		var path := "res://audio/%s.wav" % sname
		if ResourceLoader.exists(path):
			_streams[sname] = load(path)
		else:
			_streams[sname] = null
	return _streams[sname]


func _looped(sname: String) -> AudioStream:
	var key := sname + "#loop"
	if _streams.has(key):
		return _streams[key]
	var s := stream(sname)
	if s == null:
		return null
	var d: AudioStream = s.duplicate()
	if d is AudioStreamWAV:
		var w := d as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate) - 1
	_streams[key] = d
	return d


func play(sname: String, vol_db: float = 0.0, pitch: float = 1.0, rand_pitch: float = 0.0) -> void:
	var s := stream(sname)
	if s == null:
		return
	var p: AudioStreamPlayer = null
	for i in _pool.size():
		var cand := _pool[(_pool_idx + i) % _pool.size()]
		if not cand.playing:
			p = cand
			break
	if p == null:
		p = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _pool.size()
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = maxf(0.1, pitch + randf_range(-rand_pitch, rand_pitch))
	p.play()


func loop_start(key: String, sname: String, vol_db: float = 0.0, bus: String = "SFX") -> void:
	if _loops.has(key):
		var existing: AudioStreamPlayer = _loops[key]
		if is_instance_valid(existing):
			existing.volume_db = vol_db
			return
	var s := _looped(sname)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.stream = s
	p.volume_db = vol_db
	add_child(p)
	p.play()
	_loops[key] = p


func loop_stop(key: String, fade: float = 0.25) -> void:
	if not _loops.has(key):
		return
	var p: AudioStreamPlayer = _loops[key]
	_loops.erase(key)
	if not is_instance_valid(p):
		return
	var t := create_tween()
	t.tween_property(p, "volume_db", -60.0, fade)
	t.tween_callback(p.queue_free)


func loop_volume(key: String, vol_db: float) -> void:
	if _loops.has(key) and is_instance_valid(_loops[key]):
		_loops[key].volume_db = vol_db


func is_looping(key: String) -> bool:
	return _loops.has(key)


func music(mname: String, fade: float = 1.5, vol_db: float = 0.0) -> void:
	if mname == current_music:
		return
	current_music = mname
	var incoming := _music_b if _music_on_a else _music_a
	var outgoing := _music_a if _music_on_a else _music_b
	_music_on_a = not _music_on_a
	if outgoing.playing:
		var t := create_tween()
		t.tween_property(outgoing, "volume_db", -50.0, fade)
		t.tween_callback(outgoing.stop)
	if mname == "":
		return
	var s := _looped(mname)
	if s == null:
		return
	incoming.stream = s
	incoming.volume_db = -50.0
	incoming.play()
	var t2 := create_tween()
	t2.tween_property(incoming, "volume_db", vol_db, fade)


func set_setting(key: String, value) -> void:
	settings[key] = value
	_apply()
	save_settings()


func _apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, settings["master"])))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, settings["music"])))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, settings["sfx"])))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Amb"), linear_to_db(maxf(0.0001, settings["sfx"] * 0.8)))
	var want_fs: bool = settings["fullscreen"]
	var is_fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if want_fs != is_fs and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_fs else DisplayServer.WINDOW_MODE_WINDOWED)


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings.keys():
		cf.set_value("settings", k, settings[k])
	cf.save("user://settings.cfg")


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		for k in settings.keys():
			settings[k] = cf.get_value("settings", k, settings[k])
		# antes una sola opción decidía el despacho y los minijuegos: quien la tenía quitada sigue igual
		if not cf.has_section_key("settings", "stage3d"):
			settings["stage3d"] = settings["view3d"]
	_apply()


# ------------------------------------------------------------------ gráficos

## Calidad gráfica efectiva del despacho 3D: "baja", "media", "alta" o "ultra"
func gfx_preset() -> String:
	var g: String = str(settings.get("gfx", "auto"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gfx="):
			g = a.substr(6)
	if g in ["baja", "media", "alta", "ultra"]:
		return g
	if software_renderer():
		return "baja"
	return "alta" if RenderingServer.get_current_rendering_method() == "forward_plus" else "media"


## Motor gráfico que debería usarse según las opciones ("forward_plus" o "gl_compatibility")
func wanted_renderer() -> String:
	match str(settings.get("engine", "auto")):
		"avanzado":
			return "forward_plus"
		"compatible":
			return "gl_compatibility"
	# En Mac, el compatible: con el avanzado (Metal o MoltenVK) algunos Mac se quedaban con la pantalla en negro
	# y solo sonaba la música. project.godot ya arranca así en Mac (rendering_method.macos).
	if OS.has_feature("macos"):
		return "gl_compatibility"
	return "gl_compatibility" if software_renderer() else "forward_plus"


## false si la última vez no se pudo guardar override.cfg (p. ej., la app de Mac sin mover a Aplicaciones)
var override_ok := true


## Escribe override.cfg con el motor gráfico elegido (se aplica al arrancar el juego). Lleva también la clave
## «.macos», que en Mac manda sobre la normal (project.godot pone el compatible por defecto ahí).
func write_renderer_override(method: String) -> bool:
	var path := ProjectSettings.globalize_path("res://override.cfg")
	if OS.has_feature("template"):
		path = OS.get_executable_path().get_base_dir().path_join("override.cfg")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		override_ok = false
		return false
	f.store_string("; Motor gráfico elegido en Opciones de El Despacho\n[rendering]\n\nrenderer/rendering_method=\"%s\"\nrenderer/rendering_method.macos=\"%s\"\n" % [method, method])
	f.close()
	override_ok = true
	return true


## Reinicia el juego (para cambiar de motor gráfico). El motor va también en la orden de arranque, así funciona
## aunque no se haya podido guardar override.cfg.
func restart_game() -> void:
	var engine_args := []
	var raw := OS.get_cmdline_args()
	var i := 0
	while i < raw.size():
		var a := String(raw[i])
		if a == "--" or a == "++":
			break
		if a == "--rendering-method" or a == "--rendering-driver":
			i += 2
			continue
		engine_args.append(a)
		i += 1
	engine_args.append_array(["--rendering-method", wanted_renderer()])
	var user := Array(OS.get_cmdline_user_args())
	if not "--gfx-restarted" in user:
		user.append("--gfx-restarted")
	OS.set_restart_on_exit(true, engine_args + ["--"] + user)
	get_tree().quit()


## Al arrancar: si el motor gráfico no es el adecuado (p. ej. Forward+ sin tarjeta gráfica, que iría a 1-2 FPS),
## guarda el correcto y reinicia una sola vez
func _check_renderer() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var user := OS.get_cmdline_user_args()
	if "--gfx-restarted" in user or "--no-gfx-guard" in user or "--rendering-method" in OS.get_cmdline_args():
		return
	var want := wanted_renderer()
	if RenderingServer.get_current_rendering_method() == want:
		return
	if write_renderer_override(want):
		restart_game()


var _vigilada := false


## Red de seguridad para la pantalla en negro: con el menú ya a la vista, mira dos veces lo que se ha dibujado.
## Si sale una imagen lisa y oscura (el motor avanzado no pinta nada aunque el juego siga y suene la música, como
## pasaba en algunos Mac), cambia al motor compatible, lo guarda y reinicia. Una sola vez por arranque.
func vigilar_pantalla() -> void:
	if _vigilada or DisplayServer.get_name() == "headless":
		return
	_vigilada = true
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return
	var user := OS.get_cmdline_user_args()
	var debug := "--gfx-guard-debug" in user
	for a in user:
		if (a.begins_with("--shot") or a.begins_with("--capt") or a.begins_with("--autotest") or a in ["--no-gfx-guard", "--uitest", "--check"]) and not debug:
			return
	var oscuras := 0
	for intento in 2:
		await get_tree().create_timer(2.5 if intento == 0 else 1.2).timeout
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
			return
		await RenderingServer.frame_post_draw
		var r := _medir_imagen()
		if debug:
			print("Vigilancia de pantalla: luz máxima %.3f, contraste %.3f" % [r[0], r[1]])
		if r[0] >= 0.0 and r[0] < 0.16 and r[1] < 0.04:
			oscuras += 1
	if oscuras < 2:
		return
	print("La pantalla sale en negro con el motor %s: se cambia al compatible" % RenderingServer.get_current_rendering_method())
	settings["engine"] = "compatible"
	settings["aviso_motor"] = true
	save_settings()
	write_renderer_override("gl_compatibility")
	if not debug:
		restart_game()


## [luminosidad máxima, diferencia entre lo más claro y lo más oscuro] de lo que se ve (-1 si no se puede leer)
func _medir_imagen() -> Array:
	var tex := get_viewport().get_texture()
	if tex == null:
		return [-1.0, 1.0]
	var img := tex.get_image()
	if img == null or img.is_empty():
		return [-1.0, 1.0]
	var w := img.get_width()
	var h := img.get_height()
	var hi := 0.0
	var lo := 1.0
	for gy in 36:
		for gx in 64:
			var l := img.get_pixel(int((gx + 0.5) * w / 64.0), int((gy + 0.5) * h / 36.0)).get_luminance()
			hi = maxf(hi, l)
			lo = minf(lo, l)
	return [hi, hi - lo]


## true si no hay aceleración gráfica (máquina virtual, controlador básico de Windows...)
static func software_renderer() -> bool:
	var n := RenderingServer.get_video_adapter_name().to_lower()
	for s in ["basic render", "llvmpipe", "swiftshader", "softpipe", "warp"]:
		if s in n:
			return true
	return false
