extends Control
## Base de todas las pantallas superpuestas (minijuegos, paneles). Pausa el tiempo mientras está abierta.

signal closed(result)

var main: Node
var data: Dictionary = {}
var dim: ColorRect
var root: Control
var closing := false
var dim_alpha := 0.72
var pauses_time := true


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	dim = ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.04, dim_alpha)
	UI.full(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	root = Control.new()
	UI.full(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	build()


func build() -> void:
	pass


func close(result = null) -> void:
	if closing:
		return
	closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.22)
	t.tween_callback(func():
		closed.emit(result)
		queue_free())


func title_bar(title: String, subtitle: String = "", icon_name: String = "") -> Control:
	var h := UI.hbox(16)
	if icon_name != "":
		h.add_child(UI.icon_rect(icon_name, 34, UI.GOLD))
	var v := UI.vbox(0)
	if subtitle != "":
		v.add_child(UI.lbl(subtitle.to_upper(), UI.f_sans_b, 14, UI.GOLD))
	v.add_child(UI.lbl(title, UI.f_serif_b, 38, UI.TEXT))
	h.add_child(v)
	return h


func close_button(text: String = "Cerrar") -> Button:
	var b := UI.btn(text, "normal", 18)
	b.pressed.connect(func(): close())
	return b
