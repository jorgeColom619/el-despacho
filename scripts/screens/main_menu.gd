extends Control
## Menú principal.

const Backdrop := preload("res://scripts/screens/backdrop.gd")
const OfficeArt := preload("res://scripts/office/office_art.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const Reto := preload("res://scripts/systems/reto.gd")
const Promesas := preload("res://scripts/systems/promesas.gd")
const W := preload("res://scripts/data/world_data.gd")
const SC := preload("res://scripts/data/scenarios_data.gd")

var main: Node
var menu_box: VBoxContainer
var modal: Control
var _t := 0.0
var title_lbl: Label


func _ready() -> void:
	UI.full(self)
	add_child(Backdrop.new())
	var left := UI.vbox(0)
	left.position = Vector2(150, 150)
	left.size = Vector2(760, 800)
	add_child(left)
	var seal := TextureRect.new()
	seal.texture = OfficeArt.tex("seal", 0.8)
	seal.custom_minimum_size = Vector2(120, 120)
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	seal.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(seal)
	left.add_child(UI.spacer(0, 16))
	left.add_child(UI.lbl("REPÚBLICA DE VALDORIA", UI.f_sans_b, 18, UI.GOLD))
	title_lbl = UI.lbl("El Despacho", UI.f_serif_k, 118, UI.CREAM)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title_lbl.add_theme_constant_override("shadow_offset_x", 0)
	title_lbl.add_theme_constant_override("shadow_offset_y", 6)
	title_lbl.add_theme_constant_override("shadow_outline_size", 12)
	left.add_child(title_lbl)
	var sub := UI.lbl("Gobierna. Negocia. Sobrevive.", UI.f_serif, 30, UI.GOLD_L)
	left.add_child(sub)
	left.add_child(UI.spacer(0, 50))
	menu_box = UI.vbox(6)
	left.add_child(menu_box)
	_item("Nueva legislatura", func(): main.show_new_game())
	_item("Reto del día", _open_daily)
	if GS.has_save():
		_item("Continuar partida", func(): main.continue_game())
	_item("Tienda", func(): main.show_shop())
	_item("Opciones", _open_settings)
	_item("Créditos", _open_credits)
	_item("Salir", func(): get_tree().quit())
	var rec := float(Perfil.stats.get("record_anios", 0.0))
	var bal := UI.lbl("%s Laureles  ·  %s Lingotes  ·  %d/%d logros%s" % [UI.num(Perfil.laureles), UI.num(Perfil.lingotes), Perfil.achievements.size(), Perfil.S.ACHIEVEMENTS.size(), ("  ·  Récord en modo infinito: %s años" % UI.num(rec, 1)) if rec > 0.0 else ""], UI.f_sans_m, 18, UI.GOLD_L)
	bal.position = Vector2(150, 990)
	add_child(bal)
	# la versión sale de project.godot (al publicar una versión, la pone el flujo de GitHub a partir de la etiqueta)
	var foot := UI.lbl("v%s  ·  F11 pantalla completa  ·  Hecho con Godot" % str(ProjectSettings.get_setting("application/config/version", "")), UI.f_sans, 15, Color(UI.DIM, 0.7))
	foot.position = Vector2(150, 1030)
	add_child(foot)
	var quote := UI.lbl("«Gobernar es elegir entre inconvenientes.»", UI.f_serif, 22, Color(UI.CREAM, 0.55))
	quote.position = Vector2(1180, 1000)
	add_child(quote)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.2)


