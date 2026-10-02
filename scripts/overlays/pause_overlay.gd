extends "res://scripts/ui/overlay.gd"
## Menú de pausa.

const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

var box: Control


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.85)
	_menu()


func _menu() -> void:
	if box != null:
		box.queue_free()
	var cc := CenterContainer.new()
	UI.full(cc)
	root.add_child(cc)
	box = cc
	var p := UI.panel(Color(0.035, 0.05, 0.085, 0.98), 12, Color(UI.GOLD, 0.6), 34)
	p.custom_minimum_size = Vector2(520, 0)
	cc.add_child(p)
	var v := UI.vbox(12)
	p.add_child(v)
	v.add_child(UI.lbl("Pausa", UI.f_serif_b, 46, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.lbl(UI.date_long(GS.day), UI.f_sans_m, 17, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer(0, 10))
	for spec in [["Continuar", "gold"], ["Guardar partida", "normal"], ["Opciones", "normal"], ["Guardar y salir al menú", "normal"], ["Salir del juego", "ghost"]]:
		var b := UI.btn(spec[0], spec[1], 21)
		b.custom_minimum_size = Vector2(440, 54)
		var label: String = spec[0]
		b.pressed.connect(func(): _act(label))
		v.add_child(b)
	UI.pop_in(p)


func _act(label: String) -> void:
	match label:
		"Continuar":
			close()
		"Guardar partida":
			GS.save_game()
			GS.toast.emit("Partida guardada", "good", "guardar")
		"Opciones":
			box.queue_free()
			var cc := CenterContainer.new()
			UI.full(cc)
			root.add_child(cc)
			box = cc
			var sp := SettingsPanel.new()
			sp.done.connect(func(): _menu())
			cc.add_child(sp)
		"Guardar y salir al menú":
			GS.save_game()
			close()
			if main != null:
				main.transition(func(): main.show_menu())
		"Salir del juego":
			GS.save_game()
			get_tree().quit()


func on_escape() -> void:
	close()
