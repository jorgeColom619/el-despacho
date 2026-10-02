extends Control
## Fondo cinematográfico: el despacho de noche, con lluvia y un lento movimiento de cámara.

const OfficeArt := preload("res://scripts/office/office_art.gd")
const WindowView := preload("res://scripts/office/window_view.gd")

var cam: Control
var _t := 0.0
var darkness := 0.55


func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	cam = Control.new()
	cam.size = Vector2(1920, 1080)
	cam.pivot_offset = Vector2(960, 540)
	cam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cam)
	var wv := WindowView.new()
	wv.position = Vector2(96, 126)
	wv.size = Vector2(408, 470)
	wv.tod = 0.92
	wv.tod_target = 0.92
	wv.weather = "rain"
	cam.add_child(wv)
	for n in ["room"]:
		var r := TextureRect.new()
		r.texture = OfficeArt.tex(n)
		r.size = Vector2(1920, 1080)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cam.add_child(r)
	var desk := TextureRect.new()
	desk.texture = OfficeArt.tex("desk")
	desk.position = Vector2(0, 640)
	desk.size = Vector2(1920, 440)
	desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cam.add_child(desk)
	for spec in [["lamp", Rect2(290, 600, 200, 240)], ["redphone", Rect2(90, 792, 200, 150)], ["mic", Rect2(1112, 690, 120, 200)], ["monitor", Rect2(1238, 548, 340, 320)], ["globe_stand", Rect2(1664, 586, 240, 300)], ["mug", Rect2(1500, 918, 100, 110)], ["folder", Rect2(1050, 935, 220, 130)]]:
		var o := TextureRect.new()
		o.texture = OfficeArt.tex(spec[0])
		o.position = spec[1].position
		o.size = spec[1].size
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cam.add_child(o)
	var light := ColorRect.new()
	UI.full(light)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lm := ShaderMaterial.new()
	lm.shader = load("res://shaders/office_light.gdshader")
	lm.set_shader_parameter("night", 0.85)
	light.material = lm
	cam.add_child(light)
	var shade := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0.01, 0.02, 0.04, 0.97))
	gr.set_color(1, Color(0.01, 0.02, 0.04, 0.25))
	gr.add_point(0.45, Color(0.01, 0.02, 0.04, 0.85))
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	UI.full(shade)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _process(delta: float) -> void:
	_t += delta
	var z := 1.06 + sin(_t * 0.07) * 0.03
	cam.scale = Vector2(z, z)
	cam.position = Vector2(sin(_t * 0.05) * 30.0, cos(_t * 0.04) * 12.0)
