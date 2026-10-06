extends Control
## Lienzos 2D que se pintan en texturas del despacho 3D: portada del periódico, hoja del calendario,
## bandera nacional, fondo del retrato oficial y mascotas.

const Flags := preload("res://scripts/ui/flags.gd")
const PetArt := preload("res://scripts/office/pet_art.gd")

var kind := ""
var pet_kind := ""
var pet_happy := false
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	if kind == "pet":
		_t += delta
		queue_redraw()


func _draw() -> void:
	match kind:
		"newspaper":
			_newspaper()
		"calendar":
			_calendar()
		"flag":
			Flags.draw_valdoria(self, Rect2(Vector2.ZERO, size), Flags.current_style())
		"portrait_bg":
			var top := Color("3a2a1c")
			var bot := Color("120c08")
			for i in 24:
				draw_rect(Rect2(0, size.y * i / 24.0, size.x, size.y / 24.0 + 1), top.lerp(bot, i / 24.0))
			draw_circle(size * Vector2(0.5, 0.42), size.x * 0.42, Color(1, 0.85, 0.6, 0.05))
		"pet":
			PetArt.draw(self, pet_kind, _t, pet_happy, "")


func _newspaper() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.93, 0.9, 0.82))
	draw_string(UI.f_goth, Vector2(0, 52), "El Diario", HORIZONTAL_ALIGNMENT_CENTER, w, 46, Color(0.08, 0.08, 0.08))
	draw_string(UI.f_sans_b, Vector2(0, 70), "DE LA REPÚBLICA", HORIZONTAL_ALIGNMENT_CENTER, w, 10, Color(0.15, 0.15, 0.15))
	draw_line(Vector2(12, 78), Vector2(w - 12, 78), Color(0.1, 0.1, 0.1), 2.0)
	draw_string(UI.f_sans, Vector2(12, 92), UI.date_long(GS.day) if GS.active else "", HORIZONTAL_ALIGNMENT_LEFT, w - 24, 10, Color(0.2, 0.2, 0.2))
	draw_line(Vector2(12, 98), Vector2(w - 12, 98), Color(0.1, 0.1, 0.1), 1.0)
	var hl := "Nuevo Gobierno en Valdoria"
	if GS.news_feed.size() > 0:
		hl = GS.news_feed[0]["t"]
	draw_multiline_string(UI.f_serif_b, Vector2(12, 128), hl, HORIZONTAL_ALIGNMENT_LEFT, w - 24, 25, 4, Color(0.06, 0.06, 0.06))
	var py := 250.0
	draw_rect(Rect2(12, py, w * 0.55, 110), Color(0.55, 0.55, 0.57))
	for i in 9:
		draw_line(Vector2(12 + i * 18, py), Vector2(12 + i * 18 + 60, py + 110), Color(1, 1, 1, 0.06), 6.0)
	for k in 12:
		var x0 := w * 0.55 + 22.0
		draw_line(Vector2(x0, py + 4 + k * 9), Vector2(w - 12, py + 4 + k * 9), Color(0.3, 0.3, 0.3, 0.55), 2.0)
	for k2 in 4:
		draw_line(Vector2(12, py + 124 + k2 * 9), Vector2(w - 12, py + 124 + k2 * 9), Color(0.3, 0.3, 0.3, 0.55), 2.0)
	if GS.news_feed.size() > 1:
		draw_string(UI.f_serif_b, Vector2(12, h - 14), GS.news_feed[1]["t"], HORIZONTAL_ALIGNMENT_LEFT, w - 24, 13, Color(0.1, 0.1, 0.1))


func _calendar() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.97, 0.96, 0.93))
	draw_rect(Rect2(0, 0, w, 30), Color("b3261e"))
	var d := UI.date_dict(GS.day)
	draw_string(UI.f_sans_b, Vector2(0, 22), UI.MONTHS_SHORT[d["month"] - 1] + " " + str(d["year"]), HORIZONTAL_ALIGNMENT_CENTER, w, 17, Color.WHITE)
	draw_string(UI.f_cond_b, Vector2(0, 92), str(d["day"]), HORIZONTAL_ALIGNMENT_CENTER, w, 58, Color(0.12, 0.12, 0.14))
	draw_string(UI.f_sans_m, Vector2(0, 114), UI.WEEKDAYS[d["weekday"]], HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(0.35, 0.35, 0.4))
