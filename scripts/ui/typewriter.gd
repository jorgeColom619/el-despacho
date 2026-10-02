extends RichTextLabel
## Texto con efecto máquina de escribir. Clic para completar.

signal typed

var chars_per_sec := 55.0
var _running := false
var _acc := 0.0
var _tick_acc := 0
var sound := true
var on_talk: Callable


func _ready() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mouse_filter = Control.MOUSE_FILTER_PASS


func play(t: String, speed: float = 55.0) -> void:
	text = t
	visible_characters = 0
	chars_per_sec = speed * float(Sfx.settings.get("text_speed", 1.0))
	_running = true
	_acc = 0.0


func skip() -> void:
	if _running:
		visible_characters = -1
		_running = false
		typed.emit()


func is_running() -> bool:
	return _running


func _process(delta: float) -> void:
	if not _running:
		return
	_acc += delta * chars_per_sec
	var n := int(_acc)
	var total := get_total_character_count()
	if n >= total:
		visible_characters = -1
		_running = false
		typed.emit()
		return
	if n != visible_characters:
		visible_characters = n
		_tick_acc += 1
		if sound and _tick_acc % 3 == 0:
			Sfx.play("type", -16.0, 1.0, 0.15)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		skip()
