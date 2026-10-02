extends Control
## Barra de cuenta atrás con aviso sonoro al final.

signal timeout

var total := 10.0
var left := 10.0
var running := false
var label := ""
var _last_tick := -1


func start(seconds: float, text: String = "") -> void:
	total = maxf(0.1, seconds)
	left = total
	running = true
	label = text
	_last_tick = -1
	visible = true


func stop() -> void:
	running = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(200, 10)


func _process(delta: float) -> void:
	if running:
		left -= delta
		var sec := int(ceil(left))
		if left < 4.0 and sec != _last_tick and sec > 0:
			_last_tick = sec
			Sfx.play("tick", -4.0, 1.0 + (4 - sec) * 0.08)
		if left <= 0.0:
			left = 0.0
			running = false
			timeout.emit()
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(1, 1, 1, 0.08))
	var f := clampf(left / total, 0.0, 1.0)
	var col := UI.GOLD
	if f < 0.25:
		col = UI.RED if int(Time.get_ticks_msec() / 150) % 2 == 0 else UI.RED.lightened(0.3)
	elif f < 0.5:
		col = UI.AMBER
	draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), col)
	if label != "":
		draw_string(UI.f_sans_b, Vector2(0, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.DIM)
		draw_string(UI.f_cond_b, Vector2(0, -6), "%d s" % int(ceil(left)), HORIZONTAL_ALIGNMENT_RIGHT, size.x, 16, col)
