extends Control
## Notificaciones emergentes y números flotantes.

var _stack: VBoxContainer
var _last_text := ""
var _last_time := 0


func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack = UI.vbox(8)
	_stack.alignment = BoxContainer.ALIGNMENT_END
	_stack.position = Vector2(1360, 560)
	_stack.size = Vector2(540, 500)
	add_child(_stack)
	GS.toast.connect(push)


func push(text: String, kind: String = "info", icon_name: String = "info") -> void:
	var now := Time.get_ticks_msec()
	if text == _last_text and now - _last_time < 1500:
		return
	_last_text = text
	_last_time = now
	var col: Color = {"good": UI.GREEN, "bad": UI.RED, "warn": UI.AMBER, "info": UI.GOLD}.get(kind, UI.GOLD)
	var p := PanelContainer.new()
	var st := UI.sb(Color(0.035, 0.05, 0.085, 0.95), 8, Color(col, 0.7), 1, 10)
	st.border_width_left = 5
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UI.hbox(12)
	h.add_child(UI.icon_rect(icon_name, 24, col))
	var l := UI.lbl(text, UI.f_sans_m, 18, UI.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	p.add_child(h)
	_stack.add_child(p)
	while _stack.get_child_count() > 4:
		var old := _stack.get_child(0)
		_stack.remove_child(old)
		old.queue_free()
	p.modulate.a = 0.0
	var t := p.create_tween()
	t.tween_property(p, "modulate:a", 1.0, 0.25)
	t.tween_interval(5.5)
	t.tween_property(p, "modulate:a", 0.0, 0.6)
	t.tween_callback(p.queue_free)


func float_text(pos: Vector2, text: String, col: Color, fsize: int = 26) -> void:
	var l := UI.lbl(text, UI.f_cond_b, fsize, col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos - Vector2(40, 10)
	l.size = Vector2(80, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	l.scale = Vector2(0.6, 0.6)
	l.pivot_offset = Vector2(40, 15)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "position:y", l.position.y + 58.0, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(1.1)
	t.chain().tween_callback(l.queue_free)
