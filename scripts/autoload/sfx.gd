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
var settings := {"master": 0.85, "music": 0.55, "sfx": 0.9, "fullscreen": false, "grain": true, "text_speed": 1.0}


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
	_apply()