func _item(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", UI.f_serif_b)
	b.add_theme_font_size_override("font_size", 38)
	b.add_theme_color_override("font_color", Color(UI.CREAM, 0.82))
	b.add_theme_color_override("font_hover_color", UI.GOLD_L)
	b.add_theme_color_override("font_pressed_color", UI.GOLD)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, empty)
	b.custom_minimum_size = Vector2(420, 58)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var line := ColorRect.new()
	line.color = UI.GOLD
	line.position = Vector2(0, 54)
	line.size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(line)
	b.mouse_entered.connect(func():
		Sfx.play("hover", -6.0)
		b.create_tween().tween_property(line, "size:x", 300.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(line, "size:x", 0.0, 0.2))
	b.pressed.connect(func():
		Sfx.play("click", -2.0)
		cb.call())
	menu_box.add_child(b)


func _modal(content: Control) -> void:
	if modal != null:
		modal.queue_free()
	modal = Control.new()
	UI.full(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	UI.full(dim)
	modal.add_child(dim)
	var cc := CenterContainer.new()
	UI.full(cc)
	cc.add_child(content)
	modal.add_child(cc)
	add_child(modal)
	UI.pop_in(content)


func _open_settings() -> void:
	var p := SettingsPanel.new()
	p.done.connect(func():
		modal.queue_free()
		modal = null)
	_modal(p)


## El reto de hoy: lo mismo para todos, con dos reglas especiales
func _open_daily() -> void:
	var idx := Reto.today()
	var s := Reto.spec(idx)
	var p := UI.panel(Color(0.035, 0.05, 0.085, 0.98), 12, Color(UI.GOLD, 0.6), 30)
	p.custom_minimum_size = Vector2(900, 0)
	var v := UI.vbox(12)
	p.add_child(v)
	var d := Time.get_date_dict_from_system()
	v.add_child(UI.lbl("RETO DEL DÍA · %d DE %s DE %d" % [int(d["day"]), UI.MONTHS[int(d["month"]) - 1].to_upper(), int(d["year"])], UI.f_sans_b, 15, UI.GOLD))
	v.add_child(UI.lbl("La misma partida para todos", UI.f_serif_b, 40, UI.TEXT))
	var info := UI.lbl("Presidente: %s  ·  Partido: %s  ·  Escenario: %s  ·  Legislatura de %s  ·  Dificultad normal" % [s["name"], W.PARTIES[s["party"]]["name"], SC.SCENARIOS[s["scenario"]]["name"], "nueve meses" if "anticipadas" in s["rules"] else "un año"], UI.f_sans_m, 18, UI.DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(840, 0)
	v.add_child(info)
	v.add_child(UI.lbl("REGLAS DE HOY", UI.f_sans_b, 14, UI.GOLD))
	for r in s["rules"]:
		var rd: Dictionary = Reto.D.RULES[r]
		var h := UI.hbox(12)
		h.add_child(UI.icon_rect(rd["icon"], 30, UI.GOLD_L))
		var tv := UI.vbox(0)
		tv.add_child(UI.lbl(rd["name"], UI.f_sans_b, 20, UI.TEXT))
		var dl := UI.lbl(rd["desc"], UI.f_sans, 17, UI.DIM)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(780, 0)
		tv.add_child(dl)
		h.add_child(tv)
		v.add_child(h)
	v.add_child(UI.lbl("SUS PROMESAS (OBLIGATORIAS)", UI.f_sans_b, 14, UI.GOLD))
	for pid in s["promises"]:
		v.add_child(UI.lbl("«%s»" % Promesas.def(pid)["name"], UI.f_serif, 21, UI.CREAM))
	var best := Reto.best_today()
	var st := Reto.streak()
	v.add_child(UI.lbl(("Su mejor puntuación hoy: %d" % best if best >= 0 else "Aún no lo ha jugado hoy.") + ("   ·   Racha: %d día%s seguidos" % [st, "" if st == 1 else "s"] if st > 0 else ""), UI.f_sans_b, 19, UI.GOLD_L))
	var bh := UI.hbox(14)
	bh.add_child(UI.spacer(0, 0, true))
	var close_b := UI.btn("Cerrar", "normal")
	close_b.pressed.connect(func():
		modal.queue_free()
		modal = null)
	bh.add_child(close_b)
	var go := UI.btn("Jugar el reto", "gold", 22)
	go.pressed.connect(func():
		Sfx.play("whoosh", -2.0)
		main.start_new(Reto.game_opts(idx)))
	bh.add_child(go)
	v.add_child(bh)
	_modal(p)


func _open_credits() -> void:
	var p := UI.panel(Color(0.035, 0.05, 0.085, 0.98), 12, Color(UI.GOLD, 0.6), 30)
	p.custom_minimum_size = Vector2(700, 0)
	var v := UI.vbox(14)
	p.add_child(v)
	v.add_child(UI.lbl("Créditos", UI.f_serif_b, 40, UI.TEXT))
	var r := UI.rich("[b]El Despacho[/b] — simulador presidencial.\n\nDiseño, programación, arte vectorial, música y efectos sintetizados: generados íntegramente por código para este proyecto.\n\nTipografías: Playfair Display, Inter, Oswald, Special Elite, Caveat, UnifrakturMaguntia, Share Tech Mono y Mrs Saint Delafield (Google Fonts, licencias OFL/Apache).\n\nMotor: Godot Engine.\n\nTodos los países, partidos y personajes son ficticios. Cualquier parecido con la realidad es... bastante probable.", 19, UI.TEXT)
	r.custom_minimum_size = Vector2(640, 0)
	v.add_child(r)
	var b := UI.btn("Cerrar", "gold")
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.pressed.connect(func():
		modal.queue_free()
		modal = null)
	v.add_child(b)
	_modal(p)
