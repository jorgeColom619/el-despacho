extends Control
## Canal de noticias en el televisor del despacho.

const Portrait := preload("res://scripts/ui/portrait.gd")
const W := preload("res://scripts/data/world_data.gd")

var anchor: Control
var headline := "Bienvenidos a Canal 24 Noticias"
var breaking := false
var _t := 0.0
var _talk := 0.0
var _ticker_x := 0.0
var _ticker := ""
var _poll_t := 0.0
var alert := false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor = Portrait.new()
	anchor.position = Vector2(10, 26)
	anchor.size = Vector2(124, 136)
	anchor.track_mouse = false
	add_child(anchor)
	anchor.setup(W.CHARACTERS["periodista"]["look"], false)
	GS.headline.connect(_on_headline)
	_rebuild_ticker()


func _on_headline(t: String) -> void:
	headline = t
	breaking = t.begins_with("ÚLTIMA HORA") or t.begins_with("¡")
	_talk = 3.5
	_rebuild_ticker()


func _rebuild_ticker() -> void:
	var parts := PackedStringArray()
	for n in GS.news_feed.slice(0, 8):
		parts.append(n["t"])
	if parts.is_empty():
		parts.append("Valdoria estrena Gobierno")
	parts.append("Bolsa de Santa Aurora: %s" % ("▲ " + UI.num(randf_range(0.1, 1.8), 2) + "%" if GS.meters.get("economia", 50.0) > 50.0 else "▼ " + UI.num(randf_range(0.1, 1.8), 2) + "%"))
	_ticker = "   ●   ".join(parts) + "   ●   "


func _process(delta: float) -> void:
	_t += delta
	_talk = maxf(0.0, _talk - delta)
	anchor.talking = _talk > 0.0
	anchor.mood = -0.3 if breaking else 0.2
	_ticker_x -= delta * 55.0
	_poll_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var top := Color("0b1f44")
	var bot := Color("061228")
	if alert:
		top = Color("4a0b0b").lerp(Color("6a1010"), 0.5 + 0.5 * sin(_t * 4.0))
		bot = Color("1a0404")
	draw_rect(Rect2(0, 0, w, h), bot)
	for i in 12:
		var y := h * i / 12.0
		draw_rect(Rect2(0, y, w, h / 12.0 + 1), top.lerp(bot, i / 12.0))
	for i in 5:
		var x := fmod(_t * 18.0 + i * 90.0, w + 120.0) - 60.0
		draw_rect(Rect2(x, 0, 26, h), Color(1, 1, 1, 0.025))
	# mapa decorativo
	draw_circle(Vector2(w * 0.72, h * 0.42), 58, Color(0.3, 0.5, 0.9, 0.08))
	draw_arc(Vector2(w * 0.72, h * 0.42), 58, 0, TAU, 40, Color(0.5, 0.7, 1.0, 0.25), 1.0)
	var show_poll := fmod(_poll_t, 22.0) > 15.0
	if show_poll:
		draw_string(UI.f_sans_b, Vector2(w * 0.46, 50), "ENCUESTA C24", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))
		draw_string(UI.f_cond_b, Vector2(w * 0.46, 104), UI.num(GS.approval, 0) + "%", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, UI.GOLD_L)
		draw_string(UI.f_sans, Vector2(w * 0.46, 122), "aprueba al presidente", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))
		draw_rect(Rect2(w * 0.46, 130, 160, 6), Color(1, 1, 1, 0.15))
		draw_rect(Rect2(w * 0.46, 130, 160 * GS.approval / 100.0, 6), UI.color_for(GS.approval))
	else:
		draw_string(UI.f_cond_b, Vector2(w * 0.5, 70), "VALDORIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.12))
	# logo del canal
	draw_rect(Rect2(8, 7, 40, 18), Color("c62828"))
	draw_string(UI.f_cond_b, Vector2(8, 22), "C24", HORIZONTAL_ALIGNMENT_CENTER, 40, 15, Color.WHITE)
	draw_string(UI.f_sans_b, Vector2(54, 21), "NOTICIAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9))
	if GS.active:
		draw_string(UI.f_mono, Vector2(0, 21), UI.date_short(GS.day), HORIZONTAL_ALIGNMENT_RIGHT, w - 8, 12, Color(1, 1, 1, 0.85))
	draw_circle(Vector2(w - 100, 16), 4, Color(1, 0.2, 0.2, 0.5 + 0.5 * sin(_t * 5.0)))
	# rótulo inferior
	var ly := h - 62.0
	var tag := "ÚLTIMA HORA" if (breaking or alert) else "EN DIRECTO"
	var tag_col := Color("d32f2f") if (breaking or alert) else Color("1e4fa0")
	var tw := UI.f_sans_b.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 14
	draw_rect(Rect2(0, ly, tw, 16), tag_col)
	draw_string(UI.f_sans_b, Vector2(7, ly + 12), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	draw_rect(Rect2(0, ly + 16, w, 30), Color(0.96, 0.96, 0.97, 0.95))
	draw_rect(Rect2(0, ly + 16, 4, 30), tag_col)
	var hl := headline.trim_prefix("ÚLTIMA HORA: ")
	draw_multiline_string(UI.f_sans_b, Vector2(10, ly + 29), hl, HORIZONTAL_ALIGNMENT_LEFT, w - 16, 12, 2, Color("101828"))
	# ticker
	draw_rect(Rect2(0, h - 16, w, 16), Color("0a0f1c"))
	var tsw := UI.f_sans_m.get_string_size(_ticker, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	if tsw > 0.0 and _ticker_x < -tsw:
		_ticker_x += tsw
	draw_string(UI.f_sans_m, Vector2(_ticker_x, h - 4), _ticker + _ticker, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.9, 0.6))
	# líneas de barrido
	var y2 := 0.0
	while y2 < h:
		draw_line(Vector2(0, y2), Vector2(w, y2), Color(0, 0, 0, 0.08), 1.0)
		y2 += 3.0
	draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.03), false, 2.0)
