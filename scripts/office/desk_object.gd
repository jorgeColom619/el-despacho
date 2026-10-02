extends Control
## Objeto interactivo del despacho: resalta al pasar el ratón, puede vibrar (sonando) y mostrar insignias.

signal activated

var tex: Texture2D
var tex_rect := Rect2()
var title := ""
var status := ""
var badge := ""
var badge_color := UI.RED
var ringing := false
var glow_color := Color(1.0, 0.85, 0.5)
var extra_draw: Callable
var under_draw: Callable
var hover := false
var _hv := 0.0
var _t := 0.0
var enabled := true
var pulse := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func():
		hover = true
		Sfx.play("hover", -12.0))
	mouse_exited.connect(func(): hover = false)
	if tex_rect.size == Vector2.ZERO:
		tex_rect = Rect2(Vector2.ZERO, size)


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Sfx.play("click", -4.0)
		activated.emit()
		accept_event()


var animated := false
var _was_active := true


func _process(delta: float) -> void:
	_t += delta
	var target := 1.0 if hover else 0.0
	var moving := absf(_hv - target) > 0.0001
	_hv = move_toward(_hv, target, delta * 6.0)
	var active := animated or ringing or pulse or badge != "" or moving
	if active or _was_active:
		queue_redraw()
	_was_active = active


func _draw() -> void:
	var lift := -4.0 * _hv
	var shake := Vector2.ZERO
	if ringing:
		var ph := fmod(_t, 1.0)
		if ph < 0.55:
			shake = Vector2(sin(_t * 70.0) * 2.5, -absf(sin(_t * 35.0)) * 2.0)
	var glow_a := _hv * 0.28
	if ringing or pulse:
		glow_a = maxf(glow_a, 0.18 + 0.18 * sin(_t * 6.0))
	if glow_a > 0.01:
		var c := size * 0.5
		for i in 6:
			var rr := (1.0 - i / 6.0)
			_ellipse(c + Vector2(0, size.y * 0.12), Vector2(size.x * 0.62, size.y * 0.5) * (0.6 + rr * 0.6), Color(glow_color, glow_a * 0.12))
	if under_draw.is_valid():
		under_draw.call(self)
	draw_set_transform(Vector2(0, lift) + shake, 0.0, Vector2.ONE)
	if tex != null:
		var mod := Color(1, 1, 1).lerp(Color(1.15, 1.12, 1.05), _hv)
		draw_texture_rect(tex, tex_rect, false, mod)
	if extra_draw.is_valid():
		extra_draw.call(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if ringing:
		for i in 3:
			var ph2 := fmod(_t * 1.2 + i / 3.0, 1.0)
			draw_arc(size * 0.5 + Vector2(0, -size.y * 0.1), 30.0 + ph2 * size.x * 0.6, 0, TAU, 48, Color(glow_color, 0.5 * (1.0 - ph2)), 2.5, true)
	if badge != "":
		var bp := Vector2(size.x - 18, 14)
		var sc := 1.0 + 0.12 * sin(_t * 5.0)
		draw_circle(bp, 17 * sc, Color(0, 0, 0, 0.35))
		draw_circle(bp, 15 * sc, badge_color)
		draw_arc(bp, 15 * sc, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0, true)
		draw_string(UI.f_sans_b, bp + Vector2(-15, 7), badge, HORIZONTAL_ALIGNMENT_CENTER, 30, 19, Color.WHITE)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)
