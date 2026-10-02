extends "res://scripts/ui/overlay.gd"
## Noche electoral: escrutinio en directo región a región.

const Widgets := preload("res://scripts/ui/widgets.gd")
const MapView := preload("res://scripts/ui/map_view.gd")
const W := preload("res://scripts/data/world_data.gd")

const DURATION := 11.0

var res: Dictionary
var map: Control
var t := 0.0
var done := false
var order := []
var revealed := {}
var bars: Control
var pct_lbl: Label
var list_box: VBoxContainer
var banner: Label
var sub: Label


func build() -> void:
	dim.color = Color(0.01, 0.015, 0.03, 0.98)
	res = GS.compute_election()
	Sfx.music("music_tension", 1.0)
	var head := title_bar("Noche electoral", "Elecciones generales · Escrutinio en directo", "votar")
	head.position = Vector2(70, 110)
	root.add_child(head)
	pct_lbl = UI.lbl("", UI.f_cond_b, 40, UI.GOLD_L, HORIZONTAL_ALIGNMENT_RIGHT)
	pct_lbl.position = Vector2(860, 130)
	pct_lbl.size = Vector2(260, 50)
	root.add_child(pct_lbl)
	map = MapView.new()
	map.position = Vector2(70, 210)
	map.size = Vector2(1050, 798)
	map.mode = 1
	root.add_child(map)
	map.set_mode(1)
	for i in range(1, 9):
		map.set_region(i, Color(0.18, 0.2, 0.24))
	var lbls := Control.new()
	lbls.position = map.position
	lbls.size = map.size
	lbls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbls.draw.connect(func():
		for id in range(1, 9):
			var c: Vector2 = map.centroids.get(id, Vector2.ZERO)
			lbls.draw_string(UI.f_sans_b, c + Vector2(-90, -8), W.REGIONS[id]["name"].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 180, 14, Color.WHITE)
			if revealed.has(id):
				var win: String = res["regions"][id]["winner"]
				var sh: float = res["regions"][id]["shares"][win]
				lbls.draw_string(UI.f_cond_b, c + Vector2(-90, 18), "%s %s%%" % [W.PARTIES[win]["short"], UI.num(sh, 1)], HORIZONTAL_ALIGNMENT_CENTER, 180, 20, Color.WHITE))
	root.add_child(lbls)
	set_meta("lbls", lbls)
	var right := UI.vbox(10)
	right.position = Vector2(1170, 210)
	right.size = Vector2(700, 800)
	root.add_child(right)
	right.add_child(Widgets.section("Reparto de escaños"))
	bars = Control.new()
	bars.custom_minimum_size = Vector2(700, 90)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.draw.connect(_draw_bars)
	right.add_child(bars)
	list_box = UI.vbox(8)
	right.add_child(list_box)
	banner = UI.lbl("", UI.f_cond_b, 64, UI.GOLD_L)
	right.add_child(banner)
	sub = UI.lbl("", UI.f_sans_m, 20, UI.TEXT)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(700, 0)
	right.add_child(sub)
	order = [1, 2, 3, 4, 5, 6, 7, 8]
	order.shuffle()
	Sfx.play("news", -4.0)


func _frac() -> float:
	return clampf(t / DURATION, 0.0, 1.0)


func _process(delta: float) -> void:
	if done:
		return
	t += delta
	var f := _frac()
	var ease_f := 1.0 - pow(1.0 - f, 2.0)
	pct_lbl.text = "Escrutado: %s%%" % UI.num(ease_f * 100.0, 1)
	var n := int(f * 8.99)
	for i in mini(n, order.size()):
		var id: int = order[i]
		if not revealed.has(id):
			revealed[id] = true
			var win: String = res["regions"][id]["winner"]
			map.set_region(id, Color(W.PARTIES[win]["color"]))
			Sfx.play("vote_tick", -2.0, 0.8)
	(get_meta("lbls") as Control).queue_redraw()
	bars.queue_redraw()
	_update_list(ease_f)
	if f >= 1.0:
		_conclude()


