extends PanelContainer
## Panel de opciones (audio, vídeo, texto).

signal done


func _ready() -> void:
	add_theme_stylebox_override("panel", UI.sb(Color(0.035, 0.05, 0.085, 0.98), 12, Color(UI.GOLD, 0.6), 1, 24, 30))
	custom_minimum_size = Vector2(620, 0)
	var v := UI.vbox(18)
	add_child(v)
	v.add_child(UI.lbl("Opciones", UI.f_serif_b, 40, UI.TEXT))
	var line := ColorRect.new()
	line.color = Color(UI.GOLD, 0.4)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	_slider(v, "Volumen general", "master")
	_slider(v, "Música", "music")
	_slider(v, "Efectos", "sfx")
	_slider(v, "Velocidad del texto", "text_speed", 0.5, 3.0)
	_check(v, "Pantalla completa (F11)", "fullscreen")
	_check(v, "Grano cinematográfico", "grain")
	var b := UI.btn("Aceptar", "gold", 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.pressed.connect(func(): done.emit())
	v.add_child(b)


func _slider(parent: Control, label: String, key: String, lo: float = 0.0, hi: float = 1.0) -> void:
	var h := UI.hbox(20)
	var l := UI.lbl(label, UI.f_sans_m, 20, UI.TEXT)
	l.custom_minimum_size = Vector2(240, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = float(Sfx.settings.get(key, 1.0))
	s.custom_minimum_size = Vector2(300, 28)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(val):
		Sfx.set_setting(key, val)
		if key == "sfx":
			Sfx.play("click", 0.0))
	h.add_child(s)
	parent.add_child(h)


func _check(parent: Control, label: String, key: String) -> void:
	var c := CheckBox.new()
	c.text = label
	c.button_pressed = bool(Sfx.settings.get(key, false))
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 20)
	c.toggled.connect(func(on):
		Sfx.set_setting(key, on)
		if key == "grain":
			var main := get_tree().root.get_node_or_null("Main")
			if main != null and main.get("grain") != null:
				main.grain.visible = on)
	parent.add_child(c)
