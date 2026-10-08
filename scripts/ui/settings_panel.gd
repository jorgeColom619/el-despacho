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
	# en el navegador solo hay despacho 2D y motor compatible: sin ajustes del 3D ni del motor gráfico
	var web := OS.has_feature("web")
	if not web:
		_slider(v, "Sensibilidad del ratón", "mouse_sens", 0.2, 3.0)
	_check(v, "Pantalla completa (F11)", "fullscreen")
	_check(v, "Grano cinematográfico", "grain")
	if not web:
		_graphics(v)
	var b := UI.btn("Aceptar", "gold", 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.pressed.connect(func(): done.emit())
	v.add_child(b)


## Despacho 3D, calidad gráfica y motor gráfico (con el aviso de reinicio)
func _graphics(v: Control) -> void:
	_check(v, "Despacho en 3D (desactívelo en equipos lentos)", "view3d")
	_option(v, "Calidad gráfica", "gfx", [["auto", "Automática (%s)" % Sfx.gfx_preset().capitalize()], ["baja", "Baja"], ["media", "Media"], ["alta", "Alta"], ["ultra", "Ultra"]])
	_option(v, "Motor gráfico", "engine", [["auto", "Automático"], ["avanzado", "Avanzado (Forward+)"], ["compatible", "Compatible (sin tarjeta gráfica)"]])
	var note := UI.lbl("", UI.f_sans, 15, UI.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(560, 0)
	v.add_child(note)
	var rb := UI.btn("Reiniciar ahora para cambiar de motor", "normal", 17)
	rb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rb.pressed.connect(func():
		if GS.active and not GS.no_save:
			GS.save_game()
		Sfx.restart_game())
	v.add_child(rb)
	var refresh := func():
		var cur := RenderingServer.get_current_rendering_method()
		var want := Sfx.wanted_renderer()
		var names := {"forward_plus": "avanzado (Forward+)", "gl_compatibility": "compatible", "mobile": "móvil"}
		var txt := "Motor en uso: %s." % names.get(cur, cur)
		if cur != want:
			txt += " El cambio a %s se aplicará al reiniciar el juego." % names.get(want, want)
		elif cur == "forward_plus":
			txt += " Calidad Alta y Ultra: iluminación global, oclusión ambiental, reflejos y rayos de luz."
		else:
			txt += " Las calidades Alta y Ultra necesitan el motor avanzado y una tarjeta gráfica."
		note.text = txt
		rb.visible = cur != want
	refresh.call()
	set_meta("refresh", refresh)


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
			Sfx.play("click", 0.0)
		if key == "mouse_sens":
			var main := get_tree().root.get_node_or_null("Main")
			if main != null and main.get("office") != null and main.office.get("player") != null:
				main.office.player.sens = val)
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
		var main := get_tree().root.get_node_or_null("Main")
		if key == "grain":
			if main != null and main.get("grain") != null:
				main.grain.visible = on
		if key == "view3d" and main != null and main.has_method("swap_office"):
			main.swap_office())
	parent.add_child(c)


func _option(parent: Control, label: String, key: String, items: Array) -> void:
	var h := UI.hbox(20)
	var l := UI.lbl(label, UI.f_sans_m, 20, UI.TEXT)
	l.custom_minimum_size = Vector2(240, 0)
	h.add_child(l)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.add_theme_font_size_override("font_size", 18)
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in items.size():
		ob.add_item(items[i][1], i)
		if str(Sfx.settings.get(key, "auto")) == items[i][0]:
			ob.select(i)
	ob.item_selected.connect(func(idx):
		Sfx.set_setting(key, items[idx][0])
		var main := get_tree().root.get_node_or_null("Main")
		if key == "gfx" and main != null and main.get("office") != null and main.office.has_method("apply_quality"):
			main.office.apply_quality()
		if key == "engine":
			Sfx.write_renderer_override(Sfx.wanted_renderer())
		if has_meta("refresh"):
			(get_meta("refresh") as Callable).call())
	h.add_child(ob)
	parent.add_child(h)
