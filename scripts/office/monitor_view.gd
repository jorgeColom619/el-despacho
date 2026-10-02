extends Control
## Pantalla del ordenador del escritorio (SIGEP en miniatura).

const W := preload("res://scripts/data/world_data.gd")
const Widgets := preload("res://scripts/ui/widgets.gd")
var _t := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color("0a1424"))
	draw_rect(Rect2(0, 0, w, 20), Color("13294a"))
	draw_string(UI.f_sans_b, Vector2(8, 15), "SIGEP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.GOLD_L)
	draw_string(UI.f_sans, Vector2(52, 15), "Sistema de Gestión Presidencial", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.6))
	if not GS.active:
		return
	draw_string(UI.f_sans_b, Vector2(10, 38), "APROBACIÓN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.6))
	draw_string(UI.f_cond_b, Vector2(10, 72), UI.num(GS.approval, 0) + "%", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UI.color_for(GS.approval))
	var hist: Array = GS.stat_hist.get("approval", [])
	var series := hist.slice(maxi(0, hist.size() - 12))
	series.append(GS.approval)
	Widgets.draw_line_chart(self, Rect2(96, 30, w - 108, 44), series, UI.GOLD, 0.0, 100.0, 2.0)
	var y := 90.0
	var i := 0
	for m in GS.METERS:
		var col := i % 2
		var row := i / 2
		var x := 10.0 + col * (w - 10.0) / 2.0
		var yy := y + row * 22.0
		draw_string(UI.f_sans_m, Vector2(x, yy + 9), W.METER_INFO[m]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.75))
		var bw := (w - 30.0) / 2.0 - 6.0
		draw_rect(Rect2(x, yy + 12, bw, 5), Color(1, 1, 1, 0.1))
		draw_rect(Rect2(x, yy + 12, bw * GS.meters[m] / 100.0, 5), UI.color_for(GS.meters[m]))
		i += 1
	var info := "Bandeja %d  ·  Visitas %d  ·  Alertas %d" % [GS.inbox.size(), GS.visitors.size(), GS.alerts.size()]
	draw_string(UI.f_mono, Vector2(10, h - 8), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 1.0, 0.7, 0.8))
	if int(_t * 2.0) % 2 == 0:
		draw_rect(Rect2(w - 16, h - 18, 7, 12), Color(0.5, 1.0, 0.7, 0.8))
	draw_rect(Rect2(0, 0, w, h), Color(0.3, 0.6, 1.0, 0.04))