func _update_list(f: float) -> void:
	for c in list_box.get_children():
		c.queue_free()
	var parties: Array = W.PARTY_ORDER.duplicate()
	parties.sort_custom(func(a, b): return int(res["seats"][a]) > int(res["seats"][b]))
	for p in parties:
		var h := UI.hbox(12)
		var sw := ColorRect.new()
		sw.color = Color(W.PARTIES[p]["color"])
		sw.custom_minimum_size = Vector2(8, 34)
		h.add_child(sw)
		var l := UI.lbl(W.PARTIES[p]["name"] + (" ★" if p == GS.pres["party"] else ""), UI.f_sans_b if p == GS.pres["party"] else UI.f_sans_m, 18, UI.TEXT)
		l.custom_minimum_size = Vector2(330, 0)
		h.add_child(l)
		var vl := UI.lbl(UI.pct(float(res["shares"][p]) * clampf(f * 1.2, 0.0, 1.0) + float(res["shares"][p]) * 0.0, 1), UI.f_sans, 17, UI.DIM)
		vl.custom_minimum_size = Vector2(110, 0)
		h.add_child(vl)
		h.add_child(UI.lbl("%d escaños" % int(round(float(res["seats"][p]) * f)), UI.f_cond_b, 22, UI.TEXT))
		list_box.add_child(h)


func _draw_bars() -> void:
	var w := bars.size.x
	var f := 1.0 - pow(1.0 - _frac(), 2.0)
	var x := 0.0
	for p in W.PARTY_ORDER:
		var sw := w * float(res["seats"][p]) / 350.0 * f
		bars.draw_rect(Rect2(x, 20, sw, 40), Color(W.PARTIES[p]["color"]))
		x += sw
	bars.draw_rect(Rect2(0, 20, w, 40), Color(1, 1, 1, 0.3), false, 1.0)
	var mx := w * 176.0 / 350.0
	bars.draw_line(Vector2(mx, 10), Vector2(mx, 70), Color.WHITE, 2.0)
	bars.draw_string(UI.f_sans_b, Vector2(mx + 6, 84), "Mayoría absoluta: 176", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.TEXT)


func _conclude() -> void:
	done = true
	_update_list(1.0)
	var won: bool = res["won"]
	var own: String = GS.pres["party"]
	var own_seats := int(res["seats"][own])
	banner.text = "¡REELEGIDO!" if won else "DERROTA ELECTORAL"
	banner.add_theme_color_override("font_color", UI.GREEN if won else UI.RED)
	if won:
		var allies: Array = res["allies"]
		var names := []
		for a in allies:
			names.append(W.PARTIES[a]["short"])
		sub.text = "%s obtiene %d escaños%s. %s seguirá siendo presidente." % [W.PARTIES[own]["name"], own_seats, (" y gobernará con el apoyo de " + ", ".join(PackedStringArray(names))) if names.size() > 0 and own_seats < 176 else "", GS.pres["name"]]
		if res.get("minority", false):
			sub.text = "%s gana con %d escaños. La oposición no suma una mayoría alternativa: %s gobernará en minoría." % [W.PARTIES[own]["name"], own_seats, GS.pres["name"]]
		Sfx.play("cheer", -2.0)
		Sfx.play("sting_win", -4.0)
	else:
		var first: String = res["first"]
		sub.text = "%s obtiene %d escaños. %s" % [W.PARTIES[own]["name"], own_seats, ("%s gana las elecciones y formará Gobierno." % W.PARTIES[first]["name"]) if first != own else "No alcanza apoyos suficientes para gobernar."]
		Sfx.play("sting_lose", -2.0)
	UI.pop_in(banner)
	var b := UI.btn("Continuar", "gold", 22)
	b.pressed.connect(func():
		GS.end_game("reelegido" if won else "derrota"))
	list_box.get_parent().add_child(b)


func on_escape() -> void:
	pass
