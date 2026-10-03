extends Control
## Notificaciones emergentes y números flotantes.
## Las notificaciones son notas de papel arriba a la izquierda (sobre la ventana, sin tapar la mesa)
## y los números flotantes se agrupan por indicador para no amontonarse.

const PAPER := Color(0.94, 0.9, 0.8, 0.97)
const INK := Color("2b2319")
const MAX_TOASTS := 3

var _stack: VBoxContainer
var _last_text := ""
var _last_time := 0
var _floats := {}


func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack = UI.vbox(8)
	_stack.position = Vector2(18, 114)
	_stack.size = Vector2(500, 420)
	add_child(_stack)
	GS.toast.connect(push)


func push(text: String, kind: String = "info", icon_name: String = "info") -> void:
	var now := Time.get_ticks_msec()
	if text == _last_text and now - _last_time < 1500:
		return
	_last_text = text
	_last_time = now
	var col: Color = {"good": Color("3f7d3a"), "bad": Color("a8322a"), "warn": Color("b0741a"), "info": Color("8a6d33")}.get(kind, Color("8a6d33"))
	var p := PanelContainer.new()
	var st := UI.sb(PAPER, 4, Color(col, 0.9), 1, 8)
	st.border_width_left = 6
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 8
	st.shadow_offset = Vector2(2, 4)
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UI.hbox(10)
	h.add_child(UI.icon_rect(icon_name, 22, col))
	var l := UI.lbl(text, UI.f_serif, 17, INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	p.add_child(h)
	_stack.add_child(p)
	_stack.move_child(p, 0)
	while _stack.get_child_count() > MAX_TOASTS:
		var old := _stack.get_child(_stack.get_child_count() - 1)
		_stack.remove_child(old)
		old.queue_free()
	p.modulate.a = 0.0
	p.rotation = deg_to_rad(randf_range(-0.8, 0.8))
	var t := p.create_tween()
	t.tween_property(p, "modulate:a", 1.0, 0.2)
	t.tween_interval(4.8)
	t.tween_property(p, "modulate:a", 0.0, 0.5)
	t.tween_callback(p.queue_free)


func float_text(pos: Vector2, text: String, col: Color, fsize: int = 26) -> void:
	var l := _make_label(text, col, fsize)
	_animate(l, pos)


## Número flotante agrupado: si el mismo indicador cambia varias veces seguidas, se suma en un solo número
func float_delta(key: String, pos: Vector2, v: float, fmt: Callable, good: Color, bad: Color, fsize: int = 22) -> void:
	var now := Time.get_ticks_msec()
	if _floats.has(key):
		var e: Dictionary = _floats[key]
		var old_l = e["l"]
		if is_instance_valid(old_l) and now - int(e["t"]) < 1500:
			e["v"] = float(e["v"]) + v
			e["t"] = now
			var lab: Label = old_l
			lab.text = fmt.call(float(e["v"]))
			lab.add_theme_color_override("font_color", good if float(e["v"]) > 0 else bad)
			_animate(lab, pos)
			return
	var l := _make_label(fmt.call(v), good if v > 0 else bad, fsize)
	_floats[key] = {"l": l, "v": v, "t": now}
	_animate(l, pos)


func _make_label(text: String, col: Color, fsize: int) -> Label:
	var l := UI.lbl(text, UI.f_serif_b, fsize, col)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.size = Vector2(120, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(60, 15)
	add_child(l)
	return l


func _animate(l: Label, pos: Vector2) -> void:
	if l.has_meta("tw"):
		var old: Tween = l.get_meta("tw")
		if old != null and old.is_valid():
			old.kill()
	l.position = pos - Vector2(60, 0)
	l.modulate.a = 1.0
	l.scale = Vector2(0.7, 0.7)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "position:y", pos.y - 24.0, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(1.1)
	t.chain().tween_callback(l.queue_free)
	l.set_meta("tw", t)
