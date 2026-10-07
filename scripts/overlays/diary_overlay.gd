extends "res://scripts/ui/overlay.gd"
## Lectura ampliada de los diarios de opinión de la mesa baja: la misma cita que en la mesa, pero
## grande y cómoda de leer, con un tono (color) según sea favorable, tibia o crítica.

const PaperView := preload("res://scripts/office3d/paper_views.gd")

const MOOD_COLOR := {"good": Color("8fc77a"), "bad": Color("d98a7a"), "mid": Color("c9c2a8")}
const MOOD_LABEL := {"good": "FAVORABLE", "bad": "CRÍTICA", "mid": "TIBIA"}

var _who_lbl: Label
var _job_lbl: Label
var _quote_lbl: Label
var _mood_lbl: Label


func build() -> void:
	var cc := CenterContainer.new()
	UI.full(cc)
	root.add_child(cc)
	var p := UI.panel(Color(0.08, 0.07, 0.05, 0.98), 14, Color(UI.GOLD, 0.55), 36)
	p.custom_minimum_size = Vector2(640, 0)
	cc.add_child(p)
	var v := UI.vbox(10)
	p.add_child(v)
	v.add_child(UI.lbl("La Voz del Pueblo", UI.f_goth, 44, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.lbl("ENCUESTA DE OPINIÓN IMPROVISADA", UI.f_sans_b, 13, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer(0, 10))
	_mood_lbl = UI.lbl("", UI.f_sans_b, 14, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_mood_lbl)
	_who_lbl = UI.lbl("", UI.f_serif_b, 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_who_lbl)
	_job_lbl = UI.lbl("", UI.f_sans_m, 16, Color(UI.TEXT, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_job_lbl)
	v.add_child(UI.spacer(0, 6))
	_quote_lbl = UI.lbl("", UI.f_serif, 23, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote_lbl.custom_minimum_size = Vector2(560, 0)
	v.add_child(_quote_lbl)
	v.add_child(UI.spacer(0, 16))
	var h := UI.hbox(14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var next_b := UI.btn("Leer otra opinión", "normal", 18)
	next_b.pressed.connect(_next)
	h.add_child(next_b)
	var close_b := UI.btn("Dejar el diario", "gold", 18)
	close_b.pressed.connect(func(): close())
	h.add_child(close_b)
	_refresh()
	UI.pop_in(p)


func _refresh() -> void:
	var op := PaperView.pick_opinion(int(data.get("seed", 0)))
	_who_lbl.text = op["who"]
	_job_lbl.text = op["job"]
	_quote_lbl.text = op["quote"]
	var mood: String = op["mood"]
	_mood_lbl.text = "OPINIÓN " + MOOD_LABEL.get(mood, "TIBIA")
	_mood_lbl.add_theme_color_override("font_color", MOOD_COLOR.get(mood, UI.TEXT))


func _next() -> void:
	if main != null and main.office != null:
		data["seed"] = main.office.next_diary_opinion()
	_refresh()


func on_escape() -> void:
	close()
